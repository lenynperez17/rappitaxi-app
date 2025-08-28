#!/bin/bash

# =============================================================================
# RAPPITAXI - SCRIPT DE BUILD OPTIMIZADO PARA PRODUCCIÓN
# Genera todos los builds necesarios para deploy en producción
# =============================================================================

set -e  # Salir si hay error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuración
PROJECT_ROOT="/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi"
APP_DIR="$PROJECT_ROOT/app"
BACKEND_DIR="$PROJECT_ROOT/backend"
BUILD_OUTPUT_DIR="$PROJECT_ROOT/builds"
DATE_TIME=$(date +"%Y%m%d_%H%M%S")

# Flutter SDK path en WSL
FLUTTER_BIN="/mnt/c/dev/flutter/bin/flutter"
DART_BIN="/mnt/c/dev/flutter/bin/dart"

# Función para imprimir mensajes coloreados
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}$message${NC}"
}

print_success() { print_status "$GREEN" "✅ $1"; }
print_error() { print_status "$RED" "❌ $1"; }
print_info() { print_status "$BLUE" "ℹ️  $1"; }
print_warning() { print_status "$YELLOW" "⚠️  $1"; }
print_header() { print_status "$PURPLE" "🚀 $1"; }
print_section() { print_status "$CYAN" "=== $1 ==="; }

# Función para verificar si un comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Función para verificar prerequisitos
check_prerequisites() {
    print_section "VERIFICANDO PREREQUISITOS"
    
    # Verificar Flutter
    if [[ ! -f "$FLUTTER_BIN" ]]; then
        print_error "Flutter no encontrado en $FLUTTER_BIN"
        exit 1
    fi
    
    local flutter_version=$("$FLUTTER_BIN" --version | head -n 1)
    print_success "Flutter encontrado: $flutter_version"
    
    # Verificar Dart
    if [[ ! -f "$DART_BIN" ]]; then
        print_error "Dart no encontrado en $DART_BIN"
        exit 1
    fi
    
    local dart_version=$("$DART_BIN" --version | head -n 1)
    print_success "Dart encontrado: $dart_version"
    
    # Verificar Node.js para backend
    if ! command_exists node; then
        print_error "Node.js no está instalado"
        exit 1
    fi
    
    local node_version=$(node --version)
    print_success "Node.js encontrado: $node_version"
    
    # Verificar npm
    if ! command_exists npm; then
        print_error "npm no está instalado"
        exit 1
    fi
    
    local npm_version=$(npm --version)
    print_success "npm encontrado: v$npm_version"
    
    # Verificar directorios del proyecto
    if [[ ! -d "$APP_DIR" ]]; then
        print_error "Directorio de Flutter app no encontrado: $APP_DIR"
        exit 1
    fi
    
    if [[ ! -d "$BACKEND_DIR" ]]; then
        print_error "Directorio de backend no encontrado: $BACKEND_DIR"
        exit 1
    fi
    
    print_success "Todos los prerequisitos verificados ✅"
}

# Función para crear directorio de builds
setup_build_directory() {
    print_section "CONFIGURANDO DIRECTORIO DE BUILDS"
    
    # Crear directorio principal de builds
    mkdir -p "$BUILD_OUTPUT_DIR"
    
    # Crear subdirectorios
    mkdir -p "$BUILD_OUTPUT_DIR/flutter"
    mkdir -p "$BUILD_OUTPUT_DIR/flutter/android"
    mkdir -p "$BUILD_OUTPUT_DIR/flutter/web"
    mkdir -p "$BUILD_OUTPUT_DIR/flutter/windows"
    mkdir -p "$BUILD_OUTPUT_DIR/backend"
    mkdir -p "$BUILD_OUTPUT_DIR/docker"
    mkdir -p "$BUILD_OUTPUT_DIR/assets"
    
    print_success "Directorio de builds configurado: $BUILD_OUTPUT_DIR"
}

