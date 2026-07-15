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

  // Ronda 65: user-enumeration real. Antes: si email existía, allowCredentials
  // se poblaba con los credentialID del user; si no existía, allowCredentials
  // vacío. Attacker distinguía existencia + obtenía IDs públicos de credenciales.
  // Fix: SIEMPRE flow discoverable (allowCredentials omitido) sin importar si
  // el email fue provisto o no. El browser prompteará selección + verify fail
  // si no hay credencial válida. Ignoramos body.email intencionalmente para
  // no leak-ear diferencias observables en la respuesta.
  void body.email

  try {
    const options = await generateAuthentication({ user: undefined });
    return NextResponse.json({ success: true, options }, { status: 200 });
  } catch (err) {
    console.error('[passkey/authenticate/begin] error:', err);
    return NextResponse.json(
      { success: false, error: 'failed_to_generate_options' },
      { status: 500 }
    );
  }
}
