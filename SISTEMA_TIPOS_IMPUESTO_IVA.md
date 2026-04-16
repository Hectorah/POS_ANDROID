# Sistema de Tipos de Impuesto (IVA) - SENIAT Venezuela

## Descripción General

Este sistema implementa el manejo correcto de tipos de impuesto según las normativas del SENIAT (Servicio Nacional Integrado de Administración Aduanera y Tributaria) de Venezuela.

## Tipos de Impuesto

### 1. Exento (E)
- **Descripción**: Productos que por ley no pagan IVA
- **Ejemplos**: 
  - Alimentos básicos (arroz, harina de maíz, leche)
  - Medicamentos
  - Productos de primera necesidad
- **Alícuota**: 0%

### 2. General (G)
- **Descripción**: Alícuota estándar aplicable a la mayoría de productos
- **Ejemplos**:
  - Ropa
  - Tecnología
  - Servicios
  - Productos no esenciales
- **Alícuota**: 16%

## Implementación en el Sistema

### Base de Datos

#### Tabla `productos`
Se agregó el campo `tipo_impuesto`:
```sql
tipo_impuesto TEXT NOT NULL DEFAULT 'G'
```

**Valores permitidos**:
- `'E'`: Exento
- `'G'`: General (16%)

### Modelos

#### Clase `Producto` (lib/models/app_models.dart)
```dart
class Producto {
  final String tipoImpuesto; // 'E' = Exento, 'G' = General (16%)
  
  Producto({
    this.tipoImpuesto = 'G', // Por defecto General (16%)
    // ... otros campos
  });
}
```

#### Clase `ProductModel` (lib/presentation/screens/create_document_screen.dart)
```dart
class ProductModel {
  final String tipoImpuesto; // 'E' = Exento, 'G' = General (16%)
  
  ProductModel({
    this.tipoImpuesto = 'G', // Por defecto General
    // ... otros campos
  });
}
```

### Pantalla de Creación de Productos

En `lib/presentation/screens/create_product_screen.dart`:

- Se agregó un selector de tipo de impuesto con dos opciones:
  - **General (G) - IVA 16%**: Para la mayoría de productos
  - **Exento (E) - Sin IVA**: Para productos sin impuesto

- El selector muestra descripciones claras de cada tipo
- Por defecto se selecciona "General (G)"

### Cálculos de Factura

En `lib/presentation/screens/create_document_screen.dart`:

#### Cálculos según SENIAT:

1. **Base Imponible (G)**: Suma de productos con IVA General (16%)
   ```dart
   double get _baseImponible {
     return _cart.fold(0.0, (sum, item) {
       if (item.tipoImpuesto == 'G') {
         return sum + (item.price * item.quantity);
       }
       return sum;
     });
   }
   ```

2. **Monto Exento (E)**: Suma de productos sin IVA
   ```dart
   double get _montoExento {
     return _cart.fold(0.0, (sum, item) {
       if (item.tipoImpuesto == 'E') {
         return sum + (item.price * item.quantity);
       }
       return sum;
     });
   }
   ```

3. **IVA (16%)**: Solo sobre la Base Imponible
   ```dart
   double get _iva {
     return _baseImponible * 0.16;
   }
   ```

4. **Total a Pagar**: Base Imponible + IVA + Monto Exento - Retención IVA
   ```dart
   double get _total {
     return _baseImponible + _iva + _montoExento - _retencionIVA;
   }
   ```

### Visualización en Facturas

#### En el Carrito de Compras
Cada producto muestra su tipo de impuesto:
```
PRODUCTO A (G)  .... $100.00
PRODUCTO B (E)  .... $50.00
```

#### Resumen de Totales
El resumen muestra el desglose completo según SENIAT:

```
Base Imponible (G):  $100.00
IVA 16%:             $16.00
Monto Exento (E):    $50.00
─────────────────────────────
TOTAL A PAGAR:       $166.00
```

**Nota**: Si el cliente es agente de retención, también se muestra:
```
Retención IVA (75%): -$12.00
```

### Almacenamiento en Base de Datos

Al guardar una factura, se almacenan los siguientes campos fiscales:

```dart
await DbHelper.instance.crearFactura(
  baseImponible: _baseImponible,  // Solo productos con IVA
  montoIva: _iva,                 // 16% sobre base imponible
  retencionIva: _retencionIVA,    // Si aplica
  // ... otros campos
);
```

## Migración de Datos

