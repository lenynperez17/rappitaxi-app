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

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

// Documentos que el driver DEBE tener 'approved' antes del upgrade.
// Debe coincidir con REQUIRED_DOC_TYPES en /api/admin/documents/[id]/route.ts
const REQUIRED_DOC_TYPES = [
  'dni_front',
  'dni_back',
  'license_front',
  'license_back',
  'soat',
]

export async function POST(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  const user = await maybeOne<{ id: string; user_type: string; is_admin: boolean }>(
    'SELECT id, user_type, is_admin FROM users WHERE id = $1 AND deleted_at IS NULL',
    [auth.userId],
  )
  if (!user) return NextResponse.json({ success: false, error: 'user_not_found' }, { status: 404 })

  if (user.user_type === 'driver' || user.user_type === 'dual') {
    return NextResponse.json({ success: true, message: 'Ya eres conductor', userType: user.user_type })
  }

  // Verificar que todos los documentos requeridos están approved.
  const approvedRes = await query<{ doc_type: string }>(
    `SELECT doc_type FROM driver_documents
      WHERE driver_id = $1
        AND status = 'approved'
        AND doc_type = ANY($2::text[])`,
    [auth.userId, REQUIRED_DOC_TYPES],
  )
  const approvedTypes = new Set(approvedRes.map((r) => r.doc_type))
  const missing = REQUIRED_DOC_TYPES.filter((t) => !approvedTypes.has(t))
  if (missing.length > 0) {
    return NextResponse.json({
      success: false,
      error: 'documents_missing_or_not_approved',
      message: 'Un admin debe aprobar tus documentos antes de habilitar el modo conductor.',
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

  await query(
    `UPDATE users SET user_type = 'dual', is_verified = true, updated_at = now() WHERE id = $1`,
    [auth.userId],
  )
  await query(
    `INSERT INTO auth_events (user_id, event_type, provider, ip_address, user_agent, metadata)
     VALUES ($1, 'upgraded_to_driver', 'app', $2, $3, $4)`,
    [auth.userId, getClientIp(req), req.headers.get('user-agent'), JSON.stringify({
      previousType: user.user_type,
      approvedDocs: REQUIRED_DOC_TYPES,
      vehicleId: vehicle.id,
    })],
  )

  return NextResponse.json({ success: true, userType: 'dual' })
}
