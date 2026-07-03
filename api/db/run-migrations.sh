#!/bin/bash
# =============================================================================
# Plus App - Aplicador de migraciones SQL idempotente
# =============================================================================
# Uso:
#   DATABASE_URL=postgres://user:pass@host:5432/db  ./db/run-migrations.sh
#   (o vía .env: el script carga admin-web/.env si DATABASE_URL no está seteado)
#
# Funcionamiento:
#   - Aplica todos los .sql de admin-web/db/migrations/ en orden alfabético.
#   - Usa la tabla schema_migrations (registrada por cada SQL) para skip las
#     migraciones ya aplicadas (la version es el nombre del archivo sin .sql).
#   - Cada migración corre dentro de una transacción (psql -1).
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIGRATIONS_DIR="$SCRIPT_DIR/migrations"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Cargar .env si DATABASE_URL no está definido
if [ -z "${DATABASE_URL:-}" ]; then
  if [ -f "$ROOT_DIR/.env" ]; then
    # shellcheck disable=SC1091
    set -a
    . "$ROOT_DIR/.env"
    set +a
  fi
fi

if [ -z "${DATABASE_URL:-}" ]; then
  echo "ERROR: DATABASE_URL no está definido (ni en env ni en $ROOT_DIR/.env)" >&2
  exit 1
fi

if [ ! -d "$MIGRATIONS_DIR" ]; then
  echo "ERROR: directorio $MIGRATIONS_DIR no existe" >&2
  exit 1
fi

# Asegurar que existe la tabla schema_migrations (1a migración la crea, pero
# las siguientes corridas necesitan poder consultarla antes de aplicar nada)
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<'SQL' >/dev/null
CREATE TABLE IF NOT EXISTS schema_migrations (
  version     TEXT PRIMARY KEY,
  applied_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  description TEXT
);
SQL

APPLIED=0
SKIPPED=0
FAILED=0

shopt -s nullglob
for sql_file in "$MIGRATIONS_DIR"/*.sql; do
  base=$(basename "$sql_file" .sql)

  # Check si ya está aplicada
  already=$(psql "$DATABASE_URL" -At -v ON_ERROR_STOP=1 \
    -c "SELECT 1 FROM schema_migrations WHERE version = '${base}' LIMIT 1;" 2>/dev/null || true)

  if [ "$already" = "1" ]; then
    echo "[skip ] $base (ya aplicada)"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  echo "[apply] $base ..."
  if psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -1 -f "$sql_file" >/dev/null; then
    # Asegurar registro en schema_migrations (por si el SQL no lo hizo)
    psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c \
      "INSERT INTO schema_migrations (version) VALUES ('${base}') ON CONFLICT DO NOTHING;" >/dev/null
    echo "[ ok  ] $base"
    APPLIED=$((APPLIED + 1))
  else
    echo "[FAIL] $base" >&2
    FAILED=$((FAILED + 1))
    exit 1
  fi
done

echo ""
echo "Resumen: aplicadas=$APPLIED  skipped=$SKIPPED  fallidas=$FAILED"
