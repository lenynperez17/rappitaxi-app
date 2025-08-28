#!/bin/bash

# =============================================================================
# RAPPITAXI - TESTING COMPLETO DE TODOS LOS ENDPOINTS
# Script de pruebas exhaustivo para validar toda la funcionalidad
# =============================================================================

set -e  # Salir si hay error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración
BASE_URL="http://localhost:3000"
API_URL="${BASE_URL}/api"
TEST_OUTPUT_DIR="../docs/test_results"

# Crear directorio de resultados si no existe
mkdir -p "$TEST_OUTPUT_DIR"

# Variables globales para tokens
AUTH_TOKEN=""
DRIVER_TOKEN=""
PASSENGER_TOKEN=""
ADMIN_TOKEN=""

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

# Función para hacer peticiones cURL y validar respuesta
curl_test() {
    local method=$1
    local endpoint=$2
    local data=$3
    local expected_status=$4
    local description=$5
    local auth_header=$6

    print_info "Probando: $description"
    
    local headers=(-H "Content-Type: application/json")
    if [[ -n "$auth_header" ]]; then
        headers+=(-H "Authorization: Bearer $auth_header")
    fi
    
    local response
    local status_code
    
    if [[ "$method" == "GET" ]]; then
        response=$(curl -s -w "%{http_code}" "${headers[@]}" "$API_URL$endpoint")
    elif [[ "$method" == "DELETE" ]]; then
        response=$(curl -s -w "%{http_code}" -X DELETE "${headers[@]}" "$API_URL$endpoint")
    else
        response=$(curl -s -w "%{http_code}" -X "$method" "${headers[@]}" -d "$data" "$API_URL$endpoint")
    fi
    
    status_code="${response: -3}"
    response_body="${response%???}"
    
    if [[ "$status_code" == "$expected_status" ]]; then
        print_success "$description - Status: $status_code"
        echo "$response_body" | jq '.' 2>/dev/null || echo "$response_body"
        return 0
    else
        print_error "$description - Expected: $expected_status, Got: $status_code"
        echo "$response_body"
        return 1
    fi
}

# =============================================================================
# 1. TESTS DE AUTENTICACIÓN
# =============================================================================
test_authentication() {
    print_info "=== INICIANDO TESTS DE AUTENTICACIÓN ==="
    
    # 1.1 Registro de Pasajero
    local passenger_data='{
        "name": "Test Passenger",
        "email": "testpassenger@rappitaxi.com",
        "password": "TestPass123!",
        "phone": "+51987654321",
        "role": "passenger"
    }'
    
    curl_test "POST" "/auth/register" "$passenger_data" "201" "Registro de pasajero"
    
    # 1.2 Registro de Conductor
    local driver_data='{
        "name": "Test Driver",
        "email": "testdriver@rappitaxi.com",
        "password": "TestPass123!",
        "phone": "+51987654322",
        "role": "driver",
        "driverInfo": {
            "licensePlate": "TEST-123",
            "vehicleModel": "Toyota Yaris",
            "vehicleColor": "Blanco",
            "vehicleYear": 2022
        }
    }'
    
    curl_test "POST" "/auth/register" "$driver_data" "201" "Registro de conductor"
    
    # 1.3 Login Pasajero
    local passenger_login='{
        "email": "testpassenger@rappitaxi.com",
        "password": "TestPass123!"
    }'
    
    local login_response=$(curl -s -X POST -H "Content-Type: application/json" -d "$passenger_login" "$API_URL/auth/login")
    PASSENGER_TOKEN=$(echo "$login_response" | jq -r '.token' 2>/dev/null || echo "")
    
    if [[ -n "$PASSENGER_TOKEN" && "$PASSENGER_TOKEN" != "null" ]]; then
        print_success "Login de pasajero exitoso"
    else
        print_error "Falló el login de pasajero"
    fi
    
    # 1.4 Login Conductor
    local driver_login='{
        "email": "testdriver@rappitaxi.com",
        "password": "TestPass123!"
    }'
    
    local driver_login_response=$(curl -s -X POST -H "Content-Type: application/json" -d "$driver_login" "$API_URL/auth/login")
    DRIVER_TOKEN=$(echo "$driver_login_response" | jq -r '.token' 2>/dev/null || echo "")
    
    if [[ -n "$DRIVER_TOKEN" && "$DRIVER_TOKEN" != "null" ]]; then
        print_success "Login de conductor exitoso"
    else
        print_error "Falló el login de conductor"
    fi
    
    # 1.5 Verificación OTP (simulada)
    local otp_data='{
        "phone": "+51987654321",
        "code": "123456"
    }'
    
    curl_test "POST" "/auth/verify-otp" "$otp_data" "200" "Verificación OTP"
    
    # 1.6 Recuperación de contraseña
    local recovery_data='{
        "email": "testpassenger@rappitaxi.com"
    }'
    
    curl_test "POST" "/auth/forgot-password" "$recovery_data" "200" "Recuperación de contraseña"
    
    # 1.7 Refresh token
    curl_test "POST" "/auth/refresh" '{}' "200" "Refresh token" "$PASSENGER_TOKEN"
}

