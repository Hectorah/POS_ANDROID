import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para obtener y actualizar tasas de cambio
class ExchangeRateService {
  // URLs de APIs de tasas de cambio
  static const String apiTasasUrlUSD = 'https://api.exchangerate-api.com/v4/latest/USD';
  static const String apiTasasUrlEUR = 'https://api.exchangerate-api.com/v4/latest/EUR';
  static const String apiTasasUrlCOP = 'https://api.exchangerate-api.com/v4/latest/COP';

  /// Actualizar todas las tasas desde la API
  static Future<bool> updateRates() async {
    try {
      debugPrint('💱 Actualizando tasas de cambio...');
      
      final tasas = await _obtenerTodasLasTasas();
      
      if (tasas.isEmpty) {
        debugPrint('⚠️ No se pudieron obtener tasas, usando valores guardados');
        return false;
      }

      // Guardar en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      
      if (tasas['USD'] != null) {
        await prefs.setDouble('tasa_usd', tasas['USD']!);
        debugPrint('✅ Tasa USD actualizada: \$1 = Bs. ${tasas['USD']!.toStringAsFixed(2)}');
      }
      
      if (tasas['EUR'] != null) {
        await prefs.setDouble('tasa_eur', tasas['EUR']!);
        debugPrint('✅ Tasa EUR actualizada: €1 = Bs. ${tasas['EUR']!.toStringAsFixed(2)}');
      }
      
      if (tasas['COP'] != null) {
        await prefs.setDouble('tasa_cop', tasas['COP']!);
        debugPrint('✅ Tasa COP actualizada: \$1 COP = Bs. ${tasas['COP']!.toStringAsFixed(4)}');
      }

      // Guardar timestamp de última actualización
      await prefs.setString('last_rate_update', DateTime.now().toIso8601String());
      
      return true;
    } catch (e) {
      debugPrint('❌ Error actualizando tasas: $e');
      return false;
    }
  }

  /// Obtener todas las tasas desde las APIs
  static Future<Map<String, double>> _obtenerTodasLasTasas() async {
    final tasas = <String, double>{};
    
    try {
      // 1. Obtener tasa USD a VES
      try {
        final responseUSD = await http.get(Uri.parse(apiTasasUrlUSD)).timeout(
          const Duration(seconds: 10),
        );
        if (responseUSD.statusCode == 200) {
          final dataUSD = jsonDecode(responseUSD.body);
          final tasaUsdVes = (dataUSD['rates']['VES'] as num?)?.toDouble() ?? 0.0;
          if (tasaUsdVes > 0) {
            tasas['USD'] = tasaUsdVes;
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error obteniendo tasa USD: $e');
      }
      
      // 2. Obtener tasa EUR a VES
      try {
        final responseEUR = await http.get(Uri.parse(apiTasasUrlEUR)).timeout(
          const Duration(seconds: 10),
        );
        if (responseEUR.statusCode == 200) {
          final dataEUR = jsonDecode(responseEUR.body);
          final tasaEurVes = (dataEUR['rates']['VES'] as num?)?.toDouble() ?? 0.0;
          if (tasaEurVes > 0) {
            tasas['EUR'] = tasaEurVes;
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error obteniendo tasa EUR: $e');
      }
      
      // 3. Obtener tasa COP a VES
      try {
        final responseCOP = await http.get(Uri.parse(apiTasasUrlCOP)).timeout(
          const Duration(seconds: 10),
        );
        if (responseCOP.statusCode == 200) {
          final dataCOP = jsonDecode(responseCOP.body);
          final tasaCopVes = (dataCOP['rates']['VES'] as num?)?.toDouble() ?? 0.0;
          if (tasaCopVes > 0) {
            tasas['COP'] = tasaCopVes;
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error obteniendo tasa COP: $e');
      }
    } catch (e) {
      debugPrint('❌ Error general obteniendo tasas: $e');
    }
    
    return tasas;
  }

  /// Verificar si las tasas necesitan actualizarse (más de 24 horas)
  static Future<bool> needsUpdate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdate = prefs.getString('last_rate_update');
      
      if (lastUpdate == null) {
        return true; // Nunca se han actualizado
      }
      
      final lastUpdateDate = DateTime.parse(lastUpdate);
      final now = DateTime.now();
      final difference = now.difference(lastUpdateDate);
      
      // Actualizar si han pasado más de 24 horas
      return difference.inHours >= 24;
    } catch (e) {
      return true; // En caso de error, intentar actualizar
    }
  }

  /// Obtener la última fecha de actualización
  static Future<DateTime?> getLastUpdateDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdate = prefs.getString('last_rate_update');
      
      if (lastUpdate != null) {
        return DateTime.parse(lastUpdate);
      }
    } catch (e) {
      debugPrint('Error obteniendo fecha de actualización: $e');
    }
    return null;
  }
}
