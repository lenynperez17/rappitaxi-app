import { useEffect, useRef, useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import {
  Loader2, AlertCircle, CheckCircle2, XCircle, Ban, MapPin, RotateCcw,
} from 'lucide-react'
import { adminApi, AdminApiError, type AdminCancellation } from '../../lib/adminApi'
import { queryKeys } from '../../lib/queryKeys'
import { contactLine } from '../../utils/contactDisplay'
import { Avatar } from '../../components/Avatar'
import { pickPhotoUrl } from '../../lib/photoUrl'
import { DateTime } from '../../components/DateTime'

/**
 * Ronda 246: bandeja de revisión de penalidades por cancelación.
 *
 * Cuando un conductor cancela un viaje ya aceptado se le descuenta un
 * porcentaje. Acá el equipo lee el motivo que declaró y decide: si estaba
 * justificado se le devuelve el dinero a su billetera; si no, la penalidad
 * se mantiene (y hay que explicar por qué). Mismo modelo que inDriver.
 */

const REASON_LABELS: Record<string, string> = {
  passenger_no_show: 'El pasajero no apareció',
  passenger_request: 'El pasajero pidió cancelar',
  passenger_wrong_address: 'Dirección incorrecta o inaccesible',
  vehicle_issue: 'Problema con el vehículo',
  traffic_or_road: 'Vía bloqueada o tráfico extremo',
  safety_concern: 'Motivo de seguridad',
  personal_emergency: 'Emergencia personal',
  too_far: 'El punto quedaba muy lejos',
  price_disagreement: 'Desacuerdo con la tarifa',
  other: 'Otro motivo',
}

const STATUS_BADGE: Record<string, string> = {
  pending: 'bg-yellow-100 text-yellow-700',
  approved: 'bg-green-100 text-green-700',
  rejected: 'bg-red-100 text-red-700',
  none: 'bg-gray-100 text-gray-600',
}
const STATUS_LABEL: Record<string, string> = {
  pending: 'Pendiente de revisión',
  approved: 'Devuelta',
  rejected: 'Penalidad mantenida',
  none: 'Sin penalidad',
}

type StatusFilter = 'pending' | 'approved' | 'rejected' | 'all'

export function CancellationsPage() {
  const queryClient = useQueryClient()
  const [status, setStatus] = useState<StatusFilter>('pending')
  // Error de una acción (revisar); el de carga sale de la propia consulta.
  const [actionError, setActionError] = useState<string | null>(null)
  const [flash, setFlash] = useState<string | null>(null)
  const [reviewingId, setReviewingId] = useState<string | null>(null)
  const reviewingRef = useRef<string | null>(null)

  // Ronda 287: antes un `requestSeq` descartaba respuestas viejas al cambiar de
  // filtro. Con una clave por filtro, React Query ya entrega solo la del filtro
  // actual.
  const filters = { status, pageSize: 100 }
  const cancellationsQuery = useQuery({
    queryKey: queryKeys.cancellations.list(filters),
    queryFn: () => adminApi.listCancellations(filters),
  })
  const items = cancellationsQuery.data?.cancellations ?? []
  const total = cancellationsQuery.data?.total ?? 0
  const loading = cancellationsQuery.isPending
  const loadError = cancellationsQuery.isError
    ? (cancellationsQuery.error instanceof AdminApiError ? cancellationsQuery.error.message : 'Error cargando cancelaciones')
    : null
  const error = actionError ?? loadError

  useEffect(() => {
    if (!flash) return
    const t = setTimeout(() => setFlash(null), 5000)
    return () => clearTimeout(t)
  }, [flash])

  const review = async (item: AdminCancellation, decision: 'approved' | 'rejected') => {
    if (reviewingRef.current) return

    let notes: string | undefined
    if (decision === 'rejected') {
      const r = window.prompt(
        `¿Por qué se mantiene la penalidad de S/ ${item.penaltyAmount.toFixed(2)}?\n\n` +
        'El conductor verá este mensaje.',
      )
      if (!r?.trim()) return
      notes = r.trim()
    } else {
      const ok = window.confirm(
        `¿Devolver S/ ${item.penaltyAmount.toFixed(2)} a ${item.driver.fullName ?? 'el conductor'}?\n\n` +
        'Se abonará a su billetera y recibirá una notificación.',
      )
      if (!ok) return
      const r = window.prompt('Nota interna (opcional):')
      notes = r?.trim() || undefined
    }

    reviewingRef.current = item.rideId
    setReviewingId(item.rideId)
    try {
      const res = await adminApi.reviewCancellation(item.rideId, { decision, notes })
      setFlash(
        decision === 'approved'
          ? `Se devolvieron S/ ${res.refunded.toFixed(2)} a ${item.driver.fullName ?? 'el conductor'}.`
          : 'Penalidad confirmada. Se notificó al conductor.',
      )
      await queryClient.invalidateQueries({ queryKey: queryKeys.cancellations.all })
    } catch (err) {
      setActionError(err instanceof AdminApiError ? err.message : 'Error registrando la decisión')
    } finally {
      reviewingRef.current = null
      setReviewingId(null)
    }
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Cancelaciones</h1>
        <p className="text-sm text-gray-500 mt-1">
          Penalidades cobradas a conductores por cancelar viajes aceptados. Revisa el motivo y decide si se les devuelve.
        </p>
      </div>

      {flash && (
        <div className="p-3 rounded-lg bg-green-50 border border-green-200 text-sm text-green-700 flex items-center gap-2">
          <CheckCircle2 className="w-4 h-4" /> {flash}
        </div>
      )}
      {error && (
        <div className="p-3 rounded-lg bg-red-50 border border-red-200 text-sm text-red-700 flex items-center justify-between gap-2">
          <span className="flex items-center gap-2"><AlertCircle className="w-4 h-4" /> {error}</span>
          {actionError && (
            <button type="button" onClick={() => setActionError(null)} className="text-xs text-red-600 hover:text-red-800">Cerrar</button>
          )}
        </div>
      )}

      <div className="bg-white rounded-xl border border-gray-200 p-4 flex items-center gap-3">
        <select
          value={status}
          onChange={(e) => setStatus(e.target.value as StatusFilter)}
          className="border border-gray-200 rounded-lg px-3 py-2 text-sm"
        >
          <option value="pending">Pendientes{status === 'pending' ? ` (${total})` : ''}</option>
          <option value="approved">Devueltas{status === 'approved' ? ` (${total})` : ''}</option>
          <option value="rejected">Mantenidas{status === 'rejected' ? ` (${total})` : ''}</option>
          <option value="all">Todas{status === 'all' ? ` (${total})` : ''}</option>
        </select>
        <button type="button" onClick={() => void cancellationsQuery.refetch()} className="text-xs text-gray-600 hover:text-gray-900">
          Recargar
        </button>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        {loading ? (
          <div className="p-12 text-center text-gray-500 flex items-center justify-center gap-2">
            <Loader2 className="w-4 h-4 animate-spin" /> Cargando...
          </div>
        ) : items.length === 0 ? (
          <div className="p-12 text-center text-gray-500">
            <Ban className="w-10 h-10 mx-auto mb-3 text-gray-300" />
            No hay cancelaciones en esta categoría
          </div>
        ) : (
          <ul className="divide-y divide-gray-100">
            {items.map((c) => (
              <li key={c.rideId} className="p-4">
                <div className="flex items-start gap-4 flex-wrap">
                  <Avatar name={c.driver.fullName ?? undefined} src={pickPhotoUrl(c.driver.photoUrl)} />
                  <div className="flex-1 min-w-[220px]">
                    <div className="flex items-center gap-2 flex-wrap">
                      <span className="font-medium text-gray-900">{c.driver.fullName ?? '(sin nombre)'}</span>
                      <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${STATUS_BADGE[c.reviewStatus] ?? ''}`}>
                        {STATUS_LABEL[c.reviewStatus] ?? c.reviewStatus}
                      </span>
                    </div>
                    <div className="text-xs text-gray-500 mt-0.5">
                      {/* Ronda 279: el correo lápida de una cuenta borrada no
                          se enseña; se cae al id, que al menos es buscable. */}
                      {contactLine(c.driver.phone, c.driver.email) || c.driver.id}
                    </div>

                    <div className="mt-2 text-sm text-gray-800">
                      <span className="font-medium">Motivo declarado: </span>
                      {c.reasonCode ? (REASON_LABELS[c.reasonCode] ?? c.reasonCode) : '(sin motivo estructurado)'}
                    </div>
                    {c.reason && (
                      <div className="mt-1 text-sm text-gray-600 italic">“{c.reason}”</div>
                    )}

                    <div className="mt-2 text-xs text-gray-500 flex items-start gap-1">
                      <MapPin className="w-3 h-3 mt-0.5 flex-shrink-0" />
                      <span>
                        {c.pickupAddress ?? '—'} → {c.destinationAddress ?? '—'}
                      </span>
                    </div>
                    <div className="mt-1 text-xs text-gray-400">
                      Pasajero: {c.passengerName ?? '—'} · Tarifa estimada: {c.estimatedFare !== null ? `S/ ${c.estimatedFare.toFixed(2)}` : '—'} · <DateTime value={c.cancelledAt ?? c.createdAt} />
                    </div>

                    {c.reviewStatus !== 'pending' && c.reviewNotes && (
                      <div className="mt-2 text-xs text-gray-600 bg-gray-50 rounded p-2">
                        <strong>Nota de revisión:</strong> {c.reviewNotes}
                      </div>
                    )}
                  </div>

                  <div className="text-right flex flex-col items-end gap-2 min-w-[150px]">
                    <div>
                      <div className="text-xs text-gray-500">Penalidad</div>
                      <div className="text-lg font-bold text-gray-900 tabular-nums">
                        S/ {c.penaltyAmount.toFixed(2)}
                      </div>
                    </div>

                    {c.reviewStatus === 'pending' ? (
                      <div className="flex gap-2">
                        <button
                          type="button"
                          onClick={() => void review(c, 'approved')}
                          disabled={reviewingId === c.rideId}
                          className="inline-flex items-center gap-1 px-3 py-1.5 text-xs bg-green-600 text-white rounded hover:bg-green-700 disabled:opacity-60 font-medium"
                          title="El motivo es válido: devolver el dinero al conductor"
                        >
                          {reviewingId === c.rideId
                            ? <Loader2 className="w-3 h-3 animate-spin" />
                            : <RotateCcw className="w-3 h-3" />}
                          Devolver
                        </button>
                        <button
                          type="button"
                          onClick={() => void review(c, 'rejected')}
                          disabled={reviewingId === c.rideId}
                          className="inline-flex items-center gap-1 px-3 py-1.5 text-xs bg-red-600 text-white rounded hover:bg-red-700 disabled:opacity-60 font-medium"
                          title="El motivo no justifica la cancelación: mantener la penalidad"
                        >
                          <XCircle className="w-3 h-3" />
                          Mantener
                        </button>
                      </div>
                    ) : (
                      <span className="text-xs text-gray-400">
                        Revisado {c.reviewedAt && <DateTime value={c.reviewedAt} />}
                      </span>
                    )}
                  </div>
                </div>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  )
}
