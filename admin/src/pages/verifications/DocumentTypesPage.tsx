import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import {
  AlertCircle, AlertTriangle, ArrowLeft, CheckCircle2, FileText, Loader2, Save,
} from 'lucide-react'
import { adminApi, AdminApiError, type AdminDocumentType } from '../../lib/adminApi'

/**
 * Ronda 279 — qué documentos se le piden al conductor.
 *
 * Lo pidió el dueño: poder activar y desactivar desde el panel qué documentos
 * se solicitan, y que la app los muestre u oculte en consecuencia.
 *
 * POR QUÉ ESTÁ AQUÍ Y NO EN CONFIGURACIÓN
 * ---------------------------------------
 * `SettingsPage` guarda cada ajuste como un valor suelto: texto, número o
 * sí/no. Una lista de documentos con dos interruptores por fila no cabe en esa
 * forma —se guardaría serializada como texto y quedaría corrupta—, así que
 * vive en Verificaciones, que es donde se usa.
 *
 * LOS DOS INTERRUPTORES SON DISTINTOS
 * -----------------------------------
 * "Se pide" decide si el documento aparece en la app. "Es obligatorio" decide
 * si hace falta para quedar verificado. Un documento que no se pide no puede
 * ser obligatorio, y por eso al apagar el primero se apaga el segundo.
 */
