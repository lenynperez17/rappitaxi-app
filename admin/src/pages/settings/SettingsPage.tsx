import { useEffect, useState } from 'react'
import { Loader2, Save, CheckCircle2, AlertCircle } from 'lucide-react'
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
    setSaving(true)
    try {
      await adminApi.updateSettings(edited)
      setFlash({ kind: 'ok', msg: `${Object.keys(edited).length} ajuste(s) guardado(s)` })
      await load()
    } catch (err) {
      setFlash({ kind: 'err', msg: err instanceof Error ? err.message : 'Error guardando' })
    } finally {
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
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Configuración</h1>
          <p className="text-sm text-gray-500 mt-1">Parámetros globales del sistema (tabla <code className="bg-gray-100 px-1 rounded text-xs">app_settings</code>)</p>
        </div>
        <button
          onClick={save}
          disabled={!dirty || saving}
          className="inline-flex items-center gap-2 px-4 py-2 bg-[#E31E24] hover:bg-[#B5181D] text-white text-sm font-semibold rounded-lg disabled:opacity-50"
        >
          {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
          Guardar cambios
        </button>
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
                        <div className="flex items-center gap-2">
                          <code className="text-xs font-mono text-gray-600 bg-gray-100 px-1.5 py-0.5 rounded">{s.key}</code>
                          {isDirty && <span className="text-[10px] font-semibold text-orange-600 bg-orange-50 px-1.5 py-0.5 rounded">modificado</span>}
                        </div>
                        {s.description && <p className="text-xs text-gray-500 mt-1">{s.description}</p>}
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
