import 'package:flutter/material.dart';
import 'package:pos_android/database/db_helper.dart';
import 'package:pos_android/services/nota_credito_service.dart';
import 'package:pos_android/models/nota_credito.dart';
import 'package:pos_android/presentation/widgets/loading_widget.dart';
import 'package:pos_android/presentation/widgets/empty_state_widget.dart';
import 'package:pos_android/presentation/widgets/error_widget.dart'
    as error_widget;
import 'create_nota_credito_screen.dart';
import 'nota_credito_detail_screen.dart';

class NotaCreditoListScreen extends StatefulWidget {
  const NotaCreditoListScreen({super.key});

  @override
  State<NotaCreditoListScreen> createState() => _NotaCreditoListScreenState();
}

class _NotaCreditoListScreenState extends State<NotaCreditoListScreen> {
  final NotaCreditoService _service = NotaCreditoService(DbHelper.instance);
  final List<NotaCredito> _notasCredito = [];
  bool _isLoading = true;
  String? _error;
  String _filterEstado = 'todos';
  String _filterTipo = 'todos';

  @override
  void initState() {
    super.initState();
    _cargarNotasCredito();
  }

  Future<void> _cargarNotasCredito() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final notas = await _service.obtenerNotasCredito(
        estado: _filterEstado != 'todos' ? _filterEstado : null,
        tipo: _filterTipo != 'todos' ? _filterTipo : null,
      );

      setState(() {
        _notasCredito.clear();
        _notasCredito.addAll(notas);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _refrescar() {
    _cargarNotasCredito();
  }

  void _filtrar() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtrar Notas de Crédito'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _filterEstado,
              decoration: const InputDecoration(labelText: 'Estado'),
              items: const [
                DropdownMenuItem(value: 'todos', child: Text('Todos')),
                DropdownMenuItem(value: 'pendiente', child: Text('Pendiente')),
                DropdownMenuItem(value: 'procesada', child: Text('Procesada')),
                DropdownMenuItem(value: 'anulada', child: Text('Anulada')),
              ],
              onChanged: (value) {
                setState(() {
                  _filterEstado = value ?? 'todos';
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _filterTipo,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: const [
                DropdownMenuItem(value: 'todos', child: Text('Todos')),
                DropdownMenuItem(value: 'total', child: Text('Total')),
                DropdownMenuItem(value: 'parcial', child: Text('Parcial')),
              ],
              onChanged: (value) {
                setState(() {
                  _filterTipo = value ?? 'todos';
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _cargarNotasCredito();
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }

  void _navegarACrearNotaCredito() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateNotaCreditoScreen(),
      ),
    ).then((_) => _refrescar());
  }

  void _verDetalle(NotaCredito notaCredito) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            NotaCreditoDetailScreen(notaCreditoId: notaCredito.id!),
      ),
    ).then((_) => _refrescar());
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notas de Crédito'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _filtrar,
            tooltip: 'Filtrar',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refrescar,
            tooltip: 'Refrescar',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _navegarACrearNotaCredito,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingWidget(message: 'Cargando notas de crédito...');
    }

    if (_error != null) {
      return error_widget.ErrorWidget(
        error: _error!,
        onRetry: _refrescar,
      );
    }

    if (_notasCredito.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.receipt_long,
        title: 'No hay notas de crédito',
        message: 'No se han creado notas de crédito aún',
        actionText: 'Crear primera nota de crédito',
        onAction: _navegarACrearNotaCredito,
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _refrescar(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _notasCredito.length,
        itemBuilder: (context, index) {
          final notaCredito = _notasCredito[index];
          return _buildNotaCreditoCard(notaCredito);
        },
      ),
    );
  }

  Widget _buildNotaCreditoCard(NotaCredito notaCredito) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _verDetalle(notaCredito),
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
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(
                      _getEstadoText(notaCredito.estado),
                      style: const TextStyle(
                        fontSize: 12,
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
                      'Factura: ${notaCredito.facturaId}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Motivo: ${notaCredito.motivo}',
                style: const TextStyle(fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Fecha: ${_formatDate(notaCredito.fechaEmision)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    'Total: \$${notaCredito.totalGeneral.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
