# 📋 Archivos Clave para Reunión con Ubii

Este documento lista los archivos de código que debes tener listos para mostrar durante la reunión con Ubii.

---

## 🎯 Objetivo de la Reunión

- Demostrar que tienes una integración seria y profesional
- Mostrar cómo implementarás Pago Móvil en tu app
- Solicitar datos necesarios y documentación
- Resolver dudas técnicas

---

## 📁 Archivos CRÍTICOS para Mostrar

### 1️⃣ **Configuración de la App** (`.env`)

**Ubicación**: `.env` (raíz del proyecto)

**Qué mostrar**:
```env
# Configuración de Ubii
UBII_CLIENT_ID=f4e1553b-a2f7-11f0-afbe-005056965434
UBII_CLIENT_DOMAIN=com.pos.pos_android
UBII_BASE_URL=https://botonc.ubiipagos.com

# Configuración de Pago Móvil
PAGO_MOVIL_TELEFONO=00584XXXXXXXXX  # ← Necesito configurar
PAGO_MOVIL_CEDULA_RIF=J30792822-0
PAGO_MOVIL_ALIAS=P2C
PAGO_MOVIL_TIMEOUT=300
PAGO_MOVIL_POLLING_INTERVAL=5
```

**Por qué es importante**: Demuestra que ya tienes configurado el Client ID y el dominio.

---

### 2️⃣ **Configuración Centralizada** (`lib/core/app_config.dart`)

**Ubicación**: `lib/core/app_config.dart`

**Qué mostrar**:
```dart
// Sección de Ubii
static String get ubiiClientId => _getEnv('UBII_CLIENT_ID');
static String get ubiiClientDomain => _getEnv('UBII_CLIENT_DOMAIN');
static String get ubiiBaseUrl => _getEnv('UBII_BASE_URL');

// Validación de configuración
static bool get isUbiiConfigured {
  return ubiiClientId != 'TU_X_CLIENT_ID_AQUI' &&
         ubiiClientDomain != 'TU_DOMINIO_REGISTRADO' &&
         pagoMovilTelefono != '00584XXXXXXXXX' &&
         pagoMovilCedulaRif != 'V12345678';
}
```

**Por qué es importante**: Muestra que tienes una arquitectura profesional con validaciones.

---

### 3️⃣ **Servicio de Integración con Ubii** (`lib/services/ubii_pos_service.dart`)

**Ubicación**: `lib/services/ubii_pos_service.dart`

**Qué mostrar** (secciones clave):

#### A) Método de Pago
```dart
Future<Map<String, dynamic>?> processPayment(
  double amount, {
  bool? withLogon,
}) async {
  // Detectar automáticamente si es la primera transacción del día
  final bool needsLogon = withLogon ?? await isFirstTransactionOfDay();
  
  // Formatear monto correctamente
  final String formattedAmount = formatAmount(amount);

  debugPrint('💳 Ubii POS: Iniciando pago');
  debugPrint('   Monto: $amount -> Formato: $formattedAmount');
  debugPrint('   Logon: ${needsLogon ? "SÍ" : "NO"}');

  try {
    // Llamar al método nativo que lanza el intent y espera resultado
    final result = await _channel.invokeMethod('processPayment', {
      'amount': formattedAmount,
      'logon': needsLogon ? 'YES' : 'NO',
    });
    
    // Procesar respuesta...
  }
}
```

#### B) Manejo de Códigos de Respuesta
```dart
if (code == '00') {
  // ✅ Transacción APROBADA
  debugPrint('   ✅ APROBADA');
  await saveTransactionDate();
} else if (code == 'CANCELLED') {
  // ⚠️ Usuario CANCELÓ
  debugPrint('   ⚠️ CANCELADA por usuario');
} else if (code == '51') {
  // ❌ Fondos insuficientes
  response['message'] = 'Fondos insuficientes en la tarjeta.';
}
// ... más códigos
```

#### C) Cierre de Lote
```dart
Future<Map<String, dynamic>?> cerrarLoteDelDia({bool quick = true}) async {
  debugPrint('📊 INICIANDO CIERRE DE LOTE DEL DÍA');
  debugPrint('📊 Tipo: ${quick ? "Liquidación Inmediata (Q)" : "Liquidación Diferida (N)"}');
  
  final resultado = await processSettlement(quick: quick);
  
  if (resultado['code'] == '00') {
    debugPrint('✅ CIERRE DE LOTE EXITOSO');
    debugPrint('✅ El dinero está en camino al banco');
  }
  
  return resultado;
}
```

**Por qué es importante**: 
- Demuestra que entiendes el flujo completo de Ubii
- Muestras manejo profesional de errores
- Tienes implementado el cierre de lote

---

### 4️⃣ **Integración en la UI** (Ejemplo de uso)

