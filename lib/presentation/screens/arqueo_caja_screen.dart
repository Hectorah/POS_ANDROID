import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/fiscal_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/fiscal_models.dart';
import '../../services/fiscal_service.dart';
import '../../services/exchange_rate_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_snackbar.dart';

class ArqueoCajaScreen extends StatefulWidget {
  const ArqueoCajaScreen({super.key});

  @override
  State<ArqueoCajaScreen> createState() => _ArqueoCajaScreenState();
}

class _ArqueoCajaScreenState extends State<ArqueoCajaScreen> {
  final TextEditingController _efectivoBsController =
      TextEditingController(text: '0.00');
  final TextEditingController _efectivoUsdController =
      TextEditingController(text: '0.00');
  final TextEditingController _efectivoEurController =
      TextEditingController(text: '0.00');
  final TextEditingController _efectivoCopController =
      TextEditingController(text: '0.00');

  final TextEditingController _tarjetaController =
      TextEditingController(text: '0.00');
  final TextEditingController _pagoMovilController =
      TextEditingController(text: '0.00');
  final TextEditingController _otrosController =
      TextEditingController(text: '0.00');
  final TextEditingController _observacionesController =
      TextEditingController();

  bool _isSaving = false;
  bool _isLoading = true;
  double _totalUsd = 0.0;

  // Tasas de cambio del sistema
  double _tasaUsd = 36.50;
  double _tasaEur = 40.00;
  double _tasaCop = 0.012;

  // Totales Esperados del Sistema
  Map<String, dynamic> _totalesEsperados = {};

  @override
  void initState() {
    super.initState();
    _efectivoBsController.addListener(_updateTotalUsd);
    _efectivoUsdController.addListener(_updateTotalUsd);
    _efectivoEurController.addListener(_updateTotalUsd);
    _efectivoCopController.addListener(_updateTotalUsd);
    _cargarTotalesSistema();
  }

