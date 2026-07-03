/// Definiciones SQL para tablas de Notas de Crédito
class NotaCreditoTables {
  // Tipos de datos comunes
  static const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
  static const textType = 'TEXT NOT NULL';
  static const textNullable = 'TEXT';
  static const intType = 'INTEGER NOT NULL';
  static const intNullable = 'INTEGER';
  static const realType = 'REAL NOT NULL';
  static const realNullable = 'REAL';
  static const dateType = 'TEXT NOT NULL';
  static const dateNullable = 'TEXT';
  static const boolType = 'INTEGER NOT NULL DEFAULT 0';

  /// SQL para crear tabla nota_credito
  static String get createNotaCreditoTable => '''
    CREATE TABLE nota_credito (
      id $idType,
      server_id $textNullable UNIQUE,
      numero_control $textType UNIQUE,
      tipo $textType CHECK (tipo IN ('total', 'parcial')),
      factura_id $intType,
      motivo $textType,
      monto_total $realType,
      iva $realType,
      fecha_emision $dateType,
      estado $textType CHECK (estado IN ('pendiente', 'procesada', 'anulada')),
      usuario_id $intNullable,
      observaciones $textNullable,
      fecha_anulacion $dateNullable,
      motivo_anulacion $textNullable,
      usuario_anulacion_id $intNullable,
      sync_status $intType DEFAULT 0,
      last_modified $dateType DEFAULT CURRENT_TIMESTAMP,
      created_at $dateType DEFAULT CURRENT_TIMESTAMP,
      updated_at $dateType DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (factura_id) REFERENCES factura(id) ON DELETE RESTRICT,
      FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE SET NULL,
      FOREIGN KEY (usuario_anulacion_id) REFERENCES usuarios(id) ON DELETE SET NULL
    )
  ''';

  /// SQL para crear tabla nota_credito_detalle
  static String get createNotaCreditoDetalleTable => '''
    CREATE TABLE nota_credito_detalle (
      id $idType,
      server_id $textNullable UNIQUE,
      nota_credito_id $intType,
      producto_id $intType,
      cantidad $realType,
      precio_unitario $realType,
      subtotal $realType,
      lote $textNullable,
      serial $textNullable,
      fecha_vencimiento $dateNullable,
      sync_status $intType DEFAULT 0,
      last_modified $dateType DEFAULT CURRENT_TIMESTAMP,
      created_at $dateType DEFAULT CURRENT_TIMESTAMP,
      updated_at $dateType DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (nota_credito_id) REFERENCES nota_credito(id) ON DELETE CASCADE,
      FOREIGN KEY (producto_id) REFERENCES productos(id) ON DELETE RESTRICT
    )
  ''';

  /// SQL para crear tabla nota_credito_motivo
  static String get createNotaCreditoMotivoTable => '''
    CREATE TABLE nota_credito_motivo (
      id $idType,
      server_id $textNullable UNIQUE,
      codigo $textType UNIQUE,
      descripcion $textType,
      tipo $textType CHECK (tipo IN ('total', 'parcial', 'ambos')),
      activo $boolType DEFAULT 1,
      last_modified $dateType DEFAULT CURRENT_TIMESTAMP,
      sync_status $intType DEFAULT 1,
      created_at $dateType DEFAULT CURRENT_TIMESTAMP,
      updated_at $dateType DEFAULT CURRENT_TIMESTAMP
    )
  ''';

  /// SQL para crear índices
  static List<String> get createIndexes => [
    // Índices para nota_credito
    'CREATE INDEX idx_nota_credito_factura_id ON nota_credito(factura_id)',
    'CREATE INDEX idx_nota_credito_estado ON nota_credito(estado)',
    'CREATE INDEX idx_nota_credito_fecha_emision ON nota_credito(fecha_emision)',
    'CREATE INDEX idx_nota_credito_sync_status ON nota_credito(sync_status)',
    
    // Índices para nota_credito_detalle
    'CREATE INDEX idx_nota_credito_detalle_nota_credito_id ON nota_credito_detalle(nota_credito_id)',
    'CREATE INDEX idx_nota_credito_detalle_producto_id ON nota_credito_detalle(producto_id)',
    'CREATE INDEX idx_nota_credito_detalle_sync_status ON nota_credito_detalle(sync_status)',
    
    // Índices para nota_credito_motivo
    'CREATE INDEX idx_nota_credito_motivo_tipo ON nota_credito_motivo(tipo)',
    'CREATE INDEX idx_nota_credito_motivo_activo ON nota_credito_motivo(activo)',
  ];

  /// SQL para insertar motivos predefinidos
  static List<String> get insertPredefinedMotivos => [
    "INSERT OR IGNORE INTO nota_credito_motivo (codigo, descripcion, tipo) VALUES ('DEV_TOTAL', 'Devolución total de la factura', 'total')",
    "INSERT OR IGNORE INTO nota_credito_motivo (codigo, descripcion, tipo) VALUES ('DEV_PARCIAL', 'Devolución parcial de productos', 'parcial')",
    "INSERT OR IGNORE INTO nota_credito_motivo (codigo, descripcion, tipo) VALUES ('ERROR_FACT', 'Error en facturación', 'ambos')",
    "INSERT OR IGNORE INTO nota_credito_motivo (codigo, descripcion, tipo) VALUES ('PROD_DEFECT', 'Producto defectuoso', 'parcial')",
    "INSERT OR IGNORE INTO nota_credito_motivo (codigo, descripcion, tipo) VALUES ('PROD_NO_REC', 'Producto no recibido por cliente', 'parcial')",
    "INSERT OR IGNORE INTO nota_credito_motivo (codigo, descripcion, tipo) VALUES ('CAMBIO_PRECIO', 'Cambio de precio', 'parcial')",
    "INSERT OR IGNORE INTO nota_credito_motivo (codigo, descripcion, tipo) VALUES ('DESCUENTO_NO_APL', 'Descuento no aplicado', 'parcial')",
    "INSERT OR IGNORE INTO nota_credito_motivo (codigo, descripcion, tipo) VALUES ('ANULACION_CLIENTE', 'Anulación solicitada por cliente', 'total')",
    "INSERT OR IGNORE INTO nota_credito_motivo (codigo, descripcion, tipo) VALUES ('ERROR_SISTEMA', 'Error del sistema', 'ambos')",
  ];

  /// SQL para agregar campo a tabla factura (si no existe)
  static String get addTieneNotaCreditoToFactura => '''
    ALTER TABLE factura ADD COLUMN tiene_nota_credito INTEGER DEFAULT 0
  ''';

  /// Verificar si una columna existe en una tabla
  static String checkColumnExists(String tableName, String columnName) {
    return '''
      SELECT COUNT(*) as exists 
      FROM pragma_table_info('$tableName') 
      WHERE name = '$columnName'
    ''';
  }

  /// Obtener todas las sentencias SQL para crear las tablas
  static List<String> get allCreateStatements => [
    createNotaCreditoTable,
    createNotaCreditoDetalleTable,
    createNotaCreditoMotivoTable,
    ...createIndexes,
  ];

  /// Obtener todas las sentencias SQL para migración
  static List<String> get allMigrationStatements => [
    addTieneNotaCreditoToFactura,
    ...insertPredefinedMotivos,
  ];
}