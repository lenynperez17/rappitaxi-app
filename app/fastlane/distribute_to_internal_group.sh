#!/usr/bin/env bash
# Ronda 196 + 198: distribuye el build recién subido al grupo interno de
# TestFlight "Team Rapi Interno". Apple no permite hasAccessToAllBuilds=true
# via API pública, así que asignamos manualmente cada release.
#
# Ronda 198 fix: filtramos por VERSION explícita leída del pubspec.yaml,
# NO por "más reciente por uploadedDate". Antes: si Apple indexaba primero
# una build anterior aún no asignada, el script la asignaba en vez de la
# recién subida.
#
# Requiere: step-cli, python3, curl. Ruta de la key .p8 conocida.
set -euo pipefail

APP_ID=6761776704
INTERNAL_GROUP=0f11d6ef-b9e5-476f-ad6f-166d1f1b8e53
KEY_ID=HM52J5J9XA
ISSUER=77515464-9952-4f79-9de5-caa0561b9603
KEY_FILE="$(cd "$(dirname "$0")/.." && pwd)/AuthKey_${KEY_ID}.p8"
PUBSPEC="$(cd "$(dirname "$0")/.." && pwd)/pubspec.yaml"

if [[ ! -f "$KEY_FILE" ]]; then
  echo "[distribute] ERROR: falta $KEY_FILE" >&2
  exit 1
fi
if [[ ! -f "$PUBSPEC" ]]; then
  echo "[distribute] ERROR: falta $PUBSPEC" >&2
  exit 1
fi

# Extraer el build number del pubspec.yaml: `version: 1.3.0+124` → 124.
TARGET_BUILD=$(grep -E '^version:' "$PUBSPEC" | sed -E 's/^version:[[:space:]]*[^+]+\+([0-9]+).*/\1/')
if [[ -z "$TARGET_BUILD" ]]; then
  echo "[distribute] ERROR: no pude extraer buildNumber de $PUBSPEC" >&2
  exit 1
fi
echo "[distribute] target version=$TARGET_BUILD"

# JWT ES256 firmado (30 min de vida — máximo permitido por Apple).
JWT=$(step crypto jwt sign \
  --iss "$ISSUER" --aud "appstoreconnect-v1" \
  --key "$KEY_FILE" --alg ES256 --kid "$KEY_ID" \
  --exp $(($(date +%s) + 1800)) --iat $(date +%s) --subtle)

# Poll hasta 20 minutos por el build EXACTO en estado VALID.
BUILD_ID=""
for i in $(seq 1 120); do
  R=$(curl -sS -H "Authorization: Bearer $JWT" \
    "https://api.appstoreconnect.apple.com/v1/builds?filter%5Bapp%5D=${APP_ID}&filter%5Bversion%5D=${TARGET_BUILD}&limit=1")
  BUILD_ID=$(echo "$R" | python3 -c "
import json,sys
d = json.load(sys.stdin)
arr = d.get('data', [])
if arr and arr[0]['attributes']['processingState'] == 'VALID':
    print(arr[0]['id'])
")
  if [[ -n "$BUILD_ID" ]]; then break; fi
  echo "[distribute] build $TARGET_BUILD aún procesando… reintento en 10s ($i/120)"
  sleep 10
done

if [[ -z "$BUILD_ID" ]]; then
  echo "[distribute] ERROR: build $TARGET_BUILD no llegó a VALID en 20 min." >&2
  exit 1
fi

CODE=$(curl -sS -X POST \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d "{\"data\":[{\"type\":\"betaGroups\",\"id\":\"$INTERNAL_GROUP\"}]}" \
  -w "%{http_code}" -o /tmp/asc_assign.out \
  "https://api.appstoreconnect.apple.com/v1/builds/$BUILD_ID/relationships/betaGroups")

if [[ "$CODE" == "204" ]]; then
  echo "[distribute] ✓ Build $TARGET_BUILD ($BUILD_ID) asignado al grupo interno."
else
  echo "[distribute] ERROR HTTP $CODE:" >&2
  cat /tmp/asc_assign.out >&2
  exit 1
fi
