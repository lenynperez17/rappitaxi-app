/**
 * Rapi Team - Wrapper Passkeys (WebAuthn / FIDO2)
 * --------------------------------------------------------------------------
 * Wrapper sobre `@simplewebauthn/server` v13+. Maneja:
 *   - Generación de opciones (registration / authentication)
 *   - Persistencia de challenges en `webauthn_challenges` (TTL 5min)
 *   - Persistencia / lookup de credenciales en `passkey_credentials`
 *   - Verificación de respuestas y actualización del counter
 *
 * Configuración:
 *   RP_ID         = rapi-team-admin.nynelmkt.cloud
 *   RP_NAME       = "Plus App"
 *   ORIGIN        = https://rapi-team-admin.nynelmkt.cloud
 *   attestation   = 'none' (no requerir cert hardware)
 *   userVerif.    = 'preferred'  (Touch/Face ID si está disponible, no obligatorio)
 *
 * Variables de entorno (opcionales — override de defaults):
 *   WEBAUTHN_RP_ID        — RP ID (dominio) por defecto rapi-team-admin.nynelmkt.cloud
 *   WEBAUTHN_RP_NAME      — nombre amigable (default 'Plus App')
 *   WEBAUTHN_ORIGIN       — origen esperado (default https://{RP_ID})
 *   WEBAUTHN_CHALLENGE_TTL_SEC — TTL del challenge (default 300 = 5min)
 */

import { randomBytes } from 'node:crypto';
import {
  generateRegistrationOptions,
  verifyRegistrationResponse,
  generateAuthenticationOptions,
  verifyAuthenticationResponse,
  type VerifiedRegistrationResponse,
  type VerifiedAuthenticationResponse,
} from '@simplewebauthn/server';
import type {
  PublicKeyCredentialCreationOptionsJSON,
  PublicKeyCredentialRequestOptionsJSON,
  RegistrationResponseJSON,
  AuthenticationResponseJSON,
  AuthenticatorTransportFuture,
  CredentialDeviceType,
} from '@simplewebauthn/server';

import { maybeOne, query, queryFull, tx } from '@/lib/db';

// --------------------------------------------------------------------------
// Config
// --------------------------------------------------------------------------
export const RP_ID = process.env.WEBAUTHN_RP_ID ?? 'rapi-team-admin.nynelmkt.cloud';
export const RP_NAME = process.env.WEBAUTHN_RP_NAME ?? 'Plus App';
export const EXPECTED_ORIGIN =
  process.env.WEBAUTHN_ORIGIN ?? `https://${RP_ID}`;
const CHALLENGE_TTL_SEC = Number(
  process.env.WEBAUTHN_CHALLENGE_TTL_SEC ?? 300
);

// --------------------------------------------------------------------------
// Tipos
// --------------------------------------------------------------------------
export interface RegisterUser {
  id: string;
  email?: string | null;
  displayName?: string | null;
}

export interface StoredPasskey {
  id: string;
  user_id: string;
  credential_id: Buffer;
  public_key: Buffer;
  counter: string | number; // BIGINT se serializa como string por pg
  transports: string[] | null;
  device_type: 'singleDevice' | 'multiDevice' | null;
  backed_up: boolean | null;
  nickname: string | null;
  last_used_at: Date | null;
  created_at: Date;
}

// --------------------------------------------------------------------------
// Helpers internos
// --------------------------------------------------------------------------

/** Devuelve el ID interno random (32 hex chars). */
function newCredentialRowId(): string {
  return randomBytes(16).toString('hex');
}

/** Convierte Base64URL → Buffer (Node). */
function base64urlToBuffer(b64url: string): Buffer {
  // jose y simplewebauthn devuelven base64url sin padding.
  return Buffer.from(b64url, 'base64url');
}

/** Convierte Buffer → Base64URL. */
function bufferToBase64url(buf: Buffer): string {
  return buf.toString('base64url');
}

/**
 * Inserta un challenge nuevo y lo devuelve. Si por colisión cósmica ya
 * existe, reintenta una vez con otro challenge.
 */
