# Implementación de Cierre de Lote Ubii POS

## 📋 Descripción

El cierre de lote (Settlement) es el proceso que se ejecuta **UNA SOLA VEZ al final del día** para enviar todas las transacciones del día al banco para su procesamiento.

## 🗄️ Base de Datos

### Tabla: `cierres_lote`

Se creó una nueva tabla para registrar todos los cierres de lote realizados:

```sql
CREATE TABLE cierres_lote (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  fecha_creacion TEXT DEFAULT CURRENT_TIMESTAMP,
  usuario_id INTEGER NOT NULL,
  tipo_cierre TEXT NOT NULL,              -- 'Q' (inmediato) o 'N' (diferido)
  ubii_response_code TEXT,                -- Código de respuesta ('00' = exitoso)
  ubii_response_message TEXT,             -- Mensaje de respuesta
  ubii_terminal TEXT,                     -- ID del terminal
  ubii_lote TEXT,                         -- Número de lote cerrado
  ubii_fecha TEXT,                        -- Fecha del cierre
  ubii_hora TEXT,                         -- Hora del cierre
  total_transacciones INTEGER DEFAULT 0,  -- Total de transacciones en el lote
  monto_total REAL NOT NULL DEFAULT 0,    -- Monto total del lote
  datos_completos TEXT,                   -- JSON con todos los datos
  FOREIGN KEY (usuario_id) REFERENCES usuarios (id)
)
```

### Migración Automática

La base de datos se actualiza automáticamente de versión 2 a versión 3 sin perder datos.

## 🔧 Métodos Disponibles

### 1. DbHelper - Métodos CRUD

#### `registrarCierreLote()`
Registra un cierre de lote en la base de datos.

```dart
final cierreId = await DbHelper.instance.registrarCierreLote(
  usuarioId: 1,
  tipoCierre: 'Q', // 'Q' = inmediato, 'N' = diferido
  ubiiData: resultado, // Datos retornados por Ubii POS
);
```

#### `obtenerCierresLote()`
Obtiene todos los cierres con filtros opcionales.

```dart
// Todos los cierres
final cierres = await DbHelper.instance.obtenerCierresLote();

// Cierres de un rango de fechas
final cierres = await DbHelper.instance.obtenerCierresLote(
  desde: DateTime(2024, 1, 1),
  hasta: DateTime(2024, 1, 31),
  limit: 10,
);
```

#### `obtenerUltimoCierre()`
Obtiene el último cierre registrado.

```dart
final ultimoCierre = await DbHelper.instance.obtenerUltimoCierre();
if (ultimoCierre != null) {
  print('Último cierre: ${ultimoCierre['fecha_creacion']}');
  print('Lote: ${ultimoCierre['ubii_lote']}');
}
```

#### `obtenerCierresDeHoy()`
Obtiene todos los cierres realizados hoy.

```dart
final cierresHoy = await DbHelper.instance.obtenerCierresDeHoy();
print('Cierres hoy: ${cierresHoy.length}');
```

#### `yaSeHizoCierreHoy()`
Verifica si ya se realizó un cierre hoy.

```dart
final yaHizoCierre = await DbHelper.instance.yaSeHizoCierreHoy();
if (yaHizoCierre) {
  print('⚠️ Ya se realizó el cierre de hoy');
}
```

#### `obtenerEstadisticasCierres()`
Obtiene estadísticas generales de cierres.

```dart
final stats = await DbHelper.instance.obtenerEstadisticasCierres();
print('Total cierres: ${stats['total_cierres']}');
print('Monto acumulado: ${stats['monto_total_acumulado']}');
```

### 2. UbiiPosService - Métodos de Cierre

#### `cerrarLoteDelDia()`
Método principal para realizar el cierre de lote.

```dart
final ubiiService = UbiiPosService();

// Cierre inmediato (recomendado)
final resultado = await ubiiService.cerrarLoteDelDia(quick: true);

// Cierre diferido (siguiente día hábil)
final resultado = await ubiiService.cerrarLoteDelDia(quick: false);

if (resultado != null && resultado['code'] == '00') {
  print('✅ Cierre exitoso');
  print('Lote: ${resultado['lote']}');
  print('Total transacciones: ${resultado['totalTransactions']}');
  print('Monto total: ${resultado['totalAmount']}');
}
```

