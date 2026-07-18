#!/usr/bin/env bash
# Ronda 196: distribuye el último build de Rapi Team al grupo interno de
# TestFlight "Team Rapi Interno". Workaround: Apple no permite activar
# hasAccessToAllBuilds=true via API pública, así que tras cada upload
# lo asignamos manualmente al grupo interno.
#
# Requiere: step-cli, python3, curl. La clave .p8 debe existir en la
# ruta ya conocida por el resto del pipeline.
set -euo pipefail

APP_ID=6761776704
INTERNAL_GROUP=0f11d6ef-b9e5-476f-ad6f-166d1f1b8e53
KEY_ID=HM52J5J9XA
ISSUER=77515464-9952-4f79-9de5-caa0561b9603
KEY_FILE="$(cd "$(dirname "$0")/.." && pwd)/AuthKey_${KEY_ID}.p8"

if [[ ! -f "$KEY_FILE" ]]; then
  echo "[distribute] ERROR: falta $KEY_FILE" >&2
  exit 1
fi

# JWT ES256 firmado (10 min de vida) — misma técnica que fastlane usa.
JWT=$(step crypto jwt sign \
  --iss "$ISSUER" --aud "appstoreconnect-v1" \
  --key "$KEY_FILE" --alg ES256 --kid "$KEY_ID" \
  --exp $(($(date +%s) + 600)) --iat $(date +%s) --subtle)

# Poll hasta 5 minutos por el build más reciente en estado VALID (Apple
# necesita procesar el binario antes de aceptar la asignación al grupo).
BUILD_ID=""
for i in $(seq 1 60); do
  BUILD_ID=$(curl -sS -H "Authorization: Bearer $JWT" \
    "https://api.appstoreconnect.apple.com/v1/builds?filter%5Bapp%5D=$APP_ID&sort=-uploadedDate&limit=1&fields%5Bbuilds%5D=version,processingState" \
    | python3 -c "import json,sys; d=json.load(sys.stdin); b=d['data'][0]; print(b['id'] if b['attributes']['processingState']=='VALID' else '')")
  if [[ -n "$BUILD_ID" ]]; then break; fi
  echo "[distribute] build aún procesando… reintento en 5s ($i/60)"
  sleep 5
done

if [[ -z "$BUILD_ID" ]]; then
  echo "[distribute] ERROR: build no llegó a VALID en 5 minutos." >&2
  exit 1
fi

CODE=$(curl -sS -X POST \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d "{\"data\":[{\"type\":\"betaGroups\",\"id\":\"$INTERNAL_GROUP\"}]}" \
  -w "%{http_code}" -o /tmp/asc_assign.out \
  "https://api.appstoreconnect.apple.com/v1/builds/$BUILD_ID/relationships/betaGroups")

if [[ "$CODE" == "204" ]]; then
  echo "[distribute] ✓ Build $BUILD_ID asignado al grupo interno."
else
  echo "[distribute] ERROR HTTP $CODE:" >&2
  cat /tmp/asc_assign.out >&2
  exit 1
fi
