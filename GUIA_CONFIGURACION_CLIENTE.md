# 📱 Guía de Configuración - POS Android

## 🎯 Para el Cliente Final

Esta guía te ayudará a configurar la aplicación POS Android para tu negocio de forma simple y rápida.

---

## 📋 REQUISITOS PREVIOS

### 1. Hardware Necesario
- ✅ **Dispositivo Android** (versión 7.0 o superior)
- ✅ **Punto de Venta Ubii** (para pagos con tarjeta)
- ✅ **Conexión a Internet** (WiFi o datos móviles)
- ⚠️ **Espacio de almacenamiento**: Mínimo 100 MB libres

### 2. Información que Debes Tener Lista
Antes de comenzar, asegúrate de tener:

#### 📄 Información del Comercio:
- Nombre o razón social del negocio
- RIF (Registro de Información Fiscal)
- Dirección fiscal completa
- Teléfono de contacto
- Correo electrónico

#### 🏦 Información Fiscal (SENIAT):
- Prefijo del número de control (ej: 00, 01, 02)
- Rango máximo de números de control autorizados
- Tasa de IVA vigente (actualmente 16%)

#### 💳 Credenciales de Ubii (Pagos Electrónicos):
- Client ID (X-Client-Id)
- Dominio registrado
- Teléfono registrado para Pago Móvil
- Cédula o RIF para Pago Móvil
- Alias de la API Key (generalmente "P2C")

#### 💱 Información de Monedas:
- Tasa de cambio USD actual (actualizar diariamente)
- Moneda principal de operación (USD o VES)

---

## ⚙️ CONFIGURACIÓN PASO A PASO

### PASO 1: Editar el Archivo .env

El archivo `.env` contiene toda la configuración sensible de tu negocio. Debes editarlo antes de usar la aplicación.

**Ubicación del archivo**: En la raíz del proyecto encontrarás `.env.example`

**Instrucciones**:
1. Copia el archivo `.env.example` y renómbralo a `.env`
2. Abre el archivo `.env` con un editor de texto
3. Completa TODOS los campos con tu información

#### 📝 Secciones a Configurar:

##### 1️⃣ INFORMACIÓN DEL COMERCIO
```env
COMERCIO_NOMBRE=Tu Comercio Aquí
COMERCIO_RIF=J-123456789-0
COMERCIO_DIRECCION=Calle Principal, Ciudad, Estado
COMERCIO_TELEFONO=0414-1234567
COMERCIO_EMAIL=contacto@tucomercio.com
```

##### 2️⃣ CONFIGURACIÓN FISCAL (SENIAT)
```env
# Prefijo del número de control
# 00 = Caja única
# 01, 02, 03 = Múltiples cajas
FISCAL_PREFIJO_NUMERO_CONTROL=00

# Rango máximo autorizado por SENIAT
# Ejemplo: Si te autorizaron del 1 al 10,000, coloca 10000
FISCAL_RANGO_MAXIMO=10000

# Umbral de alerta (cuando quedan menos de este número)
FISCAL_UMBRAL_ALERTA=100

# Tasa de IVA vigente (0.16 = 16%)
FISCAL_TASA_IVA=0.16

# Tasa de retención de IVA (0.75 = 75%)
FISCAL_TASA_RETENCION_IVA=0.75
```

##### 3️⃣ CONFIGURACIÓN DE UBII (PAGOS)
```env
# Client ID proporcionado por Ubii
UBII_CLIENT_ID=tu_client_id_aqui

# Dominio registrado en Ubii
UBII_CLIENT_DOMAIN=tudominio.com

# URL de la API (NO CAMBIAR)
UBII_BASE_URL=https://botonc.ubiipagos.com
```

##### 4️⃣ CONFIGURACIÓN DE PAGO MÓVIL
```env
# Teléfono del comercio (formato: 00584XXXXXXXXX)
PAGO_MOVIL_TELEFONO=00584141234567

# Cédula o RIF del comercio (formato: V12345678 o J123456789)
PAGO_MOVIL_CEDULA_RIF=J123456789

# Alias de la API Key (generalmente P2C)
PAGO_MOVIL_ALIAS=P2C

# Tiempo máximo de espera (300 = 5 minutos)
PAGO_MOVIL_TIMEOUT=300

# Intervalo entre consultas (5 segundos)
PAGO_MOVIL_POLLING_INTERVAL=5
```

##### 5️⃣ CONFIGURACIÓN DE MONEDAS
```env
# Tasa de cambio USD (actualizar DIARIAMENTE según BCV)
TASA_CAMBIO_USD=36.50

# Tasa de cambio EUR (opcional)
TASA_CAMBIO_EUR=0.0

# Moneda principal (USD, VES, EUR)
MONEDA_PRINCIPAL=VES
```

##### 6️⃣ CONFIGURACIÓN DE LA APLICACIÓN
```env
# Ambiente (development, staging, production)
APP_ENVIRONMENT=production

# Logs de debug (true/false)
APP_DEBUG_LOGS=false

# Modo demo (true/false)
APP_DEMO_MODE=false
```

