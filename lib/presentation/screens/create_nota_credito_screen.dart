import 'package:flutter/material.dart';
import 'package:pos_android/database/db_helper.dart';
import 'package:pos_android/database/nota_credito_dao.dart';
import 'package:pos_android/services/nota_credito_service.dart';
import 'package:pos_android/presentation/widgets/loading_widget.dart';
import 'package:pos_android/presentation/widgets/error_widget.dart'
    as error_widget;

class CreateNotaCreditoScreen extends StatefulWidget {
  const CreateNotaCreditoScreen({super.key});

  @override
  State<CreateNotaCreditoScreen> createState() =>
      _CreateNotaCreditoScreenState();
}

class _CreateNotaCreditoScreenState extends State<CreateNotaCreditoScreen> {
  final NotaCreditoService _service = NotaCreditoService(DbHelper.instance);
  final _formKey = GlobalKey<FormState>();

  // Paso 1: Selección de factura
  int _currentStep = 0;
  String? _facturaIdError;
  final TextEditingController _facturaIdController = TextEditingController();
  Map<String, dynamic>? _facturaSeleccionada;
  Map<String, dynamic>? _clienteFactura;
  bool _validandoFactura = false;

  // Paso 2: Tipo y motivo
  String _tipoNotaCredito = 'total';
  String? _motivoSeleccionado;
  final TextEditingController _observacionesController =
      TextEditingController();
  List<Map<String, dynamic>> _motivosDisponibles = [];
  bool _cargandoMotivos = false;

  // Paso 3: Productos (solo para parcial)
  List<Map<String, dynamic>> _productosFactura = [];
  final List<Map<String, dynamic>> _productosSeleccionados = [];
  final Map<int, double> _cantidadesSeleccionadas = {};

  // Estado general
  bool _creandoNotaCredito = false;
  String? _errorGeneral;

  @override
  void initState() {
    super.initState();
    _cargarMotivos();
  }

  Future<void> _cargarMotivos() async {
    setState(() {
      _cargandoMotivos = true;
    });

    try {
      final dao = NotaCreditoDao(DbHelper.instance);
      final motivos = await dao.obtenerTodosMotivos(soloActivos: true);

      setState(() {
        _motivosDisponibles = motivos.map((motivo) {
          return {
            'codigo': motivo.codigo,
            'descripcion': motivo.descripcion,
            'tipo': motivo.tipo,
          };
        }).toList();
        _cargandoMotivos = false;
      });
    } catch (e) {
      setState(() {
        _errorGeneral = 'Error cargando motivos: $e';
        _cargandoMotivos = false;
      });
    }
  }

  /// Normaliza la entrada del usuario al formato numero_control de la BD.
  /// Ahora el formato es puramente numérico (ej: "0000001")
  String _normalizarNumeroControl(String input) {
    String normalizado = input.trim();
    // Eliminar prefijo FAC- si existe
    normalizado = normalizado.toUpperCase().replaceAll('FAC-', '');

    // Rellenar con ceros a 7 dígitos si es puramente numérico
    final soloNumero = int.tryParse(normalizado);
    if (soloNumero != null) {
      normalizado = soloNumero.toString().padLeft(7, '0');
    }

    return normalizado;
  }

