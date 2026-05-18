import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../core/app_config.dart';

/// Modelo para una línea de texto a imprimir en la impresora térmica
class PrinterLine {
  final String text;
  final String alignment; // 'left', 'center', 'right'
  final int fontSize;
  final bool isBold;

  PrinterLine({
    required this.text,
    this.alignment = 'left',
    this.fontSize = 12,
    this.isBold = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'alignment': alignment,
      'font_size': fontSize,
      'is_bold': isBold,
    };
  }
}

class ThermalPrinterService {
  static const _platform = MethodChannel('com.pos.pos_android/ubii_pos');

  // ─────────────────────────────────────────────────────────────────────────────
  // MÉTODOS DE IMPRESIÓN
  // ─────────────────────────────────────────────────────────────────────────────

  static Future<bool> printReceipt({
    required List<PrinterLine> lines,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final String linesJson =
          jsonEncode(lines.map((l) => l.toJson()).toList());
      final result =
          await _platform.invokeMethod('printLines', {'lines': linesJson});
      return result != null;
    } catch (e) {
      debugPrint('🚨 Error en impresión: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // LÓGICA DE FORMATEO (ESPACIOS DE RELLENO)
  // ─────────────────────────────────────────────────────────────────────────────

  static String _formatAmount(double amount) {
    String formatted = amount.toStringAsFixed(2);
    List<String> parts = formatted.split('.');
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    parts[0] = parts[0].replaceAllMapped(reg, (Match m) => '${m[1]}.');
    return '${parts[0]},${parts[1]}';
  }

  /// RELLENO DE ESPACIOS - Calibrado para margen derecho extremo
  static String _formatRow(String left, String right, {int width = 48}) {
    final int spaceCount = width - left.length - right.length;
    if (spaceCount <= 0) return '$left $right';
    return left + (' ' * spaceCount) + right;
  }

  static String _translatePaymentMethod(String? method) {
    if (method == null) return 'N/A';
    final m = method.toLowerCase();
    if (m == 'cash') return 'EFECTIVO';
    if (m == 'card') return 'TARJETA';
    if (m == 'pago_movil') return 'PAGO MOVIL';
    if (m == 'debit') return 'DEBITO';
    return method.toUpperCase();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // CONSTRUCCIÓN DE FACTURA
  // ─────────────────────────────────────────────────────────────────────────────

  static List<PrinterLine> buildInvoiceLines({
    required String invoiceNumber,
    required String clientName,
    required String clientRif,
    String? clientAddress,
    required List<Map<String, dynamic>> items,
    required double baseImponible,
    required double montoIva,
    required double total,
    required double tasaCambio,
    double montoExento = 0.0,
    String? metodoPago,
    String? referencia,
  }) {
    final lines = <PrinterLine>[];
    final now = DateTime.now();
    final fecha =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final hora =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // 1. Encabezado SENIAT
    lines.add(PrinterLine(
        text: 'SENIAT', alignment: 'center', fontSize: 34, isBold: true));
    lines.add(PrinterLine(
        text: AppConfig.nombreComercio.toUpperCase(),
        alignment: 'center',
        fontSize: 26,
        isBold: true));
    lines.add(PrinterLine(
        text: AppConfig.direccionComercio.toUpperCase(),
        alignment: 'center',
        fontSize: 18));
    lines.add(PrinterLine(
        text: 'RIF: ${AppConfig.rifComercio}',
        alignment: 'center',
        fontSize: 22,
        isBold: true));

    // 2. Info Documento
    lines.add(_separator());
    lines.add(PrinterLine(
        text: 'FECHA: $fecha%HORA: $hora',
        alignment: 'justifed',
        fontSize: 18));
    lines.add(PrinterLine(
        text: 'FACTURA:%${invoiceNumber.replaceAll('FAC-', '')}',
        alignment: 'justifed',
        fontSize: 20,
        isBold: true));

    // 3. Cliente
    lines.add(
        PrinterLine(text: 'NOMBRE: ${clientName.toUpperCase()}', alignment: 'left', fontSize: 18));
    lines.add(
        PrinterLine(text: 'RIF: ${clientRif.toUpperCase()}', alignment: 'left', fontSize: 18));
    if (clientAddress != null && clientAddress.trim().isNotEmpty) {
      lines.add(
          PrinterLine(text: 'DIR: ${clientAddress.trim().toUpperCase()}', alignment: 'left', fontSize: 18));
    }

    lines.add(PrinterLine(
        text: 'FACTURA', alignment: 'center', fontSize: 28, isBold: true));
    lines.add(_separator());

    // 4. Productos
    int itemIdx = 1;
    double totalArticulos = 0;
    for (final item in items) {
      final nombre = (item['nombre'] as String? ?? item['name'] as String? ?? 'PRODUCTO').toUpperCase();
      final cant = (item['cantidad'] ?? item['quantity'] ?? 1) as num;
      final precioConIva = (item['precio_unitario'] ?? item['price'] ?? 0.0) as double;
      final precioBase = precioConIva / 1.16; // Extraer IVA para base imponible
      final subtotalBaseBs = (precioBase * tasaCambio) * cant.toDouble();
      totalArticulos += cant.toDouble();

      lines.add(PrinterLine(
          text: '${itemIdx.toString().padLeft(3, '0')} $nombre',
          alignment: 'left',
          fontSize: 20,
          isBold: true));

      final cantStr =
          '${cant.toInt()} X ${_formatAmount(precioBase * tasaCambio)}';
      final montoStr = _formatAmount(subtotalBaseBs);
      // Productos justificados horizontalmente en una misma línea (Estilo Oficial Ubii)
      lines.add(PrinterLine(
          text: '$cantStr%$montoStr',
          alignment: 'justifed',
          fontSize: 20));
      itemIdx++;
    }

    lines.add(_separator());

    // 5. Totales (JUSTIFICADOS HORIZONTALMENTE NATIVO - ALINEACIÓN PERFECTA)
    lines.add(PrinterLine(
        text: 'SUBTTL Bs%${_formatAmount(baseImponible * tasaCambio)}',
        alignment: 'justifed',
        fontSize: 22));
        
    if (montoExento > 0) {
      lines.add(PrinterLine(
          text: 'EXENTO Bs%${_formatAmount(montoExento * tasaCambio)}',
          alignment: 'justifed',
          fontSize: 22));
    }
    
    lines.add(PrinterLine(
        text: 'IVA G 16%${_formatAmount(montoIva * tasaCambio)}',
        alignment: 'justifed',
        fontSize: 22));
        
    lines.add(PrinterLine(text: ' ', fontSize: 10));

    lines.add(PrinterLine(
        text: 'TOTAL Bs%${_formatAmount(total * tasaCambio)}',
        alignment: 'justifed',
        fontSize: 22,
        isBold: true));

    lines.add(_separator());

    // 6. Resumen Fiscal e Info Adicional (JUSTIFICADOS HORIZONTALMENTE NATIVO)
    lines.add(PrinterLine(
        text: 'BI G 16%${_formatAmount(baseImponible * tasaCambio)}',
        alignment: 'justifed',
        fontSize: 16));
    lines.add(PrinterLine(
        text: 'IVA G 16%${_formatAmount(montoIva * tasaCambio)}',
        alignment: 'justifed',
        fontSize: 16));

    lines.add(PrinterLine(
        text: 'METODO:%${_translatePaymentMethod(metodoPago)}',
        alignment: 'justifed',
        fontSize: 18));
    lines.add(PrinterLine(
        text: 'TASA BCV:%${_formatAmount(tasaCambio)}',
        alignment: 'justifed',
        fontSize: 18));
    lines.add(PrinterLine(
        text: 'ARTICULOS:%${totalArticulos.toInt().toString()}',
        alignment: 'justifed',
        fontSize: 18));

    // 7. Agradecimiento final
    lines.add(_separator());
    lines.add(PrinterLine(
        text: '¡GRACIAS POR SU COMPRA!',
        alignment: 'center',
        fontSize: 24,
        isBold: true));

    lines.add(PrinterLine(text: '', fontSize: 100));

    return lines;
  }

  static Future<bool> printInvoice({
    required String invoiceNumber,
    required String clientName,
    required String clientRif,
    String? clientAddress,
    required List<Map<String, dynamic>> items,
    required double baseImponible,
    required double montoIva,
    required double total,
    required double tasaCambio,
    double montoExento = 0.0,
    String? metodoPago,
    String? referencia,
    String? authCode,
    String? cardType,
  }) async {
    final lines = buildInvoiceLines(
      invoiceNumber: invoiceNumber,
      clientName: clientName,
      clientRif: clientRif,
      clientAddress: clientAddress,
      items: items,
      baseImponible: baseImponible,
      montoExento: montoExento,
      montoIva: montoIva,
      total: total,
      tasaCambio: tasaCambio,
      metodoPago: metodoPago,
      referencia: referencia,
    );
    return printReceipt(lines: lines);
  }

  static PrinterLine _separator() {
    return PrinterLine(
      text: '------------------------------------------------------------',
      alignment: 'center',
      fontSize: 14,
    );
  }
}
