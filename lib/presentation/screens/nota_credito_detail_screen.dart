import 'package:flutter/material.dart';
import 'package:pos_android/database/db_helper.dart';
import 'package:pos_android/services/nota_credito_service.dart';
import 'package:pos_android/services/nota_credito_printer.dart';
import 'package:pos_android/presentation/widgets/loading_widget.dart';
import 'package:pos_android/presentation/widgets/error_widget.dart'
    as error_widget;

class NotaCreditoDetailScreen extends StatefulWidget {
  final int notaCreditoId;

  const NotaCreditoDetailScreen({super.key, required this.notaCreditoId});

  @override
  State<NotaCreditoDetailScreen> createState() =>
      _NotaCreditoDetailScreenState();
}

class _NotaCreditoDetailScreenState extends State<NotaCreditoDetailScreen> {
  final NotaCreditoService _service = NotaCreditoService(DbHelper.instance);
  Map<String, dynamic>? _notaCreditoCompleta;
  bool _isLoading = true;
  String? _error;
  bool _imprimiendo = false;

  @override
  void initState() {
    super.initState();
    _cargarDetalle();
  }

  Future<void> _cargarDetalle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final detalle =
          await _service.obtenerNotaCreditoCompleta(widget.notaCreditoId);

      setState(() {
        _notaCreditoCompleta = detalle;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }



  Future<void> _imprimirNotaCredito() async {
    if (_notaCreditoCompleta == null) return;

    setState(() {
      _imprimiendo = true;
    });

    try {
      final notaCredito = _notaCreditoCompleta!['nota_credito'];
      final detalles =
          _notaCreditoCompleta!['detalles'] as List<Map<String, dynamic>>;
      final factura = _notaCreditoCompleta!['factura'] as Map<String, dynamic>;
      final cliente = _notaCreditoCompleta!['cliente'] as Map<String, dynamic>;

      // Obtener tasa de cambio real de la factura original
      // La NC debe reflejar los mismos montos exactos de la factura
      final tasaCambio = (factura['tasa_usd'] as num?)?.toDouble() ?? 36.50;

      final success = await NotaCreditoPrinter.printNotaCredito(
        notaCredito: notaCredito,
        detallesConProducto: detalles,
        factura: factura,
        cliente: cliente,
        tasaCambio: tasaCambio,
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nota de crédito enviada a impresión'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al imprimir nota de crédito'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error imprimiendo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _imprimiendo = false;
        });
      }
    }
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'pendiente':
        return Colors.orange;
      case 'procesada':
        return Colors.green;
      case 'anulada':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getEstadoText(String estado) {
    switch (estado) {
      case 'pendiente':
        return 'Pendiente';
      case 'procesada':
        return 'Procesada';
      case 'anulada':
        return 'Anulada';
      default:
        return estado;
    }
  }

