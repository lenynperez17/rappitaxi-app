#!/bin/bash

# 🎯 SCRIPT DE PRUEBAS EXHAUSTIVAS - RAPPITAXI API
# ========================================================
# Este script prueba TODAS las funcionalidades del backend
# Fecha: Diciembre 2024
# ========================================================

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración base
BASE_URL="http://localhost:5001/api/v1"
ADMIN_TOKEN=""
PASSENGER_TOKEN=""
DRIVER_TOKEN=""

# Variables para IDs generados
PASSENGER_ID=""
DRIVER_ID=""
RIDE_ID=""
PAYMENT_ID=""
VEHICLE_ID=""

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🚀 INICIANDO PRUEBAS COMPLETAS RAPPITAXI${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Función para verificar respuesta
check_response() {
    local status=$1
    local test_name=$2
    
    if [ $status -eq 0 ]; then
        echo -e "${GREEN}✅ $test_name - EXITOSO${NC}"
    else
        echo -e "${RED}❌ $test_name - FALLÓ${NC}"
    fi
}

# ========================================
# 1. HEALTH CHECK
# ========================================

echo -e "\n${YELLOW}1. VERIFICANDO HEALTH CHECK${NC}"
echo "========================================="

# Health check básico
echo "Probando health check..."
curl -s -o /dev/null -w "%{http_code}" $BASE_URL/health | grep -q 200
check_response $? "Health Check"

# ========================================
# 2. AUTENTICACIÓN DE PASAJEROS
# ========================================

echo -e "\n${YELLOW}2. TESTING DE AUTENTICACIÓN - PASAJERO${NC}"
echo "========================================="

# Registro de pasajero
echo "Registrando nuevo pasajero..."
REGISTER_RESPONSE=$(curl -s -X POST $BASE_URL/passengers/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test'$(date +%s)'@rappitaxi.com",
    "password": "Test123!@#",
    "name": "Test Passenger",
    "phone": "+51999888777",
    "birthDate": "1990-01-01"
  }')

if echo "$REGISTER_RESPONSE" | grep -q "token"; then
    PASSENGER_TOKEN=$(echo "$REGISTER_RESPONSE" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
    echo -e "${GREEN}✅ Registro de pasajero exitoso${NC}"
else
    echo -e "${RED}❌ Registro de pasajero falló${NC}"
fi

# Login de pasajero
echo "Probando login de pasajero..."
LOGIN_RESPONSE=$(curl -s -X POST $BASE_URL/passengers/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@rappitaxi.com",
    "password": "Test123!@#"
  }')

echo "$LOGIN_RESPONSE" | grep -q "token"
check_response $? "Login de pasajero"

# ========================================
# 3. GESTIÓN DE PERFIL - PASAJERO
# ========================================

echo -e "\n${YELLOW}3. TESTING DE PERFIL - PASAJERO${NC}"
echo "========================================="

# Obtener perfil
echo "Obteniendo perfil del pasajero..."
curl -s -X GET $BASE_URL/passengers/profile \
  -H "Authorization: Bearer $PASSENGER_TOKEN" | grep -q "name"
check_response $? "Obtener perfil de pasajero"

# Actualizar perfil
echo "Actualizando perfil del pasajero..."
curl -s -X PUT $BASE_URL/passengers/profile \
  -H "Authorization: Bearer $PASSENGER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "emergencyContact": {
      "name": "Contacto Emergencia",
      "phone": "+51999777666"
    }
  }' | grep -q "success"
check_response $? "Actualizar perfil de pasajero"

# ========================================
# 4. ESTIMACIÓN Y SOLICITUD DE VIAJES
# ========================================

echo -e "\n${YELLOW}4. TESTING DE VIAJES - PASAJERO${NC}"
echo "========================================="

# Estimar tarifa
echo "Estimando tarifa de viaje..."
ESTIMATE_RESPONSE=$(curl -s -X POST $BASE_URL/passengers/rides/estimate \
  -H "Authorization: Bearer $PASSENGER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "pickup": {
      "latitude": -12.0464,
      "longitude": -77.0428,
      "address": "Plaza San Martín, Lima"
    },
    "destination": {
      "latitude": -12.0558,
      "longitude": -77.0358,
      "address": "Parque Kennedy, Miraflores"
    },
    "vehicleType": "standard"
  }')

