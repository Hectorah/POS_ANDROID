import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter/foundation.dart';
import '../core/app_config.dart';

/// Servicio para VERIFICAR Pago Móvil a través de la API de Ubii
/// 
/// Flujo:
/// 1. Cliente realiza Pago Móvil desde su app bancaria
/// 2. Cliente proporciona la referencia del pago
/// 3. Cajero ingresa la referencia en tu app
/// 4. Este servicio VERIFICA con Ubii si el pago es válido
class UbiiPagoMovilService {
  // ==================== CONFIGURACIÓN ====================
  
  /// Credenciales del comercio desde configuración centralizada
  static String get _clientId => AppConfig.ubiiClientId;
  static String get _clientDomain => AppConfig.ubiiClientDomain;
  static String get _baseUrl => AppConfig.ubiiBaseUrl;
  static String get _phoneComercio => AppConfig.pagoMovilTelefono;
  static String get _cedulaComercio => AppConfig.pagoMovilCedulaRif;
  
  // ==================== ESTADO INTERNO ====================
  
  String? _bearerToken;
  String? _apiKeyPagoMovil;
  String? _aesKey;
  String? _aesIv;
  
  // ==================== GETTERS PÚBLICOS ====================
  
  /// Indica si el servicio está autenticado y listo para usar
  bool get isAuthenticated => _bearerToken != null && _apiKeyPagoMovil != null;
  
  /// Token de autenticación actual
  String? get bearerToken => _bearerToken;
  
  /// API Key de Pago Móvil
  String? get apiKey => _apiKeyPagoMovil;
  
  // ==================== PASO 1: AUTENTICACIÓN ====================
  
