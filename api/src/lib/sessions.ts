/**
 * Plus App — Session lifecycle (admin-web / VPS).
 * --------------------------------------------------------------------------
 * Gestión de sesiones de auth backeada por tabla `sessions` (PostgreSQL).
 *
 *   createSession(userId, deviceInfo)     → emite {access, refresh, sessionId}
 *   refreshSession(refreshToken)          → rota (atómico): invalida el viejo
 *                                            y emite uno nuevo
 *   revokeSession(sessionId)              → logout 1 dispositivo (idempotente)
 *   revokeAllUserSessions(userId)         → logout TODAS las sesiones activas
 *   listUserSessions(userId)              → lista dispositivos activos
 *   cleanupExpired()                      → DELETE de filas vencidas (cron)
 *
 * Modelo:
 *   - Access token = JWT HS256, TTL 1h, NO persistido (stateless). Contiene
 *     { sub, type:'access', sid, iat, exp, iss:'rapi-team' }.
 *   - Refresh token = JWT con `jti = sessions.id`, TTL 30 días. SE persiste
 *     SOLO como SHA-256 hex hash en `sessions.refresh_token_hash`.
 *     Single-use: cada call a /refresh invalida el viejo y emite uno nuevo
 *     (token rotation, defensa contra replay).
 *
 * Reglas:
 *   - rotation = transaccional (BEGIN; UPDATE revoked_at; INSERT new; COMMIT;).
 *   - Si el viejo refresh ya estaba revocado pero su sesión seguía vigente,
 *     se REVOCAN TODAS las sesiones del user — señal de robo de token.
 *   - device_info se almacena como JSONB ({ ua, ip, fingerprint }).
 *   - last_used_at se actualiza en cada rotation exitosa.
 *
 * Lo llaman:
 *   - /api/auth/session/refresh, /logout, /list (este archivo de routes).
 *   - Endpoints de login (Google OAuth, Passkeys, phone OTP) que llaman a
 *     `createSession()` después de validar la identidad del usuario.
 */

import { randomBytes } from 'node:crypto';

import { pool, query, maybeOne } from '@/lib/db';
import {
  signAccessToken,
  hashRefreshToken,
  ACCESS_TTL_SECONDS,
  REFRESH_TTL_SECONDS,
  JWT_ISSUER,
  JWT_AUDIENCE,
} from '@/lib/jwt';
import { SignJWT } from 'jose';

// --------------------------------------------------------------------------
// Tipos públicos
// --------------------------------------------------------------------------

export interface DeviceInfo {
  /** User-Agent del request (req.headers['user-agent']). */
  ua?: string | null;
  /** IP cliente (req.headers['x-forwarded-for']?.split(',')[0] ?? x-real-ip). */
  ip?: string | null;
  /** Fingerprint enviado por el cliente (header opcional 'x-fingerprint'). */
  fingerprint?: string | null;
}

export interface IssuedSession {
  /** ID interno de sesión (= jti del refresh token, = claim `sid` del access). */
  sessionId: string;
  /** Access token JWT (HS256). Devolver al cliente en cada respuesta. */
  accessToken: string;
  /** Refresh token JWT — SOLO al cliente. NUNCA loggear ni persistir plano. */
  refreshToken: string;
  /** TTL access token en segundos (informativo para el cliente). */
  accessExpiresInSec: number;
  /** Fecha de expiración del refresh token (UTC). */
  refreshExpiresAt: Date;
}

export interface SessionListItem {
  id: string;
  deviceInfo: DeviceInfo | null;
  createdAt: string; // ISO
  lastUsedAt: string; // ISO
  expiresAt: string; // ISO
}

// --------------------------------------------------------------------------
// Helpers internos
// --------------------------------------------------------------------------

/** Genera el id de sesión (= jti del refresh) — 16 bytes hex. */
function newSessionId(): string {
  return randomBytes(16).toString('hex');
}

/** Helper para obtener secret de JWT_SECRET (replica el de jwt.ts a propósito,
 *  para no exponerlo en la API pública del módulo).
 */
