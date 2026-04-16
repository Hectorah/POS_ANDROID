# 💳 Flujo Correcto de Pago Móvil con Ubii

## ✅ Flujo Real (Validación de Pago)

Este documento describe el flujo CORRECTO de Pago Móvil con Ubii, donde el cliente realiza el pago primero y luego Ubii valida que el pago existe.

---

## 🔄 Diagrama del Flujo

```
┌─────────────────────────────────────────────────────────────────┐
│                    FLUJO DE PAGO MÓVIL                          │
│                  (Validación de Referencia)                     │
└─────────────────────────────────────────────────────────────────┘

┌──────────────┐
│   CLIENTE    │
│   COMPRA     │
│  Bs. 150.00  │
└──────┬───────┘
       │
       ▼
┌──────────────────────────────────────────────────────────┐
│  CAJERO PROPORCIONA DATOS DEL COMERCIO AL CLIENTE       │
├──────────────────────────────────────────────────────────┤
│  • Teléfono: 0424-1234567                                │
│  • Cédula/RIF: J-30792822-0                              │
│  • Monto: Bs. 150.00                                     │
└──────┬───────────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────────┐
│  CLIENTE REALIZA PAGO MÓVIL DESDE SU APP BANCARIA        │
├──────────────────────────────────────────────────────────┤
│  1. Abre app de su banco                                 │
│  2. Selecciona "Pago Móvil"                              │
│  3. Ingresa:                                             │
│     - Teléfono destino: 0424-1234567                     │
│     - Cédula/RIF destino: J-30792822-0                   │
│     - Monto: Bs. 150.00                                  │
│  4. Confirma el pago                                     │
│  5. Recibe REFERENCIA: 123456789                         │
└──────┬───────────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────────┐
│  CLIENTE PROPORCIONA DATOS AL CAJERO                     │
├──────────────────────────────────────────────────────────┤
│  • Mi teléfono: 0414-9876543                             │
│  • Mi cédula: V-12345678                                 │
│  • Referencia: 123456789                                 │
└──────┬───────────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────────┐
│  CAJERO INGRESA DATOS EN LA APP POS                      │
├──────────────────────────────────────────────────────────┤
│  • Teléfono cliente: 0414-9876543                        │
│  • Cédula cliente: V-12345678                            │
│  • Referencia: 123456789                                 │
│  • Monto: Bs. 150.00                                     │
│  • Presiona "Validar Pago"                               │
└──────┬───────────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────────┐
│  APP POS → UBII (Autenticación)                          │
├──────────────────────────────────────────────────────────┤
│  POST /auth                                              │
│  Headers:                                                │
│    X-client-id: f4e1553b-a2f7-11f0-afbe-005056965434     │
│    X-client-domain: com.pos.pos_android                  │
│  Response: Token de autorización                         │
└──────┬───────────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────────┐
│  APP POS → UBII (Obtener API Key)                        │
├──────────────────────────────────────────────────────────┤
│  GET /get_keys                                           │
│  Headers:                                                │
│    Authorization: Bearer {token}                         │
│    X-client-id: f4e1553b-a2f7-11f0-afbe-005056965434     │
│    X-client-domain: com.pos.pos_android                  │
│  Response: X-API-KEY                                     │
└──────┬───────────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────────┐
│  APP POS → UBII (Validar Pago Móvil)                     │
├──────────────────────────────────────────────────────────┤
│  POST /validar_pago_movil (o endpoint similar)           │
│  Headers:                                                │
│    Authorization: Bearer {token}                         │
│    X-API-KEY: {api_key}                                  │
│    X-client-id: f4e1553b-a2f7-11f0-afbe-005056965434     │
│    X-client-domain: com.pos.pos_android                  │
│  Body:                                                   │
│    {                                                     │
│      "telefono_cliente": "04149876543",                  │
│      "cedula_cliente": "V12345678",                      │
│      "referencia": "123456789",                          │
│      "monto": "150.00"                                   │
│    }                                                     │
└──────┬───────────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────────┐
│  UBII → BANCO (Validación)                               │
├──────────────────────────────────────────────────────────┤
│  Ubii consulta al banco:                                 │
│  ✓ ¿Existe la referencia 123456789?                      │
│  ✓ ¿El monto es Bs. 150.00?                              │
│  ✓ ¿El teléfono es 0414-9876543?                         │
│  ✓ ¿La cédula es V-12345678?                             │
│  ✓ ¿El destino es J-30792822-0?                          │
│  ✓ ¿No está duplicado?                                   │
└──────┬───────────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────────┐
│  UBII → APP POS (Respuesta)                              │
├──────────────────────────────────────────────────────────┤
│  Response:                                               │
│  {                                                       │
│    "code": "00",                                         │
│    "message": "Pago validado correctamente",             │
│    "referencia": "123456789",                            │
│    "monto": "150.00",                                    │
│    "fecha": "2026-04-15",                                │
│    "hora": "14:30:25"                                    │
│  }                                                       │
└──────┬───────────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────────┐
│  APP POS PROCESA RESPUESTA                               │
├──────────────────────────────────────────────────────────┤
│  Si code == "00":                                        │
│    ✅ Pago VALIDADO                                      │
│    → Generar factura                                     │
│    → Imprimir comprobante                                │
│    → Guardar en base de datos                            │
│    → Entregar producto al cliente                        │
│                                                          │
│  Si code != "00":                                        │
│    ❌ Pago RECHAZADO                                     │
│    → Mostrar mensaje de error                            │
│    → Solicitar nuevo pago                                │
└──────────────────────────────────────────────────────────┘
```

