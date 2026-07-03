import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:pos_android/database/db_helper.dart';
import 'package:pos_android/database/nota_credito_dao.dart';
import 'package:pos_android/models/nota_credito.dart';
import 'package:pos_android/models/nota_credito_detalle.dart';
import 'package:pos_android/sync/enums/sync_status.dart';

/// Servicio de lógica de negocio para Notas de Crédito
class NotaCreditoService {
  final NotaCreditoDao _dao;
  final DbHelper _dbHelper;

  NotaCreditoService(this._dbHelper) : _dao = NotaCreditoDao(_dbHelper);

  // ===========================================================================
  // VALIDACIONES Y REGLAS DE NEGOCIO
  // ===========================================================================

  /// Validar si una factura puede tener nota de crédito
  Future<Map<String, dynamic>> validarFacturaParaNotaCredito(int facturaId) async {
    try {
      final db = await _dbHelper.database;
      
      // 1. Verificar que la factura existe
      final factura = await db.query(
        'factura',
        where: 'id = ?',
        whereArgs: [facturaId],
        limit: 1,
      );
      
      if (factura.isEmpty) {
        return {
          'valido': false,
          'mensaje': 'La factura no existe',
          'codigo': 'FACTURA_NO_EXISTE',
        };
      }
      
      // 2. Verificar que la factura no esté anulada
      final estado = factura.first['estado'] as String?;
      if (estado == 'cerrado' || estado == 'anulado') {
        return {
          'valido': false,
          'mensaje': 'La factura está cerrada o anulada',
          'codigo': 'FACTURA_CERRADA',
        };
      }
      
      // 3. Verificar si ya tiene notas de crédito pendientes/procesadas
      final tieneNotas = await _dao.facturaTieneNotaCredito(facturaId);
      if (tieneNotas) {
        return {
          'valido': false,
          'mensaje': 'La factura ya tiene notas de crédito asociadas',
          'codigo': 'YA_TIENE_NOTAS',
        };
      }
      
      // 4. Verificar fecha límite (máximo 30 días)
      final fechaCreacionStr = factura.first['fecha_creacion'] as String?;
      if (fechaCreacionStr != null) {
        final fechaCreacion = DateTime.parse(fechaCreacionStr);
        final diferencia = DateTime.now().difference(fechaCreacion);
        
        if (diferencia.inDays > 30) {
          return {
            'valido': false,
            'mensaje': 'La factura tiene más de 30 días de emitida',
            'codigo': 'FECHA_EXCEDIDA',
            'dias': diferencia.inDays,
          };
        }
      }
      
      return {
        'valido': true,
        'mensaje': 'La factura es válida para nota de crédito',
        'factura': factura.first,
      };
    } catch (e) {
      debugPrint('❌ Error validando factura: $e');
      return {
        'valido': false,
        'mensaje': 'Error validando factura: $e',
        'codigo': 'ERROR_VALIDACION',
      };
    }
  }

