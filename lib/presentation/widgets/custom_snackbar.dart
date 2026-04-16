import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

enum SnackBarType {
  success,
  error,
  warning,
  info,
}

/// Códigos de error para identificación rápida
class ErrorCodes {
  // Errores de red
  static const String networkConnection = 'NET_001';
  static const String networkTimeout = 'NET_002';
  static const String networkUnknown = 'NET_003';
  
  // Errores de Ubii
  static const String ubiiAuth = 'UBII_001';
  static const String ubiiConnection = 'UBII_002';
  static const String ubiiApiKey = 'UBII_003';
  static const String ubiiPayment = 'UBII_004';
  static const String ubiiCierre = 'UBII_005';
  
  // Errores de Pago Móvil
  static const String pagoMovilVerification = 'PM_001';
  static const String pagoMovilInvalid = 'PM_002';
  static const String pagoMovilTimeout = 'PM_003';
  
  // Errores de Base de Datos
  static const String dbConnection = 'DB_001';
  static const String dbQuery = 'DB_002';
  static const String dbTransaction = 'DB_003';
  
  // Errores de Facturación
  static const String invoiceNumeroControl = 'INV_001';
  static const String invoiceRangoAgotado = 'INV_002';
  static const String invoiceCreation = 'INV_003';
  
  // Errores de Configuración
  static const String configMissing = 'CFG_001';
  static const String configInvalid = 'CFG_002';
  
  // Error genérico
  static const String unknown = 'ERR_000';
}

class CustomSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    required SnackBarType type,
    Duration duration = const Duration(seconds: 3),
  }) {
    // Configuración según el tipo
    Color backgroundColor;
    Color iconColor;
    IconData icon;
    
    switch (type) {
      case SnackBarType.success:
        backgroundColor = AppColors.success;
        iconColor = Colors.white;
        icon = Icons.check_circle_rounded;
        break;
      case SnackBarType.error:
        backgroundColor = AppColors.error;
        iconColor = Colors.white;
        icon = Icons.cancel_rounded;
        break;
      case SnackBarType.warning:
        backgroundColor = AppColors.warning;
        iconColor = Colors.white;
        icon = Icons.warning_rounded;
        break;
      case SnackBarType.info:
        backgroundColor = AppColors.info;
        iconColor = Colors.white;
        icon = Icons.info_rounded;
        break;
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        duration: duration,
        elevation: 6,
      ),
    );
  }

  // Métodos de conveniencia
  static void success(BuildContext context, String message) {
    show(context, message: message, type: SnackBarType.success);
  }

  static void error(BuildContext context, String message) {
    show(context, message: message, type: SnackBarType.error);
  }

  static void warning(BuildContext context, String message) {
    show(context, message: message, type: SnackBarType.warning);
  }

  static void info(BuildContext context, String message) {
    show(context, message: message, type: SnackBarType.info);
  }
}

// ============================================================================
// ERROR DIALOG - Para errores críticos que requieren atención del usuario
// ============================================================================

