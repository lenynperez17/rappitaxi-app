import { useEffect, useState } from 'react'
import { Loader2, AlertCircle, CreditCard, Plus, X, CheckCircle2 } from 'lucide-react'
import { adminApi, AdminApiError, type AdminRecharge, type AdminDriver } from '../../lib/adminApi'
import { formatPEN } from '../../utils/currency'
import { relativeTime, toDate } from '../../utils/timeFormat'

const METHOD_LABEL: Record<string, string> = {
  cash: 'Efectivo', transfer: 'Transferencia', mercadopago: 'MercadoPago',
  yape: 'Yape', plin: 'Plin', admin_manual: 'Manual (admin)', other: 'Otro',
}

const STATUS_BADGES: Record<string, string> = {
  completed: 'bg-green-100 text-green-700',
  approved: 'bg-green-100 text-green-700',
  pending: 'bg-yellow-100 text-yellow-700',
  failed: 'bg-red-100 text-red-700',
  rejected: 'bg-red-100 text-red-700',
  refunded: 'bg-purple-100 text-purple-700',
  cancelled: 'bg-gray-100 text-gray-500',
}

const STATUS_LABEL: Record<string, string> = {
  completed: 'Completada',
  approved: 'Aprobada',
  pending: 'Pendiente',
  failed: 'Fallida',
  rejected: 'Rechazada',
  refunded: 'Reembolsada',
  cancelled: 'Cancelada',
}

