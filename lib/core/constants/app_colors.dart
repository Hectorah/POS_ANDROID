import 'package:flutter/material.dart';

class AppColors {
  // ============================================================================
  // PALETA CORPORATIVA - COLORES PRINCIPALES
  // ============================================================================
  
  // Azul Marino Profundo (#001756) - Color principal de identidad corporativa
  // Se usa en:
  // - Botones principales (Login, Guardar, etc.)
  // - Bottom Navigation Bar (iconos activos)
  // - FloatingActionButton
  // - Headers y títulos importantes
  // - Bordes de elementos seleccionados
  // - Gráficas y charts (línea principal)
  static const Color primary = Color(0xFF001756);
  
  // Azul Obsidiana (#010A23) - Tono más oscuro
  // Se usa en:
  // - Textos destacados sobre fondos claros
  // - Fondos en modo oscuro
  // - Hover states de botones
  // - Sombras de elementos principales
  static const Color primaryDark = Color(0xFF010A23);
  
  // Azul Medianoche (#24306E) - Tono intermedio
  // Se usa en:
  // - Encabezados de sección
  // - Variantes de tarjetas
  // - Estados hover suaves
  // - Fondos de iconos con opacidad
  static const Color primaryLight = Color(0xFF24306E);
  
  // ============================================================================
  // COLORES DE ACENTO (Accent Colors)
  // ============================================================================
  
  // Azul Eléctrico (#4880FF) - Color de acción
  // Se usa en:
  // - Botones de acción importantes
  // - Interruptores activos (switches)
  // - Resaltar datos importantes
  // - Badges y notificaciones
  // - Gráficas (segunda línea o segmento)
  // - Indicadores de estado activo
  static const Color accent = Color(0xFF4880FF);
  
  // Azul Eléctrico claro - Variante más suave
  // Se usa en:
  // - Hover states de elementos de acción
  // - Fondos suaves de alertas informativas
  static const Color accentLight = Color(0xFF6B9AFF);
  
  // ============================================================================
  // TEMA OSCURO (Dark Theme) - Paleta Morado/Naranja
  // ============================================================================
  
  // Morado oscuro - Fondo principal oscuro
  // Se usa en:
  // - Fondo de toda la aplicación en modo oscuro
  // - Fondo de modals y dialogs
  static const Color darkBackground = Color(0xFF1A1A2E);
  
  // Morado medio - Tarjetas oscuras
  // Se usa en:
  // - Cards de estadísticas
  // - Cards de documentos
  // - Cards de productos/clientes
  // - AppBar background
  // - Bottom Navigation Bar background
  // - Campos de texto (TextField background)
  static const Color darkCard = Color(0xFF16213E);
  
  // Morado principal - Color primario oscuro
  // Se usa en:
  // - Botones principales en modo oscuro
  // - Elementos destacados
  // - Iconos activos
  static const Color darkPrimary = Color(0xFF6B2FBF);
  
  // Naranja - Color de acento oscuro
  // Se usa en:
  // - Botones de acción en modo oscuro
  // - Elementos interactivos
  // - Badges y notificaciones
  static const Color darkAccent = Color(0xFFFF8C00);
  
  // Blanco Puro (#FFFFFF) - Texto principal oscuro
  // Se usa en:
  // - Títulos principales
  // - Texto de botones
  // - Labels importantes
  // - Nombres de productos/clientes
  static const Color darkText = Color(0xFFFFFFFF);
  
  // Gris claro - Texto secundario oscuro
  // Se usa en:
  // - Subtítulos
  // - Descripciones
  // - Hints en campos de texto
  // - Iconos inactivos
  // - Fechas y metadata
  static const Color darkTextSecondary = Color(0xFFB0B0B0);
  
  // Gris medio - Bordes oscuros
  // Se usa en:
  // - Bordes de cards
  // - Bordes de campos de texto
  // - Separadores entre elementos
  // - Líneas divisorias
  static const Color darkBorder = Color(0xFF2E3A59);
  
  // ============================================================================
  // TEMA CLARO (Light Theme)
  // ============================================================================
  
  // Gris Gélido (#EFF0F4) - Fondo principal claro
  // Se usa en:
  // - Fondo de toda la aplicación en modo claro (Scaffold)
  // - Fondo general para que las tarjetas blancas resalten
  static const Color lightBackground = Color(0xFFEFF0F4);
  
  // Blanco Puro (#FFFFFF) - Tarjetas claras
  // Se usa en:
  // - Cards de estadísticas
  // - Cards de documentos
  // - Cards de productos/clientes
  // - AppBar background
  // - Bottom Navigation Bar background
  // - Campos de texto (TextField background)
  static const Color lightCard = Color(0xFFFFFFFF);
  
  // Azul Obsidiana (#010A23) - Texto principal claro
  // Se usa en:
  // - Títulos principales
  // - Texto de contenido
  // - Labels importantes
  // - Nombres de productos/clientes
  static const Color lightText = Color(0xFF010A23);
  
