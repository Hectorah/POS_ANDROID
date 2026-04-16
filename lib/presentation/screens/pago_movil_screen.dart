import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/ubii_pago_movil_service.dart';
import '../../models/pago_movil_transaction.dart';
import '../../core/app_config.dart';
import '../widgets/custom_snackbar.dart';

/// Pantalla para VERIFICAR pagos mediante Pago Móvil con Ubii
/// 
/// Flujo:
/// 1. Cliente realiza Pago Móvil desde su app bancaria
/// 2. Cliente proporciona la referencia del pago
/// 3. Cajero ingresa los datos y la referencia
/// 4. Sistema verifica con Ubii si el pago es válido
class PagoMovilScreen extends StatefulWidget {
  final double? montoInicial;
  
  const PagoMovilScreen({
    super.key,
    this.montoInicial,
  });

  @override
  State<PagoMovilScreen> createState() => _PagoMovilScreenState();
}

class _PagoMovilScreenState extends State<PagoMovilScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = UbiiPagoMovilService();
  
  // Controladores de texto
  final _montoController = TextEditingController();
  final _phoneClienteController = TextEditingController();
  final _referenciaController = TextEditingController();
  
  // Estado
  bool _loading = false;
  bool _serviceInitialized = false;
  String? _selectedBankCode;
  PagoMovilTransaction? _verifiedTransaction;
  
  final _currencyFormat = NumberFormat.currency(
    locale: 'es_VE',
    symbol: 'Bs. ',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    if (widget.montoInicial != null) {
      _montoController.text = widget.montoInicial!.toStringAsFixed(2);
    }
    _initService();
  }

  @override
  void dispose() {
    _montoController.dispose();
    _phoneClienteController.dispose();
    _referenciaController.dispose();
    super.dispose();
  }

  /// Inicializa el servicio de Ubii Pago Móvil
  Future<void> _initService() async {
    setState(() => _loading = true);
    
    try {
      final success = await _service.initialize();
      
      if (success) {
        setState(() => _serviceInitialized = true);
        if (mounted) {
          CustomSnackBar.success(context, 'Servicio inicializado correctamente');
        }
      } else {
        if (mounted) {
          await ErrorDialog.ubiiAuthError(
            context,
            details: 'No se pudo inicializar el servicio de Pago Móvil.\nVerifica las credenciales de Ubii en la configuración.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        await ErrorDialog.networkError(
          context,
          details: 'Error al inicializar servicio de Pago Móvil:\n$e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// Verifica el pago móvil con Ubii
  Future<void> _verificarPago() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (!_serviceInitialized) {
      CustomSnackBar.warning(context, 'El servicio no está inicializado');
      return;
    }
    
    setState(() => _loading = true);
    
    try {
      // Generar número de orden único
      final orderNumber = _service.generateOrderNumber();
      final monto = double.parse(_montoController.text);
      final fecha = _service.getCurrentDate(); // Fecha actual automática
      
      // Verificar el pago con Ubii
      final result = await _service.verificarPagoMovil(
        bankAba: _selectedBankCode!,
        phoneCliente: _phoneClienteController.text,
        monto: monto,
        fecha: fecha,
        referencia: _referenciaController.text,
        orderNumber: orderNumber,
      );
      
      if (result != null) {
        if (result['R'] == '0' && result['codR'] == '00') {
          // ✅ Pago verificado correctamente
          _verifiedTransaction = PagoMovilTransaction(
            orderNumber: orderNumber,
            bankAba: _selectedBankCode!,
            phoneCliente: _phoneClienteController.text,
            phoneComercio: AppConfig.pagoMovilTelefono,
            monto: monto,
            cedulaCliente: '', // No se requiere para verificación
            referencia: result['ref'] ?? _referenciaController.text,
            status: PagoMovilStatus.approved,
            responseCode: result['codR'],
            responseMessage: result['codS'],
          );
          
          setState(() {});
          
          if (mounted) {
            CustomSnackBar.success(
              context,
              'Pago verificado! Ref: ${_verifiedTransaction!.referencia}',
            );
          }
          
          _mostrarDialogoExito();
        } else {
          // ❌ Pago no verificado
          final errorMsg = result['codS'] ?? 'Pago no encontrado o inválido';
          
          setState(() {
            _verifiedTransaction = PagoMovilTransaction(
              orderNumber: orderNumber,
              bankAba: _selectedBankCode!,
              phoneCliente: _phoneClienteController.text,
              phoneComercio: AppConfig.pagoMovilTelefono,
              monto: monto,
              cedulaCliente: '',
              referencia: _referenciaController.text,
              status: PagoMovilStatus.rejected,
              errorMessage: errorMsg,
              responseCode: result['codR'],
              responseMessage: result['codS'],
            );
          });
          
          if (mounted) {
            await ErrorDialog.pagoMovilError(
              context,
              details: 'Referencia: ${_referenciaController.text}\n'
                      'Banco: $_selectedBankCode\n'
                      'Monto: Bs. ${monto.toStringAsFixed(2)}\n'
                      'Código: ${result['codR']}\n'
                      'Mensaje: $errorMsg',
            );
          }
        }
      } else {
        if (mounted) {
          await ErrorDialog.networkError(
            context,
            details: 'No se recibió respuesta del servidor de Ubii.\n'
                    'Verifica tu conexión a internet.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        await ErrorDialog.genericError(
          context,
          message: 'Ocurrió un error al verificar el Pago Móvil',
          details: 'Error: $e\n'
                  'Referencia: ${_referenciaController.text}\n'
                  'Banco: $_selectedBankCode',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// Muestra un diálogo de éxito con los detalles del pago
  void _mostrarDialogoExito() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('Pago Verificado'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Monto:', _currencyFormat.format(_verifiedTransaction!.monto)),
            _buildDetailRow('Referencia:', _verifiedTransaction!.referencia),
            _buildDetailRow('Orden:', _verifiedTransaction!.orderNumber),
            _buildDetailRow('Banco:', BancoVenezolano.findByCodigo(_verifiedTransaction!.bankAba)?.nombre ?? _verifiedTransaction!.bankAba),
            _buildDetailRow('Teléfono:', _verifiedTransaction!.phoneCliente),
            _buildDetailRow('Fecha:', DateFormat('dd/MM/yyyy').format(_verifiedTransaction!.createdAt)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(_verifiedTransaction); // Retornar transacción
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificar Pago Móvil'),
      ),
      body: _loading && !_serviceInitialized
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Estado del servicio
                    Card(
                      color: _serviceInitialized ? Colors.green.shade50 : Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              _serviceInitialized ? Icons.check_circle : Icons.error,
                              color: _serviceInitialized ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _serviceInitialized 
                                  ? 'Servicio activo' 
                                  : 'Servicio no disponible',
                              style: TextStyle(
                                color: _serviceInitialized ? Colors.green.shade900 : Colors.red.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Instrucciones
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.blue.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'Instrucciones',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '1. El cliente realiza el Pago Móvil desde su app bancaria\n'
                              '2. El cliente proporciona el número de referencia\n'
                              '3. Ingresa los datos y la referencia aquí\n'
                              '4. El sistema verificará si el pago es válido',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Estado de la verificación
                    if (_verifiedTransaction != null) ...[
                      Card(
                        color: _getStatusColor(_verifiedTransaction!.status),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Text(
                                _verifiedTransaction!.status.emoji,
                                style: const TextStyle(fontSize: 24),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _verifiedTransaction!.status.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    
                    // Formulario
                    _buildDropdownBanco(),
                    const SizedBox(height: 16),
                    
                    _buildTextField(
                      controller: _montoController,
                      label: 'Monto (Bs.)',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      prefixIcon: Icons.attach_money,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingrese el monto';
                        }
                        final monto = double.tryParse(value);
                        if (monto == null) {
                          return 'Monto inválido';
                        }
                        if (monto <= 0) {
                          return 'El monto debe ser mayor a 0';
                        }
                        if (monto > 999999999) {
                          return 'Monto demasiado grande';
                        }
                        // Validar máximo 2 decimales
                        if (value.contains('.') && value.split('.')[1].length > 2) {
                          return 'Máximo 2 decimales';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    _buildTextField(
                      controller: _phoneClienteController,
                      label: 'Teléfono Cliente (00584XXXXXXXXX)',
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icons.phone_android,
                      maxLength: 14,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingrese el teléfono del cliente';
                        }
                        if (value.length != 14) {
                          return 'Debe tener 14 dígitos';
                        }
                        if (!value.startsWith('00584')) {
                          return 'Debe iniciar con 00584';
                        }
                        if (!_service.isValidVenezuelanPhone(value)) {
                          return 'Formato inválido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    _buildTextField(
                      controller: _referenciaController,
                      label: 'Número de Referencia',
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.confirmation_number,
                      maxLength: 20,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingrese la referencia del pago';
                        }
                        if (value.length < 4) {
                          return 'Referencia muy corta (mínimo 4 dígitos)';
                        }
                        // Validar que solo contenga números
                        if (!RegExp(r'^\d+$').hasMatch(value)) {
                          return 'Solo se permiten números';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Botón de verificación
                    ElevatedButton(
                      onPressed: (_loading || !_serviceInitialized)
                          ? null
                          : _verificarPago,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'VERIFICAR PAGO MÓVIL',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDropdownBanco() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedBankCode,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Banco del Cliente',
        prefixIcon: const Icon(Icons.account_balance),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      items: BancoVenezolano.bancos.map((banco) {
        return DropdownMenuItem(
          value: banco.codigo,
          child: Text(
            '${banco.codigo} - ${banco.nombre}',
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() => _selectedBankCode = value);
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Seleccione un banco';
        }
        return null;
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required TextInputType keyboardType,
    required IconData prefixIcon,
    String? Function(String?)? validator,
    int? maxLength,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(prefixIcon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        counterText: maxLength != null ? '' : null, // Ocultar contador
      ),
      validator: validator,
    );
  }

  Color _getStatusColor(PagoMovilStatus status) {
    switch (status) {
      case PagoMovilStatus.pending:
        return Colors.grey.shade100;
      case PagoMovilStatus.processing:
        return Colors.blue.shade50;
      case PagoMovilStatus.approved:
        return Colors.green.shade50;
      case PagoMovilStatus.rejected:
        return Colors.red.shade50;
      case PagoMovilStatus.timeout:
        return Colors.orange.shade50;
      case PagoMovilStatus.error:
        return Colors.red.shade100;
    }
  }
}