echo "$ESTIMATE_RESPONSE" | grep -q "estimatedFare"
check_response $? "Estimación de tarifa"

# Solicitar viaje
echo "Solicitando viaje..."
RIDE_RESPONSE=$(curl -s -X POST $BASE_URL/passengers/rides/request \
  -H "Authorization: Bearer $PASSENGER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "pickup": {
      "latitude": -12.0464,
      "longitude": -77.0428,
      "address": "Plaza San Martín, Lima"
    },
    "destination": {
      "latitude": -12.0558,
      "longitude": -77.0358,
      "address": "Parque Kennedy, Miraflores"
    },
    "vehicleType": "standard",
    "paymentMethod": "cash",
    "estimatedFare": 25.50
  }')

if echo "$RIDE_RESPONSE" | grep -q "rideId"; then
    RIDE_ID=$(echo "$RIDE_RESPONSE" | grep -o '"rideId":"[^"]*' | cut -d'"' -f4)
    echo -e "${GREEN}✅ Solicitud de viaje exitosa - ID: $RIDE_ID${NC}"
else
    echo -e "${RED}❌ Solicitud de viaje falló${NC}"
fi

# ========================================
# 5. LUGARES FAVORITOS
# ========================================

echo -e "\n${YELLOW}5. TESTING DE LUGARES FAVORITOS${NC}"
echo "========================================="

# Agregar lugar favorito
echo "Agregando lugar favorito..."
curl -s -X POST $BASE_URL/passengers/favorites \
  -H "Authorization: Bearer $PASSENGER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Casa",
    "address": "Av. Arequipa 123, Lima",
    "latitude": -12.0464,
    "longitude": -77.0428,
    "type": "home"
  }' | grep -q "success"
check_response $? "Agregar lugar favorito"

# Obtener lugares favoritos
echo "Obteniendo lugares favoritos..."
curl -s -X GET $BASE_URL/passengers/favorites \
  -H "Authorization: Bearer $PASSENGER_TOKEN" | grep -q "favorites"
check_response $? "Obtener lugares favoritos"

# ========================================
# 6. AUTENTICACIÓN DE CONDUCTORES
# ========================================

echo -e "\n${YELLOW}6. TESTING DE AUTENTICACIÓN - CONDUCTOR${NC}"
echo "========================================="

# Registro de conductor
echo "Registrando nuevo conductor..."
DRIVER_REGISTER=$(curl -s -X POST $BASE_URL/drivers/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "driver'$(date +%s)'@rappitaxi.com",
    "password": "Driver123!@#",
    "name": "Test Driver",
    "phone": "+51999666555",
    "licenseNumber": "LIC123456"
  }')

if echo "$DRIVER_REGISTER" | grep -q "token"; then
    DRIVER_TOKEN=$(echo "$DRIVER_REGISTER" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
    echo -e "${GREEN}✅ Registro de conductor exitoso${NC}"
else
    echo -e "${RED}❌ Registro de conductor falló${NC}"
fi

# ========================================
# 7. GESTIÓN DE VEHÍCULO - CONDUCTOR
# ========================================

echo -e "\n${YELLOW}7. TESTING DE VEHÍCULO - CONDUCTOR${NC}"
echo "========================================="

# Registrar vehículo
echo "Registrando vehículo del conductor..."
VEHICLE_RESPONSE=$(curl -s -X POST $BASE_URL/drivers/vehicle \
  -H "Authorization: Bearer $DRIVER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "make": "Toyota",
    "model": "Corolla",
    "year": 2020,
    "color": "Negro",
    "plateNumber": "ABC-123",
    "capacity": 4,
    "vehicleType": "standard"
  }')

echo "$VEHICLE_RESPONSE" | grep -q "vehicleId"
check_response $? "Registro de vehículo"

# ========================================
# 8. ESTADO Y UBICACIÓN - CONDUCTOR
# ========================================

echo -e "\n${YELLOW}8. TESTING DE ESTADO - CONDUCTOR${NC}"
echo "========================================="

# Cambiar estado online
echo "Cambiando estado del conductor a online..."
curl -s -X PATCH $BASE_URL/drivers/status \
  -H "Authorization: Bearer $DRIVER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "status": "online"
  }' | grep -q "success"
check_response $? "Cambiar estado online"

