# 🚕 RAPITEAM

> Plataforma completa de movilidad urbana con negociación de precios estilo InDriver

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)](https://flutter.dev)
[![Node.js](https://img.shields.io/badge/Node.js-20-green)](https://nodejs.org)
[![Firebase](https://img.shields.io/badge/Firebase-10+-orange)](https://firebase.google.com)
[![MercadoPago](https://img.shields.io/badge/MercadoPago-Producción-blue)](https://mercadopago.com)
[![Estado](https://img.shields.io/badge/Estado-Producción-success)](https://github.com)

## 🎯 Descripción

**RapiTeam** es una aplicación completa de transporte urbano que conecta pasajeros con conductores de manera eficiente y segura. Incluye un sistema único de **negociación de precios** donde los pasajeros proponen tarifas y los conductores pueden aceptar o contraofertar.

### 🌟 Características Principales

- 💰 **Negociación de precios en tiempo real**
- 🗺️ **Mapas interactivos con Google Maps**
- 💳 **Pagos seguros con MercadoPago**
- 💬 **Chat en tiempo real entre usuarios**
- 📱 **3 interfaces**: Pasajero, Conductor, Administrador
- 🔔 **Notificaciones push inteligentes**
- 📊 **Dashboard analítico completo**

## 🏗️ Arquitectura

```
RAPITEAM
├── 📱 Aplicación Flutter (Frontend)
├── 🚀 API Node.js + TypeScript (Backend)
├── 🔥 Firebase (Database + Auth + Storage)
├── 💳 MercadoPago (Pagos)
└── 🗺️ Google Maps (Ubicación)
```

## 🚀 Inicio Rápido

### Prerrequisitos
- Flutter 3.x
- Node.js 20 (última versión estable)
- Firebase project
- Google Maps API
- MercadoPago account (Producción configurada)

### Instalación

```bash
# 1. Clonar repositorio
git clone <repository-url>
cd AppRappiTaxi

# 2. Backend
npm install
cp .env.example .env
# Configurar .env con tus credenciales
npm run dev

# 3. Frontend
cd app
flutter pub get
flutter run
```

### Variables de Entorno

```env
# Firebase
FIREBASE_PROJECT_ID=tu_project_id
FIREBASE_PRIVATE_KEY=tu_private_key

# Google Maps
GOOGLE_MAPS_API_KEY=tu_api_key

# MercadoPago  
MERCADOPAGO_ACCESS_TOKEN=tu_access_token
```

## 📱 Funcionalidades

### Para Pasajeros
- Solicitar viajes con negociación de precio
- Seguimiento en tiempo real del conductor
- Múltiples métodos de pago
- Historial y calificaciones
- Chat con conductor

### Para Conductores
- Recibir solicitudes de viaje
- Negociar precios con pasajeros
- Dashboard de ganancias
- Navegación GPS integrada
- Gestión de vehículo

### Para Administradores
- Panel de control completo
- Gestión de usuarios y conductores
- Análisis financiero
- Reportes y estadísticas
- Configuración de tarifas

## 🛠️ Stack Técnico

| Componente | Tecnología |
|------------|------------|
| **Frontend** | Flutter 3.x, Dart |
| **Backend** | Node.js, TypeScript, Express |
| **Database** | Firebase Firestore |
| **Tiempo Real** | Firebase Realtime Database |
| **Auth** | Firebase Authentication |
| **Pagos** | MercadoPago API |
| **Mapas** | Google Maps Platform |
| **Push** | Firebase Cloud Messaging |

## 📊 Estado del Proyecto

✅ **Aplicación Flutter**: 100% Completada (38/38 features)
✅ **Backend Node.js 20**: 100% Implementado y Desplegado
✅ **Integración Firebase**: Configurada
✅ **Pagos MercadoPago**: ✅ PRODUCCIÓN ACTIVA (Octubre 2025)
✅ **Google Maps**: Integrado
✅ **Chat en Tiempo Real**: Activo
✅ **Cloud Functions**: Desplegadas (us-central1)
✅ **Webhook MercadoPago**: Configurado y Funcionando  

## 🎨 Diseño

- **Paleta**: Verde RapiTeam (#00C800), Negro, Blanco
- **Estilo**: Material Design 3 con animaciones fluidas
- **UX**: Inspirado en DiDi + InDriver
- **Responsive**: Optimizado para móviles

## 🚢 Despliegue

### Docker
```bash
docker-compose up -d
```

### Producción
```bash
# Backend
npm run build
npm start

# Frontend
flutter build apk --release
```

## 📋 Credenciales de Prueba

**Pasajero**
- Email: `passenger@test.com`
- Password: `123456`

**Conductor**  
- Email: `driver@test.com`
- Password: `123456`

**Admin**
- Email: `admin@rapiteam.app`
- Password: `admin123`

## 📚 Documentación

- [Checklist de Features](arreglar_o_implementar.md)
- [Documentación Técnica](docs/)
- [✅ Verificación MercadoPago](VERIFICACION_MERCADOPAGO.md)
- [🔧 Configuración Técnica MercadoPago](docs/CONFIGURACION_TECNICA_MERCADOPAGO.md)
- [📖 Setup MercadoPago](docs/MERCADOPAGO_SETUP.md)
- [API Documentation](src/)

## 🤝 Contribuir

1. Fork el proyecto
2. Crear rama feature (`git checkout -b feature/nueva-funcionalidad`)
3. Commit cambios (`git commit -m 'Agregar nueva funcionalidad'`)
4. Push a la rama (`git push origin feature/nueva-funcionalidad`)
5. Abrir Pull Request

## 📄 Licencia

Este proyecto está bajo la Licencia MIT - ver [LICENSE](LICENSE) para más detalles.

## 🏆 Características Destacadas

🎯 **Negociación de Precios**: Sistema único donde pasajeros y conductores negocian tarifas  
🎨 **Diseño Moderno**: UI/UX profesional con animaciones fluidas  
🔄 **Tiempo Real**: Actualizaciones instantáneas de ubicación y estado  
💼 **Panel Admin**: Dashboard completo para gestión de la plataforma  
🔒 **Seguridad**: Autenticación robusta y validación de datos  
📈 **Escalable**: Arquitectura preparada para crecimiento  

---

**RAPITEAM** - Tu viaje, tu precio, tu estilo 🚕✨

*Desarrollado con ❤️ por el equipo RapiTeam*