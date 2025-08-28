#!/bin/bash

# Script para configurar el firmado de Android para producción
# RappiTaxi - Setup Android Signing

set -e # Salir si hay algún error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
APP_DIR="/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi/app"
ANDROID_DIR="$APP_DIR/android"
KEYSTORE_PATH="$ANDROID_DIR/app/keystore.jks"
KEY_PROPERTIES="$ANDROID_DIR/key.properties"

echo -e "${BLUE}=== RappiTaxi - Configuración de Android Signing ===${NC}"
echo ""

# Verificar directorio Android
if [ ! -d "$ANDROID_DIR" ]; then
    echo -e "${RED}❌ Error: Directorio Android no encontrado en $ANDROID_DIR${NC}"
    exit 1
fi

cd "$ANDROID_DIR"

# Función para generar keystore
generate_keystore() {
    echo -e "${YELLOW}🔐 Generando nuevo keystore...${NC}"
    
    # Solicitar información
    read -p "Alias de la clave (ej: rappitaxi-key): " KEY_ALIAS
    read -s -p "Contraseña del keystore: " STORE_PASSWORD
    echo
    read -s -p "Confirma la contraseña del keystore: " STORE_PASSWORD_CONFIRM
    echo
    
    if [ "$STORE_PASSWORD" != "$STORE_PASSWORD_CONFIRM" ]; then
        echo -e "${RED}❌ Las contraseñas no coinciden${NC}"
        return 1
    fi
    
    read -s -p "Contraseña de la clave: " KEY_PASSWORD
    echo
    read -s -p "Confirma la contraseña de la clave: " KEY_PASSWORD_CONFIRM
    echo
    
    if [ "$KEY_PASSWORD" != "$KEY_PASSWORD_CONFIRM" ]; then
        echo -e "${RED}❌ Las contraseñas de la clave no coinciden${NC}"
        return 1
    fi
    
    # Información del certificado
    read -p "Nombre (CN): " CERT_NAME
    read -p "Unidad organizacional (OU): " CERT_OU
    read -p "Organización (O): " CERT_O
    read -p "Ciudad (L): " CERT_L
    read -p "Estado/Provincia (ST): " CERT_ST
    read -p "Código de país (C - 2 letras): " CERT_C
    
    # Generar keystore
    keytool -genkey \
        -v \
        -keystore "$KEYSTORE_PATH" \
        -alias "$KEY_ALIAS" \
        -keyalg RSA \
        -keysize 2048 \
        -validity 10000 \
        -storepass "$STORE_PASSWORD" \
        -keypass "$KEY_PASSWORD" \
        -dname "CN=$CERT_NAME, OU=$CERT_OU, O=$CERT_O, L=$CERT_L, ST=$CERT_ST, C=$CERT_C"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Keystore generado exitosamente: $KEYSTORE_PATH${NC}"
        
        # Crear key.properties
        create_key_properties "$KEY_ALIAS" "$KEY_PASSWORD" "$STORE_PASSWORD"
    else
        echo -e "${RED}❌ Error generando keystore${NC}"
        return 1
    fi
}

# Función para crear key.properties
create_key_properties() {
    local alias=$1
    local key_pass=$2
    local store_pass=$3
    
    cat > "$KEY_PROPERTIES" << EOF
storePassword=$store_pass
keyPassword=$key_pass
keyAlias=$alias
storeFile=keystore.jks
EOF
    
    echo -e "${GREEN}✅ Archivo key.properties creado${NC}"
    
    # Establecer permisos restrictivos
    chmod 600 "$KEY_PROPERTIES"
    chmod 600 "$KEYSTORE_PATH"
    
    echo -e "${YELLOW}🔒 Permisos restrictivos aplicados a archivos de signing${NC}"
}

# Función para verificar configuración existente
verify_existing_setup() {
    echo -e "${YELLOW}🔍 Verificando configuración existente...${NC}"
    
    local has_keystore=false
    local has_properties=false
    
    if [ -f "$KEYSTORE_PATH" ]; then
        echo -e "${GREEN}✅ Keystore encontrado: $KEYSTORE_PATH${NC}"
        has_keystore=true
    else
        echo -e "${RED}❌ Keystore no encontrado${NC}"
    fi
    
    if [ -f "$KEY_PROPERTIES" ]; then
        echo -e "${GREEN}✅ key.properties encontrado${NC}"
        has_properties=true
    else
        echo -e "${RED}❌ key.properties no encontrado${NC}"
    fi
    
    if [ "$has_keystore" = true ] && [ "$has_properties" = true ]; then
        echo -e "${GREEN}🎉 Configuración de signing completa${NC}"
        
        # Mostrar información del keystore
        echo -e "${BLUE}📋 Información del keystore:${NC}"
        keytool -list -v -keystore "$KEYSTORE_PATH" -storepass "$(grep storePassword "$KEY_PROPERTIES" | cut -d'=' -f2)" || true
        
        return 0
    else
        return 1
    fi
}

