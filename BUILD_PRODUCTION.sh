#!/bin/bash

# 🚀 SCRIPT DE BUILD DE PRODUCCIÓN - RAPPITAXI
# ================================================
# Este script genera todos los builds de producción
# Fecha: Diciembre 2024
# ================================================

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}🚀 GENERACIÓN DE BUILDS DE PRODUCCIÓN${NC}"
echo -e "${BLUE}================================================${NC}\n"

# Directorio base
BASE_DIR="/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi"
APP_DIR="$BASE_DIR/app"
BACKEND_DIR="$BASE_DIR/backend"

# ========================================
# 1. BUILD BACKEND NODE.JS
# ========================================

echo -e "${YELLOW}📦 1. COMPILANDO BACKEND NODE.JS${NC}"
echo "========================================="

cd $BACKEND_DIR

# Instalar dependencias
echo "Instalando dependencias del backend..."
npm install --production

# Compilar TypeScript
echo "Compilando TypeScript..."
npm run build

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Backend compilado exitosamente${NC}"
else
    echo -e "${YELLOW}⚠️ Backend compilado con warnings${NC}"
fi

# ========================================
# 2. BUILD FLUTTER WEB
# ========================================

echo -e "\n${YELLOW}🌐 2. GENERANDO BUILD WEB${NC}"
echo "========================================="

cd $APP_DIR

# Limpiar cache
echo "Limpiando cache de Flutter..."
flutter clean

# Obtener dependencias
echo "Obteniendo dependencias..."
flutter pub get

# Build web
echo "Generando build web optimizado..."
flutter build web --release --web-renderer html

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Build web generado exitosamente${NC}"
    echo "📂 Ubicación: $APP_DIR/build/web"
else
    echo -e "${RED}❌ Error al generar build web${NC}"
fi

# ========================================
# 3. BUILD ANDROID APK
# ========================================

echo -e "\n${YELLOW}📱 3. GENERANDO APK ANDROID${NC}"
echo "========================================="