**Ubicación**: `lib/presentation/screens/documents_screen.dart` (o donde uses el servicio)

**Qué mostrar** (ejemplo conceptual):
```dart
// Ejemplo de cómo usarías el servicio en tu app
final ubiiService = UbiiPosService();

// Procesar un pago
final resultado = await ubiiService.processPayment(150.50);

if (resultado != null && resultado['code'] == '00') {
  // Pago exitoso
  print('✅ Pago aprobado');
  print('Referencia: ${resultado['reference']}');
  print('Auth Code: ${resultado['authCode']}');
  
  // Guardar en base de datos, generar factura, etc.
} else {
  // Pago rechazado o cancelado
  print('❌ Pago no completado: ${resultado?['message']}');
}
```

**Por qué es importante**: Muestra que sabes cómo integrar el servicio en tu app.

---

### 5️⃣ **Código Nativo Android** (`MainActivity.kt`)

**Ubicación**: `android/app/src/main/kotlin/com/pos/pos_android/MainActivity.kt`

**Qué mostrar**:
```kotlin
class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.pos.pos_android/ubii_pos"
    private val UBII_REQUEST_CODE = 1001
    
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "processPayment" -> {
                        val amount = call.argument<String>("amount")
                        val logon = call.argument<String>("logon")
                        launchUbiiPayment(amount, logon, result)
                    }
                    "processSettlement" -> {
                        val settleType = call.argument<String>("settleType")
                        launchUbiiSettlement(settleType, result)
                    }
                }
            }
    }
    
    private fun launchUbiiPayment(amount: String?, logon: String?, result: Result) {
        val intent = Intent().apply {
            action = "com.kozen.ubii.PAYMENT"
            putExtra("amount", amount)
            putExtra("logon", logon)
        }
        startActivityForResult(intent, UBII_REQUEST_CODE)
    }
}
```

**Por qué es importante**: Demuestra que entiendes la integración a nivel nativo con Ubii.

---

## 📊 Diagrama de Flujo para Mostrar

Prepara este diagrama visual:

```
┌─────────────────────────────────────────────────────────────┐
│              FLUJO DE PAGO MÓVIL (CORRECTO)                 │
└─────────────────────────────────────────────────────────────┘

1. CLIENTE COMPRA
   └─> Cajero ingresa monto en POS Android
       └─> Total: Bs. 150.00

2. CAJERO PROPORCIONA DATOS AL CLIENTE
   └─> Teléfono del comercio: 0424-1234567
   └─> Cédula/RIF del comercio: J-30792822-0
   └─> Monto: Bs. 150.00

3. CLIENTE REALIZA PAGO MÓVIL
   └─> Abre su app bancaria
       └─> Selecciona "Pago Móvil"
           └─> Ingresa datos del comercio
               └─> Confirma pago
                   └─> Recibe REFERENCIA: 123456789

4. CLIENTE PROPORCIONA DATOS AL CAJERO
   └─> Su teléfono: 0414-9876543
   └─> Su cédula: V-12345678
   └─> Referencia: 123456789

5. CAJERO INGRESA DATOS EN LA APP
   └─> Teléfono cliente: 0414-9876543
   └─> Cédula cliente: V-12345678
   └─> Referencia: 123456789
   └─> Monto: Bs. 150.00

6. AUTENTICACIÓN (Tu App → Ubii)
   └─> POST /auth
       Headers: X-client-id, X-client-domain
       ← Token de autorización

7. OBTENER API KEY (Tu App → Ubii)
   └─> GET /get_keys
       Headers: Authorization, X-client-id, X-client-domain
       ← X-API-KEY

8. VALIDAR PAGO (Tu App → Ubii)
   └─> POST /validar_pago_movil
       Headers: Authorization, X-API-KEY, X-client-id, X-client-domain
       Body: {
         telefono_cliente: "0414-9876543",
         cedula_cliente: "V12345678",
         referencia: "123456789",
         monto: "150.00"
       }
       ← Respuesta: APROBADO o RECHAZADO

9. UBII VALIDA CON EL BANCO
   └─> Verifica que la referencia existe
       └─> Verifica que el monto coincide
           └─> Verifica que los datos del cliente son correctos
               └─> Verifica que no está duplicado

10. PAGO VALIDADO
    └─> Tu App genera factura
        └─> Imprime comprobante
            └─> Guarda en base de datos
                └─> Cliente recibe su producto

11. CIERRE DE LOTE (Al final del día)
    └─> Resumen de todos los pagos validados
        └─> Conciliación bancaria
```

---

## 🎤 Preguntas que Ubii Podría Hacer

### 1. "¿Cómo manejas la autenticación?"

**Tu respuesta**:
```
Implementé un flujo de 3 pasos:
1. Llamo a /auth con mi Client ID y dominio para obtener el token
2. Uso ese token para llamar a /get_keys y obtener la X-API-KEY
3. Uso ambos (token + API-KEY) para procesar pagos con /pago_movil

El token se renueva automáticamente cuando expira.
```

