import 'package:sqflite/sqflite.dart';
import 'package:flutter/material.dart';
import '../models/nota_credito.dart';
import '../models/nota_credito_detalle.dart';
import '../models/nota_credito_motivo.dart';
import 'db_helper.dart';
import '../sync/enums/sync_status.dart';

/// Data Access Object para operaciones de Notas de Crédito
class NotaCreditoDao {
  final DbHelper _dbHelper;

  NotaCreditoDao(this._dbHelper);

  /// Obtener instancia de la base de datos
  Future<Database> get _database async => await _dbHelper.database;

  // ===========================================================================
  // OPERACIONES PARA NOTA_CREDITO
  // ===========================================================================

  /// Crear una nueva nota de crédito
  Future<int> crearNotaCredito(NotaCredito notaCredito) async {
    final db = await _database;
    
    try {
      int insertedId = 0;
      
      // Iniciar transacción
      await db.transaction((txn) async {
        // 1. Insertar nota de crédito
        insertedId = await txn.insert(
          'nota_credito',
          notaCredito.toLocalMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        
        debugPrint('✅ Nota de crédito creada con ID: $insertedId');
        
        // La relación factura ↔ nota_credito se valida consultando
        // directamente la tabla nota_credito (método facturaTieneNotaCredito),
        // por lo que no es necesario un campo redundante en factura.
      });
      
      return insertedId;
    } catch (e) {
      debugPrint('❌ Error creando nota de crédito: $e');
      rethrow;
    }
  }

  /// Obtener nota de crédito por ID
  Future<NotaCredito?> obtenerNotaCreditoPorId(int id) async {
    final db = await _database;
    
    try {
      final results = await db.query(
        'nota_credito',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      
      if (results.isNotEmpty) {
        return NotaCredito.fromMap(results.first);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error obteniendo nota de crédito por ID: $e');
      return null;
    }
  }

  /// Obtener nota de crédito por número de control
  Future<NotaCredito?> obtenerNotaCreditoPorNumeroControl(String numeroControl) async {
    final db = await _database;
    
    try {
      final results = await db.query(
        'nota_credito',
        where: 'numero_control = ?',
        whereArgs: [numeroControl],
        limit: 1,
      );
      
      if (results.isNotEmpty) {
        return NotaCredito.fromMap(results.first);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error obteniendo nota de crédito por número de control: $e');
      return null;
    }
  }

  /// Obtener todas las notas de crédito
  Future<List<NotaCredito>> obtenerTodasNotasCredito({
    int? limit,
    int? offset,
    String? estado,
    String? tipo,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
  }) async {
    final db = await _database;
    
    try {
      final where = <String>[];
      final whereArgs = <dynamic>[];
      
      if (estado != null) {
        where.add('estado = ?');
        whereArgs.add(estado);
      }
      
      if (tipo != null) {
        where.add('tipo = ?');
        whereArgs.add(tipo);
      }
      
      if (fechaDesde != null) {
        where.add('fecha_emision >= ?');
        whereArgs.add(fechaDesde.toIso8601String());
      }
      
      if (fechaHasta != null) {
        where.add('fecha_emision <= ?');
        whereArgs.add(fechaHasta.toIso8601String());
      }
      
      final whereClause = where.isNotEmpty ? where.join(' AND ') : null;
      
      final results = await db.query(
        'nota_credito',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'fecha_emision DESC, id DESC',
        limit: limit,
        offset: offset,
      );
      
      return results.map((map) => NotaCredito.fromMap(map)).toList();
    } catch (e) {
      debugPrint('❌ Error obteniendo notas de crédito: $e');
      return [];
    }
  }

  /// Obtener notas de crédito por factura
  Future<List<NotaCredito>> obtenerNotasCreditoPorFactura(int facturaId) async {
    final db = await _database;
    
    try {
      final results = await db.query(
        'nota_credito',
        where: 'factura_id = ?',
        whereArgs: [facturaId],
        orderBy: 'fecha_emision DESC',
      );
      
      return results.map((map) => NotaCredito.fromMap(map)).toList();
    } catch (e) {
      debugPrint('❌ Error obteniendo notas de crédito por factura: $e');
      return [];
    }
  }

  /// Actualizar nota de crédito
  Future<int> actualizarNotaCredito(NotaCredito notaCredito) async {
    final db = await _database;
    
    try {
      if (notaCredito.id == null) {
        throw Exception('No se puede actualizar una nota de crédito sin ID');
      }
      
      final updated = await db.update(
        'nota_credito',
        notaCredito.toLocalMap(),
        where: 'id = ?',
        whereArgs: [notaCredito.id],
      );
      
      if (updated > 0) {
        debugPrint('✅ Nota de crédito ${notaCredito.id} actualizada');
      }
      
      return updated;
    } catch (e) {
      debugPrint('❌ Error actualizando nota de crédito: $e');
      rethrow;
    }
  }

  /// Marcar nota de crédito como procesada
  Future<int> marcarComoProcesada(int notaCreditoId, {DatabaseExecutor? txn}) async {
    final executor = txn ?? await _database;
    
    try {
      final updated = await executor.update(
        'nota_credito',
        {
          'estado': 'procesada',
          'sync_status': SyncStatus.pendingUpdate.toInt(),
          'updated_at': DateTime.now().toIso8601String(),
          'last_modified': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND estado = ?',
        whereArgs: [notaCreditoId, 'pendiente'],
      );
      
      if (updated > 0) {
        debugPrint('✅ Nota de crédito $notaCreditoId marcada como procesada');
      }
      
      return updated;
    } catch (e) {
      debugPrint('❌ Error marcando nota de crédito como procesada: $e');
      rethrow;
    }
  }

  /// Anular nota de crédito
  Future<int> anularNotaCredito({
    required int notaCreditoId,
    required String motivo,
    required int usuarioId,
  }) async {
    final db = await _database;
    
    try {
      final updated = await db.update(
        'nota_credito',
        {
          'estado': 'anulada',
          'fecha_anulacion': DateTime.now().toIso8601String(),
          'motivo_anulacion': motivo,
          'usuario_anulacion_id': usuarioId,
          'updated_at': DateTime.now().toIso8601String(),
          'last_modified': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND estado = ?',
        whereArgs: [notaCreditoId, 'pendiente'],
      );
      
      if (updated > 0) {
        debugPrint('✅ Nota de crédito $notaCreditoId anulada');
      }
      
      return updated;
    } catch (e) {
      debugPrint('❌ Error anulando nota de crédito: $e');
      rethrow;
    }
  }

  /// Eliminar nota de crédito (solo si está pendiente)
  Future<int> eliminarNotaCredito(int id) async {
    final db = await _database;
    
    try {
      // 1. Obtener estado actual
      final nc = await obtenerNotaCreditoPorId(id);
      if (nc == null) return 0;
      
      // 2. Proteger contra borrado si ya está procesada
      if (nc.estaProcesada) {
        throw Exception('No se puede eliminar una nota de crédito procesada.');
      }
      
      final deleted = await db.delete(
        'nota_credito',
        where: 'id = ? AND estado = ?',
        whereArgs: [id, 'pendiente'],
      );
      
      if (deleted > 0) {
        debugPrint('✅ Nota de crédito $id eliminada');
        
        // También eliminar detalles automáticamente (ON DELETE CASCADE)
      }
      
      return deleted;
    } catch (e) {
      debugPrint('❌ Error eliminando nota de crédito: $e');
      rethrow;
    }
  }

  /// Generar número de control estándar de 6 dígitos: 000000
  Future<String> generarNumeroControl() async {
    final db = await _database;

    try {
      final resultCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM nota_credito'
      );

      final count = Sqflite.firstIntValue(resultCount) ?? 0;
      final secuencia = (count + 1).toString().padLeft(6, '0');
      return secuencia;

    } catch (e) {
      debugPrint('❌ Error generando número de control: $e');
      rethrow;
    }
  }
  // ===========================================================================
  // OPERACIONES PARA NOTA_CREDITO_DETALLE
  // ===========================================================================

  /// Crear detalle de nota de crédito
  Future<int> crearNotaCreditoDetalle(NotaCreditoDetalle detalle) async {
    final db = await _database;
    
    try {
      final id = await db.insert(
        'nota_credito_detalle',
        detalle.toLocalMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      debugPrint('✅ Detalle de nota de crédito creado con ID: $id');
      return id;
    } catch (e) {
      debugPrint('❌ Error creando detalle de nota de crédito: $e');
      rethrow;
    }
  }

  /// Crear múltiples detalles de nota de crédito
  Future<void> crearMultiplesDetalles(List<NotaCreditoDetalle> detalles) async {
    final db = await _database;
    
    try {
      await db.transaction((txn) async {
        for (final detalle in detalles) {
          await txn.insert(
            'nota_credito_detalle',
            detalle.toLocalMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
      
      debugPrint('✅ ${detalles.length} detalles de nota de crédito creados');
    } catch (e) {
      debugPrint('❌ Error creando múltiples detalles: $e');
      rethrow;
    }
  }

  /// Obtener detalles de una nota de crédito
  Future<List<NotaCreditoDetalle>> obtenerDetallesPorNotaCredito(int notaCreditoId) async {
    final db = await _database;
    
    try {
      final results = await db.query(
        'nota_credito_detalle',
        where: 'nota_credito_id = ?',
        whereArgs: [notaCreditoId],
        orderBy: 'id ASC',
      );
      
      return results.map((map) => NotaCreditoDetalle.fromMap(map)).toList();
    } catch (e) {
      debugPrint('❌ Error obteniendo detalles de nota de crédito: $e');
      return [];
    }
  }

  /// Obtener detalles con información del producto
  Future<List<Map<String, dynamic>>> obtenerDetallesConProducto(int notaCreditoId) async {
    final db = await _database;
    
    try {
      final results = await db.rawQuery('''
        SELECT 
          d.id,
          d.nota_credito_id,
          d.producto_id,
          d.cantidad,
          d.precio_unitario,
          d.subtotal,
          d.lote,
          d.serial,
          d.fecha_vencimiento,
          p.cod_articulo,
          p.nombre as producto_nombre,
          p.unidad_medida
        FROM nota_credito_detalle d
        INNER JOIN productos p ON d.producto_id = p.id
        WHERE d.nota_credito_id = ?
        ORDER BY d.id ASC
      ''', [notaCreditoId]);
      
      return results;
    } catch (e) {
      debugPrint('❌ Error obteniendo detalles con producto: $e');
      return [];
    }
  }

  /// Eliminar detalles de una nota de crédito
  Future<int> eliminarDetallesPorNotaCredito(int notaCreditoId) async {
    final db = await _database;
    
    try {
      final deleted = await db.delete(
        'nota_credito_detalle',
        where: 'nota_credito_id = ?',
        whereArgs: [notaCreditoId],
      );
      
      if (deleted > 0) {
        debugPrint('✅ $deleted detalles eliminados de nota de crédito $notaCreditoId');
      }
      
      return deleted;
    } catch (e) {
      debugPrint('❌ Error eliminando detalles de nota de crédito: $e');
      rethrow;
    }
  }

  // ===========================================================================
  // OPERACIONES PARA NOTA_CREDITO_MOTIVO
  // ===========================================================================

  /// Obtener todos los motivos
  Future<List<NotaCreditoMotivo>> obtenerTodosMotivos({bool soloActivos = true}) async {
    final db = await _database;
    
    try {
      final where = soloActivos ? 'activo = 1' : null;
      final results = await db.query(
        'nota_credito_motivo',
        where: where,
        orderBy: 'tipo ASC, descripcion ASC',
      );
      
      return results.map((map) => NotaCreditoMotivo.fromMap(map)).toList();
    } catch (e) {
      debugPrint('❌ Error obteniendo motivos: $e');
      return [];
    }
  }

  /// Obtener motivos por tipo
  Future<List<NotaCreditoMotivo>> obtenerMotivosPorTipo(String tipo) async {
    final db = await _database;
    
    try {
      final results = await db.query(
        'nota_credito_motivo',
        where: 'tipo IN (?, ?) AND activo = 1',
        whereArgs: [tipo, 'ambos'],
        orderBy: 'descripcion ASC',
      );
      
      return results.map((map) => NotaCreditoMotivo.fromMap(map)).toList();
    } catch (e) {
      debugPrint('❌ Error obteniendo motivos por tipo: $e');
      return [];
    }
  }

  /// Obtener motivo por código
  Future<NotaCreditoMotivo?> obtenerMotivoPorCodigo(String codigo) async {
    final db = await _database;
    
    try {
      final results = await db.query(
        'nota_credito_motivo',
        where: 'codigo = ?',
        whereArgs: [codigo],
        limit: 1,
      );
      
      if (results.isNotEmpty) {
        return NotaCreditoMotivo.fromMap(results.first);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error obteniendo motivo por código: $e');
      return null;
    }
  }

  /// Crear nuevo motivo
  Future<int> crearMotivo(NotaCreditoMotivo motivo) async {
    final db = await _database;
    
    try {
      final id = await db.insert(
        'nota_credito_motivo',
        motivo.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      debugPrint('✅ Motivo de nota de crédito creado con ID: $id');
      return id;
    } catch (e) {
      debugPrint('❌ Error creando motivo: $e');
      rethrow;
    }
  }

  /// Actualizar motivo
  Future<int> actualizarMotivo(NotaCreditoMotivo motivo) async {
    final db = await _database;
    
    try {
      if (motivo.id == null) {
        throw Exception('No se puede actualizar un motivo sin ID');
      }
      
      final updated = await db.update(
        'nota_credito_motivo',
        motivo.toMap(),
        where: 'id = ?',
        whereArgs: [motivo.id],
      );
      
      if (updated > 0) {
        debugPrint('✅ Motivo ${motivo.id} actualizado');
      }
      
      return updated;
    } catch (e) {
      debugPrint('❌ Error actualizando motivo: $e');
      rethrow;
    }
  }

  // ===========================================================================
  // OPERACIONES DE CONSULTA Y REPORTES
  // ===========================================================================

  /// Obtener estadísticas de notas de crédito
  Future<Map<String, dynamic>> obtenerEstadisticas({
    DateTime? fechaDesde,
    DateTime? fechaHasta,
  }) async {
    final db = await _database;
    
    try {
      final where = <String>[];
      final whereArgs = <dynamic>[];
      
      if (fechaDesde != null) {
        where.add('fecha_emision >= ?');
        whereArgs.add(fechaDesde.toIso8601String());
      }
      
      if (fechaHasta != null) {
        where.add('fecha_emision <= ?');
        whereArgs.add(fechaHasta.toIso8601String());
      }
      
      final whereClause = where.isNotEmpty ? where.join(' AND ') : '1=1';
      
      // Consulta para totales
      final totalesResult = await db.rawQuery('''
        SELECT 
          COUNT(*) as total_notas,
          SUM(monto_total) as total_monto,
          SUM(iva) as total_iva,
          SUM(monto_total + iva) as total_general,
          COUNT(CASE WHEN tipo = 'total' THEN 1 END) as totales,
          COUNT(CASE WHEN tipo = 'parcial' THEN 1 END) as parciales,
          COUNT(CASE WHEN estado = 'pendiente' THEN 1 END) as pendientes,
          COUNT(CASE WHEN estado = 'procesada' THEN 1 END) as procesadas,
          COUNT(CASE WHEN estado = 'anulada' THEN 1 END) as anuladas
        FROM nota_credito
        WHERE $whereClause
      ''', whereArgs);
      
      // Consulta para top motivos
      final motivosResult = await db.rawQuery('''
        SELECT 
          motivo,
          COUNT(*) as cantidad,
          SUM(monto_total + iva) as monto_total
        FROM nota_credito
        WHERE $whereClause
        GROUP BY motivo
        ORDER BY cantidad DESC
        LIMIT 5
      ''', whereArgs);
      
      final totales = totalesResult.isNotEmpty ? totalesResult.first : {};
      
      return {
        'totales': totales,
        'top_motivos': motivosResult,
      };
    } catch (e) {
      debugPrint('❌ Error obteniendo estadísticas: $e');
      return {
        'totales': {},
        'top_motivos': [],
      };
    }
  }

  /// Verificar si una factura tiene notas de crédito
  Future<bool> facturaTieneNotaCredito(int facturaId) async {
    final db = await _database;
    
    try {
      final result = await db.rawQuery('''
        SELECT COUNT(*) as count 
        FROM nota_credito 
        WHERE factura_id = ? 
          AND estado IN ('pendiente', 'procesada')
      ''', [facturaId]);
      
      final count = (result.first['count'] as int?) ?? 0;
      return count > 0;
    } catch (e) {
      debugPrint('❌ Error verificando si factura tiene nota de crédito: $e');
      return false;
    }
  }

  /// Obtener monto total devuelto por factura
  Future<double> obtenerMontoDevueltoPorFactura(int facturaId) async {
    final db = await _database;
    
    try {
      final result = await db.rawQuery('''
        SELECT COALESCE(SUM(monto_total + iva), 0) as total_devuelto
        FROM nota_credito
        WHERE factura_id = ? 
          AND estado IN ('pendiente', 'procesada')
      ''', [facturaId]);
      
      return (result.first['total_devuelto'] as double?) ?? 0.0;
    } catch (e) {
      debugPrint('❌ Error obteniendo monto devuelto por factura: $e');
      return 0.0;
    }
  }

  /// Obtener productos devueltos por factura
  Future<List<Map<String, dynamic>>> obtenerProductosDevueltosPorFactura(int facturaId) async {
    final db = await _database;
    
    try {
      final result = await db.rawQuery('''
        SELECT 
          p.id as producto_id,
          p.cod_articulo,
          p.nombre as producto_nombre,
          SUM(d.cantidad) as cantidad_total_devuelta,
          d.precio_unitario,
          SUM(d.subtotal) as subtotal_total
        FROM nota_credito n
        INNER JOIN nota_credito_detalle d ON n.id = d.nota_credito_id
        INNER JOIN productos p ON d.producto_id = p.id
        WHERE n.factura_id = ? 
          AND n.estado IN ('pendiente', 'procesada')
        GROUP BY p.id, d.precio_unitario
        ORDER BY p.nombre ASC
      ''', [facturaId]);
      
      return result;
    } catch (e) {
      debugPrint('❌ Error obteniendo productos devueltos: $e');
      return [];
    }
  }
}