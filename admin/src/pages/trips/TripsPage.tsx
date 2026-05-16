import { useEffect, useState } from 'react'
import { collection, query, orderBy, getDocs, limit } from 'firebase/firestore'
import { httpsCallable } from 'firebase/functions'
import { db, functions } from '../../config/firebase'
import { formatPEN } from '../../utils/currency'
import type { Ride } from '../../types/ride'
import { Loader2, XCircle, AlertCircle, CheckCircle2, X } from 'lucide-react'

const CANCELABLE_STATUSES = [
  'requested',
  'searching_driver',
  'accepted',
  'arrived',
  'in_progress',
  'driver_assigned',
]

const STATUS_BADGE: Record<string, string> = {
  requested: 'bg-yellow-100 text-yellow-800',
  searching_driver: 'bg-yellow-100 text-yellow-800',
  accepted: 'bg-blue-100 text-blue-800',
  driver_assigned: 'bg-blue-100 text-blue-800',
  arrived: 'bg-indigo-100 text-indigo-800',
  in_progress: 'bg-purple-100 text-purple-800',
  completed: 'bg-green-100 text-green-800',
  cancelled: 'bg-red-100 text-red-800',
}

export function TripsPage() {
  const [trips, setTrips] = useState<Ride[]>([])
  const [loading, setLoading] = useState(true)
  const [cancelTarget, setCancelTarget] = useState<Ride | null>(null)

  useEffect(() => { void load() }, [])

  const load = async () => {
    setLoading(true)
    try {
      const snap = await getDocs(query(collection(db, 'rides'), orderBy('createdAt', 'desc'), limit(100)))
      setTrips(snap.docs.map((d) => ({ id: d.id, ...d.data() } as Ride)))
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Viajes</h1>
          <p className="text-sm text-gray-500 mt-1">Historial de viajes recientes</p>
        </div>
        <button
          onClick={load}
          disabled={loading}
          className="px-3 py-1.5 text-sm border border-gray-300 rounded-lg hover:bg-gray-50 disabled:opacity-50"
        >
          Refrescar
        </button>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-gray-50 border-b border-gray-200">
            <tr>
              <th className="text-left px-4 py-3 font-medium text-gray-600">Fecha</th>
              <th className="text-left px-4 py-3 font-medium text-gray-600">Estado</th>
              <th className="text-left px-4 py-3 font-medium text-gray-600">Origen</th>
              <th className="text-left px-4 py-3 font-medium text-gray-600">Destino</th>
              <th className="text-right px-4 py-3 font-medium text-gray-600">Tarifa</th>
              <th className="text-center px-4 py-3 font-medium text-gray-600 w-32">Acciones</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {loading ? (
              <tr><td colSpan={6} className="text-center py-12 text-gray-400">Cargando...</td></tr>
            ) : trips.length === 0 ? (
              <tr><td colSpan={6} className="text-center py-12 text-gray-400">Sin viajes</td></tr>
            ) : trips.map((t) => {
              const date = t.createdAt?.toDate?.() ?? new Date()
              const status = String(t.status ?? '')
              const canCancel = CANCELABLE_STATUSES.includes(status)
              return (
                <tr key={t.id} className="hover:bg-gray-50">
                  <td className="px-4 py-3 text-gray-700 whitespace-nowrap">{date.toLocaleString('es-PE')}</td>
                  <td className="px-4 py-3">
                    <span className={`text-xs px-2 py-0.5 rounded ${STATUS_BADGE[status] ?? 'bg-gray-100 text-gray-700'}`}>
                      {status}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-gray-700 max-w-[200px] truncate">{t.pickupAddress || t.pickup?.address || '—'}</td>
                  <td className="px-4 py-3 text-gray-700 max-w-[200px] truncate">{t.destinationAddress || t.destination?.address || '—'}</td>
                  <td className="px-4 py-3 text-right font-medium text-gray-900">{formatPEN(t.finalFare ?? t.estimatedFare ?? 0)}</td>
                  <td className="px-4 py-3 text-center">
                    {canCancel && (
                      <button
                        onClick={() => setCancelTarget(t)}
                        className="inline-flex items-center gap-1 text-xs px-2 py-1 rounded border border-red-200 text-red-600 hover:bg-red-50"
                      >
                        <XCircle className="w-3 h-3" /> Cancelar
                      </button>
                    )}
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>

      {cancelTarget && (
        <CancelRideModal
          ride={cancelTarget}
          onClose={() => setCancelTarget(null)}
          onCancelled={() => {
            setCancelTarget(null)
            void load()
          }}
        />
      )}
    </div>
  )
}

const CANCEL_REASONS = [
  'Cliente cambió de opinión',
  'Conductor no disponible',
  'Error operativo',
  'Pago fallido',
  'Otro',
]

function CancelRideModal({
  ride,
  onClose,
  onCancelled,
}: {
  ride: Ride
  onClose: () => void
  onCancelled: () => void
}) {
  const [preset, setPreset] = useState<string>('Error operativo')
  const [customReason, setCustomReason] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [success, setSuccess] = useState<string | null>(null)

  const handleSubmit = async () => {
    setError(null)
    const reason = preset === 'Otro' ? customReason.trim() : preset
    if (!reason) {
      setError('Indica una razón')
      return
    }
    setSubmitting(true)
    try {
      const fn = httpsCallable<
        { rideId: string; reason: string },
        { ok: boolean; rideId: string; refundPending: boolean }
      >(functions, 'cancelRideByAdmin')
      const res = await fn({ rideId: ride.id, reason })
      const refundMsg = res.data.refundPending
        ? ' Reembolso pendiente de procesamiento manual.'
        : ''
      setSuccess(`Viaje cancelado ✅${refundMsg}`)
      setTimeout(onCancelled, 1500)
    } catch (err: any) {
      console.error(err)
      setError(err?.message ?? 'Error al cancelar')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-xl shadow-2xl max-w-md w-full">
        <div className="px-5 py-3 border-b border-gray-200 flex items-center justify-between">
          <h2 className="text-base font-semibold text-gray-900">Cancelar viaje</h2>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-700">
            <X className="w-5 h-5" />
          </button>
        </div>
        <div className="p-5 space-y-4">
          <div className="bg-gray-50 border border-gray-200 rounded-lg p-3 text-xs text-gray-600 space-y-1">
            <p><strong>Viaje:</strong> {ride.id.slice(0, 12)}…</p>
            <p><strong>Estado actual:</strong> {String(ride.status)}</p>
            {ride.driverId && <p><strong>Conductor:</strong> {ride.driverId.slice(0, 12)}…</p>}
            <p><strong>Tarifa:</strong> {formatPEN(ride.estimatedFare ?? 0)}</p>
          </div>

          <div>
            <label className="block text-xs font-medium text-gray-700 mb-1">Razón</label>
            <select
              value={preset}
              onChange={(e) => setPreset(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#E31E24]"
            >
              {CANCEL_REASONS.map((r) => (
                <option key={r} value={r}>{r}</option>
              ))}
            </select>
          </div>

          {preset === 'Otro' && (
            <div>
              <label className="block text-xs font-medium text-gray-700 mb-1">Detalle</label>
              <textarea
                value={customReason}
                onChange={(e) => setCustomReason(e.target.value)}
                rows={3}
                placeholder="Explica brevemente la razón..."
                className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#E31E24]"
              />
            </div>
          )}

          {error && (
            <div className="bg-red-50 border border-red-200 rounded-lg p-2.5 flex items-start gap-2 text-xs text-red-700">
              <AlertCircle className="w-4 h-4 mt-0.5 flex-shrink-0" />
              <span>{error}</span>
            </div>
          )}
          {success && (
            <div className="bg-green-50 border border-green-200 rounded-lg p-2.5 flex items-start gap-2 text-xs text-green-700">
              <CheckCircle2 className="w-4 h-4 mt-0.5 flex-shrink-0" />
              <span>{success}</span>
            </div>
          )}
        </div>
        <div className="px-5 py-3 border-t border-gray-200 flex justify-end gap-2 bg-gray-50">
          <button
            onClick={onClose}
            disabled={submitting}
            className="px-4 py-2 border border-gray-300 rounded-lg text-sm text-gray-700 hover:bg-gray-100 disabled:opacity-50"
          >
            Volver
          </button>
          <button
            onClick={handleSubmit}
            disabled={submitting || !!success}
            className="px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg text-sm font-medium disabled:opacity-50 flex items-center gap-2"
          >
            {submitting && <Loader2 className="w-4 h-4 animate-spin" />}
            Cancelar viaje
          </button>
        </div>
      </div>
    </div>
  )
}
