import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pos_android/models/nota_credito.dart';
import 'package:pos_android/services/thermal_printer_service.dart';
import '../core/app_config.dart';

/// Servicio de impresión térmica para Notas de Crédito
class NotaCreditoPrinter {
  // ===========================================================================
  // MÉTODOS DE IMPRESIÓN
  // ===========================================================================

  /// Imprimir nota de crédito usando el servicio térmico existente
  static Future<bool> printNotaCredito({
    required NotaCredito notaCredito,
    required List<Map<String, dynamic>> detallesConProducto,
    required Map<String, dynamic> factura,
    required Map<String, dynamic> cliente,
    required double tasaCambio,
  }) async {
    try {
      final lines = _buildNotaCreditoLines(
        notaCredito: notaCredito,
        detallesConProducto: detallesConProducto,
        factura: factura,
        cliente: cliente,
        tasaCambio: tasaCambio,
      );

      return await ThermalPrinterService.printReceipt(lines: lines);
    } catch (e) {
      debugPrint('❌ Error imprimiendo nota de crédito: $e');
      return false;
    }
  }

  /// Enviar nota de crédito a impresora térmica POS via HTTP
  static Future<bool> sendToThermalPrinter({
    required NotaCredito notaCredito,
    required List<Map<String, dynamic>> detallesConProducto,
    required Map<String, dynamic> factura,
    required Map<String, dynamic> cliente,
    required String serverIp,
    required int serverPort,
  }) async {
    try {
      final jsonData = _buildPrinterJson(
        notaCredito: notaCredito,
        detallesConProducto: detallesConProducto,
        factura: factura,
        cliente: cliente,
      );

      final url = 'http://$serverIp:$serverPort/api/spPayment';

      debugPrint('📤 Enviando nota de crédito a impresora térmica...');
      debugPrint('   URL: $url');
      debugPrint('   JSON: ${jsonEncode(jsonData)}');

      // Usar el mismo método que para facturas
      final response = await ThermalPrinterService.sendToPrinter(
        serverIp: serverIp,
        serverPort: serverPort,
        jsonData: jsonData,
      );

      return response;
    } catch (e) {
      debugPrint('❌ Error enviando a impresora térmica: $e');
      return false;
    }
  }

  // ===========================================================================
  // CONSTRUCCIÓN DE LÍNEAS PARA IMPRESIÓN
  // ===========================================================================

