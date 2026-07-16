/**
 * DELETE /api/drivers/me/bank-accounts/:id — desactivar cuenta bancaria
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { tx } from '@/lib/db'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

// UUID v4 pattern — evita Postgres 22P02 → 500 con ids mal formados
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

export async function DELETE(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response
  const { id } = await ctx.params

  // Ronda 45 Bug#1: validar UUID antes del UPDATE
  if (!UUID_RE.test(id)) {
    return NextResponse.json({ success: false, error: 'not_found' }, { status: 404 })
  }

  // Ronda 185: al desactivar cuenta con is_default=true, promover otra a
  // default automáticamente. Antes el driver quedaba con 0 default →
  // withdrawals fallaban silenciosamente al no tener cuenta destino.
  try {
    const promoted = await tx(async (client) => {
      const del = await client.query<{ is_default: boolean }>(
        `UPDATE driver_bank_accounts
            SET is_active = false, is_default = false, updated_at = now()
          WHERE id = $1 AND driver_id = $2 AND is_active = true
          RETURNING is_default`,
        [id, auth.userId],
      )
      if (del.rowCount === 0) throw { code: 'not_found' }
      if (!del.rows[0].is_default) return false
      // Era la default → promover la más antigua activa que quede.
      await client.query(
        `UPDATE driver_bank_accounts
            SET is_default = true, updated_at = now()
          WHERE id = (
            SELECT id FROM driver_bank_accounts
             WHERE driver_id = $1 AND is_active = true
             ORDER BY created_at ASC
             LIMIT 1
          )`,
        [auth.userId],
      )
      return true
    })
    return NextResponse.json({ success: true, promotedNewDefault: promoted })
  } catch (err) {
    const e = err as { code?: string }
    if (e?.code === 'not_found') {
      return NextResponse.json({ success: false, error: 'not_found' }, { status: 404 })
    }
    console.error('[bank-accounts DELETE] error:', err)
    return NextResponse.json({ success: false, error: 'internal_error' }, { status: 500 })
  }
}