function getJwtSecretBytes(): Uint8Array {
  const secret = process.env.JWT_SECRET;
  if (!secret) {
    throw new Error('[sessions] JWT_SECRET no definido en .env');
  }
  if (secret.length < 32) {
    throw new Error('[sessions] JWT_SECRET demasiado corto (mín 32 chars)');
  }
  if (/^[0-9a-fA-F]+$/.test(secret) && secret.length % 2 === 0) {
    return Uint8Array.from(Buffer.from(secret, 'hex'));
  }
  return new TextEncoder().encode(secret);
}

/**
 * Firma un refresh token con `jti = sessionId`. El JWT en sí lleva firma +
 * expiración; la copia "viva" (no revocada) vive en `sessions`.
 */
async function signRefreshJwt(userId: string, sessionId: string): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  return await new SignJWT({ type: 'refresh' })
    .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
    .setSubject(userId)
    .setIssuer(JWT_ISSUER)
    .setAudience(JWT_AUDIENCE)
    .setJti(sessionId)
    .setIssuedAt(now)
    .setExpirationTime(now + REFRESH_TTL_SECONDS)
    .sign(getJwtSecretBytes());
}

/**
 * Decodifica un refresh JWT SIN verificarlo (solo necesitamos el jti). La
 * verificación real es por hash en DB (más estricta y revocable).
 */
function peekJti(refreshToken: string): string | null {
  const parts = refreshToken.split('.');
  if (parts.length !== 3) return null;
  try {
    const json = Buffer.from(parts[1]!, 'base64url').toString('utf8');
    const payload = JSON.parse(json) as { jti?: unknown };
    return typeof payload.jti === 'string' ? payload.jti : null;
  } catch {
    return null;
  }
}

// --------------------------------------------------------------------------
// createSession
// --------------------------------------------------------------------------

/**
 * Crea una nueva sesión para `userId` y emite (access, refresh).
 *
 * La llaman los endpoints de login (Google OAuth callback, Passkeys verify,
 * phone OTP verify) después de validar la identidad del usuario.
 *
 * Si `userId` no existe en `users`, lanza error (FK ON DELETE CASCADE).
 */
export async function createSession(
  userId: string,
  deviceInfo: DeviceInfo = {},
): Promise<IssuedSession> {
  if (!userId || typeof userId !== 'string') {
    throw new Error('[sessions] createSession: userId requerido');
  }

  const sessionId = newSessionId();
  const refreshToken = await signRefreshJwt(userId, sessionId);
  const accessToken = await signAccessToken(userId, sessionId);
  const refreshExpiresAt = new Date(Date.now() + REFRESH_TTL_SECONDS * 1000);

  await query(
    `INSERT INTO sessions
       (id, user_id, refresh_token_hash, expires_at, device_info,
        created_at, last_used_at, revoked_at, replaced_by_session_id)
     VALUES ($1, $2, $3, $4, $5::jsonb, now(), now(), NULL, NULL)`,
    [
      sessionId,
      userId,
      hashRefreshToken(refreshToken),
      refreshExpiresAt.toISOString(),
      JSON.stringify(deviceInfo ?? {}),
    ],
  );

  return {
    sessionId,
    accessToken,
    refreshToken,
    accessExpiresInSec: ACCESS_TTL_SECONDS,
    refreshExpiresAt,
  };
}

// --------------------------------------------------------------------------
// refreshSession (rotation)
// --------------------------------------------------------------------------

export class InvalidRefreshError extends Error {
  code: 'invalid_refresh' | 'reuse_detected';
  constructor(code: 'invalid_refresh' | 'reuse_detected', message?: string) {
    super(message ?? code);
    this.code = code;
    this.name = 'InvalidRefreshError';
  }
}

/**
 * Rota un refresh token: invalida el viejo y emite uno nuevo. Atómico
 * (BEGIN; UPDATE; INSERT; COMMIT).
 *
 * Detección de reuse: si el refresh recibido coincide con una sesión REVOCADA
 * (revoked_at IS NOT NULL), se revocan TODAS las sesiones del user — señal
 * de que el token fue robado y reusado.
 */