  /// Validar productos para nota de crédito parcial
  Future<Map<String, dynamic>> validarProductosParaNotaCredito(
    int facturaId,
    List<Map<String, dynamic>> productosSeleccionados,
  ) async {
    try {
      final db = await _dbHelper.database;
      
      // 1. Obtener detalles originales de la factura
      final detallesOriginales = await db.rawQuery('''
        SELECT 
          fd.producto_id,
          p.cod_articulo,
          p.nombre,
          fd.cantidad as cantidad_original,
          fd.precio_unitario,
          fd.subtotal
        FROM factura_detalle fd
        INNER JOIN productos p ON fd.producto_id = p.id
        WHERE fd.factura_id = ?
        ORDER BY fd.id ASC
      ''', [facturaId]);
      
      if (detallesOriginales.isEmpty) {
        return {
          'valido': false,
          'mensaje': 'La factura no tiene productos',
          'codigo': 'SIN_PRODUCTOS',
        };
      }
      
      // 2. Validar cada producto seleccionado
      final errores = <String>[];
      final productosValidos = <Map<String, dynamic>>[];
      double totalSeleccionado = 0.0;
      
      for (final producto in productosSeleccionados) {
        final productoId = producto['producto_id'] as int;
        final cantidadSeleccionada = (producto['cantidad'] as num).toDouble();
        
        // Buscar en detalles originales
        final detalleOriginal = detallesOriginales.firstWhere(
          (d) => d['producto_id'] == productoId,
          orElse: () => {},
        );
        
        if (detalleOriginal.isEmpty) {
          errores.add('Producto ID $productoId no existe en la factura original');
          continue;
        }
        
        final cantidadOriginal = (detalleOriginal['cantidad_original'] as num).toDouble();
        
        // Validar que la cantidad seleccionada no exceda la original
        if (cantidadSeleccionada > cantidadOriginal) {
          errores.add('Cantidad excede lo facturado para ${detalleOriginal['nombre']}');
          continue;
        }
        
        // Validar que la cantidad sea positiva
        if (cantidadSeleccionada <= 0) {
          errores.add('Cantidad debe ser mayor a 0 para ${detalleOriginal['nombre']}');
          continue;
        }
        
        // Calcular subtotal
        final precioUnitario = (detalleOriginal['precio_unitario'] as num).toDouble();
        final subtotal = cantidadSeleccionada * precioUnitario;
        
        productosValidos.add({
          'producto_id': productoId,
          'cod_articulo': detalleOriginal['cod_articulo'],
          'nombre': detalleOriginal['nombre'],
          'cantidad_original': cantidadOriginal,
          'cantidad_seleccionada': cantidadSeleccionada,
          'precio_unitario': precioUnitario,
          'subtotal': subtotal,
          'lote': producto['lote'],
          'serial': producto['serial'],
          'fecha_vencimiento': producto['fecha_vencimiento'],
        });
        
        totalSeleccionado += subtotal;
      }
      
      if (errores.isNotEmpty) {
        return {
          'valido': false,
          'mensaje': 'Errores en productos seleccionados',
          'codigo': 'ERROR_PRODUCTOS',
          'errores': errores,
        };
      }
      
      // 3. Validar monto total (no debe exceder total de factura)
      final factura = await db.query(
        'factura',
        columns: ['total'],
        where: 'id = ?',
        whereArgs: [facturaId],
        limit: 1,
      );
      
      if (factura.isNotEmpty) {
        final totalFactura = (factura.first['total'] as num).toDouble();
        
        if (totalSeleccionado > totalFactura) {
          return {
            'valido': false,
            'mensaje': 'El total seleccionado excede el total de la factura',
            'codigo': 'TOTAL_EXCEDIDO',
            'total_seleccionado': totalSeleccionado,
            'total_factura': totalFactura,
          };
        }
      }
      
      return {
        'valido': true,
        'mensaje': 'Productos válidos',
        'productos': productosValidos,
        'total_seleccionado': totalSeleccionado,
        'cantidad_productos': productosValidos.length,
      };
    } catch (e) {
      debugPrint('❌ Error validando productos: $e');
      return {
        'valido': false,
        'mensaje': 'Error validando productos: $e',
        'codigo': 'ERROR_VALIDACION',
      };
    }
  }

  // ===========================================================================
  // CREACIÓN DE NOTAS DE CRÉDITO
  // ===========================================================================

