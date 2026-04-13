class Validators {
  // Validar email
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'El email es requerido';
    }
    
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    
    if (!emailRegex.hasMatch(value)) {
      return 'Ingrese un email válido';
    }
    
    return null;
  }

  // Validar teléfono
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'El teléfono es requerido';
    }
    
    // Remover caracteres especiales para validar
    final cleanPhone = value.replaceAll(RegExp(r'[^\d]'), '');
    
    if (cleanPhone.length < 10) {
      return 'Ingrese un teléfono válido (mínimo 10 dígitos)';
    }
    
    return null;
  }

  // Validar RIF
  static String? validateRif(String? value) {
    if (value == null || value.isEmpty) {
      return 'El RIF es requerido';
    }
    
    // Remover guiones
    final cleanRif = value.replaceAll('-', '');
    
    if (cleanRif.length < 8) {
      return 'Ingrese un RIF válido (mínimo 8 dígitos)';
    }
    
    return null;
  }

  // Validar campo requerido
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName es requerido';
    }
    return null;
  }

  // Validar número decimal
  static String? validateDecimal(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName es requerido';
    }
    
    final number = double.tryParse(value);
    if (number == null) {
      return 'Ingrese un número válido';
    }
    
    if (number <= 0) {
      return '$fieldName debe ser mayor a 0';
    }
    
    return null;
  }

  // Validar número entero
  static String? validateInteger(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName es requerido';
    }
    
    final number = int.tryParse(value);
    if (number == null) {
      return 'Ingrese un número entero válido';
    }
    
    if (number < 0) {
      return '$fieldName no puede ser negativo';
    }
    
    return null;
  }

  // Validar longitud mínima
  static String? validateMinLength(String? value, int minLength, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName es requerido';
    }
    
    if (value.length < minLength) {
      return '$fieldName debe tener al menos $minLength caracteres';
    }
    
    return null;
  }

  // Validar URL
  static String? validateUrl(String? value) {
    if (value == null || value.isEmpty) {
      return 'La URL es requerida';
    }
    
    final urlRegex = RegExp(
      r'^[a-zA-Z0-9\-\.]+\.[a-zA-Z]{2,}$',
    );
    
    if (!urlRegex.hasMatch(value)) {
      return 'Ingrese una URL válida (ej: api.miempresa.com)';
    }
    
    return null;
  }

  // Validar puerto
  static String? validatePort(String? value) {
    if (value == null || value.isEmpty) {
      return 'El puerto es requerido';
    }
    
    final port = int.tryParse(value);
    if (port == null) {
      return 'Ingrese un puerto válido';
    }
    
    if (port < 1 || port > 65535) {
      return 'El puerto debe estar entre 1 y 65535';
    }
    
    return null;
  }
}
