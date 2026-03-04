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
├── src/                          # Backend Express.js (standalone)
├── functions/                    # Firebase Cloud Functions
├── firebase.json                 # Firebase services config
├── .firebaserc                   # Active project: rapi-team
├── firestore.rules               # Firestore security rules
└── storage.rules                 # Storage security rules
```

## Firebase Configuration
- **Project ID**: `rapi-team`
- **Project Number**: `52925359166`
- **Android Package**: `com.rapiteam.app`
- **iOS Bundle ID**: `com.rapiteam.app`
- **Auth Domain**: `rapi-team.firebaseapp.com`
- **Storage Bucket**: `rapi-team.firebasestorage.app`

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

### Backend
- **Runtime**: Node.js with TypeScript
- **Framework**: Express.js
- **Database**: Firebase Admin SDK (Firestore)
- **Functions**: Firebase Cloud Functions
- **Payments**: MercadoPago API

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

### Backend (from root)
```bash
npm install && npm run dev
```

### Cloud Functions (from /functions)
```bash
npm install && npm run build
firebase deploy --only functions
```

## User Roles
1. **Passenger** - Request rides, track, pay
2. **Driver** - Accept rides, navigate, earn
3. **Admin** - Dashboard, user management, analytics

## Important Notes
- DO NOT modify `firebase_options.dart` without confirmation
- MercadoPago keys are fetched dynamically from Cloud Functions
- OAuth Client IDs are in `lib/config/oauth_config.dart`
- Environment variables in `app/.env` and `functions/.env`
- Support email: `facturacion.rapiteam@gmail.com`

---
*Last updated: March 2026*