##### 7️⃣ CONFIGURACIÓN DE BASE DE DATOS
```env
# Nombre del archivo de base de datos
DB_NAME=POS_ANDROID.db

# Versión de la base de datos
DB_VERSION=5

# Backups automáticos (true/false)
DB_AUTO_BACKUP=true

# Intervalo de backups (días)
DB_BACKUP_INTERVAL_DAYS=7
```

##### 8️⃣ CONFIGURACIÓN DE IMPRESIÓN
```env
# Tipo de impresora (thermal, pdf, none)
PRINTER_TYPE=none

# Ancho del papel (58 o 80 mm)
PRINTER_PAPER_WIDTH=80

# Incluir logo (true/false)
PRINTER_INCLUDE_LOGO=false

# Ruta del logo
PRINTER_LOGO_PATH=assets/logos/klk.png
```

---

### PASO 2: Primer Inicio de la Aplicación

1. **Instala la aplicación** en tu dispositivo Android
2. **Abre la aplicación** por primera vez
3. **Inicia sesión** con las credenciales por defecto:
   - **Usuario**: `admin`
   - **Contraseña**: `admin123`

⚠️ **IMPORTANTE**: Cambia la contraseña después del primer inicio

---

### PASO 3: Importar Inventario (Opcional)

Si ya tienes un inventario, puedes importarlo desde Excel o CSV:

1. Prepara tu archivo con el siguiente formato:

**Formato Excel/CSV:**
```
CodArticulo | CodBarras | Nombre           | Precio | Stock
001         | 123456    | Producto 1       | 10.50  | 100
002         | 789012    | Producto 2       | 25.00  | 50
```

2. En la pantalla principal, presiona el botón **⋮ Opciones**
3. Selecciona **Importar Productos**
4. Elige tu archivo Excel (.xlsx) o CSV (.csv)
5. Espera a que se complete la importación

---

### PASO 4: Configurar Punto de Venta Ubii

Para usar pagos con tarjeta:

1. **Instala la app Ubii POS** en el mismo dispositivo
2. **Configura Ubii POS** con tus credenciales
3. **Verifica la conexión** realizando una transacción de prueba

---

## 🗄️ ESTRUCTURA DE LA BASE DE DATOS

La aplicación utiliza una base de datos SQLite local con las siguientes tablas:

### 📊 Tablas Principales:

#### 1. **usuarios**
Almacena los usuarios del sistema
- `id`: Identificador único
- `nombre`: Nombre completo
- `usuario`: Nombre de usuario (login)
- `clave`: Contraseña encriptada
- `nivel`: Nivel de acceso (admin, cajero)
- `fecha_creacion`: Fecha de registro

#### 2. **productos**
Catálogo de productos
- `id`: Identificador único
- `cod_articulo`: Código del artículo (único)
- `cod_barras`: Código de barras (opcional)
- `nombre`: Nombre del producto
- `precio`: Precio en USD
- `fecha_creacion`: Fecha de registro

#### 3. **existencias**
Control de inventario
- `id`: Identificador único
- `producto_id`: Referencia al producto
- `cod_articulo`: Código del artículo
- `stock`: Cantidad disponible
- `ultima_actualizacion`: Última modificación

#### 4. **clientes**
Registro de clientes
- `id`: Identificador único
- `identificacion`: RIF o Cédula (único)
- `nombre`: Nombre o razón social
- `correo`: Email (opcional)
- `direccion`: Dirección (opcional)
- `fecha_creacion`: Fecha de registro

#### 5. **factura**
Cabecera de facturas
- `id`: Identificador único
- `numero_control`: Número de control fiscal (único)
- `fecha_creacion`: Fecha y hora de emisión
- `cliente_id`: Referencia al cliente
- `usuario_id`: Referencia al usuario que emitió
- `tipo_documento`: Tipo (Factura, Nota de Crédito, etc.)
- `base_imponible`: Monto sin IVA
- `monto_iva`: Monto del IVA
- `tasa_usd`: Tasa de cambio USD usada
- `tasa_eur`: Tasa de cambio EUR usada
- `total`: Total de la factura
- `metodo_pago`: Método usado (efectivo, tarjeta, pago móvil)
- `referencia_pago`: Referencia del pago
- `monto_bs`: Monto en Bolívares
- `monto_usd`: Monto en USD
- `ubii_*`: Datos de la transacción Ubii (si aplica)

#### 6. **factura_detalle**
Detalle de productos en facturas
- `id`: Identificador único
- `factura_id`: Referencia a la factura
- `producto_id`: Referencia al producto
- `cantidad`: Cantidad vendida
- `precio_unitario`: Precio por unidad
- `subtotal`: Total del renglón

#### 7. **cierres_lote**
Registro de cierres de lote
- `id`: Identificador único
- `fecha_creacion`: Fecha y hora del cierre
- `usuario_id`: Usuario que realizó el cierre
- `tipo_cierre`: Tipo de cierre (Q = rápido)
- `ubii_*`: Datos del cierre Ubii
- `total_transacciones`: Cantidad de transacciones
- `monto_total`: Monto total del lote
- `datos_completos`: JSON con datos completos

