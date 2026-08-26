/**
 * POST /api/drivers/me/upgrade
 * Convierte un passenger en dual (habilita el modo conductor).
 *
 * SEGURIDAD: exige que el user tenga los documentos requeridos aprobados
 * ANTES de convertirlo en dual. Sin este check, cualquier passenger con JWT
 * válido se volvía driver y podía tomar viajes reales sin identidad ni
 * vehículo verificados.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth, getClientIp } from '@/lib/auth-middleware'
import { maybeOne, query } from '@/lib/db'
import { getRequiredDocTypes } from '@/lib/document-types'
import { settingBool } from '@/lib/app-settings'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

// Ronda 279: aquí había una copia literal de la lista de documentos
// obligatorios, con un comentario que pedía "debe coincidir con
// REQUIRED_DOC_TYPES en /api/admin/documents/[id]/route.ts". Coincidir a mano
// es precisamente lo que deja de pasar con el tiempo. Ahora las dos leen el
// catálogo que el administrador edita en el panel.

export async function POST(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  const user = await maybeOne<{ id: string; user_type: string; is_admin: boolean; phone_verified: boolean; email_verified: boolean }>(
    'SELECT id, user_type, is_admin, phone_verified, email_verified FROM users WHERE id = $1 AND deleted_at IS NULL',
    [auth.userId],
  )
  if (!user) return NextResponse.json({ success: false, error: 'user_not_found' }, { status: 404 })

  if (user.user_type === 'driver' || user.user_type === 'dual') {
    return NextResponse.json({ success: true, message: 'Ya eres conductor', userType: user.user_type })
  }

  // Ronda 279: `registration.driver_enabled` era otro ajuste decorativo. Las
  // cuentas de conductor no nacen en el alta —se crean como pasajero y se
  // promueven aquí—, así que éste es el sitio donde el interruptor significa
  // algo. Va después de la comprobación de "ya eres conductor" para que
  // cerrar el alta no afecte a quien ya lo es.
  if (!(await settingBool('registration.driver_enabled', true))) {
    return NextResponse.json({
      success: false,
      error: 'driver_registration_closed',
      message: 'El registro de nuevos conductores está cerrado temporalmente.',
    }, { status: 403 })
  }

  // Ronda 70 SECURITY: exigir teléfono verificado antes de upgrade a driver.
  // Antes el UPDATE forzaba is_verified=true bypassing la verificación de
  // contacto que el resto de la app exige para payouts, cambio de teléfono,
  // OTP. Un passenger sin phone verificado no debe poder tomar rides como driver.
  if (!user.phone_verified) {
    return NextResponse.json({
      success: false,
      error: 'phone_not_verified',
      message: 'Verifica tu teléfono antes de habilitar el modo conductor.',
    }, { status: 403 })
  }

  // Verificar que todos los documentos requeridos están approved Y VIGENTES.
  // Ronda 55 Bug#1 SECURITY: sin AND (expires_at IS NULL OR expires_at > now()),
  // documentos aprobados hace años con expires_at vencido pasaban el gate y el
  // pasajero se convertía en dual con licencia/SOAT expirados — exactamente
  // lo que este endpoint dice prevenir.
  const requiredDocTypes = await getRequiredDocTypes()
  const approvedRes = await query<{ doc_type: string }>(
    `SELECT doc_type FROM driver_documents
      WHERE driver_id = $1
        AND status = 'approved'
        AND (expires_at IS NULL OR expires_at > now())
        AND doc_type = ANY($2::text[])`,
    [auth.userId, requiredDocTypes],
  )
  const approvedTypes = new Set(approvedRes.map((r) => r.doc_type))
  const missing = requiredDocTypes.filter((t) => !approvedTypes.has(t))
  if (missing.length > 0) {
    return NextResponse.json({
      success: false,
      error: 'documents_missing_or_not_approved',
      message: 'Todos tus documentos deben estar aprobados y vigentes.',
      missing,
    }, { status: 403 })
  }

  // Verificar que tiene al menos un vehículo activo.
  const vehicle = await maybeOne<{ id: string }>(
    `SELECT id FROM driver_vehicles WHERE driver_id = $1 AND is_active = true LIMIT 1`,
    [auth.userId],
  )
  if (!vehicle) {
    return NextResponse.json({
      success: false,
      error: 'no_active_vehicle',
      message: 'Registra al menos un vehículo activo antes de habilitar el modo conductor.',
    }, { status: 403 })
  }

  // Ronda 70: NO forzar is_verified=true — ese flag representa verificación
  // de contacto (phone/email), no de documentos. El estado 'dual' + is_verified
  // preservado son señales independientes. is_verified se mantiene como estaba.
  await query(
    `UPDATE users SET user_type = 'dual', updated_at = now() WHERE id = $1`,
    [auth.userId],
  )
  await query(
    `INSERT INTO auth_events (user_id, event_type, provider, ip_address, user_agent, metadata)
     VALUES ($1, 'upgraded_to_driver', 'app', $2, $3, $4)`,
    [auth.userId, getClientIp(req), req.headers.get('user-agent'), JSON.stringify({
      previousType: user.user_type,
      approvedDocs: requiredDocTypes,
      vehicleId: vehicle.id,
    })],
  )

  return NextResponse.json({ success: true, userType: 'dual' })
}
