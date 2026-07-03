/**
 * Rapi Team - Google OAuth 2.0 helpers (sin Firebase Auth)
 * --------------------------------------------------------------------------
 * Implementa el flow OAuth 2.0 server-side de Google:
 *   1. googleAuthUrl(state) → URL del consent screen
 *   2. exchangeCode(code)   → intercambia code por { id_token, access_token, refresh_token }
 *   3. verifyIdToken(jwt)   → valida y devuelve el payload del id_token
 *
 * Usa `google-auth-library` (oficial de Google) que ya cachea las claves
 * públicas de Google internamente.
 *
 * Variables de entorno:
 *   GOOGLE_CLIENT_ID
 *   GOOGLE_CLIENT_SECRET
 *   GOOGLE_REDIRECT_URI=https://rapi-team-admin.nynelmkt.cloud/api/auth/google/callback
 */

import { OAuth2Client, type LoginTicket, type TokenPayload } from 'google-auth-library';

const GOOGLE_OAUTH_SCOPES = ['openid', 'email', 'profile'] as const;
const GOOGLE_AUTHORIZATION_ENDPOINT = 'https://accounts.google.com/o/oauth2/v2/auth';

// --------------------------------------------------------------------------
// Tipos públicos
// --------------------------------------------------------------------------
export interface ExchangedTokens {
  idToken: string;
  accessToken?: string;
  refreshToken?: string;
  expiresAt?: number; // epoch ms
}

export interface VerifiedGoogleIdentity {
  sub: string;            // identificador único Google (estable)
  email: string | null;
  emailVerified: boolean;
  name: string | null;
  picture: string | null;
  givenName: string | null;
  familyName: string | null;
  locale: string | null;
}

// --------------------------------------------------------------------------
// Cliente OAuth singleton
// --------------------------------------------------------------------------
let cachedClient: OAuth2Client | undefined;

function getOauthClient(): OAuth2Client {
  if (cachedClient) return cachedClient;
  const clientId = process.env.GOOGLE_CLIENT_ID;
  const clientSecret = process.env.GOOGLE_CLIENT_SECRET;
  const redirectUri = process.env.GOOGLE_REDIRECT_URI;
  if (!clientId || !clientSecret || !redirectUri) {
    throw new Error(
      '[auth-google] Faltan envs: GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, GOOGLE_REDIRECT_URI'
    );
  }
  cachedClient = new OAuth2Client({
    clientId,
    clientSecret,
    redirectUri,
  });
  return cachedClient;
}

// --------------------------------------------------------------------------
// 1. URL del consent screen
// --------------------------------------------------------------------------
/**
 * Devuelve la URL de Google donde redirigir al usuario para autorizar.
 * `state` debe venir firmado por nosotros (ver `issueOauthState` en jwt.ts).
 */
export function googleAuthUrl(state: string): string {
  const clientId = process.env.GOOGLE_CLIENT_ID;
  const redirectUri = process.env.GOOGLE_REDIRECT_URI;
  if (!clientId || !redirectUri) {
    throw new Error('[auth-google] GOOGLE_CLIENT_ID y GOOGLE_REDIRECT_URI son requeridos');
  }
  const params = new URLSearchParams({
    client_id: clientId,
    redirect_uri: redirectUri,
    response_type: 'code',
    scope: GOOGLE_OAUTH_SCOPES.join(' '),
    access_type: 'offline',
    include_granted_scopes: 'true',
    prompt: 'select_account',
    state,
  });
  return `${GOOGLE_AUTHORIZATION_ENDPOINT}?${params.toString()}`;
}

// --------------------------------------------------------------------------
// 2. Intercambio code → tokens
// --------------------------------------------------------------------------
export async function exchangeCode(code: string): Promise<ExchangedTokens> {
  if (!code) throw new Error('[auth-google] exchangeCode: code vacío');
  const client = getOauthClient();
  const { tokens } = await client.getToken(code);
  if (!tokens.id_token) {
    throw new Error('[auth-google] Google no devolvió id_token');
  }
  return {
    idToken: tokens.id_token,
    accessToken: tokens.access_token ?? undefined,
    refreshToken: tokens.refresh_token ?? undefined,
    expiresAt: tokens.expiry_date ?? undefined,
  };
}

// --------------------------------------------------------------------------
// 3. Verificación del id_token
// --------------------------------------------------------------------------
export async function verifyIdToken(idToken: string): Promise<VerifiedGoogleIdentity> {
  if (!idToken) throw new Error('[auth-google] verifyIdToken: token vacío');
  const clientId = process.env.GOOGLE_CLIENT_ID;
  if (!clientId) throw new Error('[auth-google] GOOGLE_CLIENT_ID no definido');
  const client = getOauthClient();
  const ticket: LoginTicket = await client.verifyIdToken({
    idToken,
    audience: clientId,
  });
  const payload: TokenPayload | undefined = ticket.getPayload();
  if (!payload || !payload.sub) {
    throw new Error('[auth-google] id_token sin payload o sin sub');
  }
  return {
    sub: payload.sub,
    email: payload.email ?? null,
    emailVerified: Boolean(payload.email_verified),
    name: payload.name ?? null,
    picture: payload.picture ?? null,
    givenName: payload.given_name ?? null,
    familyName: payload.family_name ?? null,
    locale: payload.locale ?? null,
  };
}
