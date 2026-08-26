import { useEffect, useRef, useState } from 'react'
import { Link } from 'react-router-dom'
import { Loader2, Save, CheckCircle2, AlertCircle, Car } from 'lucide-react'
import { adminApi } from '../../lib/adminApi'

interface Setting {
  key: string
  value: unknown
  description: string | null
  updatedAt: string
}

const GROUPS: Record<string, string> = {
  company: 'Empresa',
  rides: 'Viajes',
  wallet: 'Billetera',
  registration: 'Registros',
  maintenance_mode: 'Sistema',
}

/**
 * Ronda 276: nombre legible de cada ajuste.
 *
 * La pantalla mostraba la clave de la base de datos tal cual —
 * `wallet.min_withdrawal`, `rides.commission_percent` — como título de cada
 * fila. Son identificadores técnicos, en inglés y con guiones bajos, en una
 * pantalla que usa personal administrativo.
 */
const LABELS: Record<string, string> = {
  'company.address': 'Dirección fiscal',
  'company.name': 'Nombre comercial',
  'company.ruc': 'RUC',
  'company.support_email': 'Correo de soporte',
  'company.facebook_url': 'Facebook',
  'company.instagram_url': 'Instagram',
  'company.tiktok_url': 'TikTok',
  'company.x_url': 'X (Twitter)',
  'company.whatsapp': 'WhatsApp de contacto',
  'maintenance_mode': 'Modo mantenimiento',
  'registration.driver_enabled': 'Registro de conductores',
  'registration.passenger_enabled': 'Registro de pasajeros',
  'rides.commission_percent': 'Comisión por viaje',
  'rides.max_distance_km': 'Distancia máxima por viaje',
  'rides.min_fare': 'Tarifa mínima',
  'rides.min_balance_to_accept': 'Saldo mínimo para aceptar viajes',
  'rides.negotiable': 'Negociación de precio',
  'wallet.min_recharge': 'Recarga mínima',
  'wallet.min_withdrawal': 'Retiro mínimo',
  'wallet.withdrawal_fee': 'Cargo por retiro',
}

/**
 * Para un ajuste que se añada al backend y todavía no esté en `LABELS`, se
 * arma un título presentable a partir de la clave en vez de dejar el
 * identificador crudo: quita el prefijo del grupo, cambia guiones bajos por
 * espacios y pone la inicial en mayúscula.
 */
function labelOf(key: string): string {
  if (LABELS[key]) return LABELS[key]
  const sinPrefijo = key.includes('.') ? key.slice(key.indexOf('.') + 1) : key
  const palabras = sinPrefijo.replace(/_/g, ' ').trim()
  return palabras.charAt(0).toUpperCase() + palabras.slice(1)
}

function groupOf(key: string): string {
  if (key.startsWith('company.')) return 'company'
  if (key.startsWith('rides.')) return 'rides'
  if (key.startsWith('wallet.')) return 'wallet'
  if (key.startsWith('registration.')) return 'registration'
  return 'maintenance_mode'
}

function valueTypeOf(v: unknown): 'string' | 'number' | 'boolean' {
  if (typeof v === 'boolean') return 'boolean'
  if (typeof v === 'number') return 'number'
  return 'string'
}

