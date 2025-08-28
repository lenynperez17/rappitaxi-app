# RappiTaxi Backend API Documentation

## 🚀 Descripción General

RappiTaxi Backend es una API REST completa construida con Node.js, Express y Firebase Cloud Functions que proporciona todos los servicios necesarios para una aplicación de transporte premium con características de:
- **InDrive**: Negociación de precios
- **Uber**: Precios dinámicos (surge pricing)  
- **Didi**: Viajes programados
- **Yango**: Viajes compartidos

## 📋 Información Base

- **Base URL**: `https://us-central1-rappitaxi-app.cloudfunctions.net/api/v1`
- **Local Development**: `http://localhost:5001/rappitaxi-app/us-central1/api/api/v1`
- **Autenticación**: Bearer Token (JWT)
- **Content-Type**: `application/json`
- **Rate Limiting**: Sí (varios niveles según endpoint)

## 🔐 Autenticación

Todos los endpoints (excepto públicos) requieren un token JWT en el header:
```
Authorization: Bearer <your-jwt-token>
```

### Roles de Usuario
- **passenger**: Usuarios que solicitan viajes
- **driver**: Conductores que proporcionan viajes  
- **admin**: Administradores del sistema

---

## 📑 Endpoints por Categoría

### 🏥 1. Health Check

#### GET /health
**Descripción**: Verifica el estado del servidor  
**Autenticación**: No requerida  
**Respuesta**:
```json
{
  "status": "OK",
  "timestamp": "2024-12-20T10:30:00.000Z",
  "version": "1.0.0",
  "environment": "production"
}
```

---

### 🔑 2. Autenticación (`/auth`)

#### POST /auth/register
**Descripción**: Registra un nuevo usuario  
**Autenticación**: No requerida  
**Roles**: Todos  
**Body**:
```json
{
  "email": "usuario@example.com",
  "password": "Password123!",
  "name": "Nombre Usuario",
  "phone": "+51987654321",
  "role": "passenger|driver|admin",
  "driverData": { // Solo para drivers
    "licenseNumber": "ABC123456",
    "vehicleType": "sedan",
    "vehiclePlate": "ABC-123",
    "vehicleModel": "Toyota Corolla"
  }
}
```

#### POST /auth/login
**Descripción**: Inicia sesión y obtiene tokens  
**Autenticación**: No requerida  
**Body**:
```json
{
  "email": "usuario@example.com",
  "password": "Password123!"
}
```
**Respuesta**:
```json
{
  "accessToken": "jwt-token-here",
  "refreshToken": "refresh-token-here",
  "user": {
    "id": "user-id",
    "email": "usuario@example.com",
    "name": "Nombre Usuario",
    "role": "passenger"
  }
}
```

#### POST /auth/refresh
**Descripción**: Renueva el token de acceso  
**Body**:
```json
{
  "refreshToken": "refresh-token-here"
}
```

#### GET /auth/profile
**Descripción**: Obtiene el perfil del usuario autenticado  
**Autenticación**: Requerida  

#### PUT /auth/profile
**Descripción**: Actualiza el perfil del usuario  
**Autenticación**: Requerida  
**Body**:
```json
{
  "name": "Nuevo Nombre",
  "phone": "+51987654321"
}
```

#### POST /auth/password/request-reset
**Descripción**: Solicita restablecimiento de contraseña  
**Body**:
```json
{
  "email": "usuario@example.com"
}
```

#### POST /auth/password/reset
**Descripción**: Restablece la contraseña con token  
**Body**:
```json
{
  "token": "reset-token",
  "newPassword": "NuevaPassword123!"
}
```

#### PUT /auth/password/change
**Descripción**: Cambia la contraseña del usuario autenticado  
**Autenticación**: Requerida  
**Body**:
```json
{
  "currentPassword": "Password123!",
  "newPassword": "NuevaPassword123!"
}
```

---

### 🚗 3. Viajes (`/rides`)

#### POST /rides/estimate
**Descripción**: Obtiene estimación de precio y tiempo  
**Autenticación**: Requerida  
**Body**:
```json
{
  "pickup": {
    "latitude": -12.0464,
    "longitude": -77.0428,
    "address": "Lima Centro, Peru"
  },
  "destination": {
    "latitude": -12.1000,
    "longitude": -77.0500,
    "address": "Miraflores, Peru"
  },
  "vehicleType": "economy|standard|premium"
}
```

