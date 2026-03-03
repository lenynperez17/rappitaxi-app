# 🚖 RapiTeam - Aplicación Móvil Flutter

## 📋 Descripción General

RapiTeam es una aplicación móvil completa de transporte desarrollada en Flutter que conecta pasajeros con conductores de taxi de manera eficiente y segura. La aplicación incluye tres interfaces principales: Pasajero, Conductor y Administrador, cada una con funcionalidades específicas y optimizadas.

## 🎯 Características Principales

### 👤 Módulo Pasajero
- **Registro y Autenticación**
  - Registro con email y teléfono
  - Verificación por SMS
  - Login con múltiples métodos
  - Recuperación de contraseña
  
- **Solicitud de Viajes**
  - Mapa interactivo en tiempo real
  - Búsqueda de direcciones con autocompletado
  - Estimación de tarifa antes de confirmar
  - Selección de tipo de vehículo
  - Programación de viajes futuros
  - Viajes recurrentes
  
- **Durante el Viaje**
  - Seguimiento en tiempo real del conductor
  - Información del conductor y vehículo
  - Chat en vivo con el conductor
  - Compartir ubicación con contactos
  - Botón de pánico/emergencia
  
- **Pagos**
  - Múltiples métodos de pago (efectivo, tarjeta, wallet)
  - Historial de pagos
  - Propinas personalizables
  - Facturas electrónicas
  
- **Funciones Adicionales**
  - Historial completo de viajes
  - Calificación y comentarios
  - Lugares favoritos
  - Códigos promocionales
  - Programa de referidos

### 🚗 Módulo Conductor
- **Gestión de Perfil**
  - Registro con documentación
  - Verificación de identidad
  - Gestión de vehículo
  - Documentos (licencia, SOAT, antecedentes)
  
- **Operaciones**
  - Modo online/offline
  - Aceptación/rechazo de viajes
  - Navegación GPS integrada
  - Gestión de rutas óptimas
  - Registro de gastos (gasolina, mantenimiento)
  
- **Ganancias**
  - Dashboard de ingresos
  - Historial de viajes detallado
  - Comisiones transparentes
  - Retiros a cuenta bancaria
  - Reportes mensuales
  
- **Herramientas**
  - Chat con pasajeros
  - Zonas de calor (heatmap)
  - Estadísticas de rendimiento
  - Metas diarias/semanales
  - Capacitación en línea

### 👨‍💼 Módulo Administrador
- **Dashboard Principal**
  - KPIs en tiempo real
  - Métricas de negocio
  - Alertas y notificaciones
  - Vista general del sistema
  
- **Gestión de Usuarios**
  - CRUD completo de pasajeros
  - Verificación de cuentas
  - Bloqueos y suspensiones
  - Historial de actividad
  - Comunicación masiva
  
- **Gestión de Conductores**
  - Aprobación de registros
  - Verificación de documentos
  - Seguimiento de rendimiento
  - Gestión de pagos y comisiones
  - Capacitación y certificaciones
  
- **Analytics y Reportes**
  - Análisis de viajes
  - Métricas financieras
  - Mapas de calor
  - Reportes personalizables
  - Exportación de datos
  
- **Control Financiero**
  - Gestión de tarifas
  - Comisiones dinámicas
  - Procesamiento de pagos
  - Conciliación bancaria
  - Facturación electrónica
  
- **Configuración del Sistema**
  - Tarifas y precios dinámicos
  - Zonas de servicio
  - Promociones y descuentos
  - Notificaciones push
  - Parámetros de seguridad

## 🏗️ Arquitectura y Estructura