# Función para configurar build.gradle
configure_build_gradle() {
    local BUILD_GRADLE="$ANDROID_DIR/app/build.gradle"
    
    if [ ! -f "$BUILD_GRADLE" ]; then
        echo -e "${RED}❌ build.gradle no encontrado${NC}"
        return 1
    fi
    
    # Hacer backup
    cp "$BUILD_GRADLE" "$BUILD_GRADLE.backup"
    
    echo -e "${YELLOW}🔧 Configurando build.gradle...${NC}"
    
    # Verificar si ya está configurado
    if grep -q "signingConfigs" "$BUILD_GRADLE"; then
        echo -e "${YELLOW}⚠️  build.gradle ya parece tener configuración de signing${NC}"
        read -p "¿Reconfigurar? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi
    
    # Agregar configuración de signing
    # Nota: Esta es una configuración básica, podría necesitar ajustes manuales
    echo -e "${BLUE}📝 Agregando configuración de signing a build.gradle${NC}"
    echo -e "${YELLOW}⚠️  IMPORTANTE: Revisa manualmente el archivo build.gradle después${NC}"
    echo -e "${YELLOW}   La configuración automática podría necesitar ajustes${NC}"
    
    cat >> "$BUILD_GRADLE" << 'EOF'

// Configuración de signing agregada por setup_android_signing.sh
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled false
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}
EOF
}

# Función para mostrar siguiente pasos
show_next_steps() {
    echo ""
    echo -e "${BLUE}=== Siguientes pasos ===${NC}"
    echo -e "${GREEN}1.${NC} Guarda de forma segura las contraseñas del keystore y la clave"
    echo -e "${GREEN}2.${NC} Nunca comitees el archivo key.properties al repositorio"
    echo -e "${GREEN}3.${NC} Agrega key.properties al .gitignore si no está ya"
    echo -e "${GREEN}4.${NC} Haz backup del keystore en un lugar seguro"
    echo -e "${GREEN}5.${NC} Ejecuta un build de prueba: ./scripts/build_android_release.sh"
    
    echo ""
    echo -e "${YELLOW}⚠️  IMPORTANTE: Archivos de signing${NC}"
    echo -e "${YELLOW}   - Keystore: $KEYSTORE_PATH${NC}"
    echo -e "${YELLOW}   - Properties: $KEY_PROPERTIES${NC}"
    echo -e "${YELLOW}   - Backup build.gradle: $ANDROID_DIR/app/build.gradle.backup${NC}"
    
    echo ""
    echo -e "${BLUE}🔐 Para GitHub Actions, configura estos secrets:${NC}"
    echo -e "${YELLOW}   ANDROID_KEYSTORE_BASE64: $(base64 -w 0 "$KEYSTORE_PATH" 2>/dev/null || base64 "$KEYSTORE_PATH" | tr -d '\n')${NC}"
    echo -e "${YELLOW}   ANDROID_KEY_ALIAS: $(grep keyAlias "$KEY_PROPERTIES" | cut -d'=' -f2)${NC}"
    echo -e "${YELLOW}   ANDROID_KEY_PASSWORD: [La contraseña de la clave que ingresaste]${NC}"
    echo -e "${YELLOW}   ANDROID_STORE_PASSWORD: [La contraseña del keystore que ingresaste]${NC}"
}

# Menú principal
main_menu() {
    echo "Selecciona una opción:"
    echo "1. Verificar configuración existente"
    echo "2. Generar nuevo keystore"
    echo "3. Configurar build.gradle"
    echo "4. Mostrar pasos siguientes"
    echo "5. Salir"
    
    read -p "Opción (1-5): " -n 1 -r
    echo
    
    case $REPLY in
        1)
            verify_existing_setup
            ;;
        2)
            generate_keystore
            ;;
        3)
            configure_build_gradle
            ;;
        4)
            show_next_steps
            ;;
        5)
            echo -e "${BLUE}👋 ¡Hasta luego!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Opción inválida${NC}"
            main_menu
            ;;
    esac
}

# Verificar Java/keytool
if ! command -v keytool &> /dev/null; then
    echo -e "${RED}❌ keytool no encontrado. Instala Java JDK${NC}"
    exit 1
fi

# Agregar key.properties al .gitignore si no está
GITIGNORE_PATH="/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi/.gitignore"
if [ -f "$GITIGNORE_PATH" ]; then
    if ! grep -q "key.properties" "$GITIGNORE_PATH"; then
        echo "" >> "$GITIGNORE_PATH"
        echo "# Android signing" >> "$GITIGNORE_PATH"
        echo "android/key.properties" >> "$GITIGNORE_PATH"
        echo "android/app/keystore.jks" >> "$GITIGNORE_PATH"
        echo -e "${GREEN}✅ key.properties agregado a .gitignore${NC}"
    fi
fi

# Ejecutar verificación inicial
if verify_existing_setup; then
    echo ""
    read -p "¿Quieres reconfigurar el signing? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        show_next_steps
        exit 0
    fi
fi

# Mostrar menú
main_menu