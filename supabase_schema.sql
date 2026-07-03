-- ============================================================================
-- ESQUEMA SUPABASE COMPLETO — ESPEJO DE SQLITE (Versión 14 con Notas de Crédito)
-- ============================================================================
-- INSTRUCCIONES:
--   1. Abre Supabase → SQL Editor
--   2. Pega TODO este script y ejecuta
--   3. El PASO 1 elimina tablas viejas, el PASO 2 las recrea correctamente
-- ============================================================================

-- ============================================================================
-- PASO 1: ELIMINAR TABLAS EXISTENTES (orden inverso por FK)
-- ============================================================================
DROP TABLE IF EXISTS nota_credito_detalle CASCADE;
DROP TABLE IF EXISTS nota_credito         CASCADE;
DROP TABLE IF EXISTS nota_credito_motivo  CASCADE;
DROP TABLE IF EXISTS arqueos_caja         CASCADE;
DROP TABLE IF EXISTS gastos_diarios       CASCADE;
DROP TABLE IF EXISTS cierres_lote         CASCADE;
DROP TABLE IF EXISTS factura_detalle      CASCADE;
DROP TABLE IF EXISTS factura              CASCADE;
DROP TABLE IF EXISTS reportes_cierre      CASCADE;
DROP TABLE IF EXISTS secuencias_documentos CASCADE;
DROP TABLE IF EXISTS sesiones_fiscales    CASCADE;
DROP TABLE IF EXISTS existencias          CASCADE;
DROP TABLE IF EXISTS clientes             CASCADE;
DROP TABLE IF EXISTS productos            CASCADE;
DROP TABLE IF EXISTS usuarios             CASCADE;

-- ============================================================================
-- PASO 2: CREAR TABLAS PRINCIPALES
-- ============================================================================

