#!/bin/bash

# Script para configurar el entorno de desarrollo
# Reemplaza temporalmente el placeholder con la API key del .env para desarrollo

echo "🔧 Configurando entorno de desarrollo..."

# Cargar variables de entorno
if [ -f .env ]; then
  echo "📁 Cargando variables de entorno desde .env"
  set -a
  source .env
  set +a
else
  echo "❌ ERROR: Archivo .env no encontrado"
  exit 1
fi

# Verificar que las variables necesarias estén definidas
if [ -z "$GOOGLE_MAPS_API_KEY" ]; then
  echo "❌ ERROR: GOOGLE_MAPS_API_KEY no está definida en .env"
  exit 1
fi

# Crear backup del index.html si no existe
if [ ! -f web/index.html.template ]; then
  echo "📄 Creando backup del index.html original"
  cp web/index.html web/index.html.template
fi

# Reemplazar placeholder con la API key real para desarrollo
echo "🔑 Configurando Google Maps API Key para desarrollo..."
cp web/index.html.template web/index.html
sed -i "s/{{GOOGLE_MAPS_API_KEY}}/$GOOGLE_MAPS_API_KEY/g" web/index.html

echo "✅ Entorno de desarrollo configurado correctamente"
echo "💡 Para ejecutar la app en modo desarrollo:"
echo "   flutter run -d chrome --dart-define=GOOGLE_MAPS_API_KEY=\"$GOOGLE_MAPS_API_KEY\" \\"
echo "                          --dart-define=GOOGLE_PLACES_API_KEY=\"$GOOGLE_PLACES_API_KEY\" \\"
echo "                          --dart-define=GOOGLE_DIRECTIONS_API_KEY=\"$GOOGLE_DIRECTIONS_API_KEY\""