#!/bin/bash

# Script para generar IPA de iOS firmado para producción
# RappiTaxi - Build iOS Release
# Nota: Este script debe ejecutarse en macOS con Xcode instalado

set -e # Salir si hay algún error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Verificar que estamos en macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}❌ Este script debe ejecutarse en macOS${NC}"
    echo -e "${RED}Para builds de iOS se requiere Xcode y macOS${NC}"
    exit 1
fi

# Variables de configuración
PROJECT_DIR="$(pwd)"
APP_DIR="$PROJECT_DIR/app"
IOS_DIR="$APP_DIR/ios"
BUILD_DIR="$APP_DIR/build"
OUTPUT_DIR="$PROJECT_DIR/releases/ios"

echo -e "${BLUE}=== RappiTaxi - iOS Release Build ===${NC}"
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

# Verificar Xcode
echo -e "${YELLOW}🔍 Verificando Xcode...${NC}"
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}❌ Xcode no está instalado o xcodebuild no está en PATH${NC}"
    exit 1
fi

XCODE_VERSION=$(xcodebuild -version | head -n 1)
echo -e "${GREEN}✅ $XCODE_VERSION${NC}"

# Verificar CocoaPods
echo -e "${YELLOW}🔍 Verificando CocoaPods...${NC}"
if ! command -v pod &> /dev/null; then
    echo -e "${YELLOW}⚠️  CocoaPods no encontrado, intentando instalar...${NC}"
    sudo gem install cocoapods
fi

POD_VERSION=$(pod --version)
echo -e "${GREEN}✅ CocoaPods $POD_VERSION${NC}"

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

# Actualizar pods de iOS
echo -e "${YELLOW}📦 Actualizando CocoaPods...${NC}"
cd "$IOS_DIR"
pod install --repo-update
cd "$APP_DIR"

# Verificar configuración de Firebase
if [ ! -f "lib/firebase_options.dart" ]; then
    echo -e "${RED}❌ Error: firebase_options.dart no encontrado${NC}"
    echo -e "${RED}Ejecuta 'flutterfire configure' para generar la configuración${NC}"
    exit 1
fi

# Verificar configuración de iOS
if [ ! -f "$IOS_DIR/Runner.xcworkspace" ]; then
    echo -e "${RED}❌ Error: Runner.xcworkspace no encontrado${NC}"
    echo -e "${RED}Ejecuta 'pod install' en el directorio ios/${NC}"
    exit 1
fi

# Verificar signing y provisioning profiles
echo -e "${YELLOW}🔐 Verificando configuración de signing...${NC}"
TEAM_ID=$(grep -r "DEVELOPMENT_TEAM" "$IOS_DIR" | head -n 1 | cut -d'=' -f2 | tr -d ' ;')
if [ -z "$TEAM_ID" ]; then
    echo -e "${RED}❌ Error: DEVELOPMENT_TEAM no configurado${NC}"
    echo -e "${RED}Configura tu Team ID en Xcode (ios/Runner.xcworkspace)${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Team ID: $TEAM_ID${NC}"

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

# Build iOS Release
echo -e "${YELLOW}🏗️  Construyendo iOS Release...${NC}"
flutter build ios --release --verbose

# Variables para el archivo
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
VERSION=$(grep "version:" pubspec.yaml | cut -d' ' -f2)
APP_NAME="RappiTaxi"
SCHEME="Runner"

# Crear archivo de exportación
EXPORT_PLIST="$IOS_DIR/ExportOptions.plist"
cat > "$EXPORT_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
EOF

echo -e "${GREEN}✅ Archivo ExportOptions.plist creado${NC}"

# Archive
echo -e "${YELLOW}📦 Creando archive...${NC}"
cd "$IOS_DIR"

ARCHIVE_PATH="$BUILD_DIR/ios_archive/${APP_NAME}.xcarchive"
mkdir -p "$(dirname "$ARCHIVE_PATH")"

xcodebuild -workspace Runner.xcworkspace \
           -scheme "$SCHEME" \
           -configuration Release \
           -destination generic/platform=iOS \
           -archivePath "$ARCHIVE_PATH" \
           archive

if [ ! -d "$ARCHIVE_PATH" ]; then
    echo -e "${RED}❌ Error: Archive no se creó correctamente${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Archive creado: $ARCHIVE_PATH${NC}"

