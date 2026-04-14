import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/permissions.dart';

// Modelo de usuario simplificado (sin backend)
class UserModel {
  final String userId;
  final String userName;
  final String userType;

  UserModel({
    required this.userId,
    required this.userName,
    required this.userType,
  });

  bool hasAccess(String module) {
    return true; // Simplificado - siempre tiene acceso
  }
}

class UserProvider extends ChangeNotifier {
  UserModel? _currentUser;
  UserRole? _userRole;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _userRole == UserRole.administrador;
  bool get isCashier => _userRole == UserRole.cajero;
  bool get isSupervisor => _userRole == UserRole.supervisor;
  bool get isManager => _userRole == UserRole.gerente;
  UserRole? get userRole => _userRole;

  /// Cargar usuario actual desde SharedPreferences
  Future<void> loadUser() async {
    _currentUser = null;
    _userRole = null;
    notifyListeners();
  }

  /// Establecer usuario después del login
  void setUser(UserModel user) {
    _currentUser = user;
    _userRole = PermissionConfig.getRoleFromString(user.userType);
    notifyListeners();
  }

  /// Cerrar sesión
  Future<void> logout() async {
    await clearSession();
  }

  /// Limpiar sesión completa
  Future<void> clearSession() async {
    try {
      // Importar SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      
      // Limpiar todas las preferencias guardadas
      await prefs.clear();
      
      // Resetear variables de estado
      _currentUser = null;
      _userRole = null;
      
      notifyListeners();
      
      debugPrint('✅ Sesión limpiada completamente');
    } catch (e) {
      debugPrint('❌ Error limpiando sesión: $e');
      // Aún así resetear las variables locales
      _currentUser = null;
      _userRole = null;
      notifyListeners();
    }
  }

  /// Verificar si tiene un permiso específico
  bool hasPermission(Permission permission) {
    if (_userRole == null) return false;
    return PermissionConfig.hasPermission(_userRole!, permission);
  }

  /// Verificar si puede acceder a una acción (con string de rol)
  bool canAccess(Permission permission) {
    if (_currentUser == null) return false;
    return PermissionConfig.canAccess(_currentUser!.userType, permission);
  }

  /// Verificar si requiere autorización para una acción
  bool requiresAuthorization(Permission permission) {
    if (_currentUser == null) return true;
    return PermissionConfig.requiresAuthorization(_currentUser!.userType, permission);
  }

  /// Obtener todos los permisos del usuario actual
  Set<Permission> getUserPermissions() {
    if (_userRole == null) return {};
    return PermissionConfig.getPermissions(_userRole!);
  }

  /// Obtener nombre del rol actual
  String getRoleName() {
    if (_userRole == null) return 'Sin rol';
    return PermissionConfig.getRoleName(_userRole!);
  }

  /// Obtener descripción del rol actual
  String getRoleDescription() {
    if (_userRole == null) return '';
    return PermissionConfig.getRoleDescription(_userRole!);
  }

  // ============================================================================
  // MÉTODOS DE COMPATIBILIDAD (mantener para no romper código existente)
  // ============================================================================

  /// Verificar si tiene acceso a un módulo (legacy)
  bool hasAccess(String module) {
    if (_currentUser == null) return false;
    if (isAdmin) return true;
    return _currentUser!.hasAccess(module);
  }

  /// Verificar si puede editar (solo admin)
  bool canEdit() {
    return hasPermission(Permission.editSettings);
  }

  /// Verificar si puede ver estadísticas de cajeros
  bool canViewCashierStats() {
    return hasPermission(Permission.viewCashierStats);
  }

  /// Verificar si puede gestionar cajeros
  bool canManageCashiers() {
    return hasPermission(Permission.manageCashiers);
  }

  /// Verificar si puede ver reportes avanzados
  bool canViewAdvancedReports() {
    return hasPermission(Permission.viewAdvancedReports);
  }

  /// Verificar si puede editar inventario
  bool canEditInventory() {
    return hasPermission(Permission.editInventory);
  }

  /// Verificar si puede ver ranking de cajeros
  bool canViewCashierRanking() {
    return hasPermission(Permission.viewCashiers);
  }

  /// Verificar si puede ver gráficas
  bool canViewCharts() {
    return hasPermission(Permission.viewBasicReports);
  }

  /// Verificar si puede acceder a módulo de cajeros
  bool canAccessCashiersModule() {
    return hasPermission(Permission.manageCashiers);
  }
}