#### `necesitaCierreLote()`
Verifica si es necesario hacer cierre (después de cierta hora y no se ha hecho hoy).

```dart
// Verificar si necesita cierre (por defecto después de las 7 PM)
final necesita = await ubiiService.necesitaCierreLote();

// Personalizar hora de cierre (ej: 9 PM)
final necesita = await ubiiService.necesitaCierreLote(horaCierre: 21);

if (necesita) {
  print('⚠️ Es necesario realizar el cierre de lote');
}
```

#### `guardarFechaCierre()`
Guarda la fecha del último cierre (se llama automáticamente).

```dart
await ubiiService.guardarFechaCierre();
```

## 📱 Implementación en Pantalla Admin (Futuro)

### Ejemplo de Implementación Completa

```dart
class AdminCierreLoteScreen extends StatefulWidget {
  const AdminCierreLoteScreen({super.key});

  @override
  State<AdminCierreLoteScreen> createState() => _AdminCierreLoteScreenState();
}

class _AdminCierreLoteScreenState extends State<AdminCierreLoteScreen> {
  final UbiiPosService _ubiiService = UbiiPosService();
  bool _isProcessing = false;
  Map<String, dynamic>? _ultimoCierre;
  List<Map<String, dynamic>> _historialCierres = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final ultimoCierre = await DbHelper.instance.obtenerUltimoCierre();
    final historial = await DbHelper.instance.obtenerCierresLote(limit: 10);
    
    setState(() {
      _ultimoCierre = ultimoCierre;
      _historialCierres = historial;
    });
  }

  Future<void> _realizarCierre() async {
    // Verificar si ya se hizo cierre hoy
    final yaHizoCierre = await DbHelper.instance.yaSeHizoCierreHoy();
    
    if (yaHizoCierre) {
      _mostrarAlerta('Ya se realizó el cierre de hoy');
      return;
    }

    // Confirmar con el usuario
    final confirmar = await _mostrarDialogoConfirmacion();
    if (!confirmar) return;

    setState(() => _isProcessing = true);

    try {
      // Ejecutar cierre en Ubii POS
      final resultado = await _ubiiService.cerrarLoteDelDia(quick: true);

      if (resultado == null) {
        _mostrarError('No se recibió respuesta del POS');
        return;
      }

      if (resultado['code'] == '00') {
        // Cierre exitoso - Registrar en BD
        await DbHelper.instance.registrarCierreLote(
          usuarioId: 1, // ID del usuario actual
          tipoCierre: 'Q',
          ubiiData: resultado,
        );

        // Guardar fecha de cierre
        await _ubiiService.guardarFechaCierre();

        // Recargar datos
        await _cargarDatos();

        _mostrarExito(
          'Cierre de lote exitoso\n'
          'Lote: ${resultado['lote']}\n'
          'Transacciones: ${resultado['totalTransactions']}\n'
          'Monto: ${resultado['totalAmount']}'
        );
      } else if (resultado['code'] == 'CANCELLED') {
        _mostrarAlerta('Cierre cancelado por el usuario');
      } else {
        _mostrarError('Error: ${resultado['message']}');
      }
    } catch (e) {
      _mostrarError('Error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cierre de Lote'),
      ),
      body: Column(
        children: [
          // Botón de cierre
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _realizarCierre,
              icon: _isProcessing
                  ? const CircularProgressIndicator()
                  : const Icon(Icons.receipt_long),
              label: const Text('REALIZAR CIERRE DE LOTE'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 60),
              ),
            ),
          ),
          
          // Último cierre
          if (_ultimoCierre != null)
            Card(
              margin: const EdgeInsets.all(16),
              child: ListTile(
                title: const Text('Último Cierre'),
                subtitle: Text(
                  'Lote: ${_ultimoCierre!['ubii_lote']}\n'
                  'Fecha: ${_ultimoCierre!['fecha_creacion']}'
                ),
              ),
            ),
          
          // Historial
          Expanded(
            child: ListView.builder(
              itemCount: _historialCierres.length,
              itemBuilder: (context, index) {
                final cierre = _historialCierres[index];
                return ListTile(
                  title: Text('Lote: ${cierre['ubii_lote']}'),
                  subtitle: Text(cierre['fecha_creacion']),
                  trailing: Text('\$${cierre['monto_total']}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

## 🎯 Flujo Recomendado

### Diario (Durante el día)
1. Los usuarios procesan pagos normalmente con `processPayment()`
2. Cada transacción se guarda en la memoria del POS (el lote)
3. Las facturas se guardan en la BD de la app

### Al Final del Día (7:00 PM - 9:00 PM)
1. El administrador abre la pantalla de cierre de lote
2. La app verifica si ya se hizo cierre hoy
3. Si no se ha hecho, muestra el botón habilitado
4. El admin presiona "REALIZAR CIERRE DE LOTE"
5. La app muestra diálogo de confirmación
6. Se ejecuta `cerrarLoteDelDia(quick: true)`
7. El POS procesa el cierre y retorna los datos
8. La app registra el cierre en la BD
9. El POS imprime el reporte automáticamente
10. El dinero se envía al banco esa misma noche

## ⚠️ Notas Importantes

### 1. Una Sola Vez al Día
- El cierre de lote debe ejecutarse **UNA SOLA VEZ** al final del día
- Si se ejecuta múltiples veces, puede causar problemas con el banco
- La app verifica automáticamente si ya se hizo cierre hoy

### 2. Tipos de Cierre

#### Liquidación Inmediata (Q) - Recomendado
```dart
await ubiiService.cerrarLoteDelDia(quick: true);
```
- El banco procesa el dinero esa misma noche
- Disponible en 24-48 horas
- Usar de lunes a viernes

#### Liquidación Diferida (N)
```dart
await ubiiService.cerrarLoteDelDia(quick: false);
```
- El banco procesa el siguiente día hábil
- Útil para fines de semana
- El dinero tarda un poco más

### 3. Reporte Impreso
- El POS Ubii imprime automáticamente el reporte de cierre
- Contiene todas las transacciones del día
- Guardar este reporte para auditoría

### 4. Datos Guardados
Cada cierre guarda:
- ✅ Código de respuesta
- ✅ Terminal y lote
- ✅ Fecha y hora
- ✅ Total de transacciones
- ✅ Monto total
- ✅ Usuario que realizó el cierre
- ✅ Datos completos en JSON

## 🔍 Debugging

### Logs del Cierre

```
📊 ========================================
📊 INICIANDO CIERRE DE LOTE DEL DÍA
📊 ========================================
📊 Tipo: Liquidación Inmediata (Q)
📊 Fecha: 2024-01-15 19:30:00.000
📊 ========================================
📊 RESULTADO DEL CIERRE
📊 ========================================
📊 Código: 00
📊 Mensaje: APROBADO
✅ ========================================
✅ CIERRE DE LOTE EXITOSO
✅ ========================================
✅ Terminal: T001
✅ Lote: 001
✅ Fecha: 15/01/2024
✅ Hora: 19:30
✅ Total Transacciones: 25
✅ Monto Total: 15000.50
✅ ========================================
✅ El dinero está en camino al banco
✅ El POS imprimirá el reporte automáticamente
✅ ========================================
```

## 📊 Consultas Útiles

### Ver todos los cierres del mes
```dart
final primerDia = DateTime(2024, 1, 1);
final ultimoDia = DateTime(2024, 1, 31, 23, 59, 59);

final cierres = await DbHelper.instance.obtenerCierresLote(
  desde: primerDia,
  hasta: ultimoDia,
);
```

### Calcular total del mes
```dart
final stats = await DbHelper.instance.obtenerEstadisticasCierres();
print('Total acumulado: \$${stats['monto_total_acumulado']}');
```

### Verificar si falta hacer cierre
```dart
final necesita = await ubiiService.necesitaCierreLote();
if (necesita) {
  // Mostrar notificación al admin
  print('⚠️ Recordatorio: Realizar cierre de lote');
}
```

## 🚀 Próximos Pasos

1. ✅ Base de datos actualizada (versión 3)
2. ✅ Métodos CRUD implementados
3. ✅ Servicio de cierre implementado
4. ⏳ Crear pantalla de administración
5. ⏳ Implementar notificaciones de recordatorio
6. ⏳ Agregar reportes de cierres
7. ⏳ Implementar exportación de datos

## 📞 Soporte

La implementación está lista para ser usada en la pantalla de administración que crearás más adelante.
