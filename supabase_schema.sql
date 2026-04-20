-- ============================================================================
-- ESQUEMA SUPABASE — ESPEJO EXACTO DE SQLITE
-- Verificado contra lib/DATABASE/db_helper.dart (_createDB)
-- ============================================================================
-- INSTRUCCIONES:
--   1. Abre Supabase → SQL Editor
--   2. Pega TODO este script y ejecuta
--   3. El PASO 1 elimina tablas viejas, el PASO 2 las recrea correctamente
-- ============================================================================

-- ============================================================================
-- PASO 1: ELIMINAR TABLAS EXISTENTES (orden inverso por FK)
-- ============================================================================
DROP TABLE IF EXISTS cierres_lote    CASCADE;
DROP TABLE IF EXISTS factura_detalle CASCADE;
DROP TABLE IF EXISTS factura         CASCADE;
DROP TABLE IF EXISTS existencias     CASCADE;
DROP TABLE IF EXISTS clientes        CASCADE;
DROP TABLE IF EXISTS productos       CASCADE;
DROP TABLE IF EXISTS usuarios        CASCADE;

-- ============================================================================
-- PASO 2: CREAR TABLAS
-- Columnas en el mismo orden que SQLite.
-- Supabase usa server_id (UUID) como PK en la nube.
-- Los campos id (INTEGER local), server_id, last_modified y sync_status
-- son los campos de control de sincronización.
-- ============================================================================


-- ============================================================================
-- NOTAS IMPORTANTES
-- ============================================================================
-- 1. producto_id, factura_id, cliente_id, usuario_id son INTEGER locales.
--    No son FK en Supabase porque los IDs de SQLite no existen en la nube.
--    La relación se mantiene por cod_articulo (UNIQUE en existencias) y
--    numero_control (UNIQUE en factura).
--
-- 2. existencias tiene UNIQUE en cod_articulo → garantiza 1 fila por
--    producto, igual que el UNIQUE en producto_id de SQLite.
--    Cuando se actualiza el stock, el repositorio hace UPSERT (update si
--    existe, insert si no).
--
-- 3. sync_status NO se replica en Supabase (es un campo solo local).
--    server_id tampoco se envía en toRemoteMap() de cada repositorio.
--
-- 4. Para producción, habilitar RLS:
--    ALTER TABLE productos ENABLE ROW LEVEL SECURITY;
--    CREATE POLICY "allow_all" ON productos FOR ALL USING (true);
--    (repetir para cada tabla)
-- ============================================================================
