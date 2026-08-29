import { useEffect, useRef, useState } from 'react'
import { Link } from 'react-router-dom'
import {
  Users, Car, Route, CreditCard, TrendingUp, AlertCircle, Loader2, AlertTriangle,
  Siren, Clock, RadioTower, FileWarning, ChevronRight, ShieldCheck,
} from 'lucide-react'
import { adminApi, AdminApiError, type AdminStats } from '../lib/adminApi'
import { formatPEN } from '../utils/currency'

/**
 * Ronda 283 — el Inicio contaba el pasado y callaba el presente.
 *
 * Mostraba totales acumulados (cuántos usuarios hay, cuántos viajes hubo,
 * cuántos se cancelaron) y ni una sola cosa sobre el estado del servicio en
 * este momento. Con esa pantalla no se podía responder a "¿hay algo que
 * atender ahora?", que es la única pregunta que se le hace a una pantalla de
 * inicio. Tres emergencias llevaban abiertas 26 y 50 días y aparecían como un
 * número gris junto a "Usuarios suspendidos: 0", con el mismo peso visual.
 *
 * Además nada era pinchable: se veía un número alarmante y no había forma de
 * llegar a lo que había detrás.
 *
 * Ahora la pantalla se lee de arriba abajo por urgencia:
 *   1. Lo que requiere una acción — solo aparece si existe de verdad.
 *   2. Cómo está el servicio ahora mismo.
 *   3. Los totales de siempre, que siguen siendo útiles como contexto.
 *
 * Y todo lleva al módulo correspondiente.
 */

/** Un viaje sin cerrar más de una hora ya no es actividad: está colgado. */
const MINUTOS_VIAJE_COLGADO = 60

const REFRESCO_MS = 30_000

