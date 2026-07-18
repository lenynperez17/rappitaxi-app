import { useEffect, useMemo, useRef, useState, useCallback } from 'react'
import { MapPin, Loader2, RefreshCw, User, Car, Circle, Route, Plus, X, Search, CheckCircle2, AlertCircle } from 'lucide-react'
import { MapContainer, TileLayer, Marker, Popup, useMapEvents } from 'react-leaflet'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'
import { adminApi, AdminApiError, type AdminUser } from '../../lib/adminApi'
import { relativeTime, toDate } from '../../utils/timeFormat'
import { formatPEN } from '../../utils/currency'

/**
 * Mapa en vivo interactivo con Leaflet.
 * Muestra viajes activos, drivers online y offline en tabs, y permite crear
 * un viaje visualmente con clicks en el mapa (pickup + destino).
 */

// Fix para iconos por default de Leaflet en Vite.
// Ronda 214: antes se cargaban desde unpkg.com — si el CDN caía o se
// bloqueaba (firewalls corporativos), los marcadores desaparecían del mapa
// del admin panel. Ahora se importan desde node_modules y Vite los bundlea
// como assets (URLs con hash, servidos por el propio dominio del admin).
import markerIcon2x from 'leaflet/dist/images/marker-icon-2x.png'
import markerIcon from 'leaflet/dist/images/marker-icon.png'
import markerShadow from 'leaflet/dist/images/marker-shadow.png'
delete (L.Icon.Default.prototype as unknown as { _getIconUrl?: unknown })._getIconUrl
L.Icon.Default.mergeOptions({
  iconRetinaUrl: markerIcon2x,
  iconUrl: markerIcon,
  shadowUrl: markerShadow,
})

const DEFAULT_CENTER: [number, number] = [-12.0464, -77.0428] // Lima
const REFRESH_MS = 10_000

const TRIP_STATUS_LABEL: Record<string, string> = {
  requested: 'Solicitado', searching: 'Buscando', accepted: 'Aceptado',
  on_way: 'En camino', arrived: 'Llegó', in_progress: 'En curso',
}

const TRIP_STATUS_BADGE: Record<string, string> = {
  requested: 'bg-yellow-100 text-yellow-700',
  searching: 'bg-yellow-100 text-yellow-700',
  accepted: 'bg-blue-100 text-blue-700',
  on_way: 'bg-blue-100 text-blue-700',
  arrived: 'bg-purple-100 text-purple-700',
  in_progress: 'bg-green-100 text-green-700',
}

type LiveData = Awaited<ReturnType<typeof adminApi.getLive>>
type Point = { lat: number; lng: number; address: string }

// Iconos custom
const pickupIcon = new L.DivIcon({
  className: 'custom-marker',
  html: `<div style="background:#16A34A;width:24px;height:24px;border-radius:50%;border:3px solid white;box-shadow:0 2px 6px rgba(0,0,0,0.3);display:flex;align-items:center;justify-content:center;color:white;font-weight:bold;font-size:12px;">A</div>`,
  iconSize: [24, 24], iconAnchor: [12, 12],
})
const destIcon = new L.DivIcon({
  className: 'custom-marker',
  html: `<div style="background:#DC2626;width:24px;height:24px;border-radius:50%;border:3px solid white;box-shadow:0 2px 6px rgba(0,0,0,0.3);display:flex;align-items:center;justify-content:center;color:white;font-weight:bold;font-size:12px;">B</div>`,
  iconSize: [24, 24], iconAnchor: [12, 12],
})
const driverOnlineIcon = new L.DivIcon({
  className: 'custom-marker',
  html: `<div style="background:#22C55E;width:18px;height:18px;border-radius:50%;border:2px solid white;box-shadow:0 2px 4px rgba(0,0,0,0.3);"></div>`,
  iconSize: [18, 18], iconAnchor: [9, 9],
})

export function LiveMapPage() {
  const [data, setData] = useState<LiveData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [lastRefresh, setLastRefresh] = useState<Date | null>(null)
  const [tab, setTab] = useState<'trips' | 'online' | 'offline'>('trips')
  const [creating, setCreating] = useState(false)
  const [flash, setFlash] = useState<{ kind: 'ok' | 'err'; msg: string } | null>(null)
  const timerRef = useRef<number | null>(null)

  const load = useCallback(async (): Promise<{ auth401?: boolean }> => {
    try {
      setError(null)
      const resp = await adminApi.getLive()
      setData(resp)
      setLastRefresh(new Date())
      return {}
    } catch (err) {
      const isAuth = err instanceof AdminApiError && (err.status === 401 || err.status === 403)
      setError(err instanceof Error ? err.message : 'Error cargando datos en vivo')
      return { auth401: isAuth }
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    void load()
    // Poll periódico con auto-stop en 401/403 — si el token murió, seguir
    // pegando cada 10s solo llena logs; el guard de auth ya va a redirigir.
    timerRef.current = window.setInterval(async () => {
      const res = await load()
      if (res.auth401 && timerRef.current) {
        window.clearInterval(timerRef.current)
        timerRef.current = null
      }
    }, REFRESH_MS)
    return () => { if (timerRef.current) window.clearInterval(timerRef.current) }
  }, [load])

  useEffect(() => {
    if (!flash) return
    const t = setTimeout(() => setFlash(null), 4000)
    return () => clearTimeout(t)
  }, [flash])

  const counts = data?.counts ?? { activeTrips: 0, onlineDrivers: 0, offlineDrivers: 0 }

  return (
    <div className="h-full flex flex-col relative">
      {/* Barra superior compacta flotante */}
      <div className="absolute top-3 left-3 right-3 lg:right-[26rem] z-[600] pointer-events-none flex items-center justify-between gap-3">
        <div className="pointer-events-auto bg-white/95 backdrop-blur rounded-lg shadow-md border border-gray-200 px-3 py-2 flex items-center gap-3">
          <div>
            <div className="text-sm font-bold text-gray-900 leading-none">Mapa en vivo</div>
            <div className="text-[10px] text-gray-500 leading-none mt-0.5">
              {lastRefresh ? `Actualizado ${lastRefresh.toLocaleTimeString('es-PE')}` : 'Cargando...'}
            </div>
          </div>
          <div className="h-6 w-px bg-gray-200" />
          <span className="text-xs text-gray-600 inline-flex items-center gap-1">
            <Route className="w-3 h-3 text-blue-500" /> {counts.activeTrips}
          </span>
          <span className="text-xs text-gray-600 inline-flex items-center gap-1">
            <Circle className="w-3 h-3 text-green-500 fill-current" /> {counts.onlineDrivers}
          </span>
          <span className="text-xs text-gray-600 inline-flex items-center gap-1">
            <Circle className="w-3 h-3 text-gray-400" /> {counts.offlineDrivers}
          </span>
        </div>
        <div className="pointer-events-auto flex items-center gap-2">
          <button
            onClick={() => void load()}
            className="inline-flex items-center gap-1.5 px-3 py-2 bg-white/95 backdrop-blur border border-gray-200 rounded-lg text-sm text-gray-700 hover:bg-white shadow-md"
          >
            <RefreshCw className="w-4 h-4" /> Refrescar
          </button>
          <button
            onClick={() => setCreating(true)}
            className="inline-flex items-center gap-1.5 px-4 py-2 bg-[#E31E24] hover:bg-[#B5181D] text-white text-sm font-semibold rounded-lg shadow-md"
          >
            <Plus className="w-4 h-4" /> Nuevo viaje
          </button>
        </div>
      </div>

      {/* Flash + error flotantes */}
      {(flash || error) && (
        <div className="absolute top-16 left-1/2 -translate-x-1/2 z-[400] pointer-events-none">
          {flash && (
            <div className={`pointer-events-auto flex items-center gap-3 px-4 py-2 rounded-lg text-sm border shadow-md ${
              flash.kind === 'ok' ? 'bg-green-50 border-green-200 text-green-700' : 'bg-red-50 border-red-200 text-red-700'
            }`}>
              {flash.kind === 'ok' ? <CheckCircle2 className="w-4 h-4" /> : <AlertCircle className="w-4 h-4" />}
              {flash.msg}
            </div>
          )}
          {error && !flash && (
            <div className="pointer-events-auto px-4 py-2 rounded-lg bg-red-50 border border-red-200 text-sm text-red-700 shadow-md">
              {error}
            </div>
          )}
        </div>
      )}

      {/* Mapa + panel lateral en flex */}
      <div className="flex-1 flex overflow-hidden">
        <div className="flex-1 relative bg-gray-100">
          <MapContainer
            center={DEFAULT_CENTER}
            zoom={13}
            style={{ height: '100%', width: '100%' }}
            scrollWheelZoom
            zoomControl={false}
          >
            <TileLayer
              attribution='&copy; OpenStreetMap contributors'
              url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
            />
            {data?.onlineDrivers.filter((d) => d.latitude != null && d.longitude != null).map((d) => (
              <Marker
                key={d.driverId}
                position={[d.latitude!, d.longitude!]}
                icon={driverOnlineIcon}
              >
                <Popup>
                  <div className="text-xs">
                    <div className="font-semibold">{d.fullName ?? '—'}</div>
                    <div>{d.vehicleType} · ★ {d.rating?.toFixed(1) ?? '—'}</div>
                    {d.activeRideId && <div className="text-blue-600 mt-1">En viaje activo</div>}
                  </div>
                </Popup>
              </Marker>
            ))}
            {data?.activeTrips.filter((t) => t.pickupLat != null && t.pickupLng != null).map((t) => (
              <Marker
                key={t.id + '-p'}
                position={[t.pickupLat!, t.pickupLng!]}
                icon={pickupIcon}
              >
                <Popup>
                  <div className="text-xs">
                    <div className="font-semibold">{TRIP_STATUS_LABEL[t.status] ?? t.status}</div>
                    <div>{t.passenger?.fullName ?? '—'}</div>
                    {t.driver?.fullName && <div>Conductor: {t.driver.fullName}</div>}
                  </div>
                </Popup>
              </Marker>
            ))}
          </MapContainer>
        </div>

        <aside className="hidden lg:flex w-[26rem] flex-shrink-0 bg-white border-l border-gray-200 flex-col overflow-hidden">
          <div className="grid grid-cols-3 divide-x divide-gray-100 border-b border-gray-200 text-center">
            <button
              onClick={() => setTab('trips')}
              className={`p-3 flex flex-col items-center gap-1 text-xs transition-colors ${
                tab === 'trips' ? 'bg-blue-50 text-blue-700 border-b-2 border-blue-500' : 'text-gray-500 hover:bg-gray-50'
              }`}
            >
              <Route className="w-4 h-4" />
              <span>En curso · <strong>{counts.activeTrips}</strong></span>
            </button>
            <button
              onClick={() => setTab('online')}
              className={`p-3 flex flex-col items-center gap-1 text-xs transition-colors ${
                tab === 'online' ? 'bg-green-50 text-green-700 border-b-2 border-green-500' : 'text-gray-500 hover:bg-gray-50'
              }`}
            >
              <Circle className="w-4 h-4 fill-current" />
              <span>En línea · <strong>{counts.onlineDrivers}</strong></span>
            </button>
            <button
              onClick={() => setTab('offline')}
              className={`p-3 flex flex-col items-center gap-1 text-xs transition-colors ${
                tab === 'offline' ? 'bg-gray-100 text-gray-700 border-b-2 border-gray-500' : 'text-gray-500 hover:bg-gray-50'
              }`}
            >
              <Circle className="w-4 h-4" />
              <span>Off · <strong>{counts.offlineDrivers}</strong></span>
            </button>
          </div>
          <div className="flex-1 overflow-y-auto">
            {loading && (
              <div className="p-8 text-center">
                <Loader2 className="w-6 h-6 mx-auto animate-spin text-gray-400" />
              </div>
            )}
            {!loading && tab === 'trips' && <ActiveTripsList data={data} />}
            {!loading && tab === 'online' && <OnlineDriversList data={data} />}
            {!loading && tab === 'offline' && <OfflineDriversList data={data} />}
          </div>
        </aside>
      </div>

      {creating && (
        <CreateTripOverlay
          onlineDrivers={data?.onlineDrivers ?? []}
          onClose={() => setCreating(false)}
          onCreated={(fanout) => {
            setCreating(false)
            setFlash({ kind: 'ok', msg: `Viaje creado. ${fanout.notified} conductor(es) notificado(s), ${fanout.fcmSent} push enviado(s).` })
            void load()
          }}
          onError={(msg) => setFlash({ kind: 'err', msg })}
        />
      )}
    </div>
  )
}

// --------------------------------------------------------------------------
// Overlay para crear viaje visualmente
// --------------------------------------------------------------------------
function CreateTripOverlay({
  onlineDrivers,
  onClose,
  onCreated,
  onError,
}: {
  onlineDrivers: LiveData['onlineDrivers']
  onClose: () => void
  onCreated: (fanout: { notified: number; fcmSent: number }) => void
  onError: (msg: string) => void
}) {
  const [step, setStep] = useState<'passenger' | 'pickup' | 'destination' | 'confirm'>('passenger')
  const [passenger, setPassenger] = useState<AdminUser | null>(null)
  const [pickup, setPickup] = useState<Point | null>(null)
  const [destination, setDestination] = useState<Point | null>(null)
  const [driverId, setDriverId] = useState<string>('')
  const [vehicleType, setVehicleType] = useState('car')
  const [paymentMethod, setPaymentMethod] = useState('cash')
  const [fare, setFare] = useState('')
  const [fareEditedManually, setFareEditedManually] = useState(false)
  const [saving, setSaving] = useState(false)

  // Cálculo de tarifa auto según distancia (Haversine)
  const distanceKm = useMemo(() => {
    if (!pickup || !destination) return null
    return haversineKm(pickup.lat, pickup.lng, destination.lat, destination.lng)
  }, [pickup, destination])

  // Ronda 115: recalcular fare cuando cambia el destino, salvo que el admin
  // haya editado manualmente. Antes: la guarda `!fare` bloqueaba el recálculo
  // si el admin cambiaba destino después del primer cómputo → se cobraba
  // tarifa vieja para un recorrido nuevo.
  useEffect(() => {
    if (distanceKm != null && !fareEditedManually) {
      // Tarifa base S/5 + S/2 por km. Ajustable manualmente.
      setFare((5 + distanceKm * 2).toFixed(2))
    }
  }, [distanceKm, fareEditedManually])

  const canSubmit = passenger && pickup && destination && step === 'confirm'

  const submit = async () => {
    if (!passenger || !pickup || !destination) return
    setSaving(true)
    try {
      const resp = await adminApi.createTrip({
        passengerId: passenger.id,
        driverId: driverId || null,
        pickupAddress: pickup.address,
        pickupLat: pickup.lat,
        pickupLng: pickup.lng,
        destinationAddress: destination.address,
        destinationLat: destination.lat,
        destinationLng: destination.lng,
        estimatedFare: fare ? Number(fare) : undefined,
        vehicleType,
        paymentMethod,
      })
      onCreated(resp.fanout)
    } catch (err) {
      onError(err instanceof AdminApiError ? err.message : 'Error creando viaje')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="fixed inset-0 bg-black/60 z-[500] flex items-stretch">
      <div className="ml-auto w-full max-w-[550px] bg-white shadow-2xl flex flex-col">
        <div className="p-4 border-b border-gray-200 flex items-center justify-between">
          <div>
            <h2 className="text-lg font-bold text-gray-900">Crear viaje</h2>
            <p className="text-xs text-gray-500">Directo desde el mapa · 4 pasos</p>
          </div>
          <button onClick={onClose} className="p-2 hover:bg-gray-100 rounded">
            <X className="w-5 h-5 text-gray-500" />
          </button>
        </div>

        <Steps step={step} passenger={passenger} pickup={pickup} destination={destination} onGoto={setStep} />

        <div className="flex-1 min-h-0 overflow-y-auto">
          {step === 'passenger' && (
            <PassengerSearch
              selected={passenger}
              onPick={(p) => { setPassenger(p); setStep('pickup') }}
            />
          )}
          {(step === 'pickup' || step === 'destination') && (
            <MapPicker
              step={step}
              pickup={pickup}
              destination={destination}
              onlineDrivers={onlineDrivers}
              onPick={(p) => {
                if (step === 'pickup') { setPickup(p); setStep('destination') }
                else { setDestination(p); setStep('confirm') }
              }}
            />
          )}
          {step === 'confirm' && (
            <Confirm
              passenger={passenger!}
              pickup={pickup!}
              destination={destination!}
              distanceKm={distanceKm}
              onlineDrivers={onlineDrivers}
              driverId={driverId} onDriverChange={setDriverId}
              vehicleType={vehicleType} onVehicleChange={setVehicleType}
              paymentMethod={paymentMethod} onPaymentChange={setPaymentMethod}
              fare={fare} onFareChange={(v) => { setFare(v); setFareEditedManually(true) }}
            />
          )}
        </div>

        <div className="p-4 border-t border-gray-200 flex items-center gap-3">
          <button
            onClick={() => {
              if (step === 'destination') setStep('pickup')
              else if (step === 'confirm') setStep('destination')
              else if (step === 'pickup') setStep('passenger')
              else onClose()
            }}
            className="flex-1 px-4 py-2 border border-gray-300 rounded-lg text-sm font-medium text-gray-700 hover:bg-gray-50"
          >
            {step === 'passenger' ? 'Cancelar' : 'Atrás'}
          </button>
          {canSubmit && (
            <button
              onClick={() => void submit()}
              disabled={saving}
              className="flex-1 inline-flex items-center justify-center gap-2 px-4 py-2 bg-[#E31E24] hover:bg-[#B5181D] text-white text-sm font-semibold rounded-lg disabled:opacity-50"
            >
              {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Plus className="w-4 h-4" />}
              Crear y notificar
            </button>
          )}
        </div>
      </div>
    </div>
  )
}

function Steps({ step, passenger, pickup, destination, onGoto }: {
  step: 'passenger' | 'pickup' | 'destination' | 'confirm'
  passenger: AdminUser | null
  pickup: Point | null
  destination: Point | null
  onGoto: (s: 'passenger' | 'pickup' | 'destination' | 'confirm') => void
}) {
  const items: Array<{ key: 'passenger' | 'pickup' | 'destination' | 'confirm'; label: string; done: boolean }> = [
    { key: 'passenger', label: 'Pasajero', done: !!passenger },
    { key: 'pickup', label: 'Recojo', done: !!pickup },
    { key: 'destination', label: 'Destino', done: !!destination },
    { key: 'confirm', label: 'Confirmar', done: false },
  ]
  return (
    <div className="px-4 py-3 border-b border-gray-100 flex items-center gap-2">
      {items.map((it, i) => (
        <button
          key={it.key}
          onClick={() => (it.done || it.key === step) && onGoto(it.key)}
          className={`flex-1 flex items-center gap-2 px-2 py-1.5 rounded text-xs font-medium transition-colors ${
            step === it.key ? 'bg-red-50 text-red-700'
              : it.done ? 'bg-green-50 text-green-700'
              : 'bg-gray-50 text-gray-400'
          }`}
        >
          <span className="w-5 h-5 rounded-full flex items-center justify-center text-[10px] font-bold border-2 border-current">
            {it.done ? '✓' : i + 1}
          </span>
          <span className="truncate">{it.label}</span>
        </button>
      ))}
    </div>
  )
}

function PassengerSearch({ selected, onPick }: {
  selected: AdminUser | null
  onPick: (u: AdminUser) => void
}) {
  const [q, setQ] = useState('')
  const [results, setResults] = useState<AdminUser[]>([])
  const [loading, setLoading] = useState(false)
  const [searchError, setSearchError] = useState<string | null>(null)

  useEffect(() => {
    if (q.trim().length < 2) { setResults([]); setSearchError(null); return }
    const t = setTimeout(async () => {
      setLoading(true)
      setSearchError(null)
      try {
        // Traer TODOS los usuarios activos (pasajeros, duales, conductores,
        // admins) — el admin decide. Excluimos solo eliminados/suspendidos.
        const resp = await adminApi.listUsers({
          search: q.trim(),
          pageSize: 25,
          status: 'active',
        })
        setResults(resp.users)
      } catch (e) {
        setResults([])
        setSearchError(
          e instanceof AdminApiError
            ? `Error al buscar: ${e.message || e.code}`
            : 'Error al buscar usuarios (revisa conexión).',
        )
      } finally { setLoading(false) }
    }, 300)
    return () => clearTimeout(t)
  }, [q])

  return (
    <div className="p-4 space-y-3">
      <p className="text-xs text-gray-500">Busca al pasajero por nombre, correo o teléfono</p>
      <div className="relative">
        <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
        <input
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="María, +51999..., @gmail..."
          className="w-full pl-10 pr-3 py-2 border border-gray-300 rounded-lg text-sm"
          autoFocus
        />
      </div>
      {loading && <div className="text-center py-4"><Loader2 className="w-5 h-5 animate-spin mx-auto text-gray-400" /></div>}
      {!loading && searchError && (
        <div className="text-xs text-red-600 bg-red-50 border border-red-200 rounded-lg p-2">
          {searchError}
        </div>
      )}
      {!loading && !searchError && results.length > 0 && (
        <div className="border border-gray-200 rounded-lg divide-y divide-gray-100 max-h-[380px] overflow-y-auto">
          {results.map((u) => (
            <button
              key={u.id}
              onClick={() => onPick(u)}
              className={`w-full p-3 flex items-center gap-3 text-left hover:bg-gray-50 ${selected?.id === u.id ? 'bg-red-50' : ''}`}
            >
              <div className="w-9 h-9 rounded-full bg-blue-100 text-blue-700 flex items-center justify-center text-sm font-semibold">
                {(u.fullName ?? u.email ?? '?').charAt(0).toUpperCase()}
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2">
                  <div className="text-sm font-medium text-gray-900 truncate">{u.fullName ?? '(sin nombre)'}</div>
                  <UserTypeBadge type={u.userType} />
                </div>
                <div className="text-xs text-gray-500 truncate">{u.phone ?? u.email ?? u.id}</div>
              </div>
            </button>
          ))}
        </div>
      )}
      {!loading && q.trim().length >= 2 && results.length === 0 && (
        <div className="text-center py-8 text-sm text-gray-500">Sin resultados</div>
      )}
    </div>
  )
}

function UserTypeBadge({ type }: { type: string }) {
  const styles: Record<string, string> = {
    passenger: 'bg-blue-100 text-blue-700',
    driver: 'bg-orange-100 text-orange-700',
    dual: 'bg-purple-100 text-purple-700',
    admin: 'bg-red-100 text-red-700',
  }
  const labels: Record<string, string> = {
    passenger: 'Pasajero', driver: 'Conductor', dual: 'Dual', admin: 'Admin',
  }
  return (
    <span className={`text-[10px] font-medium px-1.5 py-0.5 rounded ${styles[type] ?? 'bg-gray-100 text-gray-600'}`}>
      {labels[type] ?? type}
    </span>
  )
}

function MapPicker({ step, pickup, destination, onlineDrivers, onPick }: {
  step: 'pickup' | 'destination'
  pickup: Point | null
  destination: Point | null
  onlineDrivers: LiveData['onlineDrivers']
  onPick: (p: Point) => void
}) {
  const [temp, setTemp] = useState<Point | null>(null)
  const [busy, setBusy] = useState(false)

  const handleClick = async (lat: number, lng: number) => {
    setBusy(true)
    try {
      const { address } = await adminApi.reverseGeocode(lat, lng)
      setTemp({ lat, lng, address })
    } catch {
      setTemp({ lat, lng, address: `${lat.toFixed(6)}, ${lng.toFixed(6)}` })
    } finally { setBusy(false) }
  }

  return (
    <div className="p-4 space-y-3">
      <p className="text-xs text-gray-500">
        {step === 'pickup' ? 'Toca en el mapa el punto de RECOJO' : 'Toca en el mapa el DESTINO'}
      </p>
      <div className="rounded-lg overflow-hidden border border-gray-200" style={{ height: 320 }}>
        <MapContainer center={DEFAULT_CENTER} zoom={13} style={{ height: '100%' }}>
          <TileLayer
            attribution='&copy; OpenStreetMap contributors'
            url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
          />
          <ClickCapture onClick={handleClick} />
          {pickup && <Marker position={[pickup.lat, pickup.lng]} icon={pickupIcon} />}
          {destination && <Marker position={[destination.lat, destination.lng]} icon={destIcon} />}
          {temp && <Marker position={[temp.lat, temp.lng]} icon={step === 'pickup' ? pickupIcon : destIcon} />}
          {onlineDrivers.filter((d) => d.latitude != null && d.longitude != null).map((d) => (
            <Marker key={d.driverId} position={[d.latitude!, d.longitude!]} icon={driverOnlineIcon} />
          ))}
        </MapContainer>
      </div>
      {temp && (
        <div className="p-3 bg-gray-50 border border-gray-200 rounded-lg space-y-2">
          <div className="text-xs text-gray-500">Dirección seleccionada:</div>
          <div className="text-sm text-gray-900">{busy ? 'Buscando...' : temp.address}</div>
          <button
            onClick={() => onPick(temp)}
            disabled={busy}
            className="w-full px-3 py-2 bg-[#E31E24] hover:bg-[#B5181D] text-white text-sm font-semibold rounded-lg disabled:opacity-50"
          >
            Usar este punto como {step === 'pickup' ? 'RECOJO' : 'DESTINO'}
          </button>
        </div>
      )}
    </div>
  )
}

function ClickCapture({ onClick }: { onClick: (lat: number, lng: number) => void }) {
  useMapEvents({
    click: (e) => onClick(e.latlng.lat, e.latlng.lng),
  })
  return null
}

function Confirm({
  passenger, pickup, destination, distanceKm, onlineDrivers,
  driverId, onDriverChange,
  vehicleType, onVehicleChange,
  paymentMethod, onPaymentChange,
  fare, onFareChange,
}: {
  passenger: AdminUser; pickup: Point; destination: Point
  distanceKm: number | null
  onlineDrivers: LiveData['onlineDrivers']
  driverId: string; onDriverChange: (v: string) => void
  vehicleType: string; onVehicleChange: (v: string) => void
  paymentMethod: string; onPaymentChange: (v: string) => void
  fare: string; onFareChange: (v: string) => void
}) {
  return (
    <div className="p-4 space-y-4">
      <div className="p-3 bg-blue-50 border border-blue-200 rounded-lg space-y-1.5 text-sm">
        <div className="flex items-center gap-2"><User className="w-4 h-4 text-blue-600" /><strong>{passenger.fullName ?? '—'}</strong> · {passenger.phone ?? passenger.email}</div>
        <div className="flex items-start gap-2"><MapPin className="w-4 h-4 text-green-600 mt-0.5" /><span className="text-gray-700">{pickup.address}</span></div>
        <div className="flex items-start gap-2"><MapPin className="w-4 h-4 text-red-600 mt-0.5" /><span className="text-gray-700">{destination.address}</span></div>
        {distanceKm != null && (
          <div className="text-xs text-gray-500 pt-1">Distancia estimada: {distanceKm.toFixed(2)} km</div>
        )}
      </div>

      <div>
        <label className="block text-xs font-medium text-gray-700 mb-1">Conductor</label>
        <select value={driverId} onChange={(e) => onDriverChange(e.target.value)}
          className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm">
          <option value="">Sin asignar (broadcast a online cercanos)</option>
          {onlineDrivers.map((d) => (
            <option key={d.driverId} value={d.driverId}>
              {d.fullName ?? '—'} · {d.vehicleType ?? '—'} · ★ {d.rating?.toFixed(1) ?? '—'}
            </option>
          ))}
        </select>
      </div>

      <div className="grid grid-cols-3 gap-3">
        <div>
          <label className="block text-xs font-medium text-gray-700 mb-1">Tarifa (S/)</label>
          <input type="number" value={fare} onChange={(e) => onFareChange(e.target.value)}
            className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm" />
        </div>
        <div>
          <label className="block text-xs font-medium text-gray-700 mb-1">Vehículo</label>
          <select value={vehicleType} onChange={(e) => onVehicleChange(e.target.value)}
            className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm">
            <option value="car">Auto / Sedán</option>
            <option value="moto">Moto</option>
            <option value="moto_taxi">Mototaxi</option>
            <option value="van">Van</option>
            <option value="truck">Camión / Flete</option>
            <option value="taxi">Taxi</option>
          </select>
        </div>
        <div>
          <label className="block text-xs font-medium text-gray-700 mb-1">Pago</label>
          <select value={paymentMethod} onChange={(e) => onPaymentChange(e.target.value)}
            className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm">
            <option value="cash">Efectivo</option>
            <option value="mercadopago">MercadoPago</option>
            <option value="yape">Yape</option>
            <option value="plin">Plin</option>
          </select>
        </div>
      </div>

      <div className="p-3 bg-yellow-50 border border-yellow-200 rounded-lg text-xs text-yellow-800">
        Al crear, se notificará al conductor asignado (o a los conductores en línea a 5 km del recojo) con push FCM y en el stream en tiempo real.
      </div>
    </div>
  )
}

function haversineKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371
  const toRad = (x: number) => (x * Math.PI) / 180
  const dLat = toRad(lat2 - lat1)
  const dLng = toRad(lng2 - lng1)
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2
  return 2 * R * Math.asin(Math.sqrt(a))
}

// --------------------------------------------------------------------------
// Listas laterales
// --------------------------------------------------------------------------
function ActiveTripsList({ data }: { data: LiveData | null }) {
  const trips = data?.activeTrips ?? []
  return (
    <>
      <div className="p-4 border-b border-gray-100">
        <h3 className="text-sm font-semibold text-gray-900">Viajes en curso</h3>
        <p className="text-xs text-gray-500 mt-0.5">{trips.length} activo(s) ahora</p>
      </div>
      {trips.length === 0 ? (
        <div className="p-8 text-center text-sm text-gray-500">
          <Route className="w-8 h-8 mx-auto mb-2 text-gray-300" />
          No hay viajes activos ahora
        </div>
      ) : (
        <div className="max-h-[520px] overflow-y-auto divide-y divide-gray-100">
          {trips.map((t) => (
            <div key={t.id} className="p-3 space-y-2">
              <div className="flex items-center justify-between gap-2">
                <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${TRIP_STATUS_BADGE[t.status] ?? 'bg-gray-100 text-gray-700'}`}>
                  {TRIP_STATUS_LABEL[t.status] ?? t.status}
                </span>
                <span className="text-xs text-gray-400">{relativeTime(toDate(t.createdAt))}</span>
              </div>
              <div className="text-xs space-y-0.5">
                <div className="flex items-center gap-1.5">
                  <MapPin className="w-3 h-3 text-green-500 flex-shrink-0" />
                  <span className="truncate text-gray-700">{t.pickupAddress ?? '—'}</span>
                </div>
                <div className="flex items-center gap-1.5">
                  <MapPin className="w-3 h-3 text-red-500 flex-shrink-0" />
                  <span className="truncate text-gray-700">{t.destinationAddress ?? '—'}</span>
                </div>
              </div>
              <div className="flex items-center justify-between gap-2 text-xs">
                <div className="min-w-0">
                  <div className="flex items-center gap-1 text-gray-500">
                    <User className="w-3 h-3" />
                    <span className="truncate">{t.passenger?.fullName ?? '—'}</span>
                  </div>
                  <div className="flex items-center gap-1 text-gray-500">
                    <Car className="w-3 h-3" />
                    <span className="truncate">{t.driver?.fullName ?? 'Sin asignar'}</span>
                  </div>
                </div>
                {t.estimatedFare != null && (
                  <span className="font-semibold text-gray-900 flex-shrink-0">{formatPEN(t.estimatedFare)}</span>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </>
  )
}

function OnlineDriversList({ data }: { data: LiveData | null }) {
  const drivers = data?.onlineDrivers ?? []
  return (
    <>
      <div className="p-4 border-b border-gray-100">
        <h3 className="text-sm font-semibold text-gray-900">Conductores en línea</h3>
        <p className="text-xs text-gray-500 mt-0.5">{drivers.length} activo(s) con GPS</p>
      </div>
      {drivers.length === 0 ? (
        <div className="p-8 text-center text-sm text-gray-500">
          <Circle className="w-8 h-8 mx-auto mb-2 text-gray-300" />
          No hay conductores en línea ahora
        </div>
      ) : (
        <div className="max-h-[520px] overflow-y-auto divide-y divide-gray-100">
          {drivers.map((d) => (
            <div key={d.driverId} className="p-3 flex items-center gap-3">
              <div className="relative">
                {d.profilePhotoUrl ? (
                  <img src={d.profilePhotoUrl} alt="" className="w-9 h-9 rounded-full object-cover" />
                ) : (
                  <div className="w-9 h-9 rounded-full bg-green-100 text-green-700 flex items-center justify-center">
                    <User className="w-4 h-4" />
                  </div>
                )}
                <span className="absolute -bottom-0.5 -right-0.5 w-3 h-3 rounded-full bg-green-500 border-2 border-white" />
              </div>
              <div className="flex-1 min-w-0">
                <div className="text-sm font-medium text-gray-900 truncate">{d.fullName ?? '—'}</div>
                <div className="text-xs text-gray-500 flex items-center gap-2">
                  {d.vehicleType && <span className="capitalize">{d.vehicleType}</span>}
                  {typeof d.rating === 'number' && <span>★ {d.rating.toFixed(1)}</span>}
                  {d.activeRideId && <span className="text-blue-600 font-medium">· En viaje</span>}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </>
  )
}

function OfflineDriversList({ data }: { data: LiveData | null }) {
  const drivers = data?.offlineDrivers ?? []
  return (
    <>
      <div className="p-4 border-b border-gray-100">
        <h3 className="text-sm font-semibold text-gray-900">Desconectados</h3>
        <p className="text-xs text-gray-500 mt-0.5">Última hora — {drivers.length} conductor(es)</p>
      </div>
      {drivers.length === 0 ? (
        <div className="p-8 text-center text-sm text-gray-500">
          <Circle className="w-8 h-8 mx-auto mb-2 text-gray-300" />
          Ningún conductor se desconectó recientemente
        </div>
      ) : (
        <div className="max-h-[520px] overflow-y-auto divide-y divide-gray-100">
          {drivers.map((d) => (
            <div key={d.driverId} className="p-3 flex items-center gap-3">
              <div className="relative">
                {d.profilePhotoUrl ? (
                  <img src={d.profilePhotoUrl} alt="" className="w-9 h-9 rounded-full object-cover grayscale" />
                ) : (
                  <div className="w-9 h-9 rounded-full bg-gray-100 text-gray-500 flex items-center justify-center">
                    <User className="w-4 h-4" />
                  </div>
                )}
                <span className="absolute -bottom-0.5 -right-0.5 w-3 h-3 rounded-full bg-gray-400 border-2 border-white" />
              </div>
              <div className="flex-1 min-w-0">
                <div className="text-sm font-medium text-gray-700 truncate">{d.fullName ?? '—'}</div>
                <div className="text-xs text-gray-500">
                  {typeof d.minutesSinceHeartbeat === 'number' && (
                    <span>Hace {Math.round(d.minutesSinceHeartbeat)} min</span>
                  )}
                  {d.vehicleType && <span className="ml-2 capitalize">· {d.vehicleType}</span>}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </>
  )
}