  // Azul Marino Profundo (#001756) - Texto secundario claro
  // Se usa en:
  // - Subtítulos
  // - Descripciones
  // - Hints en campos de texto
  // - Iconos inactivos
  // - Fechas y metadata
  static const Color lightTextSecondary = Color(0xFF001756);
  
  // Gris Gélido oscuro - Bordes claros
  // Se usa en:
  // - Bordes de cards
  // - Bordes de campos de texto
  // - Separadores entre elementos
  // - Líneas divisorias
  static const Color lightBorder = Color(0xFFD8DAE0);
  
  // ============================================================================
  // COLORES COMUNES (Usados en ambos temas)
  // ============================================================================
  
  // Verde de éxito - Se usa en:
  // - Mensajes de éxito (SnackBar)
  // - Botón "PROCESAR Y EMITIR"
  // - Indicador de stock alto
  // - Estado "Firmado" de documentos
  // - Método de pago "Pago Móvil" en gráfica
  // - Iconos de confirmación
  static const Color success = Color(0xFF4CAF50);
  
  // Verde oscuro para montos - Se usa en:
  // - Montos de dinero en facturas
  // - Totales y subtotales
  // - Precios de productos
  static const Color successDark = Color(0xFF2E7D32);
  
  // Amarillo de advertencia - Se usa en:
  // - Mensajes de advertencia
  // - Indicador de stock bajo
  // - Notas de crédito (color de tipo)
  // - Método de pago "Cashea" en gráfica
  // - Alertas importantes
  static const Color warning = Color(0xFFFFC107);
  
  // Rojo de error - Se usa en:
  // - Mensajes de error (SnackBar)
  // - Validaciones fallidas
  // - Botones de eliminar
  // - Indicador de stock crítico
  // - Iconos de cerrar/cancelar
  static const Color error = Color(0xFFF44336);
  
  // Azul informativo - Se usa en:
  // - Mensajes informativos
  // - Notas de débito (color de tipo)
  // - Método de pago "Débito Inmediato" en gráfica
  // - Links y elementos clickeables
  // - Iconos de información
  static const Color info = Color(0xFF2196F3);
  
  // Negro para sombras - Se usa en:
  // - Sombras de cards (con opacidad)
  // - Sombras de botones elevados
  // - Overlays de modals
  static const Color shadow = Color(0xFF000000);
  
  // ============================================================================
  // COLORES DE TEXTO ESPECÍFICOS
  // ============================================================================
  
  // Texto blanco - Se usa en:
  // - Texto sobre botones de color
  // - Texto sobre fondos oscuros
  // - Texto en AppBar oscuro
  static const Color textLight = Color(0xFFFFFFFF);
  
  // Texto negro - Se usa en:
  // - Texto sobre botones claros
  // - Texto sobre fondos claros
  static const Color textDark = Color(0xFF000000);
}

// ============================================================================
// PALETA CORPORATIVA - RESUMEN
// ============================================================================
//
// MODO CLARO (Paleta Corporativa Azul):
// - Azul Marino Profundo (#001756): Identidad corporativa, botones principales
// - Azul Eléctrico (#4880FF): Acciones, interruptores, datos importantes
// - Azul Medianoche (#24306E): Encabezados, variantes de tarjetas
// - Azul Obsidiana (#010A23): Textos destacados
// - Gris Gélido (#EFF0F4): Fondo general de la app
// - Blanco Puro (#FFFFFF): Tarjetas, inputs
//
// MODO OSCURO (Paleta Morado/Naranja):
// - Morado oscuro (#1A1A2E): Fondo principal
// - Morado medio (#16213E): Tarjetas y cards
// - Morado principal (#6B2FBF): Botones y elementos destacados
// - Naranja (#FF8C00): Acciones y elementos interactivos
// - Blanco (#FFFFFF): Texto principal
// - Gris claro (#B0B0B0): Texto secundario
//
// GUÍA DE USO:
//
// 1. MODO CLARO:
//    - Fondo: Gris Gélido (#EFF0F4)
//    - Tarjetas: Blanco Puro (#FFFFFF)
//    - Texto principal: Azul Obsidiana (#010A23)
//    - Texto secundario: Azul Marino Profundo (#001756)
//    - Botones: Azul Marino Profundo (#001756)
//    - Acciones: Azul Eléctrico (#4880FF)
//
// 2. MODO OSCURO:
//    - Fondo: Morado oscuro (#1A1A2E)
//    - Tarjetas: Morado medio (#16213E)
//    - Texto principal: Blanco (#FFFFFF)
//    - Texto secundario: Gris claro (#B0B0B0)
//    - Botones: Morado principal (#6B2FBF)
//    - Acciones: Naranja (#FF8C00)
//
// NOTA: Después de cambiar colores, ejecuta 'flutter clean' y reinicia la app 