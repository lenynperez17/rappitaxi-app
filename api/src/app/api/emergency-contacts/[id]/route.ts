/**
 * /api/emergency-contacts/[id]
 *
 * PATCH  — Actualiza un contacto (name, phone, relationship, isPrimary).
 *          Si isPrimary=true, primero desmarca los demás del user.
 *
 * DELETE — Borra el contacto (solo del user autenticado).
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
// PATCH — Actualizar
// ============================================================================
export async function PATCH(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response
  const { id } = await ctx.params

  let body: {
    name?: string
    phone?: string
    relationship?: string | null
    isPrimary?: boolean
  }
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  const updates: string[] = []
  const params: unknown[] = []
  let idx = 1
  const wantsPrimary = body.isPrimary === true

  if (body.name !== undefined) {
    if (!body.name.trim()) {
      return NextResponse.json({ success: false, error: 'invalid_name' }, { status: 400 })
    }
    updates.push(`name = $${idx++}`)
    params.push(body.name.trim())
  }
  if (body.phone !== undefined) {
    if (!body.phone.trim()) {
      return NextResponse.json({ success: false, error: 'invalid_phone' }, { status: 400 })
    }
    updates.push(`phone = $${idx++}`)
    params.push(body.phone.trim())
  }
  if (body.relationship !== undefined) {
    updates.push(`relationship = $${idx++}`)
    params.push(body.relationship?.trim() || null)
  }
  if (body.isPrimary !== undefined) {
    updates.push(`is_primary = $${idx++}`)
    params.push(!!body.isPrimary)
  }

  if (updates.length === 0) {
    return NextResponse.json(
      { success: false, error: 'no_changes', message: 'Nada para actualizar' },
      { status: 400 },
    )
  }

  params.push(id, auth.userId)

  try {
    const contact = await tx(async (client) => {
      if (wantsPrimary) {
        // Desmarca los demás del user (excepto el mismo por si acaso).
        await client.query(
          `UPDATE emergency_contacts SET is_primary = false
             WHERE user_id = $1 AND id <> $2`,
          [auth.userId, id],
        )
      }
      const upd = await client.query<ContactRow>(
        `UPDATE emergency_contacts
            SET ${updates.join(', ')}
          WHERE id = $${idx} AND user_id = $${idx + 1}
        RETURNING id, user_id, name, phone, relationship, is_primary, created_at`,
        params,
      )
      const row = upd.rows[0]
      if (!row) throw { code: 'not_found' }
      return row
    })
    return NextResponse.json({ success: true, contact: serialize(contact) })
  } catch (err) {
    if ((err as { code?: string })?.code === 'not_found') {
      return NextResponse.json({ success: false, error: 'not_found' }, { status: 404 })
    }
    if (isUniqueViolation(err)) {
      return NextResponse.json(
        { success: false, error: 'duplicate_phone', message: 'Ya tienes un contacto con ese teléfono' },
        { status: 409 },
      )
    }
    console.error('[emergency-contacts/PATCH] error:', err)
    return NextResponse.json({ success: false, error: 'server_error' }, { status: 500 })
  }
}

// ============================================================================
// DELETE — Borrar
// ============================================================================
export async function DELETE(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response
  const { id } = await ctx.params

  const rows = await query<{ id: string }>(
    `DELETE FROM emergency_contacts WHERE id = $1 AND user_id = $2 RETURNING id`,
    [id, auth.userId],
  )
  if (rows.length === 0) {
    return NextResponse.json({ success: false, error: 'not_found' }, { status: 404 })
  }
  return NextResponse.json({ success: true, deletedId: rows[0]!.id })
}