  /// Crear nota de crédito total
  Future<Map<String, dynamic>> crearNotaCreditoTotal({
    required int facturaId,
    required String motivo,
    required int usuarioId,
    String? observaciones,
  }) async {
    try {
      // 1. Validar factura
      final validacion = await validarFacturaParaNotaCredito(facturaId);
      if (!validacion['valido']) {
        return validacion;
      }
      
      final db = await _dbHelper.database;
      
      // 2. Obtener información de la factura
      final factura = await db.query(
        'factura',
        where: 'id = ?',
        whereArgs: [facturaId],
        limit: 1,
      );
      
      if (factura.isEmpty) {
        return {
          'valido': false,
          'mensaje': 'Factura no encontrada',
          'codigo': 'FACTURA_NO_ENCONTRADA',
        };
      }
      
      final facturaData = factura.first;
      final totalFactura = (facturaData['total'] as num).toDouble();
      final montoIva = (facturaData['monto_iva'] as num).toDouble();
      final baseImponible = totalFactura - montoIva;
      
      // 3. Generar número de control
      final numeroControl = await _dao.generarNumeroControl();
      
      // 4. Crear modelo de nota de crédito (directamente como procesada)
      final notaCredito = NotaCredito(
        numeroControl: numeroControl,
        tipo: 'total',
        facturaId: facturaId,
        motivo: motivo,
        montoTotal: baseImponible,
        iva: montoIva,
        fechaEmision: DateTime.now(),
        estado: 'procesada',
        usuarioId: usuarioId,
        observaciones: observaciones,
        syncStatus: SyncStatus.pendingUpload,
      );
      
      // 5. Guardar en base de datos
      await _dao.crearNotaCredito(notaCredito);
      
      // 6. Obtener detalles de la factura para crear detalles de nota de crédito
      final detallesFactura = await db.query(
        'factura_detalle',
        where: 'factura_id = ?',
        whereArgs: [facturaId],
      );
      
      final detallesNotaCredito = detallesFactura.map((detalle) {
        return NotaCreditoDetalle(
          notaCreditoId: 0, // Se actualizará después
          productoId: detalle['producto_id'] as int,
          cantidad: (detalle['cantidad'] as num).toDouble(),
          precioUnitario: (detalle['precio_unitario'] as num).toDouble(),
          subtotal: (detalle['subtotal'] as num).toDouble(),
          syncStatus: SyncStatus.pendingUpload,
        );
      }).toList();
      
      // 7. Obtener ID de la nota de crédito recién creada
      final notaCreada = await _dao.obtenerNotaCreditoPorNumeroControl(numeroControl);
      if (notaCreada == null) {
        return {
          'valido': false,
          'mensaje': 'Error obteniendo nota de crédito creada',
          'codigo': 'ERROR_OBTENIENDO_NOTA',
        };
      }
      
      // 8. Actualizar IDs de detalles y guardar
      for (final detalle in detallesNotaCredito) {
        await _dao.crearNotaCreditoDetalle(detalle.copyWith(
          notaCreditoId: notaCreada.id!,
        ));
      }
      
      // 9. Ajustar inventario automáticamente (NC se procesa al crearse)
      await db.transaction((txn) async {
        for (final detalle in detallesNotaCredito) {
          final existencia = await txn.query(
            'existencias',
            where: 'producto_id = ?',
            whereArgs: [detalle.productoId],
            limit: 1,
          );
          
          if (existencia.isNotEmpty) {
            final stockActual = (existencia.first['stock'] as num).toDouble();
            final nuevoStock = stockActual + detalle.cantidad;
            
            await txn.update(
              'existencias',
              {
                'stock': nuevoStock,
                'ultima_actualizacion': DateTime.now().toIso8601String(),
                'last_modified': DateTime.now().toIso8601String(),
                'sync_status': SyncStatus.pendingUpdate.toInt(),
              },
              where: 'producto_id = ?',
              whereArgs: [detalle.productoId],
            );
          }
        }
      });
      
      debugPrint('✅ Nota de crédito total creada y procesada: $numeroControl');
      debugPrint('   Factura: $facturaId');
      debugPrint('   Monto: $totalFactura');
      debugPrint('   Motivo: $motivo');
      
      return {
        'valido': true,
        'mensaje': 'Nota de crédito total creada y procesada exitosamente',
        'nota_credito': notaCreada,
        'numero_control': numeroControl,
        'detalles': detallesNotaCredito.length,
      };
    } catch (e) {
      debugPrint('❌ Error creando nota de crédito total: $e');
      return {
        'valido': false,
        'mensaje': 'Error creando nota de crédito total: $e',
        'codigo': 'ERROR_CREACION',
      };
    }
  }

