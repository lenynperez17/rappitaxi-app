/**
 * Rapi Team - Emisión y verificación de JWT propios (sin Firebase Auth)
 * --------------------------------------------------------------------------
 * Usamos `jose` (https://github.com/panva/jose) por ser activamente mantenida,
 * compatible con Web Crypto y mucho más segura que `jsonwebtoken`.
 *
 * Diseño:
 *   - Access token  → JWT HS256, TTL 1h. Stateless. Payload:
 *       { sub: userId, sid: sessionId, type: 'access', iat, exp, iss: 'rapi-team' }
 *   - Refresh token → JWT HS256, TTL 30d, `jti = sessions.id`. Su firma se
 *     valida + se busca el SHA-256 hex hash en la tabla `sessions`.
 *     La emisión y rotación viven en `@/lib/sessions`.
 *
 * Helpers CSRF/state para OAuth:
 *   - issueOauthState(extra, ttlMs) → state firmado con HMAC-SHA256
 *   - verifyOauthState(state)       → valida firma + ttl
 *
 * Variables de entorno:
 *   JWT_SECRET   — hex de 64+ chars (generar con crypto.randomBytes(64))
 */

import { SignJWT, jwtVerify, decodeJwt, type JWTPayload } from 'jose';
import { createHash, createHmac, randomBytes, timingSafeEqual } from 'node:crypto';

// --------------------------------------------------------------------------
// Constantes públicas
// --------------------------------------------------------------------------
/** TTL del access token en segundos (1 hora). */
export const ACCESS_TTL_SECONDS = 60 * 60;
/** TTL del refresh token en segundos (30 días). */
export const REFRESH_TTL_SECONDS = 60 * 60 * 24 * 30;
/** Issuer estándar de los JWT emitidos por este proyecto. */
export const JWT_ISSUER = 'rapi-team';
/** Audience estándar (cliente Flutter + admin-web). */
export const JWT_AUDIENCE = 'rapi-team-clients';

// --------------------------------------------------------------------------
// Secret helper
// --------------------------------------------------------------------------
function getJwtSecretBytes(): Uint8Array {
  const secret = process.env.JWT_SECRET;
  if (!secret) {
    throw new Error(
      '[jwt] JWT_SECRET no definido. Generar con: ' +
        "node -e \"console.log(require('crypto').randomBytes(64).toString('hex'))\""
    );
  }
  if (secret.length < 32) {
    throw new Error(
      `[jwt] JWT_SECRET demasiado corto (${secret.length} chars). Mínimo 32.`
    );
  }
  if (/^[0-9a-fA-F]+$/.test(secret) && secret.length % 2 === 0) {
    return Uint8Array.from(Buffer.from(secret, 'hex'));
  }
  return new TextEncoder().encode(secret);
}

// --------------------------------------------------------------------------
// Tipos públicos
// --------------------------------------------------------------------------
export type UserType = 'passenger' | 'driver' | 'admin';

export interface AccessTokenClaims extends JWTPayload {
  /** user id (users.id) */
  sub: string;
  /** session id (sessions.id) */
  sid: string;
  /** marca tipo de token para que un refresh nunca pase como access */
  type: 'access';
}

// --------------------------------------------------------------------------
// Access token
// --------------------------------------------------------------------------
/**
 * Emite un access token (HS256, 1h). El claim `sid` referencia la fila en
 * `sessions` y permite revocar la sesión sin esperar a que expire el JWT.
 */
export async function signAccessToken(
  userId: string,
  sessionId: string
): Promise<string> {
  if (!userId) throw new Error('[jwt] signAccessToken: userId requerido');
  if (!sessionId) throw new Error('[jwt] signAccessToken: sessionId requerido');
  const now = Math.floor(Date.now() / 1000);
  return await new SignJWT({ sid: sessionId, type: 'access' })
    .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
    .setSubject(userId)
    .setIssuer(JWT_ISSUER)
    .setAudience(JWT_AUDIENCE)
    .setIssuedAt(now)
    .setExpirationTime(now + ACCESS_TTL_SECONDS)
    .sign(getJwtSecretBytes());
}

/**
 * Verifica un access token. Devuelve los claims si es válido, `null` si no.
 *
 * (Convencionalmente devuelve null en vez de tirar para que los callers puedan
 *  hacer `if (!claims) return 401` sin try/catch — la mayoría de routes así lo
 *  usan. El middleware-bearer.ts envuelve en try/catch igualmente.)
 */
export async function verifyAccessToken(
  token: string
): Promise<AccessTokenClaims | null> {
  if (!token || typeof token !== 'string') return null;
  try {
    const { payload } = await jwtVerify(token, getJwtSecretBytes(), {
      issuer: JWT_ISSUER,
      audience: JWT_AUDIENCE,
      algorithms: ['HS256'],
    });
    const sub = typeof payload.sub === 'string' ? payload.sub : null;
    const sid = typeof payload.sid === 'string' ? payload.sid : null;
    const type = payload.type;
    if (!sub || !sid) return null;
    if (type !== 'access') return null;
    return payload as AccessTokenClaims;
  } catch {
    return null;
  }
}

