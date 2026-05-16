import { useEffect, useMemo, useState } from 'react'
import { collection, onSnapshot, query, where } from 'firebase/firestore'
import { db } from '../../config/firebase'
import { APIProvider, Map, AdvancedMarker, InfoWindow, Pin } from '@vis.gl/react-google-maps'
import { Loader2, MapPin, Phone } from 'lucide-react'
import { OrderPanel, type LatLngAddress } from '../../components/map/OrderPanel'
import { RoutePolyline } from '../../components/map/RoutePolyline'
import {
  DriverFilterBar,
  getCutoffDate,
  type DriverFilterValue,
} from '../../components/map/DriverFilterBar'
import { relativeTime, toDate } from '../../utils/timeFormat'

type DriverStatus = 'online_active' | 'ghost' | 'offline'

interface DriverPin {
  id: string
  name: string
  lat: number
  lng: number
  vehicle?: string
  plate?: string
  phone?: string
  status: DriverStatus
  lastSeen: Date | null
  isOnline: boolean
}

const GOOGLE_MAPS_API_KEY =
  (import.meta as any).env?.VITE_GOOGLE_MAPS_API_KEY ??
  'CHANGEME'

const LIMA_CENTER = { lat: -12.046374, lng: -77.042793 }

// Heartbeat window: drivers with lastSeen older than this are considered
// "ghost" (isOnline=true but not heartbeating) until the scheduled
// driverHeartbeatCheck cron flips them to isOnline=false.
const GHOST_THRESHOLD_MS = 5 * 60_000

const PIN_STYLES: Record<DriverStatus, { background: string; border: string; glyph: string }> = {
  online_active: { background: '#10B981', border: '#059669', glyph: '#fff' },
  ghost: { background: '#F59E0B', border: '#B45309', glyph: '#fff' },
  offline: { background: '#9CA3AF', border: '#6B7280', glyph: '#fff' },
}

const STATUS_LABEL: Record<DriverStatus, string> = {
  online_active: 'En línea',
  ghost: 'En línea (sin heartbeat)',
  offline: 'Desconectado',
}