# =============================================================================
# 2. TESTS DE ENDPOINTS DE PASAJEROS
# =============================================================================
test_passenger_endpoints() {
    print_info "=== INICIANDO TESTS DE PASAJEROS ==="
    
    # 2.1 Obtener perfil
    curl_test "GET" "/passengers/profile" "" "200" "Obtener perfil de pasajero" "$PASSENGER_TOKEN"
    
    # 2.2 Actualizar perfil
    local update_data='{
        "name": "Test Passenger Updated",
        "phone": "+51987654999"
    }'
    
    curl_test "PUT" "/passengers/profile" "$update_data" "200" "Actualizar perfil" "$PASSENGER_TOKEN"
    
    # 2.3 Solicitar viaje
    local ride_request='{
        "pickupLocation": {
            "latitude": -12.0464,
            "longitude": -77.0428,
            "address": "Lima Centro, Peru"
        },
        "destinationLocation": {
            "latitude": -12.0922,
            "longitude": -77.0214,
            "address": "Miraflores, Lima, Peru"
        },
        "rideType": "standard",
        "paymentMethod": "cash",
        "estimatedFare": 15.50
    }'
    
    curl_test "POST" "/passengers/rides/request" "$ride_request" "201" "Solicitar viaje" "$PASSENGER_TOKEN"
    
    # 2.4 Obtener viajes activos
    curl_test "GET" "/passengers/rides/active" "" "200" "Obtener viajes activos" "$PASSENGER_TOKEN"
    
    # 2.5 Historial de viajes
    curl_test "GET" "/passengers/rides/history?page=1&limit=10" "" "200" "Historial de viajes" "$PASSENGER_TOKEN"
    
    # 2.6 Calificar viaje
    local rating_data='{
        "rideId": "test-ride-id",
        "driverRating": 5,
        "comment": "Excelente servicio",
        "tags": ["puntual", "amable", "vehiculo_limpio"]
    }'
    
    curl_test "POST" "/passengers/rides/rate" "$rating_data" "200" "Calificar viaje" "$PASSENGER_TOKEN"
    
    # 2.7 Agregar método de pago
    local payment_method='{
        "type": "card",
        "cardNumber": "4111111111111111",
        "expiryMonth": "12",
        "expiryYear": "2025",
        "cvv": "123",
        "holderName": "Test User"
    }'
    
    curl_test "POST" "/passengers/payment-methods" "$payment_method" "201" "Agregar método de pago" "$PASSENGER_TOKEN"
    
    # 2.8 Obtener métodos de pago
    curl_test "GET" "/passengers/payment-methods" "" "200" "Obtener métodos de pago" "$PASSENGER_TOKEN"
    
    # 2.9 Agregar dirección favorita
    local favorite_address='{
        "label": "Casa",
        "address": "Av. Test 123, Lima",
        "latitude": -12.0464,
        "longitude": -77.0428
    }'
    
    curl_test "POST" "/passengers/addresses" "$favorite_address" "201" "Agregar dirección favorita" "$PASSENGER_TOKEN"
    
    # 2.10 Obtener direcciones favoritas
    curl_test "GET" "/passengers/addresses" "" "200" "Obtener direcciones favoritas" "$PASSENGER_TOKEN"
}

