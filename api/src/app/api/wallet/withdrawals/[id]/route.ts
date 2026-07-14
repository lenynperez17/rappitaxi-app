/**
 * DELETE /api/wallet/withdrawals/:id — cancelar retiro pendiente y revertir débito
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { tx } from '@/lib/db'
import type { PoolClient } from 'pg'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

export async function DELETE(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response
  const { id } = await ctx.params

  try {
    await tx(async (client: PoolClient) => {
      const wRes = await client.query<{ status: string; amount: string }>(
        `SELECT status, amount FROM wallet_withdrawals
          WHERE id = $1 AND driver_id = $2 FOR UPDATE`,
        [id, auth.userId],
      )
      if (wRes.rowCount === 0) throw { code: 'not_found', status: 404 }
      const w = wRes.rows[0]
      if (w.status !== 'pending') {
        throw { code: 'not_cancellable', status: 409, currentStatus: w.status }
      }
      await client.query(
        `UPDATE wallet_withdrawals SET status = 'cancelled', updated_at = now() WHERE id = $1`,
        [id],
      )
      // Cancelar la transacción pending del wallet
      await client.query(
        `UPDATE wallet_transactions SET status = 'cancelled', completed_at = now()
           WHERE external_ref = $1 AND user_id = $2 AND status = 'pending'`,
        [id, auth.userId],
      )
    })
    return NextResponse.json({ success: true })
  } catch (err) {
    const e = err as { code?: string; status?: number; currentStatus?: string }
    if (e?.code && e?.status) {
      return NextResponse.json({
        success: false, error: e.code,
        ...(e.currentStatus ? { currentStatus: e.currentStatus } : {})
      }, { status: e.status })
    }
    console.error('[withdrawals DELETE]', err)
    return NextResponse.json({ success: false, error: 'internal_error' }, { status: 500 })
  }
}
