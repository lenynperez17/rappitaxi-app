/**
 * POST /api/auth/passkey/register/finish
 * --------------------------------------------------------------------------
 * Verifica el attestation response del autenticador y persiste la credential.
 * Requiere Bearer JWT del MISMO usuario que llamó a /register/begin.
 *
 * Headers:  Authorization: Bearer <access_token>
 * Body:     {
 *             response: RegistrationResponseJSON,  // navigator.credentials.create result
 *             expectedChallenge: string,            // el que devolvió /begin (options.challenge)
 *             nickname?: string                     // alias amigable opcional
 *           }
 * Response: 200 { success, credentialId, deviceType, backedUp }
 *           400 challenge inválido o response mal formada
 *           401 sin Bearer
 *           422 verificación falló
 */
import { NextRequest, NextResponse } from 'next/server';

import { verifyAccessToken } from '@/lib/jwt';
import { verifyRegistration, PasskeyError } from '@/lib/passkeys';
import { maybeOne } from '@/lib/db';
import type { RegistrationResponseJSON } from '@simplewebauthn/server';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

function extractBearer(req: NextRequest): string | null {
  const h = req.headers.get('authorization');
  if (!h || !h.startsWith('Bearer ')) return null;
  const t = h.slice(7).trim();
  return t.length > 0 ? t : null;
}

interface ReqBody {
  response?: RegistrationResponseJSON;
  expectedChallenge?: string;
  nickname?: string | null;
}

export async function POST(req: NextRequest) {
  // 1) Auth
  const bearer = extractBearer(req);
  if (!bearer) {
    return NextResponse.json(
      { success: false, error: 'unauthenticated' },
      { status: 401 }
    );
  }
  const claims = await verifyAccessToken(bearer);
  if (!claims) {
    return NextResponse.json(
      { success: false, error: 'invalid_token' },
      { status: 401 }
    );
  }

  // Ronda 51 Bug#1: chequear estado del user (mismo patrón que
  // authenticate/finish B#9). Sin este gate, un user suspendido puede
  // registrar passkeys nuevas con su JWT vigente antes de que expire.
  const userRow = await maybeOne<{ is_active: boolean; suspended_at: Date | null; deleted_at: Date | null }>(
    'SELECT is_active, suspended_at, deleted_at FROM users WHERE id = $1',
    [claims.sub],
  );
  if (!userRow || userRow.deleted_at) {
    return NextResponse.json({ success: false, error: 'user_not_found' }, { status: 404 });
  }
  if (!userRow.is_active || userRow.suspended_at) {
    return NextResponse.json(
      { success: false, error: 'account_disabled', message: 'Cuenta suspendida' },
      { status: 403 },
    );
  }

  // 2) Body
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
  if (
    typeof body.expectedChallenge !== 'string' ||
    body.expectedChallenge.length < 8
  ) {
    return NextResponse.json(
      { success: false, error: 'expectedChallenge inválido' },
      { status: 400 }
    );
  }

  // 3) Verificación + persistencia
  try {
    const result = await verifyRegistration({
      userId: claims.sub,
      response: body.response,
      expectedChallenge: body.expectedChallenge,
      nickname: body.nickname ?? null,
    });
    return NextResponse.json(
      {
        success: true,
        credential: {
          id: result.id,
          credentialId: result.credentialId,
          deviceType: result.deviceType,
          backedUp: result.backedUp,
        },
      },
      { status: 200 }
    );
  } catch (err) {
    if (err instanceof PasskeyError) {
      const status =
        err.code === 'CHALLENGE_INVALID' || err.code === 'CHALLENGE_USER_MISMATCH'
          ? 400
          : 422;
      return NextResponse.json(
        { success: false, error: err.code, detail: err.message },
        { status }
      );
    }
    console.error('[passkey/register/finish] error:', err);
    return NextResponse.json(
      { success: false, error: 'internal_error' },
      { status: 500 }
    );
  }
}
