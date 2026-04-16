# ⚡ Guía Rápida - Qué Mostrar en la Reunión

Esta es tu guía de referencia rápida durante la reunión. Mantén este documento visible en tu pantalla o impreso.

---

## 📋 Archivos a Tener Abiertos

Antes de la reunión, abre estos archivos en tu editor:

1. ✅ `lib/services/ubii_pos_service.dart`
2. ✅ `android/app/src/main/kotlin/com/pos/pos_android/MainActivity.kt`
3. ✅ `lib/core/app_config.dart`
4. ✅ `.env`
5. ✅ Este documento (GUIA_RAPIDA_REUNION.md)

---

## 🎬 Flujo de la Reunión

### 1️⃣ INTRODUCCIÓN (5 min)

**Qué decir**:
```
"Soy [tu nombre], desarrollador de POS Android, un sistema de punto de venta 
para comercios en Venezuela. Estoy integrando Pago Móvil usando Ubii y ya 
tengo la implementación lista. Necesito que autoricen mi dominio y me 
proporcionen algunos datos para completar la configuración."
```

**Qué mostrar**: Nada aún, solo presentación verbal.

---

### 2️⃣ DEMOSTRACIÓN DE LA APP (10 min)

**Si preguntan**: "¿Qué tipo de aplicación es?"

**Qué mostrar**: 
- Abre la app en tu dispositivo o emulador
- Muestra la pantalla de login
- Muestra la pantalla de documentos/ventas
- Explica: "Es un POS completo con inventario, ventas, facturación y múltiples métodos de pago"

**Archivo**: La app corriendo (si es posible)

---

### 3️⃣ CONFIGURACIÓN ACTUAL (5 min)

**Si preguntan**: "¿Ya tienes configurado algo?"

**Qué mostrar**: Archivo `.env`

**Líneas específicas**:
```env
UBII_CLIENT_ID=f4e1553b-a2f7-11f0-afbe-005056965434
UBII_CLIENT_DOMAIN=com.pos.pos_android
UBII_BASE_URL=https://botonc.ubiipagos.com
```

**Qué decir**:
```
"Ya tengo configurado el Client ID que me proporcionaron y el dominio 
com.pos.pos_android. Solo necesito que autoricen este dominio para 
poder empezar a hacer pruebas."
```

---

### 4️⃣ IMPLEMENTACIÓN TÉCNICA (15 min)

#### A) Si preguntan: "¿Cómo implementaste la integración?"

**Qué mostrar**: `lib/services/ubii_pos_service.dart`

**Ir a la línea 40** (método `processPayment`):
```dart
Future<Map<String, dynamic>?> processPayment(
  double amount, {
  bool? withLogon,
}) async {
  final bool needsLogon = withLogon ?? await isFirstTransactionOfDay();
  final String formattedAmount = formatAmount(amount);
  
  // Llamar al método nativo...
}
```

**Qué decir**:
```
"Implementé un servicio que:
1. Detecta automáticamente si es la primera transacción del día
2. Formatea el monto correctamente (sin decimales)
3. Se comunica con código nativo Android
4. Maneja todos los códigos de respuesta de Ubii"
```

---

#### B) Si preguntan: "¿Cómo manejas los errores?"

**Qué mostrar**: `lib/services/ubii_pos_service.dart`

**Ir a la línea 70** (manejo de códigos):
```dart
if (code == '00') {
  // ✅ Transacción APROBADA
  await saveTransactionDate();
} else if (code == '51') {
  // ❌ Fondos insuficientes
  response['message'] = 'Fondos insuficientes en la tarjeta.';
} else if (code == '04') {
  // ❌ No honrar
  response['message'] = 'Tarjeta no honrada. Contacte a su banco.';
}
// ... más códigos
```

**Qué decir**:
```
"Implementé manejo completo de códigos de respuesta:
- Código 00: Aprobado
- Código 51: Fondos insuficientes
- Código 04: No honrar
- Y más de 15 códigos diferentes con mensajes claros para el cajero"
```

---

#### C) Si preguntan: "¿Cómo te comunicas con Ubii?"

