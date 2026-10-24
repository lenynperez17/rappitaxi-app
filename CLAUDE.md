# Rappi Team - Project Configuration for Claude

## Language
- Always respond in **Spanish**
- Commit messages in English
- Variable/function/class names in English
- Code comments in English

## Project Description
Rappi Team is a ride-hailing application built with Flutter, supporting iOS, Android, and Web. It connects passengers with drivers, featuring price negotiation (InDrive-style), dynamic pricing, scheduled rides, and real-time tracking.

## Architecture

### State Management: **Provider** (flat structure)
- All providers in `lib/providers/` (14 providers)
- No Riverpod, no GoRouter
- Simple `Navigator.push` for navigation

### Project Structure
```
App-Rapi-Team/
├── app/                          # Flutter application
│   ├── lib/
│   │   ├── config/               # OAuth, API config
│   │   ├── core/
│   │   │   ├── config/           # App configuration
│   │   │   ├── constants/        # Colors, dimensions, app constants
│   │   │   ├── extensions/       # BuildContext extensions
│   │   │   ├── services/         # Core services (location, notifications)
│   │   │   ├── theme/            # ModernTheme, AppTheme
│   │   │   ├── utils/            # Logger, helpers
│   │   │   └── widgets/          # Reusable widgets (RappiButton, RappiTextField, RappiAppBar)
│   │   ├── generated/            # Auto-generated l10n
│   │   ├── l10n/                 # Translations (app_es.arb, app_en.arb)
│   │   ├── models/               # Data models
│   │   ├── providers/            # 14 Provider classes
│   │   ├── screens/              # 58 screens organized by role
│   │   │   ├── auth/             # 7 auth screens
│   │   │   ├── passenger/        # 15 passenger screens
│   │   │   ├── driver/           # 15+ driver screens
│   │   │   ├── admin/            # 7 admin screens
│   │   │   └── shared/           # 14 shared screens
│   │   ├── services/             # 13 service classes
│   │   ├── shared/               # Shared utilities
│   │   ├── utils/                # Utility functions
│   │   ├── widgets/              # Global widgets
│   │   ├── main.dart             # App entry point (RappiTeamApp)
│   │   └── firebase_options.dart # Firebase config
│   ├── android/                  # Android config
│   ├── ios/                      # iOS config
│   └── assets/                   # Images, markers, HTML
├── api/                          # Backend Next.js — EL QUE CORRE EN PRODUCCIÓN
│                                 # VPS: /var/www/Rapi-Team-App-Api (pm2, puerto 3120)
├── admin/                        # Panel web React — se despliega por scp a Hostinger
└── store_assets/                 # Capturas fuente de las fichas de las tiendas
```

> **Ronda 275 — lo que se eliminó y por qué.**
> `src/` era el backend Express anterior a la migración: no estaba desplegado
> (el VPS corre Next.js) y nadie lo importaba. `scripts/` y `terraform/` venían
> copiados de otro proyecto y nunca se aplicaron aquí. `functions/`,
> `firebase.json`, `.firebaserc`, `firestore.rules` y `storage.rules` eran el
> stack de Firebase de antes de la migración: nada los llamaba. `.github/workflows/`
> desplegaba a Cloud Functions y a Firebase Hosting; su única ejecución, en
> agosto de 2025, falló.
>
> **De Firebase solo queda el envío de notificaciones push (FCM)**, y eso no se
> toca: es como los conductores reciben las ofertas de viaje. Lo que lo sostiene
> es `firebase_core` + `firebase_messaging` en la app, `firebase_options.dart`,
> `google-services.json`, `GoogleService-Info.plist`, y `firebase-admin` con la
> clave de servicio en el backend.

## Firebase — solo notificaciones push
El proyecto `rapi-team` sigue existiendo únicamente para FCM. Auth, Firestore,
Storage y Functions ya no se usan: la autenticación, los datos y los archivos
están en el VPS.
- **Project ID**: `rapi-team` · **Project Number**: `52925359166`
- **Android Package / iOS Bundle ID**: `com.rapiteam.app`
- `Auth Domain` y `Storage Bucket` aparecen en `firebase_options.dart` porque
  los genera FlutterFire, pero no se usan.

## Tech Stack

### Flutter App
- **Framework**: Flutter 3.x with Dart
- **State**: Provider
- **Maps**: Google Maps Flutter
- **Auth**: Firebase Auth (Email, Google, Facebook, Apple, Phone)
- **Database**: Cloud Firestore + Realtime Database
- **Storage**: Firebase Storage
- **Messaging**: Firebase Cloud Messaging
- **Payments**: MercadoPago (WebView checkout)
- **Real-time**: Socket.IO
- **i18n**: Flutter localization (ARB files)
- **Theme**: Material Design 3 (ModernTheme)

### Backend (`api/`)
- **Runtime**: Node.js with TypeScript
- **Framework**: Next.js (App Router) — no Express
- **Database**: PostgreSQL 17 en el VPS (no Firestore)
- **Firebase**: solo `firebase-admin` para enviar push (FCM)
- **Payments**: MercadoPago API
- **Archivos subidos**: `/var/www/Rapi-Team-Storage` en el VPS (no Firebase Storage)

## Color Scheme
- **Primary**: Orange `#FF6B00` (rappiOrange)
- **Primary Dark**: `#E55100` (rappiOrangeDark)
- **Primary Light**: `#FF9A4D` (rappiOrangeLight)
- **Success**: Green `#00A000` (NOT orange)
- Colors defined in `lib/core/constants/app_colors.dart`

## Key Commands

### Flutter (from /app)
```bash
flutter clean && flutter pub get
flutter analyze --no-fatal-infos
flutter run
flutter build apk --release
```

### Backend (from /api)
```bash
npm install && npm run dev        # local
npx tsc --noEmit                  # comprobar tipos antes de desplegar
```
Despliegue: `scp` del archivo al VPS → `npm run build` allí → `pm2 restart Rapi-Team-App-Api`.
Cada paso a mano y verificado, sin scripts.

### Panel admin (from /admin)
```bash
npm run build
# despliegue: scp -P 65002 dist/* dist/.htaccess a Hostinger
```

## User Roles
1. **Passenger** - Request rides, track, pay
2. **Driver** - Accept rides, navigate, earn
3. **Admin** - Dashboard, user management, analytics

## Important Notes
- DO NOT modify `firebase_options.dart` without confirmation
- MercadoPago: la `publicKey` la devuelve el backend Node al crear la preferencia
  (`payment_service.dart`), no Cloud Functions
- OAuth Client IDs are in `lib/config/oauth_config.dart`
- Environment variables in `app/.env` y `/var/www/Rapi-Team-App-Api/.env` (VPS)
- Support email: `facturacion.rapiteam@gmail.com`

---
*Last updated: March 2026*