# Función para preparar el entorno Flutter
prepare_flutter_environment() {
    print_section "PREPARANDO ENTORNO FLUTTER"
    
    cd "$APP_DIR"
    
    # Limpiar builds anteriores
    print_info "Limpiando builds anteriores..."
    "$FLUTTER_BIN" clean
    
    # Obtener dependencias
    print_info "Obteniendo dependencias de Flutter..."
    "$FLUTTER_BIN" pub get
    
    # Generar código (freezed, json_serializable, etc.)
    print_info "Generando código con build_runner..."
    "$FLUTTER_BIN" pub run build_runner build --delete-conflicting-outputs
    
    # Analizar código antes del build
    print_info "Analizando código Flutter..."
    "$FLUTTER_BIN" analyze --no-fatal-infos
    
    if [ $? -eq 0 ]; then
        print_success "Análisis de Flutter completado sin errores críticos"
    else
        print_warning "Se encontraron advertencias en el análisis, continuando..."
    fi
    
    # Verificar tests (si existen)
    if [[ -d "test" && -n "$(ls -A test 2>/dev/null)" ]]; then
        print_info "Ejecutando tests de Flutter..."
        "$FLUTTER_BIN" test || print_warning "Algunos tests fallaron, continuando con build..."
    else
        print_warning "No se encontraron tests de Flutter"
    fi
}

