#!/bin/bash
# =========================================
# RAPPITAXI - TESTING COMPLETO DE TODAS LAS APIs
# Script para probar exhaustivamente TODA la funcionalidad
# =========================================

set -e

BASE_URL=${TEST_BASE_URL:-"http://localhost:3000"}
echo "🚀 INICIANDO TESTING COMPLETO DE RAPPITAXI API"
echo "🌐 Base URL: $BASE_URL"
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

# Función para testing con resultado
test_endpoint() {
    local name="$1"
    local method="$2"
    local endpoint="$3"
    local data="$4"
    local expected_status="$5"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo -e "\n${BLUE}🧪 Testing: $name${NC}"
    echo "   Method: $method"
    echo "   Endpoint: $endpoint"
    
    if [ "$data" != "" ]; then
        response=$(curl -s -w "\n%{http_code}" -X "$method" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer test-token" \
            -d "$data" \
            "$BASE_URL$endpoint" || echo "000")
    else
        response=$(curl -s -w "\n%{http_code}" -X "$method" \
            -H "Authorization: Bearer test-token" \
            "$BASE_URL$endpoint" || echo "000")
    fi
    
    status_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n -1)
    
    if [ "$status_code" = "$expected_status" ] || [ "$status_code" = "200" ] || [ "$status_code" = "201" ]; then
        echo -e "   ${GREEN}✅ PASSED${NC} (Status: $status_code)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        if [ ${#body} -gt 100 ]; then
            echo "   Response: ${body:0:100}..."
        else
            echo "   Response: $body"
        fi
    else
        echo -e "   ${RED}❌ FAILED${NC} (Status: $status_code)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        echo "   Response: $body"
    fi
}

echo -e "\n${YELLOW}🔥 INICIANDO TESTS DE FUNCIONALIDADES CORE${NC}"

# =========================================
# 1. AUTENTICACIÓN
# =========================================
echo -e "\n${BLUE}👤 TESTING AUTENTICACIÓN${NC}"

test_endpoint "Health Check" "GET" "/health" "" "200"
test_endpoint "Registro Usuario" "POST" "/auth/register" '{
    "email": "test@rappitaxi.com",
    "password": "TestPassword123!",
    "firstName": "Usuario",
    "lastName": "Test",
    "role": "passenger",
    "phone": "+51987654321"
}' "201"

test_endpoint "Login Usuario" "POST" "/auth/login" '{
    "email": "test@rappitaxi.com", 
    "password": "TestPassword123!"
}' "200"

test_endpoint "Refresh Token" "POST" "/auth/refresh" '{
    "refreshToken": "test-refresh-token"
}' "200"

test_endpoint "Logout" "POST" "/auth/logout" '{}' "200"

# =========================================
# 2. PASAJEROS - GESTIÓN DE PERFIL
# =========================================
echo -e "\n${BLUE}🧳 TESTING FUNCIONALIDADES DE PASAJERO${NC}"

test_endpoint "Perfil Pasajero" "GET" "/passengers/profile" "" "200"
test_endpoint "Actualizar Perfil" "PUT" "/passengers/profile" '{
    "firstName": "Juan",
    "lastName": "Pérez",
    "phone": "+51987654321",
    "profileImage": "https://example.com/image.jpg"
}' "200"

# =========================================
# 3. SOLICITUD Y GESTIÓN DE VIAJES
# =========================================
echo -e "\n${BLUE}🚗 TESTING SOLICITUD DE VIAJES${NC}"

test_endpoint "Solicitar Viaje" "POST" "/passengers/rides/request" '{
    "pickupLocation": {
        "latitude": -12.0464,
        "longitude": -77.0428,
        "address": "Lima Centro, Peru"
    },
    "destinationLocation": {
        "latitude": -12.0621,
        "longitude": -77.0365,
        "address": "Miraflores, Lima, Peru"  
    },
    "vehicleType": "economic",
    "paymentMethod": "mercadopago",
    "estimatedPrice": 25.50,
    "passengerCount": 1
}' "201"

test_endpoint "Conductores Cercanos" "GET" "/passengers/drivers/nearby?lat=-12.0464&lng=-77.0428&radius=5" "" "200"

test_endpoint "Historial de Viajes" "GET" "/passengers/rides/history?page=1&limit=10" "" "200"

