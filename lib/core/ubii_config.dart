/// Configuración de credenciales para Ubii API
/// 
/// IMPORTANTE: Estos valores deben ser proporcionados por Ubiipagos
/// y deben mantenerse seguros. En producción, considera usar:
/// - Variables de entorno
/// - Almacenamiento seguro (flutter_secure_storage)
/// - Backend proxy para ocultar las credenciales
class UbiiConfig {
  // ==================== CREDENCIALES ====================
  
  /// Client ID proporcionado por Ubii
  /// Este valor se usa en el header X-CLIENT-ID
  static const String clientId = 'TU_X_CLIENT_ID_AQUI';
  
  /// Dominio registrado en Ubii
  /// Este valor se usa en el header X-CLIENT-DOMAIN
  static const String clientDomain = 'TU_DOMINIO_REGISTRADO';
  
  /// URL base de la API de Ubii
  /// Producción: https://botonc.ubiipagos.com
  /// Pruebas: Consultar con Ubii si tienen ambiente de staging
  static const String baseUrl = 'https://botonc.ubiipagos.com';
  
  // ==================== CONFIGURACIÓN DE PAGO MÓVIL ====================
  
  /// Teléfono del comercio registrado en el banco para recibir pagos móviles
  /// Formato: 00584XXXXXXXXX (14 dígitos)
  /// IMPORTANTE: Este debe ser el número exacto registrado en tu cuenta bancaria
  static const String phoneComercio = '00584XXXXXXXXX';
  
  /// Cédula o RIF del comercio
  /// Formato: V12345678, E12345678, J123456789
  /// IMPORTANTE: Debe coincidir con el registrado en tu cuenta bancaria
  static const String cedulaComercio = 'V12345678';
  
  /// Alias de la API Key de Pago Móvil en Ubii
  /// Valores comunes: "P2C", "PAGO_MOVIL"
  /// Consulta con Ubii cuál es el alias correcto para tu cuenta
  static const String pagoMovilAlias = 'P2C';
  
  // ==================== TIMEOUTS Y LÍMITES ====================
  
  /// Tiempo máximo de espera para confirmación de Pago Móvil (en segundos)
  /// Recomendado: 300 segundos (5 minutos)
  static const int pagoMovilTimeout = 300;
  
  /// Intervalo entre consultas de estado (en segundos)
  /// Recomendado: 5 segundos
  static const int pollingInterval = 5;
  
  /// Número máximo de intentos de consulta
  /// Se calcula como: pagoMovilTimeout / pollingInterval
  static int get maxPollingAttempts => pagoMovilTimeout ~/ pollingInterval;
  
  // ==================== VALIDACIÓN ====================
  
  /// Verifica si las credenciales están configuradas
  static bool get isConfigured {
    return clientId != 'TU_X_CLIENT_ID_AQUI' &&
           clientDomain != 'TU_DOMINIO_REGISTRADO' &&
           phoneComercio != '00584XXXXXXXXX' &&
           cedulaComercio != 'V12345678';
  }
  
  /// Mensaje de error si no está configurado
  static String get configurationError {
    if (!isConfigured) {
      return 'Las credenciales de Ubii no están configuradas.\n'
             'Por favor, actualiza los valores en lib/core/ubii_config.dart';
    }
    return '';
  }
}
