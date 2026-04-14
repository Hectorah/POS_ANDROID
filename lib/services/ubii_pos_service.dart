import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para interactuar con la aplicación Ubii POS (KOZEN / Ubii P14)
/// utilizando MethodChannel para recibir resultados de la transacción.
class UbiiPosService {
  // MethodChannel para comunicación con código nativo Android
  static const MethodChannel _channel = MethodChannel('com.pos.pos_android/ubii_pos');

  /// Formatea un monto double al formato requerido por Ubii:
  /// "Dos enteros y dos decimales, sin separadores" -> "150050" para 1,500.50
  String formatAmount(double amount) {
    // Aseguramos 2 decimales, reemplazamos punto y eliminamos cualquier coma residual
    return amount.toStringAsFixed(2).replaceAll('.', '').replaceAll(',', '');
  }

  /// Verifica si es la primera transacción del día
  Future<bool> isFirstTransactionOfDay() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTransactionDate = prefs.getString('last_ubii_transaction_date');
      final today = DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD
      
      return lastTransactionDate != today;
    } catch (e) {
      debugPrint('Error verificando primera transacción: $e');
      return true; // Por seguridad, asumir que es la primera
    }
  }

  /// Guardar fecha de última transacción
  Future<void> saveTransactionDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().split('T')[0];
      await prefs.setString('last_ubii_transaction_date', today);
    } catch (e) {
      debugPrint('Error guardando fecha de transacción: $e');
    }
  }

  /// Procesa un pago (PAYMENT) en el POS Ubii.
  ///
  /// [amount]: Monto double (ej. 1500.50) que será formateado automáticamente.
  /// [withLogon]: `true` para la PRIMERA transacción del día, `false` para subsecuentes.
  ///              Si es null, se detecta automáticamente.
  ///
  /// Retorna un Map con la respuesta completa de Ubii POS o `null` si hubo error.
  Future<Map<String, dynamic>?> processPayment(
    double amount, {
    bool? withLogon,
  }) async {
    // Detectar automáticamente si es la primera transacción del día
    final bool needsLogon = withLogon ?? await isFirstTransactionOfDay();
    
    // Formatear monto correctamente
    final String formattedAmount = formatAmount(amount);

    debugPrint('💳 Ubii POS: Iniciando pago');
    debugPrint('   Monto: $amount -> Formato: $formattedAmount');
    debugPrint('   Logon: ${needsLogon ? "SÍ" : "NO"} (${needsLogon ? "Primera tx del día" : "Subsecuente"})');

    try {
      // Llamar al método nativo que lanza el intent y espera resultado
      final result = await _channel.invokeMethod('processPayment', {
        'amount': formattedAmount,
        'logon': needsLogon ? 'YES' : 'NO',
      });
      
      if (result == null) {
        debugPrint('❌ Ubii POS: Respuesta nula');
        return {
          'code': 'ERROR',
          'message': 'No se recibió respuesta del POS',
        };
      }
      
      // Convertir resultado a Map<String, dynamic>
      final Map<String, dynamic> response = Map<String, dynamic>.from(result);
      
      debugPrint('✅ Ubii POS: Respuesta recibida');
      debugPrint('   Código: ${response['code']}');
      debugPrint('   Mensaje: ${response['message']}');
      debugPrint('   TODOS LOS DATOS: $response');
      
      // Detectar campos vacíos (cancelación)
      if (response['code'] == '' || response['code'] == null) {
        debugPrint('   ⚠️ Código vacío - Detectando como CANCELACIÓN');
        response['code'] = 'CANCELLED';
        response['message'] = 'Transacción cancelada por el usuario';
      }
      
      // Interpretar código de respuesta
      final code = response['code'] as String?;
      
      if (code == '00') {
        // ✅ Transacción APROBADA
        debugPrint('   ✅ APROBADA');
        debugPrint('   Referencia: ${response['reference']}');
        debugPrint('   Auth Code: ${response['authCode']}');
        debugPrint('   Tipo Tarjeta: ${response['cardType']}');
        debugPrint('   Terminal: ${response['terminal']}');
        debugPrint('   Lote: ${response['lote']}');
        
        // Guardar fecha de transacción exitosa
        await saveTransactionDate();
      } else if (code == 'CANCELLED') {
        // ⚠️ Usuario CANCELÓ
        debugPrint('   ⚠️ CANCELADA por usuario');
      } else if (code == 'NO_DATA') {
        // ⚠️ Sin datos de respuesta
        debugPrint('   ⚠️ Ubii POS no retornó datos');
        debugPrint('   La transacción puede haberse procesado correctamente');
        debugPrint('   Verifica en el POS si se imprimió el voucher');
      } else if (code == '04') {
        // ❌ No honrar (declinada por banco emisor)
        debugPrint('   ❌ NO HONRAR - Declinada por el banco emisor');
        response['message'] = 'Tarjeta no honrada. Contacte a su banco.';
      } else if (code == '05') {
        // ❌ Declinada genérica
        debugPrint('   ❌ DECLINADA - Transacción rechazada');
        response['message'] = 'Transacción declinada. Intente con otra tarjeta.';
      } else if (code == '51') {
        // ❌ Fondos insuficientes
        debugPrint('   ❌ FONDOS INSUFICIENTES');
        response['message'] = 'Fondos insuficientes en la tarjeta.';
      } else if (code == '12') {
        // ❌ Transacción inválida
        debugPrint('   ❌ TRANSACCIÓN INVÁLIDA');
        response['message'] = 'Transacción inválida. Verifique los datos.';
      } else if (code == '14') {
        // ❌ Número de tarjeta inválido
        debugPrint('   ❌ TARJETA INVÁLIDA');
        response['message'] = 'Número de tarjeta inválido.';
      } else if (code == '41') {
        // ❌ Tarjeta perdida
        debugPrint('   ❌ TARJETA PERDIDA');
        response['message'] = 'Tarjeta reportada como perdida.';
      } else if (code == '43') {
        // ❌ Tarjeta robada
        debugPrint('   ❌ TARJETA ROBADA');
        response['message'] = 'Tarjeta reportada como robada.';
      } else if (code == '54') {
        // ❌ Tarjeta vencida
        debugPrint('   ❌ TARJETA VENCIDA');
        response['message'] = 'Tarjeta vencida. Use otra tarjeta.';
      } else if (code == '55') {
        // ❌ PIN incorrecto
        debugPrint('   ❌ PIN INCORRECTO');
        response['message'] = 'PIN incorrecto. Intente nuevamente.';
      } else if (code == '57') {
        // ❌ Transacción no permitida
        debugPrint('   ❌ TRANSACCIÓN NO PERMITIDA');
        response['message'] = 'Transacción no permitida para esta tarjeta.';
      } else if (code == '58') {
        // ❌ Transacción no permitida en terminal
        debugPrint('   ❌ NO PERMITIDA EN ESTE TERMINAL');
        response['message'] = 'Transacción no permitida en este terminal.';
      } else if (code == '61') {
        // ❌ Excede límite de monto
        debugPrint('   ❌ EXCEDE LÍMITE DE MONTO');
        response['message'] = 'Monto excede el límite de la tarjeta.';
      } else if (code == '65') {
        // ❌ Excede límite de frecuencia
        debugPrint('   ❌ EXCEDE LÍMITE DE FRECUENCIA');
        response['message'] = 'Excede límite de transacciones permitidas.';
      } else if (code == '75') {
        // ❌ Excede intentos de PIN
        debugPrint('   ❌ EXCEDE INTENTOS DE PIN');
        response['message'] = 'Excedió intentos de PIN. Tarjeta bloqueada.';
      } else if (code == '91') {
        // ❌ Emisor no disponible
        debugPrint('   ❌ EMISOR NO DISPONIBLE');
        response['message'] = 'Banco emisor no disponible. Intente más tarde.';
      } else if (code == '96') {
        // ❌ Error del sistema
        debugPrint('   ❌ ERROR DEL SISTEMA');
        response['message'] = 'Error del sistema. Intente nuevamente.';
      } else {
        // ❌ Código desconocido
        debugPrint('   ❌ RECHAZADA: ${response['message']} (Código: $code)');
        // Mantener el mensaje original de Ubii si existe
        if (response['message'] == null || response['message'].toString().isEmpty) {
          response['message'] = 'Transacción rechazada (Código: $code)';
        }
      }
      
      return response;
      
    } on PlatformException catch (e) {
      debugPrint('❌ Ubii POS Platform Error: ${e.code} - ${e.message}');
      debugPrint('   Detalles: ${e.details}');
      
      // Retornar error específico en lugar de null
      if (e.code == 'LAUNCH_ERROR') {
        return {
          'code': 'ERROR',
          'message': 'No se pudo abrir Ubii POS. Verifica que esté instalado.',
        };
      } else if (e.code == 'INVALID_ARGUMENTS') {
        return {
          'code': 'ERROR',
          'message': 'Error interno: Argumentos inválidos',
        };
      } else {
        return {
          'code': 'ERROR',
          'message': e.message ?? 'Error desconocido',
        };
      }
    } catch (e) {
      debugPrint('❌ Ubii POS Error: $e');
      return {
        'code': 'ERROR',
        'message': 'Error inesperado: $e',
      };
    }
  }

  /// Realiza un cierre de lote (SETTLEMENT) en el POS Ubii.
  ///
  /// [quick]: `true` = Liquidación inmediata (Q), `false` = Siguiente día hábil (N).
  Future<Map<String, dynamic>?> processSettlement({bool quick = true}) async {
    debugPrint('📊 Ubii POS: Iniciando cierre de lote');
    debugPrint('   Tipo: ${quick ? "Inmediato (Q)" : "Siguiente día (N)"}');
    
    try {
      final result = await _channel.invokeMethod('processSettlement', {
        'settleType': quick ? 'Q' : 'N',
      });
      
      if (result == null) {
        debugPrint('❌ Ubii POS: Respuesta nula');
        return null;
      }
      
      final Map<String, dynamic> response = Map<String, dynamic>.from(result);
      
      debugPrint('✅ Ubii POS: Cierre completado');
      debugPrint('   Código: ${response['code']}');
      debugPrint('   Mensaje: ${response['message']}');
      
      return response;
      
    } on PlatformException catch (e) {
      debugPrint('❌ Ubii POS Settlement Error: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      debugPrint('❌ Ubii POS Settlement Error: $e');
      return null;
    }
  }

  /// Método de alto nivel para realizar cierre de lote del día
  /// 
  /// Este método debe ejecutarse UNA SOLA VEZ al final del día (ej: 7:00 PM)
  /// 
  /// [quick]: true = Liquidación inmediata (Q) - El banco procesa esa misma noche
  ///          false = Liquidación diferida (N) - Se procesa el siguiente día hábil
  /// 
  /// Retorna un Map con el resultado del cierre o null si hubo error
  Future<Map<String, dynamic>?> cerrarLoteDelDia({bool quick = true}) async {
    debugPrint('📊 ========================================');
    debugPrint('📊 INICIANDO CIERRE DE LOTE DEL DÍA');
    debugPrint('📊 ========================================');
    debugPrint('📊 Tipo: ${quick ? "Liquidación Inmediata (Q)" : "Liquidación Diferida (N)"}');
    debugPrint('📊 Fecha: ${DateTime.now().toString()}');
    
    try {
      // Ejecutar el cierre en el POS
      final resultado = await processSettlement(quick: quick);
      
      if (resultado == null) {
        debugPrint('❌ Error: No se recibió respuesta del POS');
        debugPrint('   Verifica que el POS esté conectado y encendido');
        return null;
      }
      
      debugPrint('📊 ========================================');
      debugPrint('📊 RESULTADO DEL CIERRE');
      debugPrint('📊 ========================================');
      debugPrint('📊 Código: ${resultado['code']}');
      debugPrint('📊 Mensaje: ${resultado['message']}');
      
      if (resultado['code'] == '00') {
        // Cierre exitoso
        debugPrint('✅ ========================================');
        debugPrint('✅ CIERRE DE LOTE EXITOSO');
        debugPrint('✅ ========================================');
        debugPrint('✅ Terminal: ${resultado['terminal'] ?? 'N/A'}');
        debugPrint('✅ Lote: ${resultado['lote'] ?? 'N/A'}');
        debugPrint('✅ Fecha: ${resultado['date'] ?? 'N/A'}');
        debugPrint('✅ Hora: ${resultado['time'] ?? 'N/A'}');
        debugPrint('✅ Total Transacciones: ${resultado['totalTransactions'] ?? 'N/A'}');
        debugPrint('✅ Monto Total: ${resultado['totalAmount'] ?? 'N/A'}');
        debugPrint('✅ ========================================');
        debugPrint('✅ El dinero está en camino al banco');
        debugPrint('✅ El POS imprimirá el reporte automáticamente');
        debugPrint('✅ ========================================');
      } else if (resultado['code'] == 'CANCELLED') {
        debugPrint('⚠️ Cierre cancelado por el usuario');
      } else {
        debugPrint('❌ Error en cierre de lote');
        debugPrint('   Código: ${resultado['code']}');
        debugPrint('   Mensaje: ${resultado['message']}');
        debugPrint('   Revisa la conexión del POS');
      }
      
      return resultado;
      
    } catch (e) {
      debugPrint('❌ ========================================');
      debugPrint('❌ ERROR CRÍTICO EN CIERRE DE LOTE');
      debugPrint('❌ ========================================');
      debugPrint('❌ Error: $e');
      debugPrint('❌ ========================================');
      return null;
    }
  }

  /// Verificar si es necesario hacer cierre de lote
  /// 
  /// Retorna true si ya pasó la hora de cierre y no se ha hecho hoy
  Future<bool> necesitaCierreLote({int horaCierre = 19}) async {
    try {
      final ahora = DateTime.now();
      
      // Verificar si ya pasó la hora de cierre
      if (ahora.hour < horaCierre) {
        return false;
      }
      
      // Verificar si ya se hizo cierre hoy
      final prefs = await SharedPreferences.getInstance();
      final ultimoCierre = prefs.getString('last_settlement_date');
      final hoy = ahora.toIso8601String().split('T')[0];
      
      return ultimoCierre != hoy;
    } catch (e) {
      debugPrint('Error verificando necesidad de cierre: $e');
      return false;
    }
  }

  /// Guardar fecha del último cierre
  Future<void> guardarFechaCierre() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hoy = DateTime.now().toIso8601String().split('T')[0];
      await prefs.setString('last_settlement_date', hoy);
      debugPrint('✅ Fecha de cierre guardada: $hoy');
    } catch (e) {
      debugPrint('Error guardando fecha de cierre: $e');
    }
  }
}