# Export IPA
echo -e "${YELLOW}📦 Exportando IPA...${NC}"
IPA_PATH="$OUTPUT_DIR/${APP_NAME}-v${VERSION}-${TIMESTAMP}.ipa"
EXPORT_PATH="$(dirname "$IPA_PATH")/export_temp"

mkdir -p "$EXPORT_PATH"

xcodebuild -exportArchive \
           -archivePath "$ARCHIVE_PATH" \
           -exportPath "$EXPORT_PATH" \
           -exportOptionsPlist "$EXPORT_PLIST"

# Mover IPA al destino final
if [ -f "$EXPORT_PATH/$APP_NAME.ipa" ]; then
    mv "$EXPORT_PATH/$APP_NAME.ipa" "$IPA_PATH"
    rm -rf "$EXPORT_PATH"
    echo -e "${GREEN}✅ IPA exportado: $IPA_PATH${NC}"
    
    # Obtener información del IPA
    IPA_SIZE=$(ls -lh "$IPA_PATH" | awk '{print $5}')
    echo -e "${BLUE}📱 Tamaño del IPA: $IPA_SIZE${NC}"
else
    echo -e "${RED}❌ Error: IPA no se exportó correctamente${NC}"
    rm -rf "$EXPORT_PATH"
    exit 1
fi

# Crear archivo de información del build
cd "$APP_DIR"
BUILD_INFO="$OUTPUT_DIR/${APP_NAME}-v${VERSION}-buildinfo-${TIMESTAMP}.txt"
cat > "$BUILD_INFO" << EOF
RappiTaxi - iOS Build Information
=================================
Fecha de build: $(date)
Versión: $VERSION
Flutter: $FLUTTER_VERSION
Xcode: $XCODE_VERSION
CocoaPods: $POD_VERSION
Team ID: $TEAM_ID
Commit: $(git rev-parse HEAD 2>/dev/null || echo "N/A")
Branch: $(git branch --show-current 2>/dev/null || echo "N/A")

Archivos generados:
- IPA: $(basename "$IPA_PATH")
- Archive: $ARCHIVE_PATH

Checksum MD5:
IPA: $(md5 -q "$IPA_PATH" 2>/dev/null || echo "N/A")

Próximos pasos:
1. Subir IPA a App Store Connect usando Transporter o Xcode
2. Configurar información de la app en App Store Connect
3. Enviar para revisión de Apple
EOF

echo -e "${GREEN}✅ Información del build guardada en: $BUILD_INFO${NC}"

# Validar IPA (opcional)
echo -e "${YELLOW}🔍 Validando IPA...${NC}"
if command -v xcrun altool &> /dev/null; then
    echo -e "${BLUE}Para validar el IPA ejecuta:${NC}"
    echo "xcrun altool --validate-app -f \"$IPA_PATH\" -t ios -u [APPLE_ID] -p [PASSWORD]"
else
    echo -e "${YELLOW}⚠️  xcrun altool no disponible para validación automática${NC}"
fi

# Limpiar archivos temporales
rm -f "$EXPORT_PLIST"

# Resumen final
echo ""
echo -e "${GREEN}🎉 Build de iOS completado exitosamente!${NC}"
echo -e "${BLUE}=== Resumen ===${NC}"
echo -e "${BLUE}Versión: $VERSION${NC}"
echo -e "${BLUE}IPA: $IPA_PATH${NC}"
echo -e "${BLUE}Tamaño: $IPA_SIZE${NC}"

echo ""
echo -e "${GREEN}📋 Siguiente paso: Subir IPA a App Store Connect${NC}"
echo -e "${YELLOW}💡 Usa Transporter (App Store) o Xcode para subir el IPA${NC}"

# Mostrar comandos útiles
echo ""
echo -e "${BLUE}=== Comandos útiles ===${NC}"
echo -e "${YELLOW}Subir a App Store Connect con altool:${NC}"
echo "xcrun altool --upload-app -f \"$IPA_PATH\" -t ios -u [APPLE_ID] -p [PASSWORD]"
echo ""
echo -e "${YELLOW}Abrir Transporter:${NC}"
echo "open -a Transporter"

exit 0