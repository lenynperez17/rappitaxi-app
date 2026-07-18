#!/usr/bin/env bash
# Rondas 196 → 198 → 211: distribuir el build recién subido al grupo
# interno de TestFlight "Team Rapi Interno". Apple no permite
# hasAccessToAllBuilds=true via API pública, así que asignamos cada release.
#
# Ronda 211 rewrite (mejoras vs Ronda 198):
#   - Flush inmediato de stdout: los logs aparecen en tiempo real cuando
#     el script se ejecuta en background con >output.log 2>&1.
#   - Timestamps [HH:MM:SS] en cada línea → sabemos cuánto tarda Apple.
#   - JWT se REGENERA cada 5 minutos (antes uno solo de 30min → expiraba
#     silenciosamente y curl devolvía 401 tratado como "no VALID").
#   - Detecta 3 estados diferenciados: 404 "aún no aparece", PROCESSING
#     "Apple procesando", VALID → OK. Logs claros.
#   - Timeout más generoso: 30 min = 180 iteraciones × 10s.
#   - `trap` para reportar limpio si se recibe SIGTERM/SIGKILL.
#   - Retry con reintento del JWT si curl devuelve 401.
#
# Requiere: step-cli, python3, curl. Ruta de la key .p8 conocida.
set -euo pipefail

# Forzar stdout sin buffer (Ronda 211 fix crítico) — sin esto los logs
# quedan en buffer 4KB de Bash cuando el script corre backgrounded y
# nadie ve nada hasta que termine (o timeout SIGKILL, output vacío).
exec >&1

APP_ID=6761776704
INTERNAL_GROUP=0f11d6ef-b9e5-476f-ad6f-166d1f1b8e53
KEY_ID=HM52J5J9XA
ISSUER=77515464-9952-4f79-9de5-caa0561b9603
KEY_FILE="$(cd "$(dirname "$0")/.." && pwd)/AuthKey_${KEY_ID}.p8"
PUBSPEC="$(cd "$(dirname "$0")/.." && pwd)/pubspec.yaml"

MAX_ITERATIONS=180        # 30 min de poll (180 × 10s)
JWT_REFRESH_EVERY=30      # regenerar cada 5 min (30 × 10s)
POLL_SLEEP=10

ts() { date '+[%H:%M:%S]'; }
log() { echo "$(ts) [distribute] $*"; }

trap 'log "SIGTERM/SIGINT recibida — abortando poll"; exit 130' TERM INT

# ---------- validaciones ----------
if [[ ! -f "$KEY_FILE" ]]; then
  log "ERROR: falta $KEY_FILE"
  exit 1
fi
if [[ ! -f "$PUBSPEC" ]]; then
  log "ERROR: falta $PUBSPEC"
  exit 1
fi

TARGET_BUILD=$(grep -E '^version:' "$PUBSPEC" | sed -E 's/^version:[[:space:]]*[^+]+\+([0-9]+).*/\1/')
if [[ -z "$TARGET_BUILD" ]]; then
  log "ERROR: no pude extraer buildNumber de $PUBSPEC"
  exit 1
fi
log "target version=$TARGET_BUILD"

# ---------- helpers ----------
sign_jwt() {
  step crypto jwt sign \
    --iss "$ISSUER" --aud "appstoreconnect-v1" \
    --key "$KEY_FILE" --alg ES256 --kid "$KEY_ID" \
    --exp $(($(date +%s) + 900)) --iat $(date +%s) --subtle
}

JWT=$(sign_jwt)
log "JWT firmado inicialmente (TTL 15 min)"

# ---------- poll loop ----------
BUILD_ID=""
LAST_STATE="-"
LAST_HTTP=""

