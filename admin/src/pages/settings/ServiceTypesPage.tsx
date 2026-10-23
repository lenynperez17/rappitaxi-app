import { useState } from 'react'
import { Link } from 'react-router-dom'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import {
  AlertCircle, AlertTriangle, ArrowLeft, CheckCircle2, Car, Loader2, Save,
} from 'lucide-react'
import { adminApi, AdminApiError, type AdminServiceType } from '../../lib/adminApi'
import { queryKeys } from '../../lib/queryKeys'

type ServiceTypeEdit = Partial<Pick<AdminServiceType, 'enabled' | 'priceMultiplier'>>
const NO_SERVICE_TYPES: AdminServiceType[] = []

/**
 * Ronda 281 — qué servicios se le ofrecen al pasajero y a cuánto.
 *
 * La ronda 280 creó el catálogo `ride_service_types`, lo expuso en
 * `/api/config/app` y enseñó a la app a pintarlo desde ahí — pero se quedó sin
 * esta pantalla. Minivan existía, desactivada, y la única forma de encenderla
 * era entrar a la base de datos a mano. Eso no es "se activa desde el panel".
 *
 * EL AVISO DE CONDUCTORES ES LO IMPORTANTE
 * ----------------------------------------
 * Cada servicio solo se le ofrece a conductores cuyo vehículo registrado puede
 * atenderlo. Activar Minivan sin tener ninguna minivan registrada crea viajes
 * que no le llegan a nadie — y desde fuera parece que la app no funciona. Por
 * eso cada fila dice cuántos conductores podrían atenderla, y se avisa antes
 * de activar una que se quedaría sin nadie.
 */
export function ServiceTypesPage() {
  const queryClient = useQueryClient()
  // Ronda 287: lo del servidor vive en la caché y aquí solo los cambios sin
  // guardar, aplicados encima. Un refresco en segundo plano ya no pisa lo que
  // el admin estaba editando.
  const [edits, setEdits] = useState<Record<string, ServiceTypeEdit>>({})
  const [saving, setSaving] = useState(false)
  const [saveError, setSaveError] = useState<string | null>(null)
  const [saved, setSaved] = useState(false)
  const [zeroWarning, setZeroWarning] = useState<string | null>(null)

  const serviceTypesQuery = useQuery({
    queryKey: queryKeys.serviceTypes.all,
    queryFn: () => adminApi.listServiceTypes(),
  })
  const original = serviceTypesQuery.data?.serviceTypes ?? NO_SERVICE_TYPES
  const types = original.map((t) => ({ ...t, ...edits[t.code] }))
  const loading = serviceTypesQuery.isPending
  const error = saveError ?? (serviceTypesQuery.isError
    ? (serviceTypesQuery.error instanceof AdminApiError ? serviceTypesQuery.error.message : 'Error cargando los servicios')
    : null)

  const editType = (code: string, patch: ServiceTypeEdit) => {
    setSaved(false)
    setZeroWarning(null)
    setEdits((prev) => ({ ...prev, [code]: { ...prev[code], ...patch } }))
  }

  const setEnabled = (code: string, value: boolean) => editType(code, { enabled: value })

  const setMultiplier = (code: string, raw: string) => {
    const n = Number(raw)
    if (!Number.isFinite(n)) return
    editType(code, { priceMultiplier: n })
  }

  const changed = types.filter((t) => {
    const before = original.find((o) => o.code === t.code)
    return before
      && (before.enabled !== t.enabled || before.priceMultiplier !== t.priceMultiplier)
  })

  const save = async (allowZeroEnabled = false) => {
    if (changed.length === 0) return
    // El servidor lo rechaza igualmente, pero decirlo aquí evita un viaje de ida
    // y vuelta y un mensaje más críptico.
    const fuera = changed.find((t) => t.priceMultiplier <= 0 || t.priceMultiplier > 10)
    if (fuera) {
      setSaveError(`El multiplicador de ${fuera.label} debe estar entre 0 y 10.`)
      return
    }
    setSaving(true)
    setSaveError(null)
    try {
      await adminApi.updateServiceTypes(
        changed.map((t) => ({
          code: t.code,
          enabled: t.enabled,
          priceMultiplier: t.priceMultiplier,
        })),
        allowZeroEnabled,
      )
      setZeroWarning(null)
      setSaved(true)
      // Primero llega lo guardado y después se sueltan los cambios locales, para
      // que la tabla no enseñe un instante los valores de antes.
      await queryClient.invalidateQueries({ queryKey: queryKeys.serviceTypes.all })
      setEdits({})
    } catch (err) {
      if (err instanceof AdminApiError && err.status === 409) {
        setZeroWarning(err.message)
      } else {
        setSaveError(err instanceof AdminApiError ? err.message : 'Error guardando')
      }
    } finally {
      setSaving(false)
    }
  }

  const activos = types.filter((t) => t.enabled).length

  return (
    <div className="space-y-6">
      <div className="flex items-start justify-between gap-4 flex-wrap">
        <div>
          <Link
            to="/settings"
            className="text-sm text-gray-500 hover:text-gray-700 inline-flex items-center gap-1 mb-2"
          >
            <ArrowLeft className="w-4 h-4" /> Configuración
          </Link>
          <h1 className="text-2xl font-bold text-gray-900">Servicios y tarifas</h1>
          <p className="text-sm text-gray-500 mt-1">
            Qué servicios puede elegir el pasajero y cuánto cuesta cada uno respecto
            a la tarifa base. Los cambios se ven en la app sin actualizarla.
          </p>
        </div>
        <button
          onClick={() => void save()}
          disabled={saving || changed.length === 0}
          className="inline-flex items-center gap-2 px-4 py-2 rounded-lg bg-orange-500 text-white text-sm font-medium disabled:opacity-40 disabled:cursor-not-allowed hover:bg-orange-600"
        >
          {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
          {changed.length === 0
            ? 'Sin cambios'
            : `Guardar ${changed.length} cambio${changed.length === 1 ? '' : 's'}`}
        </button>
      </div>

      {error && (
        <div className="p-3 rounded-lg bg-red-50 border border-red-200 text-sm text-red-700 flex items-center gap-2">
          <AlertCircle className="w-4 h-4 shrink-0" /> {error}
        </div>
      )}

      {saved && (
        <div className="p-3 rounded-lg bg-green-50 border border-green-200 text-sm text-green-700 flex items-center gap-2">
          <CheckCircle2 className="w-4 h-4 shrink-0" />
          Guardado. Los pasajeros lo verán la próxima vez que abran la app.
        </div>
      )}

      {zeroWarning && (
        <div className="p-4 rounded-lg bg-amber-50 border border-amber-300 text-sm text-amber-900 space-y-3">
          <div className="flex items-start gap-2">
            <AlertTriangle className="w-4 h-4 mt-0.5 shrink-0" />
            <span>{zeroWarning}</span>
          </div>
          <div className="flex gap-2">
            <button
              onClick={() => void save(true)}
              disabled={saving}
              className="px-3 py-1.5 rounded-lg bg-amber-600 text-white text-xs font-medium hover:bg-amber-700 disabled:opacity-40"
            >
              Sí, guardar sin servicios activos
            </button>
            <button
              onClick={() => setZeroWarning(null)}
              className="px-3 py-1.5 rounded-lg border border-amber-300 text-xs font-medium hover:bg-amber-100"
            >
              Cancelar
            </button>
          </div>
        </div>
      )}

      <div className="bg-white rounded-xl border border-gray-200 p-4 flex flex-wrap gap-6 text-sm">
        <div>
          <div className="text-gray-500">Servicios activos</div>
          <div className="text-xl font-semibold text-gray-900">{activos}</div>
        </div>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        {loading ? (
          <div className="p-12 text-center text-gray-500 flex items-center justify-center gap-2">
            <Loader2 className="w-4 h-4 animate-spin" /> Cargando...
          </div>
        ) : types.length === 0 ? (
          <div className="p-12 text-center text-gray-500">
            <Car className="w-10 h-10 mx-auto mb-3 text-gray-300" />
            No hay servicios configurados
          </div>
        ) : (
          <ul className="divide-y divide-gray-100">
            {types.map((t) => {
              const sinConductores = t.enabled && t.driversAvailable === 0
              return (
                <li key={t.code} className="p-4 flex flex-col md:flex-row md:items-center gap-4">
                  <div className="flex-1 min-w-0">
                    <div className="font-medium text-gray-900">{t.label}</div>
                    <div className="text-xs text-gray-500 mt-0.5">{t.description}</div>
                    <div className="text-xs text-gray-400 mt-1 flex items-center gap-2 flex-wrap">
                      <code className="bg-gray-100 px-1.5 py-0.5 rounded">{t.code}</code>
                      <span>
                        {t.driversAvailable} conductor{t.driversAvailable === 1 ? '' : 'es'} puede
                        {t.driversAvailable === 1 ? '' : 'n'} atenderlo
                      </span>
                      {t.ridesCount > 0 && <span>· {t.ridesCount} viajes</span>}
                    </div>
                    {/* Lo que hace que activar Minivan no sea un tiro al aire. */}
                    {sinConductores && (
                      <div className="mt-2 text-xs text-amber-700 bg-amber-50 border border-amber-200 rounded px-2 py-1.5 inline-flex items-start gap-1.5">
                        <AlertTriangle className="w-3.5 h-3.5 mt-0.5 shrink-0" />
                        <span>
                          Ningún conductor tiene un vehículo de tipo{' '}
                          <strong>{t.vehicleTypes.join(' o ') || 'cualquiera'}</strong>. Si lo
                          activas, quien pida este servicio no encontrará a nadie hasta que un
                          conductor registre ese vehículo.
                        </span>
                      </div>
                    )}
                  </div>
                  <div className="flex items-center gap-6 shrink-0">
                    <label className="flex items-center gap-2 text-sm">
                      <span className="text-gray-600">Precio</span>
                      <input
                        type="number"
                        step="0.05"
                        min="0.1"
                        max="10"
                        value={t.priceMultiplier}
                        onChange={(e) => setMultiplier(t.code, e.target.value)}
                        className="w-20 border border-gray-200 rounded-lg px-2 py-1.5 text-sm text-right"
                      />
                      <span className="text-xs text-gray-400 w-12">
                        {t.priceMultiplier === 1
                          ? 'base'
                          : `${t.priceMultiplier > 1 ? '+' : ''}${Math.round((t.priceMultiplier - 1) * 100)}%`}
                      </span>
                    </label>
                    <Toggle
                      label="Se ofrece"
                      checked={t.enabled}
                      onChange={(v) => setEnabled(t.code, v)}
                    />
                  </div>
                </li>
              )
            })}
          </ul>
        )}
      </div>

      <p className="text-xs text-gray-500">
        El multiplicador se aplica sobre la tarifa sugerida: 1 es la tarifa base y
        1.4 la encarece un 40%. Desactivar un servicio no borra los viajes que ya
        se pidieron con él.
      </p>
    </div>
  )
}

function Toggle({
  label, checked, onChange,
}: {
  label: string
  checked: boolean
  onChange: (value: boolean) => void
}) {
  return (
    <label className="flex items-center gap-2 text-sm select-none cursor-pointer">
      <span className="text-gray-600">{label}</span>
      <button
        type="button"
        role="switch"
        aria-checked={checked}
        aria-label={label}
        onClick={() => onChange(!checked)}
        className={`relative w-11 h-6 rounded-full transition-colors focus:outline-none focus:ring-2 focus:ring-orange-400 focus:ring-offset-2 ${
          checked ? 'bg-orange-500' : 'bg-gray-300'
        }`}
      >
        <span
          className={`absolute top-0.5 left-0.5 w-5 h-5 bg-white rounded-full shadow transition-transform ${
            checked ? 'translate-x-5' : ''
          }`}
        />
      </button>
    </label>
  )
}
