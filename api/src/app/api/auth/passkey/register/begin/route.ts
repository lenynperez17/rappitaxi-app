/**
 * POST /api/auth/passkey/register/begin
 * --------------------------------------------------------------------------
 * Genera y devuelve PublicKeyCredentialCreationOptionsJSON al cliente.
 * Requiere Bearer JWT (usuario logueado registrando nueva passkey).
 *
 * Headers:  Authorization: Bearer <access_token>
 * Body:     (vacío)
 * Response: 200 PublicKeyCredentialCreationOptionsJSON
 *           401 si no hay Bearer válido
 */
import { NextRequest, NextResponse } from 'next/server';

import { verifyAccessToken } from '@/lib/jwt';
import { generateRegistration } from '@/lib/passkeys';
import { maybeOne } from '@/lib/db';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

function extractBearer(req: NextRequest): string | null {
  const h = req.headers.get('authorization');
  if (!h || !h.startsWith('Bearer ')) return null;
  const t = h.slice(7).trim();
  return t.length > 0 ? t : null;
}

export async function POST(req: NextRequest) {
  // 1) Validar Bearer JWT
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

  // 2) Recuperar datos del usuario (email + display_name) — sin requerir password
  const user = await maybeOne<{
    id: string;
    email: string | null;
    display_name: string | null;
    full_name: string | null;
  }>(
    `SELECT id, email, display_name, full_name
       FROM users
      WHERE id = $1`,
    [claims.sub]
  );

  if (!user) {
    // Sesión válida pero user borrado. Forzamos logout client-side.
    return NextResponse.json(
      { success: false, error: 'user_not_found' },
      { status: 401 }
    );
  }

  // 3) Generar opciones
  try {
    const options = await generateRegistration({
      id: user.id,
      email: user.email,
      displayName: user.display_name ?? user.full_name ?? user.email ?? user.id,
    });
    return NextResponse.json({ success: true, options }, { status: 200 });
  } catch (err) {
    console.error('[passkey/register/begin] error:', err);
    return NextResponse.json(
      { success: false, error: 'failed_to_generate_options' },
      { status: 500 }
    );
  }
}