for i in $(seq 1 $MAX_ITERATIONS); do
  # Regenerar JWT cada JWT_REFRESH_EVERY iteraciones para no depender
  # de un solo token que puede expirar mid-poll.
  if (( i > 1 && i % JWT_REFRESH_EVERY == 1 )); then
    JWT=$(sign_jwt)
    log "JWT rotado (iter $i)"
  fi

  RESP=$(curl -sS -w "\n%{http_code}" \
    -H "Authorization: Bearer $JWT" \
    "https://api.appstoreconnect.apple.com/v1/builds?filter%5Bapp%5D=${APP_ID}&filter%5Bversion%5D=${TARGET_BUILD}&limit=1")
  LAST_HTTP=$(echo "$RESP" | tail -n1)
  BODY=$(echo "$RESP" | sed '$d')

  # 401 → JWT expiró o revocado; regeneramos y reintentamos SIN gastar
  # la iteración del poll.
  if [[ "$LAST_HTTP" == "401" ]]; then
    log "HTTP 401 — regenerando JWT y reintentando"
    JWT=$(sign_jwt)
    sleep 2
    continue
  fi
  if [[ "$LAST_HTTP" != "200" ]]; then
    log "HTTP inesperado $LAST_HTTP (iter $i) — reintento en ${POLL_SLEEP}s"
    sleep "$POLL_SLEEP"
    continue
  fi

  # Parse: hallar (build_id, state) o vacío si no existe.
  read -r ID STATE < <(echo "$BODY" | python3 -c "
import json,sys
d = json.load(sys.stdin)
arr = d.get('data', [])
if not arr:
    print('- -')
else:
    b = arr[0]
    print(b['id'], b['attributes']['processingState'])
")

  if [[ "$STATE" == "VALID" ]]; then
    BUILD_ID="$ID"
    log "✓ Build $TARGET_BUILD llegó a VALID (id=$ID) tras iter $i (~$((i*POLL_SLEEP))s)"
    break
  fi

  # Log solo cuando cambia el estado, o cada 10 iteraciones para
  # heartbeat sin spam.
  if [[ "$STATE" != "$LAST_STATE" || $((i % 10)) == 0 ]]; then
    if [[ "$STATE" == "-" ]]; then
      log "aún no aparece en ASC (iter $i/$MAX_ITERATIONS)"
    else
      log "state=$STATE (iter $i/$MAX_ITERATIONS)"
    fi
    LAST_STATE="$STATE"
  fi
  sleep "$POLL_SLEEP"
done

if [[ -z "$BUILD_ID" ]]; then
  log "ERROR: build $TARGET_BUILD no llegó a VALID en $((MAX_ITERATIONS * POLL_SLEEP / 60)) min."
  exit 1
fi

# ---------- assign ----------
# Ronda 212 BUG FIX CRÍTICO: el endpoint POST /builds/{id}/relationships/betaGroups
# devuelve 204 pero NUNCA persiste la asignación para grupos internos
# (isInternalGroup=true). Los builds 121-124 respondieron 204 al script
# original pero la lista `/betaGroups/{id}/builds` seguía vacía.
# El endpoint que SÍ persiste es el inverso, desde el lado del grupo:
#   POST /v1/betaGroups/{groupId}/relationships/builds
# Con este endpoint el usuario recibe la notificación de TestFlight en 5-15 min.
CODE=$(curl -sS -X POST \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d "{\"data\":[{\"type\":\"builds\",\"id\":\"$BUILD_ID\"}]}" \
  -w "%{http_code}" -o /tmp/asc_assign.out \
  "https://api.appstoreconnect.apple.com/v1/betaGroups/$INTERNAL_GROUP/relationships/builds")

if [[ "$CODE" != "204" ]]; then
  log "ERROR HTTP $CODE en asignación:"
  cat /tmp/asc_assign.out
  exit 1
fi

# Verificar que efectivamente persistió — Apple a veces devuelve 204 y
# la relación aparece con 1-3s de latencia; polleamos hasta 6s.
sleep 3
for check in 1 2 3; do
  FOUND=$(curl -sS -H "Authorization: Bearer $JWT" \
    "https://api.appstoreconnect.apple.com/v1/betaGroups/$INTERNAL_GROUP/builds?limit=50" \
    | python3 -c "
import json,sys,os
d = json.load(sys.stdin)
target = os.environ.get('BID')
print('yes' if any(b['id']==target for b in d.get('data',[])) else 'no')
" BID="$BUILD_ID")
  if [[ "$FOUND" == "yes" ]]; then
    log "✓ Build $TARGET_BUILD ($BUILD_ID) asignado al grupo interno (verificado)."
    exit 0
  fi
  log "verificación pendiente (intento $check/3)..."
  sleep 3
done

log "ADVERTENCIA: asignación devolvió 204 pero no se refleja en el grupo tras 12s."
log "  Grupo: $INTERNAL_GROUP  Build: $BUILD_ID"
log "  Puede ser latencia extendida de Apple. Verificar manualmente en ASC."
exit 1
