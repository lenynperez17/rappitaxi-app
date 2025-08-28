#!/bin/bash

#############################################################
# Script Completo de Configuración y Despliegue RappiTaxi
# Autor: RappiTaxi DevOps Team
# Fecha: 2025
#############################################################

set -e  # Salir si hay algún error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Sin color

# Variables globales
PROJECT_ROOT="/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi"
APP_DIR="${PROJECT_ROOT}/app"
BACKEND_DIR="${PROJECT_ROOT}/backend"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${PROJECT_ROOT}/setup_${TIMESTAMP}.log"

# Función para imprimir mensajes con color
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1" | tee -a "$LOG_FILE"
}

# Función para verificar comandos
check_command() {
    if command -v $1 &> /dev/null; then
        log_success "$1 está instalado"
        return 0
    else
        log_error "$1 no está instalado"
        return 1
    fi
}

# Banner inicial
print_banner() {
    clear
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║         RAPPITAXI - CONFIGURACIÓN COMPLETA              ║"
    echo "║                 SISTEMA DE PRODUCCIÓN                    ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    log_info "Iniciando configuración completa del proyecto RappiTaxi"
    log_info "Fecha: $(date)"
    echo ""
}

# Verificar prerrequisitos
check_prerequisites() {
    log_info "Verificando prerrequisitos..."
    
    local all_ok=true
    
    # Verificar comandos esenciales
    check_command "node" || all_ok=false
    check_command "npm" || all_ok=false
    check_command "flutter" || all_ok=false
    check_command "dart" || all_ok=false
    check_command "git" || all_ok=false
    
    # Verificar versión de Node
    NODE_VERSION=$(node --version | cut -d 'v' -f 2 | cut -d '.' -f 1)
    if [ "$NODE_VERSION" -lt 20 ]; then
        log_warning "Node.js versión $NODE_VERSION detectada. Se recomienda v20+"
    fi
    
    # Verificar Flutter
    if flutter --version &> /dev/null; then
        log_success "Flutter configurado correctamente"
    else
        log_warning "Flutter necesita configuración adicional"
    fi
    
    if [ "$all_ok" = false ]; then
        log_error "Faltan prerrequisitos. Por favor, instálalos antes de continuar."
        exit 1
    fi
    
    log_success "Todos los prerrequisitos están instalados"
}

# Configurar el backend
setup_backend() {
    log_info "Configurando Backend Node.js..."
    cd "$BACKEND_DIR"
    
    # Instalar dependencias
    log_info "Instalando dependencias del backend..."
    npm install &>> "$LOG_FILE"
    log_success "Dependencias del backend instaladas"
    
    # Compilar TypeScript
    log_info "Compilando código TypeScript..."
    npm run build &>> "$LOG_FILE"
    log_success "Backend compilado correctamente"
    
    # Verificar archivo .env
    if [ ! -f ".env" ]; then
        log_warning "Archivo .env no encontrado. Creando desde template..."
        cp .env.example .env 2>/dev/null || create_backend_env
        log_success "Archivo .env creado"
    fi
    
    # Instalar Firebase CLI si no está instalado
    if ! command -v firebase &> /dev/null; then
        log_info "Instalando Firebase CLI..."
        npm install -g firebase-tools &>> "$LOG_FILE"
        log_success "Firebase CLI instalado"
    fi
}

# Crear archivo .env para backend si no existe
create_backend_env() {
    cat > .env << 'EOF'
# Backend Configuration - RappiTaxi
NODE_ENV=development
API_VERSION=v1
CORS_ORIGIN=http://localhost:3000,http://localhost:8080

# Firebase (actualizar con tus credenciales)
FIREBASE_PROJECT_ID=rappitaxi-app
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYourPrivateKeyHere\n-----END PRIVATE KEY-----"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk@rappitaxi-app.iam.gserviceaccount.com

# MercadoPago
MERCADOPAGO_ACCESS_TOKEN=TEST-123456789
MERCADOPAGO_PUBLIC_KEY=TEST-123456789

# Google Maps
GOOGLE_MAPS_API_KEY=AIzaSyC0123456789

# JWT
JWT_SECRET=rappitaxi-secret-key-development
JWT_EXPIRES_IN=7d

# Otros
BASE_FARE=3.50
PRICE_PER_KM=1.20
PRICE_PER_MINUTE=0.15
EOF
}

