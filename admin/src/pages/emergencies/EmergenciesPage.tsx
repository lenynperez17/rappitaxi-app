import { useEffect, useState } from 'react'
import { Loader2, AlertCircle, MapPin, Phone, AlertTriangle } from 'lucide-react'
import { adminApi, AdminApiError, type AdminEmergency } from '../../lib/adminApi'
import { relativeTime, toDate } from '../../utils/timeFormat'

const TYPE_LABEL: Record<string, string> = {
  panic: 'Pánico', medical: 'Médico', mechanical: 'Mecánico',
  accident: 'Accidente', harassment: 'Acoso', robbery: 'Robo', other: 'Otro',
}

const STATUS_LABEL: Record<string, { bg: string; label: string }> = {
  active:     { bg: 'bg-red-100 text-red-700', label: 'Activa' },
  pending:    { bg: 'bg-yellow-100 text-yellow-700', label: 'Pendiente' },
  dispatched: { bg: 'bg-blue-100 text-blue-700', label: 'Despachada' },
  escalated:  { bg: 'bg-orange-100 text-orange-700', label: 'Escalada' },
  resolved:   { bg: 'bg-green-100 text-green-700', label: 'Resuelta' },
  cancelled:  { bg: 'bg-gray-100 text-gray-700', label: 'Cancelada' },
}

export function EmergenciesPage() {
  const [items, setItems] = useState<AdminEmergency[]>([])
  const [total, setTotal] = useState(0)
  const [loading, setLoading] = useState(true)
  const [status, setStatus] = useState<string>('all')
  const [error, setError] = useState<string | null>(null)
  const [actionError, setActionError] = useState<string | null>(null)

  useEffect(() => {
    if (!actionError) return
    const t = setTimeout(() => setActionError(null), 6000)
    return () => clearTimeout(t)
  }, [actionError])

  const load = async () => {
    setLoading(true); setError(null)
    try {
      const resp = await adminApi.listEmergencies({
        status: status !== 'all' ? status : undefined,
        pageSize: 100,
      })
      setItems(resp.emergencies); setTotal(resp.total)
    } catch (err) {
      setError(err instanceof AdminApiError ? err.message : 'Error cargando emergencias')
    } finally { setLoading(false) }
  }

  useEffect(() => { void load() }, [status])

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Emergencias</h1>
        <p className="text-sm text-gray-500 mt-1">Total: <strong>{total}</strong></p>
      </div>

      {error && (
        <div className="p-3 rounded-lg bg-red-50 border border-red-200 text-sm text-red-700 flex items-center gap-2">
          <AlertCircle className="w-4 h-4" /> {error}
        </div>
      )}
      {actionError && (
        <div className="p-3 rounded-lg bg-red-50 border border-red-200 text-sm text-red-700 flex items-center justify-between gap-2">
          <span className="flex items-center gap-2"><AlertCircle className="w-4 h-4" /> {actionError}</span>
          <button type="button" onClick={() => setActionError(null)} className="text-red-600 hover:text-red-800 text-xs">Cerrar</button>
        </div>
      )}

      <div className="bg-white rounded-xl border border-gray-200 p-4">
        <select value={status} onChange={(e) => setStatus(e.target.value)}
          className="border border-gray-200 rounded-lg px-3 py-2 text-sm">
          <option value="all">Todos los estados</option>
          <option value="active">Activas</option>
          <option value="dispatched">Despachadas</option>
          <option value="escalated">Escaladas</option>
          <option value="resolved">Resueltas</option>
          <option value="cancelled">Canceladas</option>
        </select>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        {loading ? (
          <div className="p-12 text-center text-gray-500 flex items-center justify-center gap-2">
            <Loader2 className="w-4 h-4 animate-spin" /> Cargando...
          </div>
        ) : items.length === 0 ? (
          <div className="p-12 text-center text-gray-500">
            <AlertTriangle className="w-10 h-10 mx-auto mb-3 text-gray-300" />
            No hay emergencias registradas
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-gray-50 text-gray-500 text-xs uppercase">
                <tr>
                  <th className="text-left px-4 py-3">Usuario</th>
                  <th className="text-left px-4 py-3">Tipo</th>
                  <th className="text-left px-4 py-3">Ubicación</th>
                  <th className="text-left px-4 py-3">Estado</th>
                  <th className="text-left px-4 py-3">Reportada</th>
                  <th className="text-right px-4 py-3">Acciones</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {items.map((e) => (
                  <tr key={e.id} className="hover:bg-gray-50">
                    <td className="px-4 py-3">
                      <div className="text-gray-900">{e.userName ?? '—'}</div>
                      {e.userPhone && (
                        <div className="flex items-center gap-1 text-xs text-gray-400">
                          <Phone className="w-3 h-3" /> {e.userPhone}
                        </div>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      <span className="px-2 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-700">
                        {TYPE_LABEL[e.type] ?? e.type}
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      {e.address ? (
                        <div className="flex items-center gap-1 text-xs text-gray-600">
                          <MapPin className="w-3 h-3 text-red-500" />
                          <span className="truncate max-w-[280px]">{e.address}</span>
                        </div>
                      ) : e.latitude && e.longitude ? (
                        <span className="text-xs text-gray-500">
                          {e.latitude.toFixed(5)}, {e.longitude.toFixed(5)}
                        </span>
                      ) : <span className="text-xs text-gray-400">—</span>}
                    </td>
                    <td className="px-4 py-3">
                      <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${
                        STATUS_LABEL[e.status]?.bg ?? 'bg-gray-100 text-gray-700'
                      }`}>
                        {STATUS_LABEL[e.status]?.label ?? e.status}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-xs text-gray-500">
                      {relativeTime(toDate(e.createdAt))}
                    </td>
                    <td className="px-4 py-3 text-right">
                      <EmergencyActions emergency={e} onChanged={load} onError={setActionError} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  )
}

function EmergencyActions({ emergency, onChanged, onError }: {
  emergency: AdminEmergency
  onChanged: () => void | Promise<void>
  onError: (msg: string) => void
}) {
  const [busy, setBusy] = useState(false)
  const isFinal = emergency.status === 'resolved' || emergency.status === 'cancelled'

  const change = async (status: string) => {
    setBusy(true)
    try {
      await adminApi.updateEmergency(emergency.id, { status })
      await onChanged()
    } catch (err) {
      // En un flow de emergencia (accidente/pánico) el silencio es RIESGO.
      // Propagamos el error al padre para mostrar banner visible.
      onError(err instanceof AdminApiError
        ? `Emergencia ${emergency.id.slice(0, 8)}: ${err.message}`
        : 'No se pudo actualizar la emergencia. Reintenta.')
    } finally { setBusy(false) }
  }

  if (isFinal) {
    return <span className="text-xs text-gray-400">Cerrada</span>
  }
  return (
    <div className="inline-flex gap-1">
      {emergency.status !== 'dispatched' && (
        <button onClick={() => void change('dispatched')} disabled={busy}
          className="px-2 py-1 rounded bg-blue-50 text-blue-700 text-xs font-medium hover:bg-blue-100 disabled:opacity-50">
          Despachar
        </button>
      )}
      <button onClick={() => void change('resolved')} disabled={busy}
        className="px-2 py-1 rounded bg-green-50 text-green-700 text-xs font-medium hover:bg-green-100 disabled:opacity-50">
        Resolver
      </button>
      <button onClick={() => void change('cancelled')} disabled={busy}
        className="px-2 py-1 rounded bg-gray-100 text-gray-700 text-xs font-medium hover:bg-gray-200 disabled:opacity-50">
        Cancelar
      </button>
    </div>
  )
}
