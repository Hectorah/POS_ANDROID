import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para obtener y actualizar tasas de cambio
class ExchangeRateService {
  // URLs de APIs de tasas de cambio - API más confiable
  static const String apiTasasUrl =
      'https://api.exchangerate-api.com/v4/latest/USD';

  // Tasas por defecto (en caso de que la API falle)
  static const Map<String, double> defaultRates = {
    'USD': 36.50, // 1 USD = 36.50 Bs.
    'EUR': 40.00, // 1 EUR = 40.00 Bs.
    'COP': 0.012, // 1 COP = 0.012 Bs.
  };

  /// Actualizar todas las tasas desde la API
  static Future<bool> updateRates() async {
    try {
      debugPrint('💱 Actualizando tasas de cambio...');

      final tasas = await _obtenerTodasLasTasas();

      // Si no se obtuvieron tasas, usar valores por defecto
      if (tasas.isEmpty) {
        debugPrint(
            '⚠️ No se pudieron obtener tasas de la API, usando valores por defecto');
        return await _saveDefaultRates();
      }

      // Guardar en SharedPreferences
      final prefs = await SharedPreferences.getInstance();

      // Usar tasas obtenidas o valores por defecto
      final usdRate = tasas['USD'] ?? defaultRates['USD']!;
      final eurRate = tasas['EUR'] ?? defaultRates['EUR']!;
      final copRate = tasas['COP'] ?? defaultRates['COP']!;

      await prefs.setDouble('tasa_usd', usdRate);
      await prefs.setDouble('tasa_eur', eurRate);
      await prefs.setDouble('tasa_cop', copRate);

      debugPrint(
          '✅ Tasa USD actualizada: \$1 = Bs. ${usdRate.toStringAsFixed(2)}');
      debugPrint(
          '✅ Tasa EUR actualizada: €1 = Bs. ${eurRate.toStringAsFixed(2)}');
      debugPrint(
          '✅ Tasa COP actualizada: \$1 COP = Bs. ${copRate.toStringAsFixed(4)}');

      // Guardar timestamp de última actualización
      await prefs.setString(
          'last_rate_update', DateTime.now().toIso8601String());

      return true;
    } catch (e) {
      debugPrint('❌ Error actualizando tasas: $e');
      // En caso de error, guardar tasas por defecto
      return await _saveDefaultRates();
    }
  }

  /// Guardar tasas por defecto
  static Future<bool> _saveDefaultRates() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setDouble('tasa_usd', defaultRates['USD']!);
      await prefs.setDouble('tasa_eur', defaultRates['EUR']!);
      await prefs.setDouble('tasa_cop', defaultRates['COP']!);

      debugPrint('📊 Usando tasas por defecto:');
      debugPrint(
          '   USD: \$1 = Bs. ${defaultRates['USD']!.toStringAsFixed(2)}');
      debugPrint('   EUR: €1 = Bs. ${defaultRates['EUR']!.toStringAsFixed(2)}');
      debugPrint(
          '   COP: \$1 = Bs. ${defaultRates['COP']!.toStringAsFixed(4)}');

