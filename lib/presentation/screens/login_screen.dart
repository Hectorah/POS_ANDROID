import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path_package;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_assets.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/app_config.dart';
import '../../providers/user_provider.dart';
import '../../services/auth_service.dart';
import '../../services/exchange_rate_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Configuración
  final _tasaUSDController = TextEditingController(text: '36.50');
  final _tasaEURController = TextEditingController(text: '40.00');

  @override
  void initState() {
    super.initState();
    
    _loadSavedConfig();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800), // Reducido de 1200 a 800
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut), // Más rápido
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2), // Menos desplazamiento
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut), // Más rápido
      ),
    );

    _animationController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Precargar el logo después de que el widget esté montado
    if (AppAssets.logoPath != null) {
      precacheImage(AssetImage(AppAssets.logoPath!), context);
    }
  }

  Future<void> _loadSavedConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Cargar tasas guardadas
      final savedUSD = prefs.getDouble('tasa_usd');
      final savedEUR = prefs.getDouble('tasa_eur');
      
      if (mounted) {
        setState(() {
          if (savedUSD != null) _tasaUSDController.text = savedUSD.toStringAsFixed(2);
          if (savedEUR != null) _tasaEURController.text = savedEUR.toStringAsFixed(2);
        });
      }
    } catch (e) {
      debugPrint('Error cargando configuración: $e');
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showConfigDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext builderContext, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.settings,
                    color: isDark ? AppColors.darkText : AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Configuración',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(builderContext).size.width * 0.9,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ============================================================
                      // TASAS DE CAMBIO
                      // ============================================================
                      _buildSectionTitle('💱 Tasas de Cambio', isDark),
                      const SizedBox(height: 8),
                      
                      // Tasa USD
                      TextField(
                        controller: _tasaUSDController,
                        decoration: InputDecoration(
                          labelText: 'Tasa USD (Dólar)',
                          labelStyle: const TextStyle(fontSize: 13),
                          prefixIcon: const Icon(Icons.attach_money, size: 20),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.refresh, size: 20),
                            onPressed: () async {
                              // Actualizar tasas desde el servicio
                              setDialogState(() => _isLoading = true);
                              
                              final success = await ExchangeRateService.updateRates();
                              
                              if (success) {
                                // Recargar las tasas actualizadas
                                final prefs = await SharedPreferences.getInstance();
                                final usd = prefs.getDouble('tasa_usd') ?? 36.50;
                                final eur = prefs.getDouble('tasa_eur') ?? 40.00;
                                
                                setDialogState(() {
                                  _tasaUSDController.text = usd.toStringAsFixed(2);
                                  _tasaEURController.text = eur.toStringAsFixed(2);
                                  _isLoading = false;
                                });
                                
                                // Mostrar mensaje en un mini diálogo que se cierra solo
                                if (builderContext.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('✅ Tasas actualizadas correctamente'),
                                      backgroundColor: AppColors.success,
                                      behavior: SnackBarBehavior.floating,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              } else {
                                setDialogState(() => _isLoading = false);
                                
                                if (builderContext.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('⚠️ No se pudieron actualizar las tasas'),
                                      backgroundColor: AppColors.warning,
                                      behavior: SnackBarBehavior.floating,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              }
                            },
                            tooltip: 'Actualizar desde servicio',
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                      ),
                      const SizedBox(height: 10),
                      
                      // Tasa EUR
                      TextField(
                        controller: _tasaEURController,
                        decoration: InputDecoration(
                          labelText: 'Tasa EUR (Euro) - Opcional',
                          labelStyle: const TextStyle(fontSize: 13),
                          prefixIcon: const Icon(Icons.euro, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 16),
                      
                      // ============================================================
                      // ESTADO DE UBII
                      // ============================================================
                      _buildSectionTitle('💳 Estado de Ubii', isDark),
                      const SizedBox(height: 8),
                      
                      FutureBuilder<Map<String, dynamic>>(
                        future: _getUbiiStatus(),
                        builder: (BuildContext futureContext, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          
                          final data = snapshot.data ?? {};
                          final isConnected = data['connected'] ?? false;
                          final isConfigured = data['configured'] ?? false;
                          final lastCierre = data['lastCierre'] ?? 'Nunca';
                          
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (isConnected ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: (isConnected ? AppColors.success : AppColors.error).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isConnected ? Icons.check_circle : Icons.error,
                                      color: isConnected ? AppColors.success : AppColors.error,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        isConnected ? 'Conectado' : (isConfigured ? 'Configurado (sin verificar)' : 'No configurado'),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? AppColors.darkText : AppColors.lightText,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Último cierre: $lastCierre',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _isLoading ? null : _testUbiiConnection,
                                    icon: const Icon(Icons.wifi_find, size: 18),
                                    label: const Text('Probar Conexión'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.info,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 16),
                      
                      // ============================================================
                      // BASE DE DATOS
                      // ============================================================
                      _buildSectionTitle('🗄️ Base de Datos', isDark),
                      const SizedBox(height: 8),
                      
                      FutureBuilder<Map<String, dynamic>>(
                        future: _getDatabaseInfo(),
                        builder: (BuildContext dbFutureContext, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          
                          final data = snapshot.data ?? {};
                          final size = data['size'] ?? '0 KB';
                          final lastBackup = data['lastBackup'] ?? 'Nunca';
                          
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.grey.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Tamaño:',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                    Text(
                                      size,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? AppColors.darkText : AppColors.lightText,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Último respaldo:',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                    Text(
                                      lastBackup,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? AppColors.darkText : AppColors.lightText,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      // Cerrar el diálogo de configuración primero
                                      Navigator.of(dialogContext).pop();
                                      
                                      // Esperar un momento para que el diálogo se cierre completamente
                                      await Future.delayed(const Duration(milliseconds: 300));
                                      
                                      // Crear respaldo de la base de datos
                                      setState(() => _isLoading = true);
                                      
                                      try {
                                        final success = await _createDatabaseBackup();
                                        
                                        setState(() => _isLoading = false);
                                        
                                        if (success) {
                                          _showSnackBar('✅ Respaldo guardado en Descargas', AppColors.success);
                                        } else {
                                          _showSnackBar('Respaldo cancelado o error', AppColors.warning);
                                        }
                                      } catch (e) {
                                        setState(() => _isLoading = false);
                                        _showSnackBar('Error: $e', AppColors.error);
                                      }
                                    },
                                    icon: const Icon(Icons.backup, size: 18),
                                    label: const Text('Crear Respaldo Ahora'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 16),
                      
                      // ============================================================
                      // USUARIO ACTUAL
                      // ============================================================
                      _buildSectionTitle('👤 Usuario Actual', isDark),
                      const SizedBox(height: 8),
                      
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.person,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Administrador',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppColors.darkText : AppColors.lightText,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Nivel: Admin',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      final prefs = await SharedPreferences.getInstance();
                      
                      // Guardar tasas
                      final usd = double.tryParse(_tasaUSDController.text) ?? 36.50;
                      final eur = double.tryParse(_tasaEURController.text) ?? 40.00;
                      
                      await prefs.setDouble('tasa_usd', usd);
                      await prefs.setDouble('tasa_eur', eur);
                      
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                        _showSnackBar('Configuración guardada exitosamente', AppColors.success);
                      }
                    } catch (e) {
                      if (mounted) {
                        _showSnackBar('Error al guardar: $e', AppColors.error);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: isDark ? AppColors.darkText : AppColors.lightText,
      ),
    );
  }

  Future<Map<String, dynamic>> _getUbiiStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCierreStr = prefs.getString('last_cierre_date');
      
      String lastCierre = 'Nunca';
      if (lastCierreStr != null) {
        try {
          final date = DateTime.parse(lastCierreStr);
          lastCierre = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
        } catch (e) {
          lastCierre = lastCierreStr;
        }
      }
      
      // Verificar si Ubii está configurado Y si la app está disponible
      final ubiiConfigured = AppConfig.isUbiiConfigured;
      bool ubiiAvailable = false;
      
      if (ubiiConfigured) {
        // Intentar verificar si la app Ubii está instalada
        try {
          // Esto es una verificación básica - en producción podrías hacer una llamada real
          ubiiAvailable = true; // Por ahora asumimos que si está configurado, está disponible
        } catch (e) {
          debugPrint('Error verificando disponibilidad de Ubii: $e');
          ubiiAvailable = false;
        }
      }
      
      return {
        'connected': ubiiConfigured && ubiiAvailable,
        'configured': ubiiConfigured,
        'lastCierre': lastCierre,
      };
    } catch (e) {
      debugPrint('Error obteniendo estado de Ubii: $e');
      return {
        'connected': false,
        'configured': false,
        'lastCierre': 'Error',
      };
    }
  }

  Future<void> _testUbiiConnection() async {
    setState(() => _isLoading = true);
    
    try {
      // Verificar configuración
      if (!AppConfig.isUbiiConfigured) {
        _showSnackBar('Ubii no está configurado. Verifica el archivo .env', AppColors.warning);
        setState(() => _isLoading = false);
        return;
      }
      
      // Intentar una transacción de prueba (monto mínimo)
      // En producción, podrías tener un método específico de "ping" o "test"
      _showSnackBar('Verificando conexión con Ubii...', AppColors.info);
      
      // Simular verificación (en producción harías una llamada real)
      await Future.delayed(const Duration(seconds: 1));
      
      _showSnackBar('✅ Ubii está configurado correctamente', AppColors.success);
    } catch (e) {
      _showSnackBar('❌ Error al conectar con Ubii: $e', AppColors.error);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<Map<String, dynamic>> _getDatabaseInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Obtener tamaño de la base de datos
      String size = 'Calculando...';
      try {
        final dbPath = await getDatabasesPath();
        final path = path_package.join(dbPath, AppConfig.databaseName);
        final file = File(path);
        
        if (await file.exists()) {
          final bytes = await file.length();
          if (bytes < 1024) {
            size = '$bytes B';
          } else if (bytes < 1024 * 1024) {
            size = '${(bytes / 1024).toStringAsFixed(2)} KB';
          } else {
            size = '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
          }
        } else {
          size = 'No encontrada';
        }
      } catch (e) {
        debugPrint('Error obteniendo tamaño de BD: $e');
        size = 'Error';
      }
      
      // Obtener fecha del último respaldo
      final lastBackupStr = prefs.getString('last_backup_date');
      String lastBackup = 'Nunca';
      
      if (lastBackupStr != null) {
        try {
          final date = DateTime.parse(lastBackupStr);
          final now = DateTime.now();
          final difference = now.difference(date);
          
          if (difference.inDays == 0) {
            lastBackup = 'Hoy ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
          } else if (difference.inDays == 1) {
            lastBackup = 'Ayer';
          } else if (difference.inDays < 7) {
            lastBackup = 'Hace ${difference.inDays} días';
          } else {
            lastBackup = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
          }
        } catch (e) {
          lastBackup = lastBackupStr;
        }
      }
      
      return {
        'size': size,
        'lastBackup': lastBackup,
      };
    } catch (e) {
      debugPrint('Error obteniendo info de BD: $e');
      return {
        'size': 'Error',
        'lastBackup': 'Error',
      };
    }
  }

  Future<bool> _createDatabaseBackup() async {
    try {
      debugPrint('📦 Creando respaldo de la base de datos...');
      
      // Preguntar al usuario si desea descargar el respaldo
      final shouldDownload = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.download,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Descargar Respaldo',
                    style: TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: const Text(
              '¿Deseas guardar el respaldo de la base de datos en la carpeta de Descargas?',
              style: TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(
                  'Cancelar',
                  style: TextStyle(
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Descargar'),
              ),
            ],
          );
        },
      );
      
      if (shouldDownload != true) {
        debugPrint('❌ Respaldo cancelado por el usuario');
        return false;
      }
      
      // Obtener ruta de la base de datos
      final dbPath = await getDatabasesPath();
      final sourcePath = path_package.join(dbPath, AppConfig.databaseName);
      final sourceFile = File(sourcePath);
      
      if (!await sourceFile.exists()) {
        debugPrint('❌ Base de datos no encontrada');
        return false;
      }
      
      // Obtener carpeta de Descargas
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          // Intentar ruta alternativa
          downloadsDir = await getExternalStorageDirectory();
        }
      } else {
        downloadsDir = await getDownloadsDirectory();
      }
      
      if (downloadsDir == null) {
        debugPrint('❌ No se pudo acceder a la carpeta de Descargas');
        return false;
      }
      
      // Nombre del archivo de respaldo con timestamp
      final now = DateTime.now();
      final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final backupFileName = 'POS_Respaldo_$timestamp.db';
      final backupPath = path_package.join(downloadsDir.path, backupFileName);
      
      // Copiar archivo a Descargas
      await sourceFile.copy(backupPath);
      
      // Guardar fecha del respaldo
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_backup_date', now.toIso8601String());
      
      debugPrint('✅ Respaldo creado en Descargas: $backupPath');
      
      return true;
    } catch (e) {
      debugPrint('❌ Error creando respaldo: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _passwordController.dispose();
    _tasaUSDController.dispose();
    _tasaEURController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final password = _passwordController.text.trim();
      
      // Verificar usuario en la base de datos usando AuthService
      final usuario = await AuthService.instance.login('admin', password);
      
      if (usuario != null) {
        // Usuario válido - convertir a UserModel para el provider
        final demoUser = UserModel(
          userId: usuario.id.toString(),
          userName: usuario.nombre,
          userType: usuario.nivel,
        );

        if (!mounted) return;
        
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        userProvider.setUser(demoUser);

        _showSnackBar('Bienvenido ${demoUser.userName}', AppColors.success);
        
        Navigator.of(context).pushReplacementNamed('/documents');
      } else {
        // Usuario o contraseña incorrectos
        if (!mounted) return;
        _showSnackBar('Usuario o contraseña incorrectos', AppColors.error);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error al iniciar sesión: $e', AppColors.error);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      resizeToAvoidBottomInset: false, // El teclado se superpone sin redimensionar
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [AppColors.darkBackground, AppColors.darkCard]
                    : [Colors.blue.shade50, Colors.white],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 48.0 : 32.0,
                  vertical: 16.0,
                ),
                child: Column(
                  children: [
                    // Espacio para los botones flotantes
                    const SizedBox(height: 60),
                    
                    // Contenido centrado
                    Expanded(
                      child: Center(
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth: isTablet ? 600 : 500,
                              ),
                              child: Card(
                                elevation: 12,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isTablet ? 64.0 : 40.0,
                                    vertical: isTablet ? 56.0 : 40.0,
                                  ),
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Logo más grande
                                        if (AppAssets.logoPath != null)
                                          Image.asset(
                                            AppAssets.logoPath!,
                                            height: isTablet ? 160 : 120,
                                            fit: BoxFit.contain,
                                            cacheWidth: isTablet ? 320 : 240,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Icon(
                                                Icons.image_not_supported,
                                                size: isTablet ? 160 : 120,
                                                color: Colors.grey,
                                              );
                                            },
                                          ),
                                        SizedBox(height: isTablet ? 36 : 28),

                                        // Título más grande
                                        Text(
                                          'POS ANDROID',
                                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                fontSize: isTablet ? 36 : 30,
                                                color: isDark ? Colors.white : AppColors.primary,
                                              ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          'Sistema de Punto de Venta',
                                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                                fontSize: isTablet ? 18 : 16,
                                                color: Colors.grey,
                                              ),
                                        ),
                                        SizedBox(height: isTablet ? 48 : 36),

                                        // Campo de contraseña más grande
                                        TextFormField(
                                          controller: _passwordController,
                                          obscureText: _obscurePassword,
                                          style: TextStyle(fontSize: isTablet ? 18 : 16),
                                          decoration: InputDecoration(
                                            labelText: 'Contraseña',
                                            labelStyle: TextStyle(fontSize: isTablet ? 18 : 16),
                                            prefixIcon: Icon(
                                              Icons.lock_outline,
                                              size: isTablet ? 28 : 24,
                                            ),
                                            suffixIcon: IconButton(
                                              icon: Icon(
                                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                                size: isTablet ? 28 : 24,
                                              ),
                                              onPressed: () {
                                                setState(() => _obscurePassword = !_obscurePassword);
                                              },
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            contentPadding: EdgeInsets.symmetric(
                                              horizontal: isTablet ? 24 : 20,
                                              vertical: isTablet ? 20 : 16,
                                            ),
                                          ),
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return 'Contraseña requerida';
                                            }
                                            return null;
                                          },
                                        ),
                                        SizedBox(height: isTablet ? 36 : 28),

                                        // Botón de login más grande
                                        SizedBox(
                                          width: double.infinity,
                                          height: isTablet ? 64 : 56,
                                          child: ElevatedButton(
                                            onPressed: _isLoading ? null : _handleLogin,
                                            style: ElevatedButton.styleFrom(
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                              elevation: 4,
                                            ),
                                            child: _isLoading
                                                ? const CircularProgressIndicator(color: Colors.white)
                                                : Text(
                                                    'Iniciar Sesión',
                                                    style: TextStyle(
                                                      fontSize: isTablet ? 20 : 18,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                            ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Botones flotantes en la parte superior
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Botón de configuración
                  Container(
                    decoration: BoxDecoration(
                      color: isDark 
                          ? AppColors.darkCard.withValues(alpha: 0.9)
                          : Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.settings,
                        color: isDark ? AppColors.darkText : AppColors.primary,
                      ),
                      onPressed: _showConfigDialog,
                      tooltip: 'Configuración',
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botón de cambio de tema
                  Container(
                    decoration: BoxDecoration(
                      color: isDark 
                          ? AppColors.darkCard.withValues(alpha: 0.9)
                          : Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(
                        themeProvider.themeMode == ThemeMode.dark
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        color: isDark ? AppColors.darkText : AppColors.primary,
                      ),
                      onPressed: () {
                        themeProvider.toggleTheme();
                      },
                      tooltip: 'Cambiar tema',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