async function storeChallenge(
  challenge: string,
  userId: string | null,
  purpose: 'registration' | 'authentication'
): Promise<void> {
  const expiresAt = new Date(Date.now() + CHALLENGE_TTL_SEC * 1000);
  await query(
    `INSERT INTO webauthn_challenges (challenge, user_id, purpose, expires_at)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (challenge) DO UPDATE
       SET user_id = EXCLUDED.user_id,
           purpose = EXCLUDED.purpose,
           expires_at = EXCLUDED.expires_at`,
    [challenge, userId, purpose, expiresAt.toISOString()]
  );
}

/**
 * Consume un challenge (one-shot): lo lee, valida no-expiración y lo borra.
 * Devuelve la fila o null si no existe / expiró.
 */
async function consumeChallenge(
  challenge: string,
  purpose: 'registration' | 'authentication'
): Promise<{ user_id: string | null } | null> {
  // DELETE ... RETURNING atómico (un challenge no se puede usar 2x).
  // Ronda 59 Bug#1: incluir purpose en WHERE para evitar que un flujo
  // ajeno queme el challenge del otro. Antes: registration challenge
  // podía ser deleted por authentication endpoint, forzando al user
  // a reiniciar enrollment.
  const row = await maybeOne<{
    user_id: string | null;
    expires_at: Date;
    purpose: string;
  }>(
    `DELETE FROM webauthn_challenges
      WHERE challenge = $1 AND purpose = $2
      RETURNING user_id, expires_at, purpose`,
    [challenge, purpose]
  );
  if (!row) return null;
  if (new Date(row.expires_at).getTime() < Date.now()) return null;
  return { user_id: row.user_id };
}

// --------------------------------------------------------------------------
// REGISTRATION
// --------------------------------------------------------------------------

/**
 * Devuelve PublicKeyCredentialCreationOptionsJSON para enviar al cliente.
 * El cliente llama navigator.credentials.create({ publicKey: options }).
 *
 * El challenge se persiste en `webauthn_challenges` con TTL 5min.
 */
export async function generateRegistration(
  user: RegisterUser
): Promise<PublicKeyCredentialCreationOptionsJSON> {
  // Excluir credenciales ya registradas para que el browser no permita duplicar
  const existing = await query<{ credential_id: Buffer; transports: string[] | null }>(
    `SELECT credential_id, transports
       FROM passkey_credentials
      WHERE user_id = $1`,
    [user.id]
  );

  const excludeCredentials = existing.map((c) => ({
    id: bufferToBase64url(c.credential_id),
    transports: (c.transports ?? undefined) as
      | AuthenticatorTransportFuture[]
      | undefined,
  }));

  const options = await generateRegistrationOptions({
    rpName: RP_NAME,
    rpID: RP_ID,
    userID: new TextEncoder().encode(user.id),
    userName: user.email ?? user.id,
    userDisplayName: user.displayName ?? user.email ?? user.id,
    attestationType: 'none',
    authenticatorSelection: {
      residentKey: 'preferred',
      userVerification: 'preferred',
    },
    excludeCredentials,
    // Algoritmos por defecto (-8 EdDSA, -7 ES256, -257 RS256). OK para el 99% de autenticadores.
  });

  await storeChallenge(options.challenge, user.id, 'registration');
  return options;
}

/**
 * Verifica la respuesta del autenticador y guarda la credencial en DB.
 * `expectedChallenge` opcional: si no se provee, se busca por `response.response.clientDataJSON`
 * decodificando — pero pedimos siempre que el caller lo pase explícitamente desde la sesión/storage.
 *
 * Devuelve la credencial recién creada (o lanza error si la verificación falla).
 */