export function RechargesPage() {
  const [recharges, setRecharges] = useState<AdminRecharge[]>([])
  const [total, setTotal] = useState(0)
  const [loading, setLoading] = useState(true)
  const [showCreate, setShowCreate] = useState(false)
  const [flash, setFlash] = useState<{ kind: 'ok' | 'err'; msg: string } | null>(null)

  const load = async () => {
    setLoading(true)
    try {
      const resp = await adminApi.listRecharges({ pageSize: 100 })
      setRecharges(resp.recharges); setTotal(resp.total)
    } catch (err) {
      setFlash({ kind: 'err', msg: err instanceof AdminApiError ? err.message : 'Error cargando recargas' })
    } finally { setLoading(false) }
  }

  useEffect(() => { void load() }, [])
  useEffect(() => {
    if (!flash) return
    const t = setTimeout(() => setFlash(null), 4000)
    return () => clearTimeout(t)
  }, [flash])

  const totalMonto = recharges.reduce((a, r) => r.status === 'completed' ? a + r.amount : a, 0)

  return (
    <div className="space-y-6">
      <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Recargas</h1>
          <p className="text-sm text-gray-500 mt-1">
            Total: <strong>{total}</strong> · Monto acumulado: <strong>{formatPEN(totalMonto)}</strong>
          </p>
        </div>
        <button onClick={() => setShowCreate(true)}
          className="inline-flex items-center gap-2 px-4 py-2 bg-orange-600 text-white rounded-lg hover:bg-orange-700 font-medium shadow-sm">
          <Plus className="w-4 h-4" /> Nueva recarga
        </button>
      </div>

      {flash && (
        <div className={`p-3 rounded-lg border text-sm flex items-center gap-2 ${
          flash.kind === 'ok' ? 'bg-green-50 border-green-200 text-green-700' : 'bg-red-50 border-red-200 text-red-700'
        }`}>
          {flash.kind === 'ok' ? <CheckCircle2 className="w-4 h-4" /> : <AlertCircle className="w-4 h-4" />}
          {flash.msg}
        </div>
      )}

      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        {loading ? (
          <div className="p-12 text-center text-gray-500 flex items-center justify-center gap-2">
            <Loader2 className="w-4 h-4 animate-spin" /> Cargando...
          </div>
        ) : recharges.length === 0 ? (
          <div className="p-12 text-center text-gray-500">
            <CreditCard className="w-10 h-10 mx-auto mb-3 text-gray-300" />
            No hay recargas registradas
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-gray-50 text-gray-500 text-xs uppercase">
                <tr>
                  <th className="text-left px-4 py-3">Conductor</th>
                  <th className="text-right px-4 py-3">Monto</th>
                  <th className="text-left px-4 py-3">Método</th>
                  <th className="text-left px-4 py-3">Estado</th>
                  <th className="text-left px-4 py-3">Referencia</th>
                  <th className="text-left px-4 py-3">Fecha</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {recharges.map((r) => (
                  <tr key={r.id} className="hover:bg-gray-50">
                    <td className="px-4 py-3">
                      <div className="text-gray-900">{r.driverName ?? '—'}</div>
                      <div className="text-xs text-gray-400">{r.driverPhone ?? r.driverEmail ?? ''}</div>
                    </td>
                    <td className="px-4 py-3 text-right font-semibold text-green-600">{formatPEN(r.amount)}</td>
                    <td className="px-4 py-3 text-gray-700">{METHOD_LABEL[r.method] ?? r.method}</td>
                    <td className="px-4 py-3">
                      <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${
                        STATUS_BADGES[r.status] ?? 'bg-gray-100 text-gray-700'
                      }`}>
                        {STATUS_LABEL[r.status] ?? r.status}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-xs text-gray-500">{r.reference ?? '—'}</td>
                    <td className="px-4 py-3 text-xs text-gray-500">{relativeTime(toDate(r.createdAt))}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {showCreate && (
        <CreateRechargeModal
          onClose={() => setShowCreate(false)}
          onCreated={() => {
            setShowCreate(false)
            setFlash({ kind: 'ok', msg: 'Recarga registrada' })
            void load()
          }}
        />
      )}
    </div>
  )
}

function CreateRechargeModal({ onClose, onCreated }: { onClose: () => void; onCreated: () => void }) {
  const [drivers, setDrivers] = useState<AdminDriver[]>([])
  const [driverId, setDriverId] = useState('')
  const [amount, setAmount] = useState('')
  const [method, setMethod] = useState('cash')
  const [reference, setReference] = useState('')
  const [notes, setNotes] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const [driversError, setDriversError] = useState<string | null>(null)
  useEffect(() => {
    void (async () => {
      try {
        const resp = await adminApi.listDrivers({ status: 'active', pageSize: 200 })
        setDrivers(resp.drivers)
        setDriversError(null)
      } catch (e) {
        setDriversError(
          e instanceof AdminApiError
            ? `No se pudieron cargar conductores: ${e.message || e.code}`
            : 'No se pudieron cargar conductores (revisa conexión).',
        )
      }
    })()
  }, [])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError(null)
    const amt = Number(amount)
    if (!driverId) return setError('Selecciona un conductor')
    if (!Number.isFinite(amt) || amt <= 0) return setError('Monto inválido')
    setSubmitting(true)
    try {
      await adminApi.createRecharge({ driverId, amount: amt, method, reference: reference || undefined, notes: notes || undefined })
      onCreated()
    } catch (err) {
      setError(err instanceof AdminApiError ? err.message : 'Error registrando recarga')
    } finally { setSubmitting(false) }
  }

  return (
    <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4" onClick={onClose}>
      <div onClick={(e) => e.stopPropagation()}
        className="bg-white rounded-2xl shadow-xl max-w-lg w-full max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-200">
          <h2 className="text-lg font-semibold text-gray-900">Nueva recarga</h2>
          <button onClick={onClose} className="p-1 hover:bg-gray-100 rounded"><X className="w-5 h-5 text-gray-500" /></button>
        </div>
        <form onSubmit={handleSubmit} className="p-6 space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Conductor</label>
            <select value={driverId} onChange={(e) => setDriverId(e.target.value)}
              className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm">
              <option value="">Selecciona...</option>
              {drivers.map((d) => (
                <option key={d.id} value={d.id}>
                  {d.fullName ?? '(sin nombre)'} · {d.phone ?? d.email ?? d.id.slice(0, 8)}
                </option>
              ))}
            </select>
            {driversError && (
              <p className="text-xs text-red-600 mt-1">{driversError}</p>
            )}
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Monto (S/)</label>
            <input type="number" step="0.01" min="0.01" value={amount} onChange={(e) => setAmount(e.target.value)}
              placeholder="50.00" className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm" />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Método</label>
            <select value={method} onChange={(e) => setMethod(e.target.value)}
              className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm">
              {Object.entries(METHOD_LABEL).map(([v, l]) => <option key={v} value={v}>{l}</option>)}
            </select>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Referencia <span className="text-gray-400">(opcional)</span></label>
            <input value={reference} onChange={(e) => setReference(e.target.value)}
              placeholder="Nro. operación / recibo" className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm" />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Notas <span className="text-gray-400">(opcional)</span></label>
            <textarea value={notes} onChange={(e) => setNotes(e.target.value)} rows={2}
              className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm" />
          </div>
          {error && (
            <div className="p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700 flex items-center gap-2">
              <AlertCircle className="w-4 h-4" /> {error}
            </div>
          )}
          <div className="flex gap-2 pt-4">
            <button type="button" onClick={onClose} disabled={submitting}
              className="flex-1 px-4 py-2 border border-gray-200 rounded-lg text-sm font-medium text-gray-700 hover:bg-gray-50">
              Cancelar
            </button>
            <button type="submit" disabled={submitting}
              className="flex-1 px-4 py-2 bg-orange-600 text-white rounded-lg text-sm font-medium hover:bg-orange-700 disabled:opacity-60 flex items-center justify-center gap-2">
              {submitting && <Loader2 className="w-4 h-4 animate-spin" />}
              Registrar recarga
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