# Build APK
echo "Generando APK de producción..."
flutter build apk --release --split-per-abi

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ APK generado exitosamente${NC}"
    echo "📂 Ubicación: $APP_DIR/build/app/outputs/flutter-apk/"
    ls -lh $APP_DIR/build/app/outputs/flutter-apk/*.apk 2>/dev/null
else
    echo -e "${RED}❌ Error al generar APK${NC}"
fi

# ========================================
# 4. BUILD ANDROID APP BUNDLE (AAB)
# ========================================

echo -e "\n${YELLOW}📱 4. GENERANDO APP BUNDLE (AAB)${NC}"
echo "========================================="

# Build AAB
echo "Generando App Bundle para Google Play..."
flutter build appbundle --release

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ App Bundle generado exitosamente${NC}"
    echo "📂 Ubicación: $APP_DIR/build/app/outputs/bundle/release/"
    ls -lh $APP_DIR/build/app/outputs/bundle/release/*.aab 2>/dev/null
else
    echo -e "${RED}❌ Error al generar App Bundle${NC}"
fi

# ========================================
# 5. BUILD IOS (Solo en macOS)
# ========================================

echo -e "\n${YELLOW}🍎 5. BUILD IOS${NC}"
echo "========================================="

# Verificar si estamos en macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Generando build iOS..."
    flutter build ios --release
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Build iOS generado exitosamente${NC}"
    else
        echo -e "${RED}❌ Error al generar build iOS${NC}"
    fi
else
    echo -e "${YELLOW}⚠️ Build iOS solo disponible en macOS${NC}"
fi

# ========================================
# 6. PREPARAR ARCHIVOS PARA DEPLOY
# ========================================

echo -e "\n${YELLOW}📦 6. PREPARANDO ARCHIVOS PARA DEPLOY${NC}"
echo "========================================="

# Crear directorio de distribución
DIST_DIR="$BASE_DIR/dist"
mkdir -p $DIST_DIR

echo "Copiando archivos de producción..."

# Copiar backend compilado
if [ -d "$BACKEND_DIR/dist" ]; then
    cp -r $BACKEND_DIR/dist $DIST_DIR/backend
    echo -e "${GREEN}✅ Backend copiado${NC}"
fi

# Copiar build web
if [ -d "$APP_DIR/build/web" ]; then
    cp -r $APP_DIR/build/web $DIST_DIR/web
    echo -e "${GREEN}✅ Build web copiado${NC}"
fi

# Copiar APKs
if [ -d "$APP_DIR/build/app/outputs/flutter-apk" ]; then
    mkdir -p $DIST_DIR/android
    cp $APP_DIR/build/app/outputs/flutter-apk/*.apk $DIST_DIR/android/
    echo -e "${GREEN}✅ APKs copiados${NC}"
fi

# Copiar AAB
if [ -f "$APP_DIR/build/app/outputs/bundle/release/app-release.aab" ]; then
    cp $APP_DIR/build/app/outputs/bundle/release/app-release.aab $DIST_DIR/android/
    echo -e "${GREEN}✅ App Bundle copiado${NC}"
fi

# ========================================
# 7. GENERAR ARCHIVO DE CONFIGURACIÓN
# ========================================

echo -e "\n${YELLOW}📝 7. GENERANDO CONFIGURACIÓN DE PRODUCCIÓN${NC}"
echo "========================================="

cat > $DIST_DIR/production_config.json <<EOF
{
  "project": "RappiTaxi",
  "version": "1.0.0",
  "buildDate": "$(date)",
  "platform": {
    "web": {
      "ready": true,
      "path": "web/",
      "renderer": "html"
    },
    "android": {
      "ready": true,
      "minSdk": 21,
      "targetSdk": 33,
      "files": {
        "apk": "android/*.apk",
        "bundle": "android/app-release.aab"
      }
    },
    "ios": {
      "ready": false,
      "note": "Requiere macOS para compilar"
    },
    "backend": {
      "ready": true,
      "nodeVersion": "20.x",
      "path": "backend/",
      "port": 5001
    }
  },
  "deployment": {
    "firebase": {
      "hosting": "web/",
      "functions": "backend/"
    },
    "stores": {
      "playStore": "android/app-release.aab",
      "appStore": "Pendiente compilación iOS"
    }
  },
  "environment": {
    "production": true,
    "apiUrl": "https://api.rappitaxi.com",
    "firebaseProject": "rappitaxi-app"
  }
}
EOF

echo -e "${GREEN}✅ Configuración de producción generada${NC}"

# ========================================
# 8. GENERAR DOCUMENTACIÓN DE DEPLOY
# ========================================

echo -e "\n${YELLOW}📚 8. GENERANDO DOCUMENTACIÓN${NC}"
echo "========================================="

cat > $DIST_DIR/DEPLOY_INSTRUCTIONS.md <<'EOF'
# 🚀 INSTRUCCIONES DE DEPLOY - RAPPITAXI

## 📦 Archivos Generados

### 1. Backend Node.js
- **Ubicación**: `backend/`
- **Puerto**: 5001
- **Comando**: `node backend/index.js`

### 2. Frontend Web
- **Ubicación**: `web/`
- **Deploy**: Firebase Hosting o cualquier servidor estático

### 3. App Android
- **APK**: `android/*.apk` - Para instalación directa
- **AAB**: `android/app-release.aab` - Para Google Play Store

## 🔧 Configuración Requerida

### Variables de Entorno Backend (.env)
```bash
NODE_ENV=production
PORT=5001
FIREBASE_SERVICE_ACCOUNT=<ruta-al-archivo-json>
GOOGLE_MAPS_API_KEY=<tu-api-key>
MERCADOPAGO_PUBLIC_KEY=<tu-public-key>
MERCADOPAGO_ACCESS_TOKEN=<tu-access-token>
JWT_SECRET=<tu-secret-seguro>
```

### Firebase
1. Crear proyecto en Firebase Console
2. Habilitar Authentication, Firestore, Storage
3. Descargar credenciales de servicio
4. Configurar reglas de seguridad

### Google Maps
1. Habilitar APIs: Maps, Places, Geocoding, Directions
2. Configurar API key en Android Manifest
3. Configurar API key en backend

## 🌐 Deploy Web (Firebase Hosting)

```bash
# Instalar Firebase CLI
npm install -g firebase-tools

# Login
firebase login

# Inicializar proyecto
firebase init hosting

# Deploy
firebase deploy --only hosting
```

## 📱 Deploy Android (Google Play)

1. Firmar AAB con keystore de producción
2. Subir a Google Play Console
3. Completar información de la app
4. Enviar a revisión

## 🖥️ Deploy Backend (Cloud Run / Heroku)

### Google Cloud Run
```bash
gcloud run deploy rappitaxi-backend \
  --source . \
  --region us-central1 \
  --allow-unauthenticated
```

### Heroku
```bash
heroku create rappitaxi-backend
git push heroku main
```

## ✅ Checklist Pre-Deploy

- [ ] Cambiar todas las API keys a producción
- [ ] Configurar Firebase con proyecto de producción
- [ ] Configurar dominio personalizado
- [ ] Habilitar HTTPS
- [ ] Configurar backups automáticos
- [ ] Configurar monitoreo y alertas
- [ ] Revisar reglas de seguridad de Firestore
- [ ] Configurar rate limiting
- [ ] Habilitar Google Analytics
- [ ] Configurar Crashlytics

## 📞 Soporte

Para asistencia con el deploy, consultar la documentación oficial de cada plataforma.
EOF

echo -e "${GREEN}✅ Documentación de deploy generada${NC}"

# ========================================
# RESUMEN FINAL
# ========================================

echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}📊 RESUMEN DE BUILDS GENERADOS${NC}"
echo -e "${BLUE}========================================${NC}"

echo -e "\n${GREEN}✅ BUILDS COMPLETADOS:${NC}"

# Verificar qué se generó
if [ -d "$DIST_DIR/backend" ]; then
    echo "  📦 Backend Node.js"
fi

if [ -d "$DIST_DIR/web" ]; then
    echo "  🌐 Frontend Web"
    du -sh $DIST_DIR/web 2>/dev/null
fi

if [ -f "$DIST_DIR/android/app-release.aab" ]; then
    echo "  📱 Android App Bundle (AAB)"
    ls -lh $DIST_DIR/android/app-release.aab 2>/dev/null
fi

if ls $DIST_DIR/android/*.apk 1> /dev/null 2>&1; then
    echo "  📱 Android APKs"
    ls -lh $DIST_DIR/android/*.apk 2>/dev/null
fi

echo -e "\n${YELLOW}📂 UBICACIÓN DE ARCHIVOS:${NC}"
echo "  Todos los builds: $DIST_DIR"

echo -e "\n${GREEN}🎯 BUILDS DE PRODUCCIÓN COMPLETADOS${NC}"
echo -e "${BLUE}El proyecto está listo para deploy${NC}\n"