  static List<PrinterLine> _buildNotaCreditoLines({
    required NotaCredito notaCredito,
    required List<Map<String, dynamic>> detallesConProducto,
    required Map<String, dynamic> factura,
    required Map<String, dynamic> cliente,
    required double tasaCambio,
  }) {
    final lines = <PrinterLine>[];
    final now = DateTime.now();
    final fecha =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final hora =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // 1. Encabezado SENIAT
    lines.add(PrinterLine(
      text: 'SENIAT',
      alignment: 'center',
      fontSize: 34,
      isBold: true,
    ));

    lines.add(PrinterLine(
      text: AppConfig.nombreComercio.toUpperCase(),
      alignment: 'center',
      fontSize: 26,
      isBold: true,
    ));

    lines.add(PrinterLine(
      text: AppConfig.direccionComercio.toUpperCase(),
      alignment: 'center',
      fontSize: 18,
    ));

    lines.add(PrinterLine(
      text: 'RIF: ${AppConfig.rifComercio}',
      alignment: 'center',
      fontSize: 22,
      isBold: true,
    ));

    // 2. Tipo de documento
    lines.add(_separator());
    lines.add(PrinterLine(
      text: 'NOTA DE CRÉDITO',
      alignment: 'center',
      fontSize: 28,
      isBold: true,
    ));

    // 3. Información del documento
    lines.add(_separator());
    lines.add(PrinterLine(
      text: 'FECHA: $fecha%HORA: $hora',
      alignment: 'justifed',
      fontSize: 18,
    ));

    lines.add(PrinterLine(
      text: 'N° CONTROL:%${notaCredito.numeroControl}',
      alignment: 'justifed',
      fontSize: 20,
      isBold: true,
    ));

    lines.add(PrinterLine(
      text: 'FACTURA ORIGINAL:%${factura['numero_control'] ?? 'N/A'}',
      alignment: 'justifed',
      fontSize: 18,
    ));

    // 4. Información del cliente
    lines.add(_separator());
    lines.add(PrinterLine(
      text: 'CLIENTE:',
      alignment: 'left',
      fontSize: 20,
      isBold: true,
    ));

    lines.add(PrinterLine(
      text: 'NOMBRE: ${cliente['nombre']?.toString().toUpperCase() ?? 'N/A'}',
      alignment: 'left',
      fontSize: 18,
    ));

    lines.add(PrinterLine(
      text:
          'RIF: ${cliente['identificacion']?.toString().toUpperCase() ?? 'N/A'}',
      alignment: 'left',
      fontSize: 18,
    ));

    // 5. Motivo
    lines.add(_separator());
    lines.add(PrinterLine(
      text: 'MOTIVO: ${notaCredito.motivo.toUpperCase()}',
      alignment: 'left',
      fontSize: 18,
    ));

    if (notaCredito.observaciones != null &&
        notaCredito.observaciones!.isNotEmpty) {
      lines.add(PrinterLine(
        text: 'OBS: ${notaCredito.observaciones!.toUpperCase()}',
        alignment: 'left',
        fontSize: 16,
      ));
    }

    // 6. Detalles de productos (solo para notas parciales)
    if (notaCredito.esParcial && detallesConProducto.isNotEmpty) {
      lines.add(_separator());
      lines.add(PrinterLine(
        text: 'PRODUCTOS DEVUELTOS:',
        alignment: 'center',
        fontSize: 22,
        isBold: true,
      ));

      lines.add(_separator());

      int itemIdx = 1;
      for (final detalle in detallesConProducto) {
        final nombre =
            detalle['producto_nombre']?.toString().toUpperCase() ?? 'PRODUCTO';
        final cantidad = (detalle['cantidad'] as num).toDouble();
        final precioUnitario = (detalle['precio_unitario'] as num).toDouble();
        final subtotal = (detalle['subtotal'] as num).toDouble();

        lines.add(PrinterLine(
          text: '${itemIdx.toString().padLeft(2, '0')} $nombre',
          alignment: 'left',
          fontSize: 18,
          isBold: true,
        ));

        final cantStr =
            '$cantidad X Bs ${_formatAmount(precioUnitario * tasaCambio)}';
        final montoStr = 'Bs ${_formatAmount(subtotal * tasaCambio)}';

        lines.add(PrinterLine(
          text: '$cantStr%$montoStr',
          alignment: 'justifed',
          fontSize: 18,
        ));

        // Información adicional (lote/serial)
        if (detalle['lote'] != null || detalle['serial'] != null) {
          final info = <String>[];
          if (detalle['lote'] != null) info.add('LOTE: ${detalle['lote']}');
          if (detalle['serial'] != null) {
            info.add('SERIAL: ${detalle['serial']}');
          }

          lines.add(PrinterLine(
            text: info.join(' | '),
            alignment: 'left',
            fontSize: 16,
          ));
        }

        itemIdx++;
      }
    }

    // 7. Totales
    lines.add(_separator());

    if (notaCredito.esTotal) {
      lines.add(PrinterLine(
        text: 'DEVOLUCIÓN TOTAL DE FACTURA',
        alignment: 'center',
        fontSize: 20,
        isBold: true,
      ));
    }

    lines.add(PrinterLine(
      text:
          'BASE IMPONIBLE%Bs ${_formatAmount(notaCredito.montoTotal * tasaCambio)}',
      alignment: 'justifed',
      fontSize: 22,
    ));

    lines.add(PrinterLine(
      text: 'IVA 16%%Bs ${_formatAmount(notaCredito.iva * tasaCambio)}',
      alignment: 'justifed',
      fontSize: 22,
    ));

    lines.add(PrinterLine(
      text: ' ',
      fontSize: 10,
    ));

    lines.add(PrinterLine(
      text:
          'TOTAL DEVOLUCIÓN%Bs ${_formatAmount(notaCredito.totalGeneral * tasaCambio)}',
      alignment: 'justifed',
      fontSize: 24,
      isBold: true,
    ));

    // 8. Información adicional
    lines.add(_separator());
    lines.add(PrinterLine(
      text: 'ESTADO: ${notaCredito.estado.toUpperCase()}',
      alignment: 'left',
      fontSize: 18,
    ));

    lines.add(PrinterLine(
      text: 'FECHA EMISIÓN: ${_formatDate(notaCredito.fechaEmision)}',
      alignment: 'left',
      fontSize: 18,
    ));

    lines.add(PrinterLine(
      text: 'TASA BCV:%${_formatAmount(tasaCambio)}',
      alignment: 'justifed',
      fontSize: 18,
    ));

    lines.add(_separator());
    lines.add(PrinterLine(
      text: 'DOCUMENTO FISCAL VÁLIDO',
      alignment: 'center',
      fontSize: 18,
      isBold: true,
    ));

    // Feed final con caracteres de espacio para forzar el avance del papel antes del corte físico
    lines.add(PrinterLine(text: ' ', fontSize: 24));
    lines.add(PrinterLine(text: ' ', fontSize: 24));
    lines.add(PrinterLine(text: ' ', fontSize: 24));
    lines.add(PrinterLine(text: ' ', fontSize: 24));
    lines.add(PrinterLine(text: ' ', fontSize: 24));

    return lines;
  }

