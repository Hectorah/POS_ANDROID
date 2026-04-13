import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/excel_service.dart';
import 'create_document_screen.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  bool _isCheckingProducts = true;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _checkAndShowWelcomeModal();
  }

  /// Verificar si es la primera vez y mostrar modal de bienvenida
  Future<void> _checkAndShowWelcomeModal() async {
    try {
      // Verificar si ya se mostró el modal antes
      final prefs = await SharedPreferences.getInstance();
      final hasSeenWelcome = prefs.getBool('has_seen_welcome') ?? false;

      // Contar productos en la BD
      final productCount = await ExcelService.contarProductos();

      setState(() => _isCheckingProducts = false);

      // Solo mostrar si no tiene productos Y no ha visto el modal
      if (productCount == 0 && !hasSeenWelcome && mounted) {
        // Pequeño delay para que la UI se renderice primero
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          _showWelcomeModal();
        }
      }
    } catch (e) {
      debugPrint('❌ Error verificando productos: $e');
      setState(() => _isCheckingProducts = false);
    }
  }

  /// Mostrar modal de bienvenida elegante
  void _showWelcomeModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false, // No se puede cerrar tocando afuera
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.waving_hand_rounded,
                      size: 48,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '¡Bienvenido!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Parece que es tu primera vez aquí.',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '¿Deseas importar tu inventario desde Excel o prefieres empezar de cero?',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (_isImporting)
                    Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Importando productos...',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              actions: _isImporting
                  ? []
                  : [
                      // Botón: Empezar de cero
                      TextButton.icon(
                        onPressed: () async {
                          // Marcar que ya vio el modal
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('has_seen_welcome', true);
                          
                          if (context.mounted) {
                            Navigator.of(dialogContext).pop();
                            _showSnackBar('Puedes importar productos más tarde desde el menú', AppColors.info);
                          }
                        },
                        icon: const Icon(Icons.edit_note_rounded),
                        label: const Text('Empezar de Cero'),
                        style: TextButton.styleFrom(
                          foregroundColor: isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Botón: Importar desde Excel
                      ElevatedButton.icon(
                        onPressed: () async {
                          setDialogState(() => _isImporting = true);
                          setState(() => _isImporting = true);

                          // Llamar al servicio de importación
                          final resultado = await ExcelService.importarProductos();

                          setDialogState(() => _isImporting = false);
                          setState(() => _isImporting = false);

                          if (resultado['success']) {
                            // Marcar que ya vio el modal
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('has_seen_welcome', true);

                            if (context.mounted) {
                              Navigator.of(dialogContext).pop();
                              
                              // Mostrar diálogo de éxito con detalles
                              _showSuccessDialog(
                                '${resultado['nuevos'] ?? 0} nuevos',
                                '${resultado['actualizados'] ?? 0} actualizados',
                                '${resultado['omitidos'] ?? 0} omitidos',
                              );
                            }
                          } else {
                            if (context.mounted) {
                              _showSnackBar(
                                resultado['message'] ?? 'Error al importar',
                                AppColors.error,
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.upload_file_rounded),
                        label: const Text('Importar desde Excel'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
            );
          },
        );
      },
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Mostrar diálogo de éxito con estadísticas detalladas
  void _showSuccessDialog(String nuevos, String actualizados, String omitidos) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 48,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '¡Importación Exitosa!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatRow(
                Icons.fiber_new_rounded,
                'Productos nuevos',
                nuevos,
                AppColors.success,
                isDark,
              ),
              const SizedBox(height: 12),
              _buildStatRow(
                Icons.update_rounded,
                'Productos actualizados',
                actualizados,
                AppColors.info,
                isDark,
              ),
              if (omitidos != '0') ...[
                const SizedBox(height: 12),
                _buildStatRow(
                  Icons.warning_rounded,
                  'Filas omitidas',
                  omitidos,
                  AppColors.warning,
                  isDark,
                ),
              ],
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Entendido'),
            ),
          ],
          actionsAlignment: MainAxisAlignment.center,
        );
      },
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Documentos'),
            Text(
              'Hola, ${userProvider.currentUser?.userName ?? 'Usuario'}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        automaticallyImplyLeading: false,
        actions: [
          // Botón para importar productos manualmente
          IconButton(
            icon: Icon(
              Icons.upload_file_rounded,
              color: isDark ? AppColors.darkText : AppColors.primary,
            ),
            onPressed: () => _showImportDialog(),
            tooltip: 'Importar productos',
          ),
          IconButton(
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
          IconButton(
            icon: const Icon(
              Icons.logout_rounded,
              color: AppColors.error,
            ),
            onPressed: () => _showLogoutDialog(context, userProvider),
            tooltip: 'Cerrar sesión',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isCheckingProducts
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Verificando inventario...',
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.description,
                      size: 64,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Gestión de Documentos',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Aquí podrás ver el historial de documentos emitidos',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CreateDocumentScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Crear Nueva Factura'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textLight,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  /// Mostrar diálogo para importar productos manualmente
  void _showImportDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool isImporting = false;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.upload_file_rounded,
                    color: isDark ? AppColors.darkText : AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Importar Productos',
                    style: TextStyle(
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Selecciona un archivo Excel (.xlsx) o CSV (.csv) con tus productos.',
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.info.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: AppColors.info,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Formato: CodArticulo, CodBarras, Nombre, Precio, Stock',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isImporting) ...[
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(),
                    const SizedBox(height: 8),
                    Text(
                      'Importando...',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ],
              ),
              actions: isImporting
                  ? []
                  : [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text(
                          'Cancelar',
                          style: TextStyle(
                            color: isDark ? AppColors.darkText : AppColors.lightText,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          setDialogState(() => isImporting = true);

                          final resultado = await ExcelService.importarProductos();

                          setDialogState(() => isImporting = false);

                          if (resultado['success']) {
                            if (context.mounted) {
                              Navigator.of(dialogContext).pop();
                              
                              // Mostrar diálogo de éxito con detalles
                              _showSuccessDialog(
                                '${resultado['nuevos'] ?? 0} nuevos',
                                '${resultado['actualizados'] ?? 0} actualizados',
                                '${resultado['omitidos'] ?? 0} omitidos',
                              );
                            }
                          } else {
                            if (context.mounted) {
                              _showSnackBar(
                                resultado['message'] ?? 'Error al importar',
                                AppColors.error,
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.upload_rounded),
                        label: const Text('Seleccionar Archivo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
            );
          },
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context, UserProvider userProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.logout_rounded, color: AppColors.error),
              const SizedBox(width: 12),
              Text(
                'Cerrar Sesión',
                style: TextStyle(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
            ],
          ),
          content: Text(
            '¿Estás seguro que deseas cerrar sesión?',
            style: TextStyle(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
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
                Navigator.of(dialogContext).pop();
                await userProvider.logout();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/',
                    (route) => false,
                  );
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Sesión cerrada exitosamente'),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Cerrar Sesión'),
            ),
          ],
        );
      },
    );
  }
}