**Qué mostrar**: `android/app/src/main/kotlin/com/pos/pos_android/MainActivity.kt`

**Ir a la línea 40** (método `launchUbiiPOS`):
```kotlin
private fun launchUbiiPOS(amount: String, logon: String) {
    val intent = Intent().apply {
        action = "com.ubiipagos.pos.views.activity.MainActivityView.launchFromOutside"
        putExtra("TRANS_TYPE", "PAYMENT")
        putExtra("TRANS_AMOUNT", amount)
        putExtra("LOGON", logon)
    }
    startActivityForResult(intent, UBII_REQUEST_CODE)
}
```

**Qué decir**:
```
"Uso código nativo Android para lanzar un Intent hacia la app de Ubii.
Envío el monto y si necesita logon, y espero el resultado con 
onActivityResult. Es la forma estándar de integración entre apps Android."
```

---

#### D) Si preguntan: "¿Implementaste el cierre de lote?"

**Qué mostrar**: `lib/services/ubii_pos_service.dart`

**Ir a la línea 200** (método `cerrarLoteDelDia`):
```dart
Future<Map<String, dynamic>?> cerrarLoteDelDia({bool quick = true}) async {
  debugPrint('📊 INICIANDO CIERRE DE LOTE DEL DÍA');
  
  final resultado = await processSettlement(quick: quick);
  
  if (resultado['code'] == '00') {
    debugPrint('✅ CIERRE DE LOTE EXITOSO');
    await guardarFechaCierre();
  }
  
  return resultado;
}
```

**Qué decir**:
```
"Sí, implementé cierre de lote con:
- Detección automática si ya pasó la hora de cierre (7 PM)
- Verificación si ya se hizo cierre hoy
- Opción de liquidación inmediata (Q) o diferida (N)
- Guardado de fecha del último cierre"
```

---

### 5️⃣ DOMINIO Y AUTORIZACIÓN (10 min)

**Si preguntan**: "¿Cuál es el dominio que necesitas autorizar?"

**Qué mostrar**: Archivo `.env` línea 24:
```env
UBII_CLIENT_DOMAIN=com.pos.pos_android
```

**Qué decir**:
```
"El dominio es: com.pos.pos_android

Este es el package name de mi aplicación Android. Es el identificador 
único de la app en el sistema Android y en Google Play Store."
```

**Qué preguntar**:
```
"¿Cuándo estará autorizado este dominio?
¿Necesito hacer algo adicional de mi parte?
¿Cómo sabré cuando esté activo?"
```

---

### 6️⃣ PAGO MÓVIL (10 min)

**Si preguntan**: "¿Cómo funciona el flujo de Pago Móvil?"

**Qué decir**:
```
"El flujo es el siguiente:

1. Cliente compra en mi comercio por Bs. 150
2. Cajero proporciona al cliente los datos del comercio:
   - Teléfono: 0424-1234567
   - Cédula/RIF: J-30792822-0
3. Cliente realiza Pago Móvil desde su app bancaria
4. Cliente recibe REFERENCIA del pago (ej: 123456789)
5. Cliente proporciona al cajero:
   - Su teléfono: 0414-9876543
   - Su cédula: V-12345678
   - Referencia: 123456789
6. Cajero ingresa estos datos en mi app
7. Mi app envía los datos a Ubii para validación
8. Ubii verifica con el banco que el pago existe y es correcto
9. Si es válido, se aprueba la venta y se genera la factura

Necesito que Ubii valide:
- Que la referencia existe
- Que el monto coincide
- Que los datos del cliente son correctos
- Que no es un pago duplicado"
```

**Qué mostrar**: Diagrama en `REUNION_UBII_ARCHIVOS_CLAVE.md` (sección "Diagrama de Flujo")

---

### 7️⃣ DATOS QUE NECESITAS (5 min)

**Qué preguntar**:

1. **Teléfono del Comercio**:
```
"¿Qué teléfono debo configurar para Pago Móvil?
¿Es el teléfono registrado en mi banco?"
```

**Mostrar**: `.env` línea 30:
```env
PAGO_MOVIL_TELEFONO=00584XXXXXXXXX  # ← Necesito este dato
```

