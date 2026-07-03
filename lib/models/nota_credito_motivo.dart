/// Modelo para catálogo de motivos de Nota de Crédito
class NotaCreditoMotivo {
  final int? id;
  final String? serverId;
  final String codigo;
  final String descripcion;
  final String tipo; // 'total' | 'parcial' | 'ambos'
  final bool activo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  NotaCreditoMotivo({
    this.id,
    this.serverId,
    required this.codigo,
    required this.descripcion,
    this.tipo = 'ambos',
    this.activo = true,
    this.createdAt,
    this.updatedAt,
  });

  /// Crear desde mapa de la base de datos
  factory NotaCreditoMotivo.fromMap(Map<String, dynamic> map) {
    return NotaCreditoMotivo(
      id: map['id'] as int?,
      serverId: map['server_id'] as String?,
      codigo: map['codigo'] as String,
      descripcion: map['descripcion'] as String,
      tipo: map['tipo'] as String,
      activo: (map['activo'] as int? ?? 1) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  /// Convertir a mapa para guardar en base de datos
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'server_id': serverId,
      'codigo': codigo,
      'descripcion': descripcion,
      'tipo': tipo,
      'activo': activo ? 1 : 0,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Convertir a mapa para Supabase
  Map<String, dynamic> toRemoteMap() {
    return {
      'codigo': codigo,
      'descripcion': descripcion,
      'tipo': tipo,
      'activo': activo,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Crear copia con nuevos valores
  NotaCreditoMotivo copyWith({
    int? id,
    String? serverId,
    String? codigo,
    String? descripcion,
    String? tipo,
    bool? activo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotaCreditoMotivo(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      codigo: codigo ?? this.codigo,
      descripcion: descripcion ?? this.descripcion,
      tipo: tipo ?? this.tipo,
      activo: activo ?? this.activo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Verificar si el motivo aplica para notas de crédito totales
  bool get aplicaParaTotal => tipo == 'total' || tipo == 'ambos';

  /// Verificar si el motivo aplica para notas de crédito parciales
  bool get aplicaParaParcial => tipo == 'parcial' || tipo == 'ambos';

  /// Motivos predefinidos comunes
  static List<NotaCreditoMotivo> get motivosPredefinidos => [
        NotaCreditoMotivo(
          codigo: 'DEV_TOTAL',
          descripcion: 'Devolución total de la factura',
          tipo: 'total',
        ),
        NotaCreditoMotivo(
          codigo: 'DEV_PARCIAL',
          descripcion: 'Devolución parcial de productos',
          tipo: 'parcial',
        ),
        NotaCreditoMotivo(
          codigo: 'ERROR_FACT',
          descripcion: 'Error en facturación',
          tipo: 'ambos',
        ),
        NotaCreditoMotivo(
          codigo: 'PROD_DEFECT',
          descripcion: 'Producto defectuoso',
          tipo: 'parcial',
        ),
        NotaCreditoMotivo(
          codigo: 'PROD_NO_REC',
          descripcion: 'Producto no recibido por cliente',
          tipo: 'parcial',
        ),
        NotaCreditoMotivo(
          codigo: 'CAMBIO_PRECIO',
          descripcion: 'Cambio de precio',
          tipo: 'parcial',
        ),
        NotaCreditoMotivo(
          codigo: 'DESCUENTO_NO_APL',
          descripcion: 'Descuento no aplicado',
          tipo: 'parcial',
        ),
        NotaCreditoMotivo(
          codigo: 'ANULACION_CLIENTE',
          descripcion: 'Anulación solicitada por cliente',
          tipo: 'total',
        ),
        NotaCreditoMotivo(
          codigo: 'ERROR_SISTEMA',
          descripcion: 'Error del sistema',
          tipo: 'ambos',
        ),
      ];

  @override
  String toString() {
    return 'NotaCreditoMotivo{codigo: $codigo, descripcion: $descripcion, tipo: $tipo}';
  }
}