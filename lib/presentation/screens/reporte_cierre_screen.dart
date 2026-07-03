import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../models/fiscal_models.dart';
import '../../services/thermal_printer_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_snackbar.dart';
import '../../core/constants/app_colors.dart';

class ReporteCierreScreen extends StatefulWidget {
  final ReporteCierre reporte;

  const ReporteCierreScreen({super.key, required this.reporte});

  @override
  State<ReporteCierreScreen> createState() => _ReporteCierreScreenState();
}

class _ReporteCierreScreenState extends State<ReporteCierreScreen> {
  double _tasaCambio = 36.50;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _cargarTasa();
  }

  Future<void> _cargarTasa() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _tasaCambio = prefs.getDouble('tasa_usd') ?? 36.50;
      });
    } catch (_) {}
  }

  Future<void> _reimprimirReporte() async {
    setState(() => _isPrinting = true);
    try {
      final success = await ThermalPrinterService.printReporteCierre(
          widget.reporte,
          tasaCambio: _tasaCambio);
      if (mounted) {
        if (success) {
          CustomSnackBar.success(context, 'Reporte Z enviado a la impresora.');
        } else {
          CustomSnackBar.error(context,
              'No se pudo imprimir el reporte. Verifique la impresora.');
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.error(context, 'Error de impresión: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = widget.reporte;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Reporte Fiscal Z'),
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado Fiscal
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.receipt_long,
                        size: 48, color: AppColors.primary),
                    const SizedBox(height: 8),
                    const Text(
                      'REPORTE DE CIERRE FISCAL',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Text(
                      'REPORTE Z',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppColors.primary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      r.nombreComercio,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    Text(
                      'RIF: ${r.rifComercio}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Divider(height: 32),

              // Info Reporte
              _buildInfoRow('Nº de Reporte:', r.numeroReporte, isDark,
                  boldValue: true),
              const SizedBox(height: 8),
              _buildInfoRow(
                  'Fecha:',
                  DateFormat('dd/MM/yyyy HH:mm:ss').format(r.fechaReporte),
                  isDark),
              const Divider(height: 32),

              // Resumen Operaciones
              const Text(
                'Resumen de Operaciones',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.primary),
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                  'Facturas Emitidas:', '${r.facturasEmitidas}', isDark),
              const SizedBox(height: 8),
              _buildInfoRow(
                  'Notas de Crédito:', '${r.notasCreditoEmitidas}', isDark),
              const SizedBox(height: 8),
              _buildInfoRow('Total Transacciones:',
                  '${r.facturasEmitidas + r.notasCreditoEmitidas}', isDark),
              const Divider(height: 32),

              // Desglose Pagos
              const Text(
                'Totales por Método de Pago',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.primary),
              ),
              const SizedBox(height: 8),
              _buildAmountRow('Efectivo:', r.desgloseEfectivo, isDark),
              const SizedBox(height: 8),
              _buildAmountRow(
                  'Tarjeta de Deb/Cred:', r.desgloseTarjeta, isDark),
              const SizedBox(height: 8),
              _buildAmountRow('Pago Móvil:', r.desglosePagoMovil, isDark),
              const SizedBox(height: 8),
              _buildAmountRow('Otros Métodos:', r.desgloseOtros, isDark),
              if (r.totalNotasCredito > 0) ...[
                const SizedBox(height: 8),
                _buildAmountRow(
                    'Total N de Crédito:', -r.totalNotasCredito, isDark,
                    isNegative: true),
              ],
              const Divider(height: 32),

              // IVA
              const Text(
                'Discriminación de IVA',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.primary),
              ),
              const SizedBox(height: 8),
              _buildAmountRow(
                  'Base Imp (G 16%):', r.totalVentas - r.exento, isDark),
              const SizedBox(height: 8),
              _buildAmountRow('IVA (16%):', r.ivaTotal, isDark),
              const SizedBox(height: 8),
              _buildAmountRow('Ventas Exentas (E):', r.exento, isDark),
              const Divider(height: 32),

              // Total General
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOTAL NETO:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Bs. ${(r.totalNeto * _tasaCambio).toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.primary),
                        ),
                        Text(
                          '\$ ${r.totalNeto.toStringAsFixed(2)}',
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Firma / Hash
              const Text(
                'Firma Digital de Seguridad',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                ),
                child: SelectableText(
                  r.hashIntegridad ?? 'N/A',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Botones de acción
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      onPressed: _isPrinting ? null : _reimprimirReporte,
                      text: 'IMPRIMIR TICKET',
                      icon: Icons.print,
                      isLoading: _isPrinting,
                      variant: ButtonVariant.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark,
      {bool boldValue = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: boldValue ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildAmountRow(String label, double amountUSD, bool isDark,
      {bool isNegative = false}) {
    final double amountBS = amountUSD * _tasaCambio;
    final String sign = isNegative ? '-' : '';
    final String valueText =
        '${sign}Bs. ${amountBS.abs().toStringAsFixed(2)}  (\$ ${amountUSD.abs().toStringAsFixed(2)})';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
            fontSize: 13,
          ),
        ),
        Text(
          valueText,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: isNegative ? Colors.red : null,
          ),
        ),
      ],
    );
  }
}