  String _getTipoText(String tipo) {
    switch (tipo) {
      case 'total':
        return 'Total';
      case 'parcial':
        return 'Parcial';
      default:
        return tipo;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle Nota de Crédito'),
        actions: [
          if (_notaCreditoCompleta != null &&
              _notaCreditoCompleta!['nota_credito'].estado != 'anulada')
            IconButton(
              icon: _imprimiendo
                  ? const CircularProgressIndicator(strokeWidth: 2)
                  : const Icon(Icons.print),
              onPressed: _imprimiendo ? null : _imprimirNotaCredito,
              tooltip: 'Imprimir',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingWidget(message: 'Cargando detalle...');
    }

    if (_error != null) {
      return error_widget.ErrorWidget(
        error: _error!,
        onRetry: _cargarDetalle,
      );
    }

    if (_notaCreditoCompleta == null) {
      return const Center(
        child: Text('No se encontró la nota de crédito'),
      );
    }

    final notaCredito = _notaCreditoCompleta!['nota_credito'];
    final detalles =
        _notaCreditoCompleta!['detalles'] as List<Map<String, dynamic>>;
    final factura = _notaCreditoCompleta!['factura'] as Map<String, dynamic>;
    final cliente = _notaCreditoCompleta!['cliente'] as Map<String, dynamic>;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(notaCredito, factura, cliente),
          const SizedBox(height: 16),
          _buildDetallesCard(notaCredito, detalles),
          const SizedBox(height: 16),
          _buildTotalesCard(notaCredito, factura),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(notaCredito, factura, cliente) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    notaCredito.numeroControl,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    _getEstadoText(notaCredito.estado),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  backgroundColor: _getEstadoColor(notaCredito.estado),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Chip(
                  label: Text(
                    _getTipoText(notaCredito.tipo),
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: Colors.blue.shade100,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Factura: ${factura['numero_control'] ?? 'N/A'}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Información del Cliente',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildInfoItem('Nombre:', cliente['nombre']?.toString() ?? 'N/A'),
            _buildInfoItem(
                'RIF:', cliente['identificacion']?.toString() ?? 'N/A'),
            if (cliente['direccion'] != null)
              _buildInfoItem(
                  'Dirección:', cliente['direccion']?.toString() ?? ''),
            if (cliente['telefono'] != null)
              _buildInfoItem(
                  'Teléfono:', cliente['telefono']?.toString() ?? ''),
            const SizedBox(height: 16),
            const Text(
              'Información de la Nota',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildInfoItem('Motivo:', notaCredito.motivo),
            if (notaCredito.observaciones != null &&
                notaCredito.observaciones!.isNotEmpty)
              _buildInfoItem('Observaciones:', notaCredito.observaciones!),
            _buildInfoItem('Fecha Emisión:',
                _formatDate(notaCredito.fechaEmision.toIso8601String())),
            if (notaCredito.fechaAnulacion != null)
              _buildInfoItem('Fecha Anulación:',
                  _formatDate(notaCredito.fechaAnulacion!.toIso8601String())),
            if (notaCredito.motivoAnulacion != null)
              _buildInfoItem('Motivo Anulación:', notaCredito.motivoAnulacion!),
          ],
        ),
      ),
    );
  }

  Widget _buildDetallesCard(notaCredito, List<Map<String, dynamic>> detalles) {
    if (notaCredito.esTotal || detalles.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Productos Devueltos',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                notaCredito.esTotal
                    ? 'Devolución total de todos los productos de la factura'
                    : 'No hay detalles de productos',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Productos Devueltos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...detalles.map((detalle) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detalle['producto_nombre'] as String,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Código: ${detalle['cod_articulo']}',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          'Unidad: ${detalle['unidad_medida']}',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Cantidad: ${(detalle['cantidad'] as num).toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        Text(
                          'Precio: \$${(detalle['precio_unitario'] as num).toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (detalle['lote'] != null)
                          Text(
                            'Lote: ${detalle['lote']}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        if (detalle['serial'] != null)
                          Text(
                            'Serial: ${detalle['serial']}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                    const Divider(),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalesCard(notaCredito, Map<String, dynamic> factura) {
    final tasaCambio = (factura['tasa_usd'] as num?)?.toDouble() ?? 36.50;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Totales',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildTotalItem('Base Imponible:', notaCredito.montoTotal),
            _buildTotalItemBs('', notaCredito.montoTotal * tasaCambio),
            const SizedBox(height: 4),
            _buildTotalItem('IVA 16%:', notaCredito.iva),
            _buildTotalItemBs('', notaCredito.iva * tasaCambio),
            const Divider(),
            _buildTotalItem(
              'Total Devolución:',
              notaCredito.totalGeneral,
              isTotal: true,
            ),
            _buildTotalItemBs(
              'Total Bs:',
              notaCredito.totalGeneral * tasaCambio,
              isTotal: true,
            ),
            const SizedBox(height: 8),
            Text(
              'Tasa BCV: ${tasaCambio.toStringAsFixed(2)} Bs/\$',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalItem(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.green : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalItemBs(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 14 : 12,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            'Bs ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 16 : 12,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: Colors.blueGrey,
            ),
          ),
        ],
      ),
    );
  }
}
