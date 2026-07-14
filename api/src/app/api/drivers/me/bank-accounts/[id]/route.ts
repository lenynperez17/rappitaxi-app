/**
 * DELETE /api/drivers/me/bank-accounts/:id — desactivar cuenta bancaria
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { queryFull } from '@/lib/db'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

export async function DELETE(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response
  const { id } = await ctx.params

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