# =============================================================================
# 3. TESTS DE ENDPOINTS DE CONDUCTORES
# =============================================================================
test_driver_endpoints() {
    print_info "=== INICIANDO TESTS DE CONDUCTORES ==="
    
    # 3.1 Obtener perfil de conductor
    curl_test "GET" "/drivers/profile" "" "200" "Obtener perfil de conductor" "$DRIVER_TOKEN"
    
    # 3.2 Actualizar ubicación
    local location_data='{
        "latitude": -12.0464,
        "longitude": -77.0428,
        "heading": 90.0
    }'
    
    curl_test "PUT" "/drivers/location" "$location_data" "200" "Actualizar ubicación" "$DRIVER_TOKEN"
    
    # 3.3 Cambiar estado de disponibilidad
    local status_data='{
        "status": "online"
    }'
    
    curl_test "PUT" "/drivers/status" "$status_data" "200" "Cambiar estado" "$DRIVER_TOKEN"
    
    # 3.4 Obtener solicitudes de viaje cercanas
    curl_test "GET" "/drivers/rides/nearby?radius=5000" "" "200" "Solicitudes cercanas" "$DRIVER_TOKEN"
    
    # 3.5 Aceptar viaje
    local accept_data='{
        "rideId": "test-ride-id",
        "estimatedArrival": 5
    }'
    
    curl_test "POST" "/drivers/rides/accept" "$accept_data" "200" "Aceptar viaje" "$DRIVER_TOKEN"
    
    # 3.6 Iniciar viaje
    local start_data='{
        "rideId": "test-ride-id"
    }'
    
    curl_test "POST" "/drivers/rides/start" "$start_data" "200" "Iniciar viaje" "$DRIVER_TOKEN"
    
    # 3.7 Finalizar viaje
    local complete_data='{
        "rideId": "test-ride-id",
        "finalFare": 18.75,
        "endLocation": {
            "latitude": -12.0922,
            "longitude": -77.0214
        }
    }'
    
    curl_test "POST" "/drivers/rides/complete" "$complete_data" "200" "Finalizar viaje" "$DRIVER_TOKEN"
    
    # 3.8 Historial de viajes del conductor
    curl_test "GET" "/drivers/rides/history?page=1&limit=10" "" "200" "Historial conductor" "$DRIVER_TOKEN"
    
    # 3.9 Estadísticas del conductor
    curl_test "GET" "/drivers/stats" "" "200" "Estadísticas conductor" "$DRIVER_TOKEN"
    
    # 3.10 Ganancias del conductor
    curl_test "GET" "/drivers/earnings?startDate=2024-01-01&endDate=2024-12-31" "" "200" "Ganancias conductor" "$DRIVER_TOKEN"
}

# =============================================================================
# 4. TESTS DE NEGOCIACIÓN DE PRECIOS (INDRIVE STYLE)
# =============================================================================
test_price_negotiation() {
    print_info "=== INICIANDO TESTS DE NEGOCIACIÓN DE PRECIOS ==="
    
    # 4.1 Solicitar viaje con negociación
    local negotiation_request='{
        "pickupLocation": {
            "latitude": -12.0464,
            "longitude": -77.0428,
            "address": "Lima Centro, Peru"
        },
        "destinationLocation": {
            "latitude": -12.0922,
            "longitude": -77.0214,
            "address": "Miraflores, Lima, Peru"
        },
        "proposedFare": 20.00,
        "negotiationEnabled": true,
        "maxWaitTime": 300
    }'
    
    curl_test "POST" "/rides/negotiate" "$negotiation_request" "201" "Solicitar negociación" "$PASSENGER_TOKEN"
    
    # 4.2 Conductor envía contrapropuesta
    local driver_offer='{
        "rideId": "test-negotiation-ride-id",
        "offeredFare": 25.00,
        "estimatedArrival": 3,
        "message": "Precio por tráfico pesado"
    }'
    
    curl_test "POST" "/drivers/rides/offer" "$driver_offer" "200" "Enviar contrapropuesta" "$DRIVER_TOKEN"
    
    # 4.3 Obtener ofertas para un viaje
    curl_test "GET" "/passengers/rides/test-negotiation-ride-id/offers" "" "200" "Obtener ofertas" "$PASSENGER_TOKEN"
    
    # 4.4 Pasajero acepta oferta
    local accept_offer='{
        "offerId": "test-offer-id",
        "driverId": "test-driver-id"
    }'
    
    curl_test "POST" "/passengers/rides/accept-offer" "$accept_offer" "200" "Aceptar oferta" "$PASSENGER_TOKEN"
    
    # 4.5 Extender tiempo de negociación
    curl_test "POST" "/passengers/rides/test-negotiation-ride-id/extend" '{}' "200" "Extender tiempo" "$PASSENGER_TOKEN"
}