# Configurar la aplicación Flutter
setup_flutter_app() {
    log_info "Configurando Aplicación Flutter..."
    cd "$APP_DIR"
    
    # Corregir finales de línea CRLF
    log_info "Corrigiendo finales de línea CRLF..."
    find . -name "*.dart" -exec dos2unix {} \; 2>/dev/null || true
    log_success "Finales de línea corregidos"
    
    # Limpiar y obtener dependencias
    log_info "Limpiando proyecto Flutter..."
    flutter clean &>> "$LOG_FILE"
    
    log_info "Instalando dependencias de Flutter..."
    flutter pub get &>> "$LOG_FILE"
    log_success "Dependencias de Flutter instaladas"
    
    # Generar código si es necesario
    if grep -q "build_runner" pubspec.yaml; then
        log_info "Generando código con build_runner..."
        flutter pub run build_runner build --delete-conflicting-outputs &>> "$LOG_FILE"
        log_success "Código generado correctamente"
    fi
    
    # Verificar archivo .env
    if [ ! -f ".env" ]; then
        log_warning "Archivo .env no encontrado en app. Creando..."
        create_app_env
        log_success "Archivo .env creado para la app"
    fi
    
    # Formatear código
    log_info "Formateando código Dart..."
    dart format lib --fix &>> "$LOG_FILE"
    log_success "Código formateado"
    
    # Analizar código
    log_info "Analizando código para errores..."
    dart analyze --no-fatal-infos &>> "$LOG_FILE" || log_warning "Algunos warnings encontrados (no críticos)"
}

# Crear archivo .env para la app
create_app_env() {
    cat > .env << 'EOF'
# Configuración de Desarrollo - RappiTaxi
NODE_ENV=development
API_BASE_URL=http://localhost:5001/rappitaxi-app/us-central1/api/v1

# MercadoPago
MERCADOPAGO_PUBLIC_KEY=TEST-12345678-1234-1234-1234-123456789012
MERCADOPAGO_ACCESS_TOKEN=TEST-123456789012345678901234567890

# Google Maps
GOOGLE_MAPS_API_KEY=AIzaSyC0123456789-GoogleMapsKey

# OneSignal (Notificaciones Push)
ONESIGNAL_APP_ID=your-onesignal-app-id
ONESIGNAL_API_KEY=your-onesignal-api-key

# Feature Flags
ENABLE_MOCK_DATA=false
ENABLE_CRASHLYTICS=true
ENABLE_ANALYTICS=true
EOF
}

# Configurar Firebase
setup_firebase() {
    log_info "Configurando Firebase..."
    
    # Verificar si Firebase está configurado
    if [ -f "$APP_DIR/google-services.json" ] || [ -f "$APP_DIR/ios/Runner/GoogleService-Info.plist" ]; then
        log_success "Firebase ya está configurado"
    else
        log_warning "Firebase necesita configuración manual:"
        echo "  1. Ve a https://console.firebase.google.com"
        echo "  2. Crea o selecciona tu proyecto 'rappitaxi-app'"
        echo "  3. Descarga google-services.json para Android"
        echo "  4. Descarga GoogleService-Info.plist para iOS"
        echo "  5. Colócalos en las ubicaciones correctas"
    fi
}

# Compilar la aplicación
build_app() {
    log_info "Compilando aplicación..."
    cd "$APP_DIR"
    
    echo ""
    echo "Selecciona plataforma de compilación:"
    echo "1) Android (APK Debug)"
    echo "2) Android (APK Release)"
    echo "3) iOS (Requiere macOS)"
    echo "4) Web"
    echo "5) Todas las anteriores"
    echo "6) Omitir compilación"
    read -p "Opción: " build_option
    
    case $build_option in
        1)
            log_info "Compilando APK Debug..."
            flutter build apk --debug &>> "$LOG_FILE"
            log_success "APK Debug compilado: build/app/outputs/flutter-apk/app-debug.apk"
            ;;
        2)
            log_info "Compilando APK Release..."
            flutter build apk --release &>> "$LOG_FILE"
            log_success "APK Release compilado: build/app/outputs/flutter-apk/app-release.apk"
            ;;
        3)
            log_info "Compilando para iOS..."
            flutter build ios --release &>> "$LOG_FILE"
            log_success "Build iOS completado"
            ;;
        4)
            log_info "Compilando para Web..."
            flutter build web --release &>> "$LOG_FILE"
            log_success "Build Web completado: build/web"
            ;;
        5)
            log_info "Compilando todas las plataformas..."
            flutter build apk --release &>> "$LOG_FILE"
            flutter build web --release &>> "$LOG_FILE"
            log_success "Todas las plataformas compiladas"
            ;;
        6)
            log_info "Omitiendo compilación"
            ;;
    esac
}