export function DashboardPage() {
  const [stats, setStats] = useState<AdminStats | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [actualizado, setActualizado] = useState<Date | null>(null)
  // Ronda 283: el subtítulo llevaba desde siempre diciendo "automáticamente
  // actualizado" y no había ninguna actualización automática — se cargaba una
  // vez al entrar y ahí se quedaba. O se cumple o no se dice; se cumple.
  const montado = useRef(true)

  useEffect(() => {
    montado.current = true

    const cargar = async () => {
      try {
        const s = await adminApi.getStats()
        if (!montado.current) return
        setStats(s)
        setActualizado(new Date())
        setError(null)
      } catch (err) {
        if (!montado.current) return
        // Si ya había datos en pantalla no se borran por un fallo puntual de
        // red: es peor quedarse sin nada que ver algo de hace treinta segundos.
        setError(err instanceof AdminApiError ? err.message : 'Error cargando estadísticas')
      } finally {
        if (montado.current) setLoading(false)
      }
    }

    void cargar()
    const t = setInterval(() => void cargar(), REFRESCO_MS)
    return () => {
      montado.current = false
      clearInterval(t)
    }
  }, [])

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64 text-gray-500">
        <Loader2 className="w-5 h-5 animate-spin mr-2" /> Cargando dashboard...
      </div>
    )
  }

  if (!stats) {
    return (
      <div className="p-4 bg-red-50 border border-red-200 rounded-lg text-red-700 flex items-center gap-2">
        <AlertCircle className="w-5 h-5" /> {error ?? 'Error'}
      </div>
    )
  }

  const viajeColgado = stats.ahora.oldestActiveRideMinutes >= MINUTOS_VIAJE_COLGADO

  // Solo lo que existe de verdad. Una lista de avisos con ceros enseña a la
  // gente a no mirarla.
  const atencion = [
    stats.emergencies.active > 0 && {
      key: 'sos',
      icon: Siren,
      to: '/emergencies',
      label: stats.emergencies.active === 1 ? 'Emergencia sin cerrar' : 'Emergencias sin cerrar',
      value: stats.emergencies.active,
      detail: stats.emergencies.oldestDays > 0
        ? `La más antigua lleva ${stats.emergencies.oldestDays} ${stats.emergencies.oldestDays === 1 ? 'día' : 'días'} abierta`
        : 'Abiertas hoy',
      tone: 'red' as const,
    },
    viajeColgado && {
      key: 'colgados',
      icon: Clock,
      to: '/trips',
      label: stats.ahora.ridesActive === 1 ? 'Viaje sin cerrar' : 'Viajes sin cerrar',
      value: stats.ahora.ridesActive,
      detail: `El más antiguo lleva ${formatoDuracion(stats.ahora.oldestActiveRideMinutes)} sin terminar`,
      tone: 'amber' as const,
    },
    stats.pendientes.cancellations > 0 && {
      key: 'cancelaciones',
      icon: FileWarning,
      to: '/cancellations',
      label: 'Cancelaciones por revisar',
      value: stats.pendientes.cancellations,
      detail: 'Tienen penalidad y esperan tu decisión',
      tone: 'amber' as const,
    },
    stats.pendientes.verifications > 0 && {
      key: 'verificaciones',
      icon: ShieldCheck,
      to: '/verifications',
      label: 'Conductores por aprobar',
      value: stats.pendientes.verifications,
      detail: 'Han enviado documentos o vehículo',
      tone: 'amber' as const,
    },
    stats.users.suspended > 0 && {
      key: 'suspendidos',
      icon: AlertTriangle,
      to: '/users?status=suspended',
      label: 'Usuarios suspendidos',
      value: stats.users.suspended,
      detail: 'No pueden entrar a la app',
      tone: 'amber' as const,
    },
  ].filter(Boolean) as Aviso[]

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Inicio</h1>
          <p className="text-sm text-gray-500 mt-1">
            Estado del servicio ahora mismo
            {actualizado && (
              <> · actualizado a las {actualizado.toLocaleTimeString('es-PE', { hour: '2-digit', minute: '2-digit', second: '2-digit' })}</>
            )}
          </p>
        </div>
        {error && (
          <span className="text-xs text-amber-700 bg-amber-50 border border-amber-200 rounded-lg px-2 py-1 inline-flex items-center gap-1">
            <AlertCircle className="w-3 h-3" /> Sin poder actualizar: {error}
          </span>
        )}
      </div>

      {/* 1. Lo que hay que atender. Arriba del todo porque es lo único que
          exige que alguien haga algo, y solo aparece si existe. */}
      {atencion.length > 0 ? (
        <section className="space-y-3">
          <h2 className="text-sm font-semibold text-gray-900 flex items-center gap-2">
            <AlertTriangle className="w-4 h-4 text-red-500" /> Requiere tu atención
          </h2>
          <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-3">
            {atencion.map(({ key, ...a }) => <TarjetaAviso key={key} {...a} />)}
          </div>
        </section>
      ) : (
        <div className="p-4 rounded-xl border border-green-200 bg-green-50 text-green-800 text-sm flex items-center gap-2">
          <ShieldCheck className="w-4 h-4 shrink-0" />
          Nada pendiente: sin emergencias abiertas, sin viajes colgados y sin cancelaciones por revisar.
        </div>
      )}

      {/* 2. Cómo está el servicio en este momento. */}
      <section className="space-y-3">
        <h2 className="text-sm font-semibold text-gray-900 flex items-center gap-2">
          <RadioTower className="w-4 h-4 text-blue-600" /> Ahora mismo
        </h2>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <StatCard
            icon={RadioTower} label="Conductores en línea" to="/map"
            value={stats.ahora.driversOnline.toString()}
            sub={
              stats.ahora.driversOnline === 0
                ? `Nadie puede recibir viajes · ${stats.users.drivers} registrados`
                : `de ${stats.users.drivers} registrados`
            }
            iconClass={stats.ahora.driversOnline === 0
              ? 'bg-red-100 text-red-600'
              : 'bg-green-100 text-green-600'}
          />
          <StatCard
            icon={Route} label="Viajes en curso" to="/trips"
            value={stats.ahora.ridesActive.toString()}
            sub={stats.ahora.ridesActive > 0
              ? `El más antiguo, hace ${formatoDuracion(stats.ahora.oldestActiveRideMinutes)}`
              : 'Ninguno pedido ni en marcha'}
            iconClass={viajeColgado ? 'bg-amber-100 text-amber-600' : 'bg-blue-100 text-blue-600'}
          />
          <StatCard
            icon={Car} label="Viajes hoy" to="/trips"
            value={stats.trips.today.toString()}
            sub={`${stats.trips.completed} ${stats.trips.completed === 1 ? 'completado' : 'completados'} en total`}
            iconClass="bg-green-100 text-green-600"
          />
          <StatCard
            icon={CreditCard} label="Recargas del mes" to="/recharges"
            value={formatPEN(stats.recharges.month)}
            sub={`Hoy: ${formatPEN(stats.recharges.today)}`}
            iconClass="bg-purple-100 text-purple-600"
          />
        </div>
      </section>

      {/* 3. Los totales de siempre. Siguen valiendo como contexto, pero ya no
          son lo primero que se ve. */}
      <section className="space-y-3">
        <h2 className="text-sm font-semibold text-gray-900 flex items-center gap-2">
          <TrendingUp className="w-4 h-4 text-gray-500" /> Acumulado
        </h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="bg-white rounded-xl border border-gray-200 p-6">
            <h3 className="font-semibold text-gray-900 mb-4 flex items-center gap-2 text-sm">
              <Users className="w-4 h-4 text-blue-600" /> Cuentas
            </h3>
            <dl className="space-y-2 text-sm">
              <Row label="Pasajeros" value={stats.users.passengers} to="/users?type=passenger" />
              <Row label="Conductores" value={stats.users.drivers} to="/drivers" />
              <Row label="Administradores" value={stats.users.admins} to="/users?type=admin" />
              <Row label="Total" value={stats.users.total} to="/users" />
            </dl>
          </div>
          <div className="bg-white rounded-xl border border-gray-200 p-6">
            <h3 className="font-semibold text-gray-900 mb-4 flex items-center gap-2 text-sm">
              <Route className="w-4 h-4 text-green-600" /> Viajes
            </h3>
            <dl className="space-y-2 text-sm">
              {/* Sin `?status=`: TripsPage todavía no lee filtros de la URL, y
                  un enlace que promete un filtro y lleva a la lista entera
                  confunde más que no prometer nada. */}
              <Row label="Completados" value={stats.trips.completed} to="/trips" />
              <Row label="Cancelados" value={stats.trips.cancelled} to="/trips" />
              <Row label="Total" value={stats.trips.total} to="/trips" />
            </dl>
          </div>
        </div>
      </section>
    </div>
  )
}

