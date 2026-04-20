import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/connectivity_service.dart';
import '../enums/sync_status.dart';
import '../../DATABASE/db_helper.dart';

/// Servicio que dispara la sincronización con Supabase
/// DESPUÉS de que DbHelper ya guardó en SQLite.
///
/// Estrategia: SQLite es la fuente de verdad. Supabase es el espejo.
/// Cada operación local exitosa llama a SyncTrigger para replicarla
/// en la nube de forma asíncrona (no bloquea la UI).
class SyncTrigger {
  static final SyncTrigger instance = SyncTrigger._();
  SyncTrigger._();

  SupabaseClient get _sb => Supabase.instance.client;
  bool get _online => ConnectivityService.instance.isOnline;

  // ─────────────────────────────────────────────────────────────────────────
  // PRODUCTOS
  // ─────────────────────────────────────────────────────────────────────────

  /// Llama esto justo después de DbHelper.crearProducto()
  Future<void> onProductoCreado(int localId) async {
    if (!_online) {
      await _markPending('productos', localId, SyncStatus.pendingUpload);
      return;
    }
    await _upsertFromLocal('productos', localId, uniqueCol: 'cod_articulo');
  }

  /// Llama esto justo después de DbHelper.actualizarProducto()
  Future<void> onProductoActualizado(int localId) async {
    if (!_online) {
      await _markPending('productos', localId, SyncStatus.pendingUpdate);
      return;
    }
    await _upsertFromLocal('productos', localId, uniqueCol: 'cod_articulo');
  }