  Future<void> _cargarTotalesSistema() async {
    final fiscalProvider = Provider.of<FiscalProvider>(context, listen: false);
    final sesion = fiscalProvider.sesionActual;

    // Obtener tasas activas del sistema
    final rates = await ExchangeRateService.getCurrentRates();
    _tasaUsd = rates['USD'] ?? 36.50;
    _tasaEur = rates['EUR'] ?? 40.00;
    _tasaCop = rates['COP'] ?? 0.012;

    if (sesion != null) {
      final totales =
          await FiscalService.instance.calcularTotalesSesion(sesion.id!);
      setState(() {
        _totalesEsperados = totales['facturas'] as Map<String, dynamic>;

        // Auto-rellenar pagos electrónicos con los valores del sistema
        // (no requieren conteo manual, ya están registrados electrónicamente)
        final tarjetaSistema = (_totalesEsperados['tarjeta'] as num? ?? 0.0).toDouble();
        final pagoMovilSistema = (_totalesEsperados['pago_movil'] as num? ?? 0.0).toDouble();
        final otrosSistema = (_totalesEsperados['otros'] as num? ?? 0.0).toDouble();

        _tarjetaController.text = tarjetaSistema.toStringAsFixed(2);
        _pagoMovilController.text = pagoMovilSistema.toStringAsFixed(2);
        _otrosController.text = otrosSistema.toStringAsFixed(2);

        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _efectivoBsController.dispose();
    _efectivoUsdController.dispose();
    _efectivoEurController.dispose();
    _efectivoCopController.dispose();
    _tarjetaController.dispose();
    _pagoMovilController.dispose();
    _otrosController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  void _updateTotalUsd() {
    double total = 0.0;
    final bs = double.tryParse(_efectivoBsController.text) ?? 0.0;
    final usd = double.tryParse(_efectivoUsdController.text) ?? 0.0;
    final eur = double.tryParse(_efectivoEurController.text) ?? 0.0;
    final cop = double.tryParse(_efectivoCopController.text) ?? 0.0;

    total += usd;
    if (_tasaUsd > 0) {
      total += bs / _tasaUsd;
      total += eur * (_tasaEur / _tasaUsd);
      total += cop * (_tasaCop / _tasaUsd);
    }

    setState(() {
      _totalUsd = total;
    });
  }

  Future<void> _guardarArqueo() async {
    final fiscalProvider = Provider.of<FiscalProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    if (userProvider.currentUser == null) return;

    setState(() => _isSaving = true);

    try {
      final conteo = ConteoEfectivo(
        efectivoBs: double.tryParse(_efectivoBsController.text) ?? 0.0,
        efectivoUsd: double.tryParse(_efectivoUsdController.text) ?? 0.0,
        efectivoEur: double.tryParse(_efectivoEurController.text) ?? 0.0,
        efectivoCop: double.tryParse(_efectivoCopController.text) ?? 0.0,
      );

      final arqueo = await fiscalProvider.realizarArqueo(
        usuarioId: int.tryParse(userProvider.currentUser!.userId) ?? 1,
        usuarioNombre: userProvider.currentUser!.userName,
        conteo: conteo,
        totalTarjetaDeclarado: double.tryParse(_tarjetaController.text) ?? 0.0,
        totalPagoMovilDeclarado:
            double.tryParse(_pagoMovilController.text) ?? 0.0,
        totalOtrosDeclarado: double.tryParse(_otrosController.text) ?? 0.0,
        observaciones: _observacionesController.text,
      );

      if (!mounted) return;

      String mensaje = arqueo.cuadrado
          ? 'Arqueo realizado correctamente. La caja está CUADRADA.'
          : 'Arqueo realizado. Se detectó una diferencia de Bs. ${(arqueo.diferenciaTotal * _tasaUsd).toStringAsFixed(2)}';

      CustomSnackBar.show(context,
          message: mensaje,
          type: arqueo.cuadrado ? SnackBarType.success : SnackBarType.warning);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.show(context,
          message: 'Error al realizar arqueo: $e', type: SnackBarType.error);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final efectivoEsperado =
        (_totalesEsperados['efectivo'] as num? ?? 0.0).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Arqueo de Caja (Cierre X)'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionTitle('Conteo de Efectivo por Divisa'),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildCashAmountRow('Efectivo Bs', _efectivoBsController, symbol: 'Bs.'),
                    _buildCashAmountRow('Efectivo USD', _efectivoUsdController, symbol: '\$'),
                    _buildCashAmountRow('Efectivo EUR', _efectivoEurController, symbol: '€'),
                    _buildCashAmountRow('Efectivo COP', _efectivoCopController, symbol: 'COP'),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Divider(thickness: 1.2),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Flexible(
                                child: Text('TTL EFECTIVO (ESPERADO):',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                              ),
                              const SizedBox(width: 8),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                    '\$ ${efectivoEsperado.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Flexible(
                                child: Text('TTL EFECTIVO (CONTADO):',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                              ),
                              const SizedBox(width: 8),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                    '\$ ${_totalUsd.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Colors.green)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('Otros Medios de Pago (Registrados por Sistema)'),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildReadOnlyAmountRow('Total Tarjetas', _tarjetaController),
                    _buildReadOnlyAmountRow('Total Pago Móvil', _pagoMovilController),
                    _buildReadOnlyAmountRow('Otros (Transferencias, etc)', _otrosController),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('Observaciones'),
            TextField(
              controller: _observacionesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Ingrese Comentarios...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),
            CustomButton(
              onPressed: _isSaving ? null : _guardarArqueo,
              text: 'FINALIZAR ARQUEO E IMPRIMIR',
              icon: Icons.print,
              isLoading: _isSaving,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildCashAmountRow(String label, TextEditingController controller, {required String symbol}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
          Expanded(
            flex: 2,
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                prefixText: '$symbol ',
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Campo de solo lectura para pagos electrónicos (valores del sistema)
  Widget _buildReadOnlyAmountRow(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
          Expanded(
            flex: 2,
            child: TextField(
              controller: controller,
              readOnly: true,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.grey),
              decoration: InputDecoration(
                prefixText: '\$ ',
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

