import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../enums/sync_status.dart';
import '../models/syncable_model.dart';
import '../services/connectivity_service.dart';

/// Repositorio base genérico para la arquitectura Offline-First.
///
/// Implementa el patrón Repository: las pantallas solo hablan con el
/// repositorio concreto, nunca con SQLite o Supabase directamente.
///
/// Estrategia de sincronización:
/// - ESCRITURA: Siempre guarda en local primero. Si hay internet, intenta
///   subir a Supabase de inmediato. Si no, marca como [pendingUpload].
/// - LECTURA: Siempre lee desde SQLite (fuente de verdad local).
/// - CONFLICTOS: Configurable por tabla (ver [conflictStrategy]).
///
/// Para añadir una nueva tabla, solo hay que crear un repositorio concreto
/// que extienda esta clase e implemente los métodos abstractos.
abstract class BaseRepository<T extends SyncableModel> {
  /// Nombre de la tabla en SQLite y en Supabase (deben ser iguales).
  String get tableName;

  /// Nombre de la columna PK local en SQLite (normalmente 'id').
  String get localPkColumn => 'id';

  /// Nombre de la columna UUID en Supabase (normalmente 'server_id').
  String get serverIdColumn => 'server_id';

  /// Estrategia de conflicto:
  /// - true  → Los datos locales ganan (ideal para ventas/facturas).
  /// - false → Los datos del servidor ganan (ideal para catálogo de productos).
  bool get localWinsOnConflict => false;

  // ---------------------------------------------------------------------------
  // MÉTODOS ABSTRACTOS — Implementar en cada repositorio concreto
  // ---------------------------------------------------------------------------

  /// Inserta un registro en SQLite y retorna el id generado.
  Future<int> insertLocal(T model);

  /// Actualiza un registro existente en SQLite.
  Future<void> updateLocal(T model);

  /// Obtiene todos los registros de SQLite.
  Future<List<T>> getAllLocal();

  /// Obtiene registros de SQLite filtrados por [SyncStatus].
  Future<List<T>> getLocalByStatus(SyncStatus status);

  /// Actualiza solo los campos de sincronización de un registro local.
  Future<void> updateSyncFields(
    int localId, {
    required String? serverId,
    required SyncStatus syncStatus,
    required DateTime lastModified,
  });

  /// Convierte un mapa de Supabase al modelo local.
  T fromRemoteMap(Map<String, dynamic> map);

  // ---------------------------------------------------------------------------
  // OPERACIONES PÚBLICAS — Usadas por las pantallas/providers
  // ---------------------------------------------------------------------------

  /// Guarda un nuevo registro aplicando la lógica offline-first.
  /// Retorna el modelo con [id] local y [serverId] si se sincronizó.
  Future<T> save(T model) async {
    final modelToSave = model.copyWithSyncFields(
      lastModified: DateTime.now(),
      syncStatus: SyncStatus.pendingUpload,
    ) as T;

    // 1. Guardar en local primero (siempre) — retorna el id local
    final localId = await insertLocal(modelToSave);
    debugPrint('💾 [$tableName] Guardado local id=$localId');

    // 2. Intentar subir si hay internet
    if (ConnectivityService.instance.isOnline) {
      return await _pushRecord(localId, modelToSave);
    }

    debugPrint('📴 [$tableName] Sin internet → pendiente de subida');
    return modelToSave;
  }

  /// Igual que [save] pero retorna también el id local generado por SQLite.
  Future<({T model, int localId})> saveWithId(T model) async {
    final modelToSave = model.copyWithSyncFields(
      lastModified: DateTime.now(),
      syncStatus: SyncStatus.pendingUpload,
    ) as T;

    final localId = await insertLocal(modelToSave);
    debugPrint('💾 [$tableName] Guardado local id=$localId');

    if (ConnectivityService.instance.isOnline) {
      final synced = await _pushRecord(localId, modelToSave);
      return (model: synced, localId: localId);
    }

    debugPrint('📴 [$tableName] Sin internet → pendiente de subida');
    return (model: modelToSave, localId: localId);
  }

  /// Actualiza un registro existente aplicando la lógica offline-first.
  Future<T> update(T model) async {
    final modelToUpdate = model.copyWithSyncFields(
      lastModified: DateTime.now(),
      // Si ya estaba synced, pasa a pendingUpdate; si era pendingUpload, se mantiene
      syncStatus: model.syncStatus == SyncStatus.synced
          ? SyncStatus.pendingUpdate
          : model.syncStatus,
    ) as T;

    await updateLocal(modelToUpdate);
    debugPrint('✏️ [$tableName] Actualizado local');

    if (ConnectivityService.instance.isOnline && model.serverId != null) {
      return await _updateRemote(modelToUpdate);
    }

    return modelToUpdate;
  }

  // ---------------------------------------------------------------------------
  // SINCRONIZACIÓN — Llamada por SyncManager
  // ---------------------------------------------------------------------------

