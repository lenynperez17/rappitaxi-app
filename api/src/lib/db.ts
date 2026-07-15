/**
 * Rapi Team - Cliente PostgreSQL (admin-web)
 * --------------------------------------------------------------------------
 * Cliente único basado en node-postgres (Pool). Sin ORM por decisión de
 * arquitectura: queries SQL crudas + helpers tipados.
 *
 * Uso:
 *   import { query, tx, one, maybeOne } from '@/lib/db';
 *
 *   const users = await query<UserRow>('SELECT * FROM users WHERE user_type = $1', ['driver']);
 *   const u = await one<UserRow>('SELECT * FROM users WHERE id = $1', [id]);
 *
 *   await tx(async (client) => {
 *     await client.query('UPDATE wallets SET balance = balance - $1 WHERE user_id = $2', [10, id]);
 *     await client.query('INSERT INTO wallet_transactions (...) VALUES (...)', [...]);
 *   });
 *
 * Variables de entorno:
 *   DATABASE_URL=postgres://rapi_team_user:PASS@127.0.0.1:5432/rapi_team_api
 *   PG_POOL_MAX (opcional, default 20)
 *   PG_IDLE_TIMEOUT_MS (opcional, default 30000)
 *   PG_CONNECTION_TIMEOUT_MS (opcional, default 5000)
 */

import { Pool, PoolClient, type QueryResultRow } from 'pg';

// --------------------------------------------------------------------------
// Pool singleton (compatible con HMR en dev de Next.js)
// --------------------------------------------------------------------------
declare global {
  // eslint-disable-next-line no-var
  var __rapiTeamPgPool: Pool | undefined;
}

function getDatabaseUrl(): string {
  const url = process.env.DATABASE_URL;
  if (!url) {
    throw new Error(
      '[db] DATABASE_URL no está definido. Configurar en .env: ' +
        'DATABASE_URL=postgres://rapi_team_user:PASS@127.0.0.1:5432/rapi_team_api'
    );
  }
  return url;
}

function createPool(): Pool {
  const pool = new Pool({
    connectionString: getDatabaseUrl(),
    max: Number(process.env.PG_POOL_MAX ?? 20),
    idleTimeoutMillis: Number(process.env.PG_IDLE_TIMEOUT_MS ?? 30_000),
    connectionTimeoutMillis: Number(process.env.PG_CONNECTION_TIMEOUT_MS ?? 5_000),
    // No usar SSL — Postgres está en localhost del VPS, accedido vía 127.0.0.1
    ssl: false,
  });

  // Loguear errores del pool (no derribar el proceso por un cliente caído)
  pool.on('error', (err) => {
    // Cliente idle del pool falló. No abortar el server, pero registrar.
    console.error('[db] error en cliente idle del pool:', err);
  });

  return pool;
}

/**
 * Obtiene el pool (lazy). Esto es importante para Next.js: durante
 * `next build` la fase de "collect page data" importa los módulos de los
 * route handlers, y queremos que la falta de DATABASE_URL solo falle al
 * hacer una request real (runtime), no al construir.
 */
export function getPool(): Pool {
  if (!globalThis.__rapiTeamPgPool) {
    globalThis.__rapiTeamPgPool = createPool();
  }
  return globalThis.__rapiTeamPgPool;
}

/**
 * Proxy que difiere todas las llamadas al pool real. Se mantiene esta export
 * por compatibilidad con código que ya hace `import { pool } from '@/lib/db'`.
 */
export const pool = new Proxy({} as Pool, {
  get(_target, prop) {
    // Ronda 34 Bug#2: Reflect.get con receiver=real evita romper getters
    // privados de pg.Pool (totalCount, idleCount usan #privateField). Con
    // `real[prop]` el `this` era el proxy y throwaba TypeError.
    const real = getPool();
    const value = Reflect.get(real as object, prop, real);
    return typeof value === 'function' ? (value as Function).bind(real) : value;
  },
}) as Pool;

// --------------------------------------------------------------------------
// Helpers de errores
// --------------------------------------------------------------------------

/**
 * Códigos SQLSTATE más comunes de PostgreSQL que vale la pena distinguir.
 * Referencia: https://www.postgresql.org/docs/current/errcodes-appendix.html
 */
export const PG_ERROR_CODES = {
  UNIQUE_VIOLATION: '23505',
  FOREIGN_KEY_VIOLATION: '23503',
  NOT_NULL_VIOLATION: '23502',
  CHECK_VIOLATION: '23514',
  EXCLUSION_VIOLATION: '23P01',
  STRING_DATA_RIGHT_TRUNCATION: '22001',
  INVALID_TEXT_REPRESENTATION: '22P02',
  SERIALIZATION_FAILURE: '40001',
  DEADLOCK_DETECTED: '40P01',
  UNDEFINED_TABLE: '42P01',
  UNDEFINED_COLUMN: '42703',
  SYNTAX_ERROR: '42601',
} as const;