      return true;
    } catch (e) {
      debugPrint('❌ Error guardando tasas por defecto: $e');
      return false;
    }
  }

  /// Obtener todas las tasas desde la API
  static Future<Map<String, double>> _obtenerTodasLasTasas() async {
    final tasas = <String, double>{};

    try {
      debugPrint('🌐 Conectando a API de tasas de cambio...');

      final response = await http.get(Uri.parse(apiTasasUrl)).timeout(
            const Duration(seconds: 15),
          );

      if (response.statusCode != 200) {
        debugPrint('⚠️ API respondió con código: ${response.statusCode}');
        return tasas;
      }

      final data = jsonDecode(response.body);
      final rates = data['rates'] as Map<String, dynamic>;

      debugPrint('📊 Monedas disponibles en API: ${rates.length}');

      // Estrategia 1: Buscar VES directamente
      final vesRate = (rates['VES'] as num?)?.toDouble();
      if (vesRate != null && vesRate > 0) {
        debugPrint('✅ Tasa VES directa encontrada: $vesRate');
        // Si tenemos VES directamente, calcular otras tasas
        tasas['USD'] = vesRate; // 1 USD = X VES

        // Calcular EUR usando tasa USD/EUR
        final eurRate = (rates['EUR'] as num?)?.toDouble();
        if (eurRate != null && eurRate > 0) {
          tasas['EUR'] =
              vesRate * eurRate; // 1 EUR = (1 USD en VES) * (EUR/USD)
        }

        // Calcular COP usando tasa USD/COP
        final copRate = (rates['COP'] as num?)?.toDouble();
        if (copRate != null && copRate > 0) {
          tasas['COP'] =
              vesRate / copRate; // 1 COP = (1 USD en VES) / (COP/USD)
        }
      }
      // Estrategia 2: Si no hay VES, usar monedas intermedias
      else {
        debugPrint('⚠️ VES no disponible en API, usando cálculo indirecto');

        // Buscar monedas latinoamericanas como referencia
        // final referenceCurrencies = {
        //   'COP': 'Colombian Peso',
        //   'MXN': 'Mexican Peso',
        //   'BRL': 'Brazilian Real',
        //   'ARS': 'Argentine Peso',
        //   'CLP': 'Chilean Peso',
        // };

        // Usar COP como referencia principal (más estable)
        final copRate = (rates['COP'] as num?)?.toDouble();
        if (copRate != null && copRate > 0) {
          // Estimación: 1 USD = 36.50 Bs. (VES) = 3747.64 COP (de la API)
          // Entonces: 1 COP = 36.50 / 3747.64 ≈ 0.00974 Bs.
          tasas['COP'] = 36.50 / copRate;
          tasas['USD'] = 36.50; // Valor estimado
          tasas['EUR'] = 40.00; // Valor estimado

          debugPrint(
              '💰 Usando COP como referencia: 1 COP = ${tasas['COP']!.toStringAsFixed(6)} Bs.');
        } else {
          debugPrint(
              '⚠️ No se pudo obtener referencia, usando valores por defecto');
          return {}; // Retornar vacío para usar valores por defecto
        }
      }

      // Validar que las tasas sean razonables
      _validateRates(tasas);
    } catch (e) {
      debugPrint('❌ Error obteniendo tasas: $e');
      debugPrint('   Tipo de error: ${e.runtimeType}');
      if (e is http.ClientException) {
        debugPrint('   Error de conexión HTTP');
      }
    }

    return tasas;
  }

  /// Validar que las tasas sean razonables
  static void _validateRates(Map<String, double> rates) {
    final validRates = <String, double>{};

    for (final entry in rates.entries) {
      final currency = entry.key;
      final rate = entry.value;

      // Validar rango razonable
      bool isValid = false;

      switch (currency) {
        case 'USD':
          isValid = rate > 1 && rate < 1000; // Entre 1 y 1000 Bs. por USD
          break;
        case 'EUR':
          isValid = rate > 1 && rate < 1000; // Entre 1 y 1000 Bs. por EUR
          break;
        case 'COP':
          isValid = rate > 0.0001 && rate < 1; // Entre 0.0001 y 1 Bs. por COP
          break;
        default:
          isValid = rate > 0;
      }

      if (isValid) {
        validRates[currency] = rate;
        debugPrint('   ✅ $currency: $rate (válido)');
      } else {
        debugPrint(
            '   ⚠️ $currency: $rate (fuera de rango, usando valor por defecto)');
      }
    }

    rates.clear();
    rates.addAll(validRates);
  }

  /// Verificar si las tasas necesitan actualizarse
  static Future<bool> needsUpdate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdate = prefs.getString('last_rate_update');

      if (lastUpdate == null) {
        debugPrint('📅 Nunca se han actualizado las tasas');
        return true;
      }

      final lastUpdateDate = DateTime.parse(lastUpdate);
      final now = DateTime.now();
      final difference = now.difference(lastUpdateDate);

      // Actualizar si han pasado más de 12 horas (más frecuente)
      final needsUpdate = difference.inHours >= 12;

      if (needsUpdate) {
        debugPrint('📅 Última actualización: hace ${difference.inHours} horas');
      } else {
        debugPrint(
            '📅 Tasas actualizadas hace ${difference.inHours} horas (OK)');
      }

      return needsUpdate;
    } catch (e) {
      debugPrint('⚠️ Error verificando necesidad de actualización: $e');
      return true;
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

  /// Forzar actualización de tasas (para uso manual)
  static Future<bool> forceUpdate() async {
    debugPrint('🔄 Forzando actualización de tasas...');
    return await updateRates();
  }

  /// Obtener tasas actuales (de cache o por defecto)
  static Future<Map<String, double>> getCurrentRates() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final usd = prefs.getDouble('tasa_usd') ?? defaultRates['USD']!;
      final eur = prefs.getDouble('tasa_eur') ?? defaultRates['EUR']!;
      final cop = prefs.getDouble('tasa_cop') ?? defaultRates['COP']!;

      return {
        'USD': usd,
        'EUR': eur,
        'COP': cop,
      };
    } catch (e) {
      debugPrint('Error obteniendo tasas actuales: $e');
      return Map.from(defaultRates);
    }
  }

  /// Mostrar estado actual de las tasas
  static Future<void> showCurrentStatus() async {
    try {
      final rates = await getCurrentRates();
      final lastUpdate = await getLastUpdateDate();

      debugPrint('📊 ESTADO ACTUAL DE TASAS:');
      debugPrint('   USD: \$1 = Bs. ${rates['USD']!.toStringAsFixed(2)}');
      debugPrint('   EUR: €1 = Bs. ${rates['EUR']!.toStringAsFixed(2)}');
      debugPrint('   COP: \$1 = Bs. ${rates['COP']!.toStringAsFixed(4)}');

      if (lastUpdate != null) {
        final difference = DateTime.now().difference(lastUpdate);
        debugPrint(
            '   📅 Última actualización: hace ${difference.inHours} horas');
      } else {
        debugPrint('   📅 Nunca actualizado (usando valores por defecto)');
      }
    } catch (e) {
      debugPrint('Error mostrando estado: $e');
    }
  }
}
