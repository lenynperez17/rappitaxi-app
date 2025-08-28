#!/bin/bash

# Script para generar APK y Bundle de Android firmado para producción
# RappiTaxi - Build Android Release

set -e # Salir si hay algún error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables de configuración
PROJECT_DIR="/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi"
APP_DIR="$PROJECT_DIR/app"
BUILD_DIR="$APP_DIR/build"
OUTPUT_DIR="$PROJECT_DIR/releases/android"

echo -e "${BLUE}=== RappiTaxi - Android Release Build ===${NC}"
echo -e "${BLUE}Fecha: $(date)${NC}"
echo ""

# Verificar que estamos en el directorio correcto
if [ ! -f "$APP_DIR/pubspec.yaml" ]; then
    echo -e "${RED}❌ Error: No se encontró pubspec.yaml en $APP_DIR${NC}"
    echo -e "${RED}Asegúrate de ejecutar este script desde la raíz del proyecto${NC}"
    exit 1
fi

# Verificar Flutter
echo -e "${YELLOW}🔍 Verificando Flutter...${NC}"
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter no está instalado o no está en PATH${NC}"
    exit 1
fi

FLUTTER_VERSION=$(flutter --version | head -n 1)
echo -e "${GREEN}✅ $FLUTTER_VERSION${NC}"

# Verificar Java
echo -e "${YELLOW}🔍 Verificando Java...${NC}"
if ! command -v java &> /dev/null; then
    echo -e "${RED}❌ Java no está instalado o no está en PATH${NC}"
    exit 1
fi

JAVA_VERSION=$(java -version 2>&1 | head -n 1)
echo -e "${GREEN}✅ $JAVA_VERSION${NC}"

# Cambiar al directorio de la app
cd "$APP_DIR"

# Limpiar builds anteriores
echo -e "${YELLOW}🧹 Limpiando builds anteriores...${NC}"
flutter clean

# Obtener dependencias
echo -e "${YELLOW}📦 Obteniendo dependencias...${NC}"
flutter pub get

# Generar código (build_runner para Freezed, etc.)
echo -e "${YELLOW}🔧 Generando código...${NC}"
flutter pub run build_runner build --delete-conflicting-outputs

# Verificar configuración de Firebase
if [ ! -f "lib/firebase_options.dart" ]; then
    echo -e "${RED}❌ Error: firebase_options.dart no encontrado${NC}"
    echo -e "${RED}Ejecuta 'flutterfire configure' para generar la configuración${NC}"
    exit 1
fi

# Verificar configuración de signing
if [ ! -f "android/key.properties" ]; then
    echo -e "${YELLOW}⚠️  Advertencia: android/key.properties no encontrado${NC}"
    echo -e "${YELLOW}Se construirá sin firmar (solo para debug)${NC}"
    
    # Preguntar si continuar
    read -p "¿Continuar sin firmar? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Build cancelado${NC}"
        exit 1
    fi
    SIGNED_BUILD=false
else
    echo -e "${GREEN}✅ Configuración de signing encontrada${NC}"
    SIGNED_BUILD=true
fi

# Ejecutar análisis de código
echo -e "${YELLOW}🔍 Ejecutando análisis de código...${NC}"
if ! flutter analyze --no-fatal-infos; then
    echo -e "${RED}❌ Error en análisis de código${NC}"
    read -p "¿Continuar de todos modos? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Ejecutar tests
echo -e "${YELLOW}🧪 Ejecutando tests...${NC}"
if ! flutter test; then
    echo -e "${RED}❌ Error en tests${NC}"
    read -p "¿Continuar de todos modos? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Crear directorio de salida
mkdir -p "$OUTPUT_DIR"

# Build APK
echo -e "${YELLOW}🏗️  Construyendo APK Release...${NC}"
if [ "$SIGNED_BUILD" = true ]; then
    flutter build apk --release --verbose
else
    flutter build apk --debug --verbose
fi

# Build App Bundle
echo -e "${YELLOW}🏗️  Construyendo App Bundle Release...${NC}"
if [ "$SIGNED_BUILD" = true ]; then
    flutter build appbundle --release --verbose
else
    flutter build appbundle --debug --verbose
fi

# Copiar archivos al directorio de salida
echo -e "${YELLOW}📦 Copiando archivos de salida...${NC}"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
VERSION=$(grep "version:" pubspec.yaml | cut -d' ' -f2)

