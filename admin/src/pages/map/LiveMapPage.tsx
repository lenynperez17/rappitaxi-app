import { useEffect, useMemo, useRef, useState, useCallback } from 'react'
import { Link } from 'react-router-dom'
import {
  MapPin, Loader2, RefreshCw, User, Car, Circle, Route, Plus, X, Search,
  CheckCircle2, AlertCircle, ChevronUp, Phone, Star, Crosshair,
} from 'lucide-react'
import {
  MapContainer, Marker, Popup, Polyline, ZoomControl, useMap, useMapEvents,
} from 'react-leaflet'
import L, { type Map as LeafletMap } from 'leaflet'
import 'leaflet/dist/leaflet.css'
import { adminApi, AdminApiError, type AdminUser, type PlacePrediction } from '../../lib/adminApi'
import { formatPEN } from '../../utils/currency'
import { driverIcon, pickupIcon, destinationIcon, MAP_COLORS } from '../../components/map/mapIcons'
import { MapLayerPanel, useMapLayers } from '../../components/map/MapLayerPanel'
import { VectorBasemap } from '../../components/map/VectorBasemap'
import { DateTime } from '../../components/DateTime'
import { FloatingLayer } from '../../components/FloatingLayer'
import { decodePolyline, type LatLngTuple } from '../../utils/polyline'

/**
 * Mapa en vivo del despacho.
 *
 * Ronda 270 — reescrito tomando como referencia el panel de App-Plus, que ya
 * resolvía bien lo que aquí faltaba:
 *
 *   · Un conductor libre y otro en pleno viaje eran el MISMO punto verde. Ahora
 *     cada estado tiene su marcador (coche verde / ámbar latiendo / gris) y se
 *     distinguen de un vistazo, que es justo lo que un despachador necesita.
 *   · Los viajes solo pintaban el recojo: ni destino, ni trazo, ni dónde va el
 *     conductor. Ahora se dibuja el recorrido completo.
 *   · No había forma de quitarse capas de encima. Ahora se encienden y apagan,
 *     y la elección se recuerda.
 *   · El panel lateral desaparecía por completo por debajo de 1024px: en tablet
 *     y en móvil se perdían las tres listas sin nada que las sustituyera. Ahora
 *     baja a una hoja inferior desplegable.
 *   · La barra superior se salía de la pantalla en móvil y el botón "Nuevo
 *     viaje" quedaba cortado por el borde. Ahora envuelve y se compacta.
 */

// Fix de iconos por defecto de Leaflet en Vite.
// Ronda 214: antes se cargaban desde unpkg.com — si el CDN caía o se bloqueaba
// (firewalls corporativos), los marcadores desaparecían del mapa. Ahora se
// importan desde node_modules y Vite los bundlea como assets del propio dominio.
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
type LiveTrip = LiveData['activeTrips'][number]
type LiveDriver = LiveData['onlineDrivers'][number]
type Point = { lat: number; lng: number; address: string }

const hasCoords = (lat: number | null, lng: number | null): boolean =>
  typeof lat === 'number' && typeof lng === 'number' && Number.isFinite(lat) && Number.isFinite(lng)

// ---------------------------------------------------------------------------
// Encuadre automático
// ---------------------------------------------------------------------------

/**
 * Encuadra el mapa sobre todo lo que hay que ver, UNA sola vez.
 *
 * El límite de una vez es deliberado: el sondeo recrea los arrays cada 10s y
 * reencuadrar en cada ciclo le arrancaría el mapa de las manos al operador cada
 * vez que estuviera mirando una zona concreta. El botón "Centrar" queda para
 * cuando sí lo quiera.
 */
function AutoFit({ points, onReady }: { points: Array<[number, number]>; onReady: (fit: () => void) => void }) {
  const map = useMap()
  const didFit = useRef(false)

  const fit = useCallback(() => {
    if (points.length === 0) return
    if (points.length === 1) {
      map.setView(points[0], 15, { animate: true })
      return
    }
    map.fitBounds(L.latLngBounds(points), { padding: [60, 60], maxZoom: 16, animate: true })
  }, [map, points])

  useEffect(() => { onReady(fit) }, [fit, onReady])

  useEffect(() => {
    if (didFit.current || points.length === 0) return
    didFit.current = true
    fit()
  }, [points, fit])

  return null
}

/** Centra el mapa en un punto cuando el operador elige algo en la lista lateral. */
function FlyTo({ target }: { target: { lat: number; lng: number; key: string } | null }) {
  const map = useMap()
  const lastKey = useRef<string | null>(null)
  useEffect(() => {
    if (!target || target.key === lastKey.current) return
    lastKey.current = target.key
    map.flyTo([target.lat, target.lng], Math.max(map.getZoom(), 15), { duration: 0.8 })
  }, [target, map])
  return null
}

// ---------------------------------------------------------------------------
// Página
// ---------------------------------------------------------------------------