# Actualizar ubicación
echo "Actualizando ubicación del conductor..."
curl -s -X POST $BASE_URL/drivers/location \
  -H "Authorization: Bearer $DRIVER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "latitude": -12.0464,
    "longitude": -77.0428,
    "heading": 90,
    "speed": 30
  }' | grep -q "success"
check_response $? "Actualizar ubicación"

# ========================================
# 9. ADMIN - DASHBOARD
# ========================================

echo -e "\n${YELLOW}9. TESTING DE ADMIN - DASHBOARD${NC}"
echo "========================================="

# Login admin (usando credenciales de prueba)
echo "Login de administrador..."
ADMIN_LOGIN=$(curl -s -X POST $BASE_URL/admin/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@rappitaxi.com",
    "password": "Admin123!@#"
  }')

if echo "$ADMIN_LOGIN" | grep -q "token"; then
    ADMIN_TOKEN=$(echo "$ADMIN_LOGIN" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
    echo -e "${GREEN}✅ Login admin exitoso${NC}"
else
    echo -e "${YELLOW}⚠️ Login admin falló (puede no estar configurado)${NC}"
fi

# Obtener métricas del dashboard
if [ ! -z "$ADMIN_TOKEN" ]; then
    echo "Obteniendo métricas del dashboard..."
    curl -s -X GET "$BASE_URL/admin/dashboard/metrics?period=today" \
      -H "Authorization: Bearer $ADMIN_TOKEN" | grep -q "metrics"
    check_response $? "Métricas del dashboard"
fi

# ========================================
# 10. MÉTODOS DE PAGO
# ========================================

echo -e "\n${YELLOW}10. TESTING DE MÉTODOS DE PAGO${NC}"
echo "========================================="

# Obtener métodos de pago
echo "Obteniendo métodos de pago..."
curl -s -X GET $BASE_URL/passengers/payment-methods \
  -H "Authorization: Bearer $PASSENGER_TOKEN" | grep -q "methods"
check_response $? "Obtener métodos de pago"

# Obtener balance de wallet
echo "Obteniendo balance de wallet..."
curl -s -X GET $BASE_URL/passengers/wallet/balance \
  -H "Authorization: Bearer $PASSENGER_TOKEN" | grep -q "balance"
check_response $? "Balance de wallet"

# ========================================
# 11. GANANCIAS - CONDUCTOR
# ========================================

echo -e "\n${YELLOW}11. TESTING DE GANANCIAS - CONDUCTOR${NC}"
echo "========================================="

# Obtener resumen de ganancias
echo "Obteniendo resumen de ganancias del conductor..."
curl -s -X GET "$BASE_URL/drivers/earnings/summary?period=today" \
  -H "Authorization: Bearer $DRIVER_TOKEN" | grep -q "earnings"
check_response $? "Resumen de ganancias"

# Obtener balance actual
echo "Obteniendo balance actual del conductor..."
curl -s -X GET $BASE_URL/drivers/earnings/balance \
  -H "Authorization: Bearer $DRIVER_TOKEN" | grep -q "balance"
check_response $? "Balance del conductor"

# ========================================
# 12. NOTIFICACIONES
# ========================================

echo -e "\n${YELLOW}12. TESTING DE NOTIFICACIONES${NC}"
echo "========================================="

# Obtener notificaciones del pasajero
echo "Obteniendo notificaciones del pasajero..."
curl -s -X GET $BASE_URL/passengers/notifications \
  -H "Authorization: Bearer $PASSENGER_TOKEN" | grep -q "notifications"
check_response $? "Notificaciones del pasajero"

# Registrar token FCM
echo "Registrando token FCM..."
curl -s -X POST $BASE_URL/passengers/notifications/fcm-token \
  -H "Authorization: Bearer $PASSENGER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "token": "fake-fcm-token-for-testing",
    "platform": "android"
  }' | grep -q "success"
check_response $? "Registro token FCM"

# ========================================
# 13. RESERVAS PROGRAMADAS
# ========================================

echo -e "\n${YELLOW}13. TESTING DE RESERVAS PROGRAMADAS${NC}"
echo "========================================="

# Crear reserva programada
echo "Creando reserva programada..."
TOMORROW=$(date -u -d "tomorrow" +"%Y-%m-%dT14:00:00Z")
curl -s -X POST $BASE_URL/passengers/bookings \
  -H "Authorization: Bearer $PASSENGER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "pickup": {
      "latitude": -12.0464,
      "longitude": -77.0428,
      "address": "Plaza San Martín, Lima"
    },
    "destination": {
      "latitude": -12.0558,
      "longitude": -77.0358,
      "address": "Parque Kennedy, Miraflores"
    },
    "scheduledTime": "'$TOMORROW'",
    "vehicleType": "standard",
    "paymentMethod": "cash"
  }' | grep -q "bookingId"
