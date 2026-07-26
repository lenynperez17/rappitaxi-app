/**
 * DELETE /api/rides/:id/offers/mine
 *
 * Ronda 245: el conductor retira SU propia oferta de un viaje.
 *
 * Antes no existía ningún endpoint para esto, y el cliente lo "resolvía"
 * mostrando un SnackBar sin tocar el servidor (`_rejectCounterOffer`) o con
 * no-ops comentados como "el backend expira las ofertas por TTL" — TTL que
 * tampoco existe. Consecuencia real: la oferta quedaba `pending` para
 * siempre y el pasajero podía aceptarla horas más tarde, asignándole al
 * conductor un viaje que ya había descartado. Él no se enteraba, y además
 * quedaba bloqueado para ponerse offline (409 `has_active_ride`).
 *
 * Solo marca como `withdrawn` las ofertas PENDING del propio conductor: si
 * el pasajero ya la aceptó, el ride tiene driver asignado y no se puede
 * deshacer por esta vía (hay que cancelar el viaje).
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { query } from '@/lib/db'

export const runtime = 'nodejs'

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

export async function DELETE(
  req: NextRequest,
  ctx: { params: Promise<{ id: string }> },
) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  const { id: rideId } = await ctx.params
  if (!UUID_RE.test(rideId)) {
    return NextResponse.json({ success: false, error: 'invalid_ride_id' }, { status: 400 })
  }

  // Solo ofertas pendientes propias. Si ya fue aceptada/rechazada, no se toca.
  const rows = await query<{ id: string }>(
    `UPDATE ride_offers
        SET status = 'withdrawn'
      WHERE ride_id = $1
        AND driver_id = $2
        AND status = 'pending'
      RETURNING id`,
    [rideId, auth.userId],
  )

  return NextResponse.json({
    success: true,
    withdrawn: rows.length,
  })
}
