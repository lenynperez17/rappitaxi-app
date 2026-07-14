import { useEffect, useState } from 'react'
import {
  FileMinus, Loader2, AlertCircle, Search, Plus, X, CheckCircle2,
} from 'lucide-react'
import { adminApi, AdminApiError, type AdminCreditNote, type AdminInvoice } from '../../lib/adminApi'
import { formatPEN } from '../../utils/currency'
import { relativeTime, toDate } from '../../utils/timeFormat'

const REASON_LABEL: Record<string, string> = {
  anulacion: 'Anulación',
  devolucion: 'Devolución',
  descuento_global: 'Descuento global',
  descuento_item: 'Descuento por ítem',
  ajuste_precio: 'Ajuste de precio',
  otros: 'Otros',
}

const STATUS_LABEL: Record<string, string> = {
  issued: 'Emitida', sunat_pending: 'Pendiente SUNAT', sunat_sent: 'Aceptada SUNAT', sunat_error: 'Error SUNAT',
}
const STATUS_BADGE: Record<string, string> = {
  issued: 'bg-yellow-100 text-yellow-700',
  sunat_pending: 'bg-yellow-100 text-yellow-700',
  sunat_sent: 'bg-green-100 text-green-700',
  sunat_error: 'bg-red-100 text-red-700',
}