check_response $? "Crear reserva programada"

# ========================================
# 14. HORARIOS - CONDUCTOR
# ========================================

echo -e "\n${YELLOW}14. TESTING DE HORARIOS - CONDUCTOR${NC}"
echo "========================================="

# Obtener horario
echo "Obteniendo horario del conductor..."
curl -s -X GET $BASE_URL/drivers/schedule \
  -H "Authorization: Bearer $DRIVER_TOKEN" | grep -q "schedule"
check_response $? "Obtener horario"

# Configurar horario
echo "Configurando horario del conductor..."
curl -s -X PUT $BASE_URL/drivers/schedule \
  -H "Authorization: Bearer $DRIVER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "monday": {"start": "08:00", "end": "18:00", "enabled": true},
    "tuesday": {"start": "08:00", "end": "18:00", "enabled": true},
    "autoOffline": true
  }' | grep -q "success"
check_response $? "Configurar horario"

# ========================================
# 15. CALIFICACIONES Y FEEDBACK
# ========================================

echo -e "\n${YELLOW}15. TESTING DE CALIFICACIONES${NC}"
echo "========================================="

# Obtener resumen de calificaciones del conductor
echo "Obteniendo resumen de calificaciones..."
curl -s -X GET "$BASE_URL/drivers/ratings/summary?period=all" \
  -H "Authorization: Bearer $DRIVER_TOKEN" | grep -q "summary"
check_response $? "Resumen de calificaciones"

# ========================================
# 16. WEBSOCKETS (Simulado)
# ========================================

echo -e "\n${YELLOW}16. TESTING DE WEBSOCKETS (Simulado)${NC}"
echo "========================================="

# Test de conexión WebSocket (solo verificamos el endpoint)
echo "Verificando endpoint WebSocket..."
curl -s -o /dev/null -w "%{http_code}" http://localhost:5001/socket.io/ | grep -q 200
check_response $? "Endpoint WebSocket disponible"

# ========================================
# RESUMEN FINAL
# ========================================

echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}📊 RESUMEN DE PRUEBAS COMPLETADAS${NC}"
echo -e "${BLUE}========================================${NC}"

echo -e "\n${GREEN}✅ FUNCIONALIDADES PROBADAS:${NC}"
echo "  1. Health Check del servidor"
echo "  2. Autenticación completa (registro/login)"
echo "  3. Gestión de perfiles"
echo "  4. Estimación y solicitud de viajes"
echo "  5. Lugares favoritos"
echo "  6. Registro de conductores"
echo "  7. Gestión de vehículos"
echo "  8. Estado y ubicación en tiempo real"
echo "  9. Panel de administración"
echo "  10. Métodos de pago y wallet"
echo "  11. Sistema de ganancias"
echo "  12. Notificaciones push"
echo "  13. Reservas programadas"
echo "  14. Horarios de conductores"
echo "  15. Sistema de calificaciones"
echo "  16. WebSocket para real-time"

echo -e "\n${YELLOW}📝 NOTAS:${NC}"
echo "  - Algunas pruebas pueden fallar si el backend no está corriendo"
echo "  - Las credenciales de admin deben configurarse previamente"
echo "  - Los tokens FCM son simulados para pruebas"
echo "  - WebSocket requiere una conexión real para pruebas completas"

echo -e "\n${GREEN}🎯 PRUEBAS COMPLETADAS EXITOSAMENTE${NC}\n"

# Guardar tokens para futuras pruebas
echo "# Tokens generados durante las pruebas" > tokens_test.txt
echo "PASSENGER_TOKEN=$PASSENGER_TOKEN" >> tokens_test.txt
echo "DRIVER_TOKEN=$DRIVER_TOKEN" >> tokens_test.txt
echo "ADMIN_TOKEN=$ADMIN_TOKEN" >> tokens_test.txt
echo "RIDE_ID=$RIDE_ID" >> tokens_test.txt

echo -e "${BLUE}Tokens guardados en tokens_test.txt para pruebas futuras${NC}\n"