---

## 🔐 SEGURIDAD Y RESPALDOS

### Respaldos Automáticos
La aplicación crea respaldos automáticos de la base de datos cada 7 días (configurable).

**Ubicación de respaldos**: 
- Android: `/storage/emulated/0/Android/data/com.pos.pos_android/files/backups/`

### Recomendaciones de Seguridad:
1. ✅ Cambia la contraseña por defecto inmediatamente
2. ✅ No compartas las credenciales de Ubii
3. ✅ Mantén actualizada la tasa de cambio diariamente
4. ✅ Realiza respaldos manuales semanalmente
5. ✅ Verifica el rango de números de control regularmente
6. ✅ Realiza el cierre de lote al finalizar operaciones (solo 1 vez al día)

---

## 📞 SOPORTE Y AYUDA

### Documentación Adicional:
- `GUIA_ENV.md` - Guía detallada de variables de entorno
- `MANEJO_ERRORES.md` - Sistema de manejo de errores
- `CIERRE_LOTE_UBII.md` - Guía de cierre de lote

### Códigos de Error Comunes:

| Código | Descripción | Solución |
|--------|-------------|----------|
| NET_001 | Error de conexión | Verifica tu internet |
| UBII_001 | Error de autenticación Ubii | Verifica credenciales en .env |
| PM_001 | Error en Pago Móvil | Verifica datos del pago |
| DB_001 | Error de base de datos | Reinicia la aplicación |
| INV_002 | Rango de números agotado | Solicita nuevo rango al SENIAT |
| CFG_001 | Configuración faltante | Completa el archivo .env |

---

## ✅ CHECKLIST DE CONFIGURACIÓN

Antes de usar la aplicación en producción, verifica:

- [ ] Archivo `.env` completado con todos los datos
- [ ] Credenciales de Ubii verificadas
- [ ] Rango de números de control configurado
- [ ] Tasa de cambio actualizada
- [ ] Usuario administrador con contraseña cambiada
- [ ] Inventario importado (si aplica)
- [ ] Punto de Venta Ubii configurado
- [ ] Transacción de prueba realizada exitosamente
- [ ] Cliente por defecto verificado (V-00000000)

---

## 🚀 INICIO DE OPERACIONES

Una vez completada la configuración:

1. **Verifica** que todo funcione con una venta de prueba
2. **Capacita** al personal en el uso de la aplicación
3. **Monitorea** el rango de números de control
4. **Actualiza** la tasa de cambio diariamente
5. **Realiza** el cierre de lote al final del día

---

## 📊 OPERACIONES DIARIAS

### Al Iniciar el Día:
1. Actualizar tasa de cambio en `.env`
2. Verificar conexión a internet
3. Verificar conexión con Ubii POS

### Durante el Día:
1. Emitir facturas normalmente
2. Verificar pagos móviles
3. Monitorear números de control disponibles

### Al Finalizar el Día:
1. Realizar cierre de lote (recomendado después de las 7:00 PM o al cerrar el comercio)
2. Verificar que todas las transacciones estén registradas
3. Realizar respaldo manual (opcional)

> **Nota sobre el Cierre de Lote:**  
> La aplicación permite realizar el cierre en cualquier momento del día, pero se recomienda hacerlo al finalizar las operaciones comerciales (generalmente después de las 7:00 PM) para incluir todas las transacciones del día. Solo puedes hacer UN cierre por día.

---

## ⚠️ ADVERTENCIAS IMPORTANTES

1. **NO COMPARTAS** el archivo `.env` - contiene información sensible
2. **NO SUBAS** el archivo `.env` a repositorios públicos
3. **ACTUALIZA** la tasa de cambio DIARIAMENTE
4. **SOLICITA** nuevo rango de números de control con anticipación
5. **REALIZA** el cierre de lote SOLO UNA VEZ AL DÍA
6. **VERIFICA** que el dinero de los cierres llegue al banco (24-48 horas)

---

## 📱 CONTACTO

Para soporte técnico o consultas:
- Revisa la documentación en la carpeta del proyecto
- Consulta los archivos de ayuda (.md)
- Verifica los logs de la aplicación si hay errores

---

**Última actualización**: 15 de abril de 2026  
**Versión de la aplicación**: 1.0.0  
**Versión de la base de datos**: 5

---

## 🎓 GLOSARIO

- **RIF**: Registro de Información Fiscal
- **SENIAT**: Servicio Nacional Integrado de Administración Aduanera y Tributaria
- **Ubii**: Plataforma de pagos electrónicos
- **Pago Móvil**: Sistema de transferencias bancarias en Venezuela
- **Cierre de Lote**: Proceso de liquidación de transacciones con tarjeta
- **Número de Control**: Número fiscal único para cada factura
- **Base Imponible**: Monto sin IVA
- **IVA**: Impuesto al Valor Agregado (16%)
- **BCV**: Banco Central de Venezuela