if [ "$SIGNED_BUILD" = true ]; then
    APK_SOURCE="build/app/outputs/apk/release/app-release.apk"
    BUNDLE_SOURCE="build/app/outputs/bundle/release/app-release.aab"
    APK_OUTPUT="$OUTPUT_DIR/rappitaxi-v${VERSION}-release-${TIMESTAMP}.apk"
    BUNDLE_OUTPUT="$OUTPUT_DIR/rappitaxi-v${VERSION}-release-${TIMESTAMP}.aab"
else
    APK_SOURCE="build/app/outputs/apk/debug/app-debug.apk"
    BUNDLE_SOURCE="build/app/outputs/bundle/debug/app-debug.aab"
    APK_OUTPUT="$OUTPUT_DIR/rappitaxi-v${VERSION}-debug-${TIMESTAMP}.apk"
    BUNDLE_OUTPUT="$OUTPUT_DIR/rappitaxi-v${VERSION}-debug-${TIMESTAMP}.aab"
fi

# Copiar APK
if [ -f "$APK_SOURCE" ]; then
    cp "$APK_SOURCE" "$APK_OUTPUT"
    echo -e "${GREEN}✅ APK copiado a: $APK_OUTPUT${NC}"
    
    # Obtener información del APK
    APK_SIZE=$(ls -lh "$APK_OUTPUT" | awk '{print $5}')
    echo -e "${BLUE}📱 Tamaño del APK: $APK_SIZE${NC}"
else
    echo -e "${RED}❌ Error: APK no encontrado en $APK_SOURCE${NC}"
fi

# Copiar App Bundle
if [ -f "$BUNDLE_SOURCE" ]; then
    cp "$BUNDLE_SOURCE" "$BUNDLE_OUTPUT"
    echo -e "${GREEN}✅ App Bundle copiado a: $BUNDLE_OUTPUT${NC}"
    
    # Obtener información del Bundle
    BUNDLE_SIZE=$(ls -lh "$BUNDLE_OUTPUT" | awk '{print $5}')
    echo -e "${BLUE}📱 Tamaño del App Bundle: $BUNDLE_SIZE${NC}"
else
    echo -e "${RED}❌ Error: App Bundle no encontrado en $BUNDLE_SOURCE${NC}"
fi

# Crear archivo de información del build
BUILD_INFO="$OUTPUT_DIR/rappitaxi-v${VERSION}-buildinfo-${TIMESTAMP}.txt"
cat > "$BUILD_INFO" << EOF
RappiTaxi - Android Build Information
=====================================
Fecha de build: $(date)
Versión: $VERSION
Flutter: $FLUTTER_VERSION
Java: $JAVA_VERSION
Firmado: $SIGNED_BUILD
Commit: $(git rev-parse HEAD 2>/dev/null || echo "N/A")
Branch: $(git branch --show-current 2>/dev/null || echo "N/A")

Archivos generados:
- APK: $(basename "$APK_OUTPUT")
- Bundle: $(basename "$BUNDLE_OUTPUT")

Checksums MD5:
EOF

# Agregar checksums si los archivos existen
if [ -f "$APK_OUTPUT" ]; then
    echo "APK: $(md5sum "$APK_OUTPUT" | cut -d' ' -f1)" >> "$BUILD_INFO"
fi
if [ -f "$BUNDLE_OUTPUT" ]; then
    echo "Bundle: $(md5sum "$BUNDLE_OUTPUT" | cut -d' ' -f1)" >> "$BUILD_INFO"
fi

echo -e "${GREEN}✅ Información del build guardada en: $BUILD_INFO${NC}"

# Resumen final
echo ""
echo -e "${GREEN}🎉 Build completado exitosamente!${NC}"
echo -e "${BLUE}=== Resumen ===${NC}"
echo -e "${BLUE}Versión: $VERSION${NC}"
echo -e "${BLUE}Firmado: $SIGNED_BUILD${NC}"
echo -e "${BLUE}Archivos generados en: $OUTPUT_DIR${NC}"

if [ "$SIGNED_BUILD" = true ]; then
    echo ""
    echo -e "${GREEN}📋 Siguiente paso: Subir el App Bundle (.aab) a Google Play Console${NC}"
    echo -e "${YELLOW}📋 El APK (.apk) puede usarse para distribución directa${NC}"
fi

# Mostrar comandos útiles
echo ""
echo -e "${BLUE}=== Comandos útiles ===${NC}"
echo -e "${YELLOW}Instalar APK en dispositivo:${NC}"
echo "adb install \"$APK_OUTPUT\""
echo ""
echo -e "${YELLOW}Abrir directorio de salida:${NC}"
echo "explorer.exe \"$(wslpath -w "$OUTPUT_DIR")\""

exit 0