  /// Crear nota de crédito parcial
  Future<Map<String, dynamic>> crearNotaCreditoParcial({
    required int facturaId,
    required String motivo,
    required int usuarioId,
    required List<Map<String, dynamic>> productos,
    String? observaciones,
  }) async {
    try {
      // 1. Validar factura
      final validacionFactura = await validarFacturaParaNotaCredito(facturaId);
      if (!validacionFactura['valido']) {
        return validacionFactura;
      }
      
      // 2. Validar productos
      final validacionProductos = await validarProductosParaNotaCredito(facturaId, productos);
      if (!validacionProductos['valido']) {
        return validacionProductos;
      }
      
      final productosValidos = validacionProductos['productos'] as List<Map<String, dynamic>>;
      final totalSeleccionado = (validacionProductos['total_seleccionado'] as num).toDouble();
      
      // 3. Calcular IVA (16% del subtotal)
      final iva = totalSeleccionado * 0.16;
      final baseImponible = totalSeleccionado - iva;
      
      // 4. Generar número de control
      final numeroControl = await _dao.generarNumeroControl();
      
      // 5. Crear modelo de nota de crédito (directamente como procesada)
      final notaCredito = NotaCredito(
        numeroControl: numeroControl,
        tipo: 'parcial',
        facturaId: facturaId,
        motivo: motivo,
        montoTotal: baseImponible,
        iva: iva,
        fechaEmision: DateTime.now(),
        estado: 'procesada',
        usuarioId: usuarioId,
        observaciones: observaciones,
        syncStatus: SyncStatus.pendingUpload,
      );
      
      // 6. Guardar nota de crédito
      await _dao.crearNotaCredito(notaCredito);
      
      // 7. Obtener ID de la nota de crédito recién creada
      final notaCreada = await _dao.obtenerNotaCreditoPorNumeroControl(numeroControl);
      if (notaCreada == null) {
        return {
          'valido': false,
          'mensaje': 'Error obteniendo nota de crédito creada',
          'codigo': 'ERROR_OBTENIENDO_NOTA',
        };
      }
      
      // 8. Crear detalles
      final detallesNotaCredito = productosValidos.map((producto) {
        return NotaCreditoDetalle(
          notaCreditoId: notaCreada.id!,
          productoId: producto['producto_id'] as int,
          cantidad: (producto['cantidad_seleccionada'] as num).toDouble(),
          precioUnitario: (producto['precio_unitario'] as num).toDouble(),
          subtotal: (producto['subtotal'] as num).toDouble(),
          lote: producto['lote'] as String?,
          serial: producto['serial'] as String?,
          fechaVencimiento: producto['fecha_vencimiento'] != null
              ? DateTime.tryParse(producto['fecha_vencimiento'] as String)
              : null,
          syncStatus: SyncStatus.pendingUpload,
        );
      }).toList();
      
      await _dao.crearMultiplesDetalles(detallesNotaCredito);
      
      // 9. Ajustar inventario automáticamente (NC se procesa al crearse)
      final db2 = await _dbHelper.database;
      await db2.transaction((txn) async {
        for (final detalle in detallesNotaCredito) {
          final existencia = await txn.query(
            'existencias',
            where: 'producto_id = ?',
            whereArgs: [detalle.productoId],
            limit: 1,
          );
          
          if (existencia.isNotEmpty) {
            final stockActual = (existencia.first['stock'] as num).toDouble();
            final nuevoStock = stockActual + detalle.cantidad;
            
            await txn.update(
              'existencias',
              {
                'stock': nuevoStock,
                'ultima_actualizacion': DateTime.now().toIso8601String(),
                'last_modified': DateTime.now().toIso8601String(),
                'sync_status': SyncStatus.pendingUpdate.toInt(),
              },
              where: 'producto_id = ?',
              whereArgs: [detalle.productoId],
            );
          }
        }
      });
      
      debugPrint('✅ Nota de crédito parcial creada y procesada: $numeroControl');
      debugPrint('   Factura: $facturaId');
      debugPrint('   Monto: $totalSeleccionado');
      debugPrint('   Productos: ${productosValidos.length}');
      debugPrint('   Motivo: $motivo');
      
      return {
        'valido': true,
        'mensaje': 'Nota de crédito parcial creada y procesada exitosamente',
        'nota_credito': notaCreada,
        'numero_control': numeroControl,
        'detalles': detallesNotaCredito.length,
        'total': totalSeleccionado,
      };
    } catch (e) {
      debugPrint('❌ Error creando nota de crédito parcial: $e');
      return {
        'valido': false,
        'mensaje': 'Error creando nota de crédito parcial: $e',
        'codigo': 'ERROR_CREACION',
      };
    }
  }

