// 1. MODELO DE USUARIO
class Usuario {
  final int? id;
  final String nombre;
  final String usuario;
  final String clave;
  final String nivel;

  Usuario({this.id, required this.nombre, required this.usuario, required this.clave, required this.nivel});

  // Convierte Objeto a Mapa (Para enviar a la BD)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'usuario': usuario,
      'clave': clave,
      'nivel': nivel,
    };
  }

  // Convierte Mapa a Objeto (Para leer de la BD)
  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      id: map['id'],
      nombre: map['nombre'],
      usuario: map['usuario'],
      clave: map['clave'],
      nivel: map['nivel'],
    );
  }
}

// 2. MODELO DE PRODUCTO
class Producto {
  final int? id;
  final String codArticulo;
  final String? codBarras;
  final String nombre;
  final double precio;
  final String tipoImpuesto; // 'E' = Exento, 'G' = General (16%)

  Producto({
    this.id, 
    required this.codArticulo, 
    this.codBarras, 
    required this.nombre, 
    required this.precio,
    this.tipoImpuesto = 'G', // Por defecto General (16%)
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cod_articulo': codArticulo,
      'cod_barras': codBarras,
      'nombre': nombre,
      'precio': precio,
      'tipo_impuesto': tipoImpuesto,
    };
  }

  factory Producto.fromMap(Map<String, dynamic> map) {
    return Producto(
      id: map['id'],
      codArticulo: map['cod_articulo'],
      codBarras: map['cod_barras'],
      nombre: map['nombre'],
      precio: map['precio'],
      tipoImpuesto: map['tipo_impuesto'] ?? 'G', // Por defecto General si no existe
    );
  }
}

// 3. MODELO DE EXISTENCIA
class Existencia {
  final int? id;
  final int productoId;
  final String codArticulo;
  final double stock;

  Existencia({this.id, required this.productoId, required this.codArticulo, required this.stock});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'producto_id': productoId,
      'cod_articulo': codArticulo,
      'stock': stock,
    };
  }

  factory Existencia.fromMap(Map<String, dynamic> map) {
    return Existencia(
      id: map['id'],
      productoId: map['producto_id'],
      codArticulo: map['cod_articulo'],
      stock: map['stock'],
    );
  }
}

// ============================================================================
// UNIDADES DE MEDIDA
// ============================================================================

enum UnidadMedida { und, kg }

extension UnidadMedidaExtension on UnidadMedida {
  String get label {
    switch (this) {
      case UnidadMedida.und: return 'Und';
      case UnidadMedida.kg:  return 'Kg';
    }
  }

  bool get esFraccionable {
    return this == UnidadMedida.kg;
  }

  int get decimalesPermitidos {
    return esFraccionable ? 3 : 0;
  }

  static UnidadMedida fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'kg': return UnidadMedida.kg;
      default:   return UnidadMedida.und;
    }
  }
}
