import 'dart:io';
import 'dart:convert';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:csv/csv.dart';
import '../database/db_helper.dart';

class ExcelService {
  
  /// Solicitar permisos de almacenamiento
  static Future<bool> solicitarPermisos() async {
    try {
      // Para Android 13+ (API 33+)
      if (Platform.isAndroid) {
        final androidInfo = await _getAndroidVersion();
        
        if (androidInfo >= 33) {
          // Android 13+ no necesita permisos de almacenamiento para file_picker
          return true;
        } else if (androidInfo >= 30) {
          // Android 11-12
          var status = await Permission.manageExternalStorage.status;
          if (!status.isGranted) {
            status = await Permission.manageExternalStorage.request();
          }
          return status.isGranted;
        } else {
          // Android 10 y anteriores
          var status = await Permission.storage.status;
          if (!status.isGranted) {
            status = await Permission.storage.request();
          }
          return status.isGranted;
        }
      }
      return true;
    } catch (e) {
      debugPrint('❌ Error solicitando permisos: $e');
      return true; // Continuar de todos modos
    }
  }

  static Future<int> _getAndroidVersion() async {
    try {
      // Esto es una aproximación, en producción usarías device_info_plus
      return 33; // Asumimos Android 13+
    } catch (e) {
      return 33;
    }
  }
  