export async function refreshSession(
  refreshToken: string,
  deviceInfo: DeviceInfo = {},
): Promise<IssuedSession> {
  if (!refreshToken || typeof refreshToken !== 'string') {
    throw new InvalidRefreshError('invalid_refresh', 'empty token');
  }

  const tokenHash = hashRefreshToken(refreshToken);
  // El jti embebido sirve sólo como hint; el match real es por hash.
  const hintedJti = peekJti(refreshToken);
  void hintedJti;

  // Manejo manual de transacción: en el caso `reuse_detected` necesitamos
  // COMMIT del revoke-all ANTES de tirar, para que la revocación persista.
  // Si usáramos el wrapper tx() (que hace ROLLBACK al lanzar), perderíamos
  // la revocación masiva.
  const client = await pool.connect();
  let committed = false;
  try {
    await client.query('BEGIN');

    // 1. Buscar la sesión por hash (FOR UPDATE para evitar carrera).
    const found = await client.query<{
      id: string;
      user_id: string;
      expires_at: string;
      revoked_at: string | null;
      replaced_by_session_id: string | null;
    }>(
      `SELECT id, user_id, expires_at, revoked_at, replaced_by_session_id
         FROM sessions
        WHERE refresh_token_hash = $1
        FOR UPDATE`,
      [tokenHash],
    );

    const row = found.rows[0];
    if (!row) {
      throw new InvalidRefreshError('invalid_refresh', 'unknown refresh');
    }

    // 2. Sesión revocada → reuse detection. Revocar TODAS las del user
    //    Y COMMIT antes de tirar para que la revocación masiva persista.
    if (row.revoked_at) {
      await client.query(
        `UPDATE sessions
            SET revoked_at = now()
          WHERE user_id = $1 AND revoked_at IS NULL`,
        [row.user_id],
      );
      await client.query('COMMIT');
      committed = true;
      throw new InvalidRefreshError(
        'reuse_detected',
        `reuse of revoked refresh token (sid=${row.id})`,
      );
    }

    // 3. Sesión expirada.
    if (new Date(row.expires_at).getTime() <= Date.now()) {
      throw new InvalidRefreshError('invalid_refresh', 'refresh expired');
    }

    // 4. Emitir nueva sesión.
    const newSid = newSessionId();
    const newRefresh = await signRefreshJwt(row.user_id, newSid);
    const newAccess = await signAccessToken(row.user_id, newSid);
    const newRefreshExpiresAt = new Date(Date.now() + REFRESH_TTL_SECONDS * 1000);

    await client.query(
      `INSERT INTO sessions
         (id, user_id, refresh_token_hash, expires_at, device_info,
          created_at, last_used_at, revoked_at, replaced_by_session_id)
       VALUES ($1, $2, $3, $4, $5::jsonb, now(), now(), NULL, NULL)`,
      [
        newSid,
        row.user_id,
        hashRefreshToken(newRefresh),
        newRefreshExpiresAt.toISOString(),
        JSON.stringify(deviceInfo ?? {}),
      ],
    );

    // 5. Revocar la vieja y enlazar a la nueva (auditoría).
    await client.query(
      `UPDATE sessions
          SET revoked_at = now(),
              replaced_by_session_id = $1
        WHERE id = $2`,
      [newSid, row.id],
    );

    await client.query('COMMIT');
    committed = true;

    return {
      sessionId: newSid,
      accessToken: newAccess,
      refreshToken: newRefresh,
      accessExpiresInSec: ACCESS_TTL_SECONDS,
      refreshExpiresAt: newRefreshExpiresAt,
    } satisfies IssuedSession;
  } catch (err) {
    if (!committed) {
      try {
        await client.query('ROLLBACK');
      } catch (rollbackErr) {
        console.error('[sessions] ROLLBACK error:', rollbackErr);
      }
    }
    throw err;
  } finally {
    client.release();
  }
}

// --------------------------------------------------------------------------
// revokeSession / revokeAllUserSessions
// --------------------------------------------------------------------------

