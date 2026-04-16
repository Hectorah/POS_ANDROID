# 📱 Integración Ubii - Resumen Completo

## ✅ Configuración Actual (ACTUALIZADA)

### Datos Configurados en `.env`:

```env
UBII_CLIENT_ID=f4e1553b-a2f7-11f0-afbe-005056965434
UBII_CLIENT_DOMAIN=com.pos.pos_android
UBII_BASE_URL=https://botonc.ubiipagos.com
```

**IMPORTANTE**: El dominio `com.pos.pos_android` debe estar autorizado por Ubii antes de poder realizar transacciones.

---

## 🔑 Autenticación con Ubii

### Flujo de Autenticación:

1. **Obtener Token de Autorización**
   - Endpoint: `POST https://botonc.ubiipagos.com/auth`
   - Headers:
     ```
     X-client-id: f4e1553b-a2f7-11f0-afbe-005056965434
     X-client-domain: com.pos.pos_android
     Content-Type: application/json
     ```
   - Respuesta: Token de autorización

2. **Obtener API Keys**
   - Endpoint: `GET https://botonc.ubiipagos.com/get_keys`
   - Headers:
     ```
     Authorization: Bearer {token_del_paso_1}
     X-client-id: f4e1553b-a2f7-11f0-afbe-005056965434
     X-client-domain: com.pos.pos_android
     ```
   - Respuesta: X-API-KEY para Pago Móvil

3. **Usar Pago Móvil**
   - Endpoint: `POST https://botonc.ubiipagos.com/pago_movil`
   - Headers:
     ```
     Authorization: Bearer {token}
     X-API-KEY: {api_key_obtenida_en_paso_2}
     X-client-id: f4e1553b-a2f7-11f0-afbe-005056965434
     X-client-domain: com.pos.pos_android
     Content-Type: application/json
     ```

---

## 📋 Datos NO Requeridos

Según la documentación de Ubii, **NO necesitas**:
- ❌ Client Secret
- ❌ Merchant ID
- ❌ Terminal ID

Estos se manejan automáticamente con el Client ID y el dominio.

---

## 🔄 Flujo Completo de Pago Móvil (CORRECTO)

```
1. Cliente selecciona "Pagar con Pago Móvil"
   ↓
2. Cajero proporciona al cliente:
   - Teléfono del comercio (ej: 0424-1234567)
   - Cédula/RIF del comercio (ej: J-30792822-0)
   - Monto a pagar
   ↓
3. Cliente realiza Pago Móvil desde su app bancaria
   - Transfiere a los datos del comercio
   - Recibe REFERENCIA del pago (ej: 123456789)
   ↓
4. Cliente proporciona al cajero:
   - Su teléfono (ej: 0414-9876543)
   - Su cédula (ej: V-12345678)
   - Referencia del pago (ej: 123456789)
   ↓
5. Cajero ingresa los datos en la app POS
   ↓
6. App obtiene token de autorización (/auth)
   ↓
7. App obtiene X-API-KEY (/get_keys)
   ↓
8. App envía datos a Ubii para validación (/validar_pago_movil)
   - Teléfono del cliente
   - Cédula del cliente
   - Referencia del pago
   - Monto
   ↓
9. Ubii valida con el banco que el pago existe y es correcto
   ↓
10. Si es válido → Pago aprobado → Generar factura
    Si es inválido → Rechazar venta
```

---

## 📝 Datos Requeridos para Validar Pago Móvil

### Datos que el COMERCIO proporciona al CLIENTE:

1. **Teléfono del comercio**: Formato `04XX-XXXXXXX`
   - Registrado en el banco del comercio para Pago Móvil
   - Configurado en `.env` como `PAGO_MOVIL_TELEFONO`

2. **Cédula/RIF del comercio**: Formato `J30792822-0`
   - Registrado en el banco del comercio
   - Configurado en `.env` como `PAGO_MOVIL_CEDULA_RIF`

3. **Monto a pagar**: En bolívares (VES)
   - El total de la compra

### Datos que el CLIENTE proporciona al CAJERO (después de pagar):

1. **Teléfono del cliente**: Formato `04XX-XXXXXXX`
   - El que usó para hacer el Pago Móvil

2. **Cédula del cliente**: Formato `V12345678`
   - La que usó para hacer el Pago Móvil

3. **Referencia del pago**: Número que le dio su banco
   - Ejemplo: `123456789`
   - Es la prueba de que realizó el pago

**¿Por qué se necesitan estos datos?**
- Ubii valida con el banco que el pago móvil existe
- Verifica que el monto coincide con la compra
- Confirma que los datos del cliente son correctos
- Previene fraudes y pagos duplicados

---

## 🔐 Seguridad

- El `Client ID` es público (se envía en headers)
- El `Client Domain` debe estar registrado en Ubii
- El token de autorización expira (renovar periódicamente)
- La `X-API-KEY` se obtiene dinámicamente (no se almacena en .env)

---

## 🔐 Respuesta para Ubii sobre X-client-domain

**Pregunta de Ubii**: "¿Cuál es el dominio que debo autorizar?"

**Tu respuesta debe ser**:

```
El dominio que necesito autorizar es: com.pos.pos_android

Este es el package name (identificador único) de mi aplicación Android.
```

**Información adicional que puedes proporcionar**:
- **Nombre de la aplicación**: POS Android
- **Package Name**: `com.pos.pos_android`
- **Client ID asignado**: `f4e1553b-a2f7-11f0-afbe-005056965434`
- **Plataforma**: Android
- **Tipo de integración**: Pago Móvil (P2C - Person to Commerce)

Una vez que Ubii autorice este dominio, podrás realizar transacciones de Pago Móvil desde tu aplicación.

---

## 📞 Contacto con Ubii

Si necesitas soporte técnico:
- Verifica que tu dominio `com.pos.pos_android` esté autorizado
- Solicita acceso a la documentación completa de la API
- Pregunta por el ambiente de pruebas (sandbox) si está disponible

---

## ✅ Próximos Pasos

1. ✅ Client ID configurado
2. ✅ Dominio configurado
3. ✅ URL base configurada
4. ⏳ Esperar confirmación de Ubii que el dominio está autorizado
5. ⏳ Probar autenticación con `/auth`
6. ⏳ Probar obtención de keys con `/get_keys`
7. ⏳ Implementar flujo completo de Pago Móvil

---

## 🧪 Pruebas Recomendadas

Una vez que Ubii confirme que tu dominio está autorizado:

1. **Probar autenticación**:
   ```bash
   curl -X POST https://botonc.ubiipagos.com/auth \
     -H "X-client-id: f4e1553b-a2f7-11f0-afbe-005056965434" \
     -H "X-client-domain: com.pos.pos_android" \
     -H "Content-Type: application/json"
   ```

2. **Probar obtención de keys**:
   ```bash
   curl -X GET https://botonc.ubiipagos.com/get_keys \
     -H "Authorization: Bearer {TOKEN_OBTENIDO}" \
     -H "X-client-id: f4e1553b-a2f7-11f0-afbe-005056965434" \
     -H "X-client-domain: com.pos.pos_android"
   ```

---

## 📚 Documentación

Solicita a Ubii:
- Documentación completa de la API
- Códigos de respuesta y errores
- Ejemplos de payloads
- Ambiente de pruebas (sandbox)
- Webhooks para notificaciones (si están disponibles)