interface Aviso {
  key: string
  icon: React.ElementType
  to: string
  label: string
  value: number
  detail: string
  tone: 'red' | 'amber'
}

/** Minutos a algo que se lee de un vistazo: "3 h 20 min", "2 días". */
function formatoDuracion(minutos: number): string {
  if (minutos < 60) return `${minutos} min`
  const horas = Math.floor(minutos / 60)
  if (horas < 24) {
    const resto = minutos % 60
    return resto > 0 ? `${horas} h ${resto} min` : `${horas} h`
  }
  const dias = Math.floor(horas / 24)
  return `${dias} ${dias === 1 ? 'día' : 'días'}`
}

function TarjetaAviso({ icon: Icon, to, label, value, detail, tone }: Omit<Aviso, 'key'>) {
  const colores = tone === 'red'
    ? 'bg-red-50 border-red-200 hover:border-red-300 text-red-800'
    : 'bg-amber-50 border-amber-200 hover:border-amber-300 text-amber-900'
  return (
    <Link
      to={to}
      className={`p-4 rounded-xl border transition flex items-center gap-3 ${colores}`}
    >
      <Icon className="w-6 h-6 shrink-0" />
      <div className="min-w-0 flex-1">
        <div className="flex items-baseline gap-2">
          <span className="text-2xl font-bold tabular-nums">{value}</span>
          <span className="text-sm font-medium">{label}</span>
        </div>
        <p className="text-xs mt-0.5 opacity-80">{detail}</p>
      </div>
      <ChevronRight className="w-4 h-4 shrink-0 opacity-60" />
    </Link>
  )
}

function StatCard({ icon: Icon, label, value, sub, iconClass, to }: {
  icon: React.ElementType; label: string; value: string; sub?: string
  iconClass: string; to: string
}) {
  return (
    <Link
      to={to}
      className="bg-white rounded-xl border border-gray-200 p-5 block hover:border-gray-300 hover:shadow-sm transition"
    >
      <div className="flex items-center gap-3">
        <div className={`w-10 h-10 rounded-lg flex items-center justify-center shrink-0 ${iconClass}`}>
          <Icon className="w-5 h-5" />
        </div>
        <div className="min-w-0">
          <div className="text-xs text-gray-500 uppercase truncate">{label}</div>
          <div className="text-xl font-bold text-gray-900 tabular-nums">{value}</div>
        </div>
      </div>
      {sub && <p className="mt-3 text-xs text-gray-500">{sub}</p>}
    </Link>
  )
}

function Row({ label, value, to }: { label: string; value: number; to: string }) {
  return (
    <Link
      to={to}
      className="flex items-center justify-between border-b border-gray-100 pb-2 last:border-b-0 last:pb-0 group"
    >
      <dt className="text-gray-600 group-hover:text-gray-900">{label}</dt>
      <dd className="font-semibold text-gray-900 tabular-nums flex items-center gap-1">
        {value}
        <ChevronRight className="w-3 h-3 text-gray-300 group-hover:text-gray-500" />
      </dd>
    </Link>
  )
}