  /// Llama esto justo después de DbHelper.eliminarProducto()
  Future<void> onProductoEliminado(String codArticulo) async {
    if (!_online) return;
    try {
      // 1. Borrar existencia primero (no hay CASCADE en Supabase)
      await _sb.from('existencias').delete().eq('cod_articulo', codArticulo);
      debugPrint('🗑️ [existencias] Eliminada en Supabase: $codArticulo');

      // 2. Borrar producto
      await _sb.from('productos').delete().eq('cod_articulo', codArticulo);
      debugPrint('🗑️ [productos] Eliminado en Supabase: $codArticulo');
    } catch (e) {
      debugPrint('❌ [productos] Error eliminando en Supabase: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EXISTENCIAS
  // ─────────────────────────────────────────────────────────────────────────

  /// Llama esto después de crear o actualizar stock de un producto
  Future<void> onExistenciaActualizada(int productoId) async {
    if (!_online) {
      await _markPendingWhere(
          'existencias', 'producto_id = ?', [productoId], SyncStatus.pendingUpdate);
      return;
    }
    await _upsertExistenciaByProductoId(productoId);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CLIENTES
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> onClienteCreado(int localId) async {
    if (!_online) {
      await _markPending('clientes', localId, SyncStatus.pendingUpload);
      return;
    }
    await _upsertFromLocal('clientes', localId, uniqueCol: 'identificacion');
  }

  Future<void> onClienteActualizado(int localId) async {
    if (!_online) {
      await _markPending('clientes', localId, SyncStatus.pendingUpdate);
      return;
    }
    await _upsertFromLocal('clientes', localId, uniqueCol: 'identificacion');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FACTURAS (cabecera + detalles + stock en una sola llamada)
  // ─────────────────────────────────────────────────────────────────────────

  /// Llama esto justo después de DbHelper.crearFactura()
  Future<void> onFacturaCreada(int facturaId) async {
    if (!_online) {
      await _markPending('factura', facturaId, SyncStatus.pendingUpload);
      // Marcar detalles también
      await _markPendingWhere(
          'factura_detalle', 'factura_id = ?', [facturaId], SyncStatus.pendingUpload);
      return;
    }
    await _sincronizarFacturaCompleta(facturaId);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CIERRES DE LOTE
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> onCierreLoteCreado(int localId) async {
    if (!_online) {
      await _markPending('cierres_lote', localId, SyncStatus.pendingUpload);
      return;
    }
    await _upsertFromLocal('cierres_lote', localId);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SYNC PENDIENTES — llamado por SyncManager al recuperar conexión
  // ─────────────────────────────────────────────────────────────────────────

  /// Sube todos los registros marcados como pendientes en todas las tablas.
  Future<void> pushAllPending() async {
    if (!_online) return;
    debugPrint('⬆️ SyncTrigger: subiendo todos los pendientes...');

    await _pushPendingTable('usuarios',       uniqueCol: 'usuario');
    await _pushPendingTable('clientes',       uniqueCol: 'identificacion');
    await _pushPendingTable('productos',      uniqueCol: 'cod_articulo');
    await _pushPendingExistencias();
    await _pushPendingFacturas();
    await _pushPendingTable('factura_detalle');
    await _pushPendingTable('cierres_lote');

    debugPrint('✅ SyncTrigger: push de pendientes completado');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS PRIVADOS
  // ─────────────────────────────────────────────────────────────────────────

  /// Lee una fila de SQLite y la hace upsert en Supabase.
  /// [uniqueCol] es la columna de negocio única (para el ON CONFLICT).
  Future<void> _upsertFromLocal(String table, int localId,
      {String? uniqueCol}) async {
    try {
      final db = await DbHelper.instance.database;
      final rows = await db.query(table, where: 'id = ?', whereArgs: [localId]);
      if (rows.isEmpty) return;

      final row = _toRemoteRow(rows.first);

      // INSERT con select para obtener el server_id generado por Supabase
      final response = await _sb
          .from(table)
          .upsert(row, onConflict: uniqueCol)
          .select('server_id')
          .single();

      final serverId = response['server_id'] as String?;

      if (serverId != null) {
        await db.update(
          table,
          {
            'server_id': serverId,
            'sync_status': SyncStatus.synced.toInt(),
            'last_modified': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [localId],
        );
      }

      debugPrint('☁️ [$table] Sincronizado id=$localId → server_id=$serverId');
    } catch (e) {
      debugPrint('❌ [$table] Error sync id=$localId: $e');
      await _markPending(table, localId, SyncStatus.pendingUpdate);
    }
  }

  /// Upsert de existencia usando cod_articulo como clave única en Supabase.
  Future<void> _upsertExistenciaByProductoId(int productoId) async {
    try {
      final db = await DbHelper.instance.database;
      final rows = await db.query('existencias',
          where: 'producto_id = ?', whereArgs: [productoId], limit: 1);
      if (rows.isEmpty) return;

      final row = _toRemoteRow(rows.first);

      final response = await _sb
          .from('existencias')
          .upsert(row, onConflict: 'cod_articulo')
          .select('server_id')
          .single();

      final serverId = response['server_id'] as String?;

      await db.update(
        'existencias',
        {
          if (serverId != null) 'server_id': serverId,
          'sync_status': SyncStatus.synced.toInt(),
          'last_modified': DateTime.now().toIso8601String(),
        },
        where: 'producto_id = ?',
        whereArgs: [productoId],
      );

      debugPrint('☁️ [existencias] Stock sincronizado producto_id=$productoId → server_id=$serverId');
    } catch (e) {
      debugPrint('❌ [existencias] Error sync stock: $e');
    }
  }

  /// Sincroniza factura cabecera + todos sus detalles + stock actualizado.
  Future<void> _sincronizarFacturaCompleta(int facturaId) async {
    try {
      final db = await DbHelper.instance.database;

      // 1. Cabecera
      final facturas =
          await db.query('factura', where: 'id = ?', whereArgs: [facturaId]);
      if (facturas.isEmpty) return;

      final facturaRow = _toRemoteRow(facturas.first);
      final facturaResp = await _sb
          .from('factura')
          .upsert(facturaRow, onConflict: 'numero_control')
          .select('server_id')
          .single();

      final facturaServerId = facturaResp['server_id'] as String?;

      await db.update(
        'factura',
        {
          if (facturaServerId != null) 'server_id': facturaServerId,
          'sync_status': SyncStatus.synced.toInt(),
          'last_modified': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [facturaId],
      );

      // 2. Detalles
      final detalles = await db.query('factura_detalle',
          where: 'factura_id = ?', whereArgs: [facturaId]);

      for (final detalle in detalles) {
        // Solo insertar si aún no tiene server_id (evita duplicados)
        if (detalle['server_id'] != null) continue;

        final detalleRow = _toRemoteRow(detalle);
        final detalleResp = await _sb
            .from('factura_detalle')
            .insert(detalleRow)
            .select('server_id')
            .single();

        final detalleServerId = detalleResp['server_id'] as String?;

        await db.update(
          'factura_detalle',
          {
            if (detalleServerId != null) 'server_id': detalleServerId,
            'sync_status': SyncStatus.synced.toInt(),
            'last_modified': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [detalle['id']],
        );
      }

      // 3. Stock de cada producto vendido
      for (final detalle in detalles) {
        final productoId = detalle['producto_id'] as int;
        await _upsertExistenciaByProductoId(productoId);
      }

      debugPrint('☁️ [factura] Factura $facturaId sincronizada completa');
    } catch (e) {
      debugPrint('❌ [factura] Error sync factura $facturaId: $e');
      await _markPending('factura', facturaId, SyncStatus.pendingUpdate);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUSH PENDIENTES POR TABLA
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _pushPendingTable(String table, {String? uniqueCol}) async {
    try {
      final db = await DbHelper.instance.database;
      final pending = await db.query(
        table,
        where: 'sync_status IN (?, ?)',
        whereArgs: [
          SyncStatus.pendingUpload.toInt(),
          SyncStatus.pendingUpdate.toInt()
        ],
      );

      for (final row in pending) {
        final localId = row['id'] as int;
        await _upsertFromLocal(table, localId, uniqueCol: uniqueCol);
      }
    } catch (e) {
      debugPrint('❌ [$table] Error push pendientes: $e');
    }
  }

  Future<void> _pushPendingExistencias() async {
    try {
      final db = await DbHelper.instance.database;
      final pending = await db.query(
        'existencias',
        where: 'sync_status IN (?, ?)',
        whereArgs: [
          SyncStatus.pendingUpload.toInt(),
          SyncStatus.pendingUpdate.toInt()
        ],
      );
      for (final row in pending) {
        await _upsertExistenciaByProductoId(row['producto_id'] as int);
      }
    } catch (e) {
      debugPrint('❌ [existencias] Error push pendientes: $e');
    }
  }

  Future<void> _pushPendingFacturas() async {
    try {
      final db = await DbHelper.instance.database;
      final pending = await db.query(
        'factura',
        where: 'sync_status IN (?, ?)',
        whereArgs: [
          SyncStatus.pendingUpload.toInt(),
          SyncStatus.pendingUpdate.toInt()
        ],
      );
      for (final row in pending) {
        await _sincronizarFacturaCompleta(row['id'] as int);
      }
    } catch (e) {
      debugPrint('❌ [factura] Error push pendientes: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UTILIDADES
  // ─────────────────────────────────────────────────────────────────────────

  /// Convierte una fila de SQLite al mapa que se envía a Supabase.
  /// Elimina campos que son solo locales: id, sync_status, server_id (null).
  /// Si server_id ya tiene valor (UUID previo), lo conserva para el upsert.
  Map<String, dynamic> _toRemoteRow(Map<String, dynamic> row) {
    final map = Map<String, dynamic>.from(row);
    map.remove('id');          // PK local autoincrement — no existe en Supabase
    map.remove('sync_status'); // campo solo local
    // Si server_id es null, lo eliminamos para que Supabase lo genere con DEFAULT
    if (map['server_id'] == null) {
      map.remove('server_id');
    }
    return map;
  }

  /// Marca un registro como pendiente de sincronización.
  Future<void> _markPending(
      String table, int localId, SyncStatus status) async {
    try {
      final db = await DbHelper.instance.database;
      await db.update(
        table,
        {
          'sync_status': status.toInt(),
          'last_modified': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [localId],
      );
    } catch (_) {}
  }

  /// Marca registros por condición WHERE como pendientes.
  Future<void> _markPendingWhere(String table, String where,
      List<dynamic> whereArgs, SyncStatus status) async {
    try {
      final db = await DbHelper.instance.database;
      await db.update(
        table,
        {
          'sync_status': status.toInt(),
          'last_modified': DateTime.now().toIso8601String(),
        },
        where: where,
        whereArgs: whereArgs,
      );
    } catch (_) {}
  }
}