  Future<void> _validarFactura() async {
    final inputUsuario = _facturaIdController.text.trim();
    if (inputUsuario.isEmpty) {
      setState(() {
        _facturaIdError = 'Ingrese el número de factura del comprobante';
      });
      return;
    }

    final numeroControl = _normalizarNumeroControl(inputUsuario);

    setState(() {
      _validandoFactura = true;
      _facturaIdError = null;
      _facturaSeleccionada = null;
      _clienteFactura = null;
      _productosFactura = [];
    });

    try {
      // Buscar la factura por numero_control (lo que se imprime en el ticket)
      final db = await DbHelper.instance.database;

      final factura = await db.query(
        'factura',
        where: 'numero_control = ?',
        whereArgs: [numeroControl],
        limit: 1,
      );

      if (factura.isEmpty) {
        setState(() {
          _facturaIdError = 'Factura "$numeroControl" no encontrada. '
              'Verifique el número impreso en el comprobante.';
          _validandoFactura = false;
        });
        return;
      }

      final facturaId = factura.first['id'] as int;

      // Validar reglas de negocio con el id interno
      final validacion =
          await _service.validarFacturaParaNotaCredito(facturaId);

      if (!validacion['valido']) {
        setState(() {
          _facturaIdError = validacion['mensaje'] as String;
          _validandoFactura = false;
        });
        return;
      }

      // Cliente
      final clienteId = factura.first['cliente_id'] as int;
      final cliente = await db.query(
        'clientes',
        where: 'id = ?',
        whereArgs: [clienteId],
        limit: 1,
      );

      // Productos de la factura
      final productos = await db.rawQuery('''
        SELECT 
          fd.id,
          fd.producto_id,
          p.cod_articulo,
          p.nombre,
          fd.cantidad,
          fd.precio_unitario,
          fd.subtotal,
          p.unidad_medida
        FROM factura_detalle fd
        INNER JOIN productos p ON fd.producto_id = p.id
        WHERE fd.factura_id = ?
        ORDER BY fd.id ASC
      ''', [facturaId]);

      setState(() {
        _facturaSeleccionada = factura.first;
        _clienteFactura = cliente.isNotEmpty ? cliente.first : {};
        _productosFactura = productos;
        _validandoFactura = false;

        // Avanzar al siguiente paso
        _currentStep = 1;
      });
    } catch (e) {
      setState(() {
        _facturaIdError = 'Error validando factura: $e';
        _validandoFactura = false;
      });
    }
  }

  void _seleccionarProducto(Map<String, dynamic> producto, bool seleccionado) {
    setState(() {
      if (seleccionado) {
        _productosSeleccionados.add(producto);
        _cantidadesSeleccionadas[producto['producto_id'] as int] =
            (producto['cantidad'] as num).toDouble();
      } else {
        _productosSeleccionados
            .removeWhere((p) => p['producto_id'] == producto['producto_id']);
        _cantidadesSeleccionadas.remove(producto['producto_id'] as int);
      }
    });
  }

  void _actualizarCantidad(int productoId, double cantidad) {
    setState(() {
      _cantidadesSeleccionadas[productoId] = cantidad;

      // Actualizar el producto en la lista seleccionada
      final index = _productosSeleccionados
          .indexWhere((p) => p['producto_id'] == productoId);
      if (index != -1) {
        final producto =
            Map<String, dynamic>.from(_productosSeleccionados[index]);
        producto['cantidad'] = cantidad;
        producto['subtotal'] =
            cantidad * (producto['precio_unitario'] as num).toDouble();
        _productosSeleccionados[index] = producto;
      }
    });
  }