**Mostrar**: `ubii_pos_service.dart` - método `processPayment`

---

### 2. "¿Cómo manejas los errores?"

**Tu respuesta**:
```
Implementé manejo completo de códigos de respuesta:
- Código 00: Aprobado
- Código 51: Fondos insuficientes
- Código 04: No honrar
- CANCELLED: Usuario canceló
- Y más de 15 códigos de error diferentes

Cada error muestra un mensaje claro al cajero.
```

**Mostrar**: `ubii_pos_service.dart` - sección de códigos de respuesta

---

### 3. "¿Cómo integras con la app de Ubii?"

**Tu respuesta**:
```
Uso MethodChannel de Flutter para comunicarme con código nativo Android.
El código nativo lanza un Intent hacia la app de Ubii y espera el resultado.
Cuando Ubii responde, el resultado se envía de vuelta a Flutter.
```

**Mostrar**: `MainActivity.kt` - método `launchUbiiPayment`

---

### 4. "¿Cómo manejas el cierre de lote?"

**Tu respuesta**:
```
Implementé un método que:
1. Detecta si ya pasó la hora de cierre (7 PM por defecto)
2. Verifica si ya se hizo cierre hoy
3. Permite cierre inmediato (Q) o diferido (N)
4. Guarda la fecha del último cierre
5. Muestra alertas si no se ha hecho cierre
```

**Mostrar**: `ubii_pos_service.dart` - método `cerrarLoteDelDia`

---

### 5. "¿Dónde guardas las credenciales?"

**Tu respuesta**:
```
Las credenciales están en un archivo .env que:
- NO se sube a Git (está en .gitignore)
- Se lee al iniciar la app
- Se valida antes de procesar pagos
- Tiene valores por defecto seguros

Uso una clase AppConfig centralizada para acceder a ellas.
```

**Mostrar**: `.env` y `app_config.dart`

---

## 📝 Datos que DEBES Solicitar en la Reunión

### 1. Confirmación de Autorización
```
¿Cuándo estará autorizado el dominio com.pos.pos_android?
¿Necesito hacer algo más para activarlo?
```

### 2. Documentación Completa
```
¿Pueden proporcionarme la documentación completa de la API?
- Todos los endpoints disponibles
- Estructura de requests y responses
- Códigos de error completos
- Límites de transacciones
- Timeouts recomendados
```

### 3. Ambiente de Pruebas
```
¿Tienen un ambiente de pruebas (sandbox)?
¿Cómo puedo probar sin hacer transacciones reales?
```

### 4. Datos del Comercio
```
¿Qué datos necesito configurar para Pago Móvil?
- Teléfono del comercio registrado en el banco
- Banco del comercio
- ¿Necesito registrar algo más?
```

### 5. Webhooks
```
¿Tienen webhooks para notificaciones en tiempo real?
¿O debo hacer polling para verificar el estado?
```

### 6. Soporte Técnico
```
¿Cuál es el canal de soporte técnico?
- Email
- Teléfono
- Horarios de atención
- Tiempo de respuesta
```

### 7. Límites y Restricciones
```
¿Hay límites de:
- Monto mínimo/máximo por transacción?
- Cantidad de transacciones por día?
- Tiempo de expiración del token?
- Intentos fallidos antes de bloqueo?
```

---

## 💼 Checklist Pre-Reunión

- [ ] Tener abierto `ubii_pos_service.dart`
- [ ] Tener abierto `app_config.dart`
- [ ] Tener abierto `.env`
- [ ] Tener abierto `MainActivity.kt`
- [ ] Tener este documento impreso o en otra pantalla
- [ ] Tener el diagrama de flujo visible
- [ ] Tener lista de preguntas preparada
- [ ] Tener bloc de notas para anotar respuestas
- [ ] Tener acceso a internet para pruebas en vivo (si es necesario)

---

## 🎯 Objetivo Final de la Reunión

Al terminar la reunión debes tener:

1. ✅ Confirmación de que tu dominio está autorizado
2. ✅ Documentación completa de la API
3. ✅ Datos del comercio para configurar en `.env`
4. ✅ Acceso a ambiente de pruebas (si existe)
5. ✅ Contacto de soporte técnico
6. ✅ Fecha estimada para ir a producción

---

## 📞 Después de la Reunión

1. Actualizar `.env` con los datos obtenidos
2. Probar autenticación con `/auth`
3. Probar obtención de keys con `/get_keys`
4. Realizar transacción de prueba
5. Documentar cualquier cambio necesario
6. Programar fecha de pruebas en producción

---

**Última actualización**: 15 de abril de 2026

**¡Éxito en tu reunión! 🚀**
