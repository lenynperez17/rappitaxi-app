/**
 * DELETE /api/drivers/me/bank-accounts/:id — desactivar cuenta bancaria
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { queryFull } from '@/lib/db'

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

  const r = await queryFull(
    `UPDATE driver_bank_accounts
       SET is_active = false, is_default = false, updated_at = now()
     WHERE id = $1 AND driver_id = $2 AND is_active = true`,
    [id, auth.userId],
  )
  if (r.rowCount === 0) {
    return NextResponse.json({ success: false, error: 'not_found' }, { status: 404 })
  }
  return NextResponse.json({ success: true })
}
