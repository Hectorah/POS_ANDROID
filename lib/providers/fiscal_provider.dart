import 'package:flutter/material.dart';
import '../models/fiscal_models.dart';
import '../services/fiscal_service.dart';

class FiscalProvider with ChangeNotifier {
  SesionFiscal? _sesionActual;
  bool _isLoading = false;

  SesionFiscal? get sesionActual => _sesionActual;
  bool get isLoading => _isLoading;
  bool get haySesionAbierta => _sesionActual != null && _sesionActual!.estado == EstadoSesionFiscal.abierta;

  FiscalProvider() {
    inicializar();
  }

  Future<void> inicializar() async {
    _isLoading = true;
    _sesionActual = await FiscalService.instance.obtenerSesionActual();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> abrirSesion(int usuarioId, String usuarioNombre, {double fondoCajaInicial = 0.0}) async {
    _isLoading = true;
    notifyListeners();
    try {
      _sesionActual = await FiscalService.instance.abrirSesion(usuarioId, usuarioNombre, fondoCajaInicial: fondoCajaInicial);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> registrarGasto(String concepto, double monto, String tipo, {String? comprobante, String? autorizado}) async {
    throw UnimplementedError('Registro de gastos eliminado');
  }

  Future<ArqueoCaja> realizarArqueo({
    required int usuarioId,
    required String usuarioNombre,
    required ConteoEfectivo conteo,
    required double totalTarjetaDeclarado,
    required double totalPagoMovilDeclarado,
    required double totalOtrosDeclarado,
    String? observaciones,
  }) async {
    if (_sesionActual == null) throw Exception('No hay sesión activa');
    
    _isLoading = true;
    notifyListeners();
    try {
      final arqueo = await FiscalService.instance.realizarArqueo(
        sesionId: _sesionActual!.id!,
        usuarioId: usuarioId,
        usuarioNombre: usuarioNombre,
        conteo: conteo,
        totalTarjetaDeclarado: totalTarjetaDeclarado,
        totalPagoMovilDeclarado: totalPagoMovilDeclarado,
        totalOtrosDeclarado: totalOtrosDeclarado,
        observaciones: observaciones,
      );
      
      // Actualizar sesión actual en memoria
      await inicializar(); 
      
      return arqueo;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ReporteCierre> cerrarSesion(int usuarioId, String usuarioNombre) async {
    _isLoading = true;
    notifyListeners();
    try {
      final reporte = await FiscalService.instance.cerrarSesion(usuarioId, usuarioNombre);
      _sesionActual = null; // Posterior al cierre, queda inactiva
      return reporte;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
