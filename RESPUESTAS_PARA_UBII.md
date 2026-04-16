# 📋 Respuestas para el Personal de Ubii

Este documento contiene las respuestas exactas que debes proporcionar al personal de Ubii para completar la configuración de tu integración.

---

## 1️⃣ Pregunta: X-client-domain - ¿Cuál es el dominio?

**Tu respuesta**:
```
El dominio que necesito autorizar es: com.pos.pos_android
```

**Explicación**: Este es el package name (identificador único) de tu aplicación Android. Es como el "nombre técnico" de tu app en el sistema Android.

---

## 2️⃣ Pregunta: Datos de Pago Móvil - ¿Para qué necesitas el número de teléfono, cédula/RIF y referencia?

**Tu respuesta**:
```
Necesito el número de teléfono, cédula/RIF y REFERENCIA del CLIENTE (comprador) para:

1. Validar que el pago móvil fue realizado correctamente
2. Verificar que el monto transferido coincide con la compra
3. Confirmar la identidad del cliente que realizó el pago
4. Registrar la transacción en mi sistema

El flujo es:
- Cliente compra en mi comercio por X monto
- Cajero proporciona al cliente: teléfono y cédula/RIF del comercio
- Cliente realiza Pago Móvil desde su app bancaria a los datos del comercio
- Cliente recibe REFERENCIA del pago
- Cliente proporciona al cajero: su teléfono, cédula y referencia
- App Ubii valida que el pago existe y es correcto
- Si es válido, se aprueba la venta
```

---

## 3️⃣ Información Completa de tu Integración

Si Ubii solicita información adicional, proporciona:

### Datos de la Aplicación:
- **Nombre de la aplicación**: POS Android
- **Package Name (Dominio)**: `com.pos.pos_android`
- **Plataforma**: Android
- **Tipo de aplicación**: Sistema de Punto de Venta (POS)

### Datos de Ubii Asignados:
- **Client ID**: `f4e1553b-a2f7-11f0-afbe-005056965434`
- **URL Base**: `https://botonc.ubiipagos.com`

### Tipo de Integración:
- **Método de pago**: Pago Móvil (P2C - Person to Commerce)
- **Flujo**: El cliente paga desde su app bancaria al recibir notificación

### Datos que NO necesitas:
- ❌ Client Secret (no requerido según documentación)
- ❌ Merchant ID (no requerido según documentación)
- ❌ Terminal ID (no requerido según documentación)
- ❌ X-API-KEY (se obtiene automáticamente con `/get_keys`)

---

## 4️⃣ Preguntas que DEBES hacer a Ubii

Una vez que autoricen tu dominio, pregunta:

1. **¿Cuándo estará activo el dominio `com.pos.pos_android`?**
   - Necesitas saber cuándo puedes empezar a probar

2. **¿Tienen un ambiente de pruebas (sandbox)?**
   - Para probar sin hacer transacciones reales

3. **¿Pueden proporcionar la documentación completa de la API?**
   - Endpoints disponibles
   - Códigos de respuesta y errores
   - Ejemplos de payloads
   - Límites de transacciones

4. **¿Qué datos del comercio necesito configurar para Pago Móvil?**
   - Teléfono del comercio registrado en el banco
   - Cédula/RIF del comercio
   - Banco del comercio

5. **¿Hay webhooks disponibles para notificaciones?**
   - Para recibir confirmaciones de pago en tiempo real

6. **¿Cuál es el soporte técnico disponible?**
   - Email, teléfono, horarios de atención

---

## 5️⃣ Checklist de Configuración

Marca cada paso cuando lo completes:

- [x] Client ID recibido: `f4e1553b-a2f7-11f0-afbe-005056965434`
- [x] URL Base configurada: `https://botonc.ubiipagos.com`
- [x] Dominio enviado a Ubii: `com.pos.pos_android`
- [ ] Confirmación de Ubii que el dominio está autorizado
- [ ] Prueba de autenticación con `/auth` exitosa
- [ ] Prueba de obtención de keys con `/get_keys` exitosa
- [ ] Documentación completa de API recibida
- [ ] Ambiente de pruebas (sandbox) configurado (si está disponible)
- [ ] Datos del comercio para Pago Móvil configurados en `.env`
- [ ] Primera transacción de prueba exitosa
- [ ] Integración completa en producción

---

## 6️⃣ Datos del Comercio para Pago Móvil

Estos datos los debes configurar en el archivo `.env` una vez que Ubii confirme la autorización:

```env
# Teléfono del comercio registrado en el banco (formato: 00584XXXXXXXXX)
PAGO_MOVIL_TELEFONO=00584XXXXXXXXX

# Cédula o RIF del comercio para Pago Móvil (formato: V12345678 o J123456789)
PAGO_MOVIL_CEDULA_RIF=J30792822-0

# Alias de la API Key de Pago Móvil en Ubii (común: P2C)
PAGO_MOVIL_ALIAS=P2C
```

**IMPORTANTE**: Estos datos deben coincidir con los registrados en tu banco para Pago Móvil.

---

## 📞 Contacto

Si tienes dudas durante la configuración:
1. Contacta al soporte técnico de Ubii
2. Proporciona tu Client ID: `f4e1553b-a2f7-11f0-afbe-005056965434`
3. Menciona que estás integrando Pago Móvil en una aplicación Android POS

---

## ✅ Próximos Pasos

1. Envía el dominio `com.pos.pos_android` a Ubii
2. Espera confirmación de autorización
3. Solicita documentación completa de la API
4. Configura datos del comercio en `.env`
5. Realiza pruebas de autenticación
6. Implementa flujo completo de Pago Móvil
7. Prueba en ambiente de producción

---

**Fecha de última actualización**: 15 de abril de 2026