# =============================================================================
# 5. TESTS DE CHAT Y MENSAJERÍA
# =============================================================================
test_chat_system() {
    print_info "=== INICIANDO TESTS DE CHAT ==="
    
    # 5.1 Enviar mensaje desde pasajero
    local passenger_message='{
        "rideId": "test-ride-id",
        "message": "Estoy esperando en la puerta principal",
        "messageType": "text"
    }'
    
    curl_test "POST" "/chat/send" "$passenger_message" "200" "Mensaje desde pasajero" "$PASSENGER_TOKEN"
    
    # 5.2 Enviar mensaje desde conductor
    local driver_message='{
        "rideId": "test-ride-id", 
        "message": "Ya llegué, estoy en auto azul",
        "messageType": "text"
    }'
    
    curl_test "POST" "/chat/send" "$driver_message" "200" "Mensaje desde conductor" "$DRIVER_TOKEN"
    
    # 5.3 Obtener historial de chat
    curl_test "GET" "/chat/test-ride-id/messages" "" "200" "Historial de chat" "$PASSENGER_TOKEN"
    
    # 5.4 Enviar ubicación en tiempo real
    local location_message='{
        "rideId": "test-ride-id",
        "messageType": "location",
        "location": {
            "latitude": -12.0464,
            "longitude": -77.0428
        }
    }'
    
    curl_test "POST" "/chat/send" "$location_message" "200" "Enviar ubicación" "$PASSENGER_TOKEN"
    
    # 5.5 Marcar mensajes como leídos
    curl_test "PUT" "/chat/test-ride-id/mark-read" '{}' "200" "Marcar como leído" "$DRIVER_TOKEN"
}

# =============================================================================
# 6. TESTS DE PAGOS (MERCADOPAGO)
# =============================================================================
test_payments() {
    print_info "=== INICIANDO TESTS DE PAGOS ==="
    
    # 6.1 Crear preferencia de pago
    local payment_preference='{
        "rideId": "test-ride-id",
        "amount": 25.50,
        "description": "Viaje en RappiTaxi",
        "paymentMethod": "mercadopago"
    }'
    
    curl_test "POST" "/payments/create-preference" "$payment_preference" "200" "Crear preferencia de pago" "$PASSENGER_TOKEN"
    
    # 6.2 Procesar pago
    local payment_data='{
        "preferenceId": "test-preference-id",
        "paymentId": "test-payment-id",
        "status": "approved"
    }'
    
    curl_test "POST" "/payments/process" "$payment_data" "200" "Procesar pago" "$PASSENGER_TOKEN"
    
    # 6.3 Webhook de MercadoPago
    local webhook_data='{
        "action": "payment.created",
        "api_version": "v1",
        "data": {
            "id": "test-payment-id"
        }
    }'
    
    curl_test "POST" "/payments/webhook" "$webhook_data" "200" "Webhook MercadoPago"
    
    # 6.4 Obtener historial de pagos
    curl_test "GET" "/payments/history" "" "200" "Historial de pagos" "$PASSENGER_TOKEN"
    
    # 6.5 Reembolso
    local refund_data='{
        "paymentId": "test-payment-id",
        "reason": "Viaje cancelado"
    }'
    
    curl_test "POST" "/payments/refund" "$refund_data" "200" "Procesar reembolso" "$PASSENGER_TOKEN"
}