/**
 * Lee el `iss` de un JWT sin verificar la firma. Útil para enrutar entre
 * "JWT propio" y "Firebase ID token" en `middleware-bearer.ts`.
 */
export function peekIssuer(token: string): string | null {
  if (!token || typeof token !== 'string') return null;
  try {
    const payload = decodeJwt(token);
    return typeof payload.iss === 'string' ? payload.iss : null;
  } catch {
    return null;
  }
}

// --------------------------------------------------------------------------
// Refresh token helpers
// --------------------------------------------------------------------------
/**
 * Hash SHA-256 hex del refresh token. Guardamos SOLO el hash en la tabla
 * `sessions.refresh_token_hash` por si esa tabla se filtra alguna vez.
 */
export function hashRefreshToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

// --------------------------------------------------------------------------
// State CSRF para OAuth (Google / etc.)
// --------------------------------------------------------------------------
/**
 * Genera un state firmado con HMAC-SHA256(secret) + timestamp.
 * Formato base64url(<ts>.<nonce>.<extra>.<ttlMs>.<hmacHex>).
 * Permite preservar pequeños metadatos (ej. `mode=json|deeplink`) sin DB.
 */
// Ronda 35 Bug#2: encodeURIComponent NO codifica '.', ni '~', ni "'". Si el
// caller pasa `extra` con puntos (redirect="app.rapi.team/x"), el split por
// '.' explota. Escapamos '.' → '%2E' manualmente antes del join.
function encodeStatePart(s: string): string {
  return encodeURIComponent(s).replace(/\./g, '%2E');
}
function decodeStatePart(s: string): string {
  return decodeURIComponent(s);
}

// Ronda 121: helper compartido para validar longitud del secret. Antes las
// funciones de state CSRF saltaban el chequeo `secret.length >= 32` de
// getJwtSecretBytes y aceptaban claves cortas → brute-force offline factible.
function getOauthSecret(): string {
  const secret = process.env.JWT_SECRET;
  if (!secret) throw new Error('[jwt] JWT_SECRET no definido para state CSRF');
  if (secret.length < 32) {
    throw new Error(`[jwt] JWT_SECRET demasiado corto (${secret.length} chars). Mínimo 32.`);
  }
  return secret;
}

export function issueOauthState(
  extra: Record<string, string> = {},
  ttlMs = 10 * 60 * 1000
): string {
  const secret = getOauthSecret();
  const ts = Date.now().toString();
  const nonce = randomBytes(12).toString('hex');
  const extraStr = Object.entries(extra)
    .map(([k, v]) => `${encodeStatePart(k)}=${encodeStatePart(v)}`)
    .join('&');
  const base = `${ts}.${nonce}.${extraStr}.${ttlMs}`;
  // Ronda 35 Bug#1: HMAC real, no SHA-256(base|secret) — este último es
  // vulnerable a length-extension. HMAC-SHA256 es el estándar.
  const hmac = createHmac('sha256', secret).update(base).digest('hex');
  return Buffer.from(`${base}.${hmac}`, 'utf8').toString('base64url');
}

export type OauthStateCheck =
  | { ok: true; extra: Record<string, string> }
  | { ok: false; reason: string };

export function verifyOauthState(state: string): OauthStateCheck {
  let secret: string;
  try {
    secret = getOauthSecret();
  } catch {
    // Simetría con issueOauthState — misma validación de longitud (Ronda 121)
    return { ok: false, reason: 'no_secret' };
  }
  if (!state) return { ok: false, reason: 'missing' };
  let decoded: string;
  try {
    decoded = Buffer.from(state, 'base64url').toString('utf8');
  } catch {
    return { ok: false, reason: 'malformed' };
  }
  const parts = decoded.split('.');
  if (parts.length !== 5) return { ok: false, reason: 'malformed' };
  const [ts, nonce, extraStr, ttlMs, hmac] = parts as [
    string,
    string,
    string,
    string,
    string,
  ];
  const base = `${ts}.${nonce}.${extraStr}.${ttlMs}`;
  const expected = createHmac('sha256', secret).update(base).digest('hex');
  // Ronda 35: timingSafeEqual para evitar timing attacks
  try {
    const a = Buffer.from(expected, 'hex');
    const b = Buffer.from(hmac, 'hex');
    if (a.length !== b.length || !timingSafeEqual(a, b)) {
      return { ok: false, reason: 'bad_signature' };
    }
  } catch {
    return { ok: false, reason: 'bad_signature' };
  }
  const issuedAt = Number(ts);
  const ttl = Number(ttlMs);
  if (!Number.isFinite(issuedAt) || !Number.isFinite(ttl)) {
    return { ok: false, reason: 'malformed' };
  }
  if (Date.now() - issuedAt > ttl) return { ok: false, reason: 'expired' };
  const extra: Record<string, string> = {};
  if (extraStr) {
    for (const pair of extraStr.split('&')) {
      if (!pair) continue;
      const [k, v = ''] = pair.split('=');
      extra[decodeStatePart(k!)] = decodeStatePart(v);
    }
  }
  void nonce; // silenciar lint: existe para hacer el state único
  return { ok: true, extra };
}
