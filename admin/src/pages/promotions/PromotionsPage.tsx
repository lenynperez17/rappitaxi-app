import { useEffect, useRef, useState, type FormEvent } from 'react'
import { Loader2, Plus, Tag, CheckCircle2, AlertCircle, X } from 'lucide-react'
import { adminApi } from '../../lib/adminApi'

interface Vale {
  id: string
  code: string
  description: string | null
  discountType: string
  discountValue: number
  maxUses: number | null
  usedCount: number
  minRideAmount: number | null
  startsAt: string | null
  expiresAt: string | null
  isActive: boolean
  createdAt: string
}

export function PromotionsPage() {
  const [vales, setVales] = useState<Vale[]>([])
  const [loading, setLoading] = useState(true)
  const [showCreate, setShowCreate] = useState(false)
  const [flash, setFlash] = useState<{ kind: 'ok' | 'err'; msg: string } | null>(null)

  const load = async () => {
    setLoading(true)
    try {
      const resp = await adminApi.listVales()
      setVales(resp.vales)
    } catch (err) {
      setFlash({ kind: 'err', msg: err instanceof Error ? err.message : 'Error cargando' })
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

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Promociones y vales</h1>
          <p className="text-sm text-gray-500 mt-1">Códigos de descuento aplicables al viaje</p>
        </div>
        <button
          onClick={() => setShowCreate(true)}
          className="inline-flex items-center gap-2 px-4 py-2 bg-[#E31E24] hover:bg-[#B5181D] text-white text-sm font-semibold rounded-lg"
        >
          <Plus className="w-4 h-4" /> Nuevo vale
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

      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        <div className="p-4 border-b border-gray-100 flex items-center justify-between">
          <div className="text-sm text-gray-700">Total: <b>{vales.length}</b></div>
        </div>
        {loading ? (
          <div className="p-12 text-center"><Loader2 className="w-6 h-6 mx-auto animate-spin text-gray-400" /></div>
        ) : vales.length === 0 ? (
          <div className="p-12 text-center text-sm text-gray-500">
            <Tag className="w-8 h-8 mx-auto mb-2 text-gray-300" />
            No hay vales aún. Crea uno para empezar.
          </div>
        ) : (
          <table className="w-full">
            <thead className="bg-gray-50 text-xs text-gray-500 uppercase">
              <tr>
                <th className="text-left px-4 py-3">Código</th>
                <th className="text-left px-4 py-3">Descripción</th>
                <th className="text-left px-4 py-3">Descuento</th>
                <th className="text-left px-4 py-3">Usos</th>
                <th className="text-left px-4 py-3">Expira</th>
                <th className="text-left px-4 py-3">Estado</th>
              </tr>
            </thead>
            <tbody>
              {vales.map((v) => (
                <tr key={v.id} className="border-t border-gray-100 hover:bg-gray-50 text-sm">
                  <td className="px-4 py-3 font-mono font-semibold text-gray-900">{v.code}</td>
                  <td className="px-4 py-3 text-gray-700">{v.description || '—'}</td>
                  <td className="px-4 py-3 text-gray-700">
                    {v.discountType === 'percent' ? `${v.discountValue}%` : `S/ ${v.discountValue.toFixed(2)}`}
                  </td>
                  <td className="px-4 py-3 text-gray-700">
                    {v.usedCount}{v.maxUses ? ` / ${v.maxUses}` : ''}
                  </td>
                  <td className="px-4 py-3 text-gray-500 text-xs">
                    {v.expiresAt ? new Date(v.expiresAt).toLocaleDateString('es-PE') : 'Sin límite'}
                  </td>
                  <td className="px-4 py-3">
                    {v.isActive
                      ? <span className="text-xs font-semibold px-2 py-0.5 bg-green-100 text-green-700 rounded-full">Activo</span>
                      : <span className="text-xs font-semibold px-2 py-0.5 bg-gray-100 text-gray-500 rounded-full">Inactivo</span>}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {showCreate && (
        <CreateValeModal
          onClose={() => setShowCreate(false)}
          onCreated={async () => {
            setShowCreate(false)
            setFlash({ kind: 'ok', msg: 'Vale creado' })
            await load()
          }}
        />
      )}
    </div>
  )
}

function CreateValeModal({ onClose, onCreated }: { onClose: () => void; onCreated: () => void }) {
  const [code, setCode] = useState('')
  const [description, setDescription] = useState('')
  const [discountType, setDiscountType] = useState<'percent' | 'flat'>('percent')
  const [discountValue, setDiscountValue] = useState(10)
  const [maxUses, setMaxUses] = useState<number | ''>('')
  const [expiresAt, setExpiresAt] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState('')
  // Ronda 214: guard contra doble-Enter rápido antes de que setSubmitting
  // rerenderice el botón como disabled. Sin este ref, dos Enters muy juntos
  // creaban dos vales duplicados. Mismo patrón que LoginPage.tsx.
  const submittingRef = useRef(false)

  const submit = async (e: FormEvent) => {
    e.preventDefault()
    if (submittingRef.current) return
    if (!code.trim() || discountValue <= 0) {
      setError('Código y valor requeridos')
      return
    }
    // Guardrails contra typos que quemarían dinero:
    // - Porcentaje: 100% máximo (nada de "-1000% que le pague al pasajero")
    // - Monto fijo: S/500 tope razonable para vales de taxi urbano
    if (discountType === 'percent' && discountValue > 100) {
      setError('El descuento porcentual no puede exceder 100%')
      return
    }
    if (discountType === 'flat' && discountValue > 500) {
      setError('El descuento fijo máximo es S/ 500')
      return
    }
    submittingRef.current = true
    setSubmitting(true)
    setError('')
    try {
      await adminApi.createVale({
        code: code.trim().toUpperCase(),
        description: description || undefined,
        discountType,
        discountValue,
        maxUses: maxUses === '' ? undefined : Number(maxUses),
        expiresAt: expiresAt || undefined,
      })
      onCreated()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Error creando vale')
      setSubmitting(false)
      submittingRef.current = false
    }
  }

  return (
    <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-xl w-full max-w-md p-6">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-semibold text-gray-900">Nuevo vale</h2>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600">
            <X className="w-5 h-5" />
          </button>
        </div>
        {error && (
          <div className="mb-3 p-2 bg-red-50 border border-red-200 rounded text-sm text-red-700">{error}</div>
        )}
        <form onSubmit={submit} className="space-y-3">
          <div>
            <label className="block text-xs font-semibold text-gray-700 mb-1">Código</label>
            <input
              type="text" value={code}
              onChange={(e) => setCode(e.target.value)}
              placeholder="RAPI2026"
              className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm font-mono uppercase"
              required
            />
          </div>
          <div>
            <label className="block text-xs font-semibold text-gray-700 mb-1">Descripción (opcional)</label>
            <input
              type="text" value={description}
              onChange={(e) => setDescription(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm"
            />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-semibold text-gray-700 mb-1">Tipo</label>
              <select
                value={discountType}
                onChange={(e) => setDiscountType(e.target.value as 'percent' | 'flat')}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm"
              >
                <option value="percent">Porcentaje (%)</option>
                <option value="flat">Monto fijo (S/)</option>
              </select>
            </div>
            <div>
              <label className="block text-xs font-semibold text-gray-700 mb-1">Valor</label>
              <input
                type="number"
                min={1}
                max={discountType === 'percent' ? 100 : 500}
                step={0.5}
                value={discountValue}
                onChange={(e) => setDiscountValue(Number(e.target.value))}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm"
                required
              />
            </div>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-semibold text-gray-700 mb-1">Usos máximos</label>
              <input
                type="number" min={1}
                value={maxUses}
                onChange={(e) => setMaxUses(e.target.value === '' ? '' : Number(e.target.value))}
                placeholder="Sin límite"
                className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm"
              />
            </div>
            <div>
              <label className="block text-xs font-semibold text-gray-700 mb-1">Expira</label>
              <input
                type="date" value={expiresAt}
                onChange={(e) => setExpiresAt(e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm"
              />
            </div>
          </div>
          <button
            type="submit"
            disabled={submitting}
            className="w-full py-2.5 bg-[#E31E24] hover:bg-[#B5181D] text-white text-sm font-semibold rounded-lg disabled:opacity-60 flex items-center justify-center gap-2"
          >
            {submitting && <Loader2 className="w-4 h-4 animate-spin" />}
            {submitting ? 'Creando...' : 'Crear vale'}
          </button>
        </form>
      </div>
    </div>
  )
}