# =============================================================================
# 7. TESTS DE NOTIFICACIONES
# =============================================================================
test_notifications() {
    print_info "=== INICIANDO TESTS DE NOTIFICACIONES ==="
    
    # 7.1 Registrar token FCM
    local fcm_data='{
        "fcmToken": "test-fcm-token-123456",
        "platform": "android"
    }'
    
    curl_test "POST" "/notifications/register-token" "$fcm_data" "200" "Registrar token FCM" "$PASSENGER_TOKEN"
    
    # 7.2 Enviar notificación push
    local push_notification='{
        "userId": "test-user-id",
        "title": "Conductor asignado",
        "body": "Tu conductor llegará en 3 minutos",
        "type": "driver_assigned",
        "data": {
            "rideId": "test-ride-id"
        }
    }'
    
    curl_test "POST" "/notifications/push" "$push_notification" "200" "Enviar push notification"
    
    # 7.3 Enviar notificación por email
    local email_notification='{
        "userId": "test-user-id",
        "template": "ride_completed",
        "data": {
            "rideId": "test-ride-id",
            "fare": "25.50"
        }
    }'
    
    curl_test "POST" "/notifications/email" "$email_notification" "200" "Enviar email"
    
    # 7.4 Obtener notificaciones del usuario
    curl_test "GET" "/notifications?page=1&limit=10" "" "200" "Obtener notificaciones" "$PASSENGER_TOKEN"
    
    # 7.5 Marcar notificación como leída
    curl_test "PUT" "/notifications/test-notification-id/read" '{}' "200" "Marcar como leída" "$PASSENGER_TOKEN"
}

# =============================================================================
# 8. TESTS DE ADMINISTRACIÓN
# =============================================================================
test_admin_endpoints() {
    print_info "=== INICIANDO TESTS DE ADMINISTRACIÓN ==="
    
    # Nota: Para estos tests necesitaríamos un token de admin
    # Por simplicidad, usaremos el passenger token con permisos elevados
    
    # 8.1 Dashboard - métricas generales
    curl_test "GET" "/admin/dashboard" "" "200" "Dashboard admin" "$PASSENGER_TOKEN"
    
    # 8.2 Obtener todos los conductores
    curl_test "GET" "/admin/drivers?page=1&limit=10" "" "200" "Lista de conductores" "$PASSENGER_TOKEN"
    
    # 8.3 Obtener todos los pasajeros
    curl_test "GET" "/admin/passengers?page=1&limit=10" "" "200" "Lista de pasajeros" "$PASSENGER_TOKEN"
    
    # 8.4 Estadísticas de viajes
    curl_test "GET" "/admin/rides/stats?startDate=2024-01-01&endDate=2024-12-31" "" "200" "Stats de viajes" "$PASSENGER_TOKEN"
    
    # 8.5 Suspender conductor
    local suspend_data='{
        "driverId": "test-driver-id",
        "reason": "Múltiples reportes de usuarios",
        "duration": 7
    }'
    
    curl_test "POST" "/admin/drivers/suspend" "$suspend_data" "200" "Suspender conductor" "$PASSENGER_TOKEN"
    
    # 8.6 Reportes financieros
    curl_test "GET" "/admin/reports/financial?month=12&year=2024" "" "200" "Reportes financieros" "$PASSENGER_TOKEN"
    
    # 8.7 Gestionar tarifas dinámicas
    local surge_config='{
        "zone": "lima_centro",
        "multiplier": 1.5,
        "active": true
    }'
    
    curl_test "POST" "/admin/surge-pricing" "$surge_config" "200" "Configurar surge pricing" "$PASSENGER_TOKEN"
}

