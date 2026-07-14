import { useEffect, useState } from 'react'
import {
  Receipt, Loader2, AlertCircle, Search, Plus, X, CheckCircle2, Ban, FileText,
} from 'lucide-react'
import { adminApi, AdminApiError, type AdminInvoice } from '../../lib/adminApi'
import { formatPEN } from '../../utils/currency'
import { relativeTime, toDate } from '../../utils/timeFormat'

const TYPE_LABEL: Record<string, string> = {
  receipt: 'Recibo interno', invoice: 'Factura', boleta: 'Boleta',
}
const TYPE_BADGE: Record<string, string> = {
  receipt: 'bg-gray-100 text-gray-700',
  invoice: 'bg-blue-100 text-blue-700',
  boleta: 'bg-purple-100 text-purple-700',
}
const STATUS_LABEL: Record<string, string> = {
  issued: 'Emitido', sent: 'Enviado', paid: 'Pagado', voided: 'Anulado',
  sunat_pending: 'Pendiente SUNAT', sunat_sent: 'Aceptado SUNAT', sunat_error: 'Error SUNAT',
}
const STATUS_BADGE: Record<string, string> = {
  issued: 'bg-yellow-100 text-yellow-700',
  sent: 'bg-blue-100 text-blue-700',
  paid: 'bg-green-100 text-green-700',
  voided: 'bg-red-100 text-red-700',
  sunat_pending: 'bg-yellow-100 text-yellow-700',
  sunat_sent: 'bg-green-100 text-green-700',
  sunat_error: 'bg-red-100 text-red-700',
}

