import { useEffect, useState } from 'react'
import { Users, Car, Route, CreditCard, TrendingUp, AlertCircle, Loader2, AlertTriangle } from 'lucide-react'
import { adminApi, AdminApiError, type AdminStats } from '../lib/adminApi'
import { formatPEN } from '../utils/currency'

export function DashboardPage() {
  const [stats, setStats] = useState<AdminStats | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    void (async () => {
      try {
        const s = await adminApi.getStats()
        setStats(s)
      } catch (err) {
        setError(err instanceof AdminApiError ? err.message : 'Error cargando estadísticas')
      } finally { setLoading(false) }
    })()
  }, [])

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64 text-gray-500">
        <Loader2 className="w-5 h-5 animate-spin mr-2" /> Cargando dashboard...
      </div>
    )
  }

  if (error || !stats) {
    return (
      <div className="p-4 bg-red-50 border border-red-200 rounded-lg text-red-700 flex items-center gap-2">
        <AlertCircle className="w-5 h-5" /> {error ?? 'Error'}
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Inicio</h1>
        <p className="text-sm text-gray-500 mt-1">Resumen general del día · automáticamente actualizado</p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <StatCard icon={Users} label="Usuarios" value={stats.users.total.toString()}
          sub={`${stats.users.active} activos · ${stats.users.suspended} suspendidos`}
          iconClass="bg-blue-100 text-blue-600" />
        <StatCard icon={Car} label="Conductores" value={(stats.users.drivers + stats.users.dual).toString()}
          sub={`${stats.users.drivers} solo · ${stats.users.dual} duales`}
          iconClass="bg-orange-100 text-orange-600" />
        <StatCard icon={Route} label="Viajes hoy" value={stats.trips.today.toString()}
          sub={`${stats.trips.completed} ${stats.trips.completed === 1 ? 'completado' : 'completados'} en total`}
          iconClass="bg-green-100 text-green-600" />
        <StatCard icon={CreditCard} label="Recargas mes" value={formatPEN(stats.recharges.month)}
          sub={`Hoy: ${formatPEN(stats.recharges.today)}`}
          iconClass="bg-purple-100 text-purple-600" />
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="bg-white rounded-xl border border-gray-200 p-6">
          <h3 className="font-semibold text-gray-900 mb-4 flex items-center gap-2">
            <TrendingUp className="w-4 h-4 text-green-600" /> Actividad
          </h3>
          <dl className="space-y-2 text-sm">
            <Row label="Total pasajeros" value={stats.users.passengers} />
            <Row label="Total conductores" value={stats.users.drivers} />
            <Row label="Usuarios duales" value={stats.users.dual} />
            <Row label="Administradores" value={stats.users.admins} />
            <Row label="Viajes totales" value={stats.trips.total} />
            <Row label="Viajes cancelados" value={stats.trips.cancelled} />
          </dl>
        </div>
        <div className="bg-white rounded-xl border border-gray-200 p-6">
          <h3 className="font-semibold text-gray-900 mb-4 flex items-center gap-2">
            <AlertTriangle className="w-4 h-4 text-red-500" /> Alertas
          </h3>
          <div className="space-y-3">
            <AlertBox count={stats.emergencies.active} label="Emergencias activas" color="red" />
            <AlertBox count={stats.users.suspended} label="Usuarios suspendidos" color="orange" />
          </div>
        </div>
      </div>
    </div>
  )
}

function StatCard({ icon: Icon, label, value, sub, iconClass }: {
  icon: React.ElementType; label: string; value: string; sub?: string; iconClass: string
}) {
  return (
    <div className="bg-white rounded-xl border border-gray-200 p-5">
      <div className="flex items-center gap-3">
        <div className={`w-10 h-10 rounded-lg flex items-center justify-center ${iconClass}`}>
          <Icon className="w-5 h-5" />
        </div>
        <div>
          <div className="text-xs text-gray-500 uppercase">{label}</div>
          <div className="text-xl font-bold text-gray-900">{value}</div>
        </div>
      </div>
      {sub && <p className="mt-3 text-xs text-gray-500">{sub}</p>}
    </div>
  )
}

function Row({ label, value }: { label: string; value: number }) {
  return (
    <div className="flex items-center justify-between border-b border-gray-100 pb-2 last:border-b-0 last:pb-0">
      <dt className="text-gray-600">{label}</dt>
      <dd className="font-semibold text-gray-900">{value}</dd>
    </div>
  )
}

function AlertBox({ count, label, color }: { count: number; label: string; color: 'red' | 'orange' }) {
  const colors = color === 'red'
    ? 'bg-red-50 border-red-200 text-red-700'
    : 'bg-orange-50 border-orange-200 text-orange-700'
  return (
    <div className={`p-3 rounded-lg border ${colors} flex items-center justify-between`}>
      <span className="text-sm font-medium">{label}</span>
      <span className="text-xl font-bold">{count}</span>
    </div>
  )
}
