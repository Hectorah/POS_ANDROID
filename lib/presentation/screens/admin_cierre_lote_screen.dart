import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../database/db_helper.dart';
import '../../services/ubii_pos_service.dart';
import '../widgets/custom_snackbar.dart';

/// Pantalla de administración para realizar cierre de lote
class AdminCierreLoteScreen extends StatefulWidget {
  const AdminCierreLoteScreen({super.key});

  @override
  State<AdminCierreLoteScreen> createState() => _AdminCierreLoteScreenState();
}

class _AdminCierreLoteScreenState extends State<AdminCierreLoteScreen> {
  final UbiiPosService _ubiiService = UbiiPosService();
  
  bool _isProcessing = false;
  bool _isLoading = true;
  Map<String, dynamic>? _ultimoCierre;
  List<Map<String, dynamic>> _historialCierres = [];
  Map<String, dynamic>? _estadisticas;
  bool _yaSeHizoCierreHoy = false;
  Map<String, dynamic>? _totalesDelDia;
  double _tasaUsd = 1.0;
  bool _selectedQuick = false;

  final _currencyFormat = NumberFormat.currency(
    locale: 'es_VE',
    symbol: 'Bs. ',
    decimalDigits: 2,
  );

  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  /// Cargar todos los datos necesarios
  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    
    try {
      // Cargar datos en paralelo
      final futures = await Future.wait([
        DbHelper.instance.obtenerUltimoCierre(),
        DbHelper.instance.obtenerCierresLote(limit: 10),
        DbHelper.instance.obtenerEstadisticasCierres(),
        DbHelper.instance.yaSeHizoCierreHoy(),
        DbHelper.instance.obtenerTotalesDelDia(),
      ]);

      final prefs = await SharedPreferences.getInstance();
      final tasaGuardada = prefs.getDouble('tasa_usd') ?? 1.0;

      setState(() {
        _ultimoCierre = futures[0] as Map<String, dynamic>?;
        _historialCierres = futures[1] as List<Map<String, dynamic>>;
        _estadisticas = futures[2] as Map<String, dynamic>;
        _yaSeHizoCierreHoy = futures[3] as bool;
        _totalesDelDia = futures[4] as Map<String, dynamic>;
        _tasaUsd = tasaGuardada > 0 ? tasaGuardada : 1.0;
        _isLoading = false;
      });
      
      debugPrint('✅ Datos de cierre cargados');
      debugPrint('   Último cierre: ${_ultimoCierre?['fecha_creacion']}');
      debugPrint('   Historial: ${_historialCierres.length} cierres');
      debugPrint('   Ya se hizo cierre hoy: $_yaSeHizoCierreHoy');
    } catch (e) {
      debugPrint('❌ Error cargando datos: $e');
      setState(() => _isLoading = false);
      await _mostrarError(
        'Error al cargar los datos de cierre de lote',
        detalles: 'Error: $e',
      );
    }
  }

  /// Realizar el cierre de lote
  Future<void> _realizarCierre() async {
    if (_yaSeHizoCierreHoy) {
      _mostrarAlerta('Ya se realizó el cierre de lote hoy');
      return;
    }

    final confirmar = await _mostrarDialogoConfirmacion();
    if (!confirmar) return;

    setState(() => _isProcessing = true);

    try {
      debugPrint('🔒 Lanzando cierre de lote...');

      final resultado = await _ubiiService.cerrarLoteDelDia(quick: _selectedQuick);

      if (resultado == null) {
        await _mostrarError('No se pudo lanzar el cierre en Ubii POS');
        return;
      }

      if (resultado['code'] == 'LAUNCHED') {
        // Registrar cierre localmente con datos mínimos
        await DbHelper.instance.registrarCierreLote(
          usuarioId: 1,
          tipoCierre: _selectedQuick ? 'Q' : 'N',
          ubiiData: {
            'code': '00',
            'message': 'Cierre lanzado',
            'terminal': '',
            'lote': '',
            'date': DateTime.now().toIso8601String(),
            'time': '',
          },
        );

        await _ubiiService.guardarFechaCierre();
        await _cargarDatos();

        if (mounted) {
          CustomSnackBar.success(context, 'Cierre enviado a Ubii — revisa el comprobante en el POS');
        }
      } else {
        await _mostrarError(
          'Error al lanzar el cierre',
          detalles: 'Código: ${resultado['code']}\nMensaje: ${resultado['message']}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error en cierre de lote: $e');
      await _mostrarError('Ocurrió un error al procesar el cierre de lote', detalles: 'Error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// Mostrar diálogo de confirmación
  Future<bool> _mostrarDialogoConfirmacion() async {
    bool quickSelected = false; // false = N (diferido), true = Q (inmediato)

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange, size: 32),
              SizedBox(width: 12),
              Text('Confirmar Cierre'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿Estás seguro de realizar el cierre de lote?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const Text(
                'Tipo de liquidación:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              RadioListTile<bool>(
                value: false,
                groupValue: quickSelected,
                onChanged: (v) => setDialogState(() => quickSelected = v!),
                title: const Text('Diferida (N)'),
                subtitle: const Text('Se procesa el siguiente día hábil'),
                contentPadding: EdgeInsets.zero,
              ),
              RadioListTile<bool>(
                value: true,
                groupValue: quickSelected,
                onChanged: (v) => setDialogState(() => quickSelected = v!),
                title: const Text('Inmediata (Q)'),
                subtitle: const Text('El banco procesa esta misma noche'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Confirmar Cierre', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        _selectedQuick = quickSelected;
      }
      return confirmed ?? false;
    });
  }

  Future<void> _mostrarError(String mensaje, {String? detalles}) async {
    await ErrorDialog.show(
      context,
      title: 'Error en Cierre de Lote',
      message: mensaje,
      errorCode: ErrorCodes.ubiiCierre,
      technicalDetails: detalles,
    );
  }

  void _mostrarAlerta(String mensaje) {
    CustomSnackBar.warning(context, mensaje);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cierre de Lote'),
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
      ),
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Estado actual
                  _buildEstadoCard(isDark),
                  const SizedBox(height: 16),
                  
                  // Botón principal
                  _buildBotonCierre(isDark),
                  const SizedBox(height: 24),
                  
                  // Último cierre
                  if (_ultimoCierre != null) ...[
                    _buildUltimoCierreCard(isDark),
                    const SizedBox(height: 16),
                  ],
                  
                  // Estadísticas
                  if (_estadisticas != null) ...[
                    _buildEstadisticasCard(isDark),
                    const SizedBox(height: 16),
                  ],
                  
                  // Historial
                  _buildHistorialCard(isDark),
                ],
              ),
            ),
    );
  }

  Widget _buildEstadoCard(bool isDark) {
    final Color cardColor;
    final Color iconColor;
    final String estado;
    final String descripcion;
    
    if (_yaSeHizoCierreHoy) {
      cardColor = Colors.green.shade50;
      iconColor = Colors.green;
      estado = 'Cierre Realizado';
      descripcion = 'El cierre de lote ya fue realizado hoy';
    } else {
      final ahora = DateTime.now();
      if (ahora.hour >= 19) { // Después de las 7 PM
        cardColor = Colors.orange.shade50;
        iconColor = Colors.orange;
        estado = 'Cierre Pendiente';
        descripcion = 'Es hora de realizar el cierre de lote';
      } else {
        cardColor = Colors.blue.shade50;
        iconColor = Colors.blue;
        estado = 'Operaciones Normales';
        descripcion = 'Cierre disponible después de las 7:00 PM';
      }
    }
    
    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              _yaSeHizoCierreHoy ? Icons.check_circle : Icons.schedule,
              color: iconColor,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    estado,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    descripcion,
                    style: TextStyle(
                      fontSize: 14,
                      color: iconColor.withValues(alpha:0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotonCierre(bool isDark) {
    final bool habilitado = !_yaSeHizoCierreHoy && !_isProcessing;
    
    return ElevatedButton.icon(
      onPressed: habilitado ? _realizarCierre : null,
      icon: _isProcessing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.receipt_long),
      label: Text(
        _isProcessing
            ? 'PROCESANDO CIERRE...'
            : _yaSeHizoCierreHoy
                ? 'CIERRE YA REALIZADO HOY'
                : 'REALIZAR CIERRE DE LOTE',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: habilitado ? Colors.orange : Colors.grey,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildUltimoCierreCard(bool isDark) {
    final cierre = _ultimoCierre!;
    final fecha = DateTime.parse(cierre['fecha_creacion']);
    final montoUsd = (cierre['monto_total'] as num?)?.toDouble() ?? 0.0;
    final montoBs = montoUsd * _tasaUsd;

    return Card(
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: isDark ? AppColors.darkText : AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Último Cierre',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Fecha', _dateFormat.format(fecha), isDark),
            _buildInfoRow('Terminal', cierre['ubii_terminal'] ?? 'N/A', isDark),
            _buildInfoRow('Transacciones', '${cierre['total_transacciones'] ?? 0}', isDark),
            _buildInfoRow('Monto (Bs)', _currencyFormat.format(montoBs), isDark),
            _buildInfoRow('Usuario', cierre['usuario_nombre'] ?? 'N/A', isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadisticasCard(bool isDark) {
    final stats = _estadisticas!;
    final totales = _totalesDelDia;
    final montoHoy = (totales?['total_usd'] as num?)?.toDouble() ?? 0.0;
    final montoHoyBs = montoHoy * _tasaUsd;

    return Card(
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: isDark ? AppColors.darkText : AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Estadísticas Generales',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Cierres',
                    '${stats['total_cierres'] ?? 0}',
                    Icons.receipt,
                    Colors.blue,
                    isDark,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatItem(
                    'Monto total del día (Bs)',
                    _currencyFormat.format(montoHoyBs),
                    Icons.attach_money,
                    Colors.green,
                    isDark,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHistorialCard(bool isDark) {
    return Card(
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.list,
                  color: isDark ? AppColors.darkText : AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Historial de Cierres',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_historialCierres.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.inbox,
                        size: 48,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay cierres registrados',
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _historialCierres.length,
                separatorBuilder: (context, index) => Divider(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
                itemBuilder: (context, index) {
                  final cierre = _historialCierres[index];
                  final fecha = DateTime.parse(cierre['fecha_creacion']);
                  final esExitoso = cierre['ubii_response_code'] == '00';
                  
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: esExitoso ? Colors.green.withValues(alpha:0.1) : Colors.red.withValues(alpha:0.1),
                      child: Icon(
                        esExitoso ? Icons.check : Icons.error,
                        color: esExitoso ? Colors.green : Colors.red,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Lote ${cierre['ubii_lote'] ?? 'N/A'}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _dateFormat.format(fecha),
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                        Text(
                          '${cierre['total_transacciones'] ?? 0} transacciones',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    trailing: Text(
                      _currencyFormat.format(((cierre['monto_total'] as num?)?.toDouble() ?? 0.0) * _tasaUsd),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}