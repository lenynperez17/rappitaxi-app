import { useEffect, useState } from 'react'
import { Loader2, CreditCard, TrendingUp, AlertCircle } from 'lucide-react'
import { adminApi, AdminApiError, type AdminStats, type AdminRecharge } from '../../lib/adminApi'
import { formatPEN } from '../../utils/currency'
import { relativeTime, toDate } from '../../utils/timeFormat'

const METHOD_LABEL: Record<string, string> = {
  cash: 'Efectivo', transfer: 'Transferencia', mercadopago: 'MercadoPago',
  yape: 'Yape', plin: 'Plin', admin_manual: 'Manual (admin)', other: 'Otro',
}

export function FinancialPage() {
  const [stats, setStats] = useState<AdminStats | null>(null)
  const [recharges, setRecharges] = useState<AdminRecharge[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    void (async () => {
      try {
        const [s, r] = await Promise.all([
          adminApi.getStats(),
          adminApi.listRecharges({ status: 'completed', pageSize: 50 }),
        ])
        setStats(s); setRecharges(r.recharges); setError(null)
      } catch (e) {
        setError(
          e instanceof AdminApiError
            ? `Error cargando datos financieros: ${e.message || e.code}`
            : 'Error cargando datos financieros (revisa tu conexión)',
        )
      } finally { setLoading(false) }
    })()
  }, [])

  if (loading) return (
    <div className="flex items-center justify-center h-64 text-gray-500">
      <Loader2 className="w-5 h-5 animate-spin mr-2" /> Cargando datos financieros...
    </div>
  )

  if (error && !stats) return (
    <div className="space-y-4">
      <h1 className="text-2xl font-bold text-gray-900">Financiero</h1>
      <div className="p-3 rounded-lg bg-red-50 border border-red-200 text-sm text-red-700 flex items-center gap-2">
        <AlertCircle className="w-4 h-4" /> {error}
      </div>
    </div>
  )

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Financiero</h1>
        <p className="text-sm text-gray-500 mt-1">Recargas y transacciones aprobadas</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <StatCard label="Recargas hoy" value={formatPEN(stats?.recharges.today ?? 0)} />
        <StatCard label="Recargas del mes" value={formatPEN(stats?.recharges.month ?? 0)} highlight />
        <StatCard label="Total histórico" value={formatPEN(stats?.recharges.total ?? 0)} />
      </div>

      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        <div className="px-4 py-3 border-b border-gray-100 flex items-center gap-2">
          <TrendingUp className="w-4 h-4 text-green-600" />
          <h3 className="font-semibold text-gray-900">Últimas 50 recargas aprobadas</h3>
        </div>
        {recharges.length === 0 ? (
          <div className="p-8 text-center text-gray-500">
            <CreditCard className="w-8 h-8 mx-auto mb-2 text-gray-300" />
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
                    <td className="px-4 py-3 text-xs text-gray-500">{relativeTime(toDate(r.createdAt))}</td>
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

function StatCard({ label, value, highlight = false }: { label: string; value: string; highlight?: boolean }) {
  return (
    <div className={`rounded-xl border p-6 ${highlight ? 'bg-orange-50 border-orange-200' : 'bg-white border-gray-200'}`}>
      <div className="text-xs uppercase text-gray-500 font-medium">{label}</div>
      <div className={`text-2xl font-bold mt-2 ${highlight ? 'text-orange-700' : 'text-gray-900'}`}>{value}</div>
    </div>
  )
}