export function LiveMapPage() {
  const [drivers, setDrivers] = useState<DriverPin[]>([])
  const [selected, setSelected] = useState<DriverPin | null>(null)
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState<DriverFilterValue>({ mode: 'today', customFrom: null })

  // Polyline state: published from OrderPanel
  const [pickup, setPickup] = useState<LatLngAddress | null>(null)
  const [destination, setDestination] = useState<LatLngAddress | null>(null)
  const [routeInfo, setRouteInfo] = useState<{
    distanceMeters: number
    durationSeconds: number
  } | null>(null)

  useEffect(() => {
    setLoading(true)
    const q = query(collection(db, 'users'), where('userType', 'in', ['driver', 'dual']))
    const unsub = onSnapshot(
      q,
      (snap) => {
        const now = Date.now()
        const list: DriverPin[] = []
        snap.docs.forEach((d) => {
          const data = d.data() as any
          const loc = data.currentLocation ?? data.location
          const lat = loc?.latitude ?? loc?.lat
          const lng = loc?.longitude ?? loc?.lng
          if (typeof lat !== 'number' || typeof lng !== 'number') return

          const lastSeen = toDate(data.lastSeen) ?? toDate(data.lastLocationUpdate) ?? null
          const isOnline = data.isOnline === true
          const lastSeenAgeMs = lastSeen ? now - lastSeen.getTime() : Number.POSITIVE_INFINITY

          let status: DriverStatus
          if (isOnline && lastSeenAgeMs < GHOST_THRESHOLD_MS) {
            status = 'online_active'
          } else if (isOnline) {
            status = 'ghost'
          } else {
            status = 'offline'
          }

          list.push({
            id: d.id,
            name: data.fullName ?? data.name ?? 'Conductor',
            lat,
            lng,
            vehicle: data.vehicleInfo
              ? `${data.vehicleInfo.make ?? ''} ${data.vehicleInfo.model ?? ''}`.trim() || undefined
              : undefined,
            plate: data.vehicleInfo?.plate,
            phone: data.phone ?? data.phoneNumber,
            status,
            lastSeen,
            isOnline,
          })
        })
        setDrivers(list)
        setLoading(false)
      },
      (err) => {
        console.warn('Live map listener error:', err)
        setLoading(false)
      },
    )
    return () => unsub()
  }, [])

  const filteredDrivers = useMemo(() => {
    const cutoff = getCutoffDate(filter)
    if (filter.mode === 'online_now') {
      return drivers.filter((d) => d.status === 'online_active')
    }
    if (!cutoff) return drivers
    return drivers.filter((d) => {
      if (d.status !== 'offline') return true // always include online/ghost
      if (!d.lastSeen) return false
      return d.lastSeen >= cutoff
    })
  }, [drivers, filter])

  const counters = useMemo(() => {
    let online = 0
    let ghost = 0
    let offline = 0
    for (const d of filteredDrivers) {
      if (d.status === 'online_active') online += 1
      else if (d.status === 'ghost') ghost += 1
      else offline += 1
    }
    return { online, ghost, offline }
  }, [filteredDrivers])

  // Cap markers to avoid map slowdown
  const DISPLAY_LIMIT = 200
  const displayedDrivers = filteredDrivers.slice(0, DISPLAY_LIMIT)
  const truncated = filteredDrivers.length > DISPLAY_LIMIT

  return (
    <APIProvider apiKey={GOOGLE_MAPS_API_KEY} libraries={['places', 'routes']}>
      <div className="flex flex-col h-[calc(100vh-100px)] gap-3">
        {/* Header */}
        <div className="flex flex-col gap-2 px-1">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-2xl font-bold text-gray-900">Mapa en Vivo</h1>
              <p className="text-xs text-gray-500">
                Visualiza conductores online/offline y crea pedidos manuales con ruta calculada
              </p>
            </div>
            {loading && <Loader2 className="w-5 h-5 animate-spin text-[#E31E24]" />}
          </div>
          <DriverFilterBar
            value={filter}
            onChange={setFilter}
            onlineCount={counters.online}
            ghostCount={counters.ghost}
            offlineCount={counters.offline}
          />
          {truncated && (
            <p className="text-[11px] text-amber-700 bg-amber-50 border border-amber-200 rounded px-2 py-1">
              Mostrando {DISPLAY_LIMIT} de {filteredDrivers.length} conductores. Refina los filtros
              para ver menos.
            </p>
          )}
        </div>

        {/* Two-column layout: map (left) + order panel (right) */}
        <div className="flex-1 flex gap-3 min-h-0">
          {/* Map */}
          <div className="flex-1 bg-white rounded-xl border border-gray-200 overflow-hidden">
            <Map
              defaultCenter={LIMA_CENTER}
              defaultZoom={12}
              mapId="rapi-team-live"
              gestureHandling="greedy"
              disableDefaultUI={false}
              style={{ width: '100%', height: '100%' }}
            >
              {displayedDrivers.map((d) => {
                const palette = PIN_STYLES[d.status]
                return (
                  <AdvancedMarker
                    key={d.id}
                    position={{ lat: d.lat, lng: d.lng }}
                    onClick={() => setSelected(d)}
                  >
                    <Pin
                      background={palette.background}
                      borderColor={palette.border}
                      glyphColor={palette.glyph}
                    />
                  </AdvancedMarker>
                )
              })}

              {selected && (
                <InfoWindow
                  position={{ lat: selected.lat, lng: selected.lng }}
                  onCloseClick={() => setSelected(null)}
                >
                  <div className="text-sm space-y-1 min-w-[200px]">
                    <div className="flex items-center gap-2">
                      <span
                        className="inline-block w-2 h-2 rounded-full"
                        style={{ backgroundColor: PIN_STYLES[selected.status].background }}
                      />
                      <p className="font-bold text-gray-900">{selected.name}</p>
                    </div>
                    <p className="text-xs text-gray-600">{STATUS_LABEL[selected.status]}</p>
                    {selected.vehicle && (
                      <p className="text-gray-700 text-xs">🚗 {selected.vehicle}</p>
                    )}
                    {selected.plate && (
                      <p className="text-gray-500 font-mono text-xs">Placa: {selected.plate}</p>
                    )}
                    {selected.phone && (
                      <a
                        href={`tel:${selected.phone}`}
                        className="flex items-center gap-1 text-blue-600 text-xs hover:underline"
                      >
                        <Phone className="w-3 h-3" /> {selected.phone}
                      </a>
                    )}
                    <p className="text-gray-500 text-xs">
                      Última conexión: {relativeTime(selected.lastSeen)}
                    </p>
                    <p className="text-gray-400 text-[10px] flex items-center gap-1">
                      <MapPin className="w-3 h-3" />
                      {selected.lat.toFixed(5)}, {selected.lng.toFixed(5)}
                    </p>
                  </div>
                </InfoWindow>
              )}

              <RoutePolyline
                origin={pickup ? { lat: pickup.lat, lng: pickup.lng } : null}
                destination={destination ? { lat: destination.lat, lng: destination.lng } : null}
                onRouteInfo={setRouteInfo}
              />
            </Map>
          </div>

          {/* Order panel */}
          <div className="w-[380px] shrink-0 bg-white rounded-xl border border-gray-200 overflow-hidden">
            <OrderPanel
              onPickupChange={setPickup}
              onDestinationChange={setDestination}
              routeInfo={routeInfo}
            />
          </div>
        </div>
      </div>
    </APIProvider>
  )
}
