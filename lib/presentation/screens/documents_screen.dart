import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../database/db_helper.dart';
import '../../providers/user_provider.dart';
import '../../services/excel_service.dart';
import 'create_document_screen.dart' show CreateDocumentScreen, CurrencyFormatter;
import 'admin_cierre_lote_screen.dart';
import 'products_list_screen.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  bool _isCheckingProducts = true;
  bool _isImporting = false;
  bool _isLoadingInvoices = true;
  List<Map<String, dynamic>> _invoices = [];

  @override
  void initState() {
    super.initState();
    _checkAndShowWelcomeModal();
    _loadInvoices();
  }

  /// Cargar las últimas 10 facturas
  Future<void> _loadInvoices() async {
    try {
      setState(() => _isLoadingInvoices = true);
      
      final invoices = await DbHelper.instance.obtenerFacturas(limit: 10);
      
      if (mounted) {
        setState(() {
          _invoices = invoices;
          _isLoadingInvoices = false;
        });
      }
      
      debugPrint('✅ ${_invoices.length} facturas cargadas');
    } catch (e) {
      debugPrint('❌ Error cargando facturas: $e');
      if (mounted) {
        setState(() => _isLoadingInvoices = false);
      }
    }
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
                                '${resultado['nuevos'] ?? 0}',
                                '${resultado['actualizados'] ?? 0}',
                                '${resultado['omitidos'] ?? 0}',
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
          // Botón de menú desplegable con todas las opciones
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              color: isDark ? AppColors.darkText : AppColors.primary,
            ),
            tooltip: 'Opciones',
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            constraints: const BoxConstraints(
              minWidth: 200, // Ancho mínimo
              maxWidth: 250, // Ancho máximo para responsive
            ),
            onSelected: (String value) {
              switch (value) {
                case 'productos':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProductsListScreen(),
                    ),
                  );
                  break;
                case 'cierre_lote':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminCierreLoteScreen(),
                    ),
                  );
                  break;
                case 'cierre_x':
                  _showCierreXDialog();
                  break;
                case 'cierre_z':
                  _showCierreZDialog();
                  break;
                case 'importar':
                  _showImportDialog();
                  break;
                case 'tema':
                  themeProvider.toggleTheme();
                  break;
                case 'logout':
                  _showLogoutDialog(context, userProvider);
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              // Productos
              PopupMenuItem<String>(
                value: 'productos',
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.inventory_2,
                      color: isDark ? AppColors.darkText : AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Productos',
                        style: TextStyle(
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Cierre de Lote
              PopupMenuItem<String>(
                value: 'cierre_lote',
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.receipt_long,
                      color: isDark ? AppColors.darkText : AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Cierre de Lote',
                        style: TextStyle(
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Cierre X
              PopupMenuItem<String>(
                value: 'cierre_x',
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.close,
                      color: isDark ? AppColors.darkText : AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Cierre X',
                        style: TextStyle(
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Cierre Z
              PopupMenuItem<String>(
                value: 'cierre_z',
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.block,
                      color: AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Cierre Z',
                        style: TextStyle(
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Importar productos
              PopupMenuItem<String>(
                value: 'importar',
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.upload_file_rounded,
                      color: isDark ? AppColors.darkText : AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Importar Productos',
                        style: TextStyle(
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Cambiar tema
              PopupMenuItem<String>(
                value: 'tema',
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      themeProvider.themeMode == ThemeMode.dark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      color: isDark ? AppColors.darkText : AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        themeProvider.themeMode == ThemeMode.dark
                            ? 'Modo Claro'
                            : 'Modo Oscuro',
                        style: TextStyle(
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Divisor
              const PopupMenuDivider(),
              // Cerrar sesión
              PopupMenuItem<String>(
                value: 'logout',
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.logout_rounded,
                      color: AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Cerrar Sesión',
                        style: TextStyle(
                          color: isDark ? AppColors.error : AppColors.error,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
          : _isLoadingInvoices
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Cargando facturas...',
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : _invoices.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.description_outlined,
                              size: 64,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No hay facturas',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkText : AppColors.lightText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Crea tu primera factura para comenzar',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),
                            ElevatedButton.icon(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const CreateDocumentScreen(),
                                  ),
                                );
                                // Recargar facturas al volver
                                _loadInvoices();
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
                    )
                  : RefreshIndicator(
                      onRefresh: _loadInvoices,
                      child: Column(
                        children: [
                          // Header con título y botón
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Últimas Facturas',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? AppColors.darkText : AppColors.lightText,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_invoices.length} registros',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const CreateDocumentScreen(),
                                      ),
                                    );
                                    // Recargar facturas al volver
                                    _loadInvoices();
                                  },
                                  icon: const Icon(Icons.add, size: 20),
                                  label: const Text('Nueva'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: AppColors.textLight,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Lista de facturas
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _invoices.length,
                              itemBuilder: (context, index) {
                                final invoice = _invoices[index];
                                return _buildInvoiceCard(invoice, isDark);
                              },
                            ),
                          ),
                        ],
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
                  Expanded(
                    child: Text(
                      'Importar Productos',
                      style: TextStyle(
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                        fontSize: 18,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selecciona un archivo Excel (.xlsx) o CSV (.csv) con tus productos.',
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        fontSize: 14,
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: AppColors.info,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Formato Excel requerido:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppColors.darkText : AppColors.lightText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• Columna A: CodArticulo\n'
                            '• Columna B: CodBarras\n'
                            '• Columna C: Nombre\n'
                            '• Columna D: Precio\n'
                            '• Columna E: Stock',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'La primera fila debe contener los encabezados.',
                            style: TextStyle(
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isImporting) ...[
                      const SizedBox(height: 16),
                      const Center(child: CircularProgressIndicator()),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Importando...',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
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
                                '${resultado['nuevos'] ?? 0}',
                                '${resultado['actualizados'] ?? 0}',
                                '${resultado['omitidos'] ?? 0}',
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

  void _showCierreXDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warning,
                size: 20,
              ),
               SizedBox(width: 8),
               Expanded(
                child: Text(
                  'Confirmar Cierre X',
                  style: TextStyle(fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: const Text(
            '¿Estás seguro de realizar el Cierre X?\n\nEsta acción procesará todas las transacciones del día.',
            style: TextStyle(fontSize: 14),
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
              onPressed: () {
                Navigator.of(dialogContext).pop();
                
                // TODO: Aquí iría la lógica real del cierre X
                
                // Mostrar mensaje de éxito
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Cierre X realizado con éxito'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 3),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }

  void _showCierreZDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Verificar si ya se hizo cierre de lote hoy
    final tieneCierreLoteHoy = await DbHelper.instance.yaSeHizoCierreHoy();

    if (!mounted) return;

    if (!tieneCierreLoteHoy) {
      showDialog(
        context: context,
        builder: (BuildContext ctx) {
          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.block, color: AppColors.error, size: 20),
                 SizedBox(width: 8),
                 Expanded(
                  child: Text(
                    'Cierre de Lote Requerido',
                    style: TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: const Text(
              'No se puede realizar el Cierre Z porque no existe un cierre de lote para el día de hoy.\n\nDebe realizar el Cierre de Lote primero.',
              style: TextStyle(fontSize: 14),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Entendido'),
              ),
            ],
          );
        },
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title:const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.error,
                size: 20,
              ),
               SizedBox(width: 8),
               Expanded(
                child: Text(
                  'Confirmar Cierre Z',
                  style: TextStyle(fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: const Text(
            '¿Estás seguro de realizar el Cierre Z?\n\nEsta acción es IRREVERSIBLE y cerrará definitivamente el día.',
            style: TextStyle(fontSize: 14),
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

                // [TEST] Cierre Z simulado: cerrar facturas del día
                // TODO: REVERTIR - reemplazar con lógica real de cierre Z
                final count = await DbHelper.instance.cerrarFacturasDelDia();

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ Cierre Z realizado — $count factura(s) cerrada(s)'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Confirmar'),
            ),
          ],
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

  /// Construir tarjeta de factura
  Widget _buildInvoiceCard(Map<String, dynamic> invoice, bool isDark) {
    final fecha = DateTime.parse(invoice['fecha_creacion']);
    final metodoPago = invoice['metodo_pago'] ?? 'cash';
    final total = invoice['total'] as double;
    final clienteIdentificacion = invoice['cliente_identificacion'] ?? 'N/A';
    
    // Obtener referencia de Ubii si existe
    final ubiiReference = invoice['ubii_reference'] as String?;
    final referenciaPago = invoice['referencia_pago'] as String?;
    
    // Determinar qué mostrar como título
    String titulo;
    if (ubiiReference != null && ubiiReference.isNotEmpty) {
      // Si hay referencia de Ubii, mostrarla
      titulo = 'Ref: $ubiiReference';
    } else if (referenciaPago != null && referenciaPago.isNotEmpty) {
      // Si hay referencia de pago manual, mostrarla
      titulo = 'Ref: $referenciaPago';
    } else {
      // Fallback: mostrar número de factura
      titulo = 'Factura #${invoice['id']}';
    }
    
    // Icono según método de pago
    IconData paymentIcon;
    Color paymentColor;
    String paymentLabel;
    
    switch (metodoPago) {
      case 'card':
        paymentIcon = Icons.credit_card;
        paymentColor = AppColors.info;
        paymentLabel = 'Tarjeta';
        break;
      case 'pago_movil':
        paymentIcon = Icons.phone_android;
        paymentColor = AppColors.primary;
        paymentLabel = 'Pago Móvil';
        break;
      case 'debit_immediate':
        paymentIcon = Icons.account_balance;
        paymentColor = AppColors.primaryDark;
        paymentLabel = 'Débito Inm.';
        break;
      default:
        paymentIcon = Icons.money;
        paymentColor = AppColors.success;
        paymentLabel = 'Efectivo';
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showInvoiceDetail(invoice),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Referencia con diseño especial (más pequeña)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified, size: 12, color: AppColors.info),
                              const SizedBox(width: 4),
                              Text(
                                titulo,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.info,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.badge_outlined,
                              size: 14,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              clienteIdentificacion,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: paymentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(paymentIcon, size: 16, color: paymentColor),
                        const SizedBox(width: 4),
                        Text(
                          paymentLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: paymentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        CurrencyFormatter.formatBS(total, invoice['tasa_usd'] ?? 36.50),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.formatUSD(total),
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${fecha.day}/${fecha.month}/${fecha.year}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      Text(
                        '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Mostrar detalle de factura
  void _showInvoiceDetail(Map<String, dynamic> invoice) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Cargar detalles de la factura
    final detalles = await DbHelper.instance.obtenerDetallesFactura(invoice['id']);
    
    if (!mounted) return;
    
    final screenHeight = MediaQuery.of(context).size.height;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext modalContext) => Container(
        height: screenHeight * 0.85,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Factura #${invoice['id']}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        invoice['cliente_identificacion'] ?? 'N/A',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      Text(
                        invoice['cliente_nombre'] ?? 'Cliente',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(modalContext),
                  ),
                ],
              ),
            ),
            // Contenido
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Información general
                    _buildDetailSection(
                      'Información General',
                      [
                        _buildDetailRow('Fecha', _formatDateTime(invoice['fecha_creacion']), isDark),
                        _buildDetailRow('Cliente', invoice['cliente_nombre'] ?? 'N/A', isDark),
                        _buildDetailRow('Método de Pago', _getPaymentMethodLabel(invoice['metodo_pago']), isDark),
                        if (invoice['referencia_pago'] != null && invoice['referencia_pago'].toString().isNotEmpty)
                          _buildDetailRow('Referencia Manual', invoice['referencia_pago'], isDark),
                        if (invoice['ubii_reference'] != null && invoice['ubii_reference'].toString().isNotEmpty)
                          _buildDetailRow('Referencia Ubii', invoice['ubii_reference'], isDark, highlight: true),
                      ],
                      isDark,
                    ),
                    const SizedBox(height: 20),
                    
                    // Montos
                    _buildDetailSection(
                      'Montos',
                      [
                        _buildDetailRow('Total USD', CurrencyFormatter.formatUSD(invoice['total']), isDark),
                        _buildDetailRow('Total Bs', CurrencyFormatter.formatBS(invoice['total'], invoice['tasa_usd'] ?? 36.50), isDark),
                        _buildDetailRow('Tasa USD', '${(invoice['tasa_usd'] ?? 36.50).toStringAsFixed(2)} Bs', isDark),
                      ],
                      isDark,
                    ),
                    
                    // Datos de Ubii POS (si aplica)
                    if (invoice['ubii_reference'] != null && invoice['ubii_reference'].toString().isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildDetailSection(
                        'Datos de Ubii POS',
                        [
                          _buildDetailRow('Referencia', invoice['ubii_reference'] ?? 'N/A', isDark),
                          _buildDetailRow('Código Auth', invoice['ubii_auth_code'] ?? 'N/A', isDark),
                          _buildDetailRow('Tipo Tarjeta', invoice['ubii_card_type'] ?? 'N/A', isDark),
                          _buildDetailRow('Terminal', invoice['ubii_terminal'] ?? 'N/A', isDark),
                          _buildDetailRow('Lote', invoice['ubii_lote'] ?? 'N/A', isDark),
                          _buildDetailRow('Código Respuesta', invoice['ubii_response_code'] ?? 'N/A', isDark),
                        ],
                        isDark,
                      ),
                    ],
                    
                    const SizedBox(height: 20),
                    
                    // Productos
                    Text(
                      'Productos',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...detalles.map((detalle) => _buildProductItem(detalle, isDark)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
              color: highlight 
                  ? AppColors.primary 
                  : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: highlight 
                    ? AppColors.primary 
                    : (isDark ? AppColors.darkText : AppColors.lightText),
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductItem(Map<String, dynamic> detalle, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detalle['producto_nombre'] ?? 'Producto',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cantidad: ${detalle['cantidad'].toInt()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            CurrencyFormatter.formatUSD(detalle['subtotal']),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String dateTimeStr) {
    final dt = DateTime.parse(dateTimeStr);
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _getPaymentMethodLabel(String? method) {
    switch (method) {
      case 'card':
        return 'Tarjeta';
      case 'pago_movil':
        return 'Pago Móvil';
      case 'debit_immediate':
        return 'Débito Inmediato';
      default:
        return 'Efectivo';
    }
  }
}