  // ===========================================================================
  // CONSTRUCCIÓN DE JSON PARA IMPRESORA TÉRMICA POS
  // ===========================================================================

  static Map<String, dynamic> _buildPrinterJson({
    required NotaCredito notaCredito,
    required List<Map<String, dynamic>> detallesConProducto,
    required Map<String, dynamic> factura,
    required Map<String, dynamic> cliente,
  }) {
    final lines = <Map<String, dynamic>>[];

    // 1. Encabezado
    lines.add({
      'text': AppConfig.nombreComercio.toUpperCase(),
      'alignment': 'center',
      'font_size': 24,
      'is_bold': true,
    });

    lines.add({
      'text': AppConfig.direccionComercio.toUpperCase(),
      'alignment': 'center',
      'font_size': 12,
      'is_bold': false,
    });

    lines.add({
      'text': 'RIF: ${AppConfig.rifComercio}',
      'alignment': 'center',
      'font_size': 14,
      'is_bold': true,
    });

    lines.add(_jsonSeparator());

    // 2. Tipo de documento
    lines.add({
      'text': 'NOTA DE CRÉDITO',
      'alignment': 'center',
      'font_size': 20,
      'is_bold': true,
    });

    lines.add({
      'text': notaCredito.esTotal ? 'TOTAL' : 'PARCIAL',
      'alignment': 'center',
      'font_size': 18,
      'is_bold': true,
    });

    lines.add(_jsonSeparator());

    // 3. Información del documento
    final now = DateTime.now();
    final fecha =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final hora =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    lines.add({
      'text': 'FECHA: $fecha  HORA: $hora',
      'alignment': 'center',
      'font_size': 12,
      'is_bold': false,
    });

    lines.add({
      'text': 'N° CONTROL: ${notaCredito.numeroControl}',
      'alignment': 'center',
      'font_size': 14,
      'is_bold': true,
    });

    lines.add({
      'text': 'FACTURA ORIG: ${factura['numero_control'] ?? 'N/A'}',
      'alignment': 'center',
      'font_size': 12,
      'is_bold': false,
    });

    lines.add(_jsonSeparator());

    // 4. Información del cliente
    lines.add({
      'text': 'CLIENTE:',
      'alignment': 'left',
      'font_size': 14,
      'is_bold': true,
    });

    lines.add({
      'text': 'NOMBRE: ${cliente['nombre']?.toString().toUpperCase() ?? 'N/A'}',
      'alignment': 'left',
      'font_size': 12,
      'is_bold': false,
    });

    lines.add({
      'text':
          'RIF: ${cliente['identificacion']?.toString().toUpperCase() ?? 'N/A'}',
      'alignment': 'left',
      'font_size': 12,
      'is_bold': false,
    });

    lines.add(_jsonSeparator());

    // 5. Motivo
    lines.add({
      'text': 'MOTIVO: ${notaCredito.motivo.toUpperCase()}',
      'alignment': 'left',
      'font_size': 12,
      'is_bold': true,
    });

    if (notaCredito.observaciones != null &&
        notaCredito.observaciones!.isNotEmpty) {
      lines.add({
        'text': 'OBS: ${notaCredito.observaciones!.toUpperCase()}',
        'alignment': 'left',
        'font_size': 11,
        'is_bold': false,
      });
    }

    lines.add(_jsonSeparator());

    // 6. Detalles de productos (solo para notas parciales)
    if (notaCredito.esParcial && detallesConProducto.isNotEmpty) {
      lines.add({
        'text': 'PRODUCTOS DEVUELTOS:',
        'alignment': 'center',
        'font_size': 14,
        'is_bold': true,
      });

      lines.add(_jsonSeparator());

      for (final detalle in detallesConProducto) {
        final nombre =
            detalle['producto_nombre']?.toString().toUpperCase() ?? 'PRODUCTO';
        final cantidad = (detalle['cantidad'] as num).toDouble();
        final precioUnitario = (detalle['precio_unitario'] as num).toDouble();
        final subtotal = (detalle['subtotal'] as num).toDouble();

        lines.add({
          'text': nombre,
          'alignment': 'left',
          'font_size': 12,
          'is_bold': true,
        });

        lines.add({
          'text': 'CANT: $cantidad X PRECIO: ${_formatAmount(precioUnitario)}',
          'alignment': 'left',
          'font_size': 11,
          'is_bold': false,
        });

        lines.add({
          'text': 'SUBTOTAL: ${_formatAmount(subtotal)}',
          'alignment': 'right',
          'font_size': 12,
          'is_bold': true,
        });

        // Información adicional
        if (detalle['lote'] != null || detalle['serial'] != null) {
          final info = <String>[];
          if (detalle['lote'] != null) info.add('LOTE: ${detalle['lote']}');
          if (detalle['serial'] != null) {
            info.add('SERIAL: ${detalle['serial']}');
          }

          lines.add({
            'text': info.join(' | '),
            'alignment': 'left',
            'font_size': 10,
            'is_bold': false,
          });
        }
      }

      lines.add(_jsonSeparator());
    }

    // 7. Totales
    lines.add({
      'text': 'BASE IMPONIBLE: ${_formatAmount(notaCredito.montoTotal)}',
      'alignment': 'left',
      'font_size': 12,
      'is_bold': false,
    });

    lines.add({
      'text': 'IVA 16%: ${_formatAmount(notaCredito.iva)}',
      'alignment': 'left',
      'font_size': 12,
      'is_bold': false,
    });

    lines.add(_jsonSeparator());

    lines.add({
      'text': 'TOTAL DEVOLUCIÓN: ${_formatAmount(notaCredito.totalGeneral)}',
      'alignment': 'center',
      'font_size': 16,
      'is_bold': true,
    });

    lines.add(_jsonSeparator());

    // 8. Pie de página
    lines.add({
      'text': 'ESTADO: ${notaCredito.estado.toUpperCase()}',
      'alignment': 'left',
      'font_size': 11,
      'is_bold': false,
    });

    lines.add({
      'text': 'FECHA EMISIÓN: ${_formatDate(notaCredito.fechaEmision)}',
      'alignment': 'left',
      'font_size': 11,
      'is_bold': false,
    });

    lines.add({
      'text': 'DOCUMENTO FISCAL VÁLIDO',
      'alignment': 'center',
      'font_size': 12,
      'is_bold': true,
    });

    lines.add({
      'text': ' ',
      'alignment': 'center',
      'font_size': 20,
      'is_bold': false,
    });
    lines.add({
      'text': ' ',
      'alignment': 'center',
      'font_size': 20,
      'is_bold': false,
    });
    lines.add({
      'text': ' ',
      'alignment': 'center',
      'font_size': 20,
      'is_bold': false,
    });
    lines.add({
      'text': ' ',
      'alignment': 'center',
      'font_size': 20,
      'is_bold': false,
    });

    // 9. Construir JSON final
    return {
      'PaymentID': 'NotaCredito',
      'Operation': 'PRINTER',
      'Lines': lines,
    };
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  static PrinterLine _separator() {
    return PrinterLine(
      text: '------------------------------------------------------------',
      alignment: 'center',
      fontSize: 14,
    );
  }

  static Map<String, dynamic> _jsonSeparator() {
    return {
      'text': '--------------------------------',
      'alignment': 'center',
      'font_size': 10,
      'is_bold': false,
    };
  }

  static String _formatAmount(double amount) {
    String formatted = amount.toStringAsFixed(2);
    List<String> parts = formatted.split('.');
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    parts[0] = parts[0].replaceAllMapped(reg, (Match m) => '${m[1]}.');
    return '${parts[0]},${parts[1]}';
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