/// Diálogo modal para mostrar errores críticos
/// 
/// Características:
/// - Se muestra en el centro de la pantalla
/// - Bloquea la interacción hasta que el usuario lo cierre
/// - Incluye código de error para soporte técnico
/// - NO desaparece automáticamente
class ErrorDialog {
  /// Muestra un diálogo de error crítico
  /// 
  /// Parámetros:
  /// - [context]: BuildContext requerido
  /// - [title]: Título del error (opcional, por defecto "Error")
  /// - [message]: Mensaje descriptivo del error
  /// - [errorCode]: Código único del error (ver ErrorCodes)
  /// - [technicalDetails]: Detalles técnicos adicionales (opcional)
  static Future<void> show(
    BuildContext context, {
    String title = 'Error',
    required String message,
    String? errorCode,
    String? technicalDetails,
  }) async {
    final now = DateTime.now();
    final timestamp = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    
    return showDialog(
      context: context,
      barrierDismissible: false, // No se puede cerrar tocando fuera
      builder: (BuildContext context) {
        return PopScope(
          canPop: false, // No se puede cerrar con el botón atrás
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 10,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // Header con icono y botón cerrar
                  Row(
                    children: [
                      // Icono de error
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.error,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Título
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Botón cerrar (X)
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Cerrar',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Mensaje principal
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  
                  // Código de error (si existe)
                  if (errorCode != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.code_rounded,
                            size: 18,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Código: $errorCode',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  // Timestamp
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 16,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        timestamp,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  
                  // Detalles técnicos (expandible)
                  if (technicalDetails != null) ...[
                    const SizedBox(height: 16),
                    Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(top: 8),
                        title: Text(
                          'Detalles técnicos',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        children: [
                          Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(
                              maxHeight: 200, // Altura máxima para evitar overflow
                            ),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.grey.withValues(alpha: 0.2),
                              ),
                            ),
                            child: SingleChildScrollView(
                              child: SelectableText(
                                technicalDetails,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  color: Colors.grey[700],
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Botón de acción
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Entendido'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ], // children
              ), // Column
            ), // SingleChildScrollView
          ), // Container
        ), // Dialog
      ); // PopScope
      },
    );
  }
  
  // ============================================================================
  // MÉTODOS DE CONVENIENCIA PARA ERRORES COMUNES
  // ============================================================================
  
  /// Error de conexión de red
  static Future<void> networkError(
    BuildContext context, {
    String? details,
  }) {
    return show(
      context,
      title: 'Error de Conexión',
      message: 'No se pudo conectar al servidor. Verifica tu conexión a internet e intenta nuevamente.',
      errorCode: ErrorCodes.networkConnection,
      technicalDetails: details,
    );
  }
  
  /// Error de autenticación con Ubii
  static Future<void> ubiiAuthError(
    BuildContext context, {
    String? details,
  }) {
    return show(
      context,
      title: 'Error de Autenticación Ubii',
      message: 'No se pudo autenticar con el servidor de Ubii. Verifica las credenciales en la configuración.',
      errorCode: ErrorCodes.ubiiAuth,
      technicalDetails: details,
    );
  }
  
  /// Error de verificación de Pago Móvil
  static Future<void> pagoMovilError(
    BuildContext context, {
    String? details,
  }) {
    return show(
      context,
      title: 'Error en Pago Móvil',
      message: 'No se pudo verificar el Pago Móvil. Verifica los datos ingresados e intenta nuevamente.',
      errorCode: ErrorCodes.pagoMovilVerification,
      technicalDetails: details,
    );
  }
  
  /// Error de rango de números de control agotado
  static Future<void> numeroControlAgotadoError(
    BuildContext context, {
    String? details,
  }) {
    return show(
      context,
      title: 'Rango de Números de Control Agotado',
      message: 'Se ha agotado el rango de números de control autorizado por el SENIAT. NO puede emitir más facturas. Solicite un nuevo rango URGENTEMENTE.',
      errorCode: ErrorCodes.invoiceRangoAgotado,
      technicalDetails: details,
    );
  }
  
  /// Error de base de datos
  static Future<void> databaseError(
    BuildContext context, {
    String? details,
  }) {
    return show(
      context,
      title: 'Error de Base de Datos',
      message: 'Ocurrió un error al acceder a la base de datos. Intenta reiniciar la aplicación.',
      errorCode: ErrorCodes.dbConnection,
      technicalDetails: details,
    );
  }
  
  /// Error de configuración faltante
  static Future<void> configurationError(
    BuildContext context, {
    String? details,
  }) {
    return show(
      context,
      title: 'Error de Configuración',
      message: 'Faltan configuraciones necesarias en el archivo .env. Verifica la configuración antes de continuar.',
      errorCode: ErrorCodes.configMissing,
      technicalDetails: details,
    );
  }
  
  /// Error genérico
  static Future<void> genericError(
    BuildContext context, {
    String? message,
    String? details,
  }) {
    return show(
      context,
      title: 'Error',
      message: message ?? 'Ocurrió un error inesperado. Por favor, intenta nuevamente.',
      errorCode: ErrorCodes.unknown,
      technicalDetails: details,
    );
  }
}