  // ===========================================================================
  // PROCESAMIENTO Y AJUSTE DE INVENTARIO
  // ===========================================================================

  /// Procesar nota de crédito (ajustar inventario)
  Future<Map<String, dynamic>> procesarNotaCredito(int notaCreditoId) async {
    try {
      // 1. Obtener nota de crédito
      final notaCredito = await _dao.obtenerNotaCreditoPorId(notaCreditoId);
      if (notaCredito == null) {
        return {
          'valido': false,
          'mensaje': 'Nota de crédito no encontrada',
          'codigo': 'NOTA_NO_ENCONTRADA',
        };
      }
      
      // 2. Verificar que esté pendiente
      if (!notaCredito.estaPendiente) {
        return {
          'valido': false,
          'mensaje': 'La nota de crédito ya está ${notaCredito.estado}',
          'codigo': 'YA_PROCESADA',
        };
      }
      
      final db = await _dbHelper.database;
      
      // 3. Obtener detalles
      final detalles = await _dao.obtenerDetallesPorNotaCredito(notaCreditoId);
      
      // 4. Ajustar inventario para cada producto
      await db.transaction((txn) async {
        for (final detalle in detalles) {
          // Buscar existencia actual
          final existencia = await txn.query(
            'existencias',
            where: 'producto_id = ?',
            whereArgs: [detalle.productoId],
            limit: 1,
          );
          
          if (existencia.isNotEmpty) {
            final stockActual = (existencia.first['stock'] as num).toDouble();
            final nuevoStock = stockActual + detalle.cantidad;
            
            await txn.update(
              'existencias',
              {
                'stock': nuevoStock,
                'ultima_actualizacion': DateTime.now().toIso8601String(),
                'last_modified': DateTime.now().toIso8601String(),
                'sync_status': SyncStatus.pendingUpdate.toInt(),
              },
              where: 'producto_id = ?',
              whereArgs: [detalle.productoId],
            );
            
            debugPrint('   📦 Producto ${detalle.productoId}: +${detalle.cantidad} unidades');
          } else {
            // Crear registro de existencia si no existe
            await txn.insert('existencias', {
              'producto_id': detalle.productoId,
              'cod_articulo': await _obtenerCodArticulo(detalle.productoId, txn),
              'stock': detalle.cantidad,
              'ultima_actualizacion': DateTime.now().toIso8601String(),
              'server_id': null,
              'last_modified': DateTime.now().toIso8601String(),
              'sync_status': SyncStatus.pendingUpload.toInt(),
            });
            
            debugPrint('   📦 Producto ${detalle.productoId}: nuevo registro con ${detalle.cantidad} unidades');
          }
        }
        
        // 5. Marcar nota de crédito como procesada
        await _dao.marcarComoProcesada(notaCreditoId, txn: txn);
      });
      
      debugPrint('✅ Nota de crédito $notaCreditoId procesada');
      debugPrint('   Productos ajustados: ${detalles.length}');
      debugPrint('   Monto total: ${notaCredito.totalGeneral}');
      
      return {
        'valido': true,
        'mensaje': 'Nota de crédito procesada exitosamente',
        'nota_credito_id': notaCreditoId,
        'productos_ajustados': detalles.length,
        'monto_total': notaCredito.totalGeneral,
      };
    } catch (e) {
      debugPrint('❌ Error procesando nota de crédito: $e');
      return {
        'valido': false,
        'mensaje': 'Error procesando nota de crédito: $e',
        'codigo': 'ERROR_PROCESAMIENTO',
      };
    }
  }

  /// Helper para obtener código de artículo
  Future<String> _obtenerCodArticulo(int productoId, Transaction txn) async {
    final producto = await txn.query(
      'productos',
      columns: ['cod_articulo'],
      where: 'id = ?',
      whereArgs: [productoId],
      limit: 1,
    );
    
    if (producto.isNotEmpty) {
      return producto.first['cod_articulo'] as String;
    }
    
    return 'PROD-$productoId';
  }

