/**
 * DELETE /api/payment-methods/[id]
 *
 * Borra el método de pago (solo del user autenticado).
 * Regla de negocio: NO se puede borrar el método marcado como default
 * si es el único, o sin marcar otro como default previamente. El cliente
 * debe llamar PATCH-equivalente para promover otro método antes.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { tx } from '@/lib/db'

export const runtime = 'nodejs'

export async function DELETE(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response
  const { id } = await ctx.params

  try {
    const result = await tx(async (client) => {
      const target = await client.query<{ id: string; is_default: boolean }>(
        `SELECT id, is_default FROM user_payment_methods
           WHERE id = $1 AND user_id = $2
           FOR UPDATE`,
        [id, auth.userId],
      )
      const row = target.rows[0]
      if (!row) throw { code: 'not_found' }

      if (row.is_default) {
        // Verificamos que exista otro método marcado como default; si no, error.
        const others = await client.query<{ n: number }>(
          `SELECT COUNT(*)::int AS n FROM user_payment_methods
             WHERE user_id = $1 AND id <> $2 AND is_default = true`,
          [auth.userId, id],
        )
        if ((others.rows[0]?.n ?? 0) === 0) {
          throw { code: 'default_method' }
        }
      }

      const del = await client.query<{ id: string }>(
        `DELETE FROM user_payment_methods
           WHERE id = $1 AND user_id = $2 RETURNING id`,
        [id, auth.userId],
      )
      return del.rows[0]!
    })

    return NextResponse.json({ success: true, deletedId: result.id })
  } catch (err) {
    const code = (err as { code?: string })?.code
    if (code === 'not_found') {
      return NextResponse.json({ success: false, error: 'not_found' }, { status: 404 })
    }
    if (code === 'default_method') {
      return NextResponse.json(
        {
          success: false,
          error: 'default_method',
          message:
            'No se puede borrar el método por defecto sin marcar antes otro como default',
        },
        { status: 409 },
      )
    }
    console.error('[payment-methods/DELETE] error:', err)
    return NextResponse.json({ success: false, error: 'server_error' }, { status: 500 })
  }
}
