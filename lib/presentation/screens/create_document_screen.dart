import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../database/db_helper.dart';
import '../../services/ubii_pos_service.dart';
import '../../models/pago_movil_transaction.dart';
import '../widgets/custom_snackbar.dart';
import 'pago_movil_screen.dart';

// Modelos locales simplificados (sin backend)
class ClientModel {
  final int? id;
  final String identificacion;
  final String nombre;
  final String? correo;
  final String? direccion;
  final bool agenteRetencion;

  ClientModel({
    this.id,
    required this.identificacion,
    required this.nombre,
    this.correo,
    this.direccion,
    this.agenteRetencion = false,
  });

  // Crear desde el mapa de la BD
  factory ClientModel.fromMap(Map<String, dynamic> map) {
    return ClientModel(
      id: map['id'] as int?,
      identificacion: map['identificacion'] ?? '',
      nombre: map['nombre'] ?? '',
      correo: map['correo'],
      direccion: map['direccion'],
      agenteRetencion: false, // Por ahora siempre false, se puede agregar a la BD después
    );
  }

  // Convertir a mapa para guardar en BD
  Map<String, dynamic> toMap() {
    return {
      'identificacion': identificacion,
      'nombre': nombre,
      'correo': correo,
      'direccion': direccion,
    };
  }

  // Obtener RIF completo con tipo
  String get fullRif => identificacion;
}

class ProductModel {
  final String id;
  final String code;
  final String name;
  final double price;
  final double stock;
  int quantity;

  ProductModel({
    required this.id,
    required this.code,
    required this.name,
    required this.price,
    required this.stock,
    this.quantity = 1,
  });

  // Crear desde el mapa de la BD
  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'].toString(),
      code: map['cod_articulo'] ?? '',
      name: map['nombre'] ?? '',
      price: (map['precio'] as num?)?.toDouble() ?? 0.0,
      stock: (map['stock'] as num?)?.toDouble() ?? 0.0,
      quantity: 1,
    );
  }
}

// Formateador de moneda mejorado
class CurrencyFormatter {
  /// Formatear monto en Bolívares con separadores de miles
  static String formatBS(double amount, double rate) {
    final bs = amount * rate;
    return 'Bs. ${_formatNumber(bs, 2)}';
  }

  /// Formatear monto en USD con separadores de miles
  static String formatUSD(double amount) {
    return '\$ ${_formatNumber(amount, 2)}';
  }

  /// Formatear número con separadores de miles y decimales
  /// Ejemplo: 1234.56 -> 1,234.56
  static String _formatNumber(double number, int decimals) {
    // Separar parte entera y decimal
    final parts = number.toStringAsFixed(decimals).split('.');
    final integerPart = parts[0];
    final decimalPart = parts.length > 1 ? parts[1] : '';
    
    // Agregar separadores de miles
    final buffer = StringBuffer();
    var count = 0;
    
    for (var i = integerPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(integerPart[i]);
      count++;
    }
    
    // Invertir el string
    final formattedInteger = buffer.toString().split('').reversed.join('');
    
    // Retornar con decimales
    return '$formattedInteger.$decimalPart';
  }

  /// Formatear cantidad (sin símbolo de moneda)
  static String formatQuantity(double quantity) {
    if (quantity == quantity.toInt()) {
      return quantity.toInt().toString();
    }
    return quantity.toStringAsFixed(2);
  }
}

class CreateDocumentScreen extends StatefulWidget {
  const CreateDocumentScreen({super.key});

  @override
  State<CreateDocumentScreen> createState() => _CreateDocumentScreenState();
}


class _CreateDocumentScreenState extends State<CreateDocumentScreen> {
  String _step = 'creation';
  
  final _clientFormKey = GlobalKey<FormState>();
  final _paymentFormKey = GlobalKey<FormState>();
  
  final _rifSearchController = TextEditingController();
  final _productSearchController = TextEditingController();
  ClientModel? _selectedClient;
  
  final List<ProductModel> _cart = [];
  
  String? _selectedPaymentMethod;
  final _paymentReferenceController = TextEditingController();
  
  double _exchangeRate = 36.50;
  
  bool _isSearchingClient = false;
  bool _isLoadingProducts = false;
  
  String _selectedRifType = 'V';
  final List<String> _rifTypes = ['V', 'E', 'J'];
  
  List<ProductModel> _availableProducts = [];
  List<ProductModel> _filteredProducts = [];
  
  final UbiiPosService _ubiiService = UbiiPosService();
  bool _isProcessingPayment = false;
  
  @override
  void initState() {
    super.initState();
    _loadExchangeRate();
    _loadDefaultClient();
  }

  /// Cargar tasa de cambio desde SharedPreferences
  Future<void> _loadExchangeRate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tasaUsd = prefs.getDouble('tasa_usd');
      