```
app/
├── lib/
│   ├── main.dart                 # Punto de entrada principal
│   ├── main_passenger.dart       # Entry point pasajero
│   ├── main_driver.dart          # Entry point conductor
│   ├── main_admin.dart           # Entry point administrador
│   ├── main_rapiteam.dart           # Entry point unificado RapiTeam
│   │
│   ├── core/                     # Núcleo de la aplicación
│   │   ├── constants/            # Constantes globales
│   │   │   ├── app_colors.dart
│   │   │   ├── app_constants.dart
│   │   │   └── api_endpoints.dart
│   │   ├── theme/                # Temas y estilos
│   │   │   └── modern_theme.dart
│   │   ├── utils/                # Utilidades
│   │   │   ├── validators.dart
│   │   │   ├── formatters.dart
│   │   │   └── helpers.dart
│   │   └── errors/               # Manejo de errores
│   │       └── exceptions.dart
│   │
│   ├── data/                     # Capa de datos
│   │   ├── models/               # Modelos de datos
│   │   │   ├── user_model.dart
│   │   │   ├── trip_model.dart
│   │   │   ├── driver_model.dart
│   │   │   └── payment_model.dart
│   │   ├── repositories/         # Repositorios
│   │   │   ├── auth_repository.dart
│   │   │   ├── trip_repository.dart
│   │   │   └── payment_repository.dart
│   │   └── providers/            # Providers (State Management)
│   │       ├── auth_provider.dart
│   │       ├── trip_provider.dart
│   │       └── location_provider.dart
│   │
│   ├── services/                 # Servicios
│   │   ├── api_service.dart     # API REST
│   │   ├── firebase_service.dart # Firebase
│   │   ├── location_service.dart # GPS/Ubicación
│   │   ├── notification_service.dart # Push notifications
│   │   ├── payment_service.dart  # Pagos
│   │   └── socket_service.dart   # WebSockets tiempo real
│   │
│   ├── screens/                  # Pantallas
│   │   ├── auth/                # Autenticación
│   │   │   ├── login_screen.dart
│   │   │   ├── register_screen.dart
│   │   │   ├── otp_verification_screen.dart
│   │   │   └── forgot_password_screen.dart
│   │   │
│   │   ├── passenger/           # Pantallas pasajero
│   │   │   ├── home_passenger_screen.dart
│   │   │   ├── trip_booking_screen.dart
│   │   │   ├── trip_tracking_screen.dart
│   │   │   ├── payment_screen.dart
│   │   │   ├── history_screen.dart
│   │   │   └── profile_passenger_screen.dart
│   │   │
│   │   ├── driver/              # Pantallas conductor
│   │   │   ├── home_driver_screen.dart
│   │   │   ├── trip_request_screen.dart
│   │   │   ├── navigation_screen.dart
│   │   │   ├── earnings_screen.dart
│   │   │   ├── documents_screen.dart
│   │   │   └── profile_driver_screen.dart
│   │   │
│   │   ├── admin/               # Pantallas administrador
│   │   │   ├── admin_dashboard_screen.dart
│   │   │   ├── users_management_screen.dart
│   │   │   ├── drivers_management_screen.dart
│   │   │   ├── analytics_screen.dart
│   │   │   ├── financial_screen.dart
│   │   │   └── settings_admin_screen.dart
│   │   │
│   │   └── shared/              # Pantallas compartidas
│   │       ├── splash_screen.dart
│   │       ├── onboarding_screen.dart
│   │       └── support_screen.dart
│   │
│   └── widgets/                  # Widgets reutilizables
│       ├── common/              # Widgets comunes
│       │   ├── rapiteam_app_bar.dart
│       │   ├── rapiteam_button.dart
│       │   ├── rapiteam_text_field.dart
│       │   └── loading_indicator.dart
│       ├── cards/               # Tarjetas personalizadas
│       │   ├── trip_card.dart
│       │   ├── driver_card.dart
│       │   └── stats_card.dart
│       ├── dialogs/             # Diálogos
│       │   ├── confirmation_dialog.dart
│       │   ├── rating_dialog.dart
│       │   └── error_dialog.dart
│       ├── maps/                # Componentes de mapa
│       │   ├── map_widget.dart
│       │   ├── location_picker.dart
│       │   └── route_preview.dart
│       └── animated/            # Widgets animados
│           ├── pulse_animation.dart
│           ├── slide_transition.dart
│           └── modern_animated_widgets.dart
│
├── assets/                      # Recursos
│   ├── images/                 # Imágenes
│   │   ├── logo_rapiteam.png
│   │   ├── markers/
│   │   └── backgrounds/
│   ├── animations/             # Animaciones Lottie
│   ├── fonts/                  # Fuentes personalizadas
│   └── icons/                  # Iconos personalizados
│
├── test/                       # Pruebas
│   ├── unit/                   # Pruebas unitarias
│   ├── widget/                 # Pruebas de widgets
│   └── integration/            # Pruebas de integración
│
└── pubspec.yaml               # Dependencias

```