  Future<void> _crearNotaCredito() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    if (_tipoNotaCredito == 'parcial' && _productosSeleccionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Seleccione al menos un producto para nota de crédito parcial')),
      );
      return;
    }

    if (_motivoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione un motivo')),
      );
      return;
    }

    setState(() {
      _creandoNotaCredito = true;
      _errorGeneral = null;
    });

    try {
      // Verificación defensiva
      if (_facturaSeleccionada == null) {
        throw Exception('No hay factura seleccionada');
      }

      final facturaId = _facturaSeleccionada!['id'] as int;
      const usuarioId = 1; // TODO: Obtener del usuario logueado

      Map<String, dynamic> resultado;

      if (_tipoNotaCredito == 'total') {
        // Verificación defensiva
        if (_motivoSeleccionado == null) {
          throw Exception('No hay motivo seleccionado');
        }

        resultado = await _service.crearNotaCreditoTotal(
          facturaId: facturaId,
          motivo: _motivoSeleccionado!,
          usuarioId: usuarioId,
          observaciones: _observacionesController.text.trim(),
        );
      } else {
        // Preparar productos para nota parcial
        final productosParaNota = _productosSeleccionados.map((producto) {
          return {
            'producto_id': producto['producto_id'],
            'cantidad':
                _cantidadesSeleccionadas[producto['producto_id'] as int] ??
                    (producto['cantidad'] as num).toDouble(),
            'lote': producto['lote'],
            'serial': producto['serial'],
            'fecha_vencimiento': producto['fecha_vencimiento'],
          };
        }).toList();

        // Verificación defensiva
        if (_motivoSeleccionado == null) {
          throw Exception('No hay motivo seleccionado');
        }

        resultado = await _service.crearNotaCreditoParcial(
          facturaId: facturaId,
          motivo: _motivoSeleccionado!,
          usuarioId: usuarioId,
          productos: productosParaNota,
          observaciones: _observacionesController.text.trim(),
        );
      }

      if (resultado['valido'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(resultado['mensaje'] as String),
              backgroundColor: Colors.green,
            ),
          );

          // Regresar a la lista
          Navigator.pop(context);
        }
      } else {
        setState(() {
          _errorGeneral = resultado['mensaje'] as String;
          _creandoNotaCredito = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_errorGeneral!),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorGeneral = 'Error creando nota de crédito: $e';
        _creandoNotaCredito = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorGeneral!),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _retrocederPaso() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    } else {
      Navigator.pop(context);
    }
  }

  void _avanzarPaso() {
    // Validar antes de avanzar
    if (_currentStep == 0) {
      // Validar paso 1: Factura
      if (_facturaSeleccionada == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debe seleccionar una factura válida primero'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } else if (_currentStep == 1) {
      // Validar paso 2: Tipo y Motivo
      if (_motivoSeleccionado == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debe seleccionar un motivo'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_tipoNotaCredito == 'parcial' && _productosSeleccionados.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Para nota parcial debe seleccionar al menos un producto'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
    } else {
      _crearNotaCredito();
    }
  }

  List<Step> _buildSteps() {
    return [
      Step(
        title: const Text('Factura'),
        content: _buildPasoFactura(),
        isActive: _currentStep >= 0,
        state: _currentStep > 0 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: const Text('Tipo y Motivo'),
        content: _buildPasoTipoMotivo(),
        isActive: _currentStep >= 1,
        state: _currentStep > 1 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: Text(_tipoNotaCredito == 'total' ? 'Confirmación' : 'Productos'),
        content: _currentStep >= 2
            ? (_tipoNotaCredito == 'total'
                ? _buildPasoConfirmacion()
                : _buildPasoProductos())
            : const SizedBox.shrink(),
        isActive: _currentStep >= 2,
        state: StepState.indexed,
      ),
    ];
  }

  Widget _buildPasoFactura() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _facturaIdController,
          decoration: InputDecoration(
            labelText: 'N° de Factura',
            hintText: 'Ej: 0000001 o FAC-0000001',
            helperText: 'Ingrese el número impreso en el comprobante',
            errorText: _facturaIdError,
            prefixIcon: const Icon(Icons.receipt_long),
            suffixIcon: _validandoFactura
                ? const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _validandoFactura ? null : _validarFactura,
                  ),
          ),
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.characters,
          onFieldSubmitted: (_) => _validarFactura(),
        ),
        const SizedBox(height: 16),
        if (_facturaSeleccionada != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Factura #${_facturaSeleccionada!['numero_control']}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cliente: ${_clienteFactura?['nombre'] ?? 'N/A'}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    'RIF: ${_clienteFactura?['identificacion'] ?? 'N/A'}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Fecha: ${_facturaSeleccionada!['fecha_creacion']}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    'Total: \$${(_facturaSeleccionada!['total'] as num).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  Text(
                    'Total Bs: ${((_facturaSeleccionada!['total'] as num).toDouble() * ((_facturaSeleccionada!['tasa_usd'] as num?)?.toDouble() ?? 36.50)).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.blueGrey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPasoTipoMotivo() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tipo de Nota de Crédito',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(
                value: 'total',
                label: Text('Total'),
                icon: Icon(Icons.all_inclusive),
              ),
              ButtonSegment<String>(
                value: 'parcial',
                label: Text('Parcial'),
                icon: Icon(Icons.pie_chart_outline),
              ),
            ],
            selected: {_tipoNotaCredito},
            onSelectionChanged: (Set<String> newSelection) {
              setState(() {
                _tipoNotaCredito = newSelection.first;
              });
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Motivo',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_cargandoMotivos)
            const LoadingWidget(message: 'Cargando motivos...')
          else if (_motivosDisponibles.isEmpty)
            const Text('No hay motivos disponibles',
                style: TextStyle(color: Colors.red))
          else
            Container(
              constraints: const BoxConstraints(maxWidth: double.infinity),
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _motivoSeleccionado,
                decoration: const InputDecoration(
                  labelText: 'Seleccione un motivo',
                  border: OutlineInputBorder(),
                ),
                items: _motivosDisponibles
                    .where((motivo) => _tipoNotaCredito == 'total'
                        ? motivo['tipo'] == 'total' || motivo['tipo'] == 'ambos'
                        : motivo['tipo'] == 'parcial' ||
                            motivo['tipo'] == 'ambos')
                    .map((motivo) {
                  return DropdownMenuItem<String>(
                    value: motivo['codigo'],
                    child: Text(
                      motivo['descripcion'],
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _motivoSeleccionado = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Seleccione un motivo';
                  }
                  return null;
                },
              ),
            ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _observacionesController,
            decoration: const InputDecoration(
              labelText: 'Observaciones (opcional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildPasoProductos() {
    // Verificar si tenemos datos de factura
    if (_facturaSeleccionada == null) {
      return const Column(
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No hay información de factura disponible. '
                'Por favor, complete el paso 1 primero.',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Seleccione los productos a devolver',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_productosFactura.isEmpty)
          const Text('La factura no tiene productos',
              style: TextStyle(color: Colors.red))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _productosFactura.length,
            itemBuilder: (context, index) {
              final producto = _productosFactura[index];
              final productoId = producto['producto_id'] as int;
              final estaSeleccionado = _productosSeleccionados
                  .any((p) => p['producto_id'] == productoId);
              final cantidadOriginal = (producto['cantidad'] as num).toDouble();
              final cantidadSeleccionada =
                  _cantidadesSeleccionadas[productoId] ?? cantidadOriginal;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: estaSeleccionado,
                            onChanged: (value) {
                              _seleccionarProducto(producto, value ?? false);
                            },
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  producto['nombre'] as String,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Código: ${producto['cod_articulo']}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (estaSeleccionado) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('Cantidad: ',
                                style: TextStyle(fontSize: 14)),
                            Expanded(
                              child: Slider(
                                value: cantidadSeleccionada,
                                min: 0.1,
                                max: cantidadOriginal,
                                divisions: (cantidadOriginal * 10).toInt(),
                                label: cantidadSeleccionada.toStringAsFixed(1),
                                onChanged: (value) {
                                  _actualizarCantidad(productoId, value);
                                },
                              ),
                            ),
                            Text(
                              '${cantidadSeleccionada.toStringAsFixed(1)} / $cantidadOriginal',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Subtotal: \$${(cantidadSeleccionada * (producto['precio_unitario'] as num).toDouble()).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 16),
        if (_productosSeleccionados.isNotEmpty) ...[
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resumen de productos seleccionados',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ..._productosSeleccionados.map((producto) {
                    final cantidad = _cantidadesSeleccionadas[
                            producto['producto_id'] as int] ??
                        (producto['cantidad'] as num).toDouble();
                    final subtotal = cantidad *
                        (producto['precio_unitario'] as num).toDouble();

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              producto['nombre'] as String,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          Text(
                            '$cantidad x \$${(producto['precio_unitario'] as num).toStringAsFixed(2)} = \$${subtotal.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total seleccionado:',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '\$${_calcularTotalSeleccionado().toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total en Bs:',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Bs ${(_calcularTotalSeleccionado() * ((_facturaSeleccionada?['tasa_usd'] as num?)?.toDouble() ?? 36.50)).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPasoConfirmacion() {
    // Verificar si tenemos datos de factura
    if (_facturaSeleccionada == null) {
      return const Column(
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No hay información de factura disponible. '
                'Por favor, complete el paso 1 primero.',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Resumen de la nota de crédito',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildResumenItem('Factura:',
                    _facturaSeleccionada!['numero_control'] as String),
                _buildResumenItem(
                    'Cliente:', _clienteFactura?['nombre'] ?? 'N/A'),
                _buildResumenItem(
                    'Tipo:', _tipoNotaCredito == 'total' ? 'Total' : 'Parcial'),
                _buildResumenItem('Motivo:', _motivoSeleccionado ?? 'N/A'),
                if (_observacionesController.text.isNotEmpty)
                  _buildResumenItem(
                      'Observaciones:', _observacionesController.text),
                const Divider(),
                _buildResumenItem(
                  'Monto total de la factura:',
                  '\$${(_facturaSeleccionada!['total'] as num).toStringAsFixed(2)}',
                  isAmount: true,
                ),
                _buildResumenItem(
                  'Monto en Bs:',
                  'Bs ${((_facturaSeleccionada!['total'] as num).toDouble() * ((_facturaSeleccionada!['tasa_usd'] as num?)?.toDouble() ?? 36.50)).toStringAsFixed(2)}',
                  isAmount: true,
                ),
                _buildResumenItem(
                  'Monto a devolver:',
                  '\$${(_facturaSeleccionada!['total'] as num).toStringAsFixed(2)}',
                  isAmount: true,
                  isTotal: true,
                ),
                _buildResumenItem(
                  'Monto Bs:',
                  'Bs ${((_facturaSeleccionada!['total'] as num).toDouble() * ((_facturaSeleccionada!['tasa_usd'] as num?)?.toDouble() ?? 36.50)).toStringAsFixed(2)}',
                  isAmount: true,
                  isTotal: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '⚠️ Confirmación',
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange),
        ),
        const SizedBox(height: 8),
        const Text(
          'Al crear esta nota de crédito total, se devolverá el monto completo de la factura '
          'y se ajustará el inventario de todos los productos.',
          style: TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildResumenItem(String label, String value,
      {bool isAmount = false, bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: isTotal ? 18 : 14,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                color: isAmount ? Colors.green : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _calcularTotalSeleccionado() {
    double total = 0;
    for (final producto in _productosSeleccionados) {
      final productoId = producto['producto_id'] as int;
      final cantidad = _cantidadesSeleccionadas[productoId] ??
          (producto['cantidad'] as num).toDouble();
      final precio = (producto['precio_unitario'] as num).toDouble();
      total += cantidad * precio;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Nota de Crédito'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _retrocederPaso,
        ),
      ),
      body: _creandoNotaCredito
          ? const LoadingWidget(message: 'Creando nota de crédito...')
          : _errorGeneral != null
              ? error_widget.ErrorWidget(
                  error: _errorGeneral!,
                  onRetry: _crearNotaCredito,
                )
              : Stepper(
                  currentStep: _currentStep,
                  onStepContinue: _avanzarPaso,
                  onStepCancel: _retrocederPaso,
                  onStepTapped: (step) {
                    if (step < _currentStep) {
                      setState(() {
                        _currentStep = step;
                      });
                    }
                  },
                  steps: _buildSteps(),
                  controlsBuilder: (context, details) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Row(
                        children: [
                          if (details.currentStep > 0)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: details.onStepCancel,
                                child: const Text('Atrás'),
                              ),
                            ),
                          if (details.currentStep > 0) const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: details.onStepContinue,
                              child: Text(
                                details.currentStep == 2
                                    ? 'Crear'
                                    : 'Siguiente',
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