      if (tasaUsd != null && tasaUsd > 0) {
        setState(() {
          _exchangeRate = tasaUsd;
        });
        debugPrint('💱 Tasa de cambio cargada: \$1 = Bs. $_exchangeRate');
      } else {
        debugPrint('⚠️ No hay tasa guardada, usando por defecto: $_exchangeRate');
      }
    } catch (e) {
      debugPrint('❌ Error cargando tasa de cambio: $e');
    }
  }

  /// Cargar cliente por defecto
  Future<void> _loadDefaultClient() async {
    try {
      final cliente = await DbHelper.instance.buscarClientePorId('V-00000000');
      
      if (cliente != null) {
        setState(() {
          _selectedClient = ClientModel.fromMap(cliente);
        });
        debugPrint('✅ Cliente por defecto cargado: ${_selectedClient!.nombre}');
      }
    } catch (e) {
      debugPrint('⚠️ No se pudo cargar cliente por defecto: $e');
    }
  }

  /// Buscar cliente por identificación
  Future<void> _searchClient() async {
    final identificacion = '$_selectedRifType-${_rifSearchController.text.trim()}';
    
    if (_rifSearchController.text.trim().isEmpty) {
      _showSnackBar('Ingrese un número de identificación', AppColors.warning);
      return;
    }

    setState(() => _isSearchingClient = true);

    try {
      // Buscar en la base de datos
      final cliente = await DbHelper.instance.buscarClientePorId(identificacion);
      
      if (cliente != null) {
        // Cliente encontrado
        setState(() {
          _selectedClient = ClientModel.fromMap(cliente);
          _isSearchingClient = false;
        });
        _showSnackBar('Cliente encontrado', AppColors.success);
        debugPrint('✅ Cliente encontrado: ${_selectedClient!.nombre}');
      } else {
        // Cliente no encontrado, mostrar diálogo para registrar
        setState(() => _isSearchingClient = false);
        _showRegisterClientDialog(identificacion);
      }
    } catch (e) {
      setState(() => _isSearchingClient = false);
      if (mounted) {
        await ErrorDialog.databaseError(
          context,
          details: 'Error al buscar cliente en la base de datos:\n$e\n\nIdentificación: $identificacion',
        );
      }
      debugPrint('❌ Error buscando cliente: $e');
    }
  }

  /// Mostrar diálogo para registrar nuevo cliente
  void _showRegisterClientDialog(String identificacion) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nombreController = TextEditingController();
    final correoController = TextEditingController();
    final direccionController = TextEditingController();

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
              const Icon(Icons.person_add, color: AppColors.primary),
              const SizedBox(width: 12),
              Text(
                'Registrar Cliente',
                style: TextStyle(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
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
                  'Cliente no encontrado con identificación:',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  identificacion,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nombreController,
                  decoration: InputDecoration(
                    labelText: 'Nombre completo *',
                    hintText: 'Ej: Juan Pérez',
                    filled: true,
                    fillColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.person),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: correoController,
                  decoration: InputDecoration(
                    labelText: 'Correo (opcional)',
                    hintText: 'Ej: cliente@email.com',
                    filled: true,
                    fillColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: direccionController,
                  decoration: InputDecoration(
                    labelText: 'Dirección (opcional)',
                    hintText: 'Ej: Calle 123, Ciudad',
                    filled: true,
                    fillColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.location_on),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                ),
              ],
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
            ElevatedButton.icon(
              onPressed: () async {
                final nombre = nombreController.text.trim().toUpperCase();
                final correo = correoController.text.trim().toUpperCase();
                final direccion = direccionController.text.trim().toUpperCase();
                
                if (nombre.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('El nombre es obligatorio'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }

                try {
                  // Registrar cliente en la BD
                  final clienteData = {
                    'identificacion': identificacion,
                    'nombre': nombre,
                    'correo': correo.isEmpty ? null : correo,
                    'direccion': direccion.isEmpty ? null : direccion,
                  };

                  final clienteId = await DbHelper.instance.insertarCliente(clienteData);
                  
                  if (clienteId > 0) {
                    // Cliente registrado exitosamente
                    setState(() {
                      _selectedClient = ClientModel(
                        id: clienteId,
                        identificacion: identificacion,
                        nombre: nombre,
                        correo: correo.isEmpty ? null : correo,
                        direccion: direccion.isEmpty ? null : direccion,
                      );
                    });

                    if (context.mounted) {
                      Navigator.of(dialogContext).pop();
                      _showSnackBar('Cliente registrado exitosamente', AppColors.success);
                    }
                    
                    debugPrint('✅ Cliente registrado: $nombre (ID: $clienteId)');
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text('Error al registrar: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                  debugPrint('❌ Error registrando cliente: $e');
                }
              },
              icon: const Icon(Icons.save),
              label: const Text('Registrar'),
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
  }
  Future<void> _loadProducts() async {
    // Si ya están cargados, no volver a cargar
    if (_availableProducts.isNotEmpty) {
      debugPrint('ℹ️ Productos ya cargados en caché');
      return;
    }
    
    setState(() => _isLoadingProducts = true);
    
    try {
      debugPrint('🔄 Cargando productos desde BD...');
      final productos = await DbHelper.instance.obtenerProductos();
      
      setState(() {
        _availableProducts = productos
            .map((map) => ProductModel.fromMap(map))
            .where((p) => p.stock > 0) // Solo productos con stock
            .toList();
        _filteredProducts = _availableProducts;
        _isLoadingProducts = false;
      });
      
      debugPrint('✅ ${_availableProducts.length} productos cargados');
    } catch (e) {
      debugPrint('❌ Error cargando productos: $e');
      setState(() => _isLoadingProducts = false);
      if (mounted) {
        await ErrorDialog.databaseError(
          context,
          details: 'Error al cargar productos desde la base de datos:\n$e',
        );
      }
    }
  }

  /// Recargar productos forzadamente (para el botón de actualizar)
  Future<void> _reloadProducts() async {
    _availableProducts.clear();
    await _loadProducts();
  }

  /// Buscar productos por código o nombre
  void _searchProducts(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredProducts = _availableProducts;
      });
      return;
    }

    final queryLower = query.toLowerCase();
    setState(() {
      _filteredProducts = _availableProducts.where((product) {
        return product.code.toLowerCase().contains(queryLower) ||
               product.name.toLowerCase().contains(queryLower);
      }).toList();
    });
  }

  /// Agregar producto al carrito
  void _addToCart(ProductModel product) {
    // Verificar si ya está en el carrito
    final existingIndex = _cart.indexWhere((item) => item.id == product.id);
    
    if (existingIndex >= 0) {
      // Ya existe, incrementar cantidad
      final existingItem = _cart[existingIndex];
      
      // Verificar stock disponible
      if (existingItem.quantity + 1 > product.stock) {
        _showSnackBar('Stock insuficiente. Disponible: ${product.stock.toInt()}', AppColors.warning);
        return;
      }
      
      setState(() {
        existingItem.quantity++;
      });
      _showSnackBar('Cantidad actualizada', AppColors.success);
    } else {
      // No existe, agregar nuevo
      setState(() {
        _cart.add(ProductModel(
          id: product.id,
          code: product.code,
          name: product.name,
          price: product.price,
          stock: product.stock,
          quantity: 1,
        ));
      });
      _showSnackBar('Producto agregado al carrito', AppColors.success);
    }
    
    Navigator.pop(context); // Cerrar el modal
  }

  // Cálculos
  double get _subtotal {
    return _cart.fold(0.0, (sum, item) {
      final itemSubtotal = item.price * item.quantity;
      return sum + itemSubtotal;
    });
  }

  double get _iva {
    if (_selectedClient != null && _selectedClient!.agenteRetencion) {
      return 0.0;
    }
    
    // IVA del 16% sobre el subtotal
    return _subtotal * 0.16;
  }

  double get _total {
    return _subtotal + _iva;
  }

  // Métodos de UI simplificados
  void _updateQuantity(String id, int delta) {
    final item = _cart.firstWhere((item) => item.id == id);
    final newQuantity = (item.quantity + delta).clamp(1, item.stock.toInt());

    // Verificar stock
    if (newQuantity > item.stock) {
      _showSnackBar('Stock insuficiente. Disponible: ${item.stock.toInt()}', AppColors.warning);
      return;
    }

    setState(() {
      item.quantity = newQuantity;
    });
  }

  void _removeFromCart(String id) {
    setState(() {
      _cart.removeWhere((item) => item.id == id);
    });
  }

  void _proceedToPayment() {
    if (_selectedClient == null) {
      _showSnackBar('Debe seleccionar un cliente', Colors.orange);
      return;
    }
    if (_cart.isEmpty) {
      _showSnackBar('Debe agregar al menos un producto', Colors.orange);
      return;
    }
    setState(() {
      _step = 'payment';
    });
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

  /// Procesar pago según el método seleccionado
  Future<void> _processPayment() async {
    if (_selectedPaymentMethod == null) {
      _showSnackBar('Debe seleccionar un método de pago', AppColors.warning);
      return;
    }

    setState(() => _isProcessingPayment = true);

    try {
      if (_selectedPaymentMethod == 'card') {
        // Pago con tarjeta usando Ubii POS
        await _processCardPayment();
      } else {
        // Otros métodos de pago (efectivo, pago móvil, etc.)
        await _processOtherPayment();
      }
    } catch (e) {
      debugPrint('❌ Error procesando pago: $e');
      _showSnackBar('Error procesando pago: $e', AppColors.error);
      
      // Liberar el botón después de un error
      if (mounted) {
        setState(() => _isProcessingPayment = false);
      }
    }
    
    // IMPORTANTE: NO usar finally aquí porque los métodos internos
    // pueden mostrar diálogos con await, y el finally se ejecutaría
    // antes de que el usuario cierre el diálogo.
    // Cada método interno debe manejar su propio estado.
  }

  /// Procesar pago con tarjeta usando Ubii POS
  Future<void> _processCardPayment() async {
    debugPrint('💳 Iniciando pago con tarjeta - Ubii POS');
    
    // Para pagos con tarjeta, se envía el monto en Bolívares
    final montoEnBs = _total * _exchangeRate;
    
    debugPrint('💰 Monto USD: \$${_total.toStringAsFixed(2)}');
    debugPrint('💰 Monto Bs: Bs ${montoEnBs.toStringAsFixed(2)}');
    debugPrint('💰 Tasa: ${_exchangeRate.toStringAsFixed(2)}');
    
    // NOTA: El monto se pasa en Bolívares para pagos con tarjeta.
    // El servicio UbiiPosService.formatAmount() lo formatea automáticamente
    // al formato requerido por Ubii (sin punto decimal, 2 decimales fijos)
    // Ejemplo: 1500.50 -> "150050"
    
    // Mostrar diálogo de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Procesando pago con Ubii POS...'),
                SizedBox(height: 8),
                Text(
                  'Por favor, complete la transacción en el punto de venta',
                  style: TextStyle(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Llamar al servicio de Ubii POS con el monto en Bs
      final resultado = await _ubiiService.processPayment(montoEnBs);

      // Cerrar diálogo de carga
      if (mounted) Navigator.pop(context);

      if (resultado == null) {
        // Error crítico - no debería pasar con el nuevo código
        if (mounted) {
          _showSnackBar(
            'Error crítico: No se recibió respuesta',
            AppColors.error,
          );
          setState(() => _isProcessingPayment = false);
        }
        return;
      }

      // Verificar código de respuesta
      if (resultado['code'] == '00') {
        // ✅ APROBADO
        debugPrint('✅ Pago aprobado por Ubii POS');
        debugPrint('   Referencia: ${resultado['reference']}');
        debugPrint('   Auth: ${resultado['authCode']}');
        debugPrint('   Tipo tarjeta: ${resultado['cardType']}');
        
        if (mounted) {
          _showSnackBar(
            '✅ Pago aprobado! Ref: ${resultado['reference']}',
            AppColors.success,
          );
          
          try {
            // Guardar factura en BD con datos de Ubii POS
            await _saveInvoice(ubiiData: resultado);
            
            // Mostrar diálogo de éxito
            _showSuccessDialog(resultado);
            
            // Liberar botón después de mostrar diálogo de éxito
            setState(() => _isProcessingPayment = false);
          } catch (e) {
            debugPrint('❌ Error guardando factura después de pago aprobado: $e');
            // Mostrar error pero indicar que el pago SÍ fue procesado
            if (mounted) {
              await ErrorDialog.show(
                context,
                title: 'Pago Aprobado - Error al Guardar',
                message: 'El pago fue aprobado por Ubii POS pero hubo un error al guardar la factura en la base de datos.',
                errorCode: ErrorCodes.invoiceCreation,
                technicalDetails: 'Error: $e\n'
                                'Referencia: ${resultado['reference']}\n'
                                'Auth: ${resultado['authCode']}\n'
                                'IMPORTANTE: El pago SÍ fue procesado. Verifica el voucher del POS.',
              );
            }
            
            // Liberar botón después de mostrar error
            if (mounted) {
              setState(() => _isProcessingPayment = false);
            }
          }
        }
      } else if (resultado['code'] == 'NO_DATA') {
        // Ubii POS no retornó datos pero volvió a la app
        // Esto significa que probablemente la transacción se procesó
        debugPrint('⚠️ Ubii POS no retornó datos');
        debugPrint('   Asumiendo transacción exitosa (el usuario no canceló)');
        
        if (mounted) {
          _showSnackBar(
            '✅ Pago procesado. Verifica el voucher del POS.',
            AppColors.success,
          );
          
          try {
            // Guardar factura sin datos de Ubii
            await _saveInvoice();
            
            // Mostrar diálogo de éxito
            _showSuccessDialog(null);
            
            // Liberar botón después de mostrar diálogo de éxito
            setState(() => _isProcessingPayment = false);
          } catch (e) {
            debugPrint('❌ Error guardando factura: $e');
            if (mounted) {
              await ErrorDialog.databaseError(
                context,
                details: 'Error al guardar la factura:\n$e',
              );
            }
            
            // Liberar botón después de mostrar error
            if (mounted) {
              setState(() => _isProcessingPayment = false);
            }
          }
        }
      } else if (resultado['code'] == 'CANCELLED') {
        // Usuario canceló la transacción
        debugPrint('⚠️ Transacción cancelada por el usuario');
        
        if (mounted) {
          _showSnackBar(
            'Transacción cancelada',
            AppColors.warning,
          );
          setState(() => _isProcessingPayment = false);
        }
      } else if (resultado['code'] == 'ERROR') {
        // Error de comunicación o app no instalada
        final mensaje = resultado['message'] ?? 'Error desconocido';
        debugPrint('❌ Error: $mensaje');
        
        if (mounted) {
          _showSnackBar(
            mensaje,
            AppColors.error,
          );
          setState(() => _isProcessingPayment = false);
        }
      } else {
        // ❌ RECHAZADA o ERROR
        final mensaje = resultado['message'] ?? 'Transacción rechazada';
        debugPrint('❌ Pago rechazado: $mensaje');
        
        if (mounted) {
          await ErrorDialog.show(
            context,
            title: 'Pago Rechazado',
            message: mensaje,
            errorCode: ErrorCodes.ubiiPayment,
            technicalDetails: 'Código: ${resultado['code']}\n'
                            'Terminal: ${resultado['terminal']}\n'
                            'Lote: ${resultado['lote']}\n'
                            'Monto: \$${_total.toStringAsFixed(2)}',
          );
          setState(() => _isProcessingPayment = false);
        }
      }
    } catch (e) {
      // Cerrar diálogo de carga si está abierto
      if (mounted) Navigator.pop(context);
      
      debugPrint('❌ Error en pago con tarjeta: $e');
      if (mounted) {
        await ErrorDialog.genericError(
          context,
          message: 'Ocurrió un error al procesar el pago con tarjeta',
          details: 'Error: $e\n'
                  'Monto: \$${_total.toStringAsFixed(2)}',
        );
      }
    }
  }

  /// Procesar otros métodos de pago (efectivo, pago móvil, etc.)
  Future<void> _processOtherPayment() async {
    debugPrint('💰 Procesando pago: $_selectedPaymentMethod');
    
    // Si es Pago Móvil, usar la integración con Ubii
    if (_selectedPaymentMethod == 'pago_movil') {
      await _processPagoMovil();
      return;
    }
    
    // Para otros métodos (efectivo, débito inmediato), simular procesamiento
    await Future.delayed(const Duration(seconds: 1));
    
    if (mounted) {
      _showSnackBar(
        'Pago procesado exitosamente ($_selectedPaymentMethod)',
        AppColors.success,
      );
      
      try {
        // Guardar factura en BD
        await _saveInvoice();
        
        _showSuccessDialog(null);
        setState(() => _isProcessingPayment = false);
      } catch (e) {
        debugPrint('❌ Error guardando factura: $e');
        if (mounted) {
          await ErrorDialog.show(
            context,
            title: 'Error al Guardar Factura',
            message: 'El pago fue procesado pero hubo un error al guardar la factura en la base de datos.',
            errorCode: ErrorCodes.invoiceCreation,
            technicalDetails: 'Error: $e\n'
                            'Método de pago: $_selectedPaymentMethod\n'
                            'Monto: \${_total.toStringAsFixed(2)}',
          );
        }
        if (mounted) {
          setState(() => _isProcessingPayment = false);
        }
      }
    }
  }

  /// Procesar Pago Móvil usando Ubii API
  Future<void> _processPagoMovil() async {
    debugPrint('📱 Iniciando Pago Móvil - Ubii API');
    
    // Calcular monto en Bolívares
    final montoEnBs = _total * _exchangeRate;
    
    debugPrint('💰 Monto USD: \$${_total.toStringAsFixed(2)}');
    debugPrint('💰 Monto Bs: Bs ${montoEnBs.toStringAsFixed(2)}');
    debugPrint('💰 Tasa: ${_exchangeRate.toStringAsFixed(2)}');
    
    try {
      // Abrir pantalla de Pago Móvil
      final transaction = await Navigator.push<PagoMovilTransaction>(
        context,
        MaterialPageRoute(
          builder: (context) => PagoMovilScreen(
            montoInicial: montoEnBs,
          ),
        ),
      );
      
      // Verificar si el pago fue aprobado
      if (transaction != null && transaction.status == PagoMovilStatus.approved) {
        debugPrint('✅ Pago Móvil aprobado');
        debugPrint('   Referencia: ${transaction.referencia}');
        debugPrint('   Orden: ${transaction.orderNumber}');
        debugPrint('   Banco: ${transaction.bankAba}');
        
        if (mounted) {
          _showSnackBar(
            '✅ Pago Móvil aprobado! Ref: ${transaction.referencia}',
            AppColors.success,
          );
          
          try {
            // Guardar factura con referencia del Pago Móvil
            await _saveInvoice(
              pagoMovilData: {
                'referencia': transaction.referencia,
                'orderNumber': transaction.orderNumber,
                'banco': transaction.bankAba,
                'telefono': transaction.phoneCliente,
              },
            );
            
            _showSuccessDialog(null);
            setState(() => _isProcessingPayment = false);
          } catch (e) {
            debugPrint('❌ Error guardando factura después de Pago Móvil aprobado: $e');
            if (mounted) {
              await ErrorDialog.show(
                context,
                title: 'Pago Móvil Aprobado - Error al Guardar',
                message: 'El Pago Móvil fue aprobado pero hubo un error al guardar la factura en la base de datos.',
                errorCode: ErrorCodes.invoiceCreation,
                technicalDetails: 'Error: $e\n'
                                'Referencia: ${transaction.referencia}\n'
                                'Orden: ${transaction.orderNumber}\n'
                                'Banco: ${transaction.bankAba}\n'
                                'IMPORTANTE: El pago SÍ fue procesado.',
              );
            }
            if (mounted) {
              setState(() => _isProcessingPayment = false);
            }
          }
        }
      } else if (transaction != null) {
        // Pago no aprobado (rechazado, timeout, error)
        debugPrint('❌ Pago Móvil no aprobado: ${transaction.status.displayName}');
        
        if (mounted) {
          await ErrorDialog.show(
            context,
            title: 'Pago Móvil ${transaction.status.displayName}',
            message: transaction.errorMessage ?? 'El pago no fue aprobado. Verifica los datos e intenta nuevamente.',
            errorCode: ErrorCodes.pagoMovilInvalid,
            technicalDetails: 'Referencia: ${transaction.referencia}\n'
                            'Banco: ${transaction.bankAba}\n'
                            'Teléfono: ${transaction.phoneCliente}\n'
                            'Monto: Bs. ${transaction.monto.toStringAsFixed(2)}\n'
                            'Estado: ${transaction.status.displayName}\n'
                            'Código: ${transaction.responseCode}\n'
                            'Mensaje: ${transaction.responseMessage}',
          );
          setState(() => _isProcessingPayment = false);
        }
      } else {
        // Usuario canceló o cerró la pantalla
        debugPrint('⚠️ Pago Móvil cancelado por el usuario');
        
        if (mounted) {
          CustomSnackBar.warning(context, 'Pago Móvil cancelado');
          setState(() => _isProcessingPayment = false);
        }
      }
    } catch (e) {
      debugPrint('❌ Error en Pago Móvil: $e');
      if (mounted) {
        await ErrorDialog.genericError(
          context,
          message: 'Ocurrió un error al procesar el Pago Móvil',
          details: 'Error: $e\n'
                  'Monto: Bs. ${(_total * _exchangeRate).toStringAsFixed(2)}',
        );
      }
    }
  }

  /// Guardar factura en la base de datos
  Future<void> _saveInvoice({
    Map<String, dynamic>? ubiiData,
    Map<String, dynamic>? pagoMovilData,
  }) async {
    try {
      debugPrint('💾 Guardando factura en BD...');
      
      // Obtener ID del usuario actual (por ahora usamos 1, el admin)
      const int usuarioId = 1;
      
      // Calcular montos
      final montoUsd = _total;
      final montoBs = _total * _exchangeRate;
      
      // ==================== CÁLCULOS FISCALES ====================
      // Calcular base imponible (subtotal sin IVA)
      final baseImponible = _subtotal;
      
      // Calcular monto de IVA (16%)
      final montoIva = _iva;
      
      // Tipo de documento fiscal (por defecto "Factura")
      const tipoDocumento = 'Factura';
      
      debugPrint('📊 Cálculos fiscales:');
      debugPrint('   Base imponible: \$${baseImponible.toStringAsFixed(2)}');
      debugPrint('   IVA (16%): \$${montoIva.toStringAsFixed(2)}');
      debugPrint('   Total: \$${_total.toStringAsFixed(2)}');
      debugPrint('   Tipo documento: $tipoDocumento');
      // =========================================================
      
      // Preparar referencia de pago
      String? referenciaPago;
      if (pagoMovilData != null) {
        // Para Pago Móvil, usar la referencia de Ubii
        referenciaPago = pagoMovilData['referencia'];
      } else if (_paymentReferenceController.text.trim().isNotEmpty) {
        // Para otros métodos, usar la referencia manual
        referenciaPago = _paymentReferenceController.text.trim();
      }
      
      // Preparar detalles de la factura
      final detalles = _cart.map((item) {
        return {
          'producto_id': int.parse(item.id),
          'cantidad': item.quantity.toDouble(),
          'precio_unitario': item.price,
          'subtotal': item.price * item.quantity,
        };
      }).toList();
      
      // Guardar factura
      final facturaId = await DbHelper.instance.crearFactura(
        clienteId: _selectedClient!.id ?? 0,
        usuarioId: usuarioId,
        baseImponible: _subtotal,
        montoIva: _iva,
        tasaUsd: _exchangeRate,
        tasaEur: 0.0, // No se usa EUR por ahora
        total: _total,
        detalles: detalles,
        metodoPago: _selectedPaymentMethod!,
        referenciaPago: referenciaPago,
        montoBs: montoBs,
        montoUsd: montoUsd,
        ubiiReference: ubiiData?['reference'],
        ubiiAuthCode: ubiiData?['authCode'],
        ubiiCardType: ubiiData?['cardType'],
        ubiiTerminal: ubiiData?['terminal'],
        ubiiLote: ubiiData?['lote'],
        ubiiResponseCode: ubiiData?['code'],
        ubiiResponseMessage: ubiiData?['message'],
      );
      
      debugPrint('✅ Factura guardada con ID: $facturaId');
      debugPrint('   Cliente: ${_selectedClient!.nombre}');
      debugPrint('   Método: $_selectedPaymentMethod');
      debugPrint('   Total USD: \$${montoUsd.toStringAsFixed(2)}');
      debugPrint('   Total Bs: Bs ${montoBs.toStringAsFixed(2)}');
      
      if (ubiiData != null) {
        debugPrint('   Ubii Ref: ${ubiiData['reference']}');
        debugPrint('   Ubii Auth: ${ubiiData['authCode']}');
      }
      
      if (pagoMovilData != null) {
        debugPrint('   Pago Móvil Ref: ${pagoMovilData['referencia']}');
        debugPrint('   Pago Móvil Orden: ${pagoMovilData['orderNumber']}');
        debugPrint('   Pago Móvil Banco: ${pagoMovilData['banco']}');
      }
      
    } catch (e) {
      debugPrint('❌ Error guardando factura: $e');
      if (mounted) {
        await ErrorDialog.databaseError(
          context,
          details: 'Error al guardar la factura en la base de datos:\n$e\n\n'
                  'Cliente: ${_selectedClient?.nombre}\n'
                  'Total: \$${_total.toStringAsFixed(2)}\n'
                  'Método: $_selectedPaymentMethod',
        );
      }
      rethrow;
    }
  }

  /// Limpiar todos los datos del formulario
  void _resetForm() {
    setState(() {
      // Limpiar cliente
      _selectedClient = null;
      _rifSearchController.clear();
      
      // Limpiar carrito
      _cart.clear();
      
      // Limpiar método de pago
      _selectedPaymentMethod = null;
      _paymentReferenceController.clear();
      
      // Volver al paso de creación
      _step = 'creation';
    });
    
    debugPrint('✅ Formulario limpiado - Listo para nueva factura');
  }

  /// Mostrar diálogo de éxito
  void _showSuccessDialog(Map<String, dynamic>? ubiiData) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 32),
              SizedBox(width: 12),
              Text('Pago Exitoso'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Monto: ${CurrencyFormatter.formatBS(_total, _exchangeRate)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                CurrencyFormatter.formatUSD(_total),
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 16),
              if (ubiiData != null && ubiiData['code'] == '00') ...[
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Datos de Ubii POS:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                _buildInfoRow('Referencia', ubiiData['reference'] ?? 'N/A'),
                _buildInfoRow('Auth', ubiiData['authCode'] ?? 'N/A'),
                _buildInfoRow('Tipo tarjeta', ubiiData['cardType'] ?? 'N/A'),
                _buildInfoRow('Terminal', ubiiData['terminal'] ?? 'N/A'),
                _buildInfoRow('Lote', ubiiData['lote'] ?? 'N/A'),
              ] else ...[
                const Divider(),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.info, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Verifica el voucher impreso en el POS para confirmar la transacción.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Cerrar diálogo
                _resetForm(); // Limpiar formulario para nueva factura
                _showSnackBar('Listo para nueva factura', AppColors.success);
              },
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Nueva Factura'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Mostrar diálogo cuando Ubii POS no retorna datos
  void _showNoDataDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 32),
              const SizedBox(width: 12),
              Text(
                'Verificar Transacción',
                style: TextStyle(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
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
                  'Ubii POS no retornó datos de la transacción.',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '¿Se imprimió el voucher en el POS?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Si el voucher se imprimió, la transacción fue exitosa.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Nota: Este mensaje aparece porque Ubii POS no está retornando los datos correctamente. Contacta al desarrollador para configurar la integración.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _showSnackBar('Transacción no procesada', AppColors.warning);
              },
              child: Text(
                'No se imprimió',
                style: TextStyle(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                
                // Guardar factura sin datos de Ubii
                await _saveInvoice();
                
                _showSnackBar(
                  'Factura guardada. Verifica el voucher del POS.',
                  AppColors.success,
                );
                
                _showSuccessDialog(null);
              },
              icon: const Icon(Icons.check),
              label: const Text('Sí, se imprimió'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Mostrar diálogo con datos de debugging
  void _showDebugDataDialog(Map<String, dynamic> data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Convertir el mapa a texto legible
    final dataText = data.entries
        .map((e) => '${e.key}: ${e.value}')
        .join('\n');
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.bug_report, color: AppColors.warning, size: 32),
              const SizedBox(width: 12),
              Text(
                'Datos de Ubii POS',
                style: TextStyle(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
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
                  'Datos recibidos de Ubii POS:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: SelectableText(
                    dataText.isEmpty ? 'Sin datos' : dataText,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '¿Se imprimió el voucher?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Por favor, toma una captura de pantalla de estos datos y envíala al desarrollador para configurar la integración correctamente.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _showSnackBar('Transacción no procesada', AppColors.warning);
              },
              child: Text(
                'No se imprimió',
                style: TextStyle(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                
                // Guardar factura sin datos de Ubii
                await _saveInvoice();
                
                _showSnackBar(
                  'Factura guardada',
                  AppColors.success,
                );
                
                _showSuccessDialog(null);
              },
              icon: const Icon(Icons.check),
              label: const Text('Sí, guardar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_step == 'payment') {
      return _buildPaymentStep(isDark);
    } else {
      return _buildCreationStep(isDark);
    }
  }

  Widget _buildCreationStep(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Nueva Factura'),
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Cancelar factura'),
                content: const Text('¿Desea salir? Se perderán los datos ingresados.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('No'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    child: const Text('Sí'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      body: Form(
        key: _clientFormKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildClientSection(isDark),
                    const SizedBox(height: 16),
                    _buildProductsSection(isDark),
                    const SizedBox(height: 16),
                    _buildTotalsSection(isDark),
                  ],
                ),
              ),
            ),
            _buildBottomCobrarButton(isDark),
          ],
        ),
      ),
    );
  }


  Widget _buildBottomCobrarButton(bool isDark) {
    final hasItems = _cart.isNotEmpty;
    final hasClient = _selectedClient != null;
    final canProceed = hasItems && hasClient;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: canProceed ? _proceedToPayment : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                disabledForegroundColor: Colors.grey[600],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: canProceed ? 4 : 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.payment,
                    size: 28,
                    color: canProceed ? Colors.white : Colors.grey[600],
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'CONFIRMAR',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: canProceed ? Colors.white : Colors.grey[600],
                    ),
                  ),
                  if (_cart.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: canProceed ? Colors.white.withValues(alpha: 0.2) : Colors.grey[400],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_cart.length}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: canProceed ? Colors.white : Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClientSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DATOS DEL CLIENTE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRifType,
                    items: _rifTypes.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedRifType = value!;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _rifSearchController,
                  decoration: InputDecoration(
                    hintText: 'Número de RIF o Cédula',
                    filled: true,
                    fillColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkPrimary : AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: _isSearchingClient
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.search, color: Colors.white),
                  onPressed: _isSearchingClient ? null : _searchClient,
                  tooltip: 'Buscar',
                ),
              ),
            ],
          ),
          if (_selectedClient != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedClient!.nombre,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'RIF/CÉDULA: ${_selectedClient!.identificacion}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      setState(() {
                        _selectedClient = null;
                        _rifSearchController.clear();
                      });
                    },
                    tooltip: 'Quitar cliente',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }


  Widget _buildProductsSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PRODUCTOS / SERVICIOS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  if (_cart.isNotEmpty)
                    Text(
                      'Desliza ← para eliminar',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
              TextButton(
                onPressed: _isLoadingProducts ? null : () async {
                  // Cargar productos ANTES de abrir el modal
                  if (_availableProducts.isEmpty && !_isLoadingProducts) {
                    await _loadProducts();
                  }
                  
                  if (mounted) {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) => _buildProductModal(isDark),
                    );
                  }
                },
                style: TextButton.styleFrom(
                  side: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoadingProducts 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('+ Agregar'),
              ),
            ],
          ),
          if (_cart.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: 40,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No hay items agregados',
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._cart.map((item) => _buildCartItem(item, isDark)),
        ],
      ),
    );
  }

  Widget _buildCartItem(ProductModel item, bool isDark) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
          size: 28,
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Eliminar producto'),
              content: Text('¿Desea eliminar "${item.name}" del carrito?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text(
                    'Eliminar',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ],
            );
          },
        ) ?? false;
      },
      onDismissed: (direction) {
        _removeFromCart(item.id);
        _showSnackBar('Producto eliminado del carrito', AppColors.success);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name.toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: isDark 
                        ? AppColors.darkCard.withValues(alpha: 0.5)
                        : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => _updateQuantity(item.id, -1),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.remove, size: 16),
                        ),
                      ),
                      Container(
                        constraints: const BoxConstraints(minWidth: 28),
                        alignment: Alignment.center,
                        child: Text(
                          '${item.quantity}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => _updateQuantity(item.id, 1),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.add, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.formatBS(item.price * item.quantity, _exchangeRate),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.successDark,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.formatUSD(item.price * item.quantity),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.successDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.drag_indicator,
                  size: 18,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildTotalsSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          _buildTotalRow('Subtotal', _subtotal, false, isDark),
          _buildTotalRow('IVA (16%)', _iva, false, isDark),
          if (_selectedClient != null && _selectedClient!.agenteRetencion && _iva == 0)
            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: AppColors.info,
                  ),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'IVA no aplicado - Cliente es Agente de Retención',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.info,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(),
          _buildTotalRow('TOTAL', _total, true, isDark),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double value, bool isFinal, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isFinal ? 18 : 14,
                  fontWeight: isFinal ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.formatBS(value, _exchangeRate),
                    style: TextStyle(
                      fontSize: isFinal ? 24 : 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.successDark,
                    ),
                  ),
                  Text(
                    CurrencyFormatter.formatUSD(value),
                    style: TextStyle(
                      fontSize: isFinal ? 14 : 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.successDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductModal(bool isDark) {
    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setModalState) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Seleccionar Producto',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _productSearchController,
                            decoration: InputDecoration(
                              hintText: 'Buscar por código o nombre...',
                              filled: true,
                              fillColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: const Icon(Icons.search),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            textInputAction: TextInputAction.search,
                            onChanged: (value) {
                              setModalState(() {
                                _searchProducts(value);
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkPrimary : AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.refresh, color: Colors.white),
                            onPressed: () async {
                              setModalState(() {
                                _productSearchController.clear();
                              });
                              await _reloadProducts();
                              setModalState(() {});
                            },
                            tooltip: 'Recargar',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoadingProducts
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredProducts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 48,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _productSearchController.text.isEmpty
                                      ? 'No hay productos disponibles'
                                      : 'No se encontraron productos',
                                  style: TextStyle(
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                                if (_productSearchController.text.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  TextButton.icon(
                                    onPressed: () {
                                      setModalState(() {
                                        _productSearchController.clear();
                                        _searchProducts('');
                                      });
                                    },
                                    icon: const Icon(Icons.clear),
                                    label: const Text('Limpiar búsqueda'),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredProducts.length,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemBuilder: (context, index) {
                              final product = _filteredProducts[index];
                              final isInCart = _cart.any((item) => item.id == product.id);
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.inventory_2,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  title: Text(
                                    product.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        'Código: ${product.code}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Text(
                                            CurrencyFormatter.formatUSD(product.price),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.success,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: product.stock > 10
                                                  ? AppColors.success.withValues(alpha: 0.1)
                                                  : AppColors.warning.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'Stock: ${product.stock.toInt()}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: product.stock > 10 ? AppColors.success : AppColors.warning,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: isInCart
                                      ? const Icon(
                                          Icons.check_circle,
                                          color: AppColors.success,
                                        )
                                      : IconButton(
                                          icon: const Icon(Icons.add_shopping_cart),
                                          color: AppColors.primary,
                                          onPressed: () => _addToCart(product),
                                        ),
                                  onTap: () => _addToCart(product),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildPaymentStep(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Cobro'),
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _step = 'creation';
            });
          },
        ),
      ),
      body: Form(
        key: _paymentFormKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Monto a Cobrar',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        CurrencyFormatter.formatBS(_total, _exchangeRate),
                        style: const TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.formatUSD(_total),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedClient?.nombre.toUpperCase() ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              const Text(
                'Método de Pago',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildPaymentMethod('cash', 'Efectivo', Icons.money, AppColors.success, isDark),
                  _buildPaymentMethod('card', 'Tarjeta', Icons.credit_card, AppColors.info, isDark),
                  _buildPaymentMethod('pago_movil', 'Pago Móvil', Icons.phone_android, AppColors.primary, isDark),
                  _buildPaymentMethod('debit_immediate', 'Débito Inm.', Icons.account_balance, AppColors.primaryDark, isDark),
                ],
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isProcessingPayment ? null : _processPayment,
              icon: _isProcessingPayment
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                _isProcessingPayment ? 'PROCESANDO...' : 'PROCESAR Y EMITIR',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isProcessingPayment ? Colors.grey : AppColors.success,
                foregroundColor: AppColors.textLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethod(String id, String label, IconData icon, Color color, bool isDark) {
    final isSelected = _selectedPaymentMethod == id;
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = id;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: (MediaQuery.of(context).size.width - 44) / 2,
        height: 100,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _rifSearchController.dispose();
    _productSearchController.dispose();
    _paymentReferenceController.dispose();
    super.dispose();
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