## 🔄 Flujo de Navegación

### Flujo Pasajero
```
Splash → Onboarding → Login/Register → OTP → Home
         ↓                                      ↓
    Role Selection                        Book Trip
                                               ↓
                                        Search Location
                                               ↓
                                        Confirm Booking
                                               ↓
                                        Driver Match
                                               ↓
                                        Track Trip
                                               ↓
                                        Payment
                                               ↓
                                        Rating
```

### Flujo Conductor
```
Splash → Login → Document Verification → Home Dashboard
                                              ↓
                                        Go Online/Offline
                                              ↓
                                        Receive Request
                                              ↓
                                        Accept/Reject
                                              ↓
                                        Navigate to Pickup
                                              ↓
                                        Start Trip
                                              ↓
                                        Complete Trip
                                              ↓
                                        Receive Payment
```

### Flujo Administrador
```
Splash → Admin Login → 2FA → Dashboard
                               ↓
                    ┌──────────┼──────────┐
                    ↓          ↓          ↓
              Users Mgmt  Drivers Mgmt  Analytics
                    ↓          ↓          ↓
              CRUD Ops    Approvals   Reports
```

## 🛠️ Tecnologías Utilizadas

### Frontend
- **Flutter 3.19+** - Framework principal
- **Dart 3.0+** - Lenguaje de programación
- **Provider/Riverpod** - State Management
- **Google Maps Flutter** - Mapas interactivos
- **Firebase SDK** - Servicios backend
- **Socket.io Client** - Comunicación tiempo real
- **Dio** - Cliente HTTP
- **GetX** - Navegación y dependencias
- **Hive** - Base de datos local

### Backend Services
- **Firebase Auth** - Autenticación
- **Firebase Firestore** - Base de datos NoSQL
- **Firebase Cloud Messaging** - Push notifications
- **Firebase Storage** - Almacenamiento de archivos
- **Firebase Functions** - Lógica serverless
- **Google Maps API** - Servicios de mapas
- **Mercado Pago** - Procesamiento de pagos

## 📱 Características Técnicas

### Rendimiento
- Lazy loading de imágenes
- Caché de datos offline
- Optimización de rebuilds
- Code splitting por rutas
- Minificación de assets

### Seguridad
- Autenticación JWT
- Encriptación de datos sensibles
- SSL/TLS para comunicaciones
- Validación de inputs
- Rate limiting
- Sanitización de datos

### UX/UI
- Material Design 3
- Tema claro/oscuro
- Animaciones fluidas (60 FPS)
- Responsive design
- Accesibilidad (a11y)
- Internacionalización (i18n)

## 🚀 Instalación y Configuración

### Requisitos Previos
```bash
- Flutter SDK 3.19+
- Dart SDK 3.0+
- Android Studio / Xcode
- Git
- Node.js 18+ (para Firebase)
```

### Instalación
```bash
# Clonar repositorio
git clone https://github.com/rapiteam/rapi-team-app.git
cd rapi-team-app/app

# Instalar dependencias
flutter pub get

# Configurar Firebase
flutterfire configure

# Generar código
flutter pub run build_runner build

# Ejecutar en modo desarrollo
flutter run

# Para cada tipo de usuario específico:
flutter run -t lib/main_passenger.dart  # Pasajero
flutter run -t lib/main_driver.dart     # Conductor
flutter run -t lib/main_admin.dart      # Admin
flutter run -t lib/main_rapiteam.dart      # Unificado
```