  /// Push: sube todos los registros pendientes a Supabase.
  Future<void> pushPending() async {
    final pending = [
      ...await getLocalByStatus(SyncStatus.pendingUpload),
      ...await getLocalByStatus(SyncStatus.pendingUpdate),
    ];

    if (pending.isEmpty) {
      debugPrint('✅ [$tableName] Nada pendiente de subir');
      return;
    }

    debugPrint('⬆️ [$tableName] Subiendo ${pending.length} registros...');

    for (final record in pending) {
      try {
        if (record.syncStatus == SyncStatus.pendingUpload) {
          await _pushRecord(null, record);
        } else {
          await _updateRemote(record);
        }
      } catch (e) {
        debugPrint('❌ [$tableName] Error subiendo registro: $e');
        // Continúa con el siguiente; se reintentará en el próximo ciclo
      }
    }
  }

  /// Pull: descarga cambios desde Supabase y los aplica en local.
  ///
  /// Estrategia de conflicto:
  /// - [localWinsOnConflict] = true  → Solo inserta registros nuevos del servidor.
  /// - [localWinsOnConflict] = false → El servidor sobreescribe el local.
  Future<void> pullFromServer() async {
    try {
      debugPrint('⬇️ [$tableName] Descargando desde Supabase...');

      final remoteData = await Supabase.instance.client
          .from(tableName)
          .select()
          .order('last_modified', ascending: false);

      final localRecords = await getAllLocal();
      final localServerIds = localRecords
          .where((r) => r.serverId != null)
          .map((r) => r.serverId!)
          .toSet();

      int inserted = 0;
      int updated = 0;

      for (final remoteMap in remoteData) {
        final remoteServerId = remoteMap[serverIdColumn] as String?;
        if (remoteServerId == null) continue;

        if (!localServerIds.contains(remoteServerId)) {
          // Registro nuevo del servidor → insertar en local
          final model = fromRemoteMap(remoteMap).copyWithSyncFields(
            serverId: remoteServerId,
            syncStatus: SyncStatus.synced,
            lastModified: DateTime.tryParse(
                    remoteMap['last_modified'] ?? '') ??
                DateTime.now(),
          ) as T;
          await insertLocal(model);
          inserted++;
        } else if (!localWinsOnConflict) {
          // Servidor gana → actualizar local con datos remotos
          final localRecord =
              localRecords.firstWhere((r) => r.serverId == remoteServerId);
          final remoteLastModified =
              DateTime.tryParse(remoteMap['last_modified'] ?? '') ??
                  DateTime.now();

          // Solo actualizar si el servidor tiene datos más recientes
          if (remoteLastModified.isAfter(localRecord.lastModified)) {
            final model = fromRemoteMap(remoteMap).copyWithSyncFields(
              serverId: remoteServerId,
              syncStatus: SyncStatus.synced,
              lastModified: remoteLastModified,
            ) as T;
            await updateLocal(model);
            updated++;
          }
        }
        // Si localWinsOnConflict = true, ignoramos el registro remoto
      }

      debugPrint(
          '✅ [$tableName] Pull completado: $inserted nuevos, $updated actualizados');
    } catch (e) {
      debugPrint('❌ [$tableName] Error en pull: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // MÉTODOS PRIVADOS
  // ---------------------------------------------------------------------------

  /// Sube un registro nuevo a Supabase y actualiza el server_id en local.
  Future<T> _pushRecord(int? localId, T model) async {
    try {
      final response = await Supabase.instance.client
          .from(tableName)
          .insert(model.toRemoteMap())
          .select()
          .single();

      final serverId = response[serverIdColumn] as String;
      final now = DateTime.now();

      if (localId != null) {
        await updateSyncFields(
          localId,
          serverId: serverId,
          syncStatus: SyncStatus.synced,
          lastModified: now,
        );
      }

      debugPrint('☁️ [$tableName] Subido a Supabase → server_id=$serverId');

      return model.copyWithSyncFields(
        serverId: serverId,
        syncStatus: SyncStatus.synced,
        lastModified: now,
      ) as T;
    } catch (e) {
      debugPrint('❌ [$tableName] Error subiendo a Supabase: $e');
      rethrow;
    }
  }

  /// Actualiza un registro existente en Supabase.
  Future<T> _updateRemote(T model) async {
    try {
      await Supabase.instance.client
          .from(tableName)
          .update(model.toRemoteMap())
          .eq(serverIdColumn, model.serverId!);

      debugPrint('☁️ [$tableName] Actualizado en Supabase → server_id=${model.serverId}');

      return model.copyWithSyncFields(
        syncStatus: SyncStatus.synced,
        lastModified: model.lastModified,
      ) as T;
    } catch (e) {
      debugPrint('❌ [$tableName] Error actualizando en Supabase: $e');
      rethrow;
    }
  }
}
