/**
 * Plus App — Middleware Bearer (dual: JWT propio + Firebase ID token).
 * --------------------------------------------------------------------------
 * Reemplazo/complemento gradual de `api-auth.ts`. Acepta DOS tipos de Bearer:
 *
 *   1. JWT propio (`iss === JWT_ISSUER`, default 'rapi-team')
 *      → verifica con `verifyAccessToken` (HS256, JWT_SECRET)
 *      → devuelve { uid, sid, source: 'rapi-team' }
 *
 *   2. Firebase ID token (cualquier otro `iss`, típicamente
 *      `https://securetoken.google.com/<projectId>`)
 *      → verifica con Firebase Admin SDK (`auth.verifyIdToken`)
 *      → devuelve { uid, source: 'firebase', firebaseClaims }
 *
 * Esto permite migración GRADUAL del cliente Flutter:
 *   - v172+   → emite JWT propio (login con Google/Passkeys/Phone vía VPS)
 *   - v170/v171 → seguía con Firebase Auth, mantenido temporalmente
 *
 * NO REEMPLAZA api-auth.ts: ese sigue funcionando solo con Firebase. Este
 * archivo es la nueva ruta — endpoints nuevos deberían usar `verifyBearerJWT`
 * de aquí para auto-aceptar ambos.
 */

import { NextRequest, NextResponse } from 'next/server';

import { verifyAccessToken, peekIssuer, JWT_ISSUER } from '@/lib/jwt';
import { auth as firebaseAuth } from '@/lib/firebase-admin';
import type { DecodedIdToken } from 'firebase-admin/auth';

// --------------------------------------------------------------------------
// Tipos
// --------------------------------------------------------------------------

export interface BearerUserPlusApp {
  uid: string;
  /** session id (sessions.id). Solo presente cuando source='rapi-team'. */
  sid: string;
  source: 'rapi-team';
}

export interface BearerUserFirebase {
  uid: string;
  source: 'firebase';
  /** Decoded Firebase claims (incluye email, email_verified, auth_time…). */
  firebaseClaims: DecodedIdToken;
}

export type BearerUser = BearerUserPlusApp | BearerUserFirebase;

// --------------------------------------------------------------------------
// Helpers
// --------------------------------------------------------------------------

function extractBearer(req: NextRequest): string | null {
  const h = req.headers.get('authorization') ?? req.headers.get('Authorization');
  if (!h) return null;
  return h.startsWith('Bearer ') ? h.slice(7).trim() || null : null;
}

// --------------------------------------------------------------------------
// verifyBearerJWT — la función principal
// --------------------------------------------------------------------------

/**
 * Valida el Bearer header y devuelve el user autenticado, o null si no es
 * válido. El caller debe responder 401 si null.
 *
 * Routing:
 *   - Si peekIssuer(token) === JWT_ISSUER → JWT propio.
 *   - Else → Firebase ID token (fallback).
 */
export async function verifyBearerJWT(req: NextRequest): Promise<BearerUser | null> {
  const token = extractBearer(req);
  if (!token) return null;

  const iss = peekIssuer(token);

  // --- Camino 1: JWT propio rapi-team ---
  if (iss === JWT_ISSUER) {
    const claims = await verifyAccessToken(token);
    if (!claims) return null;
    return {
      uid: claims.sub,
      sid: claims.sid,
      source: 'rapi-team',
    };
  }

  // --- Camino 2: Firebase ID token (fallback compat) ---
  try {
    const decoded = await firebaseAuth.verifyIdToken(token);
    return {
      uid: decoded.uid,
      source: 'firebase',
      firebaseClaims: decoded,
    };
  } catch {
    return null;
  }
}

// --------------------------------------------------------------------------
// Stock responses (espejo de api-auth.ts para mantener forma consistente)
// --------------------------------------------------------------------------

export function unauthorized() {
  return NextResponse.json(
    { success: false, error: 'unauthenticated' },
    { status: 401 },
  );
}

export function forbidden(detail = 'forbidden') {
  return NextResponse.json(
    { success: false, error: detail },
    { status: 403 },
  );
}
