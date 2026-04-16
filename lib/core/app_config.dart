import 'package:flutter_dotenv/flutter_dotenv.dart';

/// ============================================================================
/// CONFIGURACIÓN CENTRALIZADA DE LA APLICACIÓN
/// ============================================================================
/// 
/// Este archivo lee las configuraciones desde variables de entorno (.env)
/// para mayor seguridad y flexibilidad.
/// 
/// IMPORTANTE: 
/// - Las credenciales sensibles están en el archivo .env
/// - El archivo .env NO se sube a Git (está en .gitignore)
/// - Usa .env.example como plantilla para crear tu .env
/// ============================================================================

class AppConfig {
  // ==========================================================================
  // MÉTODOS HELPER PARA LEER VARIABLES DE ENTORNO
  // ==========================================================================
  
  /// Obtener variable de entorno como String
  static String _getEnv(String key, {String defaultValue = ''}) {
    return dotenv.env[key] ?? defaultValue;
  }
  
  /// Obtener variable de entorno como int
  static int _getEnvInt(String key, {int defaultValue = 0}) {
    final value = dotenv.env[key];
    return value != null ? int.tryParse(value) ?? defaultValue : defaultValue;
  }
  
  /// Obtener variable de entorno como double
  static double _getEnvDouble(String key, {double defaultValue = 0.0}) {
    final value = dotenv.env[key];
    return value != null ? double.tryParse(value) ?? defaultValue : defaultValue;
  }
  
  /// Obtener variable de entorno como bool
  static bool _getEnvBool(String key, {bool defaultValue = false}) {
    final value = dotenv.env[key]?.toLowerCase();
    if (value == 'true' || value == '1' || value == 'yes') return true;
    if (value == 'false' || value == '0' || value == 'no') return false;
    return defaultValue;
  }
  
  // ==========================================================================
  // 1. INFORMACIÓN DEL COMERCIO
  // ==========================================================================
  
  /// Nombre o razón social del comercio
  static String get nombreComercio => _getEnv('COMERCIO_NOMBRE', defaultValue: 'TU COMERCIO AQUÍ');
  
  /// RIF del comercio (Registro de Información Fiscal)
  static String get rifComercio => _getEnv('COMERCIO_RIF', defaultValue: 'J-000000000-0');
  
  /// Dirección fiscal del comercio
  static String get direccionComercio => _getEnv('COMERCIO_DIRECCION', defaultValue: 'DIRECCIÓN FISCAL AQUÍ');
  
  /// Teléfono de contacto del comercio
  static String get telefonoComercio => _getEnv('COMERCIO_TELEFONO', defaultValue: '0414-0000000');
  
  /// Correo electrónico del comercio
  static String get emailComercio => _getEnv('COMERCIO_EMAIL', defaultValue: 'contacto@tucomercio.com');
  
  // ==========================================================================
  // 2. CONFIGURACIÓN FISCAL (SENIAT)
  // ==========================================================================
  
  /// Prefijo del número de control fiscal
  static String get prefijoNumeroControl => _getEnv('FISCAL_PREFIJO_NUMERO_CONTROL', defaultValue: '00');
  
  /// Cantidad de dígitos para el número secuencial
  static const int digitosNumeroControl = 7;
  
  /// Rango máximo de números de control autorizado por SENIAT
  static int get rangoMaximoNumeroControl => _getEnvInt('FISCAL_RANGO_MAXIMO', defaultValue: 9999999);
  
  /// Umbral de alerta para números de control restantes
  static int get umbralAlertaNumeroControl => _getEnvInt('FISCAL_UMBRAL_ALERTA', defaultValue: 100);
  
  /// Tasa de IVA vigente en Venezuela
  static double get tasaIVA => _getEnvDouble('FISCAL_TASA_IVA', defaultValue: 0.16);
  