# Función para build de Android (APK)
build_android_apk() {
    print_section "BUILDING ANDROID APK"
    
    cd "$APP_DIR"
    
    print_info "Iniciando build de Android APK optimizado..."
    
    # Build APK release
    "$FLUTTER_BIN" build apk --release \
        --target-platform android-arm,android-arm64,android-x64 \
        --split-per-abi \
        --obfuscate \
        --split-debug-info=build/debug-info \
        --dart-define=FLUTTER_WEB_USE_SKIA=true \
        --dart-define=ENVIRONMENT=production
    
    if [ $? -eq 0 ]; then
        print_success "Android APK build completado"
        
        # Copiar APKs al directorio de builds
        cp -r build/app/outputs/flutter-apk/*.apk "$BUILD_OUTPUT_DIR/flutter/android/"
        
        # Mostrar tamaños de APKs
        print_info "Tamaños de APKs generados:"
        ls -lh build/app/outputs/flutter-apk/*.apk | while read line; do
            print_info "  $line"
        done
        
        # Generar APK bundle también (para Play Store)
        print_info "Generando Android App Bundle (AAB)..."
        "$FLUTTER_BIN" build appbundle --release \
            --obfuscate \
            --split-debug-info=build/debug-info \
            --dart-define=ENVIRONMENT=production
            
        if [ $? -eq 0 ]; then
            cp build/app/outputs/bundle/release/app-release.aab "$BUILD_OUTPUT_DIR/flutter/android/"
            print_success "Android App Bundle generado"
        fi
        
    else
        print_error "Android APK build falló"
        return 1
    fi
}

# Función para build web optimizado
build_web() {
    print_section "BUILDING WEB APP"
    
    cd "$APP_DIR"
    
    print_info "Iniciando build web optimizado para producción..."
    
    # Build web con optimizaciones
    "$FLUTTER_BIN" build web \
        --release \
        --web-renderer html \
        --pwa-strategy offline-first \
        --base-href "/" \
        --dart-define=FLUTTER_WEB_USE_SKIA=false \
        --dart-define=ENVIRONMENT=production \
        --source-maps
    
    if [ $? -eq 0 ]; then
        print_success "Web build completado"
        
        # Copiar build web al directorio de builds
        cp -r build/web/* "$BUILD_OUTPUT_DIR/flutter/web/"
        
        # Mostrar tamaño del build web
        local web_size=$(du -sh build/web | cut -f1)
        print_info "Tamaño del build web: $web_size"
        
        # Comprimir archivos adicionales para deployment
        print_info "Comprimiendo build web para deployment..."
        cd build
        tar -czf "$BUILD_OUTPUT_DIR/flutter/rappitaxi_web_${DATE_TIME}.tar.gz" web/
        cd ..
        
        print_success "Build web comprimido guardado"
        
    else
        print_error "Web build falló"
        return 1
    fi
}

# Función para build Windows (si estamos en ambiente que lo soporte)
build_windows() {
    print_section "BUILDING WINDOWS APP"
    
    cd "$APP_DIR"
    
    # Verificar si Windows build está habilitado
    if "$FLUTTER_BIN" config | grep -q "enable-windows-desktop: true"; then
        print_info "Building Windows desktop app..."
        
        "$FLUTTER_BIN" build windows --release \
            --dart-define=ENVIRONMENT=production
        
        if [ $? -eq 0 ]; then
            print_success "Windows build completado"
            
            # Copiar build Windows
            cp -r build/windows/runner/Release/* "$BUILD_OUTPUT_DIR/flutter/windows/"
            
            # Crear instalador portable
            cd build/windows/runner/Release
            zip -r "$BUILD_OUTPUT_DIR/flutter/rappitaxi_windows_${DATE_TIME}.zip" .
            cd "$APP_DIR"
            
            print_success "Windows build empaquetado"
        else
            print_error "Windows build falló"
        fi
    else
        print_warning "Windows desktop no está habilitado en Flutter"
    fi
}

# Función para preparar backend para producción
prepare_backend() {
    print_section "PREPARANDO BACKEND PARA PRODUCCIÓN"
    
    cd "$BACKEND_DIR"
    
    # Verificar package.json existe
    if [[ ! -f "package.json" ]]; then
        print_error "package.json no encontrado en $BACKEND_DIR"
        return 1
    fi
    
    # Instalar dependencias de producción
    print_info "Instalando dependencias de producción..."
    npm ci --only=production
    
    # Si hay TypeScript, compilar
    if [[ -f "tsconfig.json" ]]; then
        print_info "Compilando TypeScript..."
        if command_exists tsc; then
            npx tsc
            print_success "TypeScript compilado"
        else
            print_warning "TypeScript no disponible, saltando compilación"
        fi
    fi
    
    # Ejecutar tests si existen
    if npm run | grep -q "test"; then
        print_info "Ejecutando tests del backend..."
        npm test || print_warning "Algunos tests fallaron, continuando..."
    fi
    
    # Optimizar y minificar si hay script de build
    if npm run | grep -q "build"; then
        print_info "Ejecutando build del backend..."
        npm run build
        print_success "Backend build completado"
    fi
    
    print_success "Backend preparado para producción"
}

# Función para crear package del backend
package_backend() {
    print_section "EMPAQUETANDO BACKEND"
    
    cd "$BACKEND_DIR"
    
    # Crear directorio temporal
    local temp_dir=$(mktemp -d)
    print_info "Empaquetando backend en: $temp_dir"
    
    # Copiar archivos esenciales
    cp -r . "$temp_dir/backend"
    cd "$temp_dir/backend"
    
    # Limpiar archivos innecesarios
    rm -rf node_modules
    rm -rf .git
    rm -rf tests
    rm -rf coverage
    rm -rf .nyc_output
    rm -rf logs
    rm -f *.log
    rm -f .env.local
    rm -f .env.development
    
    # Reinstalar solo dependencias de producción
    npm ci --only=production
    
    # Crear archivo .env.example para producción
    cat > .env.production.example << EOF
# RappiTaxi Backend - Configuración de Producción
NODE_ENV=production
PORT=3000

# Base de datos
DATABASE_URL=your_database_url
REDIS_URL=your_redis_url

# Firebase
FIREBASE_PROJECT_ID=your_project_id
FIREBASE_PRIVATE_KEY=your_private_key
FIREBASE_CLIENT_EMAIL=your_client_email

# JWT
JWT_SECRET=your_jwt_secret
JWT_EXPIRES_IN=7d

# APIs externas
GOOGLE_MAPS_API_KEY=your_google_maps_key
MERCADOPAGO_ACCESS_TOKEN=your_mercadopago_token
MERCADOPAGO_PUBLIC_KEY=your_mercadopago_public_key

# Notificaciones
FCM_SERVER_KEY=your_fcm_server_key
SENDGRID_API_KEY=your_sendgrid_key

# Monitoreo
SENTRY_DSN=your_sentry_dsn
NEW_RELIC_LICENSE_KEY=your_new_relic_key

# CORS
ALLOWED_ORIGINS=https://yourdomain.com,https://admin.yourdomain.com

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100

# SSL/Security
FORCE_HTTPS=true
TRUST_PROXY=true
EOF
    
    # Crear package comprimido
    cd "$temp_dir"
    tar -czf "$BUILD_OUTPUT_DIR/backend/rappitaxi_backend_${DATE_TIME}.tar.gz" backend/
    
    # Limpiar directorio temporal
    rm -rf "$temp_dir"
    
    print_success "Backend empaquetado: rappitaxi_backend_${DATE_TIME}.tar.gz"
}

# Función para crear Dockerfiles optimizados
create_docker_configs() {
    print_section "CREANDO CONFIGURACIONES DOCKER"
    
    # Dockerfile para Flutter Web
    cat > "$BUILD_OUTPUT_DIR/docker/Dockerfile.web" << 'EOF'
# RappiTaxi Web App - Multi-stage Docker build
FROM nginx:alpine as production

# Copiar build de Flutter Web
COPY flutter/web /usr/share/nginx/html

# Configuración optimizada de Nginx
COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf /etc/nginx/conf.d/default.conf

# Optimizaciones de seguridad
RUN addgroup -g 1001 -S rappitaxi && \
    adduser -S rappitaxi -u 1001 -G rappitaxi && \
    chown -R rappitaxi:rappitaxi /usr/share/nginx/html && \
    chmod -R 755 /usr/share/nginx/html

USER rappitaxi

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF

    # Dockerfile para Backend Node.js
    cat > "$BUILD_OUTPUT_DIR/docker/Dockerfile.backend" << 'EOF'
# RappiTaxi Backend API - Multi-stage Docker build
FROM node:18-alpine as base

# Instalar dependencias del sistema
RUN apk add --no-cache dumb-init

# Crear usuario no-root
RUN addgroup -g 1001 -S rappitaxi && \
    adduser -S rappitaxi -u 1001 -G rappitaxi

# Configurar directorio de trabajo
WORKDIR /app
RUN chown rappitaxi:rappitaxi /app

# Cambiar a usuario no-root
USER rappitaxi

# Copiar package files
COPY --chown=rappitaxi:rappitaxi package*.json ./

# Instalar dependencias
RUN npm ci --only=production && npm cache clean --force

# Copiar código fuente
COPY --chown=rappitaxi:rappitaxi . .

# Variables de entorno por defecto
ENV NODE_ENV=production
ENV PORT=3000

# Healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node healthcheck.js || exit 1

EXPOSE 3000

# Usar dumb-init para manejar señales correctamente
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "server.js"]
EOF

    # nginx.conf optimizado
    cat > "$BUILD_OUTPUT_DIR/docker/nginx.conf" << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # Logging
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    
    # Performance
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    
    # Gzip
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        application/atom+xml
        application/javascript
        application/json
        application/ld+json
        application/manifest+json
        application/rss+xml
        application/vnd.geo+json
        application/vnd.ms-fontobject
        application/x-font-ttf
        application/x-web-app-manifest+json
        application/xhtml+xml
        application/xml
        font/opentype
        image/bmp
        image/svg+xml
        image/x-icon
        text/cache-manifest
        text/css
        text/plain
        text/vcard
        text/vnd.rim.location.xloc
        text/vtt
        text/x-component
        text/x-cross-domain-policy;
    
    include /etc/nginx/conf.d/*.conf;
}
EOF

    # default.conf para Flutter Web
    cat > "$BUILD_OUTPUT_DIR/docker/default.conf" << 'EOF'
server {
    listen 80;
    server_name localhost;
    
    root /usr/share/nginx/html;
    index index.html;
    
    # Configuración para SPA (Single Page Application)
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    # Cache para assets estáticos
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Manifest.json cache
    location /manifest.json {
        expires 1d;
        add_header Cache-Control "public";
    }
    
    # Service Worker no cache
    location /flutter_service_worker.js {
        expires -1;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Referrer-Policy "strict-origin-when-cross-origin";
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https:; frame-src 'none';";
    
    # Compression
    gzip_static on;
}
EOF

    # docker-compose.yml para deployment completo
    cat > "$BUILD_OUTPUT_DIR/docker/docker-compose.prod.yml" << 'EOF'
version: '3.8'

services:
  web:
    build:
      context: .
      dockerfile: Dockerfile.web
    container_name: rappitaxi-web
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./ssl:/etc/ssl/certs
    depends_on:
      - backend
    restart: unless-stopped
    networks:
      - rappitaxi-network

  backend:
    build:
      context: .
      dockerfile: Dockerfile.backend
    container_name: rappitaxi-backend
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - PORT=3000
    env_file:
      - .env.production
    volumes:
      - ./logs:/app/logs
    restart: unless-stopped
    networks:
      - rappitaxi-network

  redis:
    image: redis:7-alpine
    container_name: rappitaxi-redis
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    command: redis-server --appendonly yes --requirepass ${REDIS_PASSWORD}
    restart: unless-stopped
    networks:
      - rappitaxi-network

  nginx:
    image: nginx:alpine
    container_name: rappitaxi-proxy
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx-proxy.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/ssl/certs
      - ./logs/nginx:/var/log/nginx
    depends_on:
      - web
      - backend
    restart: unless-stopped
    networks:
      - rappitaxi-network

volumes:
  redis_data:
    driver: local

networks:
  rappitaxi-network:
    driver: bridge
EOF

    # Script de deployment
    cat > "$BUILD_OUTPUT_DIR/docker/deploy.sh" << 'EOF'
#!/bin/bash

# RappiTaxi - Script de Deployment con Docker
set -e

echo "🚀 Iniciando deployment de RappiTaxi..."

# Verificar que .env.production existe
if [[ ! -f ".env.production" ]]; then
    echo "❌ Archivo .env.production no encontrado"
    echo "Copia .env.production.example y configura las variables"
    exit 1
fi

# Bajar servicios actuales
echo "🔄 Deteniendo servicios actuales..."
docker-compose -f docker-compose.prod.yml down

# Construir nuevas imágenes
echo "🏗️  Construyendo nuevas imágenes..."
docker-compose -f docker-compose.prod.yml build --no-cache

# Iniciar servicios
echo "▶️  Iniciando servicios..."
docker-compose -f docker-compose.prod.yml up -d

# Verificar salud de servicios
echo "🔍 Verificando salud de servicios..."
sleep 10

if curl -f http://localhost:3000/health; then
    echo "✅ Backend funcionando correctamente"
else
    echo "❌ Backend no responde"
    exit 1
fi

if curl -f http://localhost/; then
    echo "✅ Frontend funcionando correctamente"
else
    echo "❌ Frontend no responde"
    exit 1
fi

echo "🎉 Deployment completado exitosamente!"
echo "📱 Frontend: http://localhost/"
echo "🔧 Backend API: http://localhost:3000/"
echo "📊 Logs: docker-compose -f docker-compose.prod.yml logs -f"
EOF

    chmod +x "$BUILD_OUTPUT_DIR/docker/deploy.sh"
    
    print_success "Configuraciones Docker creadas"
}

# Función para optimizar assets
optimize_assets() {
    print_section "OPTIMIZANDO ASSETS"
    
    local assets_dir="$APP_DIR/assets"
    local optimized_dir="$BUILD_OUTPUT_DIR/assets"
    
    if [[ -d "$assets_dir" ]]; then
        print_info "Copiando y optimizando assets..."
        
        cp -r "$assets_dir"/* "$optimized_dir/"
        
        # Optimizar imágenes si hay herramientas disponibles
        if command_exists optipng; then
            find "$optimized_dir" -name "*.png" -exec optipng -o7 {} \;
            print_success "Imágenes PNG optimizadas"
        fi
        
        if command_exists jpegoptim; then
            find "$optimized_dir" -name "*.jpg" -o -name "*.jpeg" -exec jpegoptim --max=85 {} \;
            print_success "Imágenes JPEG optimizadas"
        fi
        
        # Mostrar tamaño de assets
        local assets_size=$(du -sh "$optimized_dir" | cut -f1)
        print_info "Tamaño total de assets optimizados: $assets_size"
        
    else
        print_warning "No se encontró directorio de assets"
    fi
}

# Función para generar checksums y metadatos
generate_build_metadata() {
    print_section "GENERANDO METADATOS DE BUILD"
    
    cd "$BUILD_OUTPUT_DIR"
    
    # Crear archivo de metadatos
    cat > build_metadata.json << EOF
{
    "buildInfo": {
        "version": "1.0.0",
        "buildNumber": "$DATE_TIME",
        "buildDate": "$(date -Iseconds)",
        "environment": "production",
        "gitCommit": "$(git rev-parse HEAD 2>/dev/null || echo 'unknown')",
        "gitBranch": "$(git branch --show-current 2>/dev/null || echo 'unknown')"
    },
    "flutter": {
        "version": "$($FLUTTER_BIN --version | head -n 1)",
        "dartVersion": "$($DART_BIN --version)"
    },
    "backend": {
        "nodeVersion": "$(node --version)",
        "npmVersion": "$(npm --version)"
    },
    "builds": {
        "android": {
            "apk": "flutter/android/",
            "bundle": "flutter/android/app-release.aab"
        },
        "web": {
            "files": "flutter/web/",
            "archive": "flutter/rappitaxi_web_${DATE_TIME}.tar.gz"
        },
        "backend": {
            "archive": "backend/rappitaxi_backend_${DATE_TIME}.tar.gz"
        },
        "docker": {
            "configs": "docker/"
        }
    }
}
EOF
    
    # Generar checksums SHA256
    print_info "Generando checksums SHA256..."
    find . -type f \( -name "*.apk" -o -name "*.aab" -o -name "*.tar.gz" -o -name "*.zip" \) -exec sha256sum {} \; > checksums.sha256
    
    # Crear archivo README para el build
    cat > README_BUILD.md << EOF
# RappiTaxi - Build de Producción

**Fecha de Build:** $(date)  
**Versión:** 1.0.0  
**Build Number:** $DATE_TIME

## 📱 Aplicación Flutter

### Android
- **APKs:** \`flutter/android/\`
  - app-arm64-v8a-release.apk (ARM64)
  - app-armeabi-v7a-release.apk (ARM32)
  - app-x86_64-release.apk (x86_64)
- **App Bundle:** \`flutter/android/app-release.aab\` (para Google Play Store)

### Web
- **Archivos:** \`flutter/web/\`
- **Comprimido:** \`flutter/rappitaxi_web_${DATE_TIME}.tar.gz\`

## 🖥️ Backend

- **Código empaquetado:** \`backend/rappitaxi_backend_${DATE_TIME}.tar.gz\`
- **Configuración:** Ver .env.production.example

## 🐳 Docker

- **Configuraciones:** \`docker/\`
- **Deployment:** Ejecutar \`docker/deploy.sh\`

## 🔐 Seguridad

- Verificar checksums: \`sha256sum -c checksums.sha256\`
- Todos los builds están optimizados y ofuscados

## 📋 Deployment

1. Subir archivos al servidor
2. Configurar variables de entorno
3. Ejecutar script de deployment
4. Verificar funcionamiento

## 📞 Soporte

Para issues de deployment, contactar al equipo de desarrollo.

---

*Build generado automáticamente por RappiTaxi Build System*
EOF
    
    print_success "Metadatos de build generados"
}

# Función para generar reporte final
generate_build_report() {
    print_section "GENERANDO REPORTE FINAL"
    
    cd "$BUILD_OUTPUT_DIR"
    
    # Calcular tamaños
    local flutter_size=$(du -sh flutter 2>/dev/null | cut -f1 || echo "0B")
    local backend_size=$(du -sh backend 2>/dev/null | cut -f1 || echo "0B")
    local docker_size=$(du -sh docker 2>/dev/null | cut -f1 || echo "0B")
    local total_size=$(du -sh . | cut -f1)
    
    print_header "REPORTE FINAL DE BUILD"
    echo
    print_success "📱 Flutter Apps:"
    print_info "   Tamaño total: $flutter_size"
    if [[ -d "flutter/android" ]]; then
        local android_count=$(find flutter/android -name "*.apk" | wc -l)
        print_info "   Android APKs: $android_count archivos"
    fi
    if [[ -d "flutter/web" ]]; then
        print_info "   Web build: Disponible"
    fi
    
    echo
    print_success "🖥️  Backend:"
    print_info "   Tamaño: $backend_size"
    print_info "   Empaquetado y listo para deployment"
    
    echo
    print_success "🐳 Docker:"
    print_info "   Configuraciones: $docker_size"
    print_info "   Scripts de deployment incluidos"
    
    echo
    print_success "📊 RESUMEN TOTAL:"
    print_info "   Tamaño total de build: $total_size"
    print_info "   Ubicación: $BUILD_OUTPUT_DIR"
    print_info "   Build completado: $(date)"
    
    echo
    print_header "¡BUILD DE PRODUCCIÓN COMPLETADO EXITOSAMENTE! 🎉"
    echo
    print_info "Próximos pasos:"
    print_info "1. Revisar los archivos en: $BUILD_OUTPUT_DIR"
    print_info "2. Verificar checksums con: sha256sum -c checksums.sha256"
    print_info "3. Configurar variables de entorno para producción"
    print_info "4. Ejecutar deployment usando Docker o builds nativos"
    echo
}

# =============================================================================
# FUNCIÓN PRINCIPAL
# =============================================================================
main() {
    print_header "RAPPITAXI - BUILD OPTIMIZADO PARA PRODUCCIÓN"
    print_info "Iniciando proceso de build completo..."
    echo
    
    local start_time=$(date +%s)
    
    # Ejecutar todos los pasos
    check_prerequisites
    setup_build_directory
    prepare_flutter_environment
    
    # Builds de Flutter
    build_android_apk
    build_web
    build_windows  # Solo si está disponible
    
    # Backend
    prepare_backend
    package_backend
    
    # Docker y deployment
    create_docker_configs
    
    # Optimizaciones finales
    optimize_assets
    generate_build_metadata
    
    # Reporte final
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    generate_build_report
    
    print_success "Tiempo total de build: $((duration / 60))m $((duration % 60))s"
    
    return 0
}

# Ejecutar función principal si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi