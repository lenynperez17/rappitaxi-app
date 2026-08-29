import { useEffect, useRef, useState } from 'react'
import { Link } from 'react-router-dom'
import { Loader2, AlertCircle, Route, Search, MapPin, MapPinned, XCircle, CheckCircle2 } from 'lucide-react'
import { adminApi, AdminApiError, type AdminTrip } from '../../lib/adminApi'
import { formatPEN } from '../../utils/currency'
import { DateTime } from '../../components/DateTime'

const STATUS_LABEL: Record<string, string> = {
  requested: 'Solicitado', searching: 'Buscando', accepted: 'Aceptado',
  on_way: 'En camino', arrived: 'Llegó', in_progress: 'En curso',
  completed: 'Completado', cancelled: 'Cancelado', no_drivers: 'Sin conductores',
}
const STATUS_BADGES: Record<string, string> = {
  completed: 'bg-green-100 text-green-700',
  in_progress: 'bg-blue-100 text-blue-700',
  cancelled: 'bg-red-100 text-red-700',
  requested: 'bg-yellow-100 text-yellow-700',
  searching: 'bg-yellow-100 text-yellow-700',
  accepted: 'bg-purple-100 text-purple-700',
  on_way: 'bg-purple-100 text-purple-700',
  arrived: 'bg-purple-100 text-purple-700',
  no_drivers: 'bg-gray-100 text-gray-700',
}

/**
 * Ronda 283: estados en los que un viaje sigue vivo y, por tanto, se puede
 * cerrar a mano. El resto —completado, cancelado, sin conductores— ya terminó
 * y el backend rechazaría la cancelación.
 */
const ESTADOS_ABIERTOS = new Set([
  'requested', 'searching', 'accepted', 'on_way', 'arrived', 'in_progress',
])

export function TripsPage() {
  const [trips, setTrips] = useState<AdminTrip[]>([])
  const [total, setTotal] = useState(0)
  const [loading, setLoading] = useState(true)
  const [status, setStatus] = useState<string>('all')
  const [search, setSearch] = useState('')
  const [error, setError] = useState<string | null>(null)
  // Ronda 283: qué viaje se está cerrando, para no permitir dos clics.
  const [cerrando, setCerrando] = useState<string | null>(null)
  const [flash, setFlash] = useState<{ kind: 'ok' | 'err'; msg: string } | null>(null)

  // Ronda 112: request id para descartar respuestas caducas (mismo patrón
  // que DriversPage Ronda 111). Antes: mount inicial disparaba 2 loads
  // (status + debounced search) → race con respuestas fuera de orden.
  const requestSeq = useRef(0)

  const load = async () => {
    const seq = ++requestSeq.current
    setLoading(true); setError(null)
    try {
      const resp = await adminApi.listTrips({
        status: status !== 'all' ? status : undefined,
        search: search || undefined,
        pageSize: 100,
      })
      if (seq !== requestSeq.current) return
      setTrips(resp.trips); setTotal(resp.total)
    } catch (err) {
      if (seq !== requestSeq.current) return
      setError(err instanceof AdminApiError ? err.message : 'Error cargando viajes')
      setTrips([])
    } finally { if (seq === requestSeq.current) setLoading(false) }
  }

  /**
   * Cierra un viaje que se quedó a medias.
   *
   * Se confirma antes porque esto le llega al pasajero y al conductor: no es
   * una operación de limpieza interna, es dar un viaje por terminado.
   */
  const cerrarViaje = async (trip: AdminTrip) => {
    const quien = trip.passengerName ?? trip.passengerPhone ?? 'este pasajero'
    const ok = window.confirm(
      `¿Cerrar el viaje de ${quien}?\n\n` +
      `Estado actual: ${STATUS_LABEL[trip.status] ?? trip.status}\n\n` +
      'Quedará como cancelado y tanto el pasajero como el conductor dejarán de verlo activo.',
    )
    if (!ok || cerrando) return

    setCerrando(trip.id)
    setFlash(null)
    try {
      await adminApi.cancelTrip(trip.id, 'Cerrado por el administrador desde el panel.')
      setFlash({ kind: 'ok', msg: 'Viaje cerrado.' })
      await load()
    } catch (err) {
      setFlash({
        kind: 'err',
        msg: err instanceof AdminApiError ? err.message : 'No se pudo cerrar el viaje',
      })
    } finally {
      setCerrando(null)
    }
  }

  useEffect(() => {
    if (!flash) return
    const t = setTimeout(() => setFlash(null), 4000)
    return () => clearTimeout(t)
  }, [flash])

  // Ronda 214: un solo useEffect en vez de dos (evita doble fetch en mount).
  useEffect(() => {
    const t = setTimeout(() => void load(), search ? 350 : 0)
    return () => clearTimeout(t)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [status, search])

  return (
    <div className="space-y-6">
      {/* Ronda 270: ver nota en InvoicesPage. Aquí además la etiqueta era la
          más larga del panel y se acortaba sola en pantallas estrechas. */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="min-w-0">
          <h1 className="text-2xl font-bold text-gray-900">Viajes</h1>
          <p className="text-sm text-gray-500 mt-1">Total: <strong>{total}</strong></p>
        </div>
        <Link
          to="/map"
          className="inline-flex items-center gap-2 px-4 py-2 bg-[#E31E24] hover:bg-[#B5181D] text-white text-sm font-semibold rounded-lg flex-shrink-0 whitespace-nowrap"
        >
          <MapPinned className="w-4 h-4" />
          <span className="hidden sm:inline">Nuevo viaje en el mapa</span>
          <span className="sm:hidden">Nuevo viaje</span>
        </Link>
      </div>

      {error && (
        <div className="p-3 rounded-lg bg-red-50 border border-red-200 text-sm text-red-700 flex items-center gap-2">
          <AlertCircle className="w-4 h-4" /> {error}
        </div>
      )}

      {flash && (
        <div className={`p-3 rounded-lg border text-sm flex items-center gap-2 ${
          flash.kind === 'ok'
            ? 'bg-green-50 border-green-200 text-green-700'
            : 'bg-red-50 border-red-200 text-red-700'
        }`}>
          {flash.kind === 'ok' ? <CheckCircle2 className="w-4 h-4" /> : <AlertCircle className="w-4 h-4" />}
          {flash.msg}
        </div>
      )}

      <div className="bg-white rounded-xl border border-gray-200 p-4 flex flex-col md:flex-row gap-3">
        <div className="flex-1 relative">
          <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input value={search} onChange={(e) => setSearch(e.target.value)}
            placeholder="Buscar por dirección..." type="text"
            className="w-full pl-10 pr-3 py-2 border border-gray-200 rounded-lg text-sm" />
        </div>
        <select value={status} onChange={(e) => setStatus(e.target.value)}
          className="border border-gray-200 rounded-lg px-3 py-2 text-sm">
          <option value="all">Todos los estados</option>
          <option value="requested">Solicitados</option>
          <option value="in_progress">En curso</option>
          <option value="completed">Completados</option>
          <option value="cancelled">Cancelados</option>
        </select>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        {loading ? (
          <div className="p-12 text-center text-gray-500 flex items-center justify-center gap-2">
            <Loader2 className="w-4 h-4 animate-spin" /> Cargando viajes...
          </div>
        ) : trips.length === 0 ? (
          <div className="p-12 text-center text-gray-500">
            <Route className="w-10 h-10 mx-auto mb-3 text-gray-300" />
            No hay viajes registrados
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-gray-50 text-gray-500 text-xs uppercase">
                <tr>
                  <th className="text-left px-4 py-3">Pasajero</th>
                  <th className="text-left px-4 py-3">Conductor</th>
                  <th className="text-left px-4 py-3">Ruta</th>
                  <th className="text-right px-4 py-3">Tarifa</th>
                  <th className="text-left px-4 py-3">Estado</th>
                  <th className="text-left px-4 py-3">Creado</th>
                  {/* Ronda 283: hasta ahora la tabla era solo de lectura, así
                      que un viaje colgado no se podía cerrar desde ningún
                      sitio. */}
                  <th className="text-right px-4 py-3">Acciones</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {trips.map((t) => (
                  <tr key={t.id} className="hover:bg-gray-50">
                    <td className="px-4 py-3">
                      <div className="text-gray-900">{t.passengerName ?? '—'}</div>
                      <div className="text-xs text-gray-400">{t.passengerPhone ?? ''}</div>
                    </td>
                    <td className="px-4 py-3">
                      <div className="text-gray-900">{t.driverName ?? '—'}</div>
                      <div className="text-xs text-gray-400">{t.driverPhone ?? ''}</div>
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-1 text-xs text-gray-600">
                        <MapPin className="w-3 h-3 text-green-500" />
                        <span className="truncate max-w-[240px]">{t.pickupAddress ?? '—'}</span>
                      </div>
                      <div className="flex items-center gap-1 text-xs text-gray-600">
                        <MapPin className="w-3 h-3 text-red-500" />
                        <span className="truncate max-w-[240px]">{t.destinationAddress ?? '—'}</span>
                      </div>
                    </td>
                    <td className="px-4 py-3 text-right font-medium">
                      {t.finalFare != null ? formatPEN(t.finalFare) : t.estimatedFare != null ? formatPEN(t.estimatedFare) : '—'}
                    </td>
                    <td className="px-4 py-3">
                      <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${
                        STATUS_BADGES[t.status] ?? 'bg-gray-100 text-gray-700'
                      }`}>
                        {STATUS_LABEL[t.status] ?? t.status}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-xs text-gray-500">
                      <DateTime value={t.createdAt} />
                    </td>
                    <td className="px-4 py-3 text-right">
                      {ESTADOS_ABIERTOS.has(t.status) ? (
                        <button
                          onClick={() => void cerrarViaje(t)}
                          disabled={cerrando !== null}
                          className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg border border-red-200 text-red-700 text-xs font-medium hover:bg-red-50 disabled:opacity-40 disabled:cursor-not-allowed whitespace-nowrap"
                        >
                          {cerrando === t.id
                            ? <Loader2 className="w-3 h-3 animate-spin" />
                            : <XCircle className="w-3 h-3" />}
                          Cerrar
                        </button>
                      ) : (
                        <span className="text-xs text-gray-300">—</span>
                      )}
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

