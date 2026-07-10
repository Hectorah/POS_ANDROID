import 'dart:convert';
import 'package:flutter/foundation.dart';
// import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../core/app_config.dart';
import '../database/db_helper.dart';
import '../models/fiscal_models.dart';
import 'fiscal_service.dart';

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
      {required double tasaCambio, Map<String, dynamic>? resumenFiscal}) async {
    if (resumenFiscal == null) {
      try {
        resumenFiscal = await FiscalService.instance
            .obtenerResumenFiscalSesion(reporte.sesionFiscalId);
      } catch (e) {
        debugPrint(
            '⚠️ Error auto-obteniendo resumen fiscal para Reporte Z: $e');
      }
    }

    final lines = <PrinterLine>[];
    final now = DateTime.now();
    final fecha =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final hora =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    final String cleanRif = AppConfig.rifComercio
        .replaceAll(' ', '')
        .replaceAll('-', '')
        .toUpperCase();
    final String codOperacion = (reporte.id ?? 1).toString().padLeft(6, '0');
    final String nroZ = (reporte.id ?? 1).toString().padLeft(6, '0');

    // --- ENCABEZADO ---
    lines.add(PrinterLine(
        text: 'SENIAT', alignment: 'center', fontSize: 22, isBold: true));
    lines.add(PrinterLine(
        text: AppConfig.nombreComercio.toUpperCase(),
        alignment: 'center',
        fontSize: 18));
    lines.add(PrinterLine(
        text: AppConfig.direccionComercio.toUpperCase(),
        alignment: 'center',
        fontSize: 14));
    if (AppConfig.telefonoComercio.isNotEmpty) {
      lines.add(PrinterLine(
          text: AppConfig.telefonoComercio, alignment: 'center', fontSize: 14));
    }
    lines.add(PrinterLine(
        text: 'RIF:$cleanRif',
        alignment: 'center',
        fontSize: 16,
        isBold: true));
    lines.add(PrinterLine(
        text: '$fecha $hora   COD:$codOperacion  "Z" no. :$nroZ',
        alignment: 'center',
        fontSize: 16));
    lines.add(PrinterLine(
        text: 'REPORTE "Z"', alignment: 'center', fontSize: 22, isBold: true));
    lines.add(PrinterLine(
        text: 'Operaciones del: $fecha', alignment: 'center', fontSize: 16));

    // --- CONTADORES ---
    final int contNoFiscalHist =
        resumenFiscal?['cont_no_fiscal_hist'] as int? ?? 0;
    final int contFactHist = resumenFiscal?['cont_fact_hist'] as int? ?? 0;
    final int contNcHist = resumenFiscal?['cont_nc_hist'] as int? ?? 0;
    final int noFiscalSesion = resumenFiscal?['no_fiscal_sesion'] as int? ?? 0;
    final int cantFact =
        resumenFiscal?['cant_facturas'] as int? ?? reporte.facturasEmitidas;
    final int cantNc =
        resumenFiscal?['cant_nc'] as int? ?? reporte.notasCreditoEmitidas;

    lines.add(PrinterLine(
        text: '-----------------CONTADORES-----------------',
        alignment: 'center',
        fontSize: 14));
    lines.add(PrinterLine(
        text:
            'Contador General de Operacion No Fiscal: %${contNoFiscalHist.toString().padLeft(6, '0')}',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text:
            'Contador de Factura:                     %${contFactHist.toString().padLeft(6, '0')}',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text:
            'Contador de Nota de Credito:             %${contNcHist.toString().padLeft(6, '0')}',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text:
            'Operaciones No Fiscales desde la Ultima Z %${noFiscalSesion.toString().padLeft(6, '0')}',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text:
            'Facturas desde la Ultima Z              %${cantFact.toString().padLeft(6, '0')}',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text:
            'Notas de Credito desde la Ultima Z      %${cantNc.toString().padLeft(6, '0')}',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'RMF desde la Ultima Z                    %000000',
        alignment: 'justifed',
        fontSize: 15));

    // --- TOTALES DEL DÍA ---
    final double totalVentaBruta =
        (resumenFiscal?['total_facturado'] as num? ?? reporte.totalVentas)
                .toDouble() *
            tasaCambio;
    final double totalNcVal =
        (resumenFiscal?['total_nc'] as num? ?? 0.0).toDouble() * tasaCambio;
    final double totalVentaNeta = totalVentaBruta - totalNcVal;

    lines.add(PrinterLine(
        text: '----------------TOTALES DEL DIA----------------',
        alignment: 'center',
        fontSize: 14));
    lines.add(PrinterLine(
        text: 'VENTA BRUTA DIARIA:%${_formatAmount(totalVentaBruta)}',
        alignment: 'justifed',
        fontSize: 16));
    lines.add(PrinterLine(
        text: 'DESCUENTOS:%0,00', alignment: 'justifed', fontSize: 16));
    lines.add(PrinterLine(
        text: 'NOTAS DE CREDITO:%${_formatAmount(totalNcVal)}',
        alignment: 'justifed',
        fontSize: 16));
    lines.add(PrinterLine(
        text: 'VENTA NETA:%${_formatAmount(totalVentaNeta)}',
        alignment: 'justifed',
        fontSize: 16));

    // --- RESUMEN TRIBUTADOS ---
    final double base16F =
        (resumenFiscal?['base_16_facturas'] as num? ?? 0.0).toDouble() *
            tasaCambio;
    final double iva16F =
        (resumenFiscal?['iva_16_facturas'] as num? ?? 0.0).toDouble() *
            tasaCambio;
    final double base8F =
        (resumenFiscal?['base_8_facturas'] as num? ?? 0.0).toDouble() *
            tasaCambio;
    final double iva8F =
        (resumenFiscal?['iva_8_facturas'] as num? ?? 0.0).toDouble() *
            tasaCambio;
    final double exentoF =
        (resumenFiscal?['exento_facturas'] as num? ?? 0.0).toDouble() *
            tasaCambio;

    final double base16Nc =
        (resumenFiscal?['base_16_nc'] as num? ?? 0.0).toDouble() * tasaCambio;
    final double iva16Nc =
        (resumenFiscal?['iva_16_nc'] as num? ?? 0.0).toDouble() * tasaCambio;
    final double base8Nc =
        (resumenFiscal?['base_8_nc'] as num? ?? 0.0).toDouble() * tasaCambio;
    final double iva8Nc =
        (resumenFiscal?['iva_8_nc'] as num? ?? 0.0).toDouble() * tasaCambio;
    final double exentoNc =
        (resumenFiscal?['exento_nc'] as num? ?? 0.0).toDouble() * tasaCambio;

    final double sumaVentasValor = base16F + base8F + exentoF;
    final double sumaVentasImpuesto = iva16F + iva8F;
    final double sumaNcValor = base16Nc + base8Nc + exentoNc;
    final double sumaNcImpuesto = iva16Nc + iva8Nc;

    lines.add(PrinterLine(
        text: '-----------------Resumen Tributados-----------------',
        alignment: 'center',
        fontSize: 14));
    lines.add(PrinterLine(
        text: 'Tot.      Valor Acumulado(Bs )     Impuesto(Bs )',
        alignment: 'center',
        fontSize: 14));
    lines.add(PrinterLine(
        text:
            'Tributados%${_formatAmount(base16F + base8F)}%${_formatAmount(iva16F + iva8F)}',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'Exentos%${_formatAmount(exentoF)}',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'Percibidos%0,00', alignment: 'justifed', fontSize: 15));
    lines.add(PrinterLine(
        text:
            'Notas de Credito%${_formatAmount(sumaNcValor)}%${_formatAmount(sumaNcImpuesto)}',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text:
            'Suma:%${_formatAmount(sumaVentasValor)}%${_formatAmount(sumaVentasImpuesto)}',
        alignment: 'justifed',
        fontSize: 15,
        isBold: true));

    // --- TOTALES POR BASE IMPONIBLE ---
    lines.add(PrinterLine(
        text: '--------------Totales Por Base Imponible--------------',
        alignment: 'center',
        fontSize: 14));
    lines.add(PrinterLine(
        text: 'IGTF03,00 =%           0,00 IGTF 03,00 =%        0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'Exentos =%             ${_formatAmount(exentoF)}',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'Percibidos =%           0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text:
            'BI G16,00 =% ${_formatAmount(base16F)}%IVA G16,00 =% ${_formatAmount(iva16F)}',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text:
            'BI R08,00 =% ${_formatAmount(base8F)}%IVA R08,00 =% ${_formatAmount(iva8F)}',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'BI A31,00 =%           0,00 IVA A31,00 =%        0,00',
        alignment: 'justifed',
        fontSize: 15));

    // --- NOTAS DE CRÉDITO Y/O DEVOLUCIONES ---
    lines.add(PrinterLine(
        text: '-----------Notas de Credito y/o Devoluciones-----------',
        alignment: 'center',
        fontSize: 14));
    lines.add(PrinterLine(
        text: 'IGTF03,00 =%           0,00 IGTF 03,00 =%        0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'Exentos =%              ${_formatAmount(exentoNc)}',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'Percibidos =%           0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text:
            'BI G16,00 =% ${_formatAmount(base16Nc)}%IVA G16,00 =% ${_formatAmount(iva16Nc)}',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text:
            'BI R08,00 =% ${_formatAmount(base8Nc)}%IVA R08,00 =% ${_formatAmount(iva8Nc)}',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'BI A31,00 =%           0,00 IVA A31,00 =%        0,00',
        alignment: 'justifed',
        fontSize: 15));

    // --- ÚLTIMOS DOCUMENTOS ---
    final ultFact = resumenFiscal?['ult_fact'] as Map<String, dynamic>?;
    String factNumStr = '000000';
    String factFechaStr = '00/00/0000';
    double factTotalBs = 0.0;
    if (ultFact != null) {
      final String numCtrl = ultFact['numero_control'] as String? ?? '';
      factNumStr = numCtrl.replaceAll('FAC-', '').padLeft(6, '0');
      final DateTime? fCreacion =
          DateTime.tryParse(ultFact['fecha_creacion'] as String? ?? '');
      if (fCreacion != null) {
        factFechaStr =
            '${fCreacion.day.toString().padLeft(2, '0')}/${fCreacion.month.toString().padLeft(2, '0')}/${fCreacion.year}';
      }
      factTotalBs = (ultFact['total'] as num? ?? 0.0).toDouble() * tasaCambio;
    }

    final ultArq = resumenFiscal?['ult_arqueo'] as Map<String, dynamic>?;
    String arqNumStr = '000000';
    String arqFechaStr = '00/00/0000';
    if (ultArq != null) {
      final rawNum = ultArq['numero_arqueo'];
      if (rawNum is int) {
        arqNumStr = rawNum.toString().padLeft(6, '0');
      } else if (rawNum is String) {
        arqNumStr = rawNum.replaceAll('ARQ-', '').padLeft(6, '0');
      } else {
        arqNumStr = (rawNum ?? '0').toString().padLeft(6, '0');
      }
      final DateTime? fArq =
          DateTime.tryParse(ultArq['fecha_arqueo'] as String? ?? '');
      if (fArq != null) {
        arqFechaStr =
            '${fArq.day.toString().padLeft(2, '0')}/${fArq.month.toString().padLeft(2, '0')}/${fArq.year}';
      }
    }

    lines.add(PrinterLine(
        text: '-----------------Ultimos Documentos-----------------',
        alignment: 'center',
        fontSize: 14));
    lines.add(PrinterLine(
        text:
            'Ult. Factura $factNumStr $factFechaStr Bs%${_formatAmount(factTotalBs)}',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'Doc. No Fiscal $arqNumStr $arqFechaStr  Bs%0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'Reporte Z      $nroZ $fecha',
        alignment: 'justifed',
        fontSize: 15));

    // --- DESCUENTOS POR BASE IMPONIBLE ---
    lines.add(PrinterLine(
        text: '-------------Descuentos Por Base Imponible-------------',
        alignment: 'center',
        fontSize: 14));
    lines.add(PrinterLine(
        text: 'Exentos =%           0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'Percibidos =%           0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'BI G16,00 =%           0,00 IVA G16,00 =%        0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'BI R08,00 =%           0,00 IVA R08,00 =%        0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'BI A31,00 =%           0,00 IVA A31,00 =%        0,00',
        alignment: 'justifed',
        fontSize: 15));

    // --- ANULACIONES POR BASE IMPONIBLE ---
    final double baseAnulada =
        (resumenFiscal?['base_anulada'] as num? ?? 0.0).toDouble() * tasaCambio;
    final double ivaAnulada =
        (resumenFiscal?['iva_anulada'] as num? ?? 0.0).toDouble() * tasaCambio;
    final double exentoAnulada =
        (resumenFiscal?['exento_anulada'] as num? ?? 0.0).toDouble() *
            tasaCambio;

    lines.add(PrinterLine(
        text: '-------------Anulaciones Por Base Imponible-------------',
        alignment: 'center',
        fontSize: 14));
    lines.add(PrinterLine(
        text: 'IGTF03,00 =%           0,00 IGTF 03,00 =%        0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'Exentos =%              ${_formatAmount(exentoAnulada)}',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'Percibidos =%           0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text:
            'BI G16,00 =% ${_formatAmount(baseAnulada)}%IVA G16,00 =% ${_formatAmount(ivaAnulada)}',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'BI R08,00 =%           0,00 IVA R08,00 =%        0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'BI A31,00 =%           0,00 IVA A31,00 =%        0,00',
        alignment: 'justifed',
        fontSize: 15));

    // --- INCREMENTOS POR BASE IMPONIBLE ---
    lines.add(PrinterLine(
        text: '-------------Incrementos Por Base Imponible-------------',
        alignment: 'center',
        fontSize: 14));
    lines.add(PrinterLine(
        text: 'Exentos =%              0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'Percibidos =%           0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'BI G16,00 =%           0,00 IVA G16,00 =%        0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'BI R08,00 =%           0,00 IVA R08,00 =%        0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'BI A31,00 =%           0,00 IVA A31,00 =%        0,00',
        alignment: 'justifed',
        fontSize: 15));

    // --- TOTALIZADORES NO FISCALES ---
    final double fondoCajaBs = (reporte.totalVentas - reporte.totalNeto) *
        tasaCambio; // aproximación o fondo caja inicial
    lines.add(PrinterLine(
        text: '--------------TOTALIZADORES NO FISCALES--------------',
        alignment: 'center',
        fontSize: 14));
    lines.add(PrinterLine(
        text: '29 Retirada de caja   : 0000%0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text:
            '30 Fondo de caja      : 0000%${_formatAmount(fondoCajaBs > 0 ? fondoCajaBs : 0.0)}',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'Total de Oper. No Fiscales Bs%0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'RECARGO   NO FISCAL:%0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'DESCUENTO NO FISCAL:%0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'ANULACION NO FISCAL:%0,00',
        alignment: 'justifed',
        fontSize: 15));

    // --- INFORME GERENCIAL ---
    lines.add(PrinterLine(
        text: '-------------------INFORME GERENCIAL-------------------',
        alignment: 'center',
        fontSize: 14));
    lines.add(PrinterLine(
        text: '01 Informe General%0000', alignment: 'justifed', fontSize: 15));
    lines.add(PrinterLine(
        text: '02 Informe de Trans.%0000',
        alignment: 'justifed',
        fontSize: 15));

    // --- FORMAS DE PAGO (montos reales del reporte) ---
    lines.add(PrinterLine(
        text: '---------------------FORMAS DE PAGO---------------------',
        alignment: 'center',
        fontSize: 14));

    // Obtener el monto declarado del efectivo desde el arqueo de la sesión
    double efectivoDeclaradoZ = reporte.desgloseEfectivo;
    try {
      final dbZ = await DbHelper.instance.database;
      final arqueoResultZ = await dbZ.rawQuery('''
        SELECT total_efectivo_usd FROM arqueos_caja
        WHERE sesion_fiscal_id = ? ORDER BY id DESC LIMIT 1
      ''', [reporte.sesionFiscalId]);
      if (arqueoResultZ.isNotEmpty) {
        efectivoDeclaradoZ =
            (arqueoResultZ.first['total_efectivo_usd'] as num? ??
                    reporte.desgloseEfectivo)
                .toDouble();
      }
    } catch (e) {
      debugPrint('⚠️ Error obteniendo arqueo para formas de pago Z: $e');
    }

    // Método 01: Efectivo - monto declarado en el arqueo
    final double efTotalZ = efectivoDeclaradoZ * tasaCambio;
    lines.add(PrinterLine(
        text: '01 Efectivo                 (0001)%${_formatAmount(efTotalZ)}',
        alignment: 'justifed',
        fontSize: 15));

    // Método 02: Tarjeta - monto real del sistema
    final double tjTotalZ = reporte.desgloseTarjeta * tasaCambio;
    if (tjTotalZ > 0) {
      lines.add(PrinterLine(
          text: '02 Tarjeta                  (0001)%${_formatAmount(tjTotalZ)}',
          alignment: 'justifed',
          fontSize: 15));
    }

    // Método 03: Pago Móvil - monto real del sistema
    final double pmTotalZ = reporte.desglosePagoMovil * tasaCambio;
    if (pmTotalZ > 0) {
      lines.add(PrinterLine(
          text: '03 Pago Movil               (0001)%${_formatAmount(pmTotalZ)}',
          alignment: 'justifed',
          fontSize: 15));
    }

    // Método 04: Otros - monto real del sistema
    final double otTotalZ = reporte.desgloseOtros * tasaCambio;
    if (otTotalZ > 0) {
      lines.add(PrinterLine(
          text: '04 Otros                    (0001)%${_formatAmount(otTotalZ)}',
          alignment: 'justifed',
          fontSize: 15));
    }

    // --- PIE DE PÁGINA FISCAL (datos reales del equipo configurado en .env) ---
    final int rzRestantes =
        (AppConfig.rangoMaximoNumeroControl) - (reporte.id ?? 0);
    final String rawHash = reporte.hashIntegridad ?? '';
    final String printHash = rawHash.isNotEmpty
        ? (rawHash.length > 21
            ? rawHash.substring(0, 21).toUpperCase()
            : rawHash.toUpperCase())
        : '';

    // Construir línea de marca/modelo del equipo fiscal (solo si hay datos)
    final String marcaModelo = [
      AppConfig.marcaEquipoFiscal,
      AppConfig.modeloEquipoFiscal,
    ].where((s) => s.isNotEmpty).join('  ');

    // Construir línea de caja/tienda (solo si hay datos)
    final String cajaPart =
        AppConfig.numeroCaja.isNotEmpty ? 'CAJA:${AppConfig.numeroCaja}' : '';
    final String tiendaPart = AppConfig.numeroTienda.isNotEmpty
        ? 'TIENDA:${AppConfig.numeroTienda}'
        : '';
    final String cajaTienda =
        [cajaPart, tiendaPart].where((s) => s.isNotEmpty).join('  ');

    // Construir línea de versión/IGM (solo si hay datos)
    final String versionPart = AppConfig.versionFirmware.isNotEmpty
        ? 'VERSION:${AppConfig.versionFirmware}'
        : '';
    final String igmPart =
        AppConfig.codigoIGM.isNotEmpty ? 'IGM${AppConfig.codigoIGM}' : '';
    final String versionIGM =
        [versionPart, igmPart].where((s) => s.isNotEmpty).join('  ');

    lines.add(PrinterLine(
        text: '------------------------------------------------------',
        alignment: 'center',
        fontSize: 14));
    lines.add(PrinterLine(
        text:
            'RZ restantes: ${rzRestantes > 0 ? rzRestantes.toString().padLeft(4, '0') : '0000'}',
        alignment: 'left',
        fontSize: 15));
    if (marcaModelo.isNotEmpty) {
      lines
          .add(PrinterLine(text: marcaModelo, alignment: 'left', fontSize: 14));
    }
    if (printHash.isNotEmpty) {
      final hashLine =
          cajaTienda.isNotEmpty ? '$printHash  $cajaTienda' : printHash;
      lines.add(PrinterLine(text: hashLine, alignment: 'left', fontSize: 14));
    } else if (cajaTienda.isNotEmpty) {
      lines.add(PrinterLine(text: cajaTienda, alignment: 'left', fontSize: 14));
    }
    if (versionIGM.isNotEmpty) {
      lines.add(PrinterLine(text: versionIGM, alignment: 'left', fontSize: 14));
    }

    lines.add(PrinterLine(text: 'MH', alignment: 'left', fontSize: 18));

    lines.add(PrinterLine(text: '', fontSize: 100));

    return printReceipt(lines: lines);
  }

  static Future<bool> printArqueoCaja(
    ArqueoCaja arqueo, {
    double tasaCambio = 36.50,
    required Map<String, dynamic> datosFiscales,
  }) async {
    // Auto-cargar resumen fiscal si no viene incluido
    if (datosFiscales['resumen_fiscal'] == null) {
      try {
        final resumen = await FiscalService.instance
            .obtenerResumenFiscalSesion(arqueo.sesionFiscalId);
        datosFiscales['resumen_fiscal'] = resumen;
      } catch (e) {
        debugPrint(
            '⚠️ Error auto-obteniendo resumen fiscal para Reporte X: $e');
      }
    }

    final lines = <PrinterLine>[];
    final now = arqueo.fechaArqueo;
    final fecha =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final hora =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    final String cleanRif = AppConfig.rifComercio
        .replaceAll(' ', '')
        .replaceAll('-', '')
        .toUpperCase();
    final String codOperacion = (arqueo.id ?? 1).toString().padLeft(6, '0');

    // ═══════════════════════════════════════
    // ENCABEZADO
    // ═══════════════════════════════════════
    lines.add(PrinterLine(
        text: 'SENIAT', alignment: 'center', fontSize: 22, isBold: true));
    lines.add(PrinterLine(
        text: AppConfig.nombreComercio.toUpperCase(),
        alignment: 'center',
        fontSize: 18));
    lines.add(PrinterLine(
        text: AppConfig.direccionComercio.toUpperCase(),
        alignment: 'center',
        fontSize: 14));
    if (AppConfig.telefonoComercio.isNotEmpty) {
      lines.add(PrinterLine(
          text: AppConfig.telefonoComercio, alignment: 'center', fontSize: 14));
    }
    lines.add(PrinterLine(
        text: 'RIF:$cleanRif',
        alignment: 'center',
        fontSize: 16,
        isBold: true));
    lines.add(PrinterLine(
        text: '$fecha $hora   COD:$codOperacion',
        alignment: 'center',
        fontSize: 16));
    lines.add(PrinterLine(
        text: 'LECTURA X', alignment: 'center', fontSize: 22, isBold: true));

    // ═══════════════════════════════════════
    // CONTADORES
    // ═══════════════════════════════════════
    final resumenFiscal =
        datosFiscales['resumen_fiscal'] as Map<String, dynamic>?;
    final int contNoFiscalHist =
        resumenFiscal?['cont_no_fiscal_hist'] as int? ?? 0;
    final int contFactHist = resumenFiscal?['cont_fact_hist'] as int? ?? 0;
    final int contNcHist = resumenFiscal?['cont_nc_hist'] as int? ?? 0;
    final int noFiscalSesion = resumenFiscal?['no_fiscal_sesion'] as int? ?? 0;
    final int cantFact = resumenFiscal?['cant_facturas'] as int? ??
        (datosFiscales['cantidad_facturas'] as int? ?? 0);
    final int cantNc = resumenFiscal?['cant_nc'] as int? ??
        (datosFiscales['cantidad_nc'] as int? ?? 0);

    lines.add(PrinterLine(
        text: '-----------------CONTADORES-----------------',
        alignment: 'center',
        fontSize: 14));
    lines.add(PrinterLine(
        text:
            'Contador General de Operacion No Fiscal: %${contNoFiscalHist.toString().padLeft(6, '0')}',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text:
            'Contador de Factura:                     %${contFactHist.toString().padLeft(6, '0')}',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text:
            'Contador de Nota de Credito:             %${contNcHist.toString().padLeft(6, '0')}',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text:
            'Operaciones No Fiscales desde la Ultima Z %${noFiscalSesion.toString().padLeft(6, '0')}',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text:
            'Facturas desde la Ultima Z              %${cantFact.toString().padLeft(6, '0')}',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text:
            'Notas de Credito desde la Ultima Z%      %${cantNc.toString().padLeft(6, '0')}',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'RMF desde la Ultima Z                    %000000',
        alignment: 'justifed',
        fontSize: 15));

    // ═══════════════════════════════════════
    // TOTALES DEL DÍA
    // ═══════════════════════════════════════
    final double totalVentaBruta = (resumenFiscal?['total_facturado'] as num? ??
                (datosFiscales['total_ventas'] as num? ?? 0.0))
            .toDouble() *
        tasaCambio;
    final double totalNcVal = (resumenFiscal?['total_nc'] as num? ??
                (datosFiscales['devoluciones'] as num? ?? 0.0))
            .toDouble() *
        tasaCambio;
    final double totalVentaNeta = totalVentaBruta - totalNcVal;

    lines.add(PrinterLine(
        text: '----------------TOTALES DEL DIA----------------',
        alignment: 'center',
        fontSize: 14));
    lines.add(PrinterLine(
        text: 'VENTA BRUTA DIARIA:%${_formatAmount(totalVentaBruta)}',
        alignment: 'justifed',
        fontSize: 16));
    lines.add(PrinterLine(
        text: 'DESCUENTOS:%0,00', alignment: 'justifed', fontSize: 16));
    lines.add(PrinterLine(
        text: 'NOTAS DE CREDITO:%${_formatAmount(totalNcVal)}',
        alignment: 'justifed',
        fontSize: 16));
    lines.add(PrinterLine(
        text: 'VENTA NETA:%${_formatAmount(totalVentaNeta)}',
        alignment: 'justifed',
        fontSize: 16));

    // ═══════════════════════════════════════
    // RESUMEN TRIBUTADOS
    // ═══════════════════════════════════════
    final double base16F =
        (resumenFiscal?['base_16_facturas'] as num? ?? 0.0).toDouble() *
            tasaCambio;
    final double iva16F =
        (resumenFiscal?['iva_16_facturas'] as num? ?? 0.0).toDouble() *
            tasaCambio;
    final double base8F =
        (resumenFiscal?['base_8_facturas'] as num? ?? 0.0).toDouble() *
            tasaCambio;
    final double iva8F =
        (resumenFiscal?['iva_8_facturas'] as num? ?? 0.0).toDouble() *
            tasaCambio;
    final double exentoF =
        (resumenFiscal?['exento_facturas'] as num? ?? 0.0).toDouble() *
            tasaCambio;
    final double base16Nc =
        (resumenFiscal?['base_16_nc'] as num? ?? 0.0).toDouble() * tasaCambio;
    final double iva16Nc =
        (resumenFiscal?['iva_16_nc'] as num? ?? 0.0).toDouble() * tasaCambio;
    final double base8Nc =
        (resumenFiscal?['base_8_nc'] as num? ?? 0.0).toDouble() * tasaCambio;
    final double iva8Nc =
        (resumenFiscal?['iva_8_nc'] as num? ?? 0.0).toDouble() * tasaCambio;
    final double exentoNc =
        (resumenFiscal?['exento_nc'] as num? ?? 0.0).toDouble() * tasaCambio;
    final double baseAnulada =
        (resumenFiscal?['base_anulada'] as num? ?? 0.0).toDouble() * tasaCambio;
    final double ivaAnulada =
        (resumenFiscal?['iva_anulada'] as num? ?? 0.0).toDouble() * tasaCambio;
    final double exentoAnulada =
        (resumenFiscal?['exento_anulada'] as num? ?? 0.0).toDouble() *
            tasaCambio;

    final double sumaTributadosValor = base16F + base8F;
    final double sumaTributadosImpuesto = iva16F + iva8F;
    final double sumaVentasValor = sumaTributadosValor + exentoF;
    final double sumaNcValor = base16Nc + base8Nc + exentoNc;
    final double sumaNcImpuesto = iva16Nc + iva8Nc;

    lines.add(PrinterLine(
        text: '-----------------Resumen Tributados-----------------',
        alignment: 'center',
        fontSize: 14));
    lines.add(PrinterLine(
        text: 'Tot.      Valor Acumulado(Bs )     Impuesto(Bs )',
        alignment: 'center',
        fontSize: 14));
    lines.add(PrinterLine(
        text:
            'Tributados%${_formatAmount(sumaTributadosValor)}%${_formatAmount(sumaTributadosImpuesto)}',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'Exentos%${_formatAmount(exentoF)}',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'Percibidos%0,00', alignment: 'justifed', fontSize: 15));
    lines.add(PrinterLine(
        text:
            'Notas de Credito%${_formatAmount(sumaNcValor)}%${_formatAmount(sumaNcImpuesto)}',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text:
            'Suma:%${_formatAmount(sumaVentasValor)}%${_formatAmount(sumaTributadosImpuesto)}',
        alignment: 'justifed',
        fontSize: 15,
        isBold: true));

    // ═══════════════════════════════════════
    // NO FISCAL
    // ═══════════════════════════════════════
    lines
        .add(PrinterLine(text: 'NO FISCAL', alignment: 'center', fontSize: 14));

    // ═══════════════════════════════════════
    // TOTALES POR BASE IMPONIBLE
    // ═══════════════════════════════════════
    lines.add(PrinterLine(
        text: '--------------Totales Por Base Imponible--------------',
        alignment: 'center',
        fontSize: 14));
    lines.add(PrinterLine(
        text: 'IGTF03,00 =%           0,00 IGTF 03,00 =%        0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'Exentos =%           ${_formatAmount(exentoF)}',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'Percibidos =%           0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text:
            'BI G16,00 =% ${_formatAmount(base16F)}%IVA G16,00 =% ${_formatAmount(iva16F)}',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text:
            'BI R08,00 =% ${_formatAmount(base8F)}%IVA R08,00 =% ${_formatAmount(iva8F)}',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'BI A31,00 =%           0,00 IVA A31,00 =%        0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines
        .add(PrinterLine(text: 'NO FISCAL', alignment: 'center', fontSize: 14));

    // ═══════════════════════════════════════
    // NOTAS DE CRÉDITO Y/O DEVOLUCIONES
    // ═══════════════════════════════════════
    lines.add(PrinterLine(
        text: '-----------Notas de Credito y/o Devoluciones-----------',
        alignment: 'center',
        fontSize: 14));
    lines.add(PrinterLine(
        text: 'IGTF03,00 =%           0,00 IGTF 03,00 =%        0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'Exentos =%           ${_formatAmount(exentoNc)}',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'Percibidos =%           0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text:
            'BI G16,00 =% ${_formatAmount(base16Nc)}%IVA G16,00 =% ${_formatAmount(iva16Nc)}',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text:
            'BI R08,00 =% ${_formatAmount(base8Nc)}%IVA R08,00 =% ${_formatAmount(iva8Nc)}',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'BI A31,00 =%           0,00 IVA A31,00 =%        0,00',
        alignment: 'justifed',
        fontSize: 15));

    // ═══════════════════════════════════════
    // ÚLTIMOS DOCUMENTOS
    // ═══════════════════════════════════════
    final ultFact = resumenFiscal?['ult_fact'] as Map<String, dynamic>?;
    String factNumStr = '000000', factFechaStr = '00/00/0000';
    double factTotalBs = 0.0;
    if (ultFact != null) {
      final String numCtrl = ultFact['numero_control'] as String? ?? '';
      factNumStr = numCtrl.replaceAll('FAC-', '').padLeft(6, '0');
      final DateTime? fCreacion =
          DateTime.tryParse(ultFact['fecha_creacion'] as String? ?? '');
      if (fCreacion != null) {
        factFechaStr =
            '${fCreacion.day.toString().padLeft(2, '0')}/${fCreacion.month.toString().padLeft(2, '0')}/${fCreacion.year}';
      }
      factTotalBs = (ultFact['total'] as num? ?? 0.0).toDouble() * tasaCambio;
    }

    final ultArq = resumenFiscal?['ult_arqueo'] as Map<String, dynamic>?;
    String arqNumStr = '000000', arqFechaStr = '00/00/0000';

    if (ultArq != null) {
      final rawNum = ultArq['numero_arqueo'];
      if (rawNum is int) {
        arqNumStr = rawNum.toString().padLeft(6, '0');
      } else if (rawNum is String) {
        arqNumStr = rawNum.replaceAll('ARQ-', '').padLeft(6, '0');
      } else {
        arqNumStr = (rawNum ?? '0').toString().padLeft(6, '0');
      }
      final DateTime? fArq =
          DateTime.tryParse(ultArq['fecha_arqueo'] as String? ?? '');
      if (fArq != null) {
        arqFechaStr =
            '${fArq.day.toString().padLeft(2, '0')}/${fArq.month.toString().padLeft(2, '0')}/${fArq.year}';
      }
    }

    final ultZ = resumenFiscal?['ult_z'] as Map<String, dynamic>?;
    String zNumStr = '000000', zFechaStr = '00/00/0000';
    if (ultZ != null) {
      final String numZ = ultZ['numero_reporte'] as String? ?? '';
      zNumStr = numZ.replaceAll('REP-Z-', '').padLeft(6, '0');
      final DateTime? fZ =
          DateTime.tryParse(ultZ['fecha_reporte'] as String? ?? '');
      if (fZ != null) {
        zFechaStr =
            '${fZ.day.toString().padLeft(2, '0')}/${fZ.month.toString().padLeft(2, '0')}/${fZ.year}';
      }
    }

    lines.add(PrinterLine(
        text: '-----------------Ultimos Documentos-----------------',
        alignment: 'center',
        fontSize: 14));
    lines.add(PrinterLine(
        text:
            'Ultima Factura $factNumStr $factFechaStr  Bs%${_formatAmount(factTotalBs)}',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'Doc. No Fiscal $arqNumStr $arqFechaStr  Bs%0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'Reporte Z      $zNumStr $zFechaStr',
        alignment: 'left',
        fontSize: 15));

    // ═══════════════════════════════════════
    // DESCUENTOS POR BASE IMPONIBLE
    // ═══════════════════════════════════════
    lines.add(PrinterLine(
        text: '-------------Descuentos Por Base Imponible-------------',
        alignment: 'center',
        fontSize: 14));
    lines.add(PrinterLine(
        text: 'Exentos =%              0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'Percibidos =%           0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'BI G16,00 =%           0,00 IVA G16,00 =%        0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'BI R08,00 =%           0,00 IVA R08,00 =%        0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'BI A31,00 =%           0,00 IVA A31,00 =%        0,00',
        alignment: 'justifed',
        fontSize: 15));

    // ═══════════════════════════════════════
    // ANULACIONES POR BASE IMPONIBLE
    // ═══════════════════════════════════════
    lines.add(PrinterLine(
        text: '-------------Anulaciones Por Base Imponible-------------',
        alignment: 'center',
        fontSize: 14));
    lines.add(PrinterLine(
        text: 'IGTF03,00 =%           0,00 IGTF 03,00 =%        0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'Exentos =%              ${_formatAmount(exentoAnulada)}',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'Percibidos =%           0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text:
            'BI G16,00 =% ${_formatAmount(baseAnulada)}%IVA G16,00 =% ${_formatAmount(ivaAnulada)}',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'BI R08,00 =%           0,00 IVA R08,00 =%        0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'BI A31,00 =%           0,00 IVA A31,00 =%        0,00',
        alignment: 'justifed',
        fontSize: 15));

    // ═══════════════════════════════════════
    // INCREMENTOS POR BASE IMPONIBLE
    // ═══════════════════════════════════════
    lines.add(PrinterLine(
        text: '-------------Incrementos Por Base Imponible-------------',
        alignment: 'center',
        fontSize: 14));
    lines.add(PrinterLine(
        text: 'Exentos =%              0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'Percibidos =%           0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'BI G16,00 =%           0,00 IVA G16,00 =%        0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'BI R08,00 =%           0,00 IVA R08,00 =%        0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'BI A31,00 =%           0,00 IVA A31,00 =%        0,00',
        alignment: 'justifed',
        fontSize: 15));

    // ═══════════════════════════════════════
    // TOTALIZADORES NO FISCALES
    // ═══════════════════════════════════════
    lines.add(PrinterLine(
        text: '--------------TOTALIZADORES NO FISCALES--------------',
        alignment: 'center',
        fontSize: 14));
    lines.add(PrinterLine(
        text: '29 Retirada de caja   : 0000%0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: '30 Fondo de caja      : 0000%0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'Total de Oper. No Fiscales Bs%0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'RECARGO   NO FISCAL:%0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'DESCUENTO NO FISCAL:%0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines.add(PrinterLine(
        text: 'ANULACION NO FISCAL:%0,00',
        alignment: 'justifed',
        fontSize: 15));
    lines
        .add(PrinterLine(text: 'NO FISCAL', alignment: 'center', fontSize: 14));

    // ═══════════════════════════════════════
    // INFORME GERENCIAL
    // ═══════════════════════════════════════
    lines.add(PrinterLine(
        text: '-------------------INFORME GERENCIAL-------------------',
        alignment: 'center',
        fontSize: 14));
    lines.add(PrinterLine(
        text: '01 Informe General%0000', alignment: 'justifed', fontSize: 15));
    lines.add(PrinterLine(
        text: '02 Informe de Trans.%0000',
        alignment: 'justifed',
        fontSize: 15));

    // ═══════════════════════════════════════
    // FORMAS DE PAGO (montos declarados del arqueo)
    // ═══════════════════════════════════════
    lines.add(PrinterLine(
        text: '---------------------FORMAS DE PAGO---------------------',
        alignment: 'center',
        fontSize: 14));

    // Método 01: Efectivo - monto declarado en el arqueo
    final double efTotalX = arqueo.totalEfectivoDeclarado * tasaCambio;
    lines.add(PrinterLine(
        text: '01 Efectivo                 (0001)%${_formatAmount(efTotalX)}',
        alignment: 'justifed',
        fontSize: 15));

    // Método 02: Tarjeta - monto declarado
    final double tjTotalX = arqueo.totalTarjetaDeclarado * tasaCambio;
    if (tjTotalX > 0) {
      lines.add(PrinterLine(
          text: '02 Tarjeta                  (0001)%${_formatAmount(tjTotalX)}',
          alignment: 'justifed',
          fontSize: 15));
    }

    // Método 03: Pago Móvil - monto declarado
    final double pmTotalX = arqueo.totalPagoMovilDeclarado * tasaCambio;
    if (pmTotalX > 0) {
      lines.add(PrinterLine(
          text: '03 Pago Movil               (0001)%${_formatAmount(pmTotalX)}',
          alignment: 'justifed',
          fontSize: 15));
    }

    // Método 04: Otros - monto declarado
    final double otTotalX = arqueo.totalOtrosDeclarado * tasaCambio;
    if (otTotalX > 0) {
      lines.add(PrinterLine(
          text: '04 Otros                    (0001)%${_formatAmount(otTotalX)}',
          alignment: 'justifed',
          fontSize: 15));
    }
    lines
        .add(PrinterLine(text: 'NO FISCAL', alignment: 'center', fontSize: 14));

    // ═══════════════════════════════════════
    // PIE DE PÁGINA FISCAL (datos reales del equipo configurado en .env)
    // ═══════════════════════════════════════
    final int rzRestantes =
        (AppConfig.rangoMaximoNumeroControl) - (arqueo.id ?? 0);

    // Construir línea de marca/modelo del equipo fiscal (solo si hay datos)
    final String marcaModeloX = [
      AppConfig.marcaEquipoFiscal,
      AppConfig.modeloEquipoFiscal,
    ].where((s) => s.isNotEmpty).join('  ');

    // Construir línea de caja/tienda (solo si hay datos)
    final String cajaPartX =
        AppConfig.numeroCaja.isNotEmpty ? 'CAJA:${AppConfig.numeroCaja}' : '';
    final String tiendaPartX = AppConfig.numeroTienda.isNotEmpty
        ? 'TIENDA:${AppConfig.numeroTienda}'
        : '';
    final String cajaTiendaX =
        [cajaPartX, tiendaPartX].where((s) => s.isNotEmpty).join('  ');

    // Construir línea de versión/IGM (solo si hay datos)
    final String versionPartX = AppConfig.versionFirmware.isNotEmpty
        ? 'VERSION:${AppConfig.versionFirmware}'
        : '';
    final String igmPartX =
        AppConfig.codigoIGM.isNotEmpty ? 'IGM${AppConfig.codigoIGM}' : '';
    final String versionIGMX =
        [versionPartX, igmPartX].where((s) => s.isNotEmpty).join('  ');

    // Serial del dispositivo como identificador (si está configurado)
    final String serialDispX = AppConfig.serialDispositivo.isNotEmpty
        ? AppConfig.serialDispositivo.toUpperCase()
        : '';

    lines.add(PrinterLine(
        text: '------------------------------------------------------',
        alignment: 'center',
        fontSize: 14));

    lines.add(PrinterLine(
        text:
            'RZ restantes: ${rzRestantes > 0 ? rzRestantes.toString().padLeft(4, '0') : '0000'}',
        alignment: 'left',
        fontSize: 15));
    if (marcaModeloX.isNotEmpty) {
      lines.add(
          PrinterLine(text: marcaModeloX, alignment: 'left', fontSize: 14));
    }
    if (serialDispX.isNotEmpty) {
      final serialLine =
          cajaTiendaX.isNotEmpty ? '$serialDispX  $cajaTiendaX' : serialDispX;
      lines.add(PrinterLine(text: serialLine, alignment: 'left', fontSize: 14));
    } else if (cajaTiendaX.isNotEmpty) {
      lines
          .add(PrinterLine(text: cajaTiendaX, alignment: 'left', fontSize: 14));
    }
    if (versionIGMX.isNotEmpty) {
      lines
          .add(PrinterLine(text: versionIGMX, alignment: 'left', fontSize: 14));
    }

    lines.add(PrinterLine(text: '', fontSize: 100));

    return printReceipt(lines: lines);
  }
}
