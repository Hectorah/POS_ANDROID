import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/user_provider.dart';
import '../../providers/fiscal_provider.dart';
import '../../database/db_helper.dart';
import '../../models/fiscal_models.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_snackbar.dart';
import '../../core/constants/app_colors.dart';

class AperturaFiscalScreen extends StatefulWidget {
  const AperturaFiscalScreen({super.key});

  @override
  State<AperturaFiscalScreen> createState() => _AperturaFiscalScreenState();
}

class _AperturaFiscalScreenState extends State<AperturaFiscalScreen> {
  SesionFiscal? _ultimaSesionCerrada;
  bool _loadingUltima = true;
  bool _isOpening = false;
  final TextEditingController _fondoController = TextEditingController(text: '0.00');

  @override
  void initState() {
    super.initState();
    _cargarUltimaSesion();
  }

  @override
  void dispose() {
    _fondoController.dispose();
    super.dispose();
  }

  Future<void> _cargarUltimaSesion() async {
    try {
      final db = await DbHelper.instance.database;
      final results = await db.query(
        'sesiones_fiscales',
        where: "estado = 'CERRADA'",
        orderBy: 'fecha_cierre DESC',
        limit: 1,
      );
      if (results.isNotEmpty) {
        setState(() {
          _ultimaSesionCerrada = SesionFiscal.fromLocalMap(results.first);
        });
      }
    } catch (e) {
      debugPrint('Error cargando última sesión cerrada: $e');
    } finally {
      setState(() => _loadingUltima = false);
    }
  }

  Future<void> _realizarApertura(BuildContext context) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final fiscalProvider = Provider.of<FiscalProvider>(context, listen: false);
    
    if (userProvider.currentUser == null) {
      CustomSnackBar.error(context, 'Usuario no autenticado.');
      return;
    }

    final String userName = userProvider.currentUser!.userName;
    final int userId = int.tryParse(userProvider.currentUser!.userId) ?? 1;
    final double fondoInicial = double.tryParse(_fondoController.text) ?? 0.0;

    // Diálogo de confirmación
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Apertura Fiscal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('¿Desea iniciar la jornada fiscal? Esto le permitirá realizar ventas en el sistema.'),
            const SizedBox(height: 16),
            Text('Fondo Inicial: \$ ${fondoInicial.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Iniciar Jornada'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isOpening = true);

    try {
      await fiscalProvider.abrirSesion(userId, userName, fondoCajaInicial: fondoInicial);
      if (!context.mounted) return;
      CustomSnackBar.success(context, 'Jornada fiscal iniciada exitosamente.');
      Navigator.pop(context); // Volver
    } catch (e) {
      if (!context.mounted) return;
      CustomSnackBar.error(context, 'Error al abrir sesión: $e');
    } finally {
      if (mounted) {
        setState(() => _isOpening = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.currentUser;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Apertura Fiscal del Día'),
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card de Información General
              Card(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.today, color: Theme.of(context).colorScheme.primary, size: 24),
                          const SizedBox(width: 12),
                          const Text(
                            'Jornada Fiscal',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildInfoRow('Fecha Actual:', DateFormat('dd/MM/yyyy').format(DateTime.now()), isDark),
                      const SizedBox(height: 12),
                      _buildInfoRow('Usuario Responsable:', user?.userName ?? 'N/A', isDark),
                      const SizedBox(height: 12),
                      _buildInfoRow('Nivel de Acceso:', userProvider.getRoleName(), isDark),
                      const Divider(height: 24),
                      const Text(
                        'Fondo Fijo Inicial (USD)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _fondoController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.attach_money),
                          hintText: '0.00',
                          filled: true,
                          fillColor: isDark ? Colors.black26 : Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Card de Historial / Cierre de ayer
              if (_loadingUltima)
                const Center(child: CircularProgressIndicator())
              else if (_ultimaSesionCerrada != null) ...[
                const Text(
                  'Último Cierre Fiscal',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Card(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(
                          'Cerrado el:',
                          DateFormat('dd/MM/yyyy HH:mm:ss').format(_ultimaSesionCerrada!.fechaCierre!),
                          isDark,
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          'Total Facturado:',
                          'Bs. ${(_ultimaSesionCerrada!.totalVentas * (_ultimaSesionCerrada!.totalGeneral > 0 ? _ultimaSesionCerrada!.totalGeneral / _ultimaSesionCerrada!.totalVentas : 36.50)).toStringAsFixed(2)}', // Simulación básica o total general
                          isDark,
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow('Transacciones:', _ultimaSesionCerrada!.cantidadTransacciones.toString(), isDark),
                        const SizedBox(height: 12),
                        _buildInfoRow('Factura Final:', _ultimaSesionCerrada!.facturaFinal ?? 'N/A', isDark),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ] else ...[
                Card(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No se encontró registro de sesiones fiscales anteriores. Esta será la primera apertura.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],

              // Botón de Apertura
              CustomButton(
                onPressed: _isOpening ? null : () => _realizarApertura(context),
                text: 'INICIAR JORNADA FISCAL',
                icon: Icons.play_arrow_rounded,
                isLoading: _isOpening,
                variant: ButtonVariant.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