export function SettingsPage() {
  const [settings, setSettings] = useState<Setting[]>([])
  const [edited, setEdited] = useState<Record<string, unknown>>({})
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  // Ronda 177: ref síncrono contra doble-submit del formulario de settings.
  const savingRef = useRef(false)
  const [flash, setFlash] = useState<{ kind: 'ok' | 'err'; msg: string } | null>(null)

  const load = async () => {
    setLoading(true)
    try {
      const resp = await adminApi.listSettings()
      setSettings(resp.settings)
      setEdited({})
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'Error cargando configuración'
      setFlash({ kind: 'err', msg })
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { void load() }, [])

  useEffect(() => {
    if (!flash) return
    const t = setTimeout(() => setFlash(null), 4000)
    return () => clearTimeout(t)
  }, [flash])

  const dirty = Object.keys(edited).length > 0

  const save = async () => {
    if (savingRef.current) return
    savingRef.current = true
    setSaving(true)
    try {
      await adminApi.updateSettings(edited)
      setFlash({ kind: 'ok', msg: `${Object.keys(edited).length} ajuste(s) guardado(s)` })
      await load()
    } catch (err) {
      setFlash({ kind: 'err', msg: err instanceof Error ? err.message : 'Error guardando' })
    } finally {
      savingRef.current = false
      setSaving(false)
    }
  }

  const setValue = (key: string, val: unknown) => {
    setEdited((prev) => ({ ...prev, [key]: val }))
  }

  const getVal = (key: string, original: unknown): unknown =>
    edited[key] !== undefined ? edited[key] : original

  const grouped = settings.reduce<Record<string, Setting[]>>((acc, s) => {
    const g = groupOf(s.key)
    if (!acc[g]) acc[g] = []
    acc[g].push(s)
    return acc
  }, {})

  return (
    <div className="space-y-6">
      {/* Ronda 270: ver nota en InvoicesPage — misma cabecera, mismo desborde. */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="min-w-0">
          <h1 className="text-2xl font-bold text-gray-900">Configuración</h1>
          {/* Ronda 276: decía "(tabla app_settings)". El nombre de una tabla de
              la base de datos no le dice nada a quien administra el negocio. */}
          <p className="text-sm text-gray-500 mt-1">Parámetros que afectan a toda la plataforma</p>
        </div>
        <div className="flex items-center gap-2 flex-shrink-0">
          {/* Ronda 281: los servicios (Express, VIP, Minivan…) no caben en esta
              pantalla, que solo pinta valores sueltos. Tienen la suya, y desde
              aquí es donde la gente la va a buscar. */}
          <Link
            to="/settings/servicios"
            className="inline-flex items-center gap-2 px-4 py-2 border border-gray-200 text-gray-700 hover:bg-gray-50 text-sm font-medium rounded-lg whitespace-nowrap"
          >
            <Car className="w-4 h-4" /> Servicios y tarifas
          </Link>
          <button
            onClick={save}
            disabled={!dirty || saving}
            className="inline-flex items-center gap-2 px-4 py-2 bg-[#E31E24] hover:bg-[#B5181D] text-white text-sm font-semibold rounded-lg disabled:opacity-50 whitespace-nowrap"
          >
            {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
            Guardar cambios
          </button>
        </div>
      </div>

      {flash && (
        <div className={`flex items-center gap-3 p-3 rounded-lg text-sm border ${
          flash.kind === 'ok' ? 'bg-green-50 border-green-200 text-green-700' : 'bg-red-50 border-red-200 text-red-700'
        }`}>
          {flash.kind === 'ok' ? <CheckCircle2 className="w-4 h-4" /> : <AlertCircle className="w-4 h-4" />}
          {flash.msg}
        </div>
      )}

      {loading ? (
        <div className="p-12 text-center"><Loader2 className="w-6 h-6 mx-auto animate-spin text-gray-400" /></div>
      ) : (
        <div className="space-y-6">
          {Object.entries(grouped).map(([groupKey, items]) => (
            <div key={groupKey} className="bg-white rounded-xl border border-gray-200">
              <div className="p-4 border-b border-gray-100">
                <h3 className="text-sm font-semibold text-gray-900">{GROUPS[groupKey] || groupKey}</h3>
              </div>
              <div className="divide-y divide-gray-100">
                {items.map((s) => {
                  const type = valueTypeOf(s.value)
                  const current = getVal(s.key, s.value)
                  const isDirty = edited[s.key] !== undefined
                  return (
                    <div key={s.key} className="p-4 flex items-center gap-4">
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2 flex-wrap">
                          {/* El título es el nombre en castellano; la clave técnica
                              se conserva en el tooltip porque sigue haciendo falta
                              para dar soporte o mirar la tabla directamente. */}
                          <span className="text-sm font-medium text-gray-900" title={`Clave: ${s.key}`}>
                            {labelOf(s.key)}
                          </span>
                          {isDirty && <span className="text-[10px] font-semibold text-orange-600 bg-orange-50 px-1.5 py-0.5 rounded">modificado</span>}
                        </div>
                        {/* La descripción solo aparece si aporta algo: para
                            varios ajustes coincide palabra por palabra con el
                            título y se leía repetida. */}
                        {s.description && s.description.trim() !== labelOf(s.key) && (
                          <p className="text-xs text-gray-500 mt-1">{s.description}</p>
                        )}
                      </div>
                      <div className="flex-shrink-0">
                        {type === 'boolean' ? (
                          <label className="inline-flex items-center gap-2 cursor-pointer">
                            <input
                              type="checkbox"
                              checked={Boolean(current)}
                              onChange={(e) => setValue(s.key, e.target.checked)}
                              disabled={saving}
                              className="w-4 h-4 disabled:opacity-50"
                            />
                            <span className="text-sm text-gray-700">{Boolean(current) ? 'Sí' : 'No'}</span>
                          </label>
                        ) : type === 'number' ? (
                          <input
                            type="number"
                            value={Number(current)}
                            onChange={(e) => setValue(s.key, Number(e.target.value))}
                            disabled={saving}
                            className="w-32 px-3 py-1.5 border border-gray-300 rounded-lg text-sm text-right disabled:bg-gray-50 disabled:opacity-50"
                          />
                        ) : (
                          <input
                            type="text"
                            value={String(current ?? '')}
                            onChange={(e) => setValue(s.key, e.target.value)}
                            disabled={saving}
                            className="w-72 px-3 py-1.5 border border-gray-300 rounded-lg text-sm disabled:bg-gray-50 disabled:opacity-50"
                          />
                        )}
                      </div>
                    </div>
                  )
                })}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
