import 'dart:convert';
import 'package:flutter/foundation.dart';
// import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../core/app_config.dart';
import '../models/fiscal_models.dart';

/// Modelo para una línea de texto a imprimir en la impresora térmica
class PrinterLine {
  final String text;
  final String alignment; // 'left', 'center', 'right'
  final int fontSize;
  final bool isBold;
  final bool isItalic;

  PrinterLine({
    required this.text,
    this.alignment = 'left',
    this.fontSize = 12,
    this.isBold = false,
    this.isItalic = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'alignment': alignment,
      'font_size': fontSize,
      'is_bold': isBold,
      'is_italic': isItalic,
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
    double retencionIva = 0.0,
    String? metodoPago,
    String? referencia,
    String deviceSerial = 'N/A',
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
    lines.add(PrinterLine(
        text: 'NOMBRE: ${clientName.toUpperCase()}',
        alignment: 'left',
        fontSize: 18));
    lines.add(PrinterLine(
        text: 'RIF: ${clientRif.toUpperCase()}',
        alignment: 'left',
        fontSize: 18));
    if (clientAddress != null && clientAddress.trim().isNotEmpty) {
      lines.add(PrinterLine(
          text: 'DIR: ${clientAddress.trim().toUpperCase()}',
          alignment: 'left',
          fontSize: 18));
    }

    lines.add(PrinterLine(
        text: 'FACTURA', alignment: 'center', fontSize: 28, isBold: true));
    lines.add(_separator());

    // 4. Productos
    int itemIdx = 1;
    double totalArticulos = 0;
    for (final item in items) {
      final nombre =
          (item['nombre'] as String? ?? item['name'] as String? ?? 'PRODUCTO')
              .toUpperCase();
      final cant = (item['cantidad'] ?? item['quantity'] ?? 1) as num;

      // Los precios unitarios provienen de la UI/BD en moneda base limpia (USD)
      // y representan el precio base (tax-exclusive). No se debe aplicar divisiones agresivas.
      final precioBaseUSD =
          (item['precio_unitario'] ?? item['price'] ?? 0.0) as double;
      final subtotalUSD = precioBaseUSD * cant.toDouble();

      // Aplicación de la tasa de cambio a nivel de mantisa pura sin redondeos intermedios agresivos
      final precioBs = precioBaseUSD * tasaCambio;
      final subtotalBs = subtotalUSD * tasaCambio;
      totalArticulos += cant.toDouble();

      lines.add(PrinterLine(
          text: '${itemIdx.toString().padLeft(3, '0')} $nombre',
          alignment: 'left',
          fontSize: 20,
          isBold: true));

      // Soportar formato de cantidades enteras y decimales/fraccionarias de forma dinámica
      final String cantStrFormatted =
          cant % 1 == 0 ? cant.toInt().toString() : cant.toStringAsFixed(3);
      final cantStr = '$cantStrFormatted X Bs ${_formatAmount(precioBs)}';
      final montoStr = 'Bs ${_formatAmount(subtotalBs)}';

      // Productos justificados horizontalmente en una misma línea (Estilo Oficial Ubii)
      lines.add(PrinterLine(
          text: '$cantStr%$montoStr', alignment: 'justifed', fontSize: 20));
      itemIdx++;
    }

    lines.add(_separator());

    // 5. Totales (JUSTIFICADOS HORIZONTALMENTE NATIVO - ALINEACIÓN PERFECTA)
    // El subtotal en Bolívares debe coincidir exactamente con la suma en USD multiplicada por la tasa de cambio
    lines.add(PrinterLine(
        text:
            'SUBTTL%Bs ${_formatAmount((baseImponible + montoExento) * tasaCambio)}',
        alignment: 'justifed',
        fontSize: 22));

    if (montoExento > 0) {
      lines.add(PrinterLine(
          text: 'EXENTO%Bs ${_formatAmount(montoExento * tasaCambio)}',
          alignment: 'justifed',
          fontSize: 22));
    }

    lines.add(PrinterLine(
        text: 'BI G16％%Bs ${_formatAmount(baseImponible * tasaCambio)}',
        alignment: 'justifed',
        fontSize: 22));

    lines.add(PrinterLine(
        text: 'IVA G16％%Bs ${_formatAmount(montoIva * tasaCambio)}',
        alignment: 'justifed',
        fontSize: 22));

    // Si existe retención de IVA para un agente de retención fiscal, se refleja simétricamente
    if (retencionIva > 0.0) {
      lines.add(PrinterLine(
          text: 'RETEN. IVA%Bs -${_formatAmount(retencionIva * tasaCambio)}',
          alignment: 'justifed',
          fontSize: 22));
    }

    lines.add(PrinterLine(text: ' ', fontSize: 10));

    lines.add(PrinterLine(
        text: 'TOTAL%Bs ${_formatAmount(total * tasaCambio)}',
        alignment: 'justifed',
        fontSize: 22,
        isBold: true));

    lines.add(_separator());

    // 6. Resumen Fiscal e Info Adicional (JUSTIFICADOS HORIZONTALMENTE NATIVO)
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

    // Pie de página fiscal
    lines.add(PrinterLine(
        text: 'MH%$deviceSerial',
        alignment: 'justifed',
        fontSize: 20,
        isItalic: true));

    lines.add(PrinterLine(text: '', fontSize: 100));

    return lines;
  }

  static Future<String> getDeviceSerial() async {
    // Si está configurado en .env, usar ese
    if (AppConfig.serialDispositivo.isNotEmpty) {
      return AppConfig.serialDispositivo;
    }

    // Si no, intentar obtenerlo de forma nativa
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final String? serial = await _platform.invokeMethod('getDeviceSerial');
        if (serial != null && serial.isNotEmpty) {
          return serial;
        }
      } catch (e) {
        debugPrint('🚨 Error obteniendo serial nativo: $e');
      }
    }
    return 'N/A'; // Valor por defecto si todo falla
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
    double retencionIva = 0.0,
    String? metodoPago,
    String? referencia,
    String? authCode,
    String? cardType,
  }) async {
    // Obtener el serial del dispositivo de forma asíncrona
    final deviceSerial = await getDeviceSerial();

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
      retencionIva: retencionIva,
      metodoPago: metodoPago,
      referencia: referencia,
      deviceSerial: deviceSerial,
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

  /// Separador doble (══) para secciones principales del Reporte X SENIAT
  static PrinterLine _doubleSeparator() {
    return PrinterLine(
      text: '============================================================',
      alignment: 'center',
      fontSize: 14,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // MÉTODO PARA ENVIAR A IMPRESORA TÉRMICA POS VIA HTTP
  // ─────────────────────────────────────────────────────────────────────────────

  /// Enviar datos a impresora térmica POS via HTTP
  /// Formato JSON requerido: {"PaymentID": "string", "Operation": "PRINTER", "Lines": [...]}
  static Future<bool> sendToPrinter({
    required String serverIp,
    required int serverPort,
    required Map<String, dynamic> jsonData,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final url = Uri.parse('http://$serverIp:$serverPort/api/spPayment');

      debugPrint('📤 Enviando a impresora térmica...');
      debugPrint('   URL: $url');
      debugPrint('   JSON: ${jsonEncode(jsonData)}');

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode(jsonData),
          )
          .timeout(timeout);

      debugPrint('📥 Respuesta de impresora: ${response.statusCode}');
      debugPrint('   Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final success = responseData['success'] as bool? ?? false;

        if (success) {
          debugPrint('✅ Impresión enviada exitosamente');
          return true;
        } else {
          debugPrint(
              '❌ Error en respuesta de impresora: ${responseData['message']}');
          return false;
        }
      } else {
        debugPrint('❌ Error HTTP ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('🚨 Error enviando a impresora térmica: $e');
      return false;
    }
  }

  /// Método de diagnóstico para probar conexión con impresora
  static Future<Map<String, dynamic>> testPrinterConnection({
    required String serverIp,
    required int serverPort,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      final url = Uri.parse('http://$serverIp:$serverPort/api/spPayment');

      debugPrint('🔍 Probando conexión con impresora...');
      debugPrint('   URL: $url');

      // Enviar datos de prueba simples
      final testData = {
        'PaymentID': 'TestConnection',
        'Operation': 'PRINTER',
        'Lines': [
          {
            'text': 'PRUEBA DE CONEXIÓN',
            'alignment': 'center',
            'font_size': 24,
            'is_bold': true,
          },
          {
            'text': 'Sistema POS Android',
            'alignment': 'center',
            'font_size': 12,
            'is_bold': false,
          },
        ],
      };

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode(testData),
          )
          .timeout(timeout);

      return {
        'connected': response.statusCode == 200,
        'statusCode': response.statusCode,
        'response': response.body,
        'error': null,
      };
    } catch (e) {
      debugPrint('🚨 Error en prueba de conexión: $e');
      return {
        'connected': false,
        'statusCode': 0,
        'response': null,
        'error': e.toString(),
      };
    }
  }

  static Future<bool> printReporteCierre(ReporteCierre reporte,
      {required double tasaCambio}) async {
    final lines = <PrinterLine>[];
    final now = DateTime.now();
    final fecha =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final hora =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    lines.add(PrinterLine(
        text: 'REPORTE DE CIERRE FISCAL',
        alignment: 'center',
        fontSize: 24,
        isBold: true));
    lines.add(PrinterLine(
        text: 'REPORTE Z', alignment: 'center', fontSize: 28, isBold: true));
    lines.add(_separator());

    lines.add(PrinterLine(
        text: reporte.nombreComercio.toUpperCase(),
        alignment: 'center',
        fontSize: 20,
        isBold: true));
    lines.add(PrinterLine(
        text: reporte.direccionComercio.toUpperCase(),
        alignment: 'center',
        fontSize: 16));
    lines.add(PrinterLine(
        text: 'RIF: ${reporte.rifComercio}',
        alignment: 'center',
        fontSize: 18,
        isBold: true));
    lines.add(_separator());

    lines.add(PrinterLine(
        text: 'Nº REPORTE:%${reporte.numeroReporte}',
        alignment: 'justifed',
        fontSize: 18));
    lines.add(PrinterLine(
        text: 'FECHA: $fecha%HORA: $hora',
        alignment: 'justifed',
        fontSize: 18));
    lines.add(_separator());

    lines.add(PrinterLine(
        text: 'RESUMEN DE OPERACIONES',
        alignment: 'center',
        fontSize: 20,
        isBold: true));
    lines.add(PrinterLine(
        text: 'FACTURAS EMITIDAS:%${reporte.facturasEmitidas}',
        alignment: 'justifed',
        fontSize: 18));
    lines.add(PrinterLine(
        text: 'NOTAS CREDITO:%${reporte.notasCreditoEmitidas}',
        alignment: 'justifed',
        fontSize: 18));
    lines.add(PrinterLine(
        text:
            'TOTAL TRANSC.:%${reporte.facturasEmitidas + reporte.notasCreditoEmitidas}',
        alignment: 'justifed',
        fontSize: 18));
    lines.add(_separator());

    lines.add(PrinterLine(
        text: 'TOTALES POR METODO DE PAGO',
        alignment: 'center',
        fontSize: 20,
        isBold: true));
    lines.add(PrinterLine(
        text:
            'EFECTIVO:%Bs ${_formatAmount(reporte.desgloseEfectivo * tasaCambio)}',
        alignment: 'justifed',
        fontSize: 18));
    lines.add(PrinterLine(
        text:
            'TARJETA:%Bs ${_formatAmount(reporte.desgloseTarjeta * tasaCambio)}',
        alignment: 'justifed',
        fontSize: 18));
    lines.add(PrinterLine(
        text:
            'PAGO MOVIL:%Bs ${_formatAmount(reporte.desglosePagoMovil * tasaCambio)}',
        alignment: 'justifed',
        fontSize: 18));
    lines.add(PrinterLine(
        text: 'OTROS:%Bs ${_formatAmount(reporte.desgloseOtros * tasaCambio)}',
        alignment: 'justifed',
        fontSize: 18));
    lines.add(_separator());

    lines.add(PrinterLine(
        text: 'DISCRIMINACION DE IVA',
        alignment: 'center',
        fontSize: 20,
        isBold: true));
    final baseBs = (reporte.totalVentas - reporte.exento) * tasaCambio;
    final ivaBs = reporte.ivaTotal * tasaCambio;
    final exentoBs = reporte.exento * tasaCambio;

    lines.add(PrinterLine(
        text: 'BASE IMPONIBLE:%Bs ${_formatAmount(baseBs)}',
        alignment: 'justifed',
        fontSize: 18));
    lines.add(PrinterLine(
        text: 'IVA 16%:%Bs ${_formatAmount(ivaBs)}',
        alignment: 'justifed',
        fontSize: 18));
    lines.add(PrinterLine(
        text: 'EXENTO:%Bs ${_formatAmount(exentoBs)}',
        alignment: 'justifed',
        fontSize: 18));
    lines.add(_separator());

    lines.add(PrinterLine(
        text:
            'TOTAL GENERAL%Bs ${_formatAmount(reporte.totalNeto * tasaCambio)}',
        alignment: 'justifed',
        fontSize: 22,
        isBold: true));
    lines.add(_separator());

    // Pie de página del Informe X
    lines.add(PrinterLine(
        text: '** FIN DEL REPORTE Z **',
        alignment: 'center',
        fontSize: 18,
        isBold: true));
    lines.add(PrinterLine(
        text: 'FIRMA CONFORMIDAD ADMINISTRACIÓN',
        alignment: 'center',
        fontSize: 14));
    lines.add(PrinterLine(
        text: '\n\n__________________________',
        alignment: 'center',
        fontSize: 16));

    lines.add(PrinterLine(
        text: 'FIRMA DIGITAL',
        alignment: 'center',
        fontSize: 18,
        isBold: true));
    final String hash = reporte.hashIntegridad ?? 'N/A';
    lines.add(PrinterLine(
        text: hash, alignment: 'center', fontSize: 14, isItalic: true));

    lines.add(PrinterLine(text: '', fontSize: 100));

    return printReceipt(lines: lines);
  }

  static Future<bool> printArqueoCaja(
    ArqueoCaja arqueo, {
    double tasaCambio = 36.50,
    required Map<String, dynamic> datosFiscales,
  }) async {
    final lines = <PrinterLine>[];
    final now = arqueo.fechaArqueo;
    final fecha =
        '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
    final hora =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // ══════════════════════════════════════════════
    // ENCABEZADO DEL REPORTE X (Formato SENIAT)
    // ══════════════════════════════════════════════
    lines.add(_doubleSeparator());
    lines.add(PrinterLine(
        text: 'REPORTE  X', alignment: 'center', fontSize: 24, isBold: true));
    lines.add(_doubleSeparator());

    // Datos fiscales del comercio
    lines.add(PrinterLine(
        text: 'RAZON SOCIAL: ${AppConfig.nombreComercio.toUpperCase()}',
        alignment: 'left',
        fontSize: 18));
    lines.add(PrinterLine(
        text: 'RIF: ${AppConfig.rifComercio}',
        alignment: 'left',
        fontSize: 18));
    lines.add(PrinterLine(
        text: 'DIRECCION: ${AppConfig.direccionComercio.toUpperCase()}',
        alignment: 'left',
        fontSize: 16));
    lines.add(PrinterLine(text: ' ', fontSize: 8));

    lines.add(PrinterLine(
        text: 'FECHA: $fecha%HORA: $hora',
        alignment: 'justifed',
        fontSize: 18));
    lines.add(_doubleSeparator());

    // ══════════════════════════════════════════════
    // REGISTRO DE VENTAS PARCIALES
    // ══════════════════════════════════════════════
    lines.add(PrinterLine(
        text: 'REGISTRO DE VENTAS PARCIALES',
        alignment: 'left',
        fontSize: 18,
        isBold: true));
    lines.add(_separator());

    // --- Alícuota General (G) 16% ---
    final double baseG = (datosFiscales['base_g'] as num? ?? 0.0).toDouble();
    final double ivaG = (datosFiscales['iva_g'] as num? ?? 0.0).toDouble();
    lines.add(PrinterLine(
        text: 'VENTA BRUTA G 16.00%%BS ${_formatAmount(baseG)}',
        alignment: 'justifed',
        fontSize: 18));
    lines.add(PrinterLine(
        text: 'IMPUESTO G 16.00%%BS ${_formatAmount(ivaG)}',
        alignment: 'justifed',
        fontSize: 18));
    lines.add(PrinterLine(text: ' ', fontSize: 6));

    // --- Alícuota Reducida (R) 8% ---
    // Nota: En el código, base_a/iva_a corresponden a tasa_iva=8.0 (Reducida)
    final double baseR = (datosFiscales['base_a'] as num? ?? 0.0).toDouble();
    final double ivaR = (datosFiscales['iva_a'] as num? ?? 0.0).toDouble();
    lines.add(PrinterLine(
        text: 'VENTA BRUTA R 8.00%%BS ${_formatAmount(baseR)}',
        alignment: 'justifed',
        fontSize: 18));
    lines.add(PrinterLine(
        text: 'IMPUESTO R 8.00%%BS ${_formatAmount(ivaR)}',
        alignment: 'justifed',
        fontSize: 18));
    lines.add(PrinterLine(text: ' ', fontSize: 6));

    // --- Alícuota Adicional (A) ---
    // Nota: En el código, base_r/iva_r corresponden a tasa_iva=31.0 (Adicional/Lujo)
    final double baseA = (datosFiscales['base_r'] as num? ?? 0.0).toDouble();
    final double ivaA = (datosFiscales['iva_r'] as num? ?? 0.0).toDouble();
    final String tasaAdicional = baseA > 0 ? '31.00' : '22.00';
    lines.add(PrinterLine(
        text: 'VENTA BRUTA A $tasaAdicional%%BS ${_formatAmount(baseA)}',
        alignment: 'justifed',
        fontSize: 18));
    lines.add(PrinterLine(
        text: 'IMPUESTO A $tasaAdicional%%BS ${_formatAmount(ivaA)}',
        alignment: 'justifed',
        fontSize: 18));
    lines.add(PrinterLine(text: ' ', fontSize: 6));

    // --- Exento ---
    final double exento = (datosFiscales['exento'] as num? ?? 0.0).toDouble();
    lines.add(PrinterLine(
        text: 'EXENTO 0.00%%BS ${_formatAmount(exento)}',
        alignment: 'justifed',
        fontSize: 18));
    lines.add(PrinterLine(text: ' ', fontSize: 6));

    // ── Totales ──
    lines.add(_separator());
    final double totalBaseImponible = baseG + baseR + baseA;
    final double totalImpuesto = ivaG + ivaR + ivaA;
    final double totalNetoAcumulado =
        totalBaseImponible + totalImpuesto + exento;

    lines.add(PrinterLine(
        text: 'TOTAL BASE IMPONIBLE%BS ${_formatAmount(totalBaseImponible)}',
        alignment: 'justifed',
        fontSize: 18,
        isBold: true));
    lines.add(PrinterLine(
        text: 'TOTAL IMPUESTO%BS ${_formatAmount(totalImpuesto)}',
        alignment: 'justifed',
        fontSize: 18,
        isBold: true));
    lines.add(PrinterLine(
        text: 'TOTAL NETO ACUMULADO%BS ${_formatAmount(totalNetoAcumulado)}',
        alignment: 'justifed',
        fontSize: 18,
        isBold: true));
    lines.add(_doubleSeparator());

    // ══════════════════════════════════════════════
    // CONTADORES DE AUDITORIA (TURNO)
    // ══════════════════════════════════════════════
    lines.add(PrinterLine(
        text: 'CONTADORES DE AUDITORIA (TURNO)',
        alignment: 'center',
        fontSize: 18,
        isBold: true));
    lines.add(_separator());

    // Documentos Fiscales (Facturas)
    final int cantFacturas = datosFiscales['cantidad_facturas'] as int? ?? 0;
    final String ultimaFactura =
        datosFiscales['ultimo_ticket'] as String? ?? '00000000';
    lines.add(PrinterLine(
        text:
            'CANT. DOC. FISCALES (FAC):%${cantFacturas.toString().padLeft(4, '0')}',
        alignment: 'justifed',
        fontSize: 18));
    lines.add(PrinterLine(
        text: 'ULTIMA FACTURA:%${ultimaFactura.padLeft(8, '0')}',
        alignment: 'justifed',
        fontSize: 18));
    lines.add(PrinterLine(text: ' ', fontSize: 6));

    // Notas de Crédito
    final int cantNc = datosFiscales['cantidad_nc'] as int? ?? 0;
    final String ultimaNc = datosFiscales['ultima_nc'] as String? ?? '00000000';
    lines.add(PrinterLine(
        text:
            'CANT. NOTAS DE CREDITO (NCR):%${cantNc.toString().padLeft(4, '0')}',
        alignment: 'justifed',
        fontSize: 18));
    lines.add(PrinterLine(
        text: 'ULTIMA NOTA CREDITO:%${ultimaNc.padLeft(8, '0')}',
        alignment: 'justifed',
        fontSize: 18));
    lines.add(PrinterLine(text: ' ', fontSize: 6));

    // Notas de Débito
    final int cantNdb = datosFiscales['cantidad_ndb'] as int? ?? 0;
    final String ultimaNdb =
        datosFiscales['ultima_ndb'] as String? ?? '00000000';
    lines.add(PrinterLine(
        text:
            'CANT. NOTAS DE DEBITO (NDB):%${cantNdb.toString().padLeft(4, '0')}',
        alignment: 'justifed',
        fontSize: 18));
    lines.add(PrinterLine(
        text: 'ULTIMA NOTA DEBITO:%${ultimaNdb.padLeft(8, '0')}',
        alignment: 'justifed',
        fontSize: 18));
    lines.add(PrinterLine(text: ' ', fontSize: 10));

    // ══════════════════════════════════════════════
    // AUDITORIA INTERNA DE ARQUEO (Datos operativos)
    // ══════════════════════════════════════════════
    lines.add(PrinterLine(text: ' ', fontSize: 10));
    lines.add(_separator());
    lines.add(PrinterLine(
        text: 'AUDITORIA DE ARQUEO',
        alignment: 'center',
        fontSize: 18,
        isBold: true));
    lines.add(_separator());

    lines.add(PrinterLine(
        text:
            'EFECTIVO BS DECLARADO:%Bs. ${_formatAmount(arqueo.conteo.efectivoBs)}',
        alignment: 'justifed',
        fontSize: 18));
    lines.add(PrinterLine(
        text:
            'EFECTIVO USD DECLARADO:%\$ ${_formatAmount(arqueo.conteo.efectivoUsd)}',
        alignment: 'justifed',
        fontSize: 18));
    lines.add(PrinterLine(
        text:
            'EFECTIVO EUR DECLARADO:%€ ${_formatAmount(arqueo.conteo.efectivoEur)}',
        alignment: 'justifed',
        fontSize: 18));
    lines.add(PrinterLine(
        text:
            'EFECTIVO COP DECLARADO:%COP ${_formatAmount(arqueo.conteo.efectivoCop)}',
        alignment: 'justifed',
        fontSize: 18));

    lines.add(PrinterLine(
        text:
            'TARJETA:%Bs. ${_formatAmount(arqueo.totalTarjetaDeclarado * tasaCambio)}',
        alignment: 'justifed',
        fontSize: 18));
    lines.add(PrinterLine(
        text:
            'PAGO MOVIL:%Bs. ${_formatAmount(arqueo.totalPagoMovilDeclarado * tasaCambio)}',
        alignment: 'justifed',
        fontSize: 18));
    lines.add(PrinterLine(
        text:
            'OTROS:%Bs. ${_formatAmount(arqueo.totalOtrosDeclarado * tasaCambio)}',
        alignment: 'justifed',
        fontSize: 18));

    final String statusText =
        arqueo.cuadrado ? 'CAJA CUADRADA' : 'CAJA DESCUADRADA';
    lines.add(_separator());
    lines.add(PrinterLine(
        text: statusText, alignment: 'center', fontSize: 20, isBold: true));
    lines.add(PrinterLine(
        text:
            'DIF. TOTAL:%Bs. ${_formatAmount(arqueo.diferenciaTotal * tasaCambio)}',
        alignment: 'justifed',
        fontSize: 20,
        isBold: !arqueo.cuadrado));

    if (arqueo.observaciones != null && arqueo.observaciones!.isNotEmpty) {
      lines.add(_separator());
      lines.add(PrinterLine(
          text: 'OBSERVACIONES:',
          alignment: 'left',
          fontSize: 16,
          isBold: true));
      lines.add(PrinterLine(
          text: arqueo.observaciones!, alignment: 'left', fontSize: 16));
    }

    // Pie de página del Informe X
    lines.add(_separator());
    lines.add(PrinterLine(
        text: '** FIN DEL REPORTE X **',
        alignment: 'center',
        fontSize: 18,
        isBold: true));
    lines.add(PrinterLine(
        text: 'FIRMA CONFORMIDAD ADMINISTRACIÓN',
        alignment: 'center',
        fontSize: 14));
    lines.add(PrinterLine(
        text: '\n\n__________________________',
        alignment: 'center',
        fontSize: 16));
    lines.add(PrinterLine(text: '', fontSize: 100));

    return printReceipt(lines: lines);
  }
}
