import 'package:shared_preferences/shared_preferences.dart';

/// Servicio de configuración para acceder a valores guardados
class ConfigService {
  // Valores por defecto
  static double tasaUSD = 36.50;
  static double tasaEUR = 40.00;
  static double tasaCOP = 0.012;
  static String serverUrl = 'https://api.ejemplo.com';

  /// Cargar configuración guardada
  static Future<void> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Cargar URL
      serverUrl = prefs.getString('server_url') ?? 'https://api.ejemplo.com';
      
      // Cargar tasas
      tasaUSD = prefs.getDouble('tasa_usd') ?? 36.50;
      tasaEUR = prefs.getDouble('tasa_eur') ?? 40.00;
      tasaCOP = prefs.getDouble('tasa_cop') ?? 0.012;
    } catch (e) {
      // Si falla, usar valores por defecto
    }
  }

  /// Guardar configuración
  static Future<void> saveConfig({
    String? url,
    double? usd,
    double? eur,
    double? cop,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (url != null) {
        serverUrl = url;
        await prefs.setString('server_url', url);
      }
      
      if (usd != null) {
        tasaUSD = usd;
        await prefs.setDouble('tasa_usd', usd);
      }
      
      if (eur != null) {
        tasaEUR = eur;
        await prefs.setDouble('tasa_eur', eur);
      }
      
      if (cop != null) {
        tasaCOP = cop;
        await prefs.setDouble('tasa_cop', cop);
      }
    } catch (e) {
      // Error al guardar
    }
  }
}