/**
 * Type guard para errores de Postgres (pg lanza objetos con propiedades
 * `code`, `detail`, `constraint`, `table`, etc.).
 */
export interface PostgresError extends Error {
  code?: string;
  detail?: string;
  hint?: string;
  position?: string;
  internalPosition?: string;
  internalQuery?: string;
  where?: string;
  schema?: string;
  table?: string;
  column?: string;
  dataType?: string;
  constraint?: string;
  file?: string;
  line?: string;
  routine?: string;
}

export function isPostgresError(err: unknown): err is PostgresError {
  return (
    typeof err === 'object' &&
    err !== null &&
    'code' in err &&
    typeof (err as { code: unknown }).code === 'string'
  );
}

export function isUniqueViolation(err: unknown): boolean {
  return isPostgresError(err) && err.code === PG_ERROR_CODES.UNIQUE_VIOLATION;
}

export function isForeignKeyViolation(err: unknown): boolean {
  return isPostgresError(err) && err.code === PG_ERROR_CODES.FOREIGN_KEY_VIOLATION;
}

export function isCheckViolation(err: unknown): boolean {
  return isPostgresError(err) && err.code === PG_ERROR_CODES.CHECK_VIOLATION;
}

// --------------------------------------------------------------------------
// query() — devuelve filas tipadas
// --------------------------------------------------------------------------

/**
 * Ejecuta una query y devuelve directamente `rows` tipados.
 * Si necesitas más metadata (rowCount, fields, etc.), usa `queryFull`.
 */
export async function query<T extends QueryResultRow = QueryResultRow>(
  text: string,
  params?: ReadonlyArray<unknown>
): Promise<T[]> {
  const result = await getPool().query<T>(text, params as unknown[] | undefined);
  return result.rows;
}

/**
 * Variante que devuelve el QueryResult completo (incluye rowCount).
 */
export async function queryFull<T extends QueryResultRow = QueryResultRow>(
  text: string,
  params?: ReadonlyArray<unknown>
) {
  return getPool().query<T>(text, params as unknown[] | undefined);
}

/**
 * Devuelve exactamente una fila o lanza error si hay 0 o >1.
 */
export async function one<T extends QueryResultRow = QueryResultRow>(
  text: string,
  params?: ReadonlyArray<unknown>
): Promise<T> {
  const rows = await query<T>(text, params);
  if (rows.length === 0) {
    throw new Error('[db] one(): la query no devolvió filas');
  }
  if (rows.length > 1) {
    throw new Error(`[db] one(): la query devolvió ${rows.length} filas (esperaba 1)`);
  }
  return rows[0]!;
}

/**
 * Devuelve la primera fila o null si no hay resultados.
 */
export async function maybeOne<T extends QueryResultRow = QueryResultRow>(
  text: string,
  params?: ReadonlyArray<unknown>
): Promise<T | null> {
  const rows = await query<T>(text, params);
  return rows[0] ?? null;
}

// --------------------------------------------------------------------------
// tx() — transacción con BEGIN/COMMIT/ROLLBACK automáticos
// --------------------------------------------------------------------------

/**
 * Ejecuta `fn` dentro de una transacción. Si `fn` lanza, hace ROLLBACK
 * y re-lanza el error. Si retorna, hace COMMIT y devuelve el valor.
 *
 * El callback recibe un PoolClient: usa `client.query(...)` dentro.
 */
export async function tx<T>(
  fn: (client: PoolClient) => Promise<T>
): Promise<T> {
  const client = await getPool().connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    try {
      await client.query('ROLLBACK');
    } catch (rollbackErr) {
      console.error('[db] error durante ROLLBACK:', rollbackErr);
    }
    throw err;
  } finally {
    client.release();
  }
}

// --------------------------------------------------------------------------
// healthCheck() — útil para endpoints /api/health
// --------------------------------------------------------------------------
export async function healthCheck(): Promise<{
  ok: boolean;
  latencyMs: number;
  serverVersion?: string;
  error?: string;
}> {
  const start = Date.now();
  try {
    const rows = await query<{ server_version: string }>(
      "SELECT current_setting('server_version') AS server_version"
    );
    return {
      ok: true,
      latencyMs: Date.now() - start,
      serverVersion: rows[0]?.server_version,
    };
  } catch (err) {
    return {
      ok: false,
      latencyMs: Date.now() - start,
      error: err instanceof Error ? err.message : String(err),
    };
  }
}

// --------------------------------------------------------------------------
// Apagado limpio (útil en scripts; Next.js no lo necesita normalmente)
// --------------------------------------------------------------------------
export async function closePool(): Promise<void> {
  if (globalThis.__rapiTeamPgPool) {
    await globalThis.__rapiTeamPgPool.end();
    globalThis.__rapiTeamPgPool = undefined;
  }
}