/**
 * Logout de UNA sesión. Idempotente — si ya está revocada, no hace nada.
 * Devuelve true si la sesión existía (y se acaba de revocar o ya estaba
 * revocada), false si el id no existía.
 */
export async function revokeSession(sessionId: string): Promise<boolean> {
  if (!sessionId) return false;
  const row = await maybeOne<{ id: string }>(
    `UPDATE sessions
        SET revoked_at = COALESCE(revoked_at, now())
      WHERE id = $1
      RETURNING id`,
    [sessionId],
  );
  return !!row;
}

/**
 * Logout de TODAS las sesiones activas de un usuario.
 * Devuelve cuántas filas se revocaron en esta llamada.
 */
export async function revokeAllUserSessions(userId: string): Promise<number> {
  const rows = await query<{ id: string }>(
    `UPDATE sessions
        SET revoked_at = now()
      WHERE user_id = $1
        AND revoked_at IS NULL
      RETURNING id`,
    [userId],
  );
  return rows.length;
}

// --------------------------------------------------------------------------
// listUserSessions
// --------------------------------------------------------------------------

/**
 * Lista las sesiones activas (no revocadas, no vencidas) de un usuario.
 * Ordenadas por last_used_at DESC (la sesión "más reciente" primero).
 */
export async function listUserSessions(userId: string): Promise<SessionListItem[]> {
  const rows = await query<{
    id: string;
    device_info: DeviceInfo | null;
    created_at: string | Date;
    last_used_at: string | Date;
    expires_at: string | Date;
  }>(
    `SELECT id, device_info, created_at, last_used_at, expires_at
       FROM sessions
      WHERE user_id = $1
        AND revoked_at IS NULL
        AND expires_at > now()
      ORDER BY last_used_at DESC`,
    [userId],
  );

  return rows.map((r) => ({
    id: r.id,
    deviceInfo: r.device_info ?? null,
    createdAt: new Date(r.created_at).toISOString(),
    lastUsedAt: new Date(r.last_used_at).toISOString(),
    expiresAt: new Date(r.expires_at).toISOString(),
  }));
}

// --------------------------------------------------------------------------
// touchSession — actualiza last_used_at (llamado opcionalmente por middleware)
// --------------------------------------------------------------------------

/**
 * Actualiza last_used_at de una sesión. Best-effort, no lanza si falla.
 * Útil para que la lista de dispositivos refleje la actividad real.
 */
export async function touchSession(sessionId: string): Promise<void> {
  if (!sessionId) return;
  try {
    await query(
      `UPDATE sessions SET last_used_at = now() WHERE id = $1`,
      [sessionId],
    );
  } catch (err) {
    console.warn('[sessions] touchSession warn:', err);
  }
}

// --------------------------------------------------------------------------
// cleanupExpired — corre desde cron (worker VPS, daily 03:00)
// --------------------------------------------------------------------------

/**
 * DELETE de sesiones vencidas o revocadas hace > 7 días. Se ejecuta desde
 * el worker (node-cron) en /var/www/Plus-App/worker — daily 03:00.
 *
 * Devuelve cuántas filas se borraron.
 */
export async function cleanupExpired(): Promise<number> {
  const rows = await query<{ id: string }>(
    `DELETE FROM sessions
      WHERE expires_at < now()
         OR (revoked_at IS NOT NULL AND revoked_at < now() - interval '7 days')
      RETURNING id`,
  );
  return rows.length;
}

// --------------------------------------------------------------------------
// Helpers para los routes — extraer deviceInfo de la request
// --------------------------------------------------------------------------

/**
 * Extrae { ua, ip, fingerprint } desde headers de la Request.
 */
export function deviceInfoFromHeaders(headers: Headers): DeviceInfo {
  const ua = headers.get('user-agent');
  const xff = headers.get('x-forwarded-for');
  const ip = xff?.split(',')[0]?.trim() ?? headers.get('x-real-ip');
  const fingerprint = headers.get('x-fingerprint');
  return {
    ua: ua ?? null,
    ip: ip ?? null,
    fingerprint: fingerprint ?? null,
  };
}