  /// Porcentaje de retención de IVA para agentes de retención
  static double get tasaRetencionIVA => _getEnvDouble('FISCAL_TASA_RETENCION_IVA', defaultValue: 0.75);
  
  /// Tipos de documentos fiscales válidos
  static const List<String> tiposDocumento = [
    'Factura',
    'Nota de Débito',
    'Nota de Crédito',
    'Factura de Exportación',
  ];
  
  /// Tipo de documento por defecto
  static const String tipoDocumentoPorDefecto = 'Factura';
  
  // ==========================================================================
  // 3. CONFIGURACIÓN DE UBII (PAGOS ELECTRÓNICOS)
  // ==========================================================================
  
  /// Client ID proporcionado por Ubii
  static String get ubiiClientId => _getEnv('UBII_CLIENT_ID', defaultValue: 'TU_X_CLIENT_ID_AQUI');
  
  /// Dominio registrado en Ubii
  static String get ubiiClientDomain => _getEnv('UBII_CLIENT_DOMAIN', defaultValue: 'TU_DOMINIO_REGISTRADO');
  
  /// URL base de la API de Ubii
  static String get ubiiBaseUrl => _getEnv('UBII_BASE_URL', defaultValue: 'https://botonc.ubiipagos.com');
  
  // ==========================================================================
  // 4. CONFIGURACIÓN DE PAGO MÓVIL
  // ==========================================================================
  
  /// Teléfono del comercio registrado en el banco para Pago Móvil
  static String get pagoMovilTelefono => _getEnv('PAGO_MOVIL_TELEFONO', defaultValue: '00584XXXXXXXXX');
  
  /// Cédula o RIF del comercio para Pago Móvil
  static String get pagoMovilCedulaRif => _getEnv('PAGO_MOVIL_CEDULA_RIF', defaultValue: 'V12345678');
  
  /// Alias de la API Key de Pago Móvil en Ubii
  static String get pagoMovilAlias => _getEnv('PAGO_MOVIL_ALIAS', defaultValue: 'P2C');
  
  /// Tiempo máximo de espera para confirmación (en segundos)
  static int get pagoMovilTimeout => _getEnvInt('PAGO_MOVIL_TIMEOUT', defaultValue: 300);
  
  /// Intervalo entre consultas de estado (en segundos)
  static int get pagoMovilPollingInterval => _getEnvInt('PAGO_MOVIL_POLLING_INTERVAL', defaultValue: 5);
  
  // ==========================================================================
  // 5. CONFIGURACIÓN DE MONEDAS Y TASAS
  // ==========================================================================
  
  /// Tasa de cambio por defecto (USD a Bolívares)
  static double get tasaCambioDefaultUSD => _getEnvDouble('TASA_CAMBIO_USD', defaultValue: 36.50);
  
  /// Tasa de cambio por defecto (EUR a Bolívares)
  static double get tasaCambioDefaultEUR => _getEnvDouble('TASA_CAMBIO_EUR', defaultValue: 0.0);
  
  /// Moneda principal de la aplicación
  static String get monedaPrincipal => _getEnv('MONEDA_PRINCIPAL', defaultValue: 'USD');
  
  /// Símbolo de la moneda principal
  static const String simboloMoneda = '\$';
  
  /// Decimales para mostrar precios
  static const int decimalesPrecios = 2;
  
  // ==========================================================================
  // 6. CONFIGURACIÓN DE LA APLICACIÓN
  // ==========================================================================
  
  /// Nombre de la aplicación
  static const String appName = 'POS Android';
  
  /// Versión de la aplicación
  static const String appVersion = '1.0.0';
  
  /// Ambiente de ejecución
  static String get environment => _getEnv('APP_ENVIRONMENT', defaultValue: 'development');
  
  /// Habilitar logs de debug
  static bool get enableDebugLogs => _getEnvBool('APP_DEBUG_LOGS', defaultValue: true);
  
