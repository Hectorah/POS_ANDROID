import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'providers/user_provider.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/documents_screen.dart';
import 'database/db_helper.dart';
import 'services/config_service.dart';
import 'services/exchange_rate_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ============================================================================
  // INICIALIZACIÓN DE LA BASE DE DATOS
  // ============================================================================
  debugPrint('🚀 Iniciando aplicación POS ANDROID...');
  
  try {
    // Inicializar base de datos SQLite
    await DbHelper.initialize();
    
    // Cargar configuración (tasas, URL, etc.)
    await ConfigService.loadConfig();
    
    // Actualizar tasas de cambio si es necesario
    final needsUpdate = await ExchangeRateService.needsUpdate();
    if (needsUpdate) {
      debugPrint('🔄 Actualizando tasas de cambio...');
      final updated = await ExchangeRateService.updateRates();
      if (updated) {
        // Recargar configuración con las nuevas tasas
        await ConfigService.loadConfig();
      }
    } else {
      final lastUpdate = await ExchangeRateService.getLastUpdateDate();
      if (lastUpdate != null) {
        final hoursAgo = DateTime.now().difference(lastUpdate).inHours;
        debugPrint('ℹ️ Tasas actualizadas hace $hoursAgo horas');
      }
    }
    
    debugPrint('✅ Inicialización completada');
  } catch (e) {
    debugPrint('❌ Error en inicialización: $e');
    // La app continuará, pero mostrará errores si intenta usar la BD
  }
  
  // ============================================================================
  // CONFIGURACIÓN DE LA INTERFAZ
  // ============================================================================
  
  // Set preferred orientations for tablets
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Configurar pantalla completa - ocultar barra de navegación del sistema
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
    overlays: [SystemUiOverlay.top], // Solo mostrar barra de estado superior
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'POS ANDROID',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            initialRoute: '/',
            routes: {
              '/': (context) => const LoginScreen(),
              '/documents': (context) => const DocumentsScreen(),
            },
          );
        },
      ),
    );
  }
}
