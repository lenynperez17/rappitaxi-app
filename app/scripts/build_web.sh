#!/bin/bash

# Script para construir la aplicación web con variables de entorno
# Procesa el archivo index.html para inyectar las API keys

echo "🚀 Iniciando build web con configuración de entorno..."

# Cargar variables de entorno
if [ -f .env ]; then
  echo "📁 Cargando variables de entorno desde .env"
  set -a
  source .env
  set +a
else
  echo "⚠️ Archivo .env no encontrado, usando valores por defecto"
fi

# Verificar que las variables necesarias estén definidas
if [ -z "$GOOGLE_MAPS_API_KEY" ]; then
  echo "❌ ERROR: GOOGLE_MAPS_API_KEY no está definida en .env"
  exit 1
fi

# Crear copia temporal del index.html
cp web/index.html web/index.html.template

# Reemplazar placeholder con la API key real
echo "🔑 Inyectando Google Maps API Key..."
sed -i "s/{{GOOGLE_MAPS_API_KEY}}/$GOOGLE_MAPS_API_KEY/g" web/index.html

# Construir la aplicación
echo "🔨 Ejecutando flutter build web..."
flutter build web --dart-define=GOOGLE_MAPS_API_KEY="$GOOGLE_MAPS_API_KEY" \
                  --dart-define=GOOGLE_PLACES_API_KEY="$GOOGLE_PLACES_API_KEY" \
                  --dart-define=GOOGLE_DIRECTIONS_API_KEY="$GOOGLE_DIRECTIONS_API_KEY" \
                  --dart-define=ENVIRONMENT="$ENVIRONMENT" \
                  --dart-define=API_BASE_URL="$API_BASE_URL"

# Verificar si el build fue exitoso
if [ $? -eq 0 ]; then
  echo "✅ Build completado exitosamente"
else
  echo "❌ ERROR: El build falló"
  # Restaurar el archivo original en caso de error
  cp web/index.html.template web/index.html
  exit 1
fi

# Restaurar el archivo template (mantener placeholder para próximos builds)
cp web/index.html.template web/index.html

echo "🎉 Build web completado con éxito!"