export function InvoicesPage() {
  const [items, setItems] = useState<AdminInvoice[]>([])
  const [total, setTotal] = useState(0)
  const [loading, setLoading] = useState(true)
  const [status, setStatus] = useState<string>('all')
  const [type, setType] = useState<string>('all')
  const [search, setSearch] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [modalOpen, setModalOpen] = useState(false)
  const [flash, setFlash] = useState<{ kind: 'ok' | 'err'; msg: string } | null>(null)

  const load = async () => {
    setLoading(true); setError(null)
    try {
      const resp = await adminApi.listInvoices({
        status: status !== 'all' ? status : undefined,
        type: type !== 'all' ? type : undefined,
        search: search || undefined,
        pageSize: 100,
      })
      setItems(resp.invoices); setTotal(resp.total)
    } catch (err) {
      setError(err instanceof AdminApiError ? err.message : 'Error cargando facturas')
    } finally { setLoading(false) }
  }

  useEffect(() => { void load() }, [status, type])
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

  const [voidingId, setVoidingId] = useState<string | null>(null)
  const voidInvoice = async (inv: AdminInvoice) => {
    if (voidingId) return // ya hay un void en curso — evita doble-click
    if (!window.confirm(`¿Anular ${inv.number}? Esta acción no se puede deshacer.`)) return
    setVoidingId(inv.id)
    try {
      await adminApi.voidInvoice(inv.id)
      setFlash({ kind: 'ok', msg: 'Comprobante anulado' })
      void load()
    } catch (err) {
      setFlash({ kind: 'err', msg: err instanceof AdminApiError ? err.message : 'Error anulando' })
    } finally {
      setVoidingId(null)
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Facturación</h1>
          <p className="text-sm text-gray-500 mt-1">Total: <strong>{total}</strong> comprobante(s)</p>
        </div>
        <button
          onClick={() => setModalOpen(true)}
          className="inline-flex items-center gap-2 px-4 py-2 bg-[#E31E24] hover:bg-[#B5181D] text-white text-sm font-semibold rounded-lg"
        >
          <Plus className="w-4 h-4" /> Emitir comprobante
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

      <div className="bg-white rounded-xl border border-gray-200 p-4 flex flex-col md:flex-row gap-3">
        <div className="flex-1 relative">
          <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input value={search} onChange={(e) => setSearch(e.target.value)}
            placeholder="Buscar por número, cliente, RUC..." type="text"
            className="w-full pl-10 pr-3 py-2 border border-gray-200 rounded-lg text-sm" />
        </div>
        <select value={type} onChange={(e) => setType(e.target.value)}
          className="border border-gray-200 rounded-lg px-3 py-2 text-sm">
          <option value="all">Todos los tipos</option>
          <option value="invoice">Factura</option>
          <option value="boleta">Boleta</option>
          <option value="receipt">Recibo interno</option>
        </select>
        <select value={status} onChange={(e) => setStatus(e.target.value)}
          className="border border-gray-200 rounded-lg px-3 py-2 text-sm">
          <option value="all">Todos los estados</option>
          <option value="issued">Emitidos</option>
          <option value="paid">Pagados</option>
          <option value="voided">Anulados</option>
        </select>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        {loading ? (
          <div className="p-12 text-center text-gray-500 flex items-center justify-center gap-2">
            <Loader2 className="w-4 h-4 animate-spin" /> Cargando comprobantes...
          </div>
        ) : items.length === 0 ? (
          <div className="p-12 text-center text-gray-500">
            <Receipt className="w-10 h-10 mx-auto mb-3 text-gray-300" />
            No hay comprobantes emitidos con estos filtros.
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-gray-50 text-gray-500 text-xs uppercase">
                <tr>
                  <th className="text-left px-4 py-3">Número</th>
                  <th className="text-left px-4 py-3">Tipo</th>
                  <th className="text-left px-4 py-3">Cliente</th>
                  <th className="text-right px-4 py-3">Total</th>
                  <th className="text-left px-4 py-3">Estado</th>
                  <th className="text-left px-4 py-3">Emitido</th>
                  <th className="text-right px-4 py-3">Acciones</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {items.map((inv) => (
                  <tr key={inv.id} className="hover:bg-gray-50">
                    <td className="px-4 py-3">
                      <span className="font-mono font-medium text-gray-900">{inv.number}</span>
                    </td>
                    <td className="px-4 py-3">
                      <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${TYPE_BADGE[inv.documentType]}`}>
                        {TYPE_LABEL[inv.documentType]}
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      <div className="text-gray-900 truncate max-w-[240px]">{inv.customerName}</div>
                      {inv.customerDoc && (
                        <div className="text-xs text-gray-400">
                          {inv.customerDocType}: {inv.customerDoc}
                        </div>
                      )}
                    </td>
                    <td className="px-4 py-3 text-right font-semibold text-gray-900">{formatPEN(inv.total)}</td>
                    <td className="px-4 py-3">
                      <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${STATUS_BADGE[inv.status] ?? 'bg-gray-100 text-gray-700'}`}>
                        {STATUS_LABEL[inv.status] ?? inv.status}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-xs text-gray-500">
                      {relativeTime(toDate(inv.issuedAt))}
                    </td>
                    <td className="px-4 py-3 text-right">
                      {inv.status !== 'voided' && (
                        <button
                          onClick={() => void voidInvoice(inv)}
                          disabled={voidingId === inv.id}
                          className="inline-flex items-center gap-1 px-2 py-1 rounded bg-red-50 text-red-700 text-xs font-medium hover:bg-red-100 disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                          {voidingId === inv.id ? (
                            <><Loader2 className="w-3 h-3 animate-spin" /> Anulando…</>
                          ) : (
                            <><Ban className="w-3 h-3" /> Anular</>
                          )}
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {modalOpen && (
        <NewInvoiceModal
          onClose={() => setModalOpen(false)}
          onCreated={(inv) => {
            setModalOpen(false)
            setFlash({ kind: 'ok', msg: `Comprobante ${inv.number} emitido correctamente` })
            void load()
          }}
          onError={(msg) => setFlash({ kind: 'err', msg })}
        />
      )}
    </div>
  )
}

function NewInvoiceModal({ onClose, onCreated, onError }: {
  onClose: () => void
  onCreated: (inv: AdminInvoice) => void
  onError: (msg: string) => void
}) {
  const [docType, setDocType] = useState<'receipt' | 'invoice' | 'boleta'>('boleta')
  const [customerName, setCustomerName] = useState('')
  const [customerEmail, setCustomerEmail] = useState('')
  const [customerDocType, setCustomerDocType] = useState<'DNI' | 'RUC' | 'CE' | 'PASSPORT'>('DNI')
  const [customerDoc, setCustomerDoc] = useState('')
  const [description, setDescription] = useState('Servicio de transporte')
  const [quantity, setQuantity] = useState('1')
  const [unitPrice, setUnitPrice] = useState('')
  const [saving, setSaving] = useState(false)

  // Cambiar tipo doc según tipo de comprobante
  useEffect(() => {
    if (docType === 'invoice') setCustomerDocType('RUC')
    else if (docType === 'boleta' && customerDocType === 'RUC') setCustomerDocType('DNI')
  }, [docType])  // eslint-disable-line react-hooks/exhaustive-deps

  const submit = async (e: { preventDefault: () => void }) => {
    e.preventDefault()
    if (!customerName.trim()) { onError('Ingresa el nombre del cliente'); return }
    const qty = Number(quantity), price = Number(unitPrice)
    if (!isFinite(qty) || qty <= 0) { onError('Cantidad inválida'); return }
    if (!isFinite(price) || price <= 0) { onError('Precio unitario inválido'); return }
    if (docType === 'invoice' && (!customerDoc || customerDocType !== 'RUC')) {
      onError('La factura requiere RUC del cliente')
      return
    }

    setSaving(true)
    try {
      const resp = await adminApi.createInvoice({
        documentType: docType,
        customerName: customerName.trim(),
        customerEmail: customerEmail.trim() || undefined,
        customerDocType: customerDoc.trim() ? customerDocType : undefined,
        customerDoc: customerDoc.trim() || undefined,
        items: [{ description: description.trim() || 'Servicio', quantity: qty, unitPrice: price }],
        includeIgv: docType !== 'receipt',
      })
      onCreated(resp.invoice)
    } catch (err) {
      onError(err instanceof AdminApiError ? err.message : 'Error emitiendo comprobante')
    } finally { setSaving(false) }
  }

  const total = Number(quantity) * Number(unitPrice) || 0

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-2xl w-full max-w-lg max-h-[90vh] overflow-y-auto">
        <form onSubmit={submit} className="p-6 space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-lg font-bold text-gray-900 flex items-center gap-2">
              <FileText className="w-5 h-5" /> Emitir comprobante
            </h2>
            <button type="button" onClick={onClose} className="p-1 hover:bg-gray-100 rounded">
              <X className="w-5 h-5 text-gray-500" />
            </button>
          </div>

          <div>
            <label className="block text-xs font-medium text-gray-700 mb-1">Tipo de comprobante *</label>
            <div className="grid grid-cols-3 gap-2">
              {(['receipt', 'boleta', 'invoice'] as const).map((t) => (
                <button
                  key={t}
                  type="button"
                  onClick={() => setDocType(t)}
                  className={`px-3 py-2 border rounded-lg text-sm font-medium transition-colors ${
                    docType === t ? 'border-red-500 bg-red-50 text-red-700' : 'border-gray-300 text-gray-700 hover:bg-gray-50'
                  }`}
                >
                  {TYPE_LABEL[t]}
                </button>
              ))}
            </div>
          </div>

          <div className="pt-2 border-t border-gray-100 space-y-3">
            <p className="text-xs font-semibold text-gray-500 uppercase">Cliente</p>
            <div>
              <label className="block text-xs font-medium text-gray-700 mb-1">Nombre / Razón social *</label>
              <input value={customerName} onChange={(e) => setCustomerName(e.target.value)}
                placeholder="Juan Pérez / EMPRESA SAC"
                className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm" />
            </div>
            <div className="grid grid-cols-3 gap-2">
              <div className="col-span-1">
                <label className="block text-xs font-medium text-gray-700 mb-1">Tipo doc</label>
                <select value={customerDocType} onChange={(e) => setCustomerDocType(e.target.value as typeof customerDocType)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm">
                  <option value="DNI">DNI</option>
                  <option value="RUC">RUC</option>
                  <option value="CE">CE</option>
                  <option value="PASSPORT">Pasaporte</option>
                </select>
              </div>
              <div className="col-span-2">
                <label className="block text-xs font-medium text-gray-700 mb-1">Número doc {docType === 'invoice' && '*'}</label>
                <input value={customerDoc} onChange={(e) => setCustomerDoc(e.target.value)}
                  placeholder={customerDocType === 'RUC' ? '20612945790' : '12345678'}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm" />
              </div>
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-700 mb-1">Email (opcional)</label>
              <input type="email" value={customerEmail} onChange={(e) => setCustomerEmail(e.target.value)}
                placeholder="cliente@ejemplo.com"
                className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm" />
            </div>
          </div>

          <div className="pt-2 border-t border-gray-100 space-y-3">
            <p className="text-xs font-semibold text-gray-500 uppercase">Concepto</p>
            <div>
              <label className="block text-xs font-medium text-gray-700 mb-1">Descripción</label>
              <input value={description} onChange={(e) => setDescription(e.target.value)}
                placeholder="Servicio de transporte..."
                className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm" />
            </div>
            <div className="grid grid-cols-3 gap-3">
              <div>
                <label className="block text-xs font-medium text-gray-700 mb-1">Cantidad</label>
                <input type="number" value={quantity} onChange={(e) => setQuantity(e.target.value)} min="1" step="1"
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm" />
              </div>
              <div className="col-span-2">
                <label className="block text-xs font-medium text-gray-700 mb-1">Precio unitario (S/)</label>
                <input type="number" value={unitPrice} onChange={(e) => setUnitPrice(e.target.value)} min="0" step="0.01"
                  placeholder="15.00"
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm" />
              </div>
            </div>
            <div className="p-3 bg-gray-50 rounded-lg text-sm">
              <div className="flex items-center justify-between">
                <span className="text-gray-600">Total {docType !== 'receipt' && '(incluye IGV)'}:</span>
                <span className="font-bold text-lg">{formatPEN(total)}</span>
              </div>
              {docType !== 'receipt' && total > 0 && (
                <div className="text-xs text-gray-500 mt-1">
                  Subtotal: {formatPEN(total / 1.18)} + IGV 18%: {formatPEN(total - total / 1.18)}
                </div>
              )}
            </div>
          </div>

          <div className="flex items-center gap-3 pt-4 border-t border-gray-100">
            <button type="button" onClick={onClose}
              className="flex-1 px-4 py-2 border border-gray-300 rounded-lg text-sm font-medium text-gray-700 hover:bg-gray-50">
              Cancelar
            </button>
            <button type="submit" disabled={saving}
              className="flex-1 inline-flex items-center justify-center gap-2 px-4 py-2 bg-[#E31E24] hover:bg-[#B5181D] text-white text-sm font-semibold rounded-lg disabled:opacity-50">
              {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Plus className="w-4 h-4" />}
              Emitir
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
