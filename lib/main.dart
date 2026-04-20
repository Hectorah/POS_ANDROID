import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'providers/user_provider.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/documents_screen.dart';
import 'database/db_helper.dart';
import 'services/config_service.dart';
import 'services/exchange_rate_service.dart';
import 'sync/services/connectivity_service.dart';
import 'sync/manager/sync_manager.dart';
import 'sync/services/realtime_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ============================================================================
  // CARGAR VARIABLES DE ENTORNO
  // ============================================================================
  debugPrint('🔐 Cargando variables de entorno desde .env...');
  try {
    await dotenv.load(fileName: '.env');
    debugPrint('✅ Variables de entorno cargadas correctamente');
  } catch (e) {
    debugPrint('⚠️ Error cargando .env: $e');
    debugPrint('   La app usará valores por defecto');
  }
  
  // ============================================================================
  // INICIALIZACIÓN DE LA BASE DE DATOS
  // ============================================================================
  debugPrint('🚀 Iniciando aplicación POS ANDROID...');
  
  try {
    // Inicializar base de datos SQLite (crítico - debe esperar)
    await DbHelper.initialize();
    
    // Cargar configuración (crítico - debe esperar)
    await ConfigService.loadConfig();

    // ── Offline-First: Supabase + Conectividad + SyncManager ──────────────
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    );
    await ConnectivityService.instance.initialize();
    await SyncManager.instance.initialize();
    await RealtimeSyncService.instance.initialize();
    // ───────────────────────────────────────────────────────────────────────
    
    // Actualizar tasas de cambio en segundo plano (no crítico)
    _updateRatesInBackground();
    
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

/// Actualizar tasas de cambio en segundo plano sin bloquear el inicio
void _updateRatesInBackground() {
  Future.microtask(() async {
    try {
      final needsUpdate = await ExchangeRateService.needsUpdate();
      if (needsUpdate) {
        debugPrint('🔄 Actualizando tasas de cambio en segundo plano...');
        final updated = await ExchangeRateService.updateRates();
        if (updated) {
          // Recargar configuración con las nuevas tasas
          await ConfigService.loadConfig();
          debugPrint('✅ Tasas actualizadas en segundo plano');
        }
      } else {
        final lastUpdate = await ExchangeRateService.getLastUpdateDate();
        if (lastUpdate != null) {
          final hoursAgo = DateTime.now().difference(lastUpdate).inHours;
          debugPrint('ℹ️ Tasas actualizadas hace $hoursAgo horas');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error actualizando tasas en segundo plano: $e');
    }
  });
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