export async function verifyRegistration(opts: {
  userId: string;
  response: RegistrationResponseJSON;
  expectedChallenge: string;
  nickname?: string | null;
}): Promise<{
  id: string;
  credentialId: string;
  deviceType: CredentialDeviceType;
  backedUp: boolean;
}> {
  // Consumir el challenge (atomic delete). Si no existe → 400.
  const consumed = await consumeChallenge(opts.expectedChallenge, 'registration');
  if (!consumed) {
    throw new PasskeyError('CHALLENGE_INVALID', 'Challenge inválido o expirado');
  }
  if (consumed.user_id !== opts.userId) {
    throw new PasskeyError(
      'CHALLENGE_USER_MISMATCH',
      'El challenge no pertenece a este usuario'
    );
  }

  let verification: VerifiedRegistrationResponse;
  try {
    verification = await verifyRegistrationResponse({
      response: opts.response,
      expectedChallenge: opts.expectedChallenge,
      expectedOrigin: EXPECTED_ORIGIN,
      expectedRPID: RP_ID,
      requireUserVerification: false, // 'preferred' en options; aquí no forzamos
    });
  } catch (err) {
    const msg = err instanceof Error ? err.message : 'verifyRegistration error';
    throw new PasskeyError('VERIFY_FAILED', msg);
  }

  if (!verification.verified || !verification.registrationInfo) {
    throw new PasskeyError('VERIFY_FAILED', 'La respuesta no se pudo verificar');
  }

  const {
    credential,
    credentialDeviceType,
    credentialBackedUp,
  } = verification.registrationInfo;

  const credentialIdBuf = base64urlToBuffer(credential.id);
  const publicKeyBuf = Buffer.from(credential.publicKey);
  const rowId = newCredentialRowId();
  const transports = opts.response.response.transports ?? null;

  await query(
    `INSERT INTO passkey_credentials
       (id, user_id, credential_id, public_key, counter, transports, device_type, backed_up, nickname)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
    [
      rowId,
      opts.userId,
      credentialIdBuf,
      publicKeyBuf,
      credential.counter,
      transports,
      credentialDeviceType,
      credentialBackedUp,
      opts.nickname ?? null,
    ]
  );

  return {
    id: rowId,
    credentialId: credential.id,
    deviceType: credentialDeviceType,
    backedUp: credentialBackedUp,
  };
}

// --------------------------------------------------------------------------
// AUTHENTICATION
// --------------------------------------------------------------------------

/**
 * Devuelve PublicKeyCredentialRequestOptionsJSON. Si se pasa un user,
 * se restringe a sus credenciales (allowCredentials). Si no, se hace
 * "discoverable" (el browser selecciona).
 */
export async function generateAuthentication(opts: {
  user?: { id: string } | null;
} = {}): Promise<PublicKeyCredentialRequestOptionsJSON> {
  let allowCredentials:
    | { id: string; transports?: AuthenticatorTransportFuture[] }[]
    | undefined;
  let userIdForChallenge: string | null = null;

  if (opts.user?.id) {
    userIdForChallenge = opts.user.id;
    const rows = await query<{ credential_id: Buffer; transports: string[] | null }>(
      `SELECT credential_id, transports
         FROM passkey_credentials
        WHERE user_id = $1`,
      [opts.user.id]
    );
    allowCredentials = rows.map((r) => ({
      id: bufferToBase64url(r.credential_id),
      transports: (r.transports ?? undefined) as
        | AuthenticatorTransportFuture[]
        | undefined,
    }));
  }

  const options = await generateAuthenticationOptions({
    rpID: RP_ID,
    userVerification: 'preferred',
    allowCredentials,
  });

  await storeChallenge(options.challenge, userIdForChallenge, 'authentication');
  return options;
}

/**
 * Verifica la respuesta del autenticador y devuelve el user_id asociado
 * a la credencial. Atómicamente actualiza el counter.
 *
 * Lanza PasskeyError si:
 *   - challenge inválido / expirado
 *   - credencial no registrada
 *   - firma inválida
 *   - replay (counter no avanzó)
 */
export async function verifyAuthentication(opts: {
  response: AuthenticationResponseJSON;
  expectedChallenge: string;
}): Promise<{
  userId: string;
  credentialDbId: string;
  newCounter: number;
}> {
  const consumed = await consumeChallenge(
    opts.expectedChallenge,
    'authentication'
  );
  if (!consumed) {
    throw new PasskeyError('CHALLENGE_INVALID', 'Challenge inválido o expirado');
  }

  // 1) Lookup de la credencial por credential_id
  const credentialIdBuf = base64urlToBuffer(opts.response.id);
  const stored = await maybeOne<StoredPasskey>(
    `SELECT id, user_id, credential_id, public_key, counter, transports,
            device_type, backed_up, nickname, last_used_at, created_at
       FROM passkey_credentials
      WHERE credential_id = $1`,
    [credentialIdBuf]
  );
  if (!stored) {
    throw new PasskeyError(
      'CREDENTIAL_NOT_FOUND',
      'La passkey no está registrada'
    );
  }

  // Si el challenge venía asociado a un user, debe coincidir con el de la passkey
  if (consumed.user_id && consumed.user_id !== stored.user_id) {
    throw new PasskeyError(
      'CHALLENGE_USER_MISMATCH',
      'La passkey no corresponde al user del challenge'
    );
  }

  // 2) Verificar firma
  let verification: VerifiedAuthenticationResponse;
  try {
    verification = await verifyAuthenticationResponse({
      response: opts.response,
      expectedChallenge: opts.expectedChallenge,
      expectedOrigin: EXPECTED_ORIGIN,
      expectedRPID: RP_ID,
      requireUserVerification: false, // 'preferred'; no obligatorio
      credential: {
        id: bufferToBase64url(stored.credential_id),
        publicKey: new Uint8Array(stored.public_key),
        counter: Number(stored.counter),
        transports: (stored.transports ?? undefined) as
          | AuthenticatorTransportFuture[]
          | undefined,
      },
    });
  } catch (err) {
    const msg = err instanceof Error ? err.message : 'verifyAuthentication error';
    throw new PasskeyError('VERIFY_FAILED', msg);
  }

  if (!verification.verified) {
    throw new PasskeyError('VERIFY_FAILED', 'Firma inválida');
  }

  const newCounter = verification.authenticationInfo.newCounter;

  // Ronda 122 SECURITY: prevenir replay attack. WebAuthn requiere counter
  // MONOTÓNICAMENTE creciente. Sin este chequeo, un attacker que captura una
  // assertion antigua (counter=N-5) puede replayearla incluso después de que
  // el authenticator avanzó a N — el UPDATE retrocedía el counter y todos
  // los assertions capturados quedaban reusables. Además previene race con
  // requests concurrentes del mismo assertion.
  // Excepción: authenticators counter=0 (algunos platform auth) — el counter
  // legítimo puede quedarse en 0 → aceptar solo si stored.counter también 0.
  await tx(async (client) => {
    if (newCounter === 0 && Number(stored.counter) === 0) {
      // Authenticator que no soporta counter — solo actualizar last_used_at.
      await client.query(
        `UPDATE passkey_credentials SET last_used_at = now() WHERE id = $1`,
        [stored.id]
      );
      return;
    }
    const upd = await client.query(
      `UPDATE passkey_credentials
          SET counter = $1, last_used_at = now()
        WHERE id = $2 AND counter < $1`,
      [newCounter, stored.id]
    );
    if (upd.rowCount === 0) {
      throw new PasskeyError(
        'VERIFY_FAILED',
        'Counter no creciente — posible replay de assertion',
      );
    }
  });

  return {
    userId: stored.user_id,
    credentialDbId: stored.id,
    newCounter,
  };
}

// --------------------------------------------------------------------------
// Mantenimiento (opcional — llamar desde un cron / housekeeping route)
// --------------------------------------------------------------------------
export async function purgeExpiredChallenges(): Promise<number> {
  const res = await queryFull(
    `DELETE FROM webauthn_challenges WHERE expires_at < now()`
  );
  return res.rowCount ?? 0;
}

// --------------------------------------------------------------------------
// Errores
// --------------------------------------------------------------------------
export type PasskeyErrorCode =
  | 'CHALLENGE_INVALID'
  | 'CHALLENGE_USER_MISMATCH'
  | 'VERIFY_FAILED'
  | 'CREDENTIAL_NOT_FOUND';

export class PasskeyError extends Error {
  constructor(public code: PasskeyErrorCode, message: string) {
    super(message);
    this.name = 'PasskeyError';
  }
}
