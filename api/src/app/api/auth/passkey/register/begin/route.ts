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

import { requireAuth } from '@/lib/auth-middleware';
import { generateRegistration } from '@/lib/passkeys';
import { maybeOne } from '@/lib/db';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

// Ronda 282: `extractBearer` se elimina — lo hace `requireAuth`.

export async function POST(req: NextRequest) {
  // 1) Validar la sesión, no solo el token.
  //
  // Ronda 282: ver la nota extensa en `register/finish`. `verifyAccessToken`
  // comprueba la firma pero no si la sesión sigue viva, así que un dispositivo
  // ya expulsado o deslogueado podía usar la hora que le queda de token para
  // dejarse una llave de acceso permanente en la cuenta.
  const auth = await requireAuth(req);
  if (!auth.ok) return auth.response;
  const claims = { sub: auth.userId };

  // 2) Recuperar datos del usuario (email + display_name) — sin requerir password.
  // Ronda 166: filtrar deleted_at + is_active. Sin esto, JWT vigente de un
  // user borrado pasaba y generaba challenge en webauthn_challenges (bloat
  // + posible surface para verificaciones futuras si el user "resurge"
  // por bug en /account/delete o restore desde backup).
  const user = await maybeOne<{
    id: string;
    email: string | null;
    display_name: string | null;
    full_name: string | null;
  }>(
    `SELECT id, email, display_name, full_name
       FROM users
      WHERE id = $1 AND deleted_at IS NULL AND is_active = true`,
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
      // Ronda 64: usar || (no ??) porque '' es común en BD y ?? solo cae
      // con null/undefined. Sin esto, prompt nativo passkey mostraba cuenta
      // sin nombre visible y gestores de credenciales rechazaban el registro.
      displayName: user.display_name || user.full_name || user.email || user.id,
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