### Versión de Base de Datos: 8

La migración automática:
1. Agrega el campo `tipo_impuesto` a la tabla `productos`
2. Establece el valor por defecto `'G'` (General) para todos los productos existentes
3. Los productos existentes se consideran con IVA General (16%)

### Código de Migración
```dart
if (oldVersion < 8) {
  await db.execute('ALTER TABLE productos ADD COLUMN tipo_impuesto TEXT NOT NULL DEFAULT "G"');
}
```

## Uso del Sistema

### 1. Crear un Producto

Al crear o editar un producto:
1. Completar los datos básicos (código, nombre, precio, etc.)
2. Seleccionar el tipo de impuesto:
   - **General (G)**: Si el producto paga IVA 16%
   - **Exento (E)**: Si el producto está exento de IVA

### 2. Crear una Factura

Al agregar productos al carrito:
1. El sistema muestra el tipo de impuesto junto al nombre: `PRODUCTO (G)` o `PRODUCTO (E)`
2. Los cálculos se realizan automáticamente según el tipo
3. El resumen muestra el desglose completo

### 3. Verificar Cálculos

El sistema garantiza:
- ✅ Base Imponible solo incluye productos con IVA (G)
- ✅ IVA se calcula solo sobre la Base Imponible
- ✅ Monto Exento se suma al total sin IVA
- ✅ Retención de IVA (si aplica) se calcula sobre el IVA total

## Normativa SENIAT

Este sistema cumple con:
- **Artículo 27 de la Ley de IVA**: Productos exentos
- **Artículo 28 de la Ley de IVA**: Alícuota general del 16%
- **Providencia Administrativa SNAT/2005/0056**: Formato de facturas

### Requisitos de Facturación

Cada factura debe mostrar:
1. ✅ Identificación del tipo de impuesto por producto (E o G)
2. ✅ Base Imponible (suma de productos gravados)
3. ✅ Monto del IVA (16% sobre base imponible)
4. ✅ Monto Exento (suma de productos exentos)
5. ✅ Total a Pagar (suma de todos los conceptos)

## Ejemplos

### Ejemplo 1: Factura con productos mixtos

**Productos**:
- Arroz (E): $10.00
- Laptop (G): $500.00

**Cálculos**:
```
Base Imponible (G):  $500.00
IVA 16%:             $80.00
Monto Exento (E):    $10.00
─────────────────────────────
TOTAL A PAGAR:       $590.00
```

### Ejemplo 2: Factura solo con productos exentos

**Productos**:
- Leche (E): $5.00
- Pan (E): $3.00

**Cálculos**:
```
Monto Exento (E):    $8.00
─────────────────────────────
TOTAL A PAGAR:       $8.00
```

### Ejemplo 3: Factura con agente de retención

**Productos**:
- Laptop (G): $500.00

**Cliente**: Agente de Retención

**Cálculos**:
```
Base Imponible (G):  $500.00
IVA 16%:             $80.00
Retención IVA (75%): -$60.00
─────────────────────────────
TOTAL A PAGAR:       $520.00
```

## Mantenimiento

### Actualizar Alícuota de IVA

Si el SENIAT cambia la alícuota del IVA (actualmente 16%), actualizar en:

1. **Cálculo de IVA**:
   ```dart
   // lib/presentation/screens/create_document_screen.dart
   double get _iva {
     return _baseImponible * 0.16; // Cambiar 0.16 por nueva alícuota
   }
   ```

2. **Textos de UI**:
   - Actualizar "IVA 16%" en todos los lugares donde aparezca
   - Actualizar descripciones en el selector de tipo de impuesto

### Agregar Nuevos Tipos de Impuesto

Si se requieren nuevos tipos (ej: Reducido):

1. Agregar valor en base de datos: `'R'` para Reducido
2. Actualizar modelo `Producto` y `ProductModel`
3. Agregar opción en selector de tipo de impuesto
4. Actualizar cálculos para incluir el nuevo tipo
5. Actualizar visualización en facturas

## Soporte

Para dudas sobre normativa fiscal:
- **SENIAT**: http://www.seniat.gob.ve
- **Ley de IVA**: Gaceta Oficial N° 38.424

Para soporte técnico del sistema:
- Revisar logs en consola con prefijo `📊 Cálculos fiscales SENIAT:`
- Verificar campo `tipo_impuesto` en base de datos
- Validar cálculos en método `_saveInvoice`
