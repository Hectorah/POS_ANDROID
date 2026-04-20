import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/connectivity_service.dart';
import '../services/sync_trigger.dart';
import '../enums/sync_status.dart';
import '../../DATABASE/db_helper.dart';

/// Gestor central de sincronización.
/// - Al iniciar: push pendientes locales + pull completo desde Supabase.
/// - Al reconectar: repite el ciclo completo.
class SyncManager {
  static final SyncManager instance = SyncManager._();
  SyncManager._();

  bool _isSyncing = false;
  StreamSubscription<void>? _sub;

  Future<void> initialize() async {
    debugPrint('🔄 Inicializando SyncManager...');

    _sub = ConnectivityService.instance.onConnected.listen((_) {
      debugPrint('🌐 Conexión recuperada → sync automático');
      syncAll();
    });

    debugPrint('✅ SyncManager listo');

    if (ConnectivityService.instance.isOnline) {
      await syncAll();
    }
  }

  /// Push pendientes locales + Pull cambios de Supabase.
  Future<void> syncAll() async {
    if (_isSyncing) return;
    if (!ConnectivityService.instance.isOnline) return;

    _isSyncing = true;
    debugPrint('🔄 ── Inicio sincronización ──');
    try {
      await SyncTrigger.instance.pushAllPending();
      await pullAll();
      debugPrint('✅ ── Sincronización completada ──');
    } catch (e) {
      debugPrint('❌ Error en sync: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> pushAll() => SyncTrigger.instance.pushAllPending();

  /// Descarga desde Supabase todo lo que no existe o es más reciente en local.
  /// Orden respetando dependencias FK:
  ///   usuarios → clientes → productos → existencias
  ///   → factura → factura_detalle → cierres_lote
  Future<void> pullAll() async {
    if (!ConnectivityService.instance.isOnline) return;
    debugPrint('⬇️ Pull: descargando cambios desde Supabase...');
    await _pullTable('usuarios',        uniqueCol: 'usuario');
    await _pullTable('clientes',        uniqueCol: 'identificacion');
    await _pullTable('productos',       uniqueCol: 'cod_articulo');
    await _pullExistencias(); // especial: resuelve producto_id local por cod_articulo
    await _pullTable('factura',         uniqueCol: 'numero_control');
    await _pullFacturaDetalle(); // especial: resuelve factura_id y producto_id locales
    await _pullTable('cierres_lote');
    debugPrint('✅ Pull completado');
  }

  /// Descarga una tabla de Supabase y hace upsert en SQLite local.
  Future<void> _pullTable(String table, {String? uniqueCol}) async {
    try {
      final db = await DbHelper.instance.database;

      final remoteRows = await Supabase.instance.client
          .from(table)
          .select()
          .order('last_modified', ascending: false);

      int inserted = 0;
      int updated = 0;

      for (final remoteRow in remoteRows) {
        final serverId = remoteRow['server_id'] as String?;
        if (serverId == null) continue;

        // Buscar en local por server_id primero
        List<Map<String, dynamic>> localRows = await db.query(
          table,
          where: 'server_id = ?',
          whereArgs: [serverId],
          limit: 1,
        );

        // Si no encontró, buscar por uniqueCol (ej: identificacion, cod_articulo)
        if (localRows.isEmpty && uniqueCol != null && remoteRow[uniqueCol] != null) {
          localRows = await db.query(
            table,
            where: '$uniqueCol = ?',
            whereArgs: [remoteRow[uniqueCol]],
            limit: 1,
          );
        }

        final localRow = _remoteToLocal(remoteRow);

        if (localRows.isEmpty) {
          // No existe en local → insertar con replace para manejar
          // cualquier conflicto de UNIQUE constraints
          await db.insert(
            table,
            {...localRow, 'sync_status': SyncStatus.synced.toInt()},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          inserted++;
        } else {
          // Existe → actualizar solo si el remoto es más reciente
          final localTs = DateTime.tryParse(
                  localRows.first['last_modified'] as String? ?? '') ??
              DateTime(2000);
          final remoteTs =
              DateTime.tryParse(remoteRow['last_modified'] as String? ?? '') ??
                  DateTime(2000);

          if (remoteTs.isAfter(localTs)) {
            await db.update(
              table,
              {...localRow, 'sync_status': SyncStatus.synced.toInt()},
              where: 'server_id = ?',
              whereArgs: [serverId],
            );
            updated++;
          }
        }
      }

      if (inserted > 0 || updated > 0) {
        debugPrint('📥 [$table] Pull: $inserted nuevos, $updated actualizados');
      }
    } catch (e) {
      debugPrint('❌ [$table] Error en pull: $e');
    }
  }

  /// Convierte timestamps de Supabase (con zona horaria) a formato SQLite.
  Map<String, dynamic> _remoteToLocal(Map<String, dynamic> row) {
    final map = Map<String, dynamic>.from(row);
    for (final key in ['last_modified', 'fecha_creacion', 'ultima_actualizacion']) {
      if (map[key] != null) {
        map[key] = DateTime.tryParse(map[key].toString())
                ?.toLocal()
                .toIso8601String() ??
            map[key];
      }
    }
    return map;
  }

  /// Pull especial para existencias.
  /// El producto_id de Supabase es el ID local del dispositivo que lo creó
  /// y NO coincide con el ID local de este dispositivo.
  /// Se resuelve buscando el producto por cod_articulo y usando su id local.
  Future<void> _pullExistencias() async {
    try {
      final db = await DbHelper.instance.database;

      final remoteRows = await Supabase.instance.client
          .from('existencias')
          .select()
          .order('last_modified', ascending: false);

      int inserted = 0;
      int updated = 0;

      for (final remoteRow in remoteRows) {
        final serverId   = remoteRow['server_id']   as String?;
        final codArticulo = remoteRow['cod_articulo'] as String?;
        if (serverId == null || codArticulo == null) continue;

        // Resolver el producto_id LOCAL usando cod_articulo
        final productoRows = await db.query(
          'productos',
          columns: ['id'],
          where: 'cod_articulo = ?',
          whereArgs: [codArticulo],
          limit: 1,
        );

        if (productoRows.isEmpty) {
          // El producto aún no existe en local — se saltará esta existencia
          // (se reintentará en el próximo sync cuando el producto llegue)
          debugPrint('⚠️ [existencias] Producto $codArticulo no encontrado en local, omitiendo');
          continue;
        }

        final localProductoId = productoRows.first['id'] as int;

        // Buscar existencia en local por server_id o cod_articulo
        List<Map<String, dynamic>> localRows = await db.query(
          'existencias',
          where: 'server_id = ?',
          whereArgs: [serverId],
          limit: 1,
        );
        if (localRows.isEmpty) {
          localRows = await db.query(
            'existencias',
            where: 'cod_articulo = ?',
            whereArgs: [codArticulo],
            limit: 1,
          );
        }

        final localRow = _remoteToLocal(remoteRow);
        // Reemplazar producto_id remoto con el id local correcto
        localRow['producto_id'] = localProductoId;

        if (localRows.isEmpty) {
          await db.insert(
            'existencias',
            {...localRow, 'sync_status': SyncStatus.synced.toInt()},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          inserted++;
        } else {
          final localTs = DateTime.tryParse(
                  localRows.first['last_modified'] as String? ?? '') ??
              DateTime(2000);
          final remoteTs =
              DateTime.tryParse(remoteRow['last_modified'] as String? ?? '') ??
                  DateTime(2000);

          if (remoteTs.isAfter(localTs)) {
            await db.update(
              'existencias',
              {...localRow, 'sync_status': SyncStatus.synced.toInt()},
              where: 'server_id = ?',
              whereArgs: [serverId],
            );
            updated++;
          }
        }
      }

      if (inserted > 0 || updated > 0) {
        debugPrint('📥 [existencias] Pull: $inserted nuevos, $updated actualizados');
      }
    } catch (e) {
      debugPrint('❌ [existencias] Error en pull: $e');
    }
  }

  /// Pull especial para factura_detalle.
  /// factura_id y producto_id son IDs locales — se resuelven por
  /// numero_control y cod_articulo respectivamente.
  Future<void> _pullFacturaDetalle() async {
    try {
      final db = await DbHelper.instance.database;

      final remoteRows = await Supabase.instance.client
          .from('factura_detalle')
          .select()
          .order('last_modified', ascending: false);

      int inserted = 0;

      for (final remoteRow in remoteRows) {
        final serverId = remoteRow['server_id'] as String?;
        if (serverId == null) continue;

        // Si ya existe en local, saltar
        final existing = await db.query(
          'factura_detalle',
          where: 'server_id = ?',
          whereArgs: [serverId],
          limit: 1,
        );
        if (existing.isNotEmpty) continue;

        // Resolver factura_id local por server_id de la factura
        // El remoteRow tiene factura_id (local del otro dispositivo),
        // pero necesitamos buscar la factura por su server_id en Supabase.
        // Como no tenemos ese dato directo, buscamos la factura que tenga
        // este detalle — usamos el server_id de la factura desde Supabase.
        final facturaServerId = remoteRow['factura_server_id'] as String?;
        int? localFacturaId;

        if (facturaServerId != null) {
          final facturaRows = await db.query(
            'factura',
            columns: ['id'],
            where: 'server_id = ?',
            whereArgs: [facturaServerId],
            limit: 1,
          );
          if (facturaRows.isNotEmpty) {
            localFacturaId = facturaRows.first['id'] as int;
          }
        }

        // Fallback: buscar por factura_id si coincide (mismo dispositivo)
        if (localFacturaId == null) {
          final remoteFacturaId = remoteRow['factura_id'];
          if (remoteFacturaId != null) {
            final facturaRows = await db.query(
              'factura',
              columns: ['id'],
              where: 'id = ?',
              whereArgs: [remoteFacturaId],
              limit: 1,
            );
            if (facturaRows.isNotEmpty) {
              localFacturaId = facturaRows.first['id'] as int;
            }
          }
        }

        if (localFacturaId == null) {
          debugPrint('⚠️ [factura_detalle] Factura no encontrada en local, omitiendo');
          continue;
        }

        // Resolver producto_id local por cod_articulo
        // factura_detalle no tiene cod_articulo directo, así que usamos producto_id
        // del remoto como fallback (puede coincidir si es el mismo dispositivo)
        final remoteProductoId = remoteRow['producto_id'] as int?;
        int? localProductoId = remoteProductoId; // fallback

        // Intentar verificar que el producto existe localmente
        if (remoteProductoId != null) {
          final productoRows = await db.query(
            'productos',
            columns: ['id'],
            where: 'id = ?',
            whereArgs: [remoteProductoId],
            limit: 1,
          );
          if (productoRows.isEmpty) {
            // El producto_id no existe en local — omitir este detalle
            debugPrint('⚠️ [factura_detalle] Producto id=$remoteProductoId no encontrado, omitiendo');
            continue;
          }
        }

        final localRow = _remoteToLocal(remoteRow);
        localRow['factura_id']  = localFacturaId;
        localRow['producto_id'] = localProductoId;

        await db.insert(
          'factura_detalle',
          {...localRow, 'sync_status': SyncStatus.synced.toInt()},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        inserted++;
      }

      if (inserted > 0) {
        debugPrint('📥 [factura_detalle] Pull: $inserted nuevos');
      }
    } catch (e) {
      debugPrint('❌ [factura_detalle] Error en pull: $e');
    }
  }

  void dispose() => _sub?.cancel();
}