  // ===========================================================================
  // CONSULTAS Y REPORTES
  // ===========================================================================

  /// Obtener todas las notas de crédito con filtros
  Future<List<NotaCredito>> obtenerNotasCredito({
    String? estado,
    String? tipo,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
    int? limit,
    int? offset,
  }) async {
    return await _dao.obtenerTodasNotasCredito(
      estado: estado,
      tipo: tipo,
      fechaDesde: fechaDesde,
      fechaHasta: fechaHasta,
      limit: limit,
      offset: offset,
    );
  }

  /// Obtener nota de crédito con detalles completos
  Future<Map<String, dynamic>?> obtenerNotaCreditoCompleta(int id) async {
    try {
      final notaCredito = await _dao.obtenerNotaCreditoPorId(id);
      if (notaCredito == null) return null;
      
      final detalles = await _dao.obtenerDetallesConProducto(id);
      final motivos = await _dao.obtenerTodosMotivos();
      
      // Obtener información de la factura
      final db = await _dbHelper.database;
      final factura = await db.query(
        'factura',
        where: 'id = ?',
        whereArgs: [notaCredito.facturaId],
        limit: 1,
      );
      
      final cliente = factura.isNotEmpty
          ? await db.query(
              'clientes',
              where: 'id = ?',
              whereArgs: [factura.first['cliente_id']],
              limit: 1,
            )
          : [];
      
      return {
        'nota_credito': notaCredito,
        'detalles': detalles,
        'factura': factura.isNotEmpty ? factura.first : {},
        'cliente': cliente.isNotEmpty ? cliente.first : {},
        'motivos': motivos,
      };
    } catch (e) {
      debugPrint('❌ Error obteniendo nota de crédito completa: $e');
      return null;
    }
  }

  /// Obtener estadísticas
  Future<Map<String, dynamic>> obtenerEstadisticas({
    DateTime? fechaDesde,
    DateTime? fechaHasta,
  }) async {
    return await _dao.obtenerEstadisticas(
      fechaDesde: fechaDesde,
      fechaHasta: fechaHasta,
    );
  }

  /// Anular nota de crédito
  Future<Map<String, dynamic>> anularNotaCredito({
    required int notaCreditoId,
    required String motivo,
    required int usuarioId,
  }) async {
    try {
      final actualizado = await _dao.anularNotaCredito(
        notaCreditoId: notaCreditoId,
        motivo: motivo,
        usuarioId: usuarioId,
      );
      
      if (actualizado > 0) {
        return {
          'valido': true,
          'mensaje': 'Nota de crédito anulada exitosamente',
          'nota_credito_id': notaCreditoId,
        };
      } else {
        return {
          'valido': false,
          'mensaje': 'No se pudo anular la nota de crédito',
          'codigo': 'NO_ANULADA',
        };
      }
    } catch (e) {
      debugPrint('❌ Error anulando nota de crédito: $e');
      return {
        'valido': false,
        'mensaje': 'Error anulando nota de crédito: $e',
        'codigo': 'ERROR_ANULACION',
      };
    }
  }

  /// Verificar estado de una nota de crédito
  Future<Map<String, dynamic>> verificarEstado(int notaCreditoId) async {
    try {
      final notaCredito = await _dao.obtenerNotaCreditoPorId(notaCreditoId);
      
      if (notaCredito == null) {
        return {
          'existe': false,
          'mensaje': 'Nota de crédito no encontrada',
        };
      }
      
      final detalles = await _dao.obtenerDetallesPorNotaCredito(notaCreditoId);
      
      return {
        'existe': true,
        'nota_credito': notaCredito,
        'detalles_count': detalles.length,
        'estado': notaCredito.estado,
        'tipo': notaCredito.tipo,
        'monto_total': notaCredito.totalGeneral,
        'fecha_emision': notaCredito.fechaEmision,
      };
    } catch (e) {
      debugPrint('❌ Error verificando estado: $e');
      return {
        'existe': false,
        'mensaje': 'Error verificando estado: $e',
      };
    }
  }
}