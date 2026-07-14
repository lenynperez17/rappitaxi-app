/**
 * /api/emergency-contacts
 *
 * GET    — Lista los contactos de emergencia del user autenticado.
 *          ORDER BY is_primary DESC, created_at ASC
 *
 * POST   — Agrega un contacto.
 *          Body: { name, phone, relationship?, isPrimary? }
 *          Si isPrimary=true, primero desmarca los demás.
 *
 * DELETE — Borra un contacto. Query: ?id=uuid
 *          Solo del user autenticado.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { isUniqueViolation, query, tx } from '@/lib/db'

export const runtime = 'nodejs'

interface ContactRow {
  id: string
  user_id: string
  name: string
  phone: string
  relationship: string | null
  is_primary: boolean
  created_at: Date
}

function serialize(c: ContactRow) {
  return {
    id: c.id,
    userId: c.user_id,
    name: c.name,
    phone: c.phone,
    relationship: c.relationship,
    isPrimary: c.is_primary,
    createdAt: c.created_at,
  }
}

// ============================================================================
// GET — Lista contactos
// ============================================================================
export async function GET(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  const rows = await query<ContactRow>(
    `SELECT id, user_id, name, phone, relationship, is_primary, created_at
       FROM emergency_contacts
       WHERE user_id = $1
       ORDER BY is_primary DESC, created_at ASC`,
    [auth.userId],
  )

  return NextResponse.json({
    success: true,
    contacts: rows.map(serialize),
  })
}

// ============================================================================
// POST — Agregar contacto
// ============================================================================
export async function POST(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  let body: { name?: string; phone?: string; relationship?: string; isPrimary?: boolean }
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  const name = body.name?.trim()
  const phone = body.phone?.trim()
  const relationship = body.relationship?.trim() || null
  const isPrimary = !!body.isPrimary

  if (!name || !phone) {
    return NextResponse.json(
      { success: false, error: 'invalid_input', message: 'name y phone son requeridos' },
      { status: 400 },
    )
  }
  // Validar E.164 — sin esto un attacker podía poner strings arbitrarios
  // como phone y luego usar SOS para hacer que el sistema los "envíe" SMS
  // (Twilio rechazaría, pero validar temprano es defensa clara).
  if (!/^\+[1-9][0-9]{9,14}$/.test(phone)) {
    return NextResponse.json(
      { success: false, error: 'invalid_phone', message: 'Formato E.164 requerido: +51999888777' },
      { status: 400 },
    )
  }

  try {
    const contact = await tx(async (client) => {
      if (isPrimary) {
        await client.query(
          `UPDATE emergency_contacts SET is_primary = false WHERE user_id = $1`,
          [auth.userId],
        )
      }
      const res = await client.query<ContactRow>(
        `INSERT INTO emergency_contacts (user_id, name, phone, relationship, is_primary)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING id, user_id, name, phone, relationship, is_primary, created_at`,
        [auth.userId, name, phone, relationship, isPrimary],
      )
      return res.rows[0]!
    })

    return NextResponse.json({ success: true, contact: serialize(contact) }, { status: 200 })
  } catch (err) {
    if (isUniqueViolation(err)) {
      return NextResponse.json(
        { success: false, error: 'duplicate_phone', message: 'Ya tienes un contacto con ese teléfono' },
        { status: 409 },
      )
    }
    console.error('[emergency-contacts/POST] error:', err)
    return NextResponse.json({ success: false, error: 'server_error' }, { status: 500 })
  }
}

// ============================================================================
// DELETE — Borrar contacto por ?id=uuid
// ============================================================================
export async function DELETE(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  const { searchParams } = new URL(req.url)
  const id = searchParams.get('id')?.trim()
  if (!id) {
    return NextResponse.json(
      { success: false, error: 'invalid_input', message: 'Falta ?id=' },
      { status: 400 },
    )
  }

  const rows = await query<{ id: string }>(
    `DELETE FROM emergency_contacts WHERE id = $1 AND user_id = $2 RETURNING id`,
    [id, auth.userId],
  )
  if (rows.length === 0) {
    return NextResponse.json({ success: false, error: 'not_found' }, { status: 404 })
  }
  return NextResponse.json({ success: true, deletedId: rows[0]!.id })
}