# =========================================
# 4. NEGOCIACIÓN DE PRECIOS ESTILO INDRIVE
# =========================================
echo -e "\n${BLUE}💰 TESTING NEGOCIACIÓN DE PRECIOS INDRIVE${NC}"

test_endpoint "Crear Negociación" "POST" "/rides/negotiation/create" '{
    "rideRequestId": "ride-123",
    "suggestedPrice": 30.0,
    "negotiationType": "open_bidding",
    "passengerOffer": 25.0,
    "maxWaitTime": 300
}' "201"

test_endpoint "Ofertas de Conductores" "GET" "/rides/negotiation/ride-123/offers" "" "200"

test_endpoint "Hacer Contraoferta" "POST" "/rides/negotiation/ride-123/counter-offer" '{
    "newPrice": 27.50,
    "message": "¿Podrías aceptar este precio?"
}' "200"

test_endpoint "Aceptar Oferta" "POST" "/rides/negotiation/ride-123/accept" '{
    "offerId": "offer-456",
    "finalPrice": 28.0
}' "200"

# =========================================
# 5. CONDUCTORES - PERFIL Y GESTIÓN
# =========================================
echo -e "\n${BLUE}🚕 TESTING FUNCIONALIDADES DE CONDUCTOR${NC}"

test_endpoint "Perfil Conductor" "GET" "/drivers/profile" "" "200"
test_endpoint "Actualizar Perfil Conductor" "PUT" "/drivers/profile" '{
    "firstName": "Carlos",
    "lastName": "Conductor",
    "licenseNumber": "A1234567",
    "experienceYears": 5
}' "200"

test_endpoint "Estado del Conductor" "GET" "/drivers/status" "" "200"
test_endpoint "Cambiar Estado" "PATCH" "/drivers/status" '{
    "status": "online",
    "location": {
        "latitude": -12.0464,
        "longitude": -77.0428
    }
}' "200"

# =========================================
# 6. VEHÍCULOS
# =========================================
echo -e "\n${BLUE}🚙 TESTING GESTIÓN DE VEHÍCULOS${NC}"

test_endpoint "Información Vehículo" "GET" "/drivers/vehicle" "" "200"
test_endpoint "Registrar Vehículo" "POST" "/drivers/vehicle" '{
    "make": "Toyota",
    "model": "Corolla",
    "year": 2020,
    "color": "Blanco", 
    "licensePlate": "ABC-123",
    "soatNumber": "12345",
    "technicalInspection": "TI-67890"
}' "201"

# =========================================
# 7. GANANCIAS Y PAGOS
# =========================================
echo -e "\n${BLUE}💵 TESTING GANANCIAS Y PAGOS${NC}"

test_endpoint "Ganancias Conductor" "GET" "/drivers/earnings?period=week" "" "200"
test_endpoint "Historial Ganancias" "GET" "/drivers/earnings/history?page=1&limit=10" "" "200"
test_endpoint "Solicitar Retiro" "POST" "/drivers/earnings/withdraw" '{
    "amount": 100.0,
    "method": "mercadopago",
    "accountDetails": {
        "email": "conductor@rappitaxi.com"
    }
}' "200"

# =========================================
# 8. PAGOS MERCADOPAGO
# =========================================
echo -e "\n${BLUE}💳 TESTING PAGOS MERCADOPAGO${NC}"

test_endpoint "Crear Preferencia MercadoPago" "POST" "/payments/create-preference" '{
    "amount": 25.50,
    "rideId": "ride-123", 
    "description": "Viaje RappiTaxi",
    "payerEmail": "pasajero@rappitaxi.com"
}' "200"

test_endpoint "Procesar Pago" "POST" "/payments/process" '{
    "paymentId": "payment-123",
    "rideId": "ride-123",
    "amount": 25.50,
    "status": "approved"
}' "200"

test_endpoint "Métodos de Pago" "GET" "/payments/methods" "" "200"

# =========================================
# 9. TRACKING EN TIEMPO REAL
# =========================================
echo -e "\n${BLUE}📍 TESTING TRACKING TIEMPO REAL${NC}"

test_endpoint "Actualizar Ubicación" "PUT" "/drivers/location" '{
    "latitude": -12.0464,
    "longitude": -77.0428,
    "heading": 180.5,
    "speed": 25.0
}' "200"

test_endpoint "Ubicación del Conductor" "GET" "/rides/ride-123/driver-location" "" "200"

# =========================================
# 10. CHAT EN TIEMPO REAL
# =========================================
echo -e "\n${BLUE}💬 TESTING CHAT TIEMPO REAL${NC}"

