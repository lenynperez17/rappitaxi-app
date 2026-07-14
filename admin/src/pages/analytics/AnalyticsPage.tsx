import { useEffect, useState } from 'react'
import { BarChart3, Loader2, TrendingUp, Users, Car, Route, CreditCard, AlertCircle } from 'lucide-react'
import { adminApi, AdminApiError, type AdminStats } from '../../lib/adminApi'
import { formatPEN } from '../../utils/currency'

export function AnalyticsPage() {
  const [stats, setStats] = useState<AdminStats | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    void (async () => {
      try {
        setStats(await adminApi.getStats())
        setError(null)
      } catch (e) {
        setError(
          e instanceof AdminApiError
            ? `Error cargando analíticas: ${e.message || e.code}`
            : 'Error cargando analíticas (revisa tu conexión)',
        )
      } finally { setLoading(false) }
    })()
  }, [])

  if (loading) return (
    <div className="flex items-center justify-center h-64 text-gray-500">
      <Loader2 className="w-5 h-5 animate-spin mr-2" /> Cargando analíticas...
    </div>
  )

  if (error && !stats) return (
    <div className="space-y-4">
      <h1 className="text-2xl font-bold text-gray-900">Analíticas</h1>
      <div className="p-3 rounded-lg bg-red-50 border border-red-200 text-sm text-red-700 flex items-center gap-2">
        <AlertCircle className="w-4 h-4" /> {error}
      </div>
    </div>
  )

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Analíticas</h1>
        <p className="text-sm text-gray-500 mt-1">Métricas agregadas en tiempo real</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <Metric icon={Users} label="Total usuarios" value={stats?.users.total ?? 0} color="blue" />
        <Metric icon={Car} label="Conductores + duales" value={(stats?.users.drivers ?? 0) + (stats?.users.dual ?? 0)} color="orange" />
        <Metric icon={Route} label="Viajes completados" value={stats?.trips.completed ?? 0} color="green" />
        <Metric icon={CreditCard} label="Recargas mes" value={formatPEN(stats?.recharges.month ?? 0)} color="purple" />
      </div>

      <div className="bg-white rounded-xl border border-gray-200 p-6 space-y-4">
        <h3 className="font-semibold text-gray-900 flex items-center gap-2">
          <TrendingUp className="w-4 h-4 text-green-600" /> Desempeño operativo
        </h3>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm">
          <Card title="Viajes hoy" value={stats?.trips.today ?? 0} />
          <Card title="Viajes cancelados" value={stats?.trips.cancelled ?? 0} />
          <Card title="Emergencias activas" value={stats?.emergencies.active ?? 0} highlight />
        </div>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 p-8 text-center text-gray-500">
        <BarChart3 className="w-10 h-10 mx-auto mb-3 text-gray-300" />
        Los gráficos históricos se están migrando al nuevo backend
      </div>
    </div>
  )
}

function Metric({ icon: Icon, label, value, color }: {
  icon: React.ElementType; label: string; value: number | string; color: string
}) {
  const bg: Record<string, string> = { blue: 'bg-blue-100 text-blue-600', orange: 'bg-orange-100 text-orange-600', green: 'bg-green-100 text-green-600', purple: 'bg-purple-100 text-purple-600' }
  return (
    <div className="bg-white rounded-xl border border-gray-200 p-5">
      <div className="flex items-center gap-3">
        <div className={`w-10 h-10 rounded-lg flex items-center justify-center ${bg[color]}`}>
          <Icon className="w-5 h-5" />
        </div>
        <div>
          <div className="text-xs text-gray-500 uppercase">{label}</div>
          <div className="text-xl font-bold text-gray-900">{value}</div>
        </div>
      </div>
    </div>
  )
}

function Card({ title, value, highlight = false }: { title: string; value: number; highlight?: boolean }) {
  return (
    <div className={`rounded-lg p-4 ${highlight ? 'bg-red-50 border border-red-200' : 'bg-gray-50 border border-gray-200'}`}>
      <div className="text-xs text-gray-500 uppercase mb-1">{title}</div>
      <div className={`text-2xl font-bold ${highlight ? 'text-red-700' : 'text-gray-900'}`}>{value}</div>
    </div>
  )
}
