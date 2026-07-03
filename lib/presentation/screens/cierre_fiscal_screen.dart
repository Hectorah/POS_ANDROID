import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/user_provider.dart';
import '../../providers/fiscal_provider.dart';
import '../../services/fiscal_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_snackbar.dart';
import '../../core/constants/app_colors.dart';
import 'reporte_cierre_screen.dart';
import 'arqueo_caja_screen.dart';

class CierreFiscalScreen extends StatefulWidget {
  const CierreFiscalScreen({super.key});

  @override
  State<CierreFiscalScreen> createState() => _CierreFiscalScreenState();
}

class _CierreFiscalScreenState extends State<CierreFiscalScreen> {
  Map<String, dynamic>? _resumenFacturas;
  Map<String, dynamic>? _resumenNC;
  bool _loadingTotals = true;
  bool _isClosing = false;
  double _tasaCambio = 36.50;

  @override
  void initState() {
    super.initState();
    _cargarTasasYTotales();
  }

  Future<void> _cargarTasasYTotales() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _tasaCambio = prefs.getDouble('tasa_usd') ?? 36.50;

      if (!mounted) return;
      final fiscalProvider =
          Provider.of<FiscalProvider>(context, listen: false);
      final sesion = fiscalProvider.sesionActual;

      if (sesion != null) {
        final totals =
            await FiscalService.instance.calcularTotalesSesion(sesion.id!);
        setState(() {
          _resumenFacturas = totals['facturas'] as Map<String, dynamic>?;
          _resumenNC = totals['notas_credito'] as Map<String, dynamic>?;
        });
      }
    } catch (e) {
      debugPrint('Error cargando totales de cierre: $e');
    } finally {
      if (mounted) setState(() => _loadingTotals = false);
    }
  }

  Future<void> _realizarCierre(BuildContext context) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final fiscalProvider = Provider.of<FiscalProvider>(context, listen: false);

    if (userProvider.currentUser == null) {
      CustomSnackBar.error(context, 'Usuario no autenticado.');
      return;
    }

    final String userName = userProvider.currentUser!.userName;
    final int userId = int.tryParse(userProvider.currentUser!.userId) ?? 1;

    // VALIDACIÓN: El arqueo debe haberse realizado antes del cierre fiscal
    if (fiscalProvider.sesionActual != null &&
        !fiscalProvider.sesionActual!.arqueoRealizado) {
      CustomSnackBar.warning(context,
          'Debe realizar el Arqueo de Caja antes de cerrar la jornada fiscal.');
      return;
    }

    // Diálogo de advertencia e irreversibilidad
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('¿Cierre Fiscal'),
          ],
        ),
        content: const Text(
          'Esta acción es IRREVERSIBLE.\n\n'
          'Se consolidará la facturación del día, se generará el Reporte Z y se bloqueará el sistema para nuevas transacciones hasta una nueva apertura.\n\n'
          '¿Está seguro de continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sí, Cerrar Jornada'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isClosing = true);

    try {
      final reporte = await fiscalProvider.cerrarSesion(userId, userName);
      if (!context.mounted) return;
      CustomSnackBar.success(
          context, 'Cierre fiscal realizado con éxito y enviado a impresora.');

      // Redirigir directamente a la pantalla de visualización del reporte Z
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ReporteCierreScreen(reporte: reporte),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      CustomSnackBar.error(context, 'Error al cerrar jornada fiscal: $e');
    } finally {
      if (mounted) {
        setState(() => _isClosing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fiscalProvider = Provider.of<FiscalProvider>(context);
    final sesion = fiscalProvider.sesionActual;

    if (sesion == null && !_isClosing) {
      return Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(
          title: const Text('Cierre Fiscal del Día'),
          backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(
              'No hay ninguna sesión fiscal abierta activa para cerrar.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    // Calcular montos finales basados en las consultas
    final double efectivo = (_resumenFacturas != null)
        ? (_resumenFacturas!['efectivo'] as num? ?? 0.0).toDouble() *
            _tasaCambio
        : 0.0;
    final double tarjeta = (_resumenFacturas != null)
        ? (_resumenFacturas!['tarjeta'] as num? ?? 0.0).toDouble() * _tasaCambio
        : 0.0;
    final double pagoMovil = (_resumenFacturas != null)
        ? (_resumenFacturas!['pago_movil'] as num? ?? 0.0).toDouble() *
            _tasaCambio
        : 0.0;
    final double otros = (_resumenFacturas != null)
        ? (_resumenFacturas!['otros'] as num? ?? 0.0).toDouble() * _tasaCambio
        : 0.0;
    final double baseImp = (_resumenFacturas != null)
        ? (_resumenFacturas!['base_imponible'] as num? ?? 0.0).toDouble() *
            _tasaCambio
        : 0.0;
    final double iva = (_resumenFacturas != null)
        ? (_resumenFacturas!['iva'] as num? ?? 0.0).toDouble() * _tasaCambio
        : 0.0;
    final double exento = (_resumenFacturas != null)
        ? (_resumenFacturas!['exento'] as num? ?? 0.0).toDouble() * _tasaCambio
        : 0.0;

    // Gastos y Fondo
    final double fondoInicial = (sesion?.fondoCajaInicial ?? 0.0) * _tasaCambio;

    // Deducción por Notas de Crédito
    final double totalNc =
        (_resumenNC?['total_nc'] as num? ?? 0.0).toDouble() * _tasaCambio;

    final double totalGeneral =
        (efectivo + tarjeta + pagoMovil + otros) - totalNc;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Cierre Fiscal del Día'),
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
      ),
      body: _loadingTotals
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Botones de Acción Pre-Cierre
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const ArqueoCajaScreen()),
                              );
                              if (result == true) _cargarTasasYTotales();
                            },
                            icon: Icon(Icons.account_balance_wallet,
                                color: sesion?.arqueoRealizado == true
                                    ? Colors.green
                                    : null),
                            label: Text(sesion?.arqueoRealizado == true
                                ? 'ARQUEO LISTO'
                                : 'HACER ARQUEO'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: sesion?.arqueoRealizado == true
                                  ? const BorderSide(color: Colors.green)
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Card de Resumen de Sesión Activa
                    Card(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.receipt_long,
                                    color: AppColors.primary, size: 24),
                                const SizedBox(width: 12),
                                Text(
                                  sesion?.numeroSesion ?? 'Cerrando...',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            _buildInfoRow(
                                'Facturas Emitidas:',
                                '${_resumenFacturas?['cantidad_facturas'] ?? 0}',
                                isDark),
                            const SizedBox(height: 12),
                            _buildInfoRow('Notas de Crédito:',
                                '${_resumenNC?['cantidad_nc'] ?? 0}', isDark),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                                'Fondo Inicial:',
                                'Bs. ${fondoInicial.toStringAsFixed(2)}',
                                isDark),
                            const Divider(height: 24),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Rango de Facturas:',
                                  style: TextStyle(
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${_resumenFacturas?['factura_inicial'] ?? 'N/A'} - ${_resumenFacturas?['factura_final'] ?? 'N/A'}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Card de Métodos de Pago
                    const Text(
                      'Resumen por Métodos de Pago',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            _buildInfoRow(
                                'Efectivo Esperado:',
                                'Bs. ${(fondoInicial + efectivo).toStringAsFixed(2)}',
                                isDark),
                            const SizedBox(height: 12),
                            _buildInfoRow('Tarjeta de Déb/Cré:',
                                'Bs. ${tarjeta.toStringAsFixed(2)}', isDark),
                            const SizedBox(height: 12),
                            _buildInfoRow('Pago Móvil:',
                                'Bs. ${pagoMovil.toStringAsFixed(2)}', isDark),
                            const SizedBox(height: 12),
                            _buildInfoRow('Otros Métodos:',
                                'Bs. ${otros.toStringAsFixed(2)}', isDark),
                            if (totalNc > 0) ...[
                              const Divider(height: 24),
                              _buildInfoRow('Total Notas de Crédito:',
                                  '-Bs. ${totalNc.toStringAsFixed(2)}', isDark,
                                  isNegative: true),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Card de Discriminación de IVA
                    const Text(
                      'Discriminación de Impuestos',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            _buildInfoRow('Base Imponible (Bs.):',
                                'Bs. ${baseImp.toStringAsFixed(2)}', isDark),
                            const SizedBox(height: 12),
                            _buildInfoRow('IVA 16% (Bs.):',
                                'Bs. ${iva.toStringAsFixed(2)}', isDark),
                            const SizedBox(height: 12),
                            _buildInfoRow('Ventas Exentas (Bs.):',
                                'Bs. ${exento.toStringAsFixed(2)}', isDark),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Total General Consolidado
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            width: 1.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'TOTAL GENERAL NETO:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.primary),
                            ),
                          ),
                          Text(
                            'Bs. ${totalGeneral.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: AppColors.primary),
                            textAlign: TextAlign.right,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Botón de Cierre
                    CustomButton(
                      onPressed:
                          _isClosing ? null : () => _realizarCierre(context),
                      text: 'CERRAR JORNADA FISCAL',
                      icon: Icons.lock_outline,
                      isLoading: _isClosing,
                      variant: ButtonVariant.danger,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark,
      {bool isNegative = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isNegative ? Colors.red : null,
          ),
        ),
      ],
    );
  }
}