export function DocumentTypesPage() {
  const [types, setTypes] = useState<AdminDocumentType[]>([])
  const [original, setOriginal] = useState<AdminDocumentType[]>([])
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [saved, setSaved] = useState(false)
  // Cuando el servidor avisa de que nos quedaríamos sin obligatorios, guardamos
  // el aviso aquí y el botón pasa a pedir confirmación explícita.
  const [zeroRequiredWarning, setZeroRequiredWarning] = useState<string | null>(null)

  const load = async () => {
    setLoading(true)
    setError(null)
    try {
      const resp = await adminApi.listDocumentTypes()
      setTypes(resp.documentTypes)
      setOriginal(resp.documentTypes)
    } catch (err) {
      setError(err instanceof AdminApiError ? err.message : 'Error cargando los documentos')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    void load()
  }, [])

  const setFlag = (code: string, field: 'enabled' | 'required', value: boolean) => {
    setSaved(false)
    setZeroRequiredWarning(null)
    setTypes((prev) =>
      prev.map((t) => {
        if (t.code !== code) return t
        if (field === 'enabled') {
          // Dejar de pedir un documento y seguir exigiéndolo dejaría al
          // conductor sin forma de verificarse nunca.
          return { ...t, enabled: value, required: value ? t.required : false }
        }
        // Marcarlo obligatorio implica pedirlo.
        return { ...t, required: value, enabled: value ? true : t.enabled }
      }),
    )
  }

  const changed = types.filter((t) => {
    const before = original.find((o) => o.code === t.code)
    return before && (before.enabled !== t.enabled || before.required !== t.required)
  })

  const save = async (allowZeroRequired = false) => {
    if (changed.length === 0) return
    setSaving(true)
    setError(null)
    try {
      await adminApi.updateDocumentTypes(
        changed.map((t) => ({ code: t.code, enabled: t.enabled, required: t.required })),
        allowZeroRequired,
      )
      setZeroRequiredWarning(null)
      setSaved(true)
      await load()
    } catch (err) {
      if (err instanceof AdminApiError && err.status === 409) {
        setZeroRequiredWarning(err.message)
      } else {
        setError(err instanceof AdminApiError ? err.message : 'Error guardando')
      }
    } finally {
      setSaving(false)
    }
  }

  const requiredCount = types.filter((t) => t.enabled && t.required).length
  const enabledCount = types.filter((t) => t.enabled).length

  return (
    <div className="space-y-6">
      <div className="flex items-start justify-between gap-4 flex-wrap">
        <div>
          <Link
            to="/verifications"
            className="text-sm text-gray-500 hover:text-gray-700 inline-flex items-center gap-1 mb-2"
          >
            <ArrowLeft className="w-4 h-4" /> Verificaciones
          </Link>
          <h1 className="text-2xl font-bold text-gray-900">Documentos solicitados</h1>
          <p className="text-sm text-gray-500 mt-1">
            Elige qué documentos se le piden al conductor en la app y cuáles hacen
            falta para darlo por verificado.
          </p>
        </div>
        <button
          onClick={() => void save()}
          disabled={saving || changed.length === 0}
          className="inline-flex items-center gap-2 px-4 py-2 rounded-lg bg-orange-500 text-white text-sm font-medium disabled:opacity-40 disabled:cursor-not-allowed hover:bg-orange-600"
        >
          {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
          {changed.length === 0 ? 'Sin cambios' : `Guardar ${changed.length} cambio${changed.length === 1 ? '' : 's'}`}
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
          Guardado. Los conductores lo verán la próxima vez que abran la app.
        </div>
      )}

      {zeroRequiredWarning && (
        <div className="p-4 rounded-lg bg-amber-50 border border-amber-300 text-sm text-amber-900 space-y-3">
          <div className="flex items-start gap-2">
            <AlertTriangle className="w-4 h-4 mt-0.5 shrink-0" />
            <span>{zeroRequiredWarning}</span>
          </div>
          <div className="flex gap-2">
            <button
              onClick={() => void save(true)}
              disabled={saving}
              className="px-3 py-1.5 rounded-lg bg-amber-600 text-white text-xs font-medium hover:bg-amber-700 disabled:opacity-40"
            >
              Sí, guardar sin documentos obligatorios
            </button>
            <button
              onClick={() => setZeroRequiredWarning(null)}
              className="px-3 py-1.5 rounded-lg border border-amber-300 text-xs font-medium hover:bg-amber-100"
            >
              Cancelar
            </button>
          </div>
        </div>
      )}

      <div className="bg-white rounded-xl border border-gray-200 p-4 flex flex-wrap gap-6 text-sm">
        <div>
          <div className="text-gray-500">Se piden</div>
          <div className="text-xl font-semibold text-gray-900">{enabledCount}</div>
        </div>
        <div>
          <div className="text-gray-500">Obligatorios para verificar</div>
          <div className="text-xl font-semibold text-gray-900">{requiredCount}</div>
        </div>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        {loading ? (
          <div className="p-12 text-center text-gray-500 flex items-center justify-center gap-2">
            <Loader2 className="w-4 h-4 animate-spin" /> Cargando...
          </div>
        ) : types.length === 0 ? (
          <div className="p-12 text-center text-gray-500">
            <FileText className="w-10 h-10 mx-auto mb-3 text-gray-300" />
            No hay documentos configurados
          </div>
        ) : (
          <ul className="divide-y divide-gray-100">
            {types.map((t) => (
              <li key={t.code} className="p-4 flex flex-col md:flex-row md:items-center gap-4">
                <div className="flex-1 min-w-0">
                  <div className="font-medium text-gray-900">{t.label}</div>
                  <div className="text-xs text-gray-500 mt-0.5">{t.description}</div>
                  <div className="text-xs text-gray-400 mt-1 flex items-center gap-2 flex-wrap">
                    <code className="bg-gray-100 px-1.5 py-0.5 rounded">{t.code}</code>
                    {t.uploadedCount > 0 && (
                      <span>
                        {t.uploadedCount} subido{t.uploadedCount === 1 ? '' : 's'}
                      </span>
                    )}
                  </div>
                </div>
                <div className="flex items-center gap-6 shrink-0">
                  <Toggle
                    label="Se pide"
                    checked={t.enabled}
                    onChange={(v) => setFlag(t.code, 'enabled', v)}
                  />
                  <Toggle
                    label="Obligatorio"
                    checked={t.required}
                    disabled={!t.enabled}
                    onChange={(v) => setFlag(t.code, 'required', v)}
                  />
                </div>
              </li>
            ))}
          </ul>
        )}
      </div>

      <p className="text-xs text-gray-500">
        Desactivar un documento no borra los que ya se subieron: solo deja de
        pedirse a partir de ahora.
      </p>
    </div>
  )
}

function Toggle({
  label,
  checked,
  disabled,
  onChange,
}: {
  label: string
  checked: boolean
  disabled?: boolean
  onChange: (value: boolean) => void
}) {
  return (
    <label
      className={`flex items-center gap-2 text-sm select-none ${
        disabled ? 'opacity-40 cursor-not-allowed' : 'cursor-pointer'
      }`}
    >
      <span className="text-gray-600 w-20 md:w-auto">{label}</span>
      <button
        type="button"
        role="switch"
        aria-checked={checked}
        aria-label={label}
        disabled={disabled}
        onClick={() => !disabled && onChange(!checked)}
        className={`relative w-11 h-6 rounded-full transition-colors focus:outline-none focus:ring-2 focus:ring-orange-400 focus:ring-offset-2 ${
          checked ? 'bg-orange-500' : 'bg-gray-300'
        } ${disabled ? 'cursor-not-allowed' : ''}`}
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
