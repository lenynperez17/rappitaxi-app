import { useEffect, useMemo, useState } from 'react'
import { collection, query, where, onSnapshot, getDocs, limit as fbLimit } from 'firebase/firestore'
import { httpsCallable } from 'firebase/functions'
import { db, functions } from '../../config/firebase'
import { APIProvider, Map, AdvancedMarker, InfoWindow, Pin, useMapsLibrary } from '@vis.gl/react-google-maps'
import { Loader2, Car, MapPin, Plus, X, Search, AlertCircle, CheckCircle2, Phone } from 'lucide-react'

interface DriverPin {
  id: string
  name: string
  lat: number
  lng: number
  vehicle?: string
  plate?: string
}

interface PassengerOption {
  id: string
  name: string
  email?: string
  phone?: string
}

interface LatLngAddress {
  lat: number
  lng: number
  address: string
}

const GOOGLE_MAPS_API_KEY =
  (import.meta as any).env?.VITE_GOOGLE_MAPS_API_KEY ??
  'CHANGEME'

const LIMA_CENTER = { lat: -12.046374, lng: -77.042793 }

export function LiveMapPage() {
  const [drivers, setDrivers] = useState<DriverPin[]>([])
  const [selected, setSelected] = useState<DriverPin | null>(null)
  const [loading, setLoading] = useState(true)
  const [showOrderModal, setShowOrderModal] = useState(false)

  useEffect(() => {
    setLoading(true)
    const q = query(collection(db, 'users'), where('isOnline', '==', true))
    const unsub = onSnapshot(
      q,
      (snap) => {
        const list: DriverPin[] = []
        snap.docs.forEach((d) => {
          const data = d.data() as any
          if (data.userType !== 'driver' && data.userType !== 'dual') return
          const loc = data.currentLocation ?? data.location
          const lat = loc?.latitude ?? loc?.lat
          const lng = loc?.longitude ?? loc?.lng
          if (typeof lat !== 'number' || typeof lng !== 'number') return
          list.push({
            id: d.id,
            name: data.fullName ?? data.name ?? 'Conductor',
            lat,
            lng,
            vehicle: data.vehicleInfo
              ? `${data.vehicleInfo.make ?? ''} ${data.vehicleInfo.model ?? ''}`.trim()
              : undefined,
            plate: data.vehicleInfo?.plate,
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

  return (
    <APIProvider apiKey={GOOGLE_MAPS_API_KEY} libraries={['places']}>
      <div className="space-y-4">
        <div className="flex items-center justify-between flex-wrap gap-2">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Mapa en Vivo</h1>
            <p className="text-sm text-gray-500 mt-1">
              Conductores online y pedidos manuales en tiempo real
            </p>
          </div>
          <div className="flex items-center gap-3">
            <div className="flex items-center gap-2 text-sm text-gray-700">
              <Car className="w-4 h-4 text-green-600" />
              <span>
                <strong>{drivers.length}</strong> online
              </span>
              {loading && <Loader2 className="w-4 h-4 animate-spin text-[#E31E24]" />}
            </div>
            <button
              onClick={() => setShowOrderModal(true)}
              className="flex items-center gap-2 px-4 py-2 bg-[#E31E24] hover:bg-[#B5181D] text-white rounded-lg text-sm font-medium"
            >
              <Plus className="w-4 h-4" /> Nuevo pedido
            </button>
          </div>
        </div>

        <div
          className="bg-white rounded-xl border border-gray-200 overflow-hidden"
          style={{ height: 'calc(100vh - 220px)', minHeight: 500 }}
        >
          <Map
            defaultCenter={LIMA_CENTER}
            defaultZoom={12}
            mapId="rapi-team-live"
            gestureHandling="greedy"
            disableDefaultUI={false}
            style={{ width: '100%', height: '100%' }}
          >
            {drivers.map((d) => (
              <AdvancedMarker
                key={d.id}
                position={{ lat: d.lat, lng: d.lng }}
                onClick={() => setSelected(d)}
              >
                <Pin background={'#E31E24'} borderColor={'#B5181D'} glyphColor={'#fff'} />
              </AdvancedMarker>
            ))}
            {selected && (
              <InfoWindow
                position={{ lat: selected.lat, lng: selected.lng }}
                onCloseClick={() => setSelected(null)}
              >
                <div className="text-sm space-y-1 min-w-[180px]">
                  <p className="font-bold text-gray-900">{selected.name}</p>
                  {selected.vehicle && <p className="text-gray-600">{selected.vehicle}</p>}
                  {selected.plate && (
                    <p className="text-gray-500 font-mono text-xs">Placa: {selected.plate}</p>
                  )}
                  <p className="text-gray-400 text-xs flex items-center gap-1">
                    <MapPin className="w-3 h-3" />
                    {selected.lat.toFixed(5)}, {selected.lng.toFixed(5)}
                  </p>
                </div>
              </InfoWindow>
            )}
          </Map>
        </div>

        {drivers.length === 0 && !loading && (
          <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4 text-sm text-yellow-800">
            No hay conductores online en este momento. Los marcadores aparecerán cuando se pongan en
            línea desde la app.
          </div>
        )}

        {showOrderModal && (
          <NewOrderModal
            onClose={() => setShowOrderModal(false)}
            onSuccess={() => setShowOrderModal(false)}
          />
        )}
      </div>
    </APIProvider>
  )
}

// ============================================================
// New Order Modal
// ============================================================

function NewOrderModal({
  onClose,
  onSuccess,
}: {
  onClose: () => void
  onSuccess: () => void
}) {
  const [mode, setMode] = useState<'guest' | 'registered'>('guest')

  // Guest mode
  const [guestName, setGuestName] = useState('')
  const [guestPhone, setGuestPhone] = useState('+51 ')

  // Registered mode
  const [passengers, setPassengers] = useState<PassengerOption[]>([])
  const [loadingPassengers, setLoadingPassengers] = useState(false)
  const [passengerSearch, setPassengerSearch] = useState('')
  const [selectedPassenger, setSelectedPassenger] = useState<PassengerOption | null>(null)

  // Ride
  const [pickup, setPickup] = useState<LatLngAddress | null>(null)
  const [destination, setDestination] = useState<LatLngAddress | null>(null)
  const [fare, setFare] = useState<string>('')
  const [rideType, setRideType] = useState<'express' | 'ejecutivo' | 'vip'>('express')
  const [notes, setNotes] = useState('')

  // UI
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [success, setSuccess] = useState<string | null>(null)

  useEffect(() => {
    if (mode === 'registered' && passengers.length === 0) {
      void loadPassengers()
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [mode])

  const loadPassengers = async () => {
    setLoadingPassengers(true)
    try {
      const snap = await getDocs(
        query(collection(db, 'users'), where('userType', 'in', ['passenger', 'dual']), fbLimit(500)),
      )
      const list: PassengerOption[] = snap.docs.map((d) => {
        const data = d.data() as any
        return {
          id: d.id,
          name: data.fullName ?? data.name ?? '(sin nombre)',
          email: data.email,
          phone: data.phone ?? data.phoneNumber,
        }
      })
      list.sort((a, b) => a.name.localeCompare(b.name))
      setPassengers(list)
    } catch (err) {
      console.error('Load passengers error:', err)
    } finally {
      setLoadingPassengers(false)
    }
  }

  const filteredPassengers = useMemo(() => {
    const q = passengerSearch.trim().toLowerCase()
    if (!q) return passengers.slice(0, 20)
    return passengers
      .filter(
        (p) =>
          p.name.toLowerCase().includes(q) ||
          p.email?.toLowerCase().includes(q) ||
          p.phone?.includes(q),
      )
      .slice(0, 20)
  }, [passengers, passengerSearch])

  const fareNumber = parseFloat(fare) || 0

  const validate = (): string | null => {
    if (mode === 'guest') {
      if (!guestName.trim()) return 'Nombre del cliente requerido'
      if (!/^\+51\s?9\d{8}$/.test(guestPhone.replace(/\s/g, ''))) {
        return 'Teléfono inválido. Formato: +51 9XXXXXXXX'
      }
    } else {
      if (!selectedPassenger) return 'Selecciona un pasajero'
    }
    if (!pickup) return 'Selecciona origen'
    if (!destination) return 'Selecciona destino'
    if (fareNumber <= 0) return 'Monto debe ser mayor a 0'
    return null
  }

  const handleSubmit = async () => {
    const err = validate()
    if (err) {
      setError(err)
      return
    }
    setError(null)
    setSuccess(null)
    setSubmitting(true)
    try {
      const fn = httpsCallable<any, { ok: boolean; rideId: string; estimatedDistance: number }>(
        functions,
        'createManualRide',
      )
      const payload =
        mode === 'guest'
          ? {
              mode: 'guest' as const,
              guestName: guestName.trim(),
              guestPhone: guestPhone.replace(/\s/g, ''),
              pickup,
              destination,
              fare: fareNumber,
              rideType,
              notes: notes.trim() || null,
              paymentMethod: 'cash',
            }
          : {
              mode: 'registered' as const,
              passengerId: selectedPassenger!.id,
              pickup,
              destination,
              fare: fareNumber,
              rideType,
              notes: notes.trim() || null,
              paymentMethod: 'cash',
            }
      const res = await fn(payload)
      setSuccess(
        `Pedido creado ✅ Ride ID ${res.data.rideId.slice(0, 8)}... Conductores cercanos están siendo notificados.`,
      )
      setTimeout(onSuccess, 2000)
    } catch (err: any) {
      console.error(err)
      setError(err?.message ?? 'Error al crear pedido')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-xl shadow-2xl max-w-3xl w-full max-h-[95vh] overflow-y-auto">
        <div className="sticky top-0 bg-white border-b border-gray-200 px-6 py-4 flex items-center justify-between z-10">
          <h2 className="text-lg font-semibold text-gray-900">Nuevo pedido manual</h2>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-700">
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="p-6 space-y-5">
          {/* Toggle modo */}
          <div className="flex gap-2 bg-gray-100 p-1 rounded-lg">
            <button
              onClick={() => setMode('guest')}
              className={`flex-1 py-2 rounded text-sm font-medium ${
                mode === 'guest' ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-600'
              }`}
            >
              📞 Cliente nuevo (sin app)
            </button>
            <button
              onClick={() => setMode('registered')}
              className={`flex-1 py-2 rounded text-sm font-medium ${
                mode === 'registered' ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-600'
              }`}
            >
              👤 Cliente registrado
            </button>
          </div>

          {/* Datos del cliente */}
          {mode === 'guest' ? (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              <div>
                <label className="block text-xs font-medium text-gray-700 mb-1">
                  Nombre del cliente
                </label>
                <input
                  type="text"
                  value={guestName}
                  onChange={(e) => setGuestName(e.target.value)}
                  placeholder="Ej: Carlos Pérez"
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#E31E24]"
                />
              </div>
              <div>
                <label className="block text-xs font-medium text-gray-700 mb-1">
                  Teléfono (para que conductor llame)
                </label>
                <input
                  type="tel"
                  value={guestPhone}
                  onChange={(e) => setGuestPhone(e.target.value)}
                  placeholder="+51 9XXXXXXXX"
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#E31E24]"
                />
              </div>
            </div>
          ) : (
            <div>
              <label className="block text-xs font-medium text-gray-700 mb-1">
                Pasajero registrado
              </label>
              {selectedPassenger ? (
                <div className="flex items-center justify-between p-3 bg-blue-50 border border-blue-200 rounded-lg">
                  <div>
                    <p className="font-medium text-gray-900">{selectedPassenger.name}</p>
                    <p className="text-xs text-gray-600">
                      {selectedPassenger.email} · {selectedPassenger.phone}
                    </p>
                  </div>
                  <button
                    onClick={() => setSelectedPassenger(null)}
                    className="text-blue-600 hover:text-blue-800 text-sm"
                  >
                    Cambiar
                  </button>
                </div>
              ) : (
                <div className="space-y-2">
                  <div className="relative">
                    <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
                    <input
                      type="text"
                      value={passengerSearch}
                      onChange={(e) => setPassengerSearch(e.target.value)}
                      placeholder="Buscar por nombre, email o teléfono..."
                      className="w-full pl-9 pr-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#E31E24]"
                    />
                  </div>
                  {loadingPassengers ? (
                    <p className="text-xs text-gray-500 py-2">Cargando...</p>
                  ) : (
                    <div className="max-h-40 overflow-y-auto border border-gray-200 rounded-lg divide-y">
                      {filteredPassengers.length === 0 ? (
                        <p className="text-xs text-gray-400 p-4 text-center">Sin resultados</p>
                      ) : (
                        filteredPassengers.map((p) => (
                          <button
                            key={p.id}
                            onClick={() => setSelectedPassenger(p)}
                            className="w-full px-3 py-2 text-left hover:bg-gray-50"
                          >
                            <p className="font-medium text-gray-900 text-sm">{p.name}</p>
                            <p className="text-xs text-gray-500">
                              {p.email} · {p.phone}
                            </p>
                          </button>
                        ))
                      )}
                    </div>
                  )}
                </div>
              )}
            </div>
          )}

          {/* Origen y destino */}
          <div className="space-y-3">
            <div>
              <label className="block text-xs font-medium text-gray-700 mb-1">Origen</label>
              <PlacesAutocompleteInput
                placeholder="Dirección de recojo..."
                value={pickup}
                onChange={setPickup}
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-700 mb-1">Destino</label>
              <PlacesAutocompleteInput
                placeholder="Dirección de destino..."
                value={destination}
                onChange={setDestination}
              />
            </div>
          </div>

          {/* Tipo + Monto */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-medium text-gray-700 mb-1">Tipo de viaje</label>
              <select
                value={rideType}
                onChange={(e) => setRideType(e.target.value as any)}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm"
              >
                <option value="express">Express</option>
                <option value="ejecutivo">Ejecutivo</option>
                <option value="vip">VIP</option>
              </select>
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-700 mb-1">Monto (S/)</label>
              <input
                type="number"
                step="0.5"
                min="1"
                value={fare}
                onChange={(e) => setFare(e.target.value)}
                placeholder="Ej: 15.00"
                className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#E31E24]"
              />
            </div>
          </div>

          {/* Notas */}
          <div>
            <label className="block text-xs font-medium text-gray-700 mb-1">
              Notas (opcional, visible para el conductor)
            </label>
            <textarea
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="Ej: Llamar al llegar, casa con portón rojo..."
              rows={2}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#E31E24]"
            />
          </div>

          {/* Mensajes */}
          {error && (
            <div className="bg-red-50 border border-red-200 rounded-lg p-3 flex items-start gap-2 text-sm text-red-700">
              <AlertCircle className="w-4 h-4 mt-0.5 flex-shrink-0" />
              <span>{error}</span>
            </div>
          )}
          {success && (
            <div className="bg-green-50 border border-green-200 rounded-lg p-3 flex items-start gap-2 text-sm text-green-700">
              <CheckCircle2 className="w-4 h-4 mt-0.5 flex-shrink-0" />
              <span>{success}</span>
            </div>
          )}
        </div>

        <div className="sticky bottom-0 bg-white border-t border-gray-200 px-6 py-3 flex justify-end gap-2">
          <button
            onClick={onClose}
            disabled={submitting}
            className="px-4 py-2 bg-white border border-gray-300 rounded-lg text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-50"
          >
            Cancelar
          </button>
          <button
            onClick={handleSubmit}
            disabled={submitting}
            className="px-5 py-2 bg-[#E31E24] hover:bg-[#B5181D] text-white rounded-lg text-sm font-medium disabled:opacity-50 flex items-center gap-2"
          >
            {submitting && <Loader2 className="w-4 h-4 animate-spin" />}
            <Phone className="w-4 h-4" />
            Crear pedido y notificar conductores
          </button>
        </div>
      </div>
    </div>
  )
}

// ============================================================
// Google Places Autocomplete Input
// ============================================================

function PlacesAutocompleteInput({
  placeholder,
  value,
  onChange,
}: {
  placeholder: string
  value: LatLngAddress | null
  onChange: (val: LatLngAddress | null) => void
}) {
  const placesLib = useMapsLibrary('places')
  const [input, setInput] = useState(value?.address ?? '')
  const [predictions, setPredictions] = useState<google.maps.places.AutocompletePrediction[]>([])
  const [showList, setShowList] = useState(false)
  const [service, setService] = useState<google.maps.places.AutocompleteService | null>(null)
  const [placesService, setPlacesService] = useState<google.maps.places.PlacesService | null>(null)

  useEffect(() => {
    if (!placesLib) return
    setService(new placesLib.AutocompleteService())
    // PlacesService requires a DOM element, we use a hidden div
    const div = document.createElement('div')
    setPlacesService(new placesLib.PlacesService(div))
  }, [placesLib])

  useEffect(() => {
    if (!service || input.length < 3) {
      setPredictions([])
      return
    }
    const handler = setTimeout(() => {
      service.getPlacePredictions(
        {
          input,
          componentRestrictions: { country: 'pe' },
          types: ['geocode'],
        },
        (results) => setPredictions(results ?? []),
      )
    }, 250)
    return () => clearTimeout(handler)
  }, [input, service])

  const selectPrediction = (pred: google.maps.places.AutocompletePrediction) => {
    setShowList(false)
    setInput(pred.description)
    if (!placesService) return
    placesService.getDetails({ placeId: pred.place_id, fields: ['geometry', 'formatted_address'] }, (place) => {
      if (place?.geometry?.location) {
        onChange({
          lat: place.geometry.location.lat(),
          lng: place.geometry.location.lng(),
          address: place.formatted_address ?? pred.description,
        })
      }
    })
  }

  return (
    <div className="relative">
      <MapPin className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
      <input
        type="text"
        value={input}
        onChange={(e) => {
          setInput(e.target.value)
          setShowList(true)
          if (!e.target.value.trim()) onChange(null)
        }}
        onFocus={() => setShowList(true)}
        onBlur={() => setTimeout(() => setShowList(false), 200)}
        placeholder={placeholder}
        className="w-full pl-9 pr-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#E31E24]"
      />
      {value && (
        <p className="text-xs text-green-600 mt-1">
          ✓ {value.lat.toFixed(5)}, {value.lng.toFixed(5)}
        </p>
      )}
      {showList && predictions.length > 0 && (
        <div className="absolute top-full left-0 right-0 mt-1 bg-white border border-gray-200 rounded-lg shadow-lg z-20 max-h-48 overflow-y-auto">
          {predictions.map((p) => (
            <button
              key={p.place_id}
              type="button"
              onMouseDown={() => selectPrediction(p)}
              className="w-full px-3 py-2 text-left text-sm hover:bg-gray-50 border-b border-gray-100 last:border-0"
            >
              <p className="font-medium text-gray-900">{p.structured_formatting?.main_text}</p>
              <p className="text-xs text-gray-500">{p.structured_formatting?.secondary_text}</p>
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
