
enum Permission {
  // Navegación
  viewHome,
  viewDocuments,
  viewInventory,
  viewClients,
  
  // Documentos
  createInvoice,
  viewInvoices,
  editInvoice,
  deleteInvoice,
  printInvoice,
  
  // Clientes
  createClient,
  editClient,
  deleteClient,
  
  // Inventario
  editInventory,
  adjustStock,
  
  // Caja
  openCashRegister,
  closeCashRegister,
  viewCashMovements,
  
  // Cajeros
  viewCashiers,
  manageCashiers,
  viewCashierStats,
  viewOwnStats,
  
  // Reportes
  viewBasicReports,
  viewAdvancedReports,
  exportReports,
  
  // Configuración
  viewSettings,
  editSettings,
  configurePrinter,
  manageUsers,
  
  // Sistema
  viewLogs,
  backupData,
}

/// Roles del sistema
enum UserRole {
  administrador,
  cajero,
  supervisor,
  gerente,
}

/// Configuración de permisos por rol
class PermissionConfig {
  static final Map<UserRole, Set<Permission>> _rolePermissions = {
    // ADMINISTRADOR - Acceso total
    UserRole.administrador: {
      ...Permission.values, // Todos los permisos
    },
    
    // CAJERO - Permisos limitados para operación diaria
    UserRole.cajero: {
      // Navegación básica
      Permission.viewDocuments,
      Permission.viewClients,
      
      // Documentos
      Permission.createInvoice,
      Permission.viewInvoices,
      Permission.printInvoice,
      
      // Clientes
      Permission.createClient,
      
      // Inventario (solo consulta)
      Permission.viewInventory,
      
      // Estadísticas propias
      Permission.viewOwnStats,
      
      // Reportes básicos
      Permission.viewBasicReports,
    },
    
    // SUPERVISOR - Permisos intermedios
    UserRole.supervisor: {
      // Navegación
      Permission.viewHome,
      Permission.viewDocuments,
      Permission.viewInventory,
      Permission.viewClients,
      
      // Documentos
      Permission.createInvoice,
      Permission.viewInvoices,
      Permission.editInvoice,
      Permission.printInvoice,
      
      // Clientes
      Permission.createClient,
      Permission.editClient,
      
      // Inventario
      Permission.adjustStock,
      
      // Caja
      Permission.viewCashMovements,
      Permission.closeCashRegister,
      
      // Cajeros
      Permission.viewCashiers,
      Permission.viewCashierStats,
      
      // Reportes
      Permission.viewBasicReports,
      Permission.viewAdvancedReports,
      Permission.exportReports,
      
      // Configuración limitada
      Permission.viewSettings,
    },
    
    // GERENTE - Casi todos los permisos excepto configuración crítica
    UserRole.gerente: {
      // Navegación completa
      Permission.viewHome,
      Permission.viewDocuments,
      Permission.viewInventory,
      Permission.viewClients,
      
      // Documentos completos
      Permission.createInvoice,
      Permission.viewInvoices,
      Permission.editInvoice,
      Permission.deleteInvoice,
      Permission.printInvoice,
      
      // Clientes completos
      Permission.createClient,
      Permission.editClient,
      Permission.deleteClient,
      
      // Inventario completo
      Permission.editInventory,
      Permission.adjustStock,
      
      // Caja completa
      Permission.openCashRegister,
      Permission.closeCashRegister,
      Permission.viewCashMovements,
      
      // Cajeros
      Permission.viewCashiers,
      Permission.manageCashiers,
      Permission.viewCashierStats,
      
      // Reportes completos
      Permission.viewBasicReports,
      Permission.viewAdvancedReports,
      Permission.exportReports,
      
      // Configuración limitada
      Permission.viewSettings,
      Permission.configurePrinter,
      
      // Sistema
      Permission.viewLogs,
    },
  };

  /// Obtener rol desde string
  static UserRole getRoleFromString(String roleString) {
    final normalized = roleString.toUpperCase().trim();
    
    switch (normalized) {
      case 'ADMINISTRADOR':
      case 'ADMIN':
        return UserRole.administrador;
      case 'CAJERO':
      case 'CASHIER':
        return UserRole.cajero;
      case 'SUPERVISOR':
        return UserRole.supervisor;
      case 'GERENTE':
      case 'MANAGER':
        return UserRole.gerente;
      default:
        return UserRole.cajero; // Por defecto, menor privilegio
    }
  }

  /// Verificar si un rol tiene un permiso específico
  static bool hasPermission(UserRole role, Permission permission) {
    return _rolePermissions[role]?.contains(permission) ?? false;
  }

  /// Obtener todos los permisos de un rol
  static Set<Permission> getPermissions(UserRole role) {
    return _rolePermissions[role] ?? {};
  }

  /// Verificar si un rol puede acceder a una acción
  static bool canAccess(String roleString, Permission permission) {
    final role = getRoleFromString(roleString);
    return hasPermission(role, permission);
  }

  /// Obtener nombre legible del rol
  static String getRoleName(UserRole role) {
    switch (role) {
      case UserRole.administrador:
        return 'Administrador';
      case UserRole.cajero:
        return 'Cajero';
      case UserRole.supervisor:
        return 'Supervisor';
      case UserRole.gerente:
        return 'Gerente';
    }
  }

  /// Obtener descripción del rol
  static String getRoleDescription(UserRole role) {
    switch (role) {
      case UserRole.administrador:
        return 'Acceso total al sistema';
      case UserRole.cajero:
        return 'Operación de caja y ventas';
      case UserRole.supervisor:
        return 'Supervisión y reportes';
      case UserRole.gerente:
        return 'Gestión completa del negocio';
    }
  }

  /// Verificar si un rol requiere autorización para una acción
  static bool requiresAuthorization(String roleString, Permission permission) {
    final role = getRoleFromString(roleString);
    
    // Si no tiene el permiso, requiere autorización
    if (!hasPermission(role, permission)) {
      return true;
    }
    
    return false;
  }

  /// Obtener permisos faltantes para un rol
  static Set<Permission> getMissingPermissions(UserRole role) {
    final allPermissions = Permission.values.toSet();
    final rolePermissions = getPermissions(role);
    return allPermissions.difference(rolePermissions);
  }
}
