/**
 * /api/emergencies
 *
 * GET  — Lista emergencias.
 *   - Usuario normal: solo sus propias emergencias.
 *   - Admin: todas las emergencias.
 *   - Query params: ?status=active|resolved&limit=20
 *
 * POST — Crea una alerta SOS (panic button).
 *   Body: { type='panic', latitude, longitude, address?, description?, rideId? }
 *   - Inserta fila en `emergencies` con status='active'.
 *   - Notifica a los contactos de emergencia del user (insert en `notifications`).
 *   - Registra evento en `auth_events` (event_type='sos_triggered').
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth, getClientIp } from '@/lib/auth-middleware'
import { maybeOne, query, tx } from '@/lib/db'

export const runtime = 'nodejs'

interface EmergencyRow {
  id: string
  user_id: string | null
  ride_id: string | null
  type: string
  status: string
  latitude: string | null
  longitude: string | null
  address: string | null
  description: string | null
  resolved_by: string | null
  resolved_at: Date | null
  metadata: Record<string, unknown> | null
  created_at: Date
}

interface AdminCheckRow {
  is_admin: boolean
  user_type: string
}

const VALID_TYPES = new Set([
  'panic',
  'medical',
  'mechanical',
  'accident',
  'harassment',
  'robbery',
  'other',
])

function serialize(e: EmergencyRow) {
  return {
    id: e.id,
    userId: e.user_id,
    rideId: e.ride_id,
    type: e.type,
    status: e.status,
    latitude: e.latitude !== null ? Number(e.latitude) : null,
    longitude: e.longitude !== null ? Number(e.longitude) : null,
    address: e.address,
    description: e.description,
    resolvedBy: e.resolved_by,
    resolvedAt: e.resolved_at,
    metadata: e.metadata,
    createdAt: e.created_at,
  }
}

// ============================================================================
// GET — Lista emergencias
// ============================================================================
export async function GET(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  const { searchParams } = new URL(req.url)
  const status = searchParams.get('status')?.trim() || null
  const limitRaw = Number(searchParams.get('limit') ?? 20)
  const limit = Number.isFinite(limitRaw) && limitRaw > 0 && limitRaw <= 200 ? Math.floor(limitRaw) : 20

  // ¿Es admin?
  const adminCheck = await maybeOne<AdminCheckRow>(
    'SELECT is_admin, user_type FROM users WHERE id = $1',
    [auth.userId],
  )
  const isAdmin = !!(adminCheck && (adminCheck.is_admin || adminCheck.user_type === 'admin'))

  const conditions: string[] = []
  const params: unknown[] = []
  let idx = 1

  if (!isAdmin) {
    conditions.push(`user_id = $${idx++}`)
    params.push(auth.userId)
  }
  if (status) {
    conditions.push(`status = $${idx++}`)
    params.push(status)
  }

  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : ''
  params.push(limit)

  const rows = await query<EmergencyRow>(
    `SELECT id, user_id, ride_id, type, status, latitude::text, longitude::text,
            address, description, resolved_by, resolved_at, metadata, created_at
       FROM emergencies
       ${where}
       ORDER BY created_at DESC
       LIMIT $${idx}`,
    params,
  )

  return NextResponse.json({
    success: true,
    emergencies: rows.map(serialize),
  })
}

// ============================================================================
// POST — Crear alerta SOS
// ============================================================================
export async function POST(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  let body: {
    type?: string
    latitude?: number
    longitude?: number
    address?: string
    description?: string
    rideId?: string
  }
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  const type = (body.type ?? 'panic').trim()
  if (!VALID_TYPES.has(type)) {
    return NextResponse.json(
      { success: false, error: 'invalid_type', message: 'Tipo de emergencia inválido' },
      { status: 400 },
    )
  }

  const latitude = Number(body.latitude)
  const longitude = Number(body.longitude)
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    return NextResponse.json(
      { success: false, error: 'invalid_location', message: 'latitude/longitude requeridos' },
      { status: 400 },
    )
  }

  const address = body.address?.trim() || null
  const description = body.description?.trim() || null
  const rideId = body.rideId?.trim() || null

  try {
    const result = await tx(async (client) => {
      // 1) Insertar emergencia
      const emRes = await client.query<EmergencyRow>(
        `INSERT INTO emergencies
           (user_id, ride_id, type, status, latitude, longitude, address, description, metadata)
         VALUES ($1, $2, $3, 'active', $4, $5, $6, $7, $8)
         RETURNING id, user_id, ride_id, type, status,
                   latitude::text, longitude::text, address, description,
                   resolved_by, resolved_at, metadata, created_at`,
        [
          auth.userId,
          rideId,
          type,
          latitude,
          longitude,
          address,
          description,
          JSON.stringify({ ip: getClientIp(req), userAgent: req.headers.get('user-agent') ?? null }),
        ],
      )
      const emergency = emRes.rows[0]!

      // 2) Obtener info del user para el título/body de la notificación
      const userRes = await client.query<{ full_name: string | null; phone: string | null }>(
        'SELECT full_name, phone FROM users WHERE id = $1',
        [auth.userId],
      )
      const userName = userRes.rows[0]?.full_name ?? 'Un usuario'
      const userPhone = userRes.rows[0]?.phone ?? ''

      // 3) Notificar contactos de emergencia (los que sean también users del sistema)
      //    Se busca a los users cuyo phone coincide con phone de emergency_contacts del user.
      const contactsRes = await client.query<{ id: string; name: string; phone: string }>(
        `SELECT id, name, phone FROM emergency_contacts WHERE user_id = $1`,
        [auth.userId],
      )
      let notifiedCount = 0
      if (contactsRes.rows.length > 0) {
        const phones = contactsRes.rows.map((c) => c.phone)
        // Buscar users cuyo phone coincida
        const matchedUsersRes = await client.query<{ id: string; phone: string }>(
          `SELECT id, phone FROM users WHERE phone = ANY($1::text[])`,
          [phones],
        )
        for (const target of matchedUsersRes.rows) {
          await client.query(
            `INSERT INTO notifications (user_id, type, title, body, data)
             VALUES ($1, 'emergency_alert', $2, $3, $4)`,
            [
              target.id,
              `Alerta SOS de ${userName}`,
              `${userName} ha activado una alerta de emergencia. ` +
                (address ? `Ubicación: ${address}.` : ''),
              JSON.stringify({
                emergencyId: emergency.id,
                type,
                latitude,
                longitude,
                address,
                triggeredBy: auth.userId,
                triggeredByName: userName,
                triggeredByPhone: userPhone,
                rideId,
              }),
            ],
          )
          notifiedCount++
        }
      }

      // 4) Notificar a admins (auditoría en la app)
      const adminsRes = await client.query<{ id: string }>(
        `SELECT id FROM users
          WHERE (is_admin = true OR user_type = 'admin')
            AND is_active = true
            AND deleted_at IS NULL`,
      )
      for (const admin of adminsRes.rows) {
        await client.query(
          `INSERT INTO notifications (user_id, type, title, body, data)
           VALUES ($1, 'emergency_alert', $2, $3, $4)`,
          [
            admin.id,
            `Emergencia activada: ${type}`,
            `${userName} activó una alerta SOS. Revisa el panel de emergencias.`,
            JSON.stringify({
              emergencyId: emergency.id,
              type,
              latitude,
              longitude,
              address,
              triggeredBy: auth.userId,
              triggeredByName: userName,
              rideId,
            }),
          ],
        )
      }

      // 5) Auditoría en auth_events
      await client.query(
        `INSERT INTO auth_events (user_id, event_type, ip_address, user_agent, metadata)
         VALUES ($1, 'sos_triggered', $2, $3, $4)`,
        [
          auth.userId,
          getClientIp(req),
          req.headers.get('user-agent'),
          JSON.stringify({ emergencyId: emergency.id, type, latitude, longitude, rideId }),
        ],
      )

      return { emergency, notifiedCount }
    })

    return NextResponse.json(
      {
        success: true,
        emergency: serialize(result.emergency),
        notifiedContacts: result.notifiedCount,
      },
      { status: 200 },
    )
  } catch (err) {
    console.error('[emergencies/POST] error:', err)
    return NextResponse.json({ success: false, error: 'server_error' }, { status: 500 })
  }
}
