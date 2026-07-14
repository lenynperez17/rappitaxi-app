/**
 * POST /api/auth/passkey/authenticate/finish
 * --------------------------------------------------------------------------
 * Verifica la assertion del autenticador y EMITE JWT propio (access + refresh)
 * para el usuario asociado a la credencial. Equivalente al callback de Google OAuth.
 *
 * Body:     { response: AuthenticationResponseJSON, expectedChallenge: string }
 * Response: 200 {
 *             success,
 *             accessToken,
 *             refreshToken,
 *             accessExpiresInSec,
 *             refreshExpiresAt,
 *             sessionId,
 *             user: { id, email, displayName, type }
 *           }
 *           400 challenge inválido / body malformado
 *           401 credencial no registrada / firma inválida
 *           404 user huérfano (caso edge)
 */
import { NextRequest, NextResponse } from 'next/server';

import { createSession, deviceInfoFromHeaders } from '@/lib/sessions';
import { verifyAuthentication, PasskeyError } from '@/lib/passkeys';
import { maybeOne } from '@/lib/db';
import type { AuthenticationResponseJSON } from '@simplewebauthn/server';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

interface ReqBody {
  response?: AuthenticationResponseJSON;
  expectedChallenge?: string;
}

export async function POST(req: NextRequest) {
  let body: ReqBody;
  try {
    body = (await req.json()) as ReqBody;
  } catch {
    return NextResponse.json(
      { success: false, error: 'invalid_json' },
      { status: 400 }
    );
  }
  if (!body?.response || !body?.expectedChallenge) {
    return NextResponse.json(
      { success: false, error: 'response y expectedChallenge requeridos' },
      { status: 400 }
    );
  }

  try {
    const auth = await verifyAuthentication({
      response: body.response,
      expectedChallenge: body.expectedChallenge,
    });

    // Cargar al user para devolver datos básicos al cliente.
    // B#9: incluir is_active, suspended_at, deleted_at — sin esto,
    // una passkey de un usuario suspendido/eliminado seguía funcionando.
    const user = await maybeOne<{
      id: string;
      email: string | null;
      display_name: string | null;
      user_type: string;
      is_active: boolean;
      suspended_at: Date | null;
      deleted_at: Date | null;
    }>(
      `SELECT id, email, display_name, user_type, is_active, suspended_at, deleted_at
         FROM users
        WHERE id = $1`,
      [auth.userId]
    );
    if (!user) {
      // Credencial huérfana (user borrado). Edge case raro.
      return NextResponse.json(
        { success: false, error: 'user_not_found' },
        { status: 404 }
      );
    }
    if (user.deleted_at) {
      return NextResponse.json(
        { success: false, error: 'user_deleted' },
        { status: 410 }
      );
    }
    if (user.suspended_at) {
      return NextResponse.json(
        { success: false, error: 'user_suspended' },
        { status: 403 }
      );
    }
    if (!user.is_active) {
      return NextResponse.json(
        { success: false, error: 'user_inactive' },
        { status: 403 }
      );
    }

    // Construir device_info enriquecido con metadata de la passkey usada
    const baseDevice = deviceInfoFromHeaders(req.headers);
    const deviceInfo = {
      ...baseDevice,
      loginMethod: 'passkey',
      credentialDbId: auth.credentialDbId,
    };

    // Crear sesión completa (access + refresh + row en `sessions`)
    const session = await createSession(user.id, deviceInfo);

    return NextResponse.json(
      {
        success: true,
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        accessExpiresInSec: session.accessExpiresInSec,
        refreshExpiresAt: session.refreshExpiresAt.toISOString(),
        sessionId: session.sessionId,
        user: {
          id: user.id,
          email: user.email,
          displayName: user.display_name,
          type: user.user_type,
        },
      },
      { status: 200 }
    );
  } catch (err) {
    if (err instanceof PasskeyError) {
      const status =
        err.code === 'CHALLENGE_INVALID' || err.code === 'CHALLENGE_USER_MISMATCH'
          ? 400
          : 401;
      return NextResponse.json(
        { success: false, error: err.code, detail: err.message },
        { status }
      );
    }
    console.error('[passkey/authenticate/finish] error:', err);
    return NextResponse.json(
      { success: false, error: 'internal_error' },
      { status: 500 }
    );
  }
}
