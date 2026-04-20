import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Servicio que monitorea el estado de la conexión a internet.
///
/// Expone:
/// - [isOnline]       → Estado actual (síncrono).
/// - [onConnected]    → Stream que emite cada vez que se recupera la conexión.
///
/// Uso típico: el SyncManager escucha [onConnected] para disparar
/// la sincronización automáticamente cuando vuelve el internet.
class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService._init();
  ConnectivityService._init();

  final Connectivity _connectivity = Connectivity();

  bool _isOnline = false;
  bool get isOnline => _isOnline;

  // Controlador del stream público de "conexión recuperada"
  final StreamController<void> _connectedController =
      StreamController<void>.broadcast();

  /// Stream que emite un evento cada vez que el dispositivo recupera internet.
  Stream<void> get onConnected => _connectedController.stream;

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Inicializa el servicio y comienza a escuchar cambios de conectividad.
  /// Llamar una sola vez desde main() o al iniciar la app.
  Future<void> initialize() async {
    // Verificar estado inicial
    final results = await _connectivity.checkConnectivity();
    _isOnline = _hasInternet(results);
    debugPrint('🌐 Conectividad inicial: ${_isOnline ? "Online" : "Offline"}');

    // Escuchar cambios en tiempo real
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final wasOnline = _isOnline;
      _isOnline = _hasInternet(results);

      if (!wasOnline && _isOnline) {
        // Transición Offline → Online: notificar para disparar sync
        debugPrint('🌐 Conexión recuperada → disparando sincronización');
        _connectedController.add(null);
      }

      debugPrint('🌐 Estado de red: ${_isOnline ? "Online" : "Offline"}');
    });
  }

  /// Verifica si alguno de los resultados indica conexión real.
  bool _hasInternet(List<ConnectivityResult> results) {
    return results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet);
  }

  /// Liberar recursos al cerrar la app.
  void dispose() {
    _subscription?.cancel();
    _connectedController.close();
  }
}