export function CreditNotesPage() {
  const [items, setItems] = useState<AdminCreditNote[]>([])
  const [total, setTotal] = useState(0)
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [modalOpen, setModalOpen] = useState(false)
  const [flash, setFlash] = useState<{ kind: 'ok' | 'err'; msg: string } | null>(null)

  const load = async () => {
    setLoading(true); setError(null)
    try {
      const resp = await adminApi.listCreditNotes({
        search: search || undefined,
        pageSize: 100,
      })
      setItems(resp.creditNotes); setTotal(resp.total)
    } catch (err) {
      setError(err instanceof AdminApiError ? err.message : 'Error cargando notas de crédito')
    } finally { setLoading(false) }
  }

  useEffect(() => { void load() }, [])
  useEffect(() => {
    const t = setTimeout(() => void load(), 350)
    return () => clearTimeout(t)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [search])
  useEffect(() => {
    if (!flash) return
    const t = setTimeout(() => setFlash(null), 4000)
    return () => clearTimeout(t)
  }, [flash])

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Notas de Crédito</h1>
          <p className="text-sm text-gray-500 mt-1">Total: <strong>{total}</strong> nota(s) emitida(s)</p>
        </div>
        <button
          onClick={() => setModalOpen(true)}
          className="inline-flex items-center gap-2 px-4 py-2 bg-[#E31E24] hover:bg-[#B5181D] text-white text-sm font-semibold rounded-lg"
        >
          <Plus className="w-4 h-4" /> Emitir nota
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

      {error && (
        <div className="p-3 rounded-lg bg-red-50 border border-red-200 text-sm text-red-700 flex items-center gap-2">
          <AlertCircle className="w-4 h-4" /> {error}
        </div>
      )}

      <div className="bg-white rounded-xl border border-gray-200 p-4">
        <div className="flex-1 relative">
          <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input value={search} onChange={(e) => setSearch(e.target.value)}
            placeholder="Buscar por número o cliente..." type="text"
            className="w-full pl-10 pr-3 py-2 border border-gray-200 rounded-lg text-sm" />
        </div>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        {loading ? (
          <div className="p-12 text-center text-gray-500 flex items-center justify-center gap-2">
            <Loader2 className="w-4 h-4 animate-spin" /> Cargando notas...
          </div>
        ) : items.length === 0 ? (
          <div className="p-12 text-center text-gray-500">
            <FileMinus className="w-10 h-10 mx-auto mb-3 text-gray-300" />
            No hay notas de crédito emitidas todavía.
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-gray-50 text-gray-500 text-xs uppercase">
                <tr>
                  <th className="text-left px-4 py-3">Número</th>
                  <th className="text-left px-4 py-3">Documento asociado</th>
                  <th className="text-left px-4 py-3">Cliente</th>
                  <th className="text-left px-4 py-3">Motivo</th>
                  <th className="text-right px-4 py-3">Monto</th>
                  <th className="text-left px-4 py-3">Estado</th>
                  <th className="text-left px-4 py-3">Emitida</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {items.map((cn) => (
                  <tr key={cn.id} className="hover:bg-gray-50">
                    <td className="px-4 py-3">
                      <span className="font-mono font-medium text-gray-900">{cn.number}</span>
                    </td>
                    <td className="px-4 py-3">
                      <span className="font-mono text-xs text-gray-600">{cn.invoiceNumber ?? '—'}</span>
                    </td>
                    <td className="px-4 py-3 text-gray-900 truncate max-w-[200px]">
                      {cn.invoiceCustomer ?? '—'}
                    </td>
                    <td className="px-4 py-3">
                      <span className="px-2 py-0.5 rounded-full text-xs font-medium bg-orange-100 text-orange-700">
                        {REASON_LABEL[cn.reason] ?? cn.reason}
                      </span>
                      {cn.reasonNotes && (
                        <div className="text-xs text-gray-500 mt-1 truncate max-w-[220px]">{cn.reasonNotes}</div>
                      )}
                    </td>
                    <td className="px-4 py-3 text-right font-semibold text-red-600">-{formatPEN(cn.amount)}</td>
                    <td className="px-4 py-3">
                      <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${STATUS_BADGE[cn.status] ?? 'bg-gray-100 text-gray-700'}`}>
                        {STATUS_LABEL[cn.status] ?? cn.status}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-xs text-gray-500">
                      {relativeTime(toDate(cn.issuedAt))}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {modalOpen && (
        <NewCreditNoteModal
          onClose={() => setModalOpen(false)}
          onCreated={(cn) => {
            setModalOpen(false)
            setFlash({ kind: 'ok', msg: `Nota ${cn.number} emitida correctamente` })
            void load()
          }}
          onError={(msg) => setFlash({ kind: 'err', msg })}
        />
      )}
    </div>
  )
}

function NewCreditNoteModal({ onClose, onCreated, onError }: {
  onClose: () => void
  onCreated: (cn: AdminCreditNote) => void
  onError: (msg: string) => void
}) {
  const [q, setQ] = useState('')
  const [invoices, setInvoices] = useState<AdminInvoice[]>([])
  const [selectedInvoice, setSelectedInvoice] = useState<AdminInvoice | null>(null)
  const [loadingInvoices, setLoadingInvoices] = useState(false)
  const [invoicesError, setInvoicesError] = useState<string | null>(null)
  const [reason, setReason] = useState<'anulacion' | 'devolucion' | 'descuento_global' | 'descuento_item' | 'ajuste_precio' | 'otros'>('anulacion')
  const [reasonNotes, setReasonNotes] = useState('')
  const [amount, setAmount] = useState('')
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    if (q.trim().length < 2) { setInvoices([]); return }
    const t = setTimeout(async () => {
      setLoadingInvoices(true)
      setInvoicesError(null)
      try {
        const resp = await adminApi.listInvoices({ search: q.trim(), pageSize: 20 })
        setInvoices(resp.invoices.filter((i) => i.documentType !== 'receipt' && i.status !== 'voided'))
      } catch (e) {
        setInvoices([])
        setInvoicesError(
          e instanceof AdminApiError
            ? `Error al buscar facturas: ${e.message || e.code}`
            : 'Error al buscar facturas (revisa conexión).',
        )
      } finally { setLoadingInvoices(false) }
    }, 300)
    return () => clearTimeout(t)
  }, [q])

  useEffect(() => {
    if (selectedInvoice && reason === 'anulacion' && !amount) {
      setAmount(String(selectedInvoice.total))
    }
  }, [selectedInvoice, reason, amount])

  const submit = async (e: { preventDefault: () => void }) => {
    e.preventDefault()
    if (!selectedInvoice) { onError('Selecciona el documento asociado'); return }
    const amt = amount ? Number(amount) : selectedInvoice.total
    if (!isFinite(amt) || amt <= 0 || amt > selectedInvoice.total) {
      onError(`Monto inválido (entre 0 y ${selectedInvoice.total})`); return
    }
    setSaving(true)
    try {
      const resp = await adminApi.createCreditNote({
        invoiceId: selectedInvoice.id,
        reason,
        reasonNotes: reasonNotes.trim() || undefined,
        amount: amt,
      })
      onCreated(resp.creditNote)
    } catch (err) {
      onError(err instanceof AdminApiError ? err.message : 'Error emitiendo nota')
    } finally { setSaving(false) }
  }

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-2xl w-full max-w-lg max-h-[90vh] overflow-y-auto">
        <form onSubmit={submit} className="p-6 space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-lg font-bold text-gray-900 flex items-center gap-2">
              <FileMinus className="w-5 h-5" /> Emitir nota de crédito
            </h2>
            <button type="button" onClick={onClose} className="p-1 hover:bg-gray-100 rounded">
              <X className="w-5 h-5 text-gray-500" />
            </button>
          </div>

          <div>
            <label className="block text-xs font-medium text-gray-700 mb-1">Documento asociado *</label>
            {selectedInvoice ? (
              <div className="p-3 bg-blue-50 border border-blue-200 rounded-lg flex items-center justify-between gap-2">
                <div className="text-sm min-w-0">
                  <div className="font-mono font-medium text-blue-900">{selectedInvoice.number}</div>
                  <div className="text-gray-700 truncate">{selectedInvoice.customerName}</div>
                  <div className="text-gray-500 text-xs">Total: {formatPEN(selectedInvoice.total)}</div>
                </div>
                <button
                  type="button"
                  onClick={() => { setSelectedInvoice(null); setQ('') }}
                  className="text-xs text-blue-700 hover:underline"
                >
                  Cambiar
                </button>
              </div>
            ) : (
              <>
                <input value={q} onChange={(e) => setQ(e.target.value)}
                  placeholder="Busca por número o cliente..."
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm" />
                {loadingInvoices && (
                  <div className="text-center py-3"><Loader2 className="w-4 h-4 animate-spin mx-auto text-gray-400" /></div>
                )}
                {!loadingInvoices && invoices.length > 0 && (
                  <div className="mt-2 border border-gray-200 rounded-lg divide-y divide-gray-100 max-h-[220px] overflow-y-auto">
                    {invoices.map((i) => (
                      <button
                        key={i.id}
                        type="button"
                        onClick={() => setSelectedInvoice(i)}
                        className="w-full p-2 flex items-center justify-between gap-2 text-left hover:bg-gray-50 text-sm"
                      >
                        <div className="min-w-0">
                          <div className="font-mono text-xs text-gray-500">{i.number}</div>
                          <div className="text-gray-900 truncate">{i.customerName}</div>
                        </div>
                        <div className="text-right flex-shrink-0">
                          <div className="font-semibold">{formatPEN(i.total)}</div>
                        </div>
                      </button>
                    ))}
                  </div>
                )}
                {!loadingInvoices && invoicesError && (
                  <div className="text-xs text-red-600 bg-red-50 border border-red-200 rounded-lg p-2">
                    {invoicesError}
                  </div>
                )}
                {!loadingInvoices && !invoicesError && q.trim().length >= 2 && invoices.length === 0 && (
                  <div className="text-center py-3 text-sm text-gray-500">Sin resultados</div>
                )}
              </>
            )}
          </div>

          {selectedInvoice && (
            <>
              <div>
                <label className="block text-xs font-medium text-gray-700 mb-1">Motivo *</label>
                <select value={reason} onChange={(e) => setReason(e.target.value as typeof reason)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm">
                  {Object.entries(REASON_LABEL).map(([k, v]) => (
                    <option key={k} value={k}>{v}</option>
                  ))}
                </select>
              </div>
              <div>
                <label className="block text-xs font-medium text-gray-700 mb-1">Descripción del motivo</label>
                <textarea value={reasonNotes} onChange={(e) => setReasonNotes(e.target.value)} rows={2}
                  placeholder="Detalle del motivo..."
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm" />
              </div>
              <div>
                <label className="block text-xs font-medium text-gray-700 mb-1">Monto (S/) *</label>
                <input type="number" value={amount} onChange={(e) => setAmount(e.target.value)}
                  min="0" step="0.01" max={selectedInvoice.total}
                  placeholder={String(selectedInvoice.total)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm" />
                <p className="text-xs text-gray-500 mt-1">Máximo: {formatPEN(selectedInvoice.total)}</p>
              </div>
            </>
          )}

          <div className="flex items-center gap-3 pt-4 border-t border-gray-100">
            <button type="button" onClick={onClose}
              className="flex-1 px-4 py-2 border border-gray-300 rounded-lg text-sm font-medium text-gray-700 hover:bg-gray-50">
              Cancelar
            </button>
            <button type="submit" disabled={saving || !selectedInvoice}
              className="flex-1 inline-flex items-center justify-center gap-2 px-4 py-2 bg-[#E31E24] hover:bg-[#B5181D] text-white text-sm font-semibold rounded-lg disabled:opacity-50">
              {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Plus className="w-4 h-4" />}
              Emitir nota
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