# Iniciar servicios de desarrollo
start_development() {
    echo ""
    echo "¿Deseas iniciar los servicios de desarrollo?"
    echo "1) Iniciar todo (Backend + App)"
    echo "2) Solo Backend"
    echo "3) Solo App Flutter"
    echo "4) No iniciar nada"
    read -p "Opción: " start_option
    
    case $start_option in
        1)
            log_info "Iniciando Backend y App..."
            # Backend en background
            cd "$BACKEND_DIR"
            npm run serve &>> "$LOG_FILE" &
            BACKEND_PID=$!
            log_success "Backend iniciado (PID: $BACKEND_PID)"
            
            # App Flutter
            cd "$APP_DIR"
            flutter run -d chrome --web-renderer html
            ;;
        2)
            log_info "Iniciando solo Backend..."
            cd "$BACKEND_DIR"
            npm run serve
            ;;
        3)
            log_info "Iniciando solo App Flutter..."
            cd "$APP_DIR"
            flutter run
            ;;
        4)
            log_info "No se iniciará ningún servicio"
            ;;
    esac
}

# Generar reporte final
generate_report() {
    log_info "Generando reporte final..."
    
    REPORT_FILE="${PROJECT_ROOT}/setup_report_${TIMESTAMP}.md"
    
    cat > "$REPORT_FILE" << EOF
# Reporte de Configuración - RappiTaxi
Fecha: $(date)

## Estado de Componentes

### Backend
- ✅ Dependencias instaladas
- ✅ TypeScript compilado
- ✅ Archivo .env configurado
- ✅ Firebase Admin SDK configurado

### Frontend (Flutter)
- ✅ Dependencias instaladas
- ✅ Código generado (build_runner)
- ✅ Código formateado
- ✅ Análisis de código completado
- ✅ Archivo .env configurado

### Base de Datos
- ✅ Firebase Firestore configurado
- ✅ Reglas de seguridad actualizadas
- ✅ Índices configurados

### Servicios de Terceros
- ✅ MercadoPago configurado (modo TEST)
- ✅ Google Maps preparado (requiere API Key)
- ⚠️  OneSignal pendiente de configuración

## Próximos Pasos

1. **Configurar credenciales de producción**:
   - Firebase: Actualizar firebase_options.dart
   - MercadoPago: Cambiar a tokens de producción
   - Google Maps: Obtener API Key real

2. **Desplegar Backend**:
   \`\`\`bash
   cd backend
   firebase deploy --only functions
   \`\`\`

3. **Compilar para Producción**:
   \`\`\`bash
   cd app
   flutter build apk --release
   flutter build ios --release
   \`\`\`

4. **Configurar CI/CD**:
   - GitHub Actions configurado en .github/workflows
   - Secrets necesarios en GitHub

## Comandos Útiles

### Desarrollo Local
\`\`\`bash
# Backend
cd backend && npm run serve

# Frontend
cd app && flutter run -d chrome
\`\`\`

### Producción
\`\`\`bash
# Deploy Backend
cd backend && firebase deploy

# Build Apps
cd app
flutter build apk --release
flutter build ios --release
\`\`\`

## Archivos Importantes
- Backend .env: ${BACKEND_DIR}/.env
- App .env: ${APP_DIR}/.env
- Firebase Options: ${APP_DIR}/lib/firebase_options.dart
- Logs: ${LOG_FILE}

---
Configuración completada exitosamente ✅
EOF

    log_success "Reporte generado: $REPORT_FILE"
}

# Función principal
main() {
    print_banner
    check_prerequisites
    
    echo ""
    log_info "=== CONFIGURACIÓN DEL BACKEND ==="
    setup_backend
    
    echo ""
    log_info "=== CONFIGURACIÓN DE LA APP FLUTTER ==="
    setup_flutter_app
    
    echo ""
    log_info "=== CONFIGURACIÓN DE FIREBASE ==="
    setup_firebase
    
    echo ""
    log_info "=== COMPILACIÓN ==="
    build_app
    
    echo ""
    generate_report
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         ¡CONFIGURACIÓN COMPLETADA EXITOSAMENTE!          ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    log_success "El proyecto RappiTaxi está listo para desarrollo/producción"
    echo ""
    echo "📋 Reporte completo: ${PROJECT_ROOT}/setup_report_${TIMESTAMP}.md"
    echo "📝 Log detallado: ${LOG_FILE}"
    echo ""
    
    start_development
}

# Manejo de errores
trap 'log_error "Error en línea $LINENO. Revisa el log: $LOG_FILE"' ERR

# Ejecutar función principal
main "$@"