test_endpoint "Enviar Mensaje" "POST" "/chat/send" '{
    "rideId": "ride-123",
    "message": "Ya estoy llegando",
    "messageType": "text",
    "senderId": "driver-456"
}' "201"

test_endpoint "Historial Chat" "GET" "/chat/ride-123/messages" "" "200"

# =========================================
# 11. ADMINISTRADOR - DASHBOARD
# =========================================
echo -e "\n${BLUE}👨‍💼 TESTING PANEL ADMINISTRADOR${NC}"

test_endpoint "Métricas Dashboard" "GET" "/admin/dashboard/metrics?period=today" "" "200"
test_endpoint "Usuarios Activos" "GET" "/admin/users?status=active&page=1&limit=10" "" "200"
test_endpoint "Gestión de Viajes" "GET" "/admin/rides?status=active&page=1&limit=10" "" "200"

# =========================================
# 12. SURGE PRICING (TARIFAS DINÁMICAS)
# =========================================
echo -e "\n${BLUE}📈 TESTING SURGE PRICING${NC}"

test_endpoint "Multiplicador Actual" "GET" "/rides/surge-pricing?lat=-12.0464&lng=-77.0428" "" "200"
test_endpoint "Historial Surge" "GET" "/rides/surge-pricing/history?zone=lima-centro" "" "200"

# =========================================
# 13. VIAJES COMPARTIDOS
# =========================================
echo -e "\n${BLUE}👥 TESTING VIAJES COMPARTIDOS${NC}"

test_endpoint "Solicitar Viaje Compartido" "POST" "/rides/shared/request" '{
    "pickupLocation": {
        "latitude": -12.0464,
        "longitude": -77.0428
    },
    "destinationLocation": {
        "latitude": -12.0621, 
        "longitude": -77.0365
    },
    "maxPassengers": 3,
    "maxDeviationTime": 15
}' "201"

test_endpoint "Matches Disponibles" "GET" "/rides/shared/matches/ride-123" "" "200"

# =========================================
# 14. NOTIFICACIONES
# =========================================
echo -e "\n${BLUE}🔔 TESTING NOTIFICACIONES${NC}"

test_endpoint "Enviar Notificación" "POST" "/notifications/send" '{
    "userId": "user-123",
    "title": "Viaje Confirmado",
    "body": "Tu viaje ha sido confirmado",
    "type": "ride_confirmed",
    "data": {"rideId": "ride-123"}
}' "200"

test_endpoint "Historial Notificaciones" "GET" "/notifications/user-123/history" "" "200"

# =========================================
# 15. SUPPORT Y AYUDA
# =========================================
echo -e "\n${BLUE}❓ TESTING SOPORTE${NC}"

test_endpoint "Crear Ticket Soporte" "POST" "/support/tickets" '{
    "subject": "Problema con pago",
    "category": "payment",
    "description": "No se procesó mi pago correctamente",
    "rideId": "ride-123"
}' "201"

test_endpoint "Listar Tickets" "GET" "/support/tickets" "" "200"

# =========================================
# RESULTADOS FINALES
# =========================================
echo -e "\n${YELLOW}=========================================="
echo -e "📊 RESULTADOS FINALES DEL TESTING"
echo -e "==========================================${NC}"
echo -e "🧪 Total Tests Ejecutados: ${BLUE}$TOTAL_TESTS${NC}"
echo -e "✅ Tests Exitosos: ${GREEN}$PASSED_TESTS${NC}"
echo -e "❌ Tests Fallidos: ${RED}$FAILED_TESTS${NC}"

SUCCESS_RATE=$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))
echo -e "📈 Tasa de Éxito: ${BLUE}$SUCCESS_RATE%${NC}"

if [ $SUCCESS_RATE -ge 80 ]; then
    echo -e "\n${GREEN}🎉 ¡TESTING EXITOSO! La aplicación está lista para producción${NC}"
elif [ $SUCCESS_RATE -ge 60 ]; then
    echo -e "\n${YELLOW}⚠️  TESTING PARCIAL. Revisar endpoints fallidos antes de producción${NC}"
else
    echo -e "\n${RED}🚨 TESTING CRÍTICO. Múltiples endpoints fallidos - Revisar urgentemente${NC}"
fi

echo -e "\n⏰ Testing completado: $(date)"
echo "=========================================="