#### POST /rides
**Descripción**: Crea una nueva solicitud de viaje  
**Autenticación**: Requerida  
**Roles**: passenger  
**Body**:
```json
{
  "pickup": {
    "latitude": -12.0464,
    "longitude": -77.0428,
    "address": "Lima Centro, Peru"
  },
  "destination": {
    "latitude": -12.1000,
    "longitude": -77.0500,
    "address": "Miraflores, Peru"
  },
  "vehicleType": "standard",
  "paymentMethod": "cash|card|wallet",
  "notes": "Instrucciones especiales",
  "scheduledFor": "2024-12-21T10:00:00.000Z", // Opcional para viajes programados
  "isShared": false, // Para viajes compartidos
  "negotiatePrice": false // Para negociación InDrive
}
```

#### GET /rides/active
**Descripción**: Obtiene viajes activos del usuario  
**Autenticación**: Requerida  

#### GET /rides/history
**Descripción**: Obtiene historial de viajes  
**Autenticación**: Requerida  
**Query Params**: `?page=1&limit=10&startDate=2024-01-01&endDate=2024-12-31`

#### GET /rides/nearby
**Descripción**: Obtiene viajes cercanos (solo drivers)  
**Autenticación**: Requerida  
**Roles**: driver  
**Query Params**: `?latitude=-12.0464&longitude=-77.0428&radius=5000`

#### GET /rides/driver/active
**Descripción**: Obtiene el viaje activo del conductor  
**Autenticación**: Requerida  
**Roles**: driver  

#### GET /rides/:rideId
**Descripción**: Obtiene detalles de un viaje específico  
**Autenticación**: Requerida  

#### POST /rides/:rideId/accept
**Descripción**: Conductor acepta un viaje  
**Autenticación**: Requerida  
**Roles**: driver  

#### POST /rides/:rideId/reject
**Descripción**: Conductor rechaza un viaje  
**Autenticación**: Requerida  
**Roles**: driver  

#### POST /rides/:rideId/start
**Descripción**: Conductor inicia el viaje  
**Autenticación**: Requerida  
**Roles**: driver  

#### POST /rides/:rideId/complete
**Descripción**: Conductor completa el viaje  
**Autenticación**: Requerida  
**Roles**: driver  

#### POST /rides/:rideId/cancel
**Descripción**: Cancela un viaje  
**Autenticación**: Requerida  
**Body**:
```json
{
  "reason": "Motivo de cancelación",
  "cancelledBy": "passenger|driver"
}
```

#### PUT /rides/:rideId/driver-location
**Descripción**: Actualiza ubicación del conductor  
**Autenticación**: Requerida  
**Roles**: driver  
**Body**:
```json
{
  "latitude": -12.0464,
  "longitude": -77.0428,
  "heading": 90,
  "speed": 25
}
```

#### POST /rides/:rideId/rate
**Descripción**: Califica un viaje completado  
**Autenticación**: Requerida  
**Body**:
```json
{
  "rating": 5,
  "comment": "Excelente servicio",
  "ratedBy": "passenger|driver"
}
```

#### POST /rides/:rideId/emergency
**Descripción**: Alerta de emergencia  
**Autenticación**: Requerida  
**Rate Limit**: 5 por minuto  
**Body**:
```json
{
  "type": "medical|security|accident",
  "message": "Descripción de la emergencia",
  "location": {
    "latitude": -12.0464,
    "longitude": -77.0428
  }
}
```

#### POST /rides/:rideId/share
**Descripción**: Comparte ubicación del viaje  
**Autenticación**: Requerida  
**Body**:
```json
{
  "shareWithContacts": ["contact1@email.com", "contact2@email.com"],
  "message": "Comparto mi ubicación de viaje"
}
```

---

### 💳 4. Pagos (`/payments`)

#### GET /payments/methods
**Descripción**: Obtiene métodos de pago del usuario  
**Autenticación**: Requerida  

#### POST /payments/methods
**Descripción**: Añade un método de pago  
**Autenticación**: Requerida  
**Body**:
```json
{
  "type": "card|mercadopago",
  "cardNumber": "4242424242424242",
  "expiryMonth": "12",
  "expiryYear": "2028",
  "cvv": "123",
  "cardholderName": "Nombre Titular"
}
```

#### DELETE /payments/methods/:methodId
**Descripción**: Elimina un método de pago  
**Autenticación**: Requerida  

#### PUT /payments/methods/:methodId/default
**Descripción**: Establece método de pago por defecto  
**Autenticación**: Requerida  

#### GET /payments/wallet/balance
**Descripción**: Obtiene balance de la billetera  
**Autenticación**: Requerida  

#### POST /payments/wallet/add-funds
**Descripción**: Añade fondos a la billetera  
**Autenticación**: Requerida  
**Body**:
```json
{
  "amount": 50.00,
  "currency": "PEN",
  "paymentMethod": "card|mercadopago"
}
```

#### POST /payments/wallet/withdraw
**Descripción**: Retira fondos de la billetera  
**Autenticación**: Requerida  
**Rate Limit**: 5 por 5 minutos  
**Body**:
```json
{
  "amount": 25.00,
  "currency": "PEN",
  "withdrawalMethod": "bank_transfer|mercadopago"
}
```

#### POST /payments
**Descripción**: Crea un pago  
**Autenticación**: Requerida  
**Body**:
```json
{
  "amount": 25.50,
  "currency": "PEN",
  "rideId": "ride-id-123",
  "paymentMethod": "cash|card|wallet|mercadopago"
}
```

#### POST /payments/:paymentId/process
**Descripción**: Procesa un pago pendiente  
**Autenticación**: Requerida  
**Rate Limit**: 10 por minuto  

#### POST /payments/:paymentId/refund
**Descripción**: Reembolsa un pago  
**Autenticación**: Requerida  
**Roles**: admin  

#### GET /payments/history
**Descripción**: Obtiene historial de pagos  
**Autenticación**: Requerida  
**Query Params**: `?page=1&limit=10&startDate=2024-01-01&endDate=2024-12-31`

#### POST /payments/generate-link
**Descripción**: Genera link de pago  
**Autenticación**: Requerida  
**Body**:
```json
{
  "amount": 25.50,
  "currency": "PEN",
  "description": "Pago de viaje RappiTaxi",
  "rideId": "ride-id-123"
}
```

#### GET /payments/driver/earnings
**Descripción**: Obtiene ganancias del conductor  
**Autenticación**: Requerida  
**Roles**: driver, admin  
**Query Params**: `?startDate=2024-01-01&endDate=2024-12-31&groupBy=day|week|month`

#### POST /payments/driver/payout
**Descripción**: Solicita pago de ganancias  
**Autenticación**: Requerida  
**Roles**: driver  
**Rate Limit**: 3 por día  
**Body**:
```json
{
  "amount": 500.00,
  "currency": "PEN",
  "payoutMethod": "bank_transfer|mercadopago"
}
```

---

### 🔔 5. Notificaciones (`/notifications`)

#### GET /notifications
**Descripción**: Obtiene notificaciones del usuario  
**Autenticación**: Requerida  
**Query Params**: `?page=1&limit=10&unreadOnly=true`

#### GET /notifications/unread-count
**Descripción**: Obtiene cantidad de notificaciones no leídas  
**Autenticación**: Requerida  

#### PUT /notifications/:notificationId/read
**Descripción**: Marca notificación como leída  
**Autenticación**: Requerida  

#### PUT /notifications/mark-all-read
**Descripción**: Marca todas las notificaciones como leídas  
**Autenticación**: Requerida  

#### DELETE /notifications/:notificationId
**Descripción**: Elimina una notificación  
**Autenticación**: Requerida  

#### POST /notifications/device-token
**Descripción**: Registra token de dispositivo para push notifications  
**Autenticación**: Requerida  
**Body**:
```json
{
  "token": "fcm-device-token-here",
  "platform": "android|ios|web"
}
```

#### DELETE /notifications/device-token
**Descripción**: Desregistra token de dispositivo  
**Autenticación**: Requerida  

#### POST /notifications/topics/:topic/subscribe
**Descripción**: Se suscribe a un topic de notificaciones  
**Autenticación**: Requerida  

#### DELETE /notifications/topics/:topic/unsubscribe
**Descripción**: Se desuscribe de un topic  
**Autenticación**: Requerida  

#### GET /notifications/preferences
**Descripción**: Obtiene preferencias de notificaciones  
**Autenticación**: Requerida  

#### PUT /notifications/preferences
**Descripción**: Actualiza preferencias de notificaciones  
**Autenticación**: Requerida  
**Body**:
```json
{
  "rideUpdates": true,
  "paymentAlerts": true,
  "promotions": false,
  "emailNotifications": true,
  "pushNotifications": true,
  "smsNotifications": false
}
```

---

### 🛡️ 6. Admin (`/admin` routes)

#### GET /rides/admin/all
**Descripción**: Obtiene todos los viajes (admin)  
**Autenticación**: Requerida  
**Roles**: admin  
**Query Params**: `?page=1&limit=10&status=active|completed|cancelled`

#### GET /payments/admin/analytics
**Descripción**: Obtiene analytics de pagos  
**Autenticación**: Requerida  
**Roles**: admin  
**Query Params**: `?startDate=2024-01-01&endDate=2024-12-31&groupBy=day|week|month`

#### GET /payments/admin/user/:userId/payments
**Descripción**: Obtiene pagos de un usuario específico  
**Autenticación**: Requerida  
**Roles**: admin  

