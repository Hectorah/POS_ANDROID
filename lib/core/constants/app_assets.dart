/// Clase para gestionar las rutas de assets de la aplicación
/// 
/// Uso:
/// ```dart
/// Image.asset(AppAssets.logoMain)
/// Image.asset(AppAssets.iconCash)
/// ```
class AppAssets {
  // ============================================================================
  // LOGOS
  // ============================================================================
  
  /// Logo principal de la empresa (KLK)
  /// Usar en: Splash screen, Login, About
  static const String logoMain = 'assets/logos/klk.png';
  
  /// Getter para compatibilidad con código existente
  static String? get logo => logoPath;
  static String? get logoPath => logoMain;
  
  /// Logo en blanco (para fondos oscuros)
  /// Usar en: AppBar en modo oscuro, headers oscuros
  static const String logoWhite = 'assets/logos/logo_white.png';
  
  /// Logo en oscuro (para fondos claros)
  /// Usar en: AppBar en modo claro, headers claros
  static const String logoDark = 'assets/logos/logo_dark.png';
  
  /// Splash screen
  /// Usar en: Pantalla de carga inicial
  static const String splash = 'assets/logos/splash.png';
  
  // ============================================================================
  // ICONOS DE MÉTODOS DE PAGO
  // ============================================================================
  
  /// Icono de efectivo
  static const String iconCash = 'assets/icons/cash.png';
  
  /// Icono de tarjeta de crédito/débito
  static const String iconCard = 'assets/icons/card.png';
  
  /// Icono de Pago Móvil
  static const String iconPagoMovil = 'assets/icons/pago_movil.png';
  
  /// Icono de Débito Inmediato
  static const String iconDebitInmediato = 'assets/icons/debit_inmediato.png';
  
  /// Icono de Cashea
  static const String iconCashea = 'assets/icons/cashea.png';
  
  // ============================================================================
  // ICONOS DE CATEGORÍAS
  // ============================================================================
  
  /// Icono de categoría Electrónica
  static const String categoryElectronics = 'assets/icons/category_electronics.png';
  
  /// Icono de categoría Ropa
  static const String categoryClothing = 'assets/icons/category_clothing.png';
  
  /// Icono de categoría Alimentos
  static const String categoryFood = 'assets/icons/category_food.png';
  
  /// Icono de categoría Servicios
  static const String categoryServices = 'assets/icons/category_services.png';
  
  // ============================================================================
  // IMÁGENES GENERALES
  // ============================================================================
  
  /// Imagen de placeholder para productos sin foto
  static const String productPlaceholder = 'assets/images/product_placeholder.png';
  
  /// Imagen de placeholder para clientes sin foto
  static const String clientPlaceholder = 'assets/images/client_placeholder.png';
  
  /// Imagen de fondo para pantalla vacía
  static const String emptyState = 'assets/images/empty_state.png';
  
  /// Imagen de error
  static const String errorImage = 'assets/images/error.png';
  
  /// Imagen de éxito
  static const String successImage = 'assets/images/success.png';
  
  // ============================================================================
  // ILUSTRACIONES
  // ============================================================================
  
  /// Ilustración de bienvenida
  static const String illustrationWelcome = 'assets/images/illustration_welcome.png';
  
  /// Ilustración de sin conexión
  static const String illustrationNoConnection = 'assets/images/illustration_no_connection.png';
  
  /// Ilustración de sin datos
  static const String illustrationNoData = 'assets/images/illustration_no_data.png';
}

// ============================================================================
// GUÍA DE USO
// ============================================================================
//
// 1. AGREGAR IMÁGENES:
//    - Coloca tus imágenes en las carpetas correspondientes:
//      * assets/logos/ - Para logos
//      * assets/icons/ - Para iconos
//      * assets/images/ - Para imágenes generales
//
// 2. USAR EN LA APP:
//    ```dart
//    // Para imágenes
//    Image.asset(AppAssets.logoMain)
//    
//    // Para iconos con tamaño
//    Image.asset(
//      AppAssets.iconCash,
//      width: 24,
//      height: 24,
//    )
//    
//    // Con color tint
//    Image.asset(
//      AppAssets.iconCard,
//      color: AppColors.primary,
//    )
//    ```
//
// 3. FORMATOS RECOMENDADOS:
//    - Logos: PNG con transparencia
//    - Iconos: PNG o SVG (24x24, 48x48)
//    - Imágenes: PNG o JPG
//    - Tamaños: @1x, @2x, @3x para diferentes densidades
//
// 4. NOMBRADO DE ARCHIVOS:
//    - Usar snake_case: logo_main.png
//    - Ser descriptivo: icon_pago_movil.png
//    - Incluir variantes: logo_white.png, logo_dark.png
//
// ============================================================================
