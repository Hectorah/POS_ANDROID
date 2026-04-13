import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/app_models.dart';

/// Servicio de autenticación
/// Maneja el login y validación de usuarios
class AuthService {
  static final AuthService instance = AuthService._init();
  AuthService._init();

  /// Iniciar sesión con usuario y contraseña
  /// Retorna el Usuario si las credenciales son correctas, null si no
  Future<Usuario?> login(String usuario, String clave) async {
    try {
      debugPrint('🔐 Intentando login para usuario: $usuario');
      
      // Verificar en la base de datos
      final resultado = await DbHelper.instance.verificarUsuario(usuario, clave);
      
      if (resultado != null) {
        debugPrint('✅ Login exitoso para: ${resultado['nombre']}');
        return Usuario.fromMap(resultado);
      } else {
        debugPrint('❌ Credenciales incorrectas');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error en login: $e');
      return null;
    }
  }

  /// Crear un nuevo usuario
  Future<bool> crearUsuario({
    required String nombre,
    required String usuario,
    required String clave,
    required String nivel,
  }) async {
    try {
      final nuevoUsuario = Usuario(
        nombre: nombre,
        usuario: usuario,
        clave: DbHelper.instance.hashPassword(clave),
        nivel: nivel,
      );

      final id = await DbHelper.instance.insertarUsuario(nuevoUsuario.toMap());
      
      debugPrint('✅ Usuario creado con ID: $id');
      return id > 0;
    } catch (e) {
      debugPrint('❌ Error creando usuario: $e');
      return false;
    }
  }

  /// Obtener todos los usuarios
  Future<List<Usuario>> obtenerUsuarios() async {
    try {
      final resultados = await DbHelper.instance.obtenerUsuarios();
      return resultados.map((map) => Usuario.fromMap(map)).toList();
    } catch (e) {
      debugPrint('❌ Error obteniendo usuarios: $e');
      return [];
    }
  }
}
