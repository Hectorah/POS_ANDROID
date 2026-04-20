import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../DATABASE/db_helper.dart';
import '../enums/sync_status.dart';

/// Escucha cambios en Supabase en tiempo real y los aplica en SQLite local.
///
/// Flujo nube → local:
///   Supabase INSERT/UPDATE → RealtimeSyncService → SQLite (upsert local)
///   Supabase DELETE        → RealtimeSyncService → SQLite (delete local)
///
/// Tablas monitoreadas: productos, existencias, clientes, factura,
///                      factura_detalle, cierres_lote, usuarios.
///
/// IMPORTANTE: Solo aplica cambios que vienen de OTRO dispositivo.
/// Los cambios que esta misma app hizo ya están en local, así que
/// se ignoran usando el server_id como identificador.
class RealtimeSyncService {
  static final RealtimeSyncService instance = RealtimeSyncService._();
  RealtimeSyncService._();

  final List<RealtimeChannel> _channels = [];
  bool _initialized = false;

  // ─────────────────────────────────────────────────────────────────────────
  // INICIALIZACIÓN
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    debugPrint('📡 Iniciando Realtime sync...');

    _listenTable(
      table: 'productos',
      onInsertOrUpdate: _onProductoRemoto,
      onDelete: (row) => _onDeleteRemoto('productos', row, uniqueCol: 'cod_articulo'),
    );

    _listenTable(
      table: 'existencias',
      onInsertOrUpdate: _onExistenciaRemota,
      onDelete: (row) => _onDeleteRemoto('existencias', row, uniqueCol: 'cod_articulo'),
    );

    _listenTable(
      table: 'clientes',
      onInsertOrUpdate: (row) => _onUpsertRemoto('clientes', row, uniqueCol: 'identificacion'),
      onDelete: (row) => _onDeleteRemoto('clientes', row, uniqueCol: 'identificacion'),
    );

    _listenTable(
      table: 'factura',
      onInsertOrUpdate: (row) => _onUpsertRemoto('factura', row, uniqueCol: 'numero_control'),
      onDelete: (row) => _onDeleteRemoto('factura', row, uniqueCol: 'numero_control'),
    );

    _listenTable(
      table: 'factura_detalle',
      onInsertOrUpdate: (row) => _onUpsertRemoto('factura_detalle', row),
      onDelete: (row) => _onDeleteRemoto('factura_detalle', row),
    );

    _listenTable(
      table: 'cierres_lote',
      onInsertOrUpdate: (row) => _onUpsertRemoto('cierres_lote', row),
      onDelete: null,
    );

    _listenTable(
      table: 'usuarios',
      onInsertOrUpdate: (row) => _onUpsertRemoto('usuarios', row, uniqueCol: 'usuario'),
      onDelete: null,
    );