export function LiveMapPage() {
  const [data, setData] = useState<LiveData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [lastRefresh, setLastRefresh] = useState<Date | null>(null)
  const [tab, setTab] = useState<'trips' | 'online' | 'offline'>('trips')
  const [creating, setCreating] = useState(false)
  const [flash, setFlash] = useState<{ kind: 'ok' | 'err'; msg: string } | null>(null)
  const [sheetOpen, setSheetOpen] = useState(false)
  const [focus, setFocus] = useState<{ lat: number; lng: number; key: string } | null>(null)
  const [selectedTripId, setSelectedTripId] = useState<string | null>(null)
  const [layers, toggleLayer] = useMapLayers()
  const timerRef = useRef<number | null>(null)
  const fitRef = useRef<(() => void) | null>(null)

  /**
   * Ronda 283: la ruta REAL del viaje seleccionado.
   *
   * Antes se pintaba una línea recta del conductor al recojo —sólida y gruesa,
   * o sea con toda la pinta de ser una ruta— que cruzaba por encima de las
   * manzanas. Y se pintaba para TODOS los viajes activos a la vez, así que con
   * unos cuantos en marcha el mapa era una maraña de rectas.
   *
   * Ahora se pide la ruta de verdad, y solo del viaje que estás mirando. Eso
   * arregla las dos cosas al mismo tiempo, y además es lo único sostenible:
   * pedir rutas para todos los viajes en cada refresco de 10 s serían decenas
   * de peticiones por minuto al servicio de rutas.
   */
  const [ruta, setRuta] = useState<{
    tripId: string
    haciaRecojo: LatLngTuple[] | null
    haciaDestino: LatLngTuple[] | null
    resumen: string | null
    aproximada: boolean
  } | null>(null)
  const rutaSeq = useRef(0)

  /** Ronda 283: viaje sobre el que se está actuando, y el que va a asignarse. */
  const [ocupado, setOcupado] = useState<string | null>(null)
  const [asignando, setAsignando] = useState<LiveData['activeTrips'][number] | null>(null)

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

  /**
   * Ronda 283 — cerrar un viaje desde el mapa.
   *
   * Se confirma antes: esto no es limpieza interna, es dar un viaje por
   * terminado, y le llega al pasajero y al conductor.
   */
  const cerrarViaje = useCallback(async (t: LiveData['activeTrips'][number]) => {
    const quien = t.passenger?.fullName ?? 'este pasajero'
    if (!window.confirm(
      `¿Cerrar el viaje de ${quien}?\n\nQuedará como cancelado y dejará de estar activo `
      + 'tanto para el pasajero como para el conductor.',
    )) return
    setOcupado(t.id)
    try {
      await adminApi.cancelTrip(t.id, 'Cerrado por el administrador desde el mapa.')
      setFlash({ kind: 'ok', msg: 'Viaje cerrado.' })
      setSelectedTripId(null)
      await load()
    } catch (err) {
      setFlash({
        kind: 'err',
        msg: err instanceof AdminApiError ? err.message : 'No se pudo cerrar el viaje',
      })
    } finally {
      setOcupado(null)
    }
  }, [load])

  /** Asignar el conductor elegido. La validación de fondo la hace el servidor. */
  const asignarConductor = useCallback(async (tripId: string, driverId: string) => {
    setOcupado(tripId)
    try {
      await adminApi.assignTrip(tripId, driverId)
      setFlash({ kind: 'ok', msg: 'Conductor asignado. Le llegó el aviso a su teléfono.' })
      setAsignando(null)
      await load()
    } catch (err) {
      setFlash({
        kind: 'err',
        msg: err instanceof AdminApiError ? err.message : 'No se pudo asignar el conductor',
      })
    } finally {
      setOcupado(null)
    }
  }, [load])

  useEffect(() => {
    void load()
    // Sondeo periódico con auto-parada en 401/403 — si el token murió, seguir
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

  // Los conductores en línea se parten en libres y ocupados por su viaje activo:
  // es la distinción que decide a quién se le puede mandar el siguiente servicio.
  const { freeDrivers, busyDrivers } = useMemo(() => {
    const online = (data?.onlineDrivers ?? []).filter((d) => hasCoords(d.latitude, d.longitude))
    return {
      freeDrivers: online.filter((d) => !d.activeRideId),
      busyDrivers: online.filter((d) => !!d.activeRideId),
    }
  }, [data])

  // Los desconectados solo se pintan si alguna vez reportaron posición.
  const offlineOnMap = useMemo(
    () => (data?.offlineDrivers ?? []).filter((d) => hasCoords(d.latitude, d.longitude)),
    [data],
  )

  const mappableTrips = useMemo(
    () => (data?.activeTrips ?? []).filter((t) => hasCoords(t.pickupLat, t.pickupLng)),
    [data],
  )

  const selectedTrip = useMemo(
    () => mappableTrips.find((t) => t.id === selectedTripId) ?? null,
    [mappableTrips, selectedTripId],
  )

  /**
   * Pide la ruta del viaje seleccionado.
   *
   * Depende del ID y de las coordenadas, NO del objeto del viaje: si dependiera
   * del objeto, cada refresco de 10 s trae uno nuevo y volvería a pedir la
   * ruta entera aunque no haya cambiado nada. Solo se vuelve a pedir si el
   * conductor se ha movido de verdad, y para eso basta con sus coordenadas.
   */
  const rutaKey = selectedTrip
    ? [
        selectedTrip.id,
        selectedTrip.driver?.latitude ?? '', selectedTrip.driver?.longitude ?? '',
        selectedTrip.pickupLat ?? '', selectedTrip.pickupLng ?? '',
        selectedTrip.destinationLat ?? '', selectedTrip.destinationLng ?? '',
      ].join('|')
    : null

  useEffect(() => {
    if (!selectedTrip || !rutaKey) { setRuta(null); return }

    const seq = ++rutaSeq.current
    const t = selectedTrip
    let cancelado = false

    void (async () => {
      const pedir = async (
        a: { lat: number; lng: number } | null,
        b: { lat: number; lng: number } | null,
      ): Promise<{ puntos: LatLngTuple[] | null; texto: string | null }> => {
        if (!a || !b) return { puntos: null, texto: null }
        try {
          const r = await adminApi.getDirections(a, b)
          if (!r.success || !r.polyline) return { puntos: null, texto: null }
          return {
            puntos: decodePolyline(r.polyline),
            texto: r.distanceText && r.durationText
              ? `${r.distanceText} · ${r.durationText}`
              : null,
          }
        } catch {
          // Sin ruta se dibuja la recta, pero avisando de que lo es.
          return { puntos: null, texto: null }
        }
      }

      const conductor = hasCoords(t.driver?.latitude ?? null, t.driver?.longitude ?? null)
        ? { lat: t.driver!.latitude!, lng: t.driver!.longitude! }
        : null
      const recojo = { lat: t.pickupLat!, lng: t.pickupLng! }
      const destino = hasCoords(t.destinationLat, t.destinationLng)
        ? { lat: t.destinationLat!, lng: t.destinationLng! }
        : null

      const [aRecojo, aDestino] = await Promise.all([
        pedir(conductor, recojo),
        pedir(recojo, destino),
      ])

      // Descarta la respuesta vieja que llega después de otra selección.
      if (cancelado || seq !== rutaSeq.current) return

      setRuta({
        tripId: t.id,
        haciaRecojo: aRecojo.puntos,
        haciaDestino: aDestino.puntos,
        resumen: aDestino.texto,
        // Si el viaje tiene destino y no se pudo trazar, lo que se ve es una
        // recta: hay que decirlo en vez de dejar que parezca un recorrido.
        aproximada: (!!destino && !aDestino.puntos) || (!!conductor && !aRecojo.puntos),
      })
    })()

    return () => { cancelado = true }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [rutaKey])

  // Puntos para el encuadre inicial: solo de las capas encendidas, para no
  // alejar el mapa por culpa de algo que ni siquiera se está viendo.
  const fitPoints = useMemo(() => {
    const pts: Array<[number, number]> = []
    if (layers.free) freeDrivers.forEach((d) => pts.push([d.latitude!, d.longitude!]))
    if (layers.busy) busyDrivers.forEach((d) => pts.push([d.latitude!, d.longitude!]))
    if (layers.offline) offlineOnMap.forEach((d) => pts.push([d.latitude!, d.longitude!]))
    if (layers.trips) {
      mappableTrips.forEach((t) => {
        pts.push([t.pickupLat!, t.pickupLng!])
        if (hasCoords(t.destinationLat, t.destinationLng)) pts.push([t.destinationLat!, t.destinationLng!])
      })
    }
    return pts
  }, [layers, freeDrivers, busyDrivers, offlineOnMap, mappableTrips])

  /**
   * Centra el mapa en algo elegido desde las listas.
   *
   * Si su capa está apagada se enciende antes: centrar sobre un marcador que
   * no se está dibujando deja al operador mirando un punto vacío del plano,
   * convencido de que la aplicación falló. Pasa con los desconectados, que
   * vienen apagados de fábrica.
   */
  const focusOn = useCallback((lat: number, lng: number, key: string, layer: keyof typeof layers) => {
    if (!layers[layer]) toggleLayer(layer)
    setFocus({ lat, lng, key: `${key}-${Date.now()}` })
    setSheetOpen(false)
  }, [layers, toggleLayer])

  const layerCounts = {
    free: freeDrivers.length,
    busy: busyDrivers.length,
    offline: offlineOnMap.length,
    trips: mappableTrips.length,
  }

  return (
    <div className="h-full flex flex-col lg:flex-row overflow-hidden relative">
      {/* ---------------------------------------------------------------
          Mapa + controles flotantes
      --------------------------------------------------------------- */}
      <div className="flex-1 relative bg-gray-100 min-h-0">
        {/* Toda la interfaz flotante vive en UNA columna en flujo normal.
            El primer intento colocaba las capas con un desplazamiento fijo
            (`top-[4.5rem]`) y en móvil, cuando la barra se parte en dos líneas,
            el panel se comía el botón "Nuevo viaje". Apilándolo de verdad, cada
            pieza cae debajo de la anterior mida lo que mida. */}
        <div className="absolute inset-x-2 top-2 z-[1000] pointer-events-none flex flex-col gap-2">
          {/* Fila 1 — identificación, contadores y acciones */}
          <div className="flex flex-wrap items-start justify-between gap-2">
          <div className="pointer-events-auto bg-white/95 backdrop-blur rounded-lg shadow-md border border-gray-200 px-3 py-2 flex items-center gap-3 min-w-0">
            <div className="min-w-0">
              <div className="text-sm font-bold text-gray-900 leading-none truncate">Mapa en vivo</div>
              <div className="text-[10px] text-gray-500 leading-none mt-1 truncate">
                {lastRefresh
                  ? <>Actualizado <DateTime value={lastRefresh} /></>
                  : 'Cargando…'}
              </div>
            </div>
            <div className="h-6 w-px bg-gray-200 flex-shrink-0" />
            <div className="flex items-center gap-2.5 flex-shrink-0">
              <span className="text-xs text-gray-600 inline-flex items-center gap-1" title="Viajes activos">
                <Route className="w-3 h-3 text-blue-500" /> {counts.activeTrips}
              </span>
              <span className="text-xs text-gray-600 inline-flex items-center gap-1" title="Conductores en línea">
                <Circle className="w-3 h-3 text-green-500 fill-current" /> {counts.onlineDrivers}
              </span>
              <span className="text-xs text-gray-600 inline-flex items-center gap-1" title="Conductores desconectados">
                <Circle className="w-3 h-3 text-gray-400" /> {counts.offlineDrivers}
              </span>
            </div>
          </div>

          <div className="pointer-events-auto flex items-center gap-2 flex-shrink-0">
            <button
              onClick={() => fitRef.current?.()}
              title="Centrar el mapa en todo lo visible"
              aria-label="Centrar el mapa"
              className="inline-flex items-center gap-1.5 px-2.5 py-2 bg-white/95 backdrop-blur border border-gray-200 rounded-lg text-sm text-gray-700 hover:bg-white shadow-md"
            >
              <Crosshair className="w-4 h-4" />
              <span className="hidden xl:inline">Centrar</span>
            </button>
            <button
              onClick={() => void load()}
              title="Refrescar"
              aria-label="Refrescar"
              className="inline-flex items-center gap-1.5 px-2.5 py-2 bg-white/95 backdrop-blur border border-gray-200 rounded-lg text-sm text-gray-700 hover:bg-white shadow-md"
            >
              <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
              <span className="hidden xl:inline">Refrescar</span>
            </button>
            <button
              onClick={() => setCreating(true)}
              className="inline-flex items-center gap-1.5 px-3 py-2 bg-[#E31E24] hover:bg-[#B5181D] text-white text-sm font-semibold rounded-lg shadow-md whitespace-nowrap"
            >
              <Plus className="w-4 h-4" />
              <span className="hidden sm:inline">Nuevo viaje</span>
              <span className="sm:hidden">Nuevo</span>
            </button>
          </div>
          </div>

          {/* Fila 2 — capas a la izquierda, avisos a su derecha. Nunca se
              solapan porque comparten fila y el hueco se reparte con `gap`. */}
          <div className="flex items-start gap-2">
            <div className="w-36 flex-shrink-0">
              <MapLayerPanel layers={layers} onToggle={toggleLayer} counts={layerCounts} />
            </div>
            {(flash || error) && (
              <div className="flex-1 min-w-0 max-w-sm">
                {flash && (
                  <div className={`pointer-events-auto flex items-start gap-2 px-3 py-2 rounded-lg text-xs border shadow-md ${
                    flash.kind === 'ok' ? 'bg-green-50 border-green-200 text-green-700' : 'bg-red-50 border-red-200 text-red-700'
                  }`}>
                    {flash.kind === 'ok'
                      ? <CheckCircle2 className="w-4 h-4 flex-shrink-0 mt-px" />
                      : <AlertCircle className="w-4 h-4 flex-shrink-0 mt-px" />}
                    <span className="min-w-0">{flash.msg}</span>
                  </div>
                )}
                {error && !flash && (
                  <div className="pointer-events-auto px-3 py-2 rounded-lg bg-red-50 border border-red-200 text-xs text-red-700 shadow-md">
                    {error}
                  </div>
                )}
              </div>
            )}
          </div>
        </div>

        <MapContainer
          center={DEFAULT_CENTER}
          zoom={13}
          style={{ height: '100%', width: '100%' }}
          scrollWheelZoom
          zoomControl={false}
        >
          <VectorBasemap />
          <ZoomControl position="bottomright" />
          <AutoFit points={fitPoints} onReady={(fit) => { fitRef.current = fit }} />
          <FlyTo target={focus} />

          {/* Ronda 283 — el recorrido, solo del viaje seleccionado.
              Antes se pintaban rectas para TODOS los viajes a la vez: una
              maraña en cuanto hay unos cuantos, y encima la del conductor al
              recojo iba sólida y gruesa, con toda la pinta de ser una ruta
              cuando cruzaba por encima de las manzanas.
              Ahora se pide la ruta de verdad al seleccionar uno. Trazo sólido:
              lo que el conductor está recorriendo ahora. Trazo punteado: lo que
              queda por recorrer hasta el destino. */}
          {layers.trips && selectedTrip && ruta?.tripId === selectedTrip.id && (
            <>
              {ruta.haciaRecojo && (
                <Polyline
                  positions={ruta.haciaRecojo}
                  pathOptions={{ color: MAP_COLORS.busy, weight: 5, opacity: 0.9 }}
                />
              )}
              {ruta.haciaDestino && (
                <Polyline
                  positions={ruta.haciaDestino}
                  pathOptions={{ color: MAP_COLORS.destination, weight: 4, opacity: 0.75 }}
                />
              )}
              {/* Si el servicio de rutas no respondió se dibuja la recta, pero
                  punteada y fina: que se vea que es una aproximación y no el
                  camino que va a hacer nadie. */}
              {!ruta.haciaDestino && hasCoords(selectedTrip.destinationLat, selectedTrip.destinationLng) && (
                <Polyline
                  positions={[
                    [selectedTrip.pickupLat!, selectedTrip.pickupLng!],
                    [selectedTrip.destinationLat!, selectedTrip.destinationLng!],
                  ]}
                  pathOptions={{
                    color: MAP_COLORS.destination, weight: 2, opacity: 0.45, dashArray: '4 10',
                  }}
                />
              )}
              {!ruta.haciaRecojo && hasCoords(
                selectedTrip.driver?.latitude ?? null, selectedTrip.driver?.longitude ?? null,
              ) && (
                <Polyline
                  positions={[
                    [selectedTrip.driver!.latitude!, selectedTrip.driver!.longitude!],
                    [selectedTrip.pickupLat!, selectedTrip.pickupLng!],
                  ]}
                  pathOptions={{
                    color: MAP_COLORS.busy, weight: 2, opacity: 0.45, dashArray: '4 10',
                  }}
                />
              )}
            </>
          )}

          {/* Recojos y destinos */}
          {layers.trips && mappableTrips.map((t) => (
            <Marker
              key={`${t.id}-pickup`}
              position={[t.pickupLat!, t.pickupLng!]}
              icon={pickupIcon()}
              eventHandlers={{ click: () => { setSelectedTripId(t.id); setTab('trips') } }}
            >
              <Popup><TripPopup trip={t} /></Popup>
            </Marker>
          ))}
          {layers.trips && mappableTrips
            .filter((t) => hasCoords(t.destinationLat, t.destinationLng))
            .map((t) => (
              <Marker key={`${t.id}-destination`} position={[t.destinationLat!, t.destinationLng!]} icon={destinationIcon()}>
                <Popup>
                  <div className="text-xs space-y-1">
                    <div className="font-semibold text-gray-900">Destino</div>
                    <div className="text-gray-600">{t.destinationAddress ?? '—'}</div>
                  </div>
                </Popup>
              </Marker>
            ))}

          {/* Conductores */}
          {layers.free && freeDrivers.map((d) => (
            <Marker key={`free-${d.driverId}`} position={[d.latitude!, d.longitude!]} icon={driverIcon('free')}>
              <Popup><DriverPopup driver={d} state="free" /></Popup>
            </Marker>
          ))}
          {layers.busy && busyDrivers.map((d) => (
            <Marker key={`busy-${d.driverId}`} position={[d.latitude!, d.longitude!]} icon={driverIcon('busy')}>
              <Popup><DriverPopup driver={d} state="busy" /></Popup>
            </Marker>
          ))}
          {layers.offline && offlineOnMap.map((d) => (
            <Marker key={`off-${d.driverId}`} position={[d.latitude!, d.longitude!]} icon={driverIcon('offline')}>
              <Popup><DriverPopup driver={d} state="offline" /></Popup>
            </Marker>
          ))}
        </MapContainer>
      </div>

      {/* ---------------------------------------------------------------
          Listas. En escritorio, columna a la derecha. Por debajo de 1024px,
          hoja inferior desplegable: antes simplemente desaparecían y en tablet
          o móvil no había forma de ver viajes ni conductores.
      --------------------------------------------------------------- */}
      <aside
        className={`
          bg-white border-gray-200 flex flex-col overflow-hidden flex-shrink-0
          absolute inset-x-0 bottom-0 z-[1100] border-t rounded-t-2xl shadow-[0_-4px_16px_rgba(0,0,0,0.12)]
          transition-[height] duration-300 ease-out
          ${sheetOpen ? 'h-[70%]' : 'h-auto'}
          lg:static lg:h-auto lg:w-[26rem] lg:border-t-0 lg:border-l lg:rounded-none lg:shadow-none lg:z-auto
        `}
      >
        {/* Asa: solo tiene sentido mientras la hoja se pueda plegar */}
        <button
          type="button"
          onClick={() => setSheetOpen((o) => !o)}
          aria-expanded={sheetOpen}
          className="lg:hidden w-full flex items-center justify-center gap-2 py-2 text-xs font-medium text-gray-500 hover:bg-gray-50"
        >
          <span className="absolute top-1.5 left-1/2 -translate-x-1/2 w-10 h-1 rounded-full bg-gray-300" />
          <ChevronUp className={`w-4 h-4 transition-transform mt-1.5 ${sheetOpen ? 'rotate-180' : ''}`} />
          <span className="mt-1.5">{sheetOpen ? 'Ocultar listas' : 'Ver viajes y conductores'}</span>
        </button>

        <div className={`${sheetOpen ? 'flex' : 'hidden'} lg:flex flex-col min-h-0 flex-1`}>
          <div className="grid grid-cols-3 divide-x divide-gray-100 border-y lg:border-t-0 border-gray-200 text-center flex-shrink-0">
            <TabButton active={tab === 'trips'} onClick={() => setTab('trips')} tone="blue" icon={<Route className="w-4 h-4" />}
              label="En curso" count={counts.activeTrips} />
            <TabButton active={tab === 'online'} onClick={() => setTab('online')} tone="green" icon={<Circle className="w-4 h-4 fill-current" />}
              label="En línea" count={counts.onlineDrivers} />
            <TabButton active={tab === 'offline'} onClick={() => setTab('offline')} tone="gray" icon={<Circle className="w-4 h-4" />}
              label="Off" count={counts.offlineDrivers} />
          </div>
          <div className="flex-1 overflow-y-auto min-h-0">
            {loading && (
              <div className="p-8 text-center">
                <Loader2 className="w-6 h-6 mx-auto animate-spin text-gray-400" />
              </div>
            )}
            {!loading && tab === 'trips' && (
              <ActiveTripsList
                data={data}
                selectedId={selectedTripId}
                onFocus={focusOn}
                onSelect={setSelectedTripId}
                onCancel={(t) => void cerrarViaje(t)}
                onAssign={(t) => setAsignando(t)}
                ocupado={ocupado}
                resumenRuta={ruta?.tripId === selectedTripId ? ruta.resumen : null}
              />
            )}
            {!loading && tab === 'online' && <DriversList data={data} kind="online" onFocus={focusOn} />}
            {!loading && tab === 'offline' && <DriversList data={data} kind="offline" onFocus={focusOn} />}
          </div>
        </div>
      </aside>

      {asignando && (
        <AssignDriverOverlay
          trip={asignando}
          onlineDrivers={data?.onlineDrivers ?? []}
          offlineDrivers={data?.offlineDrivers ?? []}
          ocupado={ocupado !== null}
          onClose={() => setAsignando(null)}
          onPick={(driverId) => void asignarConductor(asignando.id, driverId)}
        />
      )}

      {creating && (
        <CreateTripOverlay
          onlineDrivers={data?.onlineDrivers ?? []}
          onClose={() => setCreating(false)}
          onCreated={(fanout, passengerCreated) => {
            setCreating(false)
            setFlash({
              kind: 'ok',
              msg: `Viaje creado${passengerCreated ? ' y cliente registrado' : ''}. `
                + `${fanout.notified} conductor(es) notificado(s), ${fanout.fcmSent} push enviado(s).`,
            })
            void load()
          }}
          onError={(msg) => setFlash({ kind: 'err', msg })}
        />
      )}
    </div>
  )
}

// ---------------------------------------------------------------------------
// Piezas de la interfaz
// ---------------------------------------------------------------------------

/**
 * Ronda 283 — elegir a quién se le manda el viaje.
 *
 * Los conectados van primero y separados de los demás porque son los únicos
 * que se van a enterar ahora mismo: al desconectado le llegará el push cuando
 * abra la app, que puede ser dentro de horas. Se le puede asignar igualmente
 * —a veces se sabe que está a punto de conectarse— pero viéndolo, no por
 * descuido.
 */
function AssignDriverOverlay({ trip, onlineDrivers, offlineDrivers, ocupado, onClose, onPick }: {
  trip: LiveData['activeTrips'][number]
  onlineDrivers: LiveData['onlineDrivers']
  offlineDrivers: LiveData['offlineDrivers']
  ocupado: boolean
  onClose: () => void
  onPick: (driverId: string) => void
}) {
  // Un conductor que ya está en un viaje no debería recibir otro.
  const libres = onlineDrivers.filter((d) => !d.activeRideId)
  const ocupados = onlineDrivers.filter((d) => d.activeRideId)

  const Fila = ({ id, nombre, telefono, nota, tono }: {
    id: string; nombre: string | null; telefono: string | null
    nota: string; tono: 'verde' | 'ambar' | 'gris'
  }) => (
    <button
      type="button"
      disabled={ocupado}
      onClick={() => onPick(id)}
      className="w-full p-3 flex items-center gap-3 text-left hover:bg-gray-50 disabled:opacity-40 disabled:cursor-not-allowed"
    >
      <span className={`w-2.5 h-2.5 rounded-full flex-shrink-0 ${
        tono === 'verde' ? 'bg-green-500' : tono === 'ambar' ? 'bg-amber-500' : 'bg-gray-300'
      }`} />
      <div className="min-w-0 flex-1">
        <div className="text-sm text-gray-900 truncate">{nombre ?? '(sin nombre)'}</div>
        <div className="text-xs text-gray-500 truncate">{telefono ?? nota}</div>
      </div>
      <span className="text-xs text-gray-400 flex-shrink-0">{nota}</span>
    </button>
  )

  return (
    <div className="fixed inset-0 bg-black/60 z-[2000] flex items-center justify-center p-4" onClick={onClose}>
      <div
        onClick={(e) => e.stopPropagation()}
        className="bg-white rounded-2xl shadow-xl w-full max-w-md max-h-[85vh] flex flex-col overflow-hidden"
      >
        <div className="px-5 py-4 border-b border-gray-200 flex items-start justify-between gap-3">
          <div className="min-w-0">
            <h2 className="text-lg font-semibold text-gray-900">Asignar conductor</h2>
            <p className="text-xs text-gray-500 mt-0.5 truncate">
              Recoge en {trip.pickupAddress ?? 'el punto indicado'}
            </p>
          </div>
          <button onClick={onClose} className="p-1 hover:bg-gray-100 rounded flex-shrink-0">
            <X className="w-5 h-5 text-gray-500" />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto min-h-0">
          {libres.length === 0 && ocupados.length === 0 && offlineDrivers.length === 0 ? (
            <div className="p-8 text-center text-sm text-gray-500">
              No hay conductores registrados.
            </div>
          ) : (
            <>
              <Seccion titulo="En línea y libres" vacio="Ninguno libre ahora mismo">
                {libres.map((d) => (
                  <Fila key={d.driverId} id={d.driverId} nombre={d.fullName}
                    telefono={d.phone} nota="disponible" tono="verde" />
                ))}
              </Seccion>
              {ocupados.length > 0 && (
                <Seccion titulo="En línea, pero en un viaje">
                  {ocupados.map((d) => (
                    <Fila key={d.driverId} id={d.driverId} nombre={d.fullName}
                      telefono={d.phone} nota="ocupado" tono="ambar" />
                  ))}
                </Seccion>
              )}
              {offlineDrivers.length > 0 && (
                <Seccion titulo="Desconectados">
                  {offlineDrivers.map((d) => (
                    <Fila key={d.driverId} id={d.driverId} nombre={d.fullName}
                      telefono={d.phone} nota="sin conexión" tono="gris" />
                  ))}
                </Seccion>
              )}
            </>
          )}
        </div>

        <div className="px-5 py-3 border-t border-gray-200">
          <p className="text-xs text-gray-500">
            Al asignarlo, el viaje queda aceptado a su nombre y le llega un aviso al teléfono.
          </p>
        </div>
      </div>
    </div>
  )
}

function Seccion({ titulo, vacio, children }: {
  titulo: string
  vacio?: string
  children: React.ReactNode
}) {
  const hayHijos = Array.isArray(children) ? children.length > 0 : !!children
  return (
    <div>
      <div className="px-4 py-2 bg-gray-50 text-xs font-medium text-gray-500 uppercase sticky top-0">
        {titulo}
      </div>
      {hayHijos
        ? <div className="divide-y divide-gray-100">{children}</div>
        : vacio && <p className="px-4 py-3 text-xs text-gray-400">{vacio}</p>}
    </div>
  )
}

function TabButton({ active, onClick, tone, icon, label, count }: {
  active: boolean
  onClick: () => void
  tone: 'blue' | 'green' | 'gray'
  icon: React.ReactNode
  label: string
  count: number
}) {
  const tones = {
    blue: 'bg-blue-50 text-blue-700 border-blue-500',
    green: 'bg-green-50 text-green-700 border-green-500',
    gray: 'bg-gray-100 text-gray-700 border-gray-500',
  }
  return (
    <button
      onClick={onClick}
      className={`p-2.5 flex flex-col items-center gap-1 text-xs transition-colors ${
        active ? `${tones[tone]} border-b-2` : 'text-gray-500 hover:bg-gray-50'
      }`}
    >
      {icon}
      <span className="truncate w-full">{label} · <strong>{count}</strong></span>
    </button>
  )
}

function TripPopup({ trip }: { trip: LiveTrip }) {
  return (
    <div className="text-xs space-y-1.5">
      <div className="flex items-center gap-2">
        <span className={`px-1.5 py-0.5 rounded-full text-[10px] font-medium ${TRIP_STATUS_BADGE[trip.status] ?? 'bg-gray-100 text-gray-700'}`}>
          {TRIP_STATUS_LABEL[trip.status] ?? trip.status}
        </span>
        {trip.estimatedFare != null && (
          <span className="font-semibold text-gray-900">{formatPEN(trip.estimatedFare)}</span>
        )}
      </div>
      <div className="text-gray-700"><strong>{trip.passenger?.fullName ?? 'Pasajero —'}</strong></div>
      <div className="text-gray-600">📍 {trip.pickupAddress ?? '—'}</div>
      <div className="text-gray-600">🏁 {trip.destinationAddress ?? '—'}</div>
      <div className="text-gray-500">
        🚗 {trip.driver?.fullName ?? 'Sin asignar'}
      </div>
      {/* Ronda 273: en el mapa la antigüedad importa tanto como el reloj —
          un viaje pedido hace 20 minutos y sin conductor es una alarma— así
          que aquí se muestran las dos cosas. */}
      <div className="text-gray-400">🕐 <DateTime value={trip.createdAt} relative /></div>
      {trip.driver?.id && (
        <Link to={`/users/${trip.driver.id}`} className="block text-center mt-1 px-2 py-1 rounded border border-gray-300 text-gray-700 hover:bg-gray-50">
          Ver conductor
        </Link>
      )}
    </div>
  )
}

function DriverPopup({ driver, state }: { driver: LiveDriver; state: 'free' | 'busy' | 'offline' }) {
  const label = state === 'free' ? 'Disponible' : state === 'busy' ? 'En viaje' : 'Desconectado'
  const color = state === 'free' ? MAP_COLORS.free : state === 'busy' ? MAP_COLORS.busy : MAP_COLORS.offline
  return (
    <div className="text-xs space-y-1.5">
      <div className="font-semibold text-gray-900">{driver.fullName ?? '—'}</div>
      <span className="inline-block px-2 py-0.5 rounded-full text-[10px] font-medium text-white" style={{ background: color }}>
        {label}
      </span>
      <div className="text-gray-600 flex items-center gap-2 flex-wrap">
        {driver.vehicleType && <span className="capitalize">{driver.vehicleType}</span>}
        {typeof driver.rating === 'number' && (
          <span className="inline-flex items-center gap-0.5"><Star className="w-3 h-3 text-amber-500 fill-current" />{driver.rating.toFixed(1)}</span>
        )}
      </div>
      {driver.phone && (
        <a href={`tel:${driver.phone}`} className="text-gray-600 inline-flex items-center gap-1 hover:text-gray-900">
          <Phone className="w-3 h-3" /> {driver.phone}
        </a>
      )}
      {state === 'offline' && typeof driver.minutesSinceHeartbeat === 'number' && (
        <div className="text-gray-400">Sin señal hace {Math.round(driver.minutesSinceHeartbeat)} min</div>
      )}
      <Link to={`/users/${driver.driverId}`} className="block text-center mt-1 px-2 py-1 rounded border border-gray-300 text-gray-700 hover:bg-gray-50">
        Ver ficha
      </Link>
    </div>
  )
}

// ---------------------------------------------------------------------------
// Listas laterales
// ---------------------------------------------------------------------------

/**
 * Ronda 283: estados en los que se le puede poner conductor a un viaje. Mismos
 * que acepta el servidor en `admin/trips/[id]/assign`; si divergieran, el panel
 * ofrecería un botón que siempre falla.
 */
const ASIGNABLES = new Set(['requested', 'searching', 'no_drivers'])

function ActiveTripsList({ data, selectedId, onFocus, onSelect, onCancel, onAssign, ocupado, resumenRuta }: {
  data: LiveData | null
  selectedId: string | null
  onFocus: (lat: number, lng: number, key: string, layer: 'trips') => void
  onSelect: (id: string) => void
  onCancel: (trip: LiveData['activeTrips'][number]) => void
  onAssign: (trip: LiveData['activeTrips'][number]) => void
  /** Id del viaje sobre el que se está actuando, para no permitir dos clics. */
  ocupado: string | null
  /** "12,3 km · 25 min" del viaje seleccionado, cuando ya se calculó. */
  resumenRuta: string | null
}) {
  const trips = data?.activeTrips ?? []
  return (
    <>
      <div className="p-4 border-b border-gray-100">
        <h3 className="text-sm font-semibold text-gray-900">Viajes en curso</h3>
        <p className="text-xs text-gray-500 mt-0.5">{trips.length} activo(s) ahora</p>
      </div>
      {trips.length === 0 ? (
        <EmptyState icon={<Route className="w-8 h-8" />} text="No hay viajes activos ahora" />
      ) : (
        <div className="divide-y divide-gray-100">
          {trips.map((t) => {
            const locatable = hasCoords(t.pickupLat, t.pickupLng)
            const seleccionado = selectedId === t.id
            return (
              /* Ronda 283: era un <button> envolviéndolo todo, y dentro no se
                 pueden meter los botones de acción — anidar botones no es HTML
                 válido y el clic de dentro dispararía también el de fuera. */
              <div
                key={t.id}
                role="button"
                tabIndex={0}
                onClick={() => { onSelect(t.id); if (locatable) onFocus(t.pickupLat!, t.pickupLng!, t.id, 'trips') }}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' || e.key === ' ') {
                    e.preventDefault()
                    onSelect(t.id)
                    if (locatable) onFocus(t.pickupLat!, t.pickupLng!, t.id, 'trips')
                  }
                }}
                className={`w-full text-left p-3 space-y-2 transition-colors cursor-pointer ${
                  seleccionado ? 'bg-blue-50' : 'hover:bg-gray-50'
                }`}
              >
                <div className="flex items-center justify-between gap-2">
                  <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${TRIP_STATUS_BADGE[t.status] ?? 'bg-gray-100 text-gray-700'}`}>
                    {TRIP_STATUS_LABEL[t.status] ?? t.status}
                  </span>
                  <span className="text-xs text-gray-400"><DateTime value={t.createdAt} relative /></span>
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
                      <User className="w-3 h-3 flex-shrink-0" />
                      <span className="truncate">{t.passenger?.fullName ?? '—'}</span>
                    </div>
                    <div className="flex items-center gap-1 text-gray-500">
                      <Car className="w-3 h-3 flex-shrink-0" />
                      <span className="truncate">{t.driver?.fullName ?? 'Sin asignar'}</span>
                    </div>
                  </div>
                  {t.estimatedFare != null && (
                    <span className="font-semibold text-gray-900 flex-shrink-0">{formatPEN(t.estimatedFare)}</span>
                  )}
                </div>

                {/* Ronda 283: distancia y duración REALES por calles. Antes no
                    se veían por ninguna parte: la única referencia era una
                    línea recta, que además engaña sobre lo que se va a tardar. */}
                {seleccionado && resumenRuta && (
                  <div className="flex items-center gap-1.5 text-xs text-gray-500 pt-0.5">
                    <Route className="w-3 h-3 flex-shrink-0" />
                    <span>{resumenRuta}</span>
                  </div>
                )}

                {/* Acciones, solo en el viaje seleccionado: en todas las filas
                    a la vez serían un muro de botones. */}
                {seleccionado && (
                  <div
                    className="flex items-center gap-2 pt-1"
                    onClick={(e) => e.stopPropagation()}
                  >
                    {!t.driver && ASIGNABLES.has(t.status) && (
                      <button
                        type="button"
                        onClick={() => onAssign(t)}
                        disabled={ocupado !== null}
                        className="flex-1 inline-flex items-center justify-center gap-1 px-2 py-1.5 rounded-lg bg-[#E31E24] hover:bg-[#B5181D] text-white text-xs font-medium disabled:opacity-40"
                      >
                        <Car className="w-3 h-3" /> Asignar conductor
                      </button>
                    )}
                    <button
                      type="button"
                      onClick={() => onCancel(t)}
                      disabled={ocupado !== null}
                      className="flex-1 inline-flex items-center justify-center gap-1 px-2 py-1.5 rounded-lg border border-red-200 text-red-700 hover:bg-red-50 text-xs font-medium disabled:opacity-40"
                    >
                      {ocupado === t.id
                        ? <Loader2 className="w-3 h-3 animate-spin" />
                        : <X className="w-3 h-3" />}
                      Cerrar viaje
                    </button>
                  </div>
                )}
              </div>
            )
          })}
        </div>
      )}
    </>
  )
}

function DriversList({ data, kind, onFocus }: {
  data: LiveData | null
  kind: 'online' | 'offline'
  onFocus: (lat: number, lng: number, key: string, layer: 'free' | 'busy' | 'offline') => void
}) {
  const drivers = (kind === 'online' ? data?.onlineDrivers : data?.offlineDrivers) ?? []
  const title = kind === 'online' ? 'Conductores en línea' : 'Desconectados'
  const subtitle = kind === 'online'
    ? `${drivers.length} activo(s) con GPS`
    : `${drivers.length} conductor(es) sin conexión`
  const emptyText = kind === 'online'
    ? 'No hay conductores en línea ahora'
    : 'Todos los conductores están conectados'

  return (
    <>
      <div className="p-4 border-b border-gray-100">
        <h3 className="text-sm font-semibold text-gray-900">{title}</h3>
        <p className="text-xs text-gray-500 mt-0.5">{subtitle}</p>
      </div>
      {drivers.length === 0 ? (
        <EmptyState icon={<Circle className="w-8 h-8" />} text={emptyText} />
      ) : (
        <div className="divide-y divide-gray-100">
          {drivers.map((d) => {
            const locatable = hasCoords(d.latitude, d.longitude)
            return (
              <button
                key={d.driverId}
                type="button"
                disabled={!locatable}
                onClick={() => locatable && onFocus(
                  d.latitude!, d.longitude!, d.driverId,
                  kind === 'offline' ? 'offline' : d.activeRideId ? 'busy' : 'free',
                )}
                title={locatable ? 'Centrar en el mapa' : 'Sin posición conocida'}
                className={`w-full text-left p-3 flex items-center gap-3 transition-colors ${
                  locatable ? 'hover:bg-gray-50' : 'cursor-default opacity-70'
                }`}
              >
                <div className="relative flex-shrink-0">
                  {d.profilePhotoUrl ? (
                    <img src={d.profilePhotoUrl} alt="" className={`w-9 h-9 rounded-full object-cover ${kind === 'offline' ? 'grayscale' : ''}`} />
                  ) : (
                    <div className={`w-9 h-9 rounded-full flex items-center justify-center ${
                      kind === 'online' ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-500'
                    }`}>
                      <User className="w-4 h-4" />
                    </div>
                  )}
                  <span className={`absolute -bottom-0.5 -right-0.5 w-3 h-3 rounded-full border-2 border-white ${
                    kind === 'online' ? (d.activeRideId ? 'bg-amber-500' : 'bg-green-500') : 'bg-gray-400'
                  }`} />
                </div>
                <div className="flex-1 min-w-0">
                  <div className={`text-sm font-medium truncate ${kind === 'online' ? 'text-gray-900' : 'text-gray-700'}`}>
                    {d.fullName ?? '—'}
                  </div>
                  <div className="text-xs text-gray-500 flex items-center gap-2 flex-wrap">
                    {d.vehicleType && <span className="capitalize">{d.vehicleType}</span>}
                    {typeof d.rating === 'number' && <span>★ {d.rating.toFixed(1)}</span>}
                    {kind === 'online' && d.activeRideId && <span className="text-amber-600 font-medium">· En viaje</span>}
                    {kind === 'offline' && typeof d.minutesSinceHeartbeat === 'number' && (
                      <span>Hace {Math.round(d.minutesSinceHeartbeat)} min</span>
                    )}
                  </div>
                </div>
                {locatable && <MapPin className="w-4 h-4 text-gray-300 flex-shrink-0" />}
              </button>
            )
          })}
        </div>
      )}
    </>
  )
}

function EmptyState({ icon, text }: { icon: React.ReactNode; text: string }) {
  return (
    <div className="p-8 text-center text-sm text-gray-500">
      <div className="flex justify-center mb-2 text-gray-300">{icon}</div>
      {text}
    </div>
  )
}

// ---------------------------------------------------------------------------
// Crear viaje desde el mapa
// ---------------------------------------------------------------------------

/**
 * Ronda 271: el pasajero de un viaje creado desde el panel ya no tiene por qué
 * estar registrado.
 *
 * La central atiende llamadas de gente que no tiene la app, y el panel solo
 * sabía buscar entre los usuarios existentes: el operador tenía que irse a
 * Usuarios, dar de alta al cliente a mano, volver al mapa y buscarlo, con el
 * cliente esperando al teléfono.
 */
type TripPassenger =
  | { kind: 'registered'; user: AdminUser }
  | { kind: 'guest'; fullName: string; phone: string }

/** Nombre a mostrar, venga de donde venga el pasajero. */
function passengerLabel(p: TripPassenger): string {
  return p.kind === 'registered' ? (p.user.fullName ?? '(sin nombre)') : p.fullName
}

/** Contacto secundario: teléfono, o correo si el registrado no tiene teléfono. */
function passengerContact(p: TripPassenger): string {
  return p.kind === 'registered' ? (p.user.phone ?? p.user.email ?? p.user.id) : p.phone
}

function CreateTripOverlay({
  onlineDrivers,
  onClose,
  onCreated,
  onError,
}: {
  onlineDrivers: LiveData['onlineDrivers']
  onClose: () => void
  onCreated: (fanout: { notified: number; fcmSent: number }, passengerCreated: boolean) => void
  onError: (msg: string) => void
}) {
  const [step, setStep] = useState<'passenger' | 'pickup' | 'destination' | 'confirm'>('passenger')
  const [passenger, setPassenger] = useState<TripPassenger | null>(null)
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
        ...(passenger.kind === 'registered'
          ? { passengerId: passenger.user.id }
          : { guestPassenger: { fullName: passenger.fullName, phone: passenger.phone } }),
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
      onCreated(resp.fanout, resp.passenger?.created ?? false)
    } catch (err) {
      onError(err instanceof AdminApiError ? err.message : 'Error creando viaje')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="fixed inset-0 bg-black/60 z-[2000] flex items-stretch justify-end">
      <div className="w-full sm:max-w-[550px] bg-white shadow-2xl flex flex-col">
        <div className="p-4 border-b border-gray-200 flex items-center justify-between gap-2">
          <div className="min-w-0">
            <h2 className="text-lg font-bold text-gray-900">Crear viaje</h2>
            <p className="text-xs text-gray-500">Directo desde el mapa · 4 pasos</p>
          </div>
          <button onClick={onClose} aria-label="Cerrar" className="p-2 hover:bg-gray-100 rounded flex-shrink-0">
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
  passenger: TripPassenger | null
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
    <div className="px-3 py-3 border-b border-gray-100 flex items-center gap-1.5">
      {items.map((it, i) => (
        <button
          key={it.key}
          onClick={() => (it.done || it.key === step) && onGoto(it.key)}
          className={`flex-1 min-w-0 flex items-center justify-center sm:justify-start gap-1.5 px-1.5 py-1.5 rounded text-xs font-medium transition-colors ${
            step === it.key ? 'bg-red-50 text-red-700'
              : it.done ? 'bg-green-50 text-green-700'
              : 'bg-gray-50 text-gray-400'
          }`}
        >
          <span className="w-5 h-5 flex-shrink-0 rounded-full flex items-center justify-center text-[10px] font-bold border-2 border-current">
            {it.done ? '✓' : i + 1}
          </span>
          <span className="truncate hidden sm:inline">{it.label}</span>
        </button>
      ))}
    </div>
  )
}

function PassengerSearch({ selected, onPick }: {
  selected: TripPassenger | null
  onPick: (p: TripPassenger) => void
}) {
  const [mode, setMode] = useState<'registered' | 'guest'>(
    selected?.kind === 'guest' ? 'guest' : 'registered',
  )
  const [q, setQ] = useState('')
  const [results, setResults] = useState<AdminUser[]>([])
  const [loading, setLoading] = useState(false)
  const [searchError, setSearchError] = useState<string | null>(null)
  const selectedId = selected?.kind === 'registered' ? selected.user.id : null

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
      {/* Ronda 271: dos vías para el pasajero. La central recibe llamadas de
          gente sin la app, y antes solo se podía buscar entre los registrados. */}
      <div className="grid grid-cols-2 gap-2 p-1 bg-gray-100 rounded-lg">
        <button
          type="button"
          onClick={() => setMode('registered')}
          className={`px-3 py-1.5 rounded-md text-xs font-medium transition-colors ${
            mode === 'registered' ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-500 hover:text-gray-700'
          }`}
        >
          Cliente registrado
        </button>
        <button
          type="button"
          onClick={() => setMode('guest')}
          className={`px-3 py-1.5 rounded-md text-xs font-medium transition-colors ${
            mode === 'guest' ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-500 hover:text-gray-700'
          }`}
        >
          Cliente nuevo
        </button>
      </div>

      {mode === 'guest' && <GuestPassengerForm initial={selected} onPick={onPick} />}

      {mode === 'registered' && (
        <>
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
              onClick={() => onPick({ kind: 'registered', user: u })}
              className={`w-full p-3 flex items-center gap-3 text-left hover:bg-gray-50 ${selectedId === u.id ? 'bg-red-50' : ''}`}
            >
              <div className="w-9 h-9 flex-shrink-0 rounded-full bg-blue-100 text-blue-700 flex items-center justify-center text-sm font-semibold">
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
        <div className="text-center py-6 text-sm text-gray-500 space-y-2">
          <p>Sin resultados</p>
          {/* Un buscador que no encuentra nada es justo el momento en que hace
              falta el alta: se ofrece aquí en vez de dejar al operador atascado. */}
          <button
            type="button"
            onClick={() => setMode('guest')}
            className="text-xs font-medium text-[#E31E24] hover:underline"
          >
            Registrar a este cliente como nuevo
          </button>
        </div>
      )}
        </>
      )}
    </div>
  )
}

/**
 * Alta rápida del cliente que llama por teléfono.
 *
 * Solo se piden nombre y teléfono: es lo que necesita el conductor para
 * recogerlo y lo único que el operador tiene a mano en mitad de una llamada.
 * El backend busca ese teléfono antes de crear nada, así que un habitual no
 * acumula una ficha por llamada.
 */
function GuestPassengerForm({ initial, onPick }: {
  initial: TripPassenger | null
  onPick: (p: TripPassenger) => void
}) {
  const [fullName, setFullName] = useState(initial?.kind === 'guest' ? initial.fullName : '')
  const [phone, setPhone] = useState(initial?.kind === 'guest' ? initial.phone : '+51')
  const [touched, setTouched] = useState(false)

  const trimmedName = fullName.trim()
  const trimmedPhone = phone.trim()
  const nameOk = trimmedName.length >= 2
  // Mismo formato que exige el backend; validarlo aquí evita el viaje de ida y
  // vuelta al servidor para decir lo que ya se sabe en el navegador.
  const phoneOk = /^\+[1-9][0-9]{9,14}$/.test(trimmedPhone)

  const submit = () => {
    setTouched(true)
    if (!nameOk || !phoneOk) return
    onPick({ kind: 'guest', fullName: trimmedName, phone: trimmedPhone })
  }

  return (
    <div className="space-y-3">
      <p className="text-xs text-gray-500">
        Para quien pide el viaje por teléfono y no tiene la app. Se le crea una ficha
        con estos datos; si ya llamó antes, se reutiliza la suya.
      </p>
      <div>
        <label htmlFor="guest-name" className="block text-xs font-medium text-gray-700 mb-1">
          Nombre del cliente
        </label>
        <input
          id="guest-name"
          value={fullName}
          onChange={(e) => setFullName(e.target.value)}
          placeholder="María Quispe"
          autoFocus
          className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm"
        />
        {touched && !nameOk && (
          <p className="text-xs text-red-600 mt-1">Escribe el nombre del cliente.</p>
        )}
      </div>
      <div>
        <label htmlFor="guest-phone" className="block text-xs font-medium text-gray-700 mb-1">
          Teléfono
        </label>
        <input
          id="guest-phone"
          value={phone}
          onChange={(e) => setPhone(e.target.value)}
          onKeyDown={(e) => { if (e.key === 'Enter') submit() }}
          placeholder="+51999888777"
          inputMode="tel"
          className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm"
        />
        {touched && !phoneOk && (
          <p className="text-xs text-red-600 mt-1">Con código de país, así: +51999888777.</p>
        )}
      </div>
      <button
        type="button"
        onClick={submit}
        className="w-full px-3 py-2 bg-[#E31E24] hover:bg-[#B5181D] text-white text-sm font-semibold rounded-lg"
      >
        Continuar con este cliente
      </button>
    </div>
  )
}

function UserTypeBadge({ type }: { type: string }) {
  /**
   * Ronda 283: aquí se está buscando a un PASAJERO, así que todo el que sale
   * en la lista puede serlo — decir "Pasajero" o "Conductor y pasajero" no
   * distingue nada. Lo único que aporta la etiqueta en este contexto es avisar
   * de que esa persona además conduce, por si se le está creando un viaje a
   * quien no toca. Se quita también 'driver', que ya no existe (migración 027).
   */
  const styles: Record<string, string> = {
    dual: 'bg-orange-100 text-orange-700',
    admin: 'bg-red-100 text-red-700',
  }
  const labels: Record<string, string> = {
    dual: 'También conductor', admin: 'Admin',
  }
  // Para un pasajero normal no se pinta nada: es lo que se espera encontrar.
  if (!labels[type]) return null
  return (
    <span className={`text-[10px] font-medium px-1.5 py-0.5 rounded flex-shrink-0 ${styles[type] ?? 'bg-gray-100 text-gray-600'}`}>
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

  // Ronda 281: buscar la dirección escribiéndola, además de tocando el mapa.
  // Quien atiende el teléfono oye «Jockey Plaza»; buscar eso a ojo en el mapa
  // es al revés de lo cómodo.
  const [q, setQ] = useState('')
  const [results, setResults] = useState<PlacePrediction[]>([])
  const [searching, setSearching] = useState(false)
  const [searchError, setSearchError] = useState<string | null>(null)
  // El centro del mapa sesga las sugerencias hacia lo que se está mirando.
  const [center, setCenter] = useState<{ lat: number; lng: number }>({
    lat: DEFAULT_CENTER[0], lng: DEFAULT_CENTER[1],
  })
  // Descarta la respuesta vieja que llega después de la nueva. Mismo recurso
  // que usa `VerificationsPage` para su buscador.
  const requestSeq = useRef(0)
  const mapRef = useRef<LeafletMap | null>(null)
  /**
   * Ronda 283: el campo de búsqueda, para colgar de él la lista de resultados
   * desde fuera del panel lateral. Ver `FloatingLayer`.
   *
   * Se guarda en estado y no solo en un ref porque un ref no provoca
   * repintado: al montar vale `null`, y si la lista se pintara mirando el ref
   * no habría nada a lo que anclarse todavía.
   */
  const [buscadorEl, setBuscadorEl] = useState<HTMLDivElement | null>(null)
  const buscadorRef = useCallback((el: HTMLDivElement | null) => setBuscadorEl(el), [])

  /**
   * Ronda 283: marca que el texto lo acaba de poner el propio programa al
   * elegir una sugerencia, no la persona escribiendo.
   *
   * Sin esto, elegir una dirección no cerraba la lista: `handlePickPrediction`
   * la vacía, pero acto seguido escribe la dirección elegida en el campo, y
   * ese cambio vuelve a disparar la búsqueda, que la rellena otra vez con las
   * mismas sugerencias. Quedaba tapando el mapa después de haber elegido.
   *
   * Es un ref y no un estado a propósito: cambiarlo no debe repintar nada, y
   * el efecto tiene que verlo ya puesto en la misma vuelta.
   */
  const textoPuestoPorNosotros = useRef(false)

  useEffect(() => {
    // Elegir una sugerencia no es escribir: no se vuelve a buscar.
    if (textoPuestoPorNosotros.current) {
      textoPuestoPorNosotros.current = false
      return
    }
    // El endpoint devuelve lista vacía con menos de 2 caracteres; no gastamos
    // la petición.
    if (q.trim().length < 2) { setResults([]); setSearchError(null); return }
    const t = setTimeout(async () => {
      const seq = ++requestSeq.current
      setSearching(true)
      setSearchError(null)
      try {
        const resp = await adminApi.searchPlaces(q.trim(), center)
        if (seq !== requestSeq.current) return
        setResults(resp.predictions ?? [])
      } catch (e) {
        if (seq !== requestSeq.current) return
        setResults([])
        setSearchError(
          e instanceof AdminApiError
            ? `Error al buscar: ${e.message || e.code}`
            : 'Error al buscar direcciones (revisa conexión).',
        )
      } finally {
        if (seq === requestSeq.current) setSearching(false)
      }
    }, 300)
    return () => clearTimeout(t)
    // `center` a propósito fuera: cambiarlo al volar el mapa no debe relanzar
    // la búsqueda que acaba de provocar ese vuelo.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [q])

  /**
   * Ronda 281: al pasar de RECOJO a DESTINO hay que vaciar la selección.
   *
   * Este componente es el mismo en los dos pasos —solo cambia la prop `step`—,
   * así que React conserva su estado. El marcador temporal del recojo seguía
   * ahí al llegar al destino, con el botón ya diciendo «Usar este punto como
   * DESTINO» y la dirección del recojo debajo: bastaba un clic distraído para
   * mandar a alguien al sitio del que lo estabas recogiendo. El buscador nuevo
   * lo empeoraba, porque además arrastraba el texto escrito.
   *
   * De paso, el mapa se acerca al recojo al entrar en el destino: casi siempre
   * el viaje empieza cerca de ahí.
   */
  useEffect(() => {
    setTemp(null)
    setQ('')
    setResults([])
    setSearchError(null)
    if (step === 'destination' && pickup) {
      mapRef.current?.flyTo([pickup.lat, pickup.lng], 14)
    }
    // `pickup` fuera: solo interesa el momento en que se cambia de paso.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [step])

  const handleClick = async (lat: number, lng: number) => {
    setBusy(true)
    try {
      const { address } = await adminApi.reverseGeocode(lat, lng)
      setTemp({ lat, lng, address })
    } catch {
      setTemp({ lat, lng, address: `${lat.toFixed(6)}, ${lng.toFixed(6)}` })
    } finally { setBusy(false) }
  }

  /**
   * Ronda 281: colocar en el mapa la sugerencia elegida.
   *
   * Si la predicción ya trae coordenadas, se usan. Solo si no las trae se pide
   * `placeDetails`. El orden importa: los identificadores de Mapbox
   * (`address.8248…`) no los sabe resolver ese endpoint, y saltarse las
   * coordenadas que ya venían fue justo el fallo de la ronda 262 en la app —
   * el texto se escribía y no pasaba nada más.
   */
  const handlePickPrediction = async (p: PlacePrediction) => {
    setResults([])
    // Antes de escribir en el campo: si no, el efecto de búsqueda lo tomaría
    // por tecleo y volvería a abrir la lista que se acaba de cerrar.
    //
    // Solo se marca si el texto cambia de verdad: con el mismo valor React no
    // repinta, el efecto no llega a correr y la marca se quedaría puesta,
    // comiéndose la siguiente búsqueda que sí escribiera la persona.
    if (p.description !== q) textoPuestoPorNosotros.current = true
    setQ(p.description)
    setBusy(true)
    setSearchError(null)
    try {
      let lat = p.lat
      let lng = p.lng
      if ((lat == null || lng == null) && p.placeId) {
        const d = await adminApi.placeDetails(p.placeId)
        lat = d.lat ?? undefined
        lng = d.lng ?? undefined
      }
      if (lat == null || lng == null) {
        // Sin coordenada no hay punto. Se dice, en vez de dejar el texto
        // puesto aparentando que se eligió algo.
        setSearchError('No se pudo ubicar esa dirección. Elige otra o tócala en el mapa.')
        return
      }
      setTemp({ lat, lng, address: p.description })
      mapRef.current?.flyTo([lat, lng], 16)
    } catch (e) {
      setSearchError(
        e instanceof AdminApiError
          ? `No se pudo ubicar: ${e.message || e.code}`
          : 'No se pudo ubicar esa dirección.',
      )
    } finally { setBusy(false) }
  }

  return (
    <div className="p-4 space-y-3">
      <p className="text-xs text-gray-500">
        {step === 'pickup'
          ? 'Escribe la dirección de RECOJO o tócala en el mapa'
          : 'Escribe la dirección de DESTINO o tócala en el mapa'}
      </p>

      {/* Ronda 281: buscador de direcciones. Mismo aspecto que el de pasajero
          de esta misma pantalla, para que no parezcan dos buscadores. */}
      <div className="relative" ref={buscadorRef}>
        <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
        <input
          value={q}
          onChange={(e) => setQ(e.target.value)}
          type="text"
          placeholder={step === 'pickup' ? 'Ej: Jockey Plaza, Surco' : '¿A dónde va?'}
          className="w-full pl-10 pr-9 py-2 border border-gray-200 rounded-lg text-sm"
        />
        {(searching || q.length > 0) && (
          <div className="absolute right-3 top-1/2 -translate-y-1/2">
            {searching ? (
              <Loader2 className="w-4 h-4 animate-spin text-gray-400" />
            ) : (
              <button
                type="button"
                aria-label="Limpiar búsqueda"
                onClick={() => { setQ(''); setResults([]); setSearchError(null) }}
                className="text-gray-400 hover:text-gray-600"
              >
                <X className="w-4 h-4" />
              </button>
            )}
          </div>
        )}
        {/* Ronda 283: en una capa fuera del panel lateral. Ese panel es un
            `overflow-y-auto`, así que la lista se cortaba por abajo justo
            cuando había resultados que leer. `matchWidth` la deja del mismo
            ancho que el campo, como si siguiera colgando de él. */}
        {results.length > 0 && (
          <FloatingLayer
            anchor={buscadorEl}
            matchWidth
            onClose={() => setResults([])}
          >
          <ul className="bg-white border border-gray-200 rounded-lg shadow-lg max-h-56 overflow-y-auto divide-y divide-gray-100">
            {results.map((p, i) => (
              <li key={`${p.placeId ?? 'sin-id'}-${i}`}>
                <button
                  type="button"
                  onClick={() => void handlePickPrediction(p)}
                  className="w-full text-left px-3 py-2 hover:bg-gray-50"
                >
                  <div className="text-sm text-gray-900 truncate">{p.mainText || p.description}</div>
                  {p.secondaryText && (
                    <div className="text-xs text-gray-500 truncate">{p.secondaryText}</div>
                  )}
                </button>
              </li>
            ))}
          </ul>
          </FloatingLayer>
        )}
      </div>
      {searchError && (
        <p className="text-xs text-red-600">{searchError}</p>
      )}
      {!searching && !searchError && q.trim().length >= 2 && results.length === 0 && !temp && (
        <p className="text-xs text-gray-500">Sin resultados. Prueba con otra escritura o tócalo en el mapa.</p>
      )}

      <div className="rounded-lg overflow-hidden border border-gray-200 h-[45vh] min-h-[240px] max-h-[360px]">
        <MapContainer
          center={DEFAULT_CENTER}
          zoom={13}
          style={{ height: '100%' }}
          ref={mapRef}
        >
          <VectorBasemap />
          <ClickCapture onClick={handleClick} />
          <CenterTracker onMove={setCenter} />
          {pickup && <Marker position={[pickup.lat, pickup.lng]} icon={pickupIcon()} />}
          {destination && <Marker position={[destination.lat, destination.lng]} icon={destinationIcon()} />}
          {temp && <Marker position={[temp.lat, temp.lng]} icon={step === 'pickup' ? pickupIcon() : destinationIcon()} />}
          {onlineDrivers.filter((d) => hasCoords(d.latitude, d.longitude)).map((d) => (
            <Marker
              key={d.driverId}
              position={[d.latitude!, d.longitude!]}
              icon={driverIcon(d.activeRideId ? 'busy' : 'free')}
            />
          ))}
        </MapContainer>
      </div>
      {temp && (
        <div className="p-3 bg-gray-50 border border-gray-200 rounded-lg space-y-2">
          <div className="text-xs text-gray-500">Dirección seleccionada:</div>
          <div className="text-sm text-gray-900 break-words">{busy ? 'Buscando...' : temp.address}</div>
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

/**
 * Ronda 281: sigue el centro del mapa para sesgar las sugerencias hacia lo que
 * el administrador está mirando. Sin esto, escribir «Los Olivos» devuelve
 * resultados de todo el país en vez de los de al lado.
 */
function CenterTracker({ onMove }: { onMove: (c: { lat: number; lng: number }) => void }) {
  const map = useMapEvents({
    moveend: () => {
      const c = map.getCenter()
      onMove({ lat: c.lat, lng: c.lng })
    },
  })
  return null
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
  passenger: TripPassenger; pickup: Point; destination: Point
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
        <div className="flex items-start gap-2">
          <User className="w-4 h-4 text-blue-600 mt-0.5 flex-shrink-0" />
          <span className="min-w-0 break-words">
            <strong>{passengerLabel(passenger)}</strong> · {passengerContact(passenger)}
            {passenger.kind === 'guest' && (
              <span className="ml-2 text-[10px] font-medium px-1.5 py-0.5 rounded bg-amber-100 text-amber-800 whitespace-nowrap">
                Cliente nuevo
              </span>
            )}
          </span>
        </div>
        <div className="flex items-start gap-2"><MapPin className="w-4 h-4 text-green-600 mt-0.5 flex-shrink-0" /><span className="text-gray-700 break-words">{pickup.address}</span></div>
        <div className="flex items-start gap-2"><MapPin className="w-4 h-4 text-red-600 mt-0.5 flex-shrink-0" /><span className="text-gray-700 break-words">{destination.address}</span></div>
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

      <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
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