# =============================================================================
# 9. TESTS DE UBICACIÓN Y MAPAS
# =============================================================================
test_location_services() {
    print_info "=== INICIANDO TESTS DE SERVICIOS DE UBICACIÓN ==="
    
    # 9.1 Geocoding - obtener dirección desde coordenadas
    curl_test "GET" "/location/geocode?lat=-12.0464&lng=-77.0428" "" "200" "Geocoding"
    
    # 9.2 Reverse geocoding - obtener coordenadas desde dirección
    curl_test "GET" "/location/reverse-geocode?address=Lima%20Centro%20Peru" "" "200" "Reverse geocoding"
    
    # 9.3 Buscar lugares
    curl_test "GET" "/location/places/search?query=restaurantes&lat=-12.0464&lng=-77.0428" "" "200" "Buscar lugares"
    
    # 9.4 Obtener ruta entre puntos
    local route_request='{
        "origin": {"latitude": -12.0464, "longitude": -77.0428},
        "destination": {"latitude": -12.0922, "longitude": -77.0214}
    }'
    
    curl_test "POST" "/location/route" "$route_request" "200" "Calcular ruta"
    
    # 9.5 Estimar tiempo y distancia
    curl_test "POST" "/location/estimate" "$route_request" "200" "Estimar tiempo/distancia"
    
    # 9.6 Obtener conductores cercanos
    curl_test "GET" "/location/drivers/nearby?lat=-12.0464&lng=-77.0428&radius=2000" "" "200" "Conductores cercanos"
}

# =============================================================================
# 10. TESTS DE PROMOCIONES Y REFERIDOS
# =============================================================================
test_promotions() {
    print_info "=== INICIANDO TESTS DE PROMOCIONES ==="
    
    # 10.1 Obtener promociones activas
    curl_test "GET" "/promotions/active" "" "200" "Promociones activas" "$PASSENGER_TOKEN"
    
    # 10.2 Aplicar código de descuento
    local promo_data='{
        "code": "PRIMEROVIAJE",
        "rideId": "test-ride-id"
    }'
    
    curl_test "POST" "/promotions/apply" "$promo_data" "200" "Aplicar promoción" "$PASSENGER_TOKEN"
    
    # 10.3 Sistema de referidos - obtener código
    curl_test "GET" "/referrals/my-code" "" "200" "Mi código de referido" "$PASSENGER_TOKEN"
    
    # 10.4 Usar código de referido
    local referral_data='{
        "referralCode": "TEST123456"
    }'
    
    curl_test "POST" "/referrals/use" "$referral_data" "200" "Usar código referido" "$PASSENGER_TOKEN"
    
    # 10.5 Estadísticas de referidos
    curl_test "GET" "/referrals/stats" "" "200" "Stats de referidos" "$PASSENGER_TOKEN"
}

# =============================================================================
# FUNCIÓN PRINCIPAL
# =============================================================================
main() {
    print_info "🚀 INICIANDO TESTING COMPLETO DE RAPPITAXI"
    print_info "Base URL: $BASE_URL"
    print_info "Resultados se guardarán en: $TEST_OUTPUT_DIR"
    
    # Verificar que el servidor esté corriendo
    if ! curl -s "$BASE_URL/health" > /dev/null; then
        print_error "El servidor no está corriendo en $BASE_URL"
        print_info "Ejecuta: cd ../backend && npm run dev"
        exit 1
    fi
    
    print_success "Servidor está corriendo ✅"
    
    # Ejecutar todas las pruebas
    local start_time=$(date +%s)
    
    test_authentication
    test_passenger_endpoints  
    test_driver_endpoints
    test_price_negotiation
    test_chat_system
    test_payments
    test_notifications
    test_admin_endpoints
    test_location_services
    test_promotions
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    print_success "🎉 TESTING COMPLETO FINALIZADO"
    print_info "⏱️  Tiempo total: ${duration}s"
    print_info "📊 Revisa los resultados en: $TEST_OUTPUT_DIR"
    
    # Generar reporte final
    local report_file="$TEST_OUTPUT_DIR/test_summary_$(date +%Y%m%d_%H%M%S).json"
    echo "{
        \"timestamp\": \"$(date -Iseconds)\",
        \"duration\": ${duration},
        \"base_url\": \"$BASE_URL\",
        \"tests_completed\": true,
        \"status\": \"success\"
    }" > "$report_file"
    
    print_success "📋 Reporte guardado: $report_file"
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi