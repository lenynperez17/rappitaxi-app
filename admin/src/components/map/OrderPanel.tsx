import { useEffect, useMemo, useState } from 'react'
import { collection, query, where, getDocs, limit as fbLimit } from 'firebase/firestore'
import { httpsCallable } from 'firebase/functions'
import { db, functions } from '../../config/firebase'
import { useMapsLibrary } from '@vis.gl/react-google-maps'
import {
  Loader2,
  MapPin,
  Search,
  AlertCircle,
  CheckCircle2,
  Phone,
  RotateCcw,
} from 'lucide-react'

export interface LatLngAddress {
  lat: number
  lng: number
  address: string
}

interface PassengerOption {
  id: string
  name: string
  email?: string
  phone?: string
}

interface OrderPanelProps {
  /**
   * Called whenever pickup changes — parent uses it to draw the
   * route polyline on the map.
   */
  onPickupChange: (val: LatLngAddress | null) => void
  /**
   * Called whenever destination changes.
   */
  onDestinationChange: (val: LatLngAddress | null) => void
  /**
   * Optional route metadata to display (km, min).
   */
  routeInfo?: { distanceMeters: number; durationSeconds: number } | null
}

export function OrderPanel({ onPickupChange, onDestinationChange, routeInfo }: OrderPanelProps) {
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
  const [pickup, setPickupState] = useState<LatLngAddress | null>(null)
  const [destination, setDestinationState] = useState<LatLngAddress | null>(null)
  const [fare, setFare] = useState<string>('')
  const [rideType, setRideType] = useState<'express' | 'ejecutivo' | 'vip'>('express')
  const [notes, setNotes] = useState('')

  // UI
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [success, setSuccess] = useState<string | null>(null)

  // Forward pickup/destination changes up to the parent so it can draw the route
  const setPickup = (val: LatLngAddress | null) => {
    setPickupState(val)
    onPickupChange(val)
  }
  const setDestination = (val: LatLngAddress | null) => {
    setDestinationState(val)
    onDestinationChange(val)
  }

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

  const resetForm = () => {
    setGuestName('')
    setGuestPhone('+51 ')
    setSelectedPassenger(null)
    setPassengerSearch('')
    setPickup(null)
    setDestination(null)
    setFare('')
    setRideType('express')
    setNotes('')
    setError(null)
    setSuccess(null)
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
      // Reset the form so the admin can create another ride immediately, but keep the panel open
      setTimeout(() => {
        resetForm()
      }, 2500)
    } catch (err: any) {
      console.error(err)
      setError(err?.message ?? 'Error al crear pedido')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div className="h-full flex flex-col bg-white">
      <div className="px-4 py-3 border-b border-gray-200 flex items-center justify-between bg-gradient-to-r from-[#E31E24] to-[#B5181D] text-white">
        <h2 className="text-base font-semibold flex items-center gap-2">
          <Phone className="w-4 h-4" /> Nuevo pedido
        </h2>
        <button
          type="button"
          onClick={resetForm}
          title="Limpiar formulario"
          className="text-white/80 hover:text-white p-1 rounded hover:bg-white/10"
        >
          <RotateCcw className="w-4 h-4" />
        </button>
      </div>

      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        {/* Toggle modo */}
        <div className="flex gap-1 bg-gray-100 p-1 rounded-lg">
          <button
            type="button"
            onClick={() => setMode('guest')}
            className={`flex-1 py-2 rounded text-xs font-medium ${
              mode === 'guest' ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-600'
            }`}
          >
            📞 Cliente nuevo
          </button>
          <button
            type="button"
            onClick={() => setMode('registered')}
            className={`flex-1 py-2 rounded text-xs font-medium ${
              mode === 'registered' ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-600'
            }`}
          >
            👤 Registrado
          </button>
        </div>

        {/* Datos cliente */}
        {mode === 'guest' ? (
          <div className="space-y-2">
            <div>
              <label className="block text-xs font-medium text-gray-700 mb-1">Nombre</label>
              <input
                type="text"
                value={guestName}
                onChange={(e) => setGuestName(e.target.value)}
                placeholder="Ej: Carlos Pérez"
                className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#E31E24]"
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-700 mb-1">Teléfono</label>
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
            <label className="block text-xs font-medium text-gray-700 mb-1">Pasajero</label>
            {selectedPassenger ? (
              <div className="flex items-center justify-between p-2.5 bg-blue-50 border border-blue-200 rounded-lg">
                <div className="min-w-0">
                  <p className="font-medium text-gray-900 text-sm truncate">
                    {selectedPassenger.name}
                  </p>
                  <p className="text-xs text-gray-600 truncate">
                    {selectedPassenger.email} · {selectedPassenger.phone}
                  </p>
                </div>
                <button
                  type="button"
                  onClick={() => setSelectedPassenger(null)}
                  className="text-blue-600 hover:text-blue-800 text-xs ml-2 shrink-0"
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
                    placeholder="Buscar pasajero..."
                    className="w-full pl-9 pr-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#E31E24]"
                  />
                </div>
                {loadingPassengers ? (
                  <p className="text-xs text-gray-500 py-1">Cargando...</p>
                ) : (
                  <div className="max-h-32 overflow-y-auto border border-gray-200 rounded-lg divide-y">
                    {filteredPassengers.length === 0 ? (
                      <p className="text-xs text-gray-400 p-3 text-center">Sin resultados</p>
                    ) : (
                      filteredPassengers.map((p) => (
                        <button
                          key={p.id}
                          type="button"
                          onClick={() => setSelectedPassenger(p)}
                          className="w-full px-3 py-2 text-left hover:bg-gray-50"
                        >
                          <p className="font-medium text-gray-900 text-sm truncate">{p.name}</p>
                          <p className="text-xs text-gray-500 truncate">
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

        {/* Origen / destino */}
        <div className="space-y-2">
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

        {/* Ruta info */}
        {routeInfo && (
          <div className="bg-gray-50 border border-gray-200 rounded-lg px-3 py-2 text-xs text-gray-700 flex justify-between">
            <span>
              📏 <strong>{(routeInfo.distanceMeters / 1000).toFixed(1)} km</strong>
            </span>
            <span>
              ⏱️ <strong>{Math.round(routeInfo.durationSeconds / 60)} min</strong>
            </span>
          </div>
        )}

        {/* Tipo + Monto */}
        <div className="grid grid-cols-2 gap-2">
          <div>
            <label className="block text-xs font-medium text-gray-700 mb-1">Tipo</label>
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
            <label className="block text-xs font-medium text-gray-700 mb-1">Monto S/</label>
            <input
              type="number"
              step="0.5"
              min="1"
              value={fare}
              onChange={(e) => setFare(e.target.value)}
              placeholder="15.00"
              className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#E31E24]"
            />
          </div>
        </div>

        {/* Notas */}
        <div>
          <label className="block text-xs font-medium text-gray-700 mb-1">Notas</label>
          <textarea
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            placeholder="Casa portón rojo, llamar al llegar..."
            rows={2}
            className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#E31E24]"
          />
        </div>

        {/* Mensajes */}
        {error && (
          <div className="bg-red-50 border border-red-200 rounded-lg p-2.5 flex items-start gap-2 text-xs text-red-700">
            <AlertCircle className="w-4 h-4 mt-0.5 flex-shrink-0" />
            <span>{error}</span>
          </div>
        )}
        {success && (
          <div className="bg-green-50 border border-green-200 rounded-lg p-2.5 flex items-start gap-2 text-xs text-green-700">
            <CheckCircle2 className="w-4 h-4 mt-0.5 flex-shrink-0" />
            <span>{success}</span>
          </div>
        )}
      </div>

      {/* Submit button */}
      <div className="border-t border-gray-200 p-3 bg-gray-50">
        <button
          type="button"
          onClick={handleSubmit}
          disabled={submitting}
          className="w-full px-4 py-2.5 bg-[#E31E24] hover:bg-[#B5181D] text-white rounded-lg text-sm font-medium disabled:opacity-50 flex items-center justify-center gap-2"
        >
          {submitting && <Loader2 className="w-4 h-4 animate-spin" />}
          <Phone className="w-4 h-4" />
          Crear pedido
        </button>
      </div>
    </div>
  )
}

// ============================================================
// Google Places Autocomplete Input (moved from LiveMapPage)
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

  // Sync internal input with external value (e.g. when parent resets the form)
  useEffect(() => {
    setInput(value?.address ?? '')
  }, [value?.address])

  useEffect(() => {
    if (!placesLib) return
    setService(new placesLib.AutocompleteService())
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
    placesService.getDetails(
      { placeId: pred.place_id, fields: ['geometry', 'formatted_address'] },
      (place) => {
        if (place?.geometry?.location) {
          onChange({
            lat: place.geometry.location.lat(),
            lng: place.geometry.location.lng(),
            address: place.formatted_address ?? pred.description,
          })
        }
      },
    )
  }

  return (
    <div className="relative">
      <MapPin className="w-4 h-4 absolute left-3 top-2.5 text-gray-400" />
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
        <p className="text-[10px] text-green-600 mt-0.5">
          ✓ {value.lat.toFixed(5)}, {value.lng.toFixed(5)}
        </p>
      )}
      {showList && predictions.length > 0 && (
        <div className="absolute top-full left-0 right-0 mt-1 bg-white border border-gray-200 rounded-lg shadow-lg z-30 max-h-44 overflow-y-auto">
          {predictions.map((p) => (
            <button
              key={p.place_id}
              type="button"
              onMouseDown={() => selectPrediction(p)}
              className="w-full px-3 py-2 text-left text-sm hover:bg-gray-50 border-b border-gray-100 last:border-0"
            >
              <p className="font-medium text-gray-900 text-xs">{p.structured_formatting?.main_text}</p>
              <p className="text-[10px] text-gray-500">{p.structured_formatting?.secondary_text}</p>
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
