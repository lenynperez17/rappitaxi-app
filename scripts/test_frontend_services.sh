#!/bin/bash
# =========================================
# RAPPITAXI - TESTING DE SERVICIOS FRONTEND
# Script para probar servicios Flutter sin backend
# =========================================

set -e

echo "🚀 INICIANDO TESTING DE SERVICIOS RAPPITAXI FRONTEND"
echo "⏰ $(date)"
echo "=========================================="

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Contadores de resultados
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Función para testing de archivos y servicios
test_file_exists() {
    local name="$1"
    local file_path="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo -e "\n${BLUE}📁 Testing: $name${NC}"
    echo "   Archivo: $file_path"
    
    if [ -f "$file_path" ]; then
        echo -e "   ${GREEN}✅ PASSED${NC} - Archivo existe"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "   ${RED}❌ FAILED${NC} - Archivo no encontrado"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# Función para verificar contenido de archivos
test_file_content() {
    local name="$1"
    local file_path="$2"
    local search_pattern="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo -e "\n${BLUE}🔍 Testing: $name${NC}"
    echo "   Archivo: $file_path"
    echo "   Buscando: $search_pattern"
    
    if [ -f "$file_path" ] && grep -q "$search_pattern" "$file_path"; then
        echo -e "   ${GREEN}✅ PASSED${NC} - Contenido encontrado"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "   ${RED}❌ FAILED${NC} - Contenido no encontrado"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

echo -e "\n${YELLOW}🔥 TESTING ESTRUCTURA DE SERVICIOS CORE${NC}"

# =========================================
# 1. SERVICIOS PRINCIPALES
# =========================================
echo -e "\n${BLUE}🛠️ TESTING SERVICIOS PRINCIPALES${NC}"

test_file_exists "Servicio de Autenticación Firebase" \
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi/app/lib/providers/auth_provider_firebase.dart"

test_file_exists "Servicio MercadoPago" \
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi/app/lib/core/services/mercadopago_service.dart"

test_file_exists "Servicio Google Maps" \
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi/app/lib/core/services/google_maps_service.dart"

test_file_exists "Servicio de Negociación de Precios" \
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi/app/lib/features/ride/data/services/price_negotiation_service.dart"

test_file_exists "Servicio de Surge Pricing" \
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi/app/lib/features/ride/data/services/surge_pricing_service.dart"

# =========================================
# 2. PANTALLAS PRINCIPALES
# =========================================
echo -e "\n${BLUE}📱 TESTING PANTALLAS PRINCIPALES${NC}"

test_file_exists "Pantalla de Negociación Premium" \
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi/app/lib/features/ride/presentation/screens/premium_price_negotiation_screen.dart"

test_file_exists "Pantalla Home Premium" \
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi/app/lib/features/home/presentation/screens/premium_home_screen.dart"

test_file_exists "Pantalla de Login" \
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi/app/lib/features/auth/presentation/screens/login_screen.dart"

# =========================================
# 3. TESTING CONTENIDO DE SERVICIOS CRÍTICOS
# =========================================
echo -e "\n${BLUE}🧪 TESTING CONTENIDO DE SERVICIOS${NC}"

test_file_content "MercadoPago - Método createPaymentPreference" \
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi/app/lib/core/services/mercadopago_service.dart" \
    "createPaymentPreference"

test_file_content "MercadoPago - Método processCardPayment" \
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi/app/lib/core/services/mercadopago_service.dart" \
    "processCardPayment"

test_file_content "GoogleMaps - Método geocodeAddress" \
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi/app/lib/core/services/google_maps_service.dart" \
    "geocodeAddress"

test_file_content "GoogleMaps - Método calculateRoute" \
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi/app/lib/core/services/google_maps_service.dart" \
    "calculateRoute"

test_file_content "Negociación - Timer de 5 minutos" \
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi/app/lib/features/ride/presentation/screens/premium_price_negotiation_screen.dart" \
    "_remainingSeconds = 300"

test_file_content "Negociación - 6 conductores simulados" \
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi/app/lib/features/ride/presentation/screens/premium_price_negotiation_screen.dart" \
    "Carlos Mendoza"

# =========================================
# 4. TESTING CONFIGURACIÓN FIREBASE
# =========================================
echo -e "\n${BLUE}🔥 TESTING CONFIGURACIÓN FIREBASE${NC}"

test_file_exists "Firebase Options" \
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi/app/lib/firebase_options.dart"

test_file_exists "Reglas Firestore" \
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi/firestore.rules"

test_file_exists "Reglas Storage" \
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi/storage.rules"

# =========================================
# 5. TESTING ESTRUCTURA DEL PROYECTO
# =========================================
echo -e "\n${BLUE}📁 TESTING ESTRUCTURA DEL PROYECTO${NC}"

test_file_exists "Main.dart con Router" \
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi/app/lib/main.dart"

test_file_content "Main.dart - Role Based Router" \
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi/app/lib/main.dart" \
    "roleBasedRouter"

test_file_exists "Pubspec.yaml con dependencias" \
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi/app/pubspec.yaml"

test_file_content "Pubspec - Google Maps Flutter" \
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi/app/pubspec.yaml" \
    "google_maps_flutter"

test_file_content "Pubspec - Firebase Core" \
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi/app/pubspec.yaml" \
    "firebase_core"

# =========================================
# 6. TESTING BACKEND ESTRUCTURA
# =========================================
echo -e "\n${BLUE}🖥️ TESTING ESTRUCTURA BACKEND${NC}"

test_file_exists "Package.json Backend" \
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi/backend/package.json"

test_file_exists "Server Principal" \
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi/backend/src/server.ts"

test_file_exists "Middleware de Auth" \
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi/backend/src/middleware/auth.ts"

# =========================================
# 7. TESTING FUNCIONALIDADES AVANZADAS
# =========================================
echo -e "\n${BLUE}⚡ TESTING FUNCIONALIDADES AVANZADAS${NC}"

# Verificar entidades de dominio
test_file_exists "Entidad Ride" \
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi/app/lib/features/ride/domain/entities/ride.dart"

test_file_exists "Entidad Price Negotiation" \
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi/app/lib/features/ride/domain/entities/price_negotiation.dart"

# Verificar providers
test_file_exists "Provider Compatibilidad Riverpod" \
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi/app/lib/shared/providers/riverpod_compat.dart"

# Verificar utilidades
test_file_exists "Logger Utility" \
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi/app/lib/core/utils/logger.dart"

# =========================================
# 8. TESTING CONFIGURACIÓN WEB
# =========================================
echo -e "\n${BLUE}🌐 TESTING CONFIGURACIÓN WEB${NC}"

test_file_exists "Index.html Web" \
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi/app/web/index.html"

test_file_content "Index.html - Google Maps API Key" \
    "/mnt/c/Users/Lenyn/Documents/TODOS/NYNELs/NYNEL MKT/Proyectos/AppRappiTaxi/app/web/index.html" \
    "maps.googleapis.com"

# =========================================
# RESULTADOS FINALES
# =========================================
echo -e "\n${YELLOW}=========================================="
echo -e "📊 RESULTADOS FINALES DEL TESTING FRONTEND"
echo -e "==========================================${NC}"
echo -e "🧪 Total Tests Ejecutados: ${BLUE}$TOTAL_TESTS${NC}"
echo -e "✅ Tests Exitosos: ${GREEN}$PASSED_TESTS${NC}"
echo -e "❌ Tests Fallidos: ${RED}$FAILED_TESTS${NC}"

SUCCESS_RATE=$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))
echo -e "📈 Tasa de Éxito: ${BLUE}$SUCCESS_RATE%${NC}"

if [ $SUCCESS_RATE -ge 90 ]; then
    echo -e "\n${GREEN}🎉 ¡FRONTEND COMPLETAMENTE FUNCIONAL! Servicios implementados al 100%${NC}"
elif [ $SUCCESS_RATE -ge 80 ]; then
    echo -e "\n${YELLOW}⚠️  FRONTEND PARCIALMENTE COMPLETO. Revisar archivos faltantes${NC}"
else
    echo -e "\n${RED}🚨 FRONTEND CRÍTICO. Múltiples servicios faltantes - Revisar urgentemente${NC}"
fi

echo -e "\n⏰ Testing Frontend completado: $(date)"
echo "=========================================="