### Variables de Entorno
Crear archivo `.env` en la raíz:
```env
# API Configuration
API_BASE_URL=https://api.rapiteam.com
API_KEY=your_api_key_here
GOOGLE_MAPS_API_KEY=your_google_maps_key

# Firebase
FIREBASE_PROJECT_ID=rapi-team
FIREBASE_API_KEY=your_firebase_api_key

# Payment Gateways
MERCADO_PAGO_PUBLIC_KEY=pk_test_xxx
MERCADO_PAGO_CLIENT_ID=xxx

# Push Notifications
FCM_SERVER_KEY=xxx

# Analytics
GOOGLE_ANALYTICS_ID=G-XXX
MIXPANEL_TOKEN=xxx
```

## 📊 Monitoreo y Analytics

### Métricas Trackeadas
- **Usuarios**: Registros, logins, retención
- **Viajes**: Solicitudes, completados, cancelados
- **Financiero**: Ingresos, comisiones, métodos de pago
- **Rendimiento**: Tiempos de respuesta, crashes, ANRs
- **Conductores**: Tiempo online, aceptación rate, rating

### Herramientas
- Firebase Analytics
- Google Analytics
- Crashlytics
- Performance Monitoring
- Custom Dashboard

## 🧪 Testing

### Tipos de Pruebas
```bash
# Unit tests
flutter test test/unit/

# Widget tests
flutter test test/widget/

# Integration tests
flutter test integration_test/

# Coverage report
flutter test --coverage
```

### Pruebas Automatizadas
- CI/CD con GitHub Actions
- Pruebas en cada PR
- Deploy automático a TestFlight/Play Console
- Smoke tests post-deploy

## 📦 Build y Deployment

### Android
```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release --obfuscate --split-debug-info=build/symbols

# App Bundle
flutter build appbundle --release
```

### iOS
```bash
# Debug IPA
flutter build ios --debug

# Release IPA
flutter build ios --release --obfuscate --split-debug-info=build/symbols

# Archive for App Store
flutter build ipa --release
```

### Web
```bash
# Build web
flutter build web --release --web-renderer canvaskit

# Deploy to Firebase Hosting
firebase deploy --only hosting
```

## 🔐 Seguridad y Compliance

### Cumplimiento Normativo
- **GDPR** - Protección de datos europeos
- **PCI DSS** - Seguridad en pagos
- **ISO 27001** - Gestión de seguridad
- **LOPD** - Ley de protección de datos
- **PSD2** - Directiva de servicios de pago

### Medidas de Seguridad
- Autenticación multifactor (MFA)
- Encriptación end-to-end
- Auditoría de accesos
- Backups automáticos
- DDoS protection
- WAF (Web Application Firewall)

## 📈 Roadmap

### Q1 2024
- [x] MVP Pasajero
- [x] MVP Conductor
- [x] Sistema de pagos
- [x] Panel admin básico

### Q2 2024
- [ ] Viajes compartidos
- [ ] Reservas programadas
- [ ] Wallet digital
- [ ] Multi-idioma

### Q3 2024
- [ ] IA para predicción de demanda
- [ ] Programa de lealtad
- [ ] Integración con empresas
- [ ] API pública

### Q4 2024
- [ ] Expansión internacional
- [ ] Vehículos eléctricos
- [ ] Blockchain para pagos
- [ ] Voice assistant

## 👥 Equipo de Desarrollo

- **Project Manager**: [Nombre]
- **Tech Lead**: [Nombre]
- **Flutter Developers**: [Equipo]
- **Backend Developers**: [Equipo]
- **UX/UI Designers**: [Equipo]
- **QA Engineers**: [Equipo]
- **DevOps**: [Equipo]

## 📞 Soporte

### Canales de Soporte
- **Email**: support@rapiteam.com
- **WhatsApp**: +51 999 999 999
- **In-app Chat**: Disponible 24/7
- **Centro de Ayuda**: help.rapiteam.com

### Reportar Problemas
Para reportar bugs o solicitar features:
1. Ir a [GitHub Issues](https://github.com/rapiteam/app/issues)
2. Crear nuevo issue con template
3. Incluir logs y screenshots
4. Especificar dispositivo y OS

## 📄 Licencia

Este proyecto es software propietario de RapiTeam S.A.C. Todos los derechos reservados.

---

**Última actualización**: Diciembre 2024
**Versión**: 2.0.0
**Estado**: Producción

© 2024 RapiTeam - Tu viaje, tu precio 🚖