-- Tabla USUARIOS
CREATE TABLE usuarios (
  id SERIAL PRIMARY KEY,
  server_id UUID UNIQUE,
  nombre TEXT NOT NULL,
  usuario TEXT NOT NULL UNIQUE,
  clave TEXT NOT NULL,
  nivel TEXT NOT NULL,
  fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_modified TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabla SESIONES_FISCALES
CREATE TABLE sesiones_fiscales (
  id SERIAL PRIMARY KEY,
  server_id UUID UNIQUE DEFAULT gen_random_uuid(),
  numero_sesion TEXT NOT NULL UNIQUE,
  fecha_apertura TIMESTAMP WITH TIME ZONE NOT NULL,
  fecha_cierre TIMESTAMP WITH TIME ZONE,
  usuario_apertura_id INTEGER NOT NULL,
  usuario_apertura_nombre TEXT NOT NULL,
  usuario_cierre_id INTEGER,
  usuario_cierre_nombre TEXT,
  estado TEXT NOT NULL DEFAULT 'ABIERTA' CHECK(estado IN ('ABIERTA', 'CERRADA')),
  total_ventas DECIMAL(10,2) NOT NULL DEFAULT 0,
  total_notas_credito DECIMAL(10,2) NOT NULL DEFAULT 0,
  total_efectivo DECIMAL(10,2) NOT NULL DEFAULT 0,
  total_tarjeta DECIMAL(10,2) NOT NULL DEFAULT 0,
  total_pago_movil DECIMAL(10,2) NOT NULL DEFAULT 0,
  total_otros_metodos DECIMAL(10,2) NOT NULL DEFAULT 0,
  total_base_imponible DECIMAL(10,2) NOT NULL DEFAULT 0,
  total_iva DECIMAL(10,2) NOT NULL DEFAULT 0,
  total_exento DECIMAL(10,2) NOT NULL DEFAULT 0,
  total_general DECIMAL(10,2) NOT NULL DEFAULT 0,
  cantidad_facturas INTEGER NOT NULL DEFAULT 0,
  cantidad_notas_credito INTEGER NOT NULL DEFAULT 0,
  cantidad_transacciones INTEGER NOT NULL DEFAULT 0,
  factura_inicial TEXT,
  factura_final TEXT,
  nc_inicial TEXT,
  nc_final TEXT,
  arqueo_realizado BOOLEAN NOT NULL DEFAULT FALSE,
  arqueo_id INTEGER,
  fondo_caja_inicial DECIMAL(10,2) NOT NULL DEFAULT 0,
  last_modified TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabla ARQUEOS_CAJA
CREATE TABLE arqueos_caja (
  id SERIAL PRIMARY KEY,
  server_id UUID UNIQUE DEFAULT gen_random_uuid(),
  sesion_fiscal_id INTEGER NOT NULL,
  numero_arqueo TEXT NOT NULL UNIQUE,
  fecha_arqueo TIMESTAMP WITH TIME ZONE NOT NULL,
  usuario_arqueo_id INTEGER NOT NULL,
  usuario_arqueo_nombre TEXT NOT NULL,
  billete_100_usd INTEGER NOT NULL DEFAULT 0,
  billete_50_usd INTEGER NOT NULL DEFAULT 0,
  billete_20_usd INTEGER NOT NULL DEFAULT 0,
  billete_10_usd INTEGER NOT NULL DEFAULT 0,
  billete_5_usd INTEGER NOT NULL DEFAULT 0,
  billete_1_usd INTEGER NOT NULL DEFAULT 0,
  billete_100_bs INTEGER NOT NULL DEFAULT 0,
  billete_50_bs INTEGER NOT NULL DEFAULT 0,
  billete_20_bs INTEGER NOT NULL DEFAULT 0,
  billete_10_bs INTEGER NOT NULL DEFAULT 0,
  billete_5_bs INTEGER NOT NULL DEFAULT 0,
  moneda_1_usd INTEGER NOT NULL DEFAULT 0,
  moneda_050_usd INTEGER NOT NULL DEFAULT 0,
  moneda_025_usd INTEGER NOT NULL DEFAULT 0,
  moneda_010_usd INTEGER NOT NULL DEFAULT 0,
  moneda_005_usd INTEGER NOT NULL DEFAULT 0,
  moneda_001_usd INTEGER NOT NULL DEFAULT 0,
  total_efectivo_usd DECIMAL(10,2) NOT NULL DEFAULT 0,
  total_efectivo_bs DECIMAL(10,2) NOT NULL DEFAULT 0,
  total_tarjeta_declarado DECIMAL(10,2) NOT NULL DEFAULT 0,
  total_pago_movil_declarado DECIMAL(10,2) NOT NULL DEFAULT 0,
  total_otros_declarado DECIMAL(10,2) NOT NULL DEFAULT 0,
  total_efectivo_sistema DECIMAL(10,2) NOT NULL DEFAULT 0,
  total_tarjeta_sistema DECIMAL(10,2) NOT NULL DEFAULT 0,
  total_pago_movil_sistema DECIMAL(10,2) NOT NULL DEFAULT 0,
  total_otros_sistema DECIMAL(10,2) NOT NULL DEFAULT 0,
  diferencia_efectivo DECIMAL(10,2) NOT NULL DEFAULT 0,
  diferencia_tarjeta DECIMAL(10,2) NOT NULL DEFAULT 0,
  diferencia_pago_movil DECIMAL(10,2) NOT NULL DEFAULT 0,
  diferencia_total DECIMAL(10,2) NOT NULL DEFAULT 0,
  cuadrado BOOLEAN NOT NULL DEFAULT FALSE,
  observaciones TEXT,
  fondo_caja_inicial DECIMAL(10,2) NOT NULL DEFAULT 0,
  last_modified TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  FOREIGN KEY (sesion_fiscal_id) REFERENCES sesiones_fiscales(id)
);

-- Tabla REPORTES_CIERRE
CREATE TABLE reportes_cierre (
  id SERIAL PRIMARY KEY,
  server_id UUID UNIQUE DEFAULT gen_random_uuid(),
  sesion_fiscal_id INTEGER NOT NULL,
  numero_reporte TEXT NOT NULL UNIQUE,
  fecha_reporte TIMESTAMP WITH TIME ZONE NOT NULL,
  facturas_emitidas INTEGER NOT NULL DEFAULT 0,
  notas_credito_emitidas INTEGER NOT NULL DEFAULT 0,
  total_ventas DECIMAL(10,2) NOT NULL DEFAULT 0,
  total_notas_credito DECIMAL(10,2) NOT NULL DEFAULT 0,
  total_neto DECIMAL(10,2) NOT NULL DEFAULT 0,
  iva_16 DECIMAL(10,2) NOT NULL DEFAULT 0,
  iva_8 DECIMAL(10,2) NOT NULL DEFAULT 0,
  iva_total DECIMAL(10,2) NOT NULL DEFAULT 0,
  exento DECIMAL(10,2) NOT NULL DEFAULT 0,
  desglose_efectivo DECIMAL(10,2) NOT NULL DEFAULT 0,
  desglose_tarjeta DECIMAL(10,2) NOT NULL DEFAULT 0,
  desglose_pago_movil DECIMAL(10,2) NOT NULL DEFAULT 0,
  desglose_otros DECIMAL(10,2) NOT NULL DEFAULT 0,
  rif_comercio TEXT NOT NULL,
  nombre_comercio TEXT NOT NULL,
  direccion_comercio TEXT NOT NULL,
  hash_integridad TEXT,
  seniat_sync_id TEXT,
  seniat_sync_fecha TIMESTAMP WITH TIME ZONE,
  seniat_sync_estado TEXT DEFAULT 'PENDIENTE' CHECK(seniat_sync_estado IN ('PENDIENTE', 'ENVIADO', 'APROBADO', 'RECHAZADO')),
  last_modified TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  FOREIGN KEY (sesion_fiscal_id) REFERENCES sesiones_fiscales(id)
);

-- Tabla SECUENCIAS_DOCUMENTOS
CREATE TABLE secuencias_documentos (
  id SERIAL PRIMARY KEY,
  server_id UUID UNIQUE DEFAULT gen_random_uuid(),
  tipo_documento TEXT NOT NULL UNIQUE CHECK(tipo_documento IN ('FACTURA', 'NOTA_CREDITO')),
  prefijo TEXT NOT NULL,
  ultimo_numero INTEGER NOT NULL DEFAULT 0,
  reinicio_diario INTEGER NOT NULL DEFAULT 0,
  last_modified TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabla PRODUCTOS
CREATE TABLE productos (
  id SERIAL PRIMARY KEY,
  server_id UUID UNIQUE,
  cod_articulo TEXT NOT NULL UNIQUE,
  cod_barras TEXT,
  nombre TEXT NOT NULL,
  descripcion TEXT,
  precio DECIMAL(10,2) NOT NULL,
  tipo_impuesto TEXT NOT NULL DEFAULT 'G',
  unidad_medida TEXT NOT NULL DEFAULT 'und',
  last_modified TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabla EXISTENCIAS (Stock)
CREATE TABLE existencias (
  id SERIAL PRIMARY KEY,
  server_id UUID UNIQUE,
  producto_id INTEGER NOT NULL,
  cod_articulo TEXT NOT NULL,
  stock DECIMAL(10,3) NOT NULL,
  ultima_actualizacion TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_modified TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(cod_articulo)
);

-- Tabla CLIENTES
CREATE TABLE clientes (
  id SERIAL PRIMARY KEY,
  server_id UUID UNIQUE,
  identificacion TEXT NOT NULL UNIQUE,
  nombre TEXT NOT NULL,
  direccion TEXT,
  telefono TEXT,
  correo TEXT,
  agente_retencion INTEGER DEFAULT 0,
  fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_modified TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabla FACTURA (Cabecera)
CREATE TABLE factura (
  id SERIAL PRIMARY KEY,
  server_id UUID UNIQUE,
  numero_control TEXT NOT NULL UNIQUE,
  fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  cliente_id INTEGER NOT NULL,
  usuario_id INTEGER NOT NULL,
  tipo_documento TEXT NOT NULL DEFAULT 'Factura',
  base_imponible DECIMAL(10,2) NOT NULL,
  monto_iva DECIMAL(10,2) NOT NULL,
  retencion_iva DECIMAL(10,2) DEFAULT 0,
  tasa_usd DECIMAL(10,2),
  tasa_eur DECIMAL(10,2),
  total DECIMAL(10,2) NOT NULL,
  metodo_pago TEXT NOT NULL,
  referencia_pago TEXT,
  monto_bs DECIMAL(10,2),
  monto_usd DECIMAL(10,2),
  ubii_reference TEXT,
  ubii_auth_code TEXT,
  ubii_card_type TEXT,
  ubii_terminal TEXT,
  ubii_lote TEXT,
  ubii_response_code TEXT,
  ubii_response_message TEXT,
  estado TEXT NOT NULL DEFAULT 'activo',
  tiene_nota_credito INTEGER DEFAULT 0,
  sesion_fiscal_id INTEGER REFERENCES sesiones_fiscales(id),
  tasa_iva DECIMAL(10,2) DEFAULT 16.0,
  monto_exento DECIMAL(10,2) DEFAULT 0,
  monto_base_imponible DECIMAL(10,2),
  last_modified TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabla FACTURA_DETALLE (Renglones)
CREATE TABLE factura_detalle (
  id SERIAL PRIMARY KEY,
  server_id UUID UNIQUE,
  factura_id INTEGER NOT NULL,
  producto_id INTEGER NOT NULL,
  cantidad DECIMAL(10,3) NOT NULL,
  precio_unitario DECIMAL(10,2) NOT NULL,
  subtotal DECIMAL(10,2) NOT NULL,
  last_modified TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  FOREIGN KEY (factura_id) REFERENCES factura(id) ON DELETE CASCADE
);

-- Tabla CIERRES_LOTE (Settlement)
CREATE TABLE cierres_lote (
  id SERIAL PRIMARY KEY,
  server_id UUID UNIQUE,
  fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  usuario_id INTEGER NOT NULL,
  tipo_cierre TEXT NOT NULL,
  ubii_response_code TEXT,
  ubii_response_message TEXT,
  ubii_terminal TEXT,
  ubii_lote TEXT,
  ubii_fecha TEXT,
  ubii_hora TEXT,
  total_transacciones INTEGER DEFAULT 0,
  monto_total DECIMAL(10,2),
  datos_completos TEXT,
  last_modified TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
);

-- ============================================================================
-- TABLAS DE NOTAS DE CRÉDITO (Nuevas en versión 14)
-- ============================================================================

-- Tabla NOTA_CREDITO
CREATE TABLE nota_credito (
  id SERIAL PRIMARY KEY,
  server_id UUID UNIQUE,
  numero_control TEXT NOT NULL UNIQUE,
  tipo TEXT NOT NULL CHECK (tipo IN ('total', 'parcial')),
  factura_id INTEGER NOT NULL,
  motivo TEXT NOT NULL,
  monto_total DECIMAL(10,2) NOT NULL,
  iva DECIMAL(10,2) NOT NULL,
  fecha_emision TIMESTAMP WITH TIME ZONE NOT NULL,
  estado TEXT NOT NULL CHECK (estado IN ('pendiente', 'procesada', 'anulada')),
  usuario_id INTEGER,
  observaciones TEXT,
  fecha_anulacion TIMESTAMP WITH TIME ZONE,
  motivo_anulacion TEXT,
  usuario_anulacion_id INTEGER,
  last_modified TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabla NOTA_CREDITO_DETALLE
CREATE TABLE nota_credito_detalle (
  id SERIAL PRIMARY KEY,
  server_id UUID UNIQUE,
  nota_credito_id INTEGER NOT NULL,
  producto_id INTEGER NOT NULL,
  cantidad DECIMAL(10,3) NOT NULL,
  precio_unitario DECIMAL(10,2) NOT NULL,
  subtotal DECIMAL(10,2) NOT NULL,
  lote TEXT,
  serial TEXT,
  fecha_vencimiento TIMESTAMP WITH TIME ZONE,
  last_modified TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  FOREIGN KEY (nota_credito_id) REFERENCES nota_credito(id) ON DELETE CASCADE
);

-- Tabla NOTA_CREDITO_MOTIVO
CREATE TABLE nota_credito_motivo (
  id SERIAL PRIMARY KEY,
  server_id UUID UNIQUE,
  codigo TEXT NOT NULL UNIQUE,
  descripcion TEXT NOT NULL,
  tipo TEXT NOT NULL CHECK (tipo IN ('total', 'parcial', 'ambos')),
  activo BOOLEAN DEFAULT TRUE,
  last_modified TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- ÍNDICES PARA OPTIMIZACIÓN
-- ============================================================================

-- Índices para USUARIOS
CREATE INDEX idx_usuarios_usuario ON usuarios(usuario);
CREATE INDEX idx_usuarios_nivel ON usuarios(nivel);

-- Índices para PRODUCTOS
CREATE INDEX idx_productos_cod_articulo ON productos(cod_articulo);
CREATE INDEX idx_productos_nombre ON productos(nombre);

-- Índices para EXISTENCIAS
CREATE INDEX idx_existencias_cod_articulo ON existencias(cod_articulo);
CREATE INDEX idx_existencias_producto_id ON existencias(producto_id);

-- Índices para CLIENTES
CREATE INDEX idx_clientes_identificacion ON clientes(identificacion);
CREATE INDEX idx_clientes_nombre ON clientes(nombre);

-- Índices para FACTURA
CREATE INDEX idx_factura_numero_control ON factura(numero_control);
CREATE INDEX idx_factura_cliente_id ON factura(cliente_id);
CREATE INDEX idx_factura_fecha_creacion ON factura(fecha_creacion);
CREATE INDEX idx_factura_estado ON factura(estado);

-- Índices para FACTURA_DETALLE
CREATE INDEX idx_factura_detalle_factura_id ON factura_detalle(factura_id);
CREATE INDEX idx_factura_detalle_producto_id ON factura_detalle(producto_id);

-- Índices para CIERRES_LOTE
CREATE INDEX idx_cierres_lote_usuario_id ON cierres_lote(usuario_id);
CREATE INDEX idx_cierres_lote_fecha_creacion ON cierres_lote(fecha_creacion);

-- Índices para NOTA_CREDITO
CREATE INDEX idx_nota_credito_factura_id ON nota_credito(factura_id);
CREATE INDEX idx_nota_credito_estado ON nota_credito(estado);
CREATE INDEX idx_nota_credito_fecha_emision ON nota_credito(fecha_emision);
CREATE INDEX idx_nota_credito_numero_control ON nota_credito(numero_control);

-- Índices para NOTA_CREDITO_DETALLE
CREATE INDEX idx_nota_credito_detalle_nota_credito_id ON nota_credito_detalle(nota_credito_id);
CREATE INDEX idx_nota_credito_detalle_producto_id ON nota_credito_detalle(producto_id);

-- Índices para NOTA_CREDITO_MOTIVO
CREATE INDEX idx_nota_credito_motivo_tipo ON nota_credito_motivo(tipo);
CREATE INDEX idx_nota_credito_motivo_activo ON nota_credito_motivo(activo);
CREATE INDEX idx_nota_credito_motivo_codigo ON nota_credito_motivo(codigo);

-- ============================================================================
-- DATOS INICIALES
-- ============================================================================

-- Usuario por defecto
INSERT INTO usuarios (nombre, usuario, clave, nivel) VALUES
  ('Administrador', 'admin', 'admin123', 'admin')
ON CONFLICT (usuario) DO NOTHING;

-- Motivos predefinidos para notas de crédito
INSERT INTO nota_credito_motivo (codigo, descripcion, tipo) VALUES
  ('DEV_TOTAL', 'Devolución total de la factura', 'total'),
  ('DEV_PARCIAL', 'Devolución parcial de productos', 'parcial'),
  ('ERROR_FACT', 'Error en facturación', 'ambos'),
  ('PROD_DEFECT', 'Producto defectuoso', 'parcial'),
  ('PROD_NO_REC', 'Producto no recibido por cliente', 'parcial'),
  ('CAMBIO_PRECIO', 'Cambio de precio', 'parcial'),
  ('DESCUENTO_NO_APL', 'Descuento no aplicado', 'parcial'),
  ('ANULACION_CLIENTE', 'Anulación solicitada por cliente', 'total'),
  ('ERROR_SISTEMA', 'Error del sistema', 'ambos')
ON CONFLICT (codigo) DO NOTHING;

-- ============================================================================
-- CONFIGURACIÓN DE SEGURIDAD (RLS - Row Level Security)
-- ============================================================================
-- Descomentar estas líneas en producción:

/*
-- Habilitar RLS para todas las tablas
ALTER TABLE usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE productos ENABLE ROW LEVEL SECURITY;
ALTER TABLE existencias ENABLE ROW LEVEL SECURITY;
ALTER TABLE clientes ENABLE ROW LEVEL SECURITY;
ALTER TABLE factura ENABLE ROW LEVEL SECURITY;
ALTER TABLE factura_detalle ENABLE ROW LEVEL SECURITY;
ALTER TABLE cierres_lote ENABLE ROW LEVEL SECURITY;
ALTER TABLE nota_credito ENABLE ROW LEVEL SECURITY;
ALTER TABLE nota_credito_detalle ENABLE ROW LEVEL SECURITY;
ALTER TABLE nota_credito_motivo ENABLE ROW LEVEL SECURITY;
ALTER TABLE sesiones_fiscales ENABLE ROW LEVEL SECURITY;
ALTER TABLE reportes_cierre ENABLE ROW LEVEL SECURITY;
ALTER TABLE secuencias_documentos ENABLE ROW LEVEL SECURITY;

-- Políticas para permitir todas las operaciones (ajustar según necesidades)
CREATE POLICY "allow_all_usuarios" ON usuarios FOR ALL USING (true);
CREATE POLICY "allow_all_productos" ON productos FOR ALL USING (true);
CREATE POLICY "allow_all_existencias" ON existencias FOR ALL USING (true);
CREATE POLICY "allow_all_clientes" ON clientes FOR ALL USING (true);
CREATE POLICY "allow_all_factura" ON factura FOR ALL USING (true);
CREATE POLICY "allow_all_factura_detalle" ON factura_detalle FOR ALL USING (true);
CREATE POLICY "allow_all_cierres_lote" ON cierres_lote FOR ALL USING (true);
CREATE POLICY "allow_all_nota_credito" ON nota_credito FOR ALL USING (true);
CREATE POLICY "allow_all_nota_credito_detalle" ON nota_credito_detalle FOR ALL USING (true);
CREATE POLICY "allow_all_nota_credito_motivo" ON nota_credito_motivo FOR ALL USING (true);
CREATE POLICY "allow_all_sesiones_fiscales" ON sesiones_fiscales FOR ALL USING (true);
CREATE POLICY "allow_all_reportes_cierre" ON reportes_cierre FOR ALL USING (true);
CREATE POLICY "allow_all_secuencias_documentos" ON secuencias_documentos FOR ALL USING (true);
*/

-- ============================================================================
-- NOTAS IMPORTANTES PARA SINCRONIZACIÓN
-- ============================================================================
-- 1. Los campos sync_status NO se replican en Supabase (son solo locales)
-- 2. server_id se usa para mapear registros locales (SQLite) con remotos (Supabase)
-- 3. Las relaciones (factura_id, producto_id, etc.) usan IDs locales de SQLite
-- 4. En Supabase, las relaciones se mantienen por campos únicos como:
--    - cod_articulo (productos y existencias)
--    - numero_control (factura)
--    - identificacion (clientes)
--    - usuario (usuarios)
-- 5. Los repositorios de sincronización hacen UPSERT basado en estos campos únicos
-- 6. Para desarrollo, mantener RLS deshabilitado
-- 7. Para producción, habilitar RLS y configurar políticas apropiadas
-- ============================================================================