  /// Autentica el cliente con Ubii y obtiene el token JWT
  /// 
  /// El token contiene las llaves de cifrado (i = IV, k = Key)
  /// necesarias para cifrar las peticiones de pago.
  /// 
  /// Retorna `true` si la autenticación fue exitosa.
  Future<bool> authenticate() async {
    final url = Uri.parse('$_baseUrl/check_client_id');
    final headers = {
      'CONTENT-TYPE': 'application/json',
      'X-CLIENT-ID': _clientId,
      'X-CLIENT-DOMAIN': _clientDomain,
      'X-CLIENT-CHANNEL': 'BTN-API',
    };
    
    try {
      debugPrint('🔐 Ubii Pago Móvil: Autenticando...');
      
      final response = await http.get(url, headers: headers);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['R'] == '0') {
          _bearerToken = data['token'];
          
          // Decodificar JWT para obtener llaves de cifrado
          Map<String, dynamic> payload = JwtDecoder.decode(_bearerToken!);
          _aesIv = payload['i'];   // IV de 16 bytes
          _aesKey = payload['k'];  // Key de 32 bytes
          
          debugPrint('✅ Autenticación exitosa');
          debugPrint('   Token obtenido: ${_bearerToken!.substring(0, 20)}...');
          debugPrint('   IV: ${_aesIv?.substring(0, 10)}...');
          debugPrint('   Key: ${_aesKey?.substring(0, 10)}...');
          
          return true;
        } else {
          debugPrint('❌ Error en autenticación: ${data['S']}');
          return false;
        }
      } else {
        debugPrint('❌ Error HTTP ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error autenticando: $e');
      return false;
    }
  }
  
  // ==================== PASO 2: OBTENER API KEYS ====================
  
  /// Obtiene las API Keys del comercio, específicamente la de Pago Móvil
  /// 
  /// Busca la key con alias "P2C" o "PAGO_MOVIL" según configuración.
  /// 
  /// Retorna `true` si se encontró la key de Pago Móvil.
  Future<bool> fetchApiKeys() async {
    if (_bearerToken == null) {
      debugPrint('❌ No hay token de autenticación');
      return false;
    }
    
    final url = Uri.parse('$_baseUrl/get_keys');
    final headers = {
      'CONTENT-TYPE': 'application/json',
      'X-CLIENT-ID': _clientId,
      'X-CLIENT-DOMAIN': _clientDomain,
      'X-CLIENT-CHANNEL': 'BTN-API',
      'Authorization': 'Bearer $_bearerToken',
    };
    
    try {
      debugPrint('🔑 Ubii Pago Móvil: Obteniendo API Keys...');
      
      final response = await http.get(url, headers: headers);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['R'] == '0') {
          final keys = data['Keys'] as List;
          
          // Buscar la key de Pago Móvil (alias "P2C" o "PAGO_MOVIL")
          for (var k in keys) {
            final alias = k['btn_alias'] as String?;
            if (alias == AppConfig.pagoMovilAlias || alias == 'P2C' || alias == 'PAGO_MOVIL') {
              _apiKeyPagoMovil = k['btn_key'];
              debugPrint('✅ API Key de Pago Móvil encontrada');
              debugPrint('   Alias: $alias');
              debugPrint('   Key: ${_apiKeyPagoMovil!.substring(0, 20)}...');
              return true;
            }
          }
          
          debugPrint('❌ No se encontró API Key de Pago Móvil');
          debugPrint('   Keys disponibles: ${keys.map((k) => k['btn_alias']).join(', ')}');
          return false;
        } else {
          debugPrint('❌ Error obteniendo keys: ${data['S']}');
          return false;
        }
      } else {
        debugPrint('❌ Error HTTP ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error obteniendo keys: $e');
      return false;
    }
  }
  
  // ==================== PASO 3: CIFRADO ====================
  
  /// Cifra los datos de la transacción usando AES-256 CBC
  /// 
  /// Utiliza las llaves (i, k) obtenidas del JWT en el paso 1.
  /// El resultado es un string en Base64 listo para enviar.
  String _encryptData(Map<String, dynamic> jsonData) {
    try {
      // 1. Convertir JSON a String
      String plainText = jsonEncode(jsonData);
      
      debugPrint('🔒 Cifrando datos...');
      debugPrint('   Datos originales: $plainText');
      
      // 2. Configurar el cifrador AES-256 CBC con PKCS7 (equivalente a PKCS5)
      final key = encrypt.Key.fromBase64(_aesKey!);
      final iv = encrypt.IV.fromBase64(_aesIv!);
      
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: 'PKCS7')
      );
      
      // 3. Cifrar
      final encrypted = encrypter.encrypt(plainText, iv: iv);
      
      // 4. Retornar en Base64
      final encryptedBase64 = encrypted.base64;
      debugPrint('✅ Datos cifrados: ${encryptedBase64.substring(0, 30)}...');
      
      return encryptedBase64;
    } catch (e) {
      debugPrint('❌ Error cifrando datos: $e');
      rethrow;
    }
  }
  
  // ==================== PASO 4: VERIFICAR PAGO MÓVIL ====================
  
  /// Verifica si un Pago Móvil reportado por el cliente es válido
  /// 
  /// Parámetros:
  /// - [bankAba]: Código ABA del banco del cliente (ej: "0134" para Banesco)
  /// - [phoneCliente]: Teléfono del cliente que realizó el pago (ej: "00584127121936")
  /// - [monto]: Monto exacto del pago en bolívares
  /// - [fecha]: Fecha del pago en formato YYYYMMDD (ej: "20260414")
  /// - [referencia]: Número de referencia proporcionado por el cliente
  /// - [orderNumber]: Número de orden único generado por tu sistema
  /// 
  /// Retorna un Map con la respuesta de Ubii o null si hubo error.
  /// 
  /// Códigos de respuesta importantes:
  /// - R = "0": Pago verificado correctamente ✅
  /// - R = "1": Pago no encontrado o inválido ❌
  Future<Map<String, dynamic>?> verificarPagoMovil({
    required String bankAba,
    required String phoneCliente,
    required double monto,
    required String fecha,
    required String referencia,
    required String orderNumber,
  }) async {
    if (_apiKeyPagoMovil == null || _aesKey == null || _aesIv == null) {
      debugPrint('❌ Error: No hay API Key o llaves de cifrado');
      debugPrint('   ¿Ejecutaste authenticate() y fetchApiKeys()?');
      return null;
    }
    
    final url = Uri.parse('$_baseUrl/payment_pago_movil_ref');
    
    debugPrint('🔍 Ubii Pago Móvil: Verificando pago...');
    debugPrint('   Banco: $bankAba');
    debugPrint('   Teléfono Cliente: $phoneCliente');
    debugPrint('   Monto: Bs. ${monto.toStringAsFixed(2)}');
    debugPrint('   Fecha: $fecha');
    debugPrint('   Referencia: $referencia');
    debugPrint('   Orden: $orderNumber');
    
    // Datos a cifrar según documentación de Ubii
    Map<String, dynamic> rawData = {
      'bank': bankAba,
      'date': fecha,
      'phoneP': phoneCliente,
      'phoneC': _phoneComercio,
      'm': monto.toStringAsFixed(2),
      'ref': referencia,
      'ci': _cedulaComercio,
      'order': orderNumber,
      'ip': '',
    };
    
    try {
      // Cifrar el cuerpo de la petición
      final encryptedBody = _encryptData(rawData);
      
      final headers = {
        'CONTENT-TYPE': 'application/json',
        'X-CLIENT-ID': _clientId,
        'X-API-KEY': _apiKeyPagoMovil!,
        'X-CLIENT-CHANNEL': 'BTN-API',
        'Authorization': 'Bearer $_bearerToken',
      };
      
      final response = await http.post(
        url,
        headers: headers,
        body: encryptedBody, // Enviamos el string cifrado directamente
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        debugPrint('✅ Respuesta recibida');
        debugPrint('   R: ${data['R']}');
        debugPrint('   S: ${data['S']}');
        debugPrint('   codR: ${data['codR']}');
        debugPrint('   codS: ${data['codS']}');
        
        if (data['R'] == '0' && data['codR'] == '00') {
          debugPrint('✅ Pago Móvil VERIFICADO correctamente');
          debugPrint('   Referencia confirmada: ${data['ref']}');
        } else {
          debugPrint('❌ Pago Móvil NO verificado');
          debugPrint('   Motivo: ${data['codS']}');
        }
        
        return data;
      } else {
        debugPrint('❌ Error HTTP ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error verificando pago móvil: $e');
      return null;
    }
  }
  
  // ==================== UTILIDADES ====================
  
  /// Retorna la fecha actual en formato YYYYMMDD
  String getCurrentDate() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  }
  
  /// Genera un número de orden único basado en timestamp
  /// 
  /// Formato: ORD-{timestamp}-{random}
  String generateOrderNumber() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 1000).toString().padLeft(3, '0');
    return 'ORD-$timestamp-$random';
  }
  
  /// Valida el formato de un teléfono venezolano
  /// 
  /// Debe ser: 00584XXXXXXXXX (14 dígitos)
  bool isValidVenezuelanPhone(String phone) {
    final regex = RegExp(r'^00584\d{9}$');
    return regex.hasMatch(phone);
  }
  
  /// Valida el formato de una cédula venezolana
  /// 
  /// Debe ser: V12345678 o E12345678
  bool isValidVenezuelanCI(String ci) {
    final regex = RegExp(r'^[VEJ]\d{6,9}$');
    return regex.hasMatch(ci);
  }
  
  /// Limpia el estado del servicio (útil para logout)
  void clearSession() {
    _bearerToken = null;
    _apiKeyPagoMovil = null;
    _aesKey = null;
    _aesIv = null;
    debugPrint('🔓 Sesión de Ubii Pago Móvil limpiada');
  }
  
  // ==================== MÉTODO DE ALTO NIVEL ====================
  
  /// Inicializa el servicio completo (autenticación + obtención de keys)
  /// 
  /// Este método debe llamarse UNA VEZ al inicio de la aplicación
  /// o cuando se necesite verificar un Pago Móvil.
  /// 
  /// Retorna `true` si la inicialización fue exitosa.
  Future<bool> initialize() async {
    debugPrint('🚀 Inicializando Ubii Pago Móvil...');
    
    // Paso 1: Autenticar
    final authSuccess = await authenticate();
    if (!authSuccess) {
      debugPrint('❌ Fallo en autenticación');
      return false;
    }
    
    // Paso 2: Obtener API Keys
    final keysSuccess = await fetchApiKeys();
    if (!keysSuccess) {
      debugPrint('❌ Fallo obteniendo API Keys');
      return false;
    }
    
    debugPrint('✅ Ubii Pago Móvil inicializado correctamente');
    return true;
  }
}