    debugPrint('✅ Realtime sync activo — 7 tablas monitoreadas');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HANDLERS ESPECÍFICOS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _onProductoRemoto(Map<String, dynamic> row) async {
    final db = await DbHelper.instance.database;
    final serverId = row['server_id'] as String?;
    if (serverId == null) return;

    // Verificar si ya existe localmente por server_id
    final existing = await db.query('productos',
        where: 'server_id = ?', whereArgs: [serverId], limit: 1);

    final localRow = _toLocalRow(row);

    if (existing.isEmpty) {
      // Nuevo producto desde otro dispositivo → insertar
      await db.insert('productos', {
        ...localRow,
        'sync_status': SyncStatus.synced.toInt(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      debugPrint('📥 [productos] Nuevo desde nube: ${row['cod_articulo']}');
    } else {
      // Actualización desde otro dispositivo
      final localLastModified = DateTime.tryParse(
              existing.first['last_modified'] as String? ?? '') ??
          DateTime(2000);
      final remoteLastModified =
          DateTime.tryParse(row['last_modified'] as String? ?? '') ??
              DateTime(2000);

      // Solo actualizar si el remoto es más reciente
      if (remoteLastModified.isAfter(localLastModified)) {
        await db.update(
          'productos',
          {
            ...localRow,
            'sync_status': SyncStatus.synced.toInt(),
          },
          where: 'server_id = ?',
          whereArgs: [serverId],
        );
        debugPrint('📥 [productos] Actualizado desde nube: ${row['cod_articulo']}');
      }
    }
  }

  Future<void> _onExistenciaRemota(Map<String, dynamic> row) async {
    final db = await DbHelper.instance.database;
    final codArticulo = row['cod_articulo'] as String?;
    if (codArticulo == null) return;

    final existing = await db.query('existencias',
        where: 'cod_articulo = ?', whereArgs: [codArticulo], limit: 1);

    final localRow = _toLocalRow(row);

    if (existing.isEmpty) {
      await db.insert('existencias', {
        ...localRow,
        'sync_status': SyncStatus.synced.toInt(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      debugPrint('📥 [existencias] Nueva desde nube: $codArticulo');
    } else {
      final localLastModified = DateTime.tryParse(
              existing.first['last_modified'] as String? ?? '') ??
          DateTime(2000);
      final remoteLastModified =
          DateTime.tryParse(row['last_modified'] as String? ?? '') ??
              DateTime(2000);

      if (remoteLastModified.isAfter(localLastModified)) {
        await db.update(
          'existencias',
          {
            ...localRow,
            'sync_status': SyncStatus.synced.toInt(),
          },
          where: 'cod_articulo = ?',
          whereArgs: [codArticulo],
        );
        debugPrint('📥 [existencias] Stock actualizado desde nube: $codArticulo stock=${row['stock']}');
      }
    }
  }

  /// Handler genérico para tablas con uniqueCol de negocio.
  Future<void> _onUpsertRemoto(String table, Map<String, dynamic> row,
      {String? uniqueCol}) async {
    final db = await DbHelper.instance.database;
    final serverId = row['server_id'] as String?;
    if (serverId == null) return;

    // Buscar por server_id primero, luego por uniqueCol
    List<Map<String, dynamic>> existing = await db.query(table,
        where: 'server_id = ?', whereArgs: [serverId], limit: 1);

    if (existing.isEmpty && uniqueCol != null && row[uniqueCol] != null) {
      existing = await db.query(table,
          where: '$uniqueCol = ?', whereArgs: [row[uniqueCol]], limit: 1);
    }

    final localRow = _toLocalRow(row);

    if (existing.isEmpty) {
      await db.insert(table, {
        ...localRow,
        'sync_status': SyncStatus.synced.toInt(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      debugPrint('📥 [$table] Nuevo desde nube');
    } else {
      final localLastModified = DateTime.tryParse(
              existing.first['last_modified'] as String? ?? '') ??
          DateTime(2000);
      final remoteLastModified =
          DateTime.tryParse(row['last_modified'] as String? ?? '') ??
              DateTime(2000);

      if (remoteLastModified.isAfter(localLastModified)) {
        await db.update(
          table,
          {
            ...localRow,
            'sync_status': SyncStatus.synced.toInt(),
          },
          where: 'server_id = ?',
          whereArgs: [serverId],
        );
        debugPrint('📥 [$table] Actualizado desde nube');
      }
    }
  }

  Future<void> _onDeleteRemoto(String table, Map<String, dynamic> row,
      {String? uniqueCol}) async {
    final db = await DbHelper.instance.database;
    final serverId = row['server_id'] as String?;

    if (serverId != null) {
      await db.delete(table, where: 'server_id = ?', whereArgs: [serverId]);
      debugPrint('🗑️ [$table] Eliminado desde nube (server_id=$serverId)');
      return;
    }

    // Fallback por uniqueCol si no hay server_id en el evento DELETE
    if (uniqueCol != null && row[uniqueCol] != null) {
      await db.delete(table,
          where: '$uniqueCol = ?', whereArgs: [row[uniqueCol]]);
      debugPrint('🗑️ [$table] Eliminado desde nube (${row[uniqueCol]})');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SUSCRIPCIÓN GENÉRICA
  // ─────────────────────────────────────────────────────────────────────────

  void _listenTable({
    required String table,
    required Future<void> Function(Map<String, dynamic>)? onInsertOrUpdate,
    required Future<void> Function(Map<String, dynamic>)? onDelete,
  }) {
    final channel = Supabase.instance.client
        .channel('realtime:$table')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: table,
          callback: (payload) {
            if (onInsertOrUpdate != null) {
              onInsertOrUpdate(payload.newRecord).catchError(
                (e) => debugPrint('❌ Realtime INSERT [$table]: $e'),
              );
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: table,
          callback: (payload) {
            if (onInsertOrUpdate != null) {
              onInsertOrUpdate(payload.newRecord).catchError(
                (e) => debugPrint('❌ Realtime UPDATE [$table]: $e'),
              );
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: table,
          callback: (payload) {
            if (onDelete != null) {
              onDelete(payload.oldRecord).catchError(
                (e) => debugPrint('❌ Realtime DELETE [$table]: $e'),
              );
            }
          },
        )
        .subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint('📡 Realtime suscrito: $table');
          } else if (error != null) {
            debugPrint('❌ Realtime error [$table]: $error');
          }
        });

    _channels.add(channel);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UTILIDADES
  // ─────────────────────────────────────────────────────────────────────────

  /// Convierte una fila de Supabase al formato local de SQLite.
  /// Elimina server_id del mapa de datos (se guarda por separado)
  /// y añade sync_status = synced.
  Map<String, dynamic> _toLocalRow(Map<String, dynamic> remoteRow) {
    final map = Map<String, dynamic>.from(remoteRow);
    // Conservar server_id en local para futuras actualizaciones
    // Convertir timestamps de Supabase (ISO con zona) a formato local
    if (map['last_modified'] != null) {
      map['last_modified'] =
          DateTime.tryParse(map['last_modified'].toString())
                  ?.toLocal()
                  .toIso8601String() ??
              map['last_modified'];
    }
    if (map['fecha_creacion'] != null) {
      map['fecha_creacion'] =
          DateTime.tryParse(map['fecha_creacion'].toString())
                  ?.toLocal()
                  .toIso8601String() ??
              map['fecha_creacion'];
    }
    if (map['ultima_actualizacion'] != null) {
      map['ultima_actualizacion'] =
          DateTime.tryParse(map['ultima_actualizacion'].toString())
                  ?.toLocal()
                  .toIso8601String() ??
              map['ultima_actualizacion'];
    }
    return map;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LIMPIEZA
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    for (final channel in _channels) {
      await Supabase.instance.client.removeChannel(channel);
    }
    _channels.clear();
    _initialized = false;
    debugPrint('📡 Realtime sync detenido');
  }
}