#### POST /notifications/admin/test
**Descripción**: Envía notificación de prueba  
**Autenticación**: Requerida  
**Roles**: admin  
**Body**:
```json
{
  "userId": "user-id-here",
  "title": "Notificación de Prueba",
  "body": "Este es un mensaje de prueba",
  "data": {"testKey": "testValue"}
}
```

#### POST /notifications/admin/bulk
**Descripción**: Envía notificación masiva  
**Autenticación**: Requerida  
**Roles**: admin  
**Rate Limit**: 5 por 5 minutos  
**Body**:
```json
{
  "title": "Notificación Masiva",
  "body": "Mensaje para todos los usuarios",
  "targetAudience": "all|passengers|drivers",
  "data": {"campaignId": "promo-2024"}
}
```

#### PUT /auth/users/:userId/role
**Descripción**: Actualiza rol de usuario  
**Autenticación**: Requerida  
**Roles**: admin  
**Body**:
```json
{
  "role": "passenger|driver|admin"
}
```

#### PUT /auth/users/:userId/deactivate
**Descripción**: Desactiva cuenta de usuario  
**Autenticación**: Requerida  
**Roles**: admin  

#### PUT /auth/users/:userId/reactivate
**Descripción**: Reactiva cuenta de usuario  
**Autenticación**: Requerida  
**Roles**: admin  

#### DELETE /auth/users/:userId
**Descripción**: Elimina cuenta de usuario  
**Autenticación**: Requerida  
**Roles**: admin  

---

### 🌐 7. Webhooks

#### POST /payments/webhooks/mercadopago
**Descripción**: Webhook para MercadoPago  
**Autenticación**: No requerida (validación por signature)  

---

## 🚦 Rate Limiting

La API implementa diferentes niveles de rate limiting:

- **General**: 100 requests por 15 minutos
- **Auth endpoints**: 10 requests por 15 minutos  
- **Password reset**: 3 requests por hora
- **Payment processing**: 10 requests por minuto
- **Wallet withdrawals**: 5 requests por 5 minutos
- **Driver payouts**: 3 requests por día
- **Emergency alerts**: 5 requests por minuto
- **Bulk notifications**: 5 requests por 5 minutos

## 📊 Códigos de Respuesta HTTP

- **200**: OK - Solicitud exitosa
- **201**: Created - Recurso creado exitosamente  
- **204**: No Content - Acción exitosa sin contenido
- **400**: Bad Request - Datos inválidos
- **401**: Unauthorized - Token inválido o faltante
- **403**: Forbidden - Sin permisos para esta acción
- **404**: Not Found - Recurso no encontrado
- **409**: Conflict - Conflicto en el estado del recurso
- **422**: Unprocessable Entity - Validación fallida
- **429**: Too Many Requests - Rate limit excedido
- **500**: Internal Server Error - Error del servidor

## 🔧 Testing

Para probar todos los endpoints, ejecuta:

```bash
# Hacer ejecutable (solo la primera vez)
chmod +x backend/test_all_endpoints.sh

# Ejecutar tests completos
./backend/test_all_endpoints.sh

# Para testing local (cambiar ENV="local" en el script)
# Primero iniciar el servidor local:
cd backend && npm run dev
```

El script probará:
- ✅ Todos los endpoints de autenticación
- ✅ Operaciones CRUD de viajes
- ✅ Sistema completo de pagos
- ✅ Gestión de notificaciones
- ✅ Funciones administrativas
- ✅ Manejo de errores
- ✅ Rate limiting
- ✅ Captura de tokens para testing posterior

## 🛠️ Características Especiales

### InDrive-Style Price Negotiation
- Endpoint: `POST /rides` con `"negotiatePrice": true`
- Los conductores pueden enviar múltiples ofertas
- Sistema de timeout para negociaciones

### Uber-Style Surge Pricing  
- Calculado automáticamente basado en demanda
- Multiplicadores dinámicos en tiempo real
- Integrado en estimaciones de precio

### Didi-Style Scheduled Rides
- Endpoint: `POST /rides` con `"scheduledFor": "ISO-date"`
- Soporte para recurrencia de viajes
- Sistema de recordatorios automático

### Yango-Style Shared Rides
- Endpoint: `POST /rides` con `"isShared": true`
- Algoritmo de emparejamiento de pasajeros
- Descuentos automáticos por compartir

---

## 📚 Recursos Adicionales

- **Postman Collection**: Incluir endpoints para testing
- **OpenAPI/Swagger**: Documentación interactiva
- **SDK Examples**: Ejemplos de integración
- **Error Codes Reference**: Guía completa de códigos de error

---

**Última actualización**: Diciembre 2024  
**Versión de API**: v1  
**Mantenido por**: Equipo RappiTaxi