/**
 * POST /api/auth/passkey/authenticate/begin
 * --------------------------------------------------------------------------
 * Devuelve PublicKeyCredentialRequestOptionsJSON para login con passkey.
 * PÚBLICO (sin Bearer). Si se provee `email` opcional en el body se restringe
 * a las credenciales de ese usuario. Si no, se hace flow "discoverable".
 *
 * Body:     { email?: string }
 * Response: 200 PublicKeyCredentialRequestOptionsJSON
 */
import { NextRequest, NextResponse } from 'next/server';

import { generateAuthentication } from '@/lib/passkeys';
import { maybeOne } from '@/lib/db';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

interface ReqBody {
  email?: string;
}

export async function POST(req: NextRequest) {
  let body: ReqBody = {};
  // Body opcional. Si llega vacío o malformado, asumimos discoverable.
  try {
    const txt = await req.text();
    if (txt.trim().length > 0) {
      body = JSON.parse(txt) as ReqBody;
    }
  } catch {
    body = {};
  }

  let userForOptions: { id: string } | undefined;
  if (body.email && typeof body.email === 'string') {
    const email = body.email.trim().toLowerCase();
    if (email.length > 0) {
      const u = await maybeOne<{ id: string }>(
        `SELECT id FROM users WHERE LOWER(email) = $1 LIMIT 1`,
        [email]
      );
      // Si el email no existe NO devolvemos error (evita user-enumeration).
      // Caemos a flow discoverable: el browser pedirá selección y el verify
      // fallará si no hay credencial registrada.
      if (u) userForOptions = { id: u.id };
    }
  }

  try {
    const options = await generateAuthentication({ user: userForOptions });
    return NextResponse.json({ success: true, options }, { status: 200 });
  } catch (err) {
    console.error('[passkey/authenticate/begin] error:', err);
    return NextResponse.json(
      { success: false, error: 'failed_to_generate_options' },
      { status: 500 }
    );
  }
}