2. **Documentación**:
```
"¿Pueden proporcionarme la documentación completa de la API?
Necesito:
- Endpoints disponibles
- Estructura de requests y responses
- Códigos de error completos
- Ejemplos de payloads"
```

3. **Ambiente de Pruebas**:
```
"¿Tienen un ambiente de pruebas (sandbox)?
¿Cómo puedo probar sin hacer transacciones reales?"
```

---

### 8️⃣ PRÓXIMOS PASOS (5 min)

**Qué decir**:
```
"Una vez que autoricen mi dominio, mi plan es:

1. Probar autenticación con /auth
2. Probar obtención de keys con /get_keys
3. Realizar transacciones de prueba con montos pequeños
4. Hacer pruebas exhaustivas
5. Lanzar en producción

¿Cuánto tiempo estiman que tome la autorización del dominio?
¿Hay algo más que necesite hacer de mi parte?"
```

---

## 🚨 RESPUESTAS RÁPIDAS A PREGUNTAS COMUNES

### "¿Qué framework usas?"
```
Flutter 3.x con Dart. Es multiplataforma pero esta versión es solo Android.
```

### "¿Dónde guardas las credenciales?"
```
En un archivo .env que no se sube a Git. Uso variables de entorno por seguridad.
```

**Mostrar**: `.env` y mencionar que está en `.gitignore`

### "¿Cómo manejas la seguridad?"
```
- Credenciales en .env (no en código)
- Validación de configuración antes de procesar pagos
- Manejo de errores exhaustivo
- Logging detallado para debugging
- Base de datos local encriptada
```

### "¿Cuántas transacciones esperas procesar?"
```
Inicialmente 10-20 transacciones diarias. Potencial de crecimiento a 100+ diarias.
```

### "¿Tienes experiencia con integraciones similares?"
```
Sí, ya integré [menciona otras integraciones si las tienes, o di]:
"Esta es mi primera integración con Ubii pero tengo experiencia con 
integraciones de APIs y sistemas de pago."
```

---

## 📝 CHECKLIST DURANTE LA REUNIÓN

Marca cada punto cuando lo completes:

- [ ] Presenté la aplicación
- [ ] Mostré la configuración actual
- [ ] Expliqué la implementación técnica
- [ ] Solicité autorización del dominio
- [ ] Expliqué el propósito del teléfono/cédula
- [ ] Solicité documentación completa
- [ ] Pregunté por ambiente de pruebas
- [ ] Obtuve teléfono del comercio
- [ ] Obtuve contacto de soporte técnico
- [ ] Definí próximos pasos
- [ ] Agendé seguimiento

---

## 📞 INFORMACIÓN DE CONTACTO

**Tu información** (para compartir con Ubii):
- **Nombre**: [Tu nombre]
- **Email**: [Tu email]
- **Teléfono**: [Tu teléfono]
- **Empresa**: KLK Sistemas, C.A.
- **RIF**: J-30792822-0

**Datos de la app**:
- **Package Name**: com.pos.pos_android
- **Client ID**: f4e1553b-a2f7-11f0-afbe-005056965434

---

## 🎯 OBJETIVO DE LA REUNIÓN

Al terminar, debes tener:
1. ✅ Confirmación de autorización del dominio (o fecha estimada)
2. ✅ Teléfono del comercio para Pago Móvil
3. ✅ Documentación de la API (o compromiso de envío)
4. ✅ Contacto de soporte técnico
5. ✅ Próximos pasos claros

---

## 💡 TIPS FINALES

1. **Sé conciso**: No expliques de más, responde lo que pregunten
2. **Muestra confianza**: Ya tienes todo implementado, solo necesitas autorización
3. **Toma notas**: Anota TODO lo que te digan
4. **Pregunta**: Si algo no está claro, pregunta inmediatamente
5. **Confirma**: Al final, resume los acuerdos y próximos pasos

---

**¡Éxito en tu reunión! 🚀**

**Recuerda**: Ya tienes todo listo. Solo necesitas la autorización y algunos datos finales.