  /// Habilitar modo demo (datos de prueba)
  static bool get enableDemoMode => _getEnvBool('APP_DEMO_MODE', defaultValue: false);
  
  // ==========================================================================
  // 7. CONFIGURACIÓN DE BASE DE DATOS
  // ==========================================================================
  
  /// Nombre del archivo de base de datos
  static String get databaseName => _getEnv('DB_NAME', defaultValue: 'POS_ANDROID.db');
  
  /// Versión de la base de datos
  static int get databaseVersion => _getEnvInt('DB_VERSION', defaultValue: 5);
  
  /// Habilitar backups automáticos
  static bool get enableAutoBackup => _getEnvBool('DB_AUTO_BACKUP', defaultValue: true);
  
  /// Intervalo de backups automáticos (en días)
  static int get backupIntervalDays => _getEnvInt('DB_BACKUP_INTERVAL_DAYS', defaultValue: 7);
  
  // ==========================================================================
  // 8. CONFIGURACIÓN DE IMPRESIÓN
  // ==========================================================================
  
  /// Tipo de impresora
  static String get printerType => _getEnv('PRINTER_TYPE', defaultValue: 'none');
  
  /// Ancho del papel (en mm)
  static int get paperWidthMm => _getEnvInt('PRINTER_PAPER_WIDTH', defaultValue: 80);
  
  /// Incluir logo en facturas
  static bool get includeLogo => _getEnvBool('PRINTER_INCLUDE_LOGO', defaultValue: false);
  
  /// Ruta del logo
  static String get logoPath => _getEnv('PRINTER_LOGO_PATH', defaultValue: 'assets/logos/klk.png');
  
  // ==========================================================================
  // MÉTODOS DE VALIDACIÓN
  // ==========================================================================
  
  /// Verifica si la configuración de Ubii está completa
  static bool get isUbiiConfigured {
    return ubiiClientId != 'TU_X_CLIENT_ID_AQUI' &&
           ubiiClientDomain != 'TU_DOMINIO_REGISTRADO' &&
           pagoMovilTelefono != '00584XXXXXXXXX' &&
           pagoMovilCedulaRif != 'V12345678';
  }
  
  /// Verifica si la configuración del comercio está completa
  static bool get isComercioConfigured {
    return nombreComercio != 'TU COMERCIO AQUÍ' &&
           rifComercio != 'J-000000000-0' &&
           direccionComercio != 'DIRECCIÓN FISCAL AQUÍ';
  }
  
  /// Verifica si toda la configuración está completa
  static bool get isFullyConfigured {
    return isUbiiConfigured && isComercioConfigured;
  }
  
  /// Obtiene una lista de configuraciones faltantes
  static List<String> get missingConfigurations {
    final missing = <String>[];
    
    if (nombreComercio == 'TU COMERCIO AQUÍ') {
      missing.add('Nombre del comercio (COMERCIO_NOMBRE en .env)');
    }
    if (rifComercio == 'J-000000000-0') {
      missing.add('RIF del comercio (COMERCIO_RIF en .env)');
    }
    if (direccionComercio == 'DIRECCIÓN FISCAL AQUÍ') {
      missing.add('Dirección del comercio (COMERCIO_DIRECCION en .env)');
    }
    if (ubiiClientId == 'TU_X_CLIENT_ID_AQUI') {
      missing.add('Ubii Client ID (UBII_CLIENT_ID en .env)');
    }
    if (ubiiClientDomain == 'TU_DOMINIO_REGISTRADO') {
      missing.add('Ubii Client Domain (UBII_CLIENT_DOMAIN en .env)');
    }
    if (pagoMovilTelefono == '00584XXXXXXXXX') {
      missing.add('Teléfono para Pago Móvil (PAGO_MOVIL_TELEFONO en .env)');
    }
    if (pagoMovilCedulaRif == 'V12345678') {
      missing.add('Cédula/RIF para Pago Móvil (PAGO_MOVIL_CEDULA_RIF en .env)');
    }
    
    return missing;
  }
  