  /// Importar productos desde un archivo Excel
  /// Retorna un Map con el resultado: {success: bool, message: String, count: int}
  static Future<Map<String, dynamic>> importarProductos() async {
    try {
      // Solicitar permisos primero
      final permisoConcedido = await solicitarPermisos();
      if (!permisoConcedido) {
        return {
          'success': false,
          'message': 'Permisos de almacenamiento denegados',
          'count': 0,
        };
      }

      debugPrint('📂 Abriendo selector de archivos...');

      // 1. El usuario selecciona el archivo .xlsx
      // Cambiamos a FileType.any para mayor compatibilidad
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any, // Aceptar cualquier tipo de archivo
        allowMultiple: false,
        withData: true, // Importante para leer el contenido
        allowCompression: false,
      );

      if (result == null) {
        debugPrint('⚠️ Selección cancelada por el usuario');
        return {
          'success': false,
          'message': 'Selección cancelada',
          'count': 0,
        };
      }

      final fileName = result.files.single.name;
      debugPrint('✅ Archivo seleccionado: $fileName');

      // Verificar extensión del archivo
      final isExcel = fileName.toLowerCase().endsWith('.xlsx') || 
                      fileName.toLowerCase().endsWith('.xls');
      final isCsv = fileName.toLowerCase().endsWith('.csv');
      
      if (!isExcel && !isCsv) {
        return {
          'success': false,
          'message': 'Por favor selecciona un archivo Excel (.xlsx) o CSV (.csv)',
          'count': 0,
        };
      }

      // 2. Leer los bytes del archivo
      final bytes = result.files.single.bytes;
      if (bytes == null) {
        // Intentar leer desde la ruta
        final filePath = result.files.single.path;
        if (filePath == null) {
          return {
            'success': false,
            'message': 'No se pudo acceder al archivo',
            'count': 0,
          };
        }
        
        debugPrint('📖 Leyendo archivo desde: $filePath');
        final fileBytes = File(filePath).readAsBytesSync();
        
        // Procesar según el tipo de archivo
        if (isCsv) {
          return await _procesarCSV(fileBytes);
        } else {
          return await _procesarExcel(fileBytes);
        }
      }

      // Procesar según el tipo de archivo
      if (isCsv) {
        return await _procesarCSV(bytes);
      } else {
        return await _procesarExcel(bytes);
      }
    } catch (e) {
      debugPrint('❌ Error al importar: $e');
      return {
        'success': false,
        'message': 'Error al importar: ${e.toString()}',
        'count': 0,
      };
    }
  }

  static Future<Map<String, dynamic>> _procesarExcel(List<int> bytes) async {
    try {
      debugPrint('🔄 Procesando archivo Excel...');
      debugPrint('📏 Tamaño del archivo: ${bytes.length} bytes');
      
      // Intentar decodificar el Excel
      Excel excel;
      try {
        excel = Excel.decodeBytes(bytes);
        debugPrint('✅ Archivo Excel decodificado correctamente');
      } catch (e) {
        debugPrint('❌ Error decodificando Excel: $e');
        
        String mensajeError = '❌ Archivo Excel dañado o formato no válido\n\n';
        
        if (e.toString().contains('Damaged') || e.toString().contains('Invalid')) {
          mensajeError += '💡 SOLUCIÓN:\n\n'
              '1️⃣ Usa el archivo CSV en su lugar:\n'
              '   - Es más confiable\n'
              '   - Mismo formato de datos\n\n'
              '2️⃣ O repara el Excel:\n'
              '   - Abre el archivo en Excel\n'
              '   - Guarda como nuevo .xlsx\n'
              '   - Intenta de nuevo\n\n'
              '📄 Recomendación: Usa CSV para evitar problemas';
        } else if (e.toString().contains('Unsupported')) {
          mensajeError += 'Solo se aceptan archivos .xlsx (Excel 2007+)\n\n'
              'Si tienes .xls (Excel antiguo):\n'
              '1. Ábrelo en Excel\n'
              '2. Guarda como .xlsx\n'
              '3. Intenta de nuevo\n\n'
              'O mejor aún: Usa el archivo CSV';
        } else {
          mensajeError += 'Error: ${e.toString()}\n\n'
              '💡 Intenta usar el archivo CSV en su lugar';
        }
        
        return {
          'success': false,
          'message': mensajeError,
          'count': 0,
        };
      }

      // Verificar que tenga hojas
      if (excel.tables.isEmpty) {
        return {
          'success': false,
          'message': 'El archivo Excel está vacío o no tiene hojas',
          'count': 0,
        };
      }

      // 3. Obtener la instancia de la base de datos
      final db = await DbHelper.instance.database;

      int productosImportados = 0;
      int productosActualizados = 0;
      int filasOmitidas = 0;
      int totalFilasProcesadas = 0;

      // Iniciamos una transacción para que si algo falla, no se guarde nada a medias
      await db.transaction((txn) async {
        for (var table in excel.tables.keys) {
          debugPrint('📊 Procesando hoja: $table');
          
          var rows = excel.tables[table]!.rows;
          
          if (rows.isEmpty) {
            debugPrint('⚠️ Hoja vacía: $table');
            continue;
          }
          
          debugPrint('📋 Total de filas en la hoja: ${rows.length}');
          
          // Verificar si la primera fila son cabeceras
          final hasHeaders = rows.first.any((cell) => 
            cell?.value.toString().toLowerCase().contains('codigo') == true ||
            cell?.value.toString().toLowerCase().contains('articulo') == true ||
            cell?.value.toString().toLowerCase().contains('nombre') == true ||
            cell?.value.toString().toLowerCase().contains('precio') == true
          );
          
          debugPrint('📌 ¿Tiene cabeceras? $hasHeaders');
          
          final dataRows = hasHeaders ? rows.skip(1) : rows;
          final dataRowsList = dataRows.toList();
          
          debugPrint('📊 Filas de datos a procesar: ${dataRowsList.length}');

          for (var row in dataRowsList) {
            totalFilasProcesadas++;
            
            try {
              // Verificar que la fila tenga al menos 3 columnas
              if (row.length < 3) {
                debugPrint('⚠️ Fila $totalFilasProcesadas omitida: menos de 3 columnas');
                filasOmitidas++;
                continue;
              }

              // Extraemos los datos según el orden de tus columnas en Excel
              // Col 0: CodArticulo, Col 1: CodBarras, Col 2: Nombre, Col 3: Precio, Col 4: Stock
              final codArt = row.isNotEmpty ? (row[0]?.value?.toString().trim() ?? '') : '';
              final codBar = row.length > 1 ? (row[1]?.value?.toString().trim() ?? '') : '';
              final nombre = row.length > 2 ? (row[2]?.value?.toString().trim() ?? '') : '';
              final precioStr = row.length > 3 ? (row[3]?.value?.toString().trim() ?? '0') : '0';
              final stockStr = row.length > 4 ? (row[4]?.value?.toString().trim() ?? '0') : '0';

              // Validar que al menos tengamos código y nombre
              if (codArt.isEmpty || nombre.isEmpty) {
                debugPrint('⚠️ Fila $totalFilasProcesadas omitida: código="$codArt" nombre="$nombre"');
                filasOmitidas++;
                continue;
              }

              // Parsear precio y stock
              final precio = double.tryParse(precioStr.replaceAll(',', '.')) ?? 0.0;
              final stock = double.tryParse(stockStr.replaceAll(',', '.')) ?? 0.0;

              debugPrint('📦 Procesando: $codArt - $nombre - \$$precio - Stock: $stock');

              // Verificar si el producto ya existe
              final existingProduct = await txn.query(
                'productos',
                where: 'cod_articulo = ?',
                whereArgs: [codArt],
                limit: 1,
              );

              int productoId;

              if (existingProduct.isNotEmpty) {
                // Actualizar producto existente
                productoId = existingProduct.first['id'] as int;
                await txn.update(
                  'productos',
                  {
                    'cod_barras': codBar,
                    'nombre': nombre,
                    'precio': precio,
                  },
                  where: 'id = ?',
                  whereArgs: [productoId],
                );
                
                // Actualizar stock
                await txn.update(
                  'existencias',
                  {
                    'stock': stock,
                    'ultima_actualizacion': DateTime.now().toIso8601String(),
                  },
                  where: 'producto_id = ?',
                  whereArgs: [productoId],
                );
                
                productosActualizados++;
                debugPrint('✏️ Producto actualizado: $codArt - $nombre');
              } else {
                // Insertar nuevo producto
                productoId = await txn.insert('productos', {
                  'cod_articulo': codArt,
                  'cod_barras': codBar,
                  'nombre': nombre,
                  'precio': precio,
                  'fecha_creacion': DateTime.now().toIso8601String(),
                });

                // Insertar stock
                await txn.insert('existencias', {
                  'producto_id': productoId,
                  'cod_articulo': codArt,
                  'stock': stock,
                  'ultima_actualizacion': DateTime.now().toIso8601String(),
                });
                
                productosImportados++;
                debugPrint('✅ Producto nuevo: $codArt - $nombre');
              }
            } catch (e) {
              debugPrint('❌ Error procesando fila $totalFilasProcesadas: $e');
              filasOmitidas++;
              // Continuar con la siguiente fila
            }
          }
        }
      });

      final totalProcesados = productosImportados + productosActualizados;
      
      debugPrint('📊 Resumen:');
      debugPrint('   - Nuevos: $productosImportados');
      debugPrint('   - Actualizados: $productosActualizados');
      debugPrint('   - Omitidos: $filasOmitidas');
      debugPrint('   - Total procesados: $totalProcesados');
      
      String mensaje = '';
      if (totalProcesados > 0) {
        mensaje = '✅ Importación exitosa\n\n';
        if (productosImportados > 0) {
          mensaje += '🆕 Nuevos: $productosImportados\n';
        }
        if (productosActualizados > 0) {
          mensaje += '✏️ Actualizados: $productosActualizados';
        }
      } else {
        mensaje = '⚠️ No se importaron productos';
      }
      
      return {
        'success': totalProcesados > 0,
        'message': mensaje,
        'count': totalProcesados,
        'nuevos': productosImportados,
        'actualizados': productosActualizados,
        'omitidos': filasOmitidas,
      };
    } catch (e) {
      debugPrint('❌ Error procesando Excel: $e');
      
      String mensajeError = 'Error procesando archivo';
      
      if (e.toString().contains('Unsupported operation') || 
          e.toString().contains('Excel format unsupported')) {
        mensajeError = 'Formato no soportado\n\n'
            'Solo se aceptan archivos .xlsx (Excel 2007+)\n\n'
            'Si tienes un archivo .xls (Excel antiguo):\n'
            '1. Ábrelo en Excel\n'
            '2. Guárdalo como "Excel Workbook (.xlsx)"\n'
            '3. Intenta importar de nuevo';
      } else {
        mensajeError = 'Error: ${e.toString()}';
      }
      
      return {
        'success': false,
        'message': mensajeError,
        'count': 0,
      };
    }
  }

  /// Procesar archivo CSV
  static Future<Map<String, dynamic>> _procesarCSV(List<int> bytes) async {
    try {
      debugPrint('🔄 Procesando archivo CSV...');
      debugPrint('📏 Tamaño del archivo: ${bytes.length} bytes');
      
      // Convertir bytes a string
      final csvString = utf8.decode(bytes);
      
      // Parsear CSV
      final List<List<dynamic>> rows = const CsvToListConverter().convert(
        csvString,
        eol: '\n',
        fieldDelimiter: ',',
      );
      
      if (rows.isEmpty) {
        return {
          'success': false,
          'message': 'El archivo CSV está vacío',
          'count': 0,
        };
      }
      
      debugPrint('📋 Total de filas en CSV: ${rows.length}');
      
      // Filtrar comentarios (líneas que empiezan con #)
      final rowsSinComentarios = rows.where((row) {
        if (row.isEmpty) return false;
        final firstCell = row[0].toString().trim();
        return !firstCell.startsWith('#');
      }).toList();
      
      if (rowsSinComentarios.isEmpty) {
        return {
          'success': false,
          'message': 'El archivo CSV no tiene datos válidos',
          'count': 0,
        };
      }
      
      // Verificar si tiene columna TIPO (formato unificado)
      final hasTypeColumn = rowsSinComentarios.first.any((cell) => 
        cell.toString().toUpperCase() == 'TIPO'
      );
      
      debugPrint('📌 ¿Formato unificado (con TIPO)? $hasTypeColumn');
      
      if (hasTypeColumn) {
        return await _procesarCSVUnificado(rowsSinComentarios);
      } else {
        return await _procesarCSVProductos(rowsSinComentarios);
      }
      
    } catch (e) {
      debugPrint('❌ Error procesando CSV: $e');
      
      String mensajeError = '❌ Error al procesar CSV\n\n';
      
      if (e.toString().contains('FormatException')) {
        mensajeError += 'El archivo tiene un formato incorrecto.\n\n'
            '💡 Verifica que:\n'
            '- Los datos estén separados por comas\n'
            '- No haya líneas vacías al final\n'
            '- Los decimales usen punto (.) no coma (,)';
      } else {
        mensajeError = 'Error: ${e.toString()}';
      }
      
      return {
        'success': false,
        'message': mensajeError,
        'count': 0,
      };
    }
  }

  /// Procesar CSV unificado con columna TIPO (productos y clientes)
  static Future<Map<String, dynamic>> _procesarCSVUnificado(List<List<dynamic>> rows) async {
    debugPrint('🔄 Procesando CSV unificado (productos + clientes)...');
    
    // La primera fila son los encabezados
    final headers = rows.first.map((e) => e.toString().toUpperCase()).toList();
    final tipoIndex = headers.indexOf('TIPO');
    
    if (tipoIndex == -1) {
      return {
        'success': false,
        'message': 'No se encontró la columna TIPO en el archivo',
        'count': 0,
      };
    }
    
    final dataRows = rows.skip(1).toList();
    debugPrint('📊 Filas de datos a procesar: ${dataRows.length}');
    
    final db = await DbHelper.instance.database;
    
    int productosImportados = 0;
    int productosActualizados = 0;
    int clientesImportados = 0;
    int clientesActualizados = 0;
    int filasOmitidas = 0;
    int totalFilasProcesadas = 0;
    
    await db.transaction((txn) async {
      for (var row in dataRows) {
        totalFilasProcesadas++;
        
        try {
          if (row.length <= tipoIndex) {
            filasOmitidas++;
            continue;
          }
          
          final tipo = row[tipoIndex].toString().trim().toUpperCase();
          
          if (tipo == 'PRODUCTO') {
            // Procesar producto
            final result = await _procesarFilaProducto(txn, row, tipoIndex);
            if (result == 'nuevo') { productosImportados++;
            }else if (result == 'actualizado'){ productosActualizados++;
            }else{ filasOmitidas++;
              filasOmitidas++;
            }
          } else if (tipo == 'CLIENTE') {
            // Procesar cliente
            final result = await _procesarFilaCliente(txn, row, tipoIndex);
            if (result == 'nuevo'){ clientesImportados++;
            }else if (result == 'actualizado'){ clientesActualizados++;
            }else { filasOmitidas++; }
          } else {
            debugPrint('⚠️ Fila $totalFilasProcesadas: tipo desconocido "$tipo"');
            filasOmitidas++;
          }
        } catch (e) {
          debugPrint('❌ Error procesando fila $totalFilasProcesadas: $e');
          filasOmitidas++;
        }
      }
    });
    
    final totalProcesados = productosImportados + productosActualizados + 
                           clientesImportados + clientesActualizados;
    
    debugPrint('📊 Resumen CSV Unificado:');
    debugPrint('   PRODUCTOS:');
    debugPrint('   - Nuevos: $productosImportados');
    debugPrint('   - Actualizados: $productosActualizados');
    debugPrint('   CLIENTES:');
    debugPrint('   - Nuevos: $clientesImportados');
    debugPrint('   - Actualizados: $clientesActualizados');
    debugPrint('   - Omitidos: $filasOmitidas');
    
    String mensaje = '';
    if (totalProcesados > 0) {
      mensaje = '✅ Importación exitosa\n\n';
      
      if (productosImportados > 0 || productosActualizados > 0) {
        mensaje += '📦 PRODUCTOS:\n';
        if (productosImportados > 0) mensaje += '  🆕 Nuevos: $productosImportados\n';
        if (productosActualizados > 0) mensaje += '  ✏️ Actualizados: $productosActualizados';
      }
      
      if (clientesImportados > 0 || clientesActualizados > 0) {
        if (productosImportados > 0 || productosActualizados > 0) mensaje += '\n\n';
        mensaje += '👥 CLIENTES:\n';
        if (clientesImportados > 0) mensaje += '  🆕 Nuevos: $clientesImportados\n';
        if (clientesActualizados > 0) mensaje += '  ✏️ Actualizados: $clientesActualizados';
      }
    } else {
      mensaje = '⚠️ No se importaron datos\n\n'
          'Verifica que el archivo tenga el formato correcto';
    }
    
    return {
      'success': totalProcesados > 0,
      'message': mensaje,
      'count': totalProcesados,
      'nuevos': productosImportados,
      'actualizados': productosActualizados,
      'omitidos': filasOmitidas,
    };
  }

  /// Procesar fila de producto
  static Future<String> _procesarFilaProducto(
    Transaction txn, 
    List<dynamic> row, 
    int tipoIndex
  ) async {
    // TIPO, CodArticulo, CodBarras, Nombre, Precio, Stock
    if (row.length < tipoIndex + 6) return 'omitido';
    
    final codArt = row[tipoIndex + 1].toString().trim();
    final codBar = row[tipoIndex + 2].toString().trim();
    final nombre = row[tipoIndex + 3].toString().trim();
    final descripcion = row.length > tipoIndex + 4 ? row[tipoIndex + 4].toString().trim() : '';
    final precioStr = row.length > tipoIndex + 5 ? row[tipoIndex + 5].toString().trim() : '0';
    final stockStr = row.length > tipoIndex + 6 ? row[tipoIndex + 6].toString().trim() : '0';
    final tipoImpuesto = row.length > tipoIndex + 7 ? row[tipoIndex + 7].toString().trim().toUpperCase() : 'G';
    final unidadMedidaStr = row.length > tipoIndex + 8 ? row[tipoIndex + 8].toString().trim().toLowerCase() : 'und';
    
    if (codArt.isEmpty || nombre.isEmpty) return 'omitido';
    
    final precio = double.tryParse(precioStr.replaceAll(',', '.')) ?? 0.0;
    final stock = double.tryParse(stockStr.replaceAll(',', '.')) ?? 0.0;
    
    // Validar tipo de impuesto
    final tipoImpuestoFinal = (tipoImpuesto == 'E' || tipoImpuesto == 'G') ? tipoImpuesto : 'G';
    
    debugPrint('📦 Producto: $codArt - $nombre - \$$precio - Stock: $stock - Tipo: $tipoImpuestoFinal');
    
    final existingProduct = await txn.query(
      'productos',
      where: 'cod_articulo = ?',
      whereArgs: [codArt],
      limit: 1,
    );
    
    if (existingProduct.isNotEmpty) {
      final productoId = existingProduct.first['id'] as int;
      await txn.update(
        'productos',
        {
          'cod_barras': codBar.isEmpty ? null : codBar,
          'nombre': nombre,
          'descripcion': descripcion.isEmpty ? null : descripcion,
          'precio': precio,
          'tipo_impuesto': tipoImpuestoFinal,
          'unidad_medida': (unidadMedidaStr == 'kg' || unidadMedidaStr == 'g' || unidadMedidaStr == 'pza') ? unidadMedidaStr : 'und',
        },
        where: 'id = ?',
        whereArgs: [productoId],
      );
      
      await txn.update(
        'existencias',
        {
          'stock': stock,
          'ultima_actualizacion': DateTime.now().toIso8601String(),
        },
        where: 'producto_id = ?',
        whereArgs: [productoId],
      );
      
      return 'actualizado';
    } else {
      final productoId = await txn.insert('productos', {
        'cod_articulo': codArt,
        'cod_barras': codBar.isEmpty ? null : codBar,
        'nombre': nombre,
        'descripcion': descripcion.isEmpty ? null : descripcion,
        'precio': precio,
        'tipo_impuesto': tipoImpuestoFinal,
        'unidad_medida': (unidadMedidaStr == 'kg' || unidadMedidaStr == 'g' || unidadMedidaStr == 'pza') ? unidadMedidaStr : 'und',
        'fecha_creacion': DateTime.now().toIso8601String(),
      });
      
      await txn.insert('existencias', {
        'producto_id': productoId,
        'cod_articulo': codArt,
        'stock': stock,
        'ultima_actualizacion': DateTime.now().toIso8601String(),
      });
      
      return 'nuevo';
    }
  }

  /// Procesar fila de cliente
  static Future<String> _procesarFilaCliente(
    Transaction txn, 
    List<dynamic> row, 
    int tipoIndex
  ) async {
    // TIPO, Identificacion, Nombre, Direccion, Telefono, Correo, AgenteRetencion
    if (row.length < tipoIndex + 4) return 'omitido';
    
    final identificacion = row[tipoIndex + 1].toString().trim();
    final nombre = row[tipoIndex + 2].toString().trim();
    final direccion = row[tipoIndex + 3].toString().trim();
    final telefono = row.length > tipoIndex + 4 ? row[tipoIndex + 4].toString().trim() : '';
    final correo = row.length > tipoIndex + 5 ? row[tipoIndex + 5].toString().trim() : '';
    final agenteRetencionStr = row.length > tipoIndex + 6 ? row[tipoIndex + 6].toString().trim().toUpperCase() : '';
    final agenteRetencion = (agenteRetencionStr == 'SI' || agenteRetencionStr == 'SÍ' || agenteRetencionStr == '1' || agenteRetencionStr == 'TRUE') ? 1 : 0;
    
    // Validar campos obligatorios
    if (identificacion.isEmpty || nombre.isEmpty || direccion.isEmpty) {
      debugPrint('⚠️ Cliente omitido: ID="$identificacion" Nombre="$nombre" Dir="$direccion"');
      return 'omitido';
    }
    
    debugPrint('👤 Cliente: $identificacion - $nombre - Dir: $direccion - Tel: ${telefono.isEmpty ? "N/A" : telefono} (AR: ${agenteRetencion == 1 ? "Sí" : "No"})');
    
    final existingClient = await txn.query(
      'clientes',
      where: 'identificacion = ?',
      whereArgs: [identificacion],
      limit: 1,
    );
    
    if (existingClient.isNotEmpty) {
      await txn.update(
        'clientes',
        {
          'nombre': nombre,
          'direccion': direccion,
          'telefono': telefono.isEmpty ? null : telefono,
          'correo': correo.isEmpty ? null : correo,
          'agente_retencion': agenteRetencion,
        },
        where: 'identificacion = ?',
        whereArgs: [identificacion],
      );
      
      return 'actualizado';
    } else {
      await txn.insert('clientes', {
        'identificacion': identificacion,
        'nombre': nombre,
        'direccion': direccion,
        'telefono': telefono.isEmpty ? null : telefono,
        'correo': correo.isEmpty ? null : correo,
        'agente_retencion': agenteRetencion,
        'fecha_creacion': DateTime.now().toIso8601String(),
      });
      
      return 'nuevo';
    }
  }

  /// Procesar CSV de solo productos (formato antiguo)
  static Future<Map<String, dynamic>> _procesarCSVProductos(List<List<dynamic>> rows) async {
    try {
      debugPrint('🔄 Procesando CSV de productos (formato antiguo)...');
      
      // Verificar si tiene cabeceras
      final hasHeaders = rows.first.any((cell) => 
        cell.toString().toLowerCase().contains('codigo') ||
        cell.toString().toLowerCase().contains('articulo') ||
        cell.toString().toLowerCase().contains('nombre') ||
        cell.toString().toLowerCase().contains('precio')
      );
      
      debugPrint('📌 ¿Tiene cabeceras? $hasHeaders');
      
      final dataRows = hasHeaders ? rows.skip(1).toList() : rows;
      debugPrint('📊 Filas de datos a procesar: ${dataRows.length}');
      
      // Obtener la instancia de la base de datos
      final db = await DbHelper.instance.database;

      int productosImportados = 0;
      int productosActualizados = 0;
      int filasOmitidas = 0;
      int totalFilasProcesadas = 0;

      // Transacción
      await db.transaction((txn) async {
        for (var row in dataRows) {
          totalFilasProcesadas++;
          
          try {
            // Verificar que la fila tenga al menos 3 columnas
            if (row.length < 3) {
              debugPrint('⚠️ Fila $totalFilasProcesadas omitida: menos de 3 columnas');
              filasOmitidas++;
              continue;
            }

            // Extraer datos
            final codArt = row.isNotEmpty ? row[0].toString().trim() : '';
            final codBar = row.length > 1 ? row[1].toString().trim() : '';
            final nombre = row.length > 2 ? row[2].toString().trim() : '';
            final precioStr = row.length > 3 ? row[3].toString().trim() : '0';
            final stockStr = row.length > 4 ? row[4].toString().trim() : '0';

            // Validar
            if (codArt.isEmpty || nombre.isEmpty) {
              debugPrint('⚠️ Fila $totalFilasProcesadas omitida: código="$codArt" nombre="$nombre"');
              filasOmitidas++;
              continue;
            }

            // Parsear números
            final precio = double.tryParse(precioStr.replaceAll(',', '.')) ?? 0.0;
            final stock = double.tryParse(stockStr.replaceAll(',', '.')) ?? 0.0;

            debugPrint('📦 Procesando: $codArt - $nombre - \$$precio - Stock: $stock');

            // Verificar si existe
            final existingProduct = await txn.query(
              'productos',
              where: 'cod_articulo = ?',
              whereArgs: [codArt],
              limit: 1,
            );

            int productoId;

            if (existingProduct.isNotEmpty) {
              // Actualizar
              productoId = existingProduct.first['id'] as int;
              await txn.update(
                'productos',
                {
                  'cod_barras': codBar,
                  'nombre': nombre,
                  'precio': precio,
                },
                where: 'id = ?',
                whereArgs: [productoId],
              );
              
              await txn.update(
                'existencias',
                {
                  'stock': stock,
                  'ultima_actualizacion': DateTime.now().toIso8601String(),
                },
                where: 'producto_id = ?',
                whereArgs: [productoId],
              );
              
              productosActualizados++;
              debugPrint('✏️ Producto actualizado: $codArt - $nombre');
            } else {
              // Insertar
              productoId = await txn.insert('productos', {
                'cod_articulo': codArt,
                'cod_barras': codBar,
                'nombre': nombre,
                'precio': precio,
                'fecha_creacion': DateTime.now().toIso8601String(),
              });

              await txn.insert('existencias', {
                'producto_id': productoId,
                'cod_articulo': codArt,
                'stock': stock,
                'ultima_actualizacion': DateTime.now().toIso8601String(),
              });
              
              productosImportados++;
              debugPrint('✅ Producto nuevo: $codArt - $nombre');
            }
          } catch (e) {
            debugPrint('❌ Error procesando fila $totalFilasProcesadas: $e');
            filasOmitidas++;
          }
        }
      });

      final totalProcesados = productosImportados + productosActualizados;
      
      debugPrint('📊 Resumen CSV:');
      debugPrint('   - Nuevos: $productosImportados');
      debugPrint('   - Actualizados: $productosActualizados');
      debugPrint('   - Omitidos: $filasOmitidas');
      
      String mensaje = '';
      if (totalProcesados > 0) {
        mensaje = '✅ Importación exitosa\n\n';
        if (productosImportados > 0) {
          mensaje += '🆕 Nuevos: $productosImportados\n';
        }
        if (productosActualizados > 0) {
          mensaje += '✏️ Actualizados: $productosActualizados';
        }
      } else {
        mensaje = '⚠️ No se importaron productos';
      }
      
      return {
        'success': totalProcesados > 0,
        'message': mensaje,
        'count': totalProcesados,
        'nuevos': productosImportados,
        'actualizados': productosActualizados,
        'omitidos': filasOmitidas,
      };
    } catch (e) {
      debugPrint('❌ Error procesando CSV: $e');
      return {
        'success': false,
        'message': 'Error procesando archivo CSV: ${e.toString()}',
        'count': 0,
      };
    }
  }

  /// Verificar si la base de datos tiene productos
  static Future<bool> tieneProductos() async {
    try {
      final db = await DbHelper.instance.database;
      final result = await db.query('productos', limit: 1);
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error verificando productos: $e');
      return false;
    }
  }

  /// Obtener el conteo de productos en la base de datos
  static Future<int> contarProductos() async {
    try {
      final db = await DbHelper.instance.database;
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM productos');
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      debugPrint('❌ Error contando productos: $e');
      return 0;
    }
  }

  /// Limpiar todos los productos (útil para reimportar)
  static Future<bool> limpiarProductos() async {
    try {
      final db = await DbHelper.instance.database;
      await db.transaction((txn) async {
        await txn.delete('existencias');
        await txn.delete('productos');
      });
      debugPrint('🗑️ Productos eliminados');
      return true;
    } catch (e) {
      debugPrint('❌ Error limpiando productos: $e');
      return false;
    }
  }
}