---

## 📝 Datos Necesarios

### Datos del COMERCIO (configurados en `.env`):

```env
# Estos datos los proporciona el cajero al cliente
PAGO_MOVIL_TELEFONO=0424-1234567
PAGO_MOVIL_CEDULA_RIF=J30792822-0
```

### Datos del CLIENTE (ingresados por el cajero):

```
• Teléfono del cliente: 0414-9876543
• Cédula del cliente: V-12345678
• Referencia del pago: 123456789
• Monto: Bs. 150.00
```

---

## 🔍 Validaciones que Realiza Ubii

1. **Existencia de la referencia**: Verifica que el número de referencia existe en el sistema bancario
2. **Coincidencia de monto**: Confirma que el monto pagado coincide con el solicitado
3. **Datos del cliente**: Valida que el teléfono y cédula del cliente son correctos
4. **Destino correcto**: Verifica que el pago fue hecho a los datos del comercio
5. **No duplicación**: Confirma que la referencia no ha sido usada antes
6. **Estado del pago**: Verifica que el pago fue exitoso en el banco

---

## ❓ Preguntas Críticas para Ubii

### 1. Endpoint de Validación
```
¿Cuál es el endpoint exacto para validar un Pago Móvil?
- ¿Es /validar_pago_movil?
- ¿Es /verificar_pago?
- ¿Otro nombre?
```

### 2. Estructura del Request
```
¿Qué campos exactos debo enviar en el body?
- telefono_cliente o phone?
- cedula_cliente o document?
- referencia o reference?
- monto o amount?
- ¿Algún campo adicional?
```

### 3. Formato de Datos
```
¿Qué formato debo usar?
- Teléfono: "04149876543" o "0414-987-6543"?
- Cédula: "V12345678" o "V-12345678"?
- Monto: "150.00" o "150" o 150?
- Referencia: ¿String o número?
```

### 4. Códigos de Respuesta
```
¿Qué códigos de respuesta puedo recibir?
- 00: Validado correctamente
- ¿Qué otros códigos existen?
- ¿Qué significa cada uno?
```

### 5. Tiempo de Validación
```
¿Cuánto tiempo tarda la validación?
- ¿Es inmediata?
- ¿Puede tardar varios segundos?
- ¿Hay timeout recomendado?
```

### 6. Manejo de Errores
```
¿Qué pasa si:
- La referencia no existe?
- El monto no coincide?
- Los datos del cliente son incorrectos?
- La referencia ya fue usada?
- El banco no responde?
```

### 7. Límites
```
¿Hay límites de:
- Tiempo máximo entre el pago y la validación?
- Cantidad de intentos de validación?
- Monto mínimo/máximo?
```

---

## 💻 Implementación Necesaria

### Método a Implementar en `ubii_pos_service.dart`:

```dart
/// Valida un Pago Móvil realizado por el cliente
///
/// [telefonoCliente]: Teléfono del cliente (ej: "04149876543")
/// [cedulaCliente]: Cédula del cliente (ej: "V12345678")
/// [referencia]: Número de referencia del pago (ej: "123456789")
/// [monto]: Monto del pago en bolívares (ej: 150.00)
///
/// Retorna un Map con la respuesta de Ubii o null si hubo error
Future<Map<String, dynamic>?> validarPagoMovil({
  required String telefonoCliente,
  required String cedulaCliente,
  required String referencia,
  required double monto,
}) async {
  debugPrint('💳 Ubii: Validando Pago Móvil');
  debugPrint('   Teléfono cliente: $telefonoCliente');
  debugPrint('   Cédula cliente: $cedulaCliente');
  debugPrint('   Referencia: $referencia');
  debugPrint('   Monto: Bs. ${monto.toStringAsFixed(2)}');

  try {
    // 1. Obtener token de autorización
    final token = await _obtenerToken();
    if (token == null) {
      return {
        'code': 'ERROR',
        'message': 'No se pudo obtener token de autorización',
      };
    }

    // 2. Obtener API Key
    final apiKey = await _obtenerApiKey(token);
    if (apiKey == null) {
      return {
        'code': 'ERROR',
        'message': 'No se pudo obtener API Key',
      };
    }

    // 3. Validar pago con Ubii
    final response = await http.post(
      Uri.parse('${AppConfig.ubiiBaseUrl}/validar_pago_movil'),
      headers: {
        'Authorization': 'Bearer $token',
        'X-API-KEY': apiKey,
        'X-client-id': AppConfig.ubiiClientId,
        'X-client-domain': AppConfig.ubiiClientDomain,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'telefono_cliente': telefonoCliente,
        'cedula_cliente': cedulaCliente,
        'referencia': referencia,
        'monto': monto.toStringAsFixed(2),
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      if (data['code'] == '00') {
        debugPrint('✅ Pago validado correctamente');
      } else {
        debugPrint('❌ Pago rechazado: ${data['message']}');
      }
      
      return data;
    } else {
      debugPrint('❌ Error HTTP: ${response.statusCode}');
      return {
        'code': 'ERROR',
        'message': 'Error de comunicación con Ubii',
      };
    }
  } catch (e) {
    debugPrint('❌ Error validando pago: $e');
    return {
      'code': 'ERROR',
      'message': 'Error inesperado: $e',
    };
  }
}
```

---

## 🎯 Interfaz de Usuario Necesaria

### Pantalla de Validación de Pago Móvil:

```
┌─────────────────────────────────────────┐
│     VALIDAR PAGO MÓVIL                  │
├─────────────────────────────────────────┤
│                                         │
│  Total a pagar: Bs. 150.00              │
│                                         │
│  Datos del comercio (mostrar):         │
│  📱 Teléfono: 0424-1234567              │
│  🆔 RIF: J-30792822-0                   │
│                                         │
│  ─────────────────────────────────────  │
│                                         │
│  Datos del cliente (ingresar):         │
│                                         │
│  📱 Teléfono:  [________________]       │
│                                         │
│  🆔 Cédula:    [________________]       │
│                                         │
│  🔢 Referencia: [________________]      │
│                                         │
│  💰 Monto:     [________________]       │
│                                         │
│  ─────────────────────────────────────  │
│                                         │
│  [  CANCELAR  ]  [  VALIDAR PAGO  ]    │
│                                         │
└─────────────────────────────────────────┘
```

---

## ✅ Checklist de Implementación

- [ ] Obtener endpoint exacto de validación de Ubii
- [ ] Obtener estructura exacta del request
- [ ] Obtener formato de datos requerido
- [ ] Implementar método `validarPagoMovil()` en `ubii_pos_service.dart`
- [ ] Crear pantalla de validación de Pago Móvil
- [ ] Implementar manejo de códigos de respuesta
- [ ] Agregar validaciones de formato de datos
- [ ] Implementar timeout y reintentos
- [ ] Agregar logging detallado
- [ ] Probar con datos reales
- [ ] Documentar casos de error
- [ ] Capacitar a usuarios

---

**Última actualización**: 15 de abril de 2026

**IMPORTANTE**: Este flujo es el CORRECTO. El cliente paga primero y luego Ubii valida que el pago existe.