  /// Mensaje de error con configuraciones faltantes
  static String get configurationError {
    if (isFullyConfigured) return '';
    
    final missing = missingConfigurations;
    return 'Configuraciones faltantes en el archivo .env:\n${missing.map((m) => '• $m').join('\n')}\n\n'
           'Por favor, edita el archivo .env en la raíz del proyecto.';
  }
  
  // ==========================================================================
  // MÉTODOS DE UTILIDAD
  // ==========================================================================
  
  /// Calcular IVA sobre un monto base
  static double calcularIVA(double baseImponible) {
    return baseImponible * tasaIVA;
  }
  
  /// Calcular retención de IVA
  static double calcularRetencionIVA(double montoIVA) {
    return montoIVA * tasaRetencionIVA;
  }
  
  /// Calcular total de factura (base + IVA)
  static double calcularTotal(double baseImponible) {
    return baseImponible + calcularIVA(baseImponible);
  }
  
  /// Validar formato de número de control
  static bool validarFormatoNumeroControl(String numeroControl) {
    final regex = RegExp(r'^\d{2}-\d{7}$');
    return regex.hasMatch(numeroControl);
  }
  
  /// Validar tipo de documento
  static bool validarTipoDocumento(String tipoDocumento) {
    return tiposDocumento.contains(tipoDocumento);
  }
  
  /// Formatear número de control
  static String formatearNumeroControl(int numero) {
    final numeroFormateado = numero.toString().padLeft(digitosNumeroControl, '0');
    return '$prefijoNumeroControl-$numeroFormateado';
  }
  
  /// Obtener información del rango de números de control
  static Map<String, dynamic> obtenerInfoRango() {
    return {
      'prefijo': prefijoNumeroControl,
      'digitos': digitosNumeroControl,
      'rango_maximo': rangoMaximoNumeroControl,
      'formato_ejemplo': formatearNumeroControl(1),
      'ultimo_numero_posible': formatearNumeroControl(rangoMaximoNumeroControl),
      'umbral_alerta': umbralAlertaNumeroControl,
    };
  }
  
  /// Obtener mensaje de alerta para números de control
  static String obtenerMensajeAlerta(int numerosRestantes) {
    if (numerosRestantes <= 0) {
      return '🚨 CRÍTICO: Rango de números de control agotado. '
             'NO puede emitir más facturas. Solicite un nuevo rango al SENIAT URGENTEMENTE.';
    } else if (numerosRestantes <= umbralAlertaNumeroControl) {
      return '⚠️ ALERTA: Solo quedan $numerosRestantes números de control disponibles. '
             'Solicite un nuevo rango al SENIAT pronto.';
    }
    return '';
  }
  
  /// Obtener configuración como Map (útil para debug)
  static Map<String, dynamic> toMap() {
    return {
      'comercio': {
        'nombre': nombreComercio,
        'rif': rifComercio,
        'direccion': direccionComercio,
        'telefono': telefonoComercio,
        'email': emailComercio,
      },
      'fiscal': {
        'prefijo_numero_control': prefijoNumeroControl,
        'rango_maximo': rangoMaximoNumeroControl,
        'tasa_iva': tasaIVA,
        'tasa_retencion_iva': tasaRetencionIVA,
      },
      'ubii': {
        'client_id': ubiiClientId,
        'client_domain': ubiiClientDomain,
        'base_url': ubiiBaseUrl,
        'configurado': isUbiiConfigured,
      },
      'pago_movil': {
        'telefono': pagoMovilTelefono,
        'cedula_rif': pagoMovilCedulaRif,
        'alias': pagoMovilAlias,
      },
      'app': {
        'nombre': appName,
        'version': appVersion,
        'ambiente': environment,
        'debug': enableDebugLogs,
      },
      'configuracion_completa': isFullyConfigured,
    };
  }
}
