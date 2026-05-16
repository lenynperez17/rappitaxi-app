import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { collection, query, orderBy, limit as fbLimit, getDocs, where, Timestamp } from 'firebase/firestore'
import { httpsCallable } from 'firebase/functions'
import { db, functions } from '../../config/firebase'
import { formatPEN } from '../../utils/currency'
import { calculateRechargeBreakdown } from '../../utils/mercadopagoFees'
import { CreditCard, TrendingDown, TrendingUp, Search, Calendar, Download, Plus, X, Loader2, CheckCircle2, AlertCircle } from 'lucide-react'
import type { DriverRecharge, RechargeStatus } from '../../types/recharge'

interface DriverOption {
  id: string
  name: string
  email?: string
  phone?: string
}

export function RechargesPage() {
  const [recharges, setRecharges] = useState<DriverRecharge[]>([])
  const [loading, setLoading] = useState(true)
  const [filterStatus, setFilterStatus] = useState<RechargeStatus | 'all'>('all')
  const [searchQuery, setSearchQuery] = useState('')
  const [dateRange, setDateRange] = useState<'today' | '7d' | '30d' | 'all'>('30d')
  const [showModal, setShowModal] = useState(false)

  useEffect(() => {
    loadRecharges()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [dateRange])

  const loadRecharges = async () => {
    setLoading(true)
    try {
      const constraints: any[] = [orderBy('createdAt', 'desc'), fbLimit(500)]

      if (dateRange !== 'all') {
        const now = new Date()
        const start = new Date()
        if (dateRange === 'today') start.setHours(0, 0, 0, 0)
        else if (dateRange === '7d') start.setDate(now.getDate() - 7)
        else if (dateRange === '30d') start.setDate(now.getDate() - 30)
        constraints.unshift(where('createdAt', '>=', Timestamp.fromDate(start)))
      }

      const q = query(collection(db, 'driverRecharges'), ...constraints)
      const snap = await getDocs(q)
      const data = snap.docs.map((d) => ({ id: d.id, ...d.data() } as DriverRecharge))
      setRecharges(data)
    } catch (err) {
      console.error('Error loading recharges:', err)
    } finally {
      setLoading(false)
    }
  }

  const filtered = useMemo(() => {
    return recharges.filter((r) => {
      if (filterStatus !== 'all' && r.status !== filterStatus) return false
      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase()
        return (
          r.driverName?.toLowerCase().includes(q) ||
          r.driverEmail?.toLowerCase().includes(q) ||
          r.mpPaymentId?.toLowerCase().includes(q)
        )
      }
      return true
    })
  }, [recharges, filterStatus, searchQuery])

  const totals = useMemo(() => {
    const approved = filtered.filter((r) => r.status === 'approved')
    return approved.reduce(
      (acc, r) => ({
        gross: acc.gross + (r.grossAmount ?? 0),
        net: acc.net + (r.netAmount ?? 0),
        fees: acc.fees + (r.totalMpFee ?? 0),
        count: acc.count + 1,
      }),
      { gross: 0, net: 0, fees: 0, count: 0 },
    )
  }, [filtered])

  const exportCsv = () => {
    const headers = [
      'Fecha', 'ID', 'Conductor', 'Email', 'Monto Bruto',
      'Comision MP (4.49%)', 'IGV MP (S/0.55)', 'Total Fee MP', 'Neto Acreditado',
      'Metodo', 'Estado MP', 'ID Pago MP', 'Estado', 'Factura',
    ]
    const rows = filtered.map((r) => {
      const date = r.createdAt?.toDate?.() ?? new Date()
      return [
        date.toLocaleString('es-PE'),
        r.id,
        r.driverName ?? '',
        r.driverEmail ?? '',
        r.grossAmount.toFixed(2),
        r.mpCommission.toFixed(2),
        r.mpIgv.toFixed(2),
        r.totalMpFee.toFixed(2),
        r.netAmount.toFixed(2),
        r.paymentMethod,
        r.mpPaymentStatus ?? '',
        r.mpPaymentId ?? '',
        r.status,
        r.invoiceNumber ?? '',
      ].map((v) => `"${String(v).replace(/"/g, '""')}"`).join(',')
    })
    const csv = [headers.join(','), ...rows].join('\n')
    const blob = new Blob(['﻿' + csv], { type: 'text/csv;charset=utf-8' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `recargas_${new Date().toISOString().slice(0, 10)}.csv`
    a.click()
    URL.revokeObjectURL(url)
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Recargas</h1>
          <p className="text-sm text-gray-500 mt-1">Recargas de conductores con desglose de comisiones MercadoPago</p>
        </div>
        <div className="flex gap-2">
          <button
            onClick={() => setShowModal(true)}
            className="flex items-center gap-2 px-4 py-2 bg-[#E31E24] hover:bg-[#B5181D] text-white rounded-lg text-sm font-medium"
          >
            <Plus className="w-4 h-4" />
            Nueva recarga manual
          </button>
          <button
            onClick={exportCsv}
            className="flex items-center gap-2 px-4 py-2 bg-white border border-gray-300 rounded-lg text-sm font-medium text-gray-700 hover:bg-gray-50"
          >
            <Download className="w-4 h-4" />
            Exportar CSV
          </button>
        </div>
      </div>

      {showModal && (
        <NewRechargeModal
          onClose={() => setShowModal(false)}
          onSuccess={() => {
            setShowModal(false)
            void loadRecharges()
          }}
        />
      )}

      {/* KPIs */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <KpiCard label="Recargas (count)" value={totals.count.toString()} icon={CreditCard} color="indigo" />
        <KpiCard label="Total bruto" value={formatPEN(totals.gross)} icon={TrendingUp} color="blue" />
        <KpiCard label="Comision MP retenida" value={formatPEN(totals.fees)} icon={TrendingDown} color="orange" />
        <KpiCard label="Neto acreditado" value={formatPEN(totals.net)} icon={TrendingUp} color="green" />
      </div>

      {/* Filters */}
      <div className="bg-white rounded-xl border border-gray-200 p-4 flex flex-col sm:flex-row gap-3">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <input
            type="text"
            placeholder="Buscar por conductor, email, ID pago..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-9 pr-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#E31E24]"
          />
        </div>

        <select
          value={dateRange}
          onChange={(e) => setDateRange(e.target.value as typeof dateRange)}
          className="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#E31E24]"
        >
          <option value="today">Hoy</option>
          <option value="7d">Ultimos 7 dias</option>
          <option value="30d">Ultimos 30 dias</option>
          <option value="all">Todo</option>
        </select>

        <select
          value={filterStatus}
          onChange={(e) => setFilterStatus(e.target.value as RechargeStatus | 'all')}
          className="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#E31E24]"
        >
          <option value="all">Todos los estados</option>
          <option value="approved">Aprobado</option>
          <option value="pending">Pendiente</option>
          <option value="rejected">Rechazado</option>
          <option value="refunded">Reembolsado</option>
        </select>
      </div>

      {/* Tabla */}
      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Fecha</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Conductor</th>
                <th className="text-right px-4 py-3 font-medium text-gray-600">Bruto</th>
                <th className="text-right px-4 py-3 font-medium text-gray-600">Comision MP</th>
                <th className="text-right px-4 py-3 font-medium text-gray-600">Neto</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Metodo</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Estado</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Factura</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {loading ? (
                <tr><td colSpan={8} className="text-center py-12 text-gray-400">Cargando...</td></tr>
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={8} className="text-center py-12 text-gray-400">
                    <Calendar className="w-8 h-8 mx-auto mb-2 text-gray-300" />
                    No hay recargas en el rango seleccionado.
                  </td>
                </tr>
              ) : (
                filtered.map((r) => <RechargeRow key={r.id} recharge={r} />)
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}

function RechargeRow({ recharge }: { recharge: DriverRecharge }) {
  const date = recharge.createdAt?.toDate?.() ?? new Date()
  // Recompute breakdown on the fly to validate stored values
  const breakdown = calculateRechargeBreakdown(recharge.grossAmount)
  const matchesExpected =
    Math.abs(breakdown.netAmount - recharge.netAmount) < 0.01

  return (
    <tr className="hover:bg-gray-50">
      <td className="px-4 py-3 text-gray-700">
        {date.toLocaleDateString('es-PE', { day: '2-digit', month: 'short', year: '2-digit' })}
        <span className="block text-xs text-gray-400">
          {date.toLocaleTimeString('es-PE', { hour: '2-digit', minute: '2-digit' })}
        </span>
      </td>
      <td className="px-4 py-3">
        <p className="font-medium text-gray-900 truncate max-w-[180px]">{recharge.driverName || '—'}</p>
        <p className="text-xs text-gray-500 truncate max-w-[180px]">{recharge.driverEmail}</p>
      </td>
      <td className="px-4 py-3 text-right font-medium text-gray-900">{formatPEN(recharge.grossAmount)}</td>
      <td className="px-4 py-3 text-right text-orange-600">
        -{formatPEN(recharge.totalMpFee)}
        {!matchesExpected && (
          <span className="block text-[10px] text-red-500">⚠ valor stored</span>
        )}
      </td>
      <td className="px-4 py-3 text-right font-bold text-green-600">{formatPEN(recharge.netAmount)}</td>
      <td className="px-4 py-3">
        <PaymentMethodBadge method={recharge.paymentMethod} />
      </td>
      <td className="px-4 py-3">
        <StatusBadge status={recharge.status} />
      </td>
      <td className="px-4 py-3">
        {recharge.invoiceNumber ? (
          <Link
            to={`/invoices/${recharge.invoiceId}`}
            className="text-[#E31E24] hover:underline text-xs font-medium"
          >
            {recharge.invoiceNumber}
          </Link>
        ) : (
          <Link
            to={`/recharges/${recharge.id}`}
            className="text-gray-500 hover:text-[#E31E24] text-xs"
          >
            Generar
          </Link>
        )}
      </td>
    </tr>
  )
}

function StatusBadge({ status }: { status: RechargeStatus | string }) {
  const map: Record<string, { bg: string; label: string }> = {
    approved: { bg: 'bg-green-100 text-green-700', label: 'Aprobado' },
    pending: { bg: 'bg-yellow-100 text-yellow-700', label: 'Pendiente' },
    rejected: { bg: 'bg-red-100 text-red-700', label: 'Rechazado' },
    refunded: { bg: 'bg-gray-100 text-gray-700', label: 'Reembolsado' },
    completed: { bg: 'bg-green-100 text-green-700', label: 'Completado' },
    cancelled: { bg: 'bg-gray-100 text-gray-700', label: 'Cancelado' },
  }
  const cfg = map[status] ?? { bg: 'bg-gray-100 text-gray-700', label: status || '—' }
  return <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${cfg.bg}`}>{cfg.label}</span>
}

function PaymentMethodBadge({ method }: { method: string }) {
  const map: Record<string, string> = {
    mercadopago: 'bg-blue-100 text-blue-700',
    cash: 'bg-emerald-100 text-emerald-700',
    admin_manual: 'bg-purple-100 text-purple-700',
    transfer: 'bg-indigo-100 text-indigo-700',
  }
  return (
    <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs ${map[method] ?? 'bg-gray-100 text-gray-700'}`}>
      {method === 'mercadopago' ? 'MercadoPago' : method === 'admin_manual' ? 'Manual' : method}
    </span>
  )
}

interface KpiCardProps {
  label: string
  value: string
  icon: React.ComponentType<{ className?: string }>
  color: 'blue' | 'green' | 'orange' | 'indigo'
}

function KpiCard({ label, value, icon: Icon, color }: KpiCardProps) {
  const colorMap = {
    blue: 'bg-blue-50 text-blue-600',
    green: 'bg-green-50 text-green-600',
    orange: 'bg-orange-50 text-orange-600',
    indigo: 'bg-indigo-50 text-indigo-600',
  }
  return (
    <div className="bg-white rounded-xl border border-gray-200 p-4 flex items-center gap-3">
      <div className={`w-10 h-10 rounded-lg flex items-center justify-center ${colorMap[color]}`}>
        <Icon className="w-5 h-5" />
      </div>
      <div className="min-w-0 flex-1">
        <p className="text-xs text-gray-500 uppercase">{label}</p>
        <p className="text-lg font-bold text-gray-900 truncate">{value}</p>
      </div>
    </div>
  )
}

// ===========================================================
// NewRechargeModal — Crear recarga manual desde el panel
// ===========================================================

function NewRechargeModal({
  onClose,
  onSuccess,
}: {
  onClose: () => void
  onSuccess: () => void
}) {
  const [drivers, setDrivers] = useState<DriverOption[]>([])
  const [loadingDrivers, setLoadingDrivers] = useState(true)
  const [driverSearch, setDriverSearch] = useState('')
  const [selectedDriver, setSelectedDriver] = useState<DriverOption | null>(null)
  const [amount, setAmount] = useState<string>('')
  const [paymentMethod, setPaymentMethod] = useState<'admin_manual' | 'cash' | 'transfer'>('admin_manual')
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [success, setSuccess] = useState<string | null>(null)

  useEffect(() => {
    void loadDrivers()
  }, [])

  const loadDrivers = async () => {
    setLoadingDrivers(true)
    try {
      const snap = await getDocs(query(
        collection(db, 'users'),
        where('userType', 'in', ['driver', 'dual']),
        fbLimit(500),
      ))
      const list: DriverOption[] = snap.docs.map((d) => {
        const data = d.data() as any
        return {
          id: d.id,
          name: data.fullName ?? data.name ?? '(sin nombre)',
          email: data.email,
          phone: data.phone ?? data.phoneNumber,
        }
      })
      list.sort((a, b) => a.name.localeCompare(b.name))
      setDrivers(list)
    } catch (err) {
      console.error('Load drivers error:', err)
    } finally {
      setLoadingDrivers(false)
    }
  }

  const filteredDrivers = useMemo(() => {
    const q = driverSearch.trim().toLowerCase()
    if (!q) return drivers.slice(0, 20)
    return drivers
      .filter(
        (d) =>
          d.name.toLowerCase().includes(q) ||
          d.email?.toLowerCase().includes(q) ||
          d.phone?.includes(q),
      )
      .slice(0, 20)
  }, [drivers, driverSearch])

  const grossNumber = parseFloat(amount) || 0
  const breakdown = grossNumber > 0 ? calculateRechargeBreakdown(grossNumber) : null

  const handleSubmit = async () => {
    setError(null)
    setSuccess(null)
    if (!selectedDriver) {
      setError('Selecciona un conductor')
      return
    }
    if (grossNumber <= 0) {
      setError('Ingresa un monto válido mayor a 0')
      return
    }
    setSubmitting(true)
    try {
      const fn = httpsCallable<
        { driverId: string; grossAmount: number; paymentMethod: string },
        { ok: boolean; rechargeId: string; breakdown: any }
      >(functions, 'createManualRecharge')
      const res = await fn({
        driverId: selectedDriver.id,
        grossAmount: grossNumber,
        paymentMethod,
      })
      setSuccess(
        `Recarga creada exitosamente. Acreditado S/ ${res.data.breakdown.netAmount.toFixed(2)} al conductor.`,
      )
      setTimeout(() => onSuccess(), 1500)
    } catch (err: any) {
      console.error(err)
      setError(err?.message || 'Error al crear recarga')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-xl shadow-2xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
        <div className="sticky top-0 bg-white border-b border-gray-200 px-6 py-4 flex items-center justify-between">
          <h2 className="text-lg font-semibold text-gray-900">Nueva recarga manual</h2>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-700">
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="p-6 space-y-4">
          {/* Conductor */}
          <div>
            <label className="block text-xs font-medium text-gray-700 mb-1">Conductor</label>
            {selectedDriver ? (
              <div className="flex items-center justify-between p-3 bg-blue-50 border border-blue-200 rounded-lg">
                <div>
                  <p className="font-medium text-gray-900">{selectedDriver.name}</p>
                  <p className="text-xs text-gray-600">
                    {selectedDriver.email} · {selectedDriver.phone}
                  </p>
                </div>
                <button
                  onClick={() => setSelectedDriver(null)}
                  className="text-blue-600 hover:text-blue-800 text-sm font-medium"
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
                    value={driverSearch}
                    onChange={(e) => setDriverSearch(e.target.value)}
                    placeholder="Buscar por nombre, email o teléfono..."
                    className="w-full pl-9 pr-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#E31E24]"
                    autoFocus
                  />
                </div>
                {loadingDrivers ? (
                  <p className="text-xs text-gray-500 py-2">Cargando conductores...</p>
                ) : (
                  <div className="max-h-48 overflow-y-auto border border-gray-200 rounded-lg divide-y">
                    {filteredDrivers.length === 0 ? (
                      <p className="text-xs text-gray-400 p-4 text-center">Sin resultados</p>
                    ) : (
                      filteredDrivers.map((d) => (
                        <button
                          key={d.id}
                          onClick={() => setSelectedDriver(d)}
                          className="w-full px-3 py-2 text-left hover:bg-gray-50 flex justify-between"
                        >
                          <div>
                            <p className="font-medium text-gray-900 text-sm">{d.name}</p>
                            <p className="text-xs text-gray-500">
                              {d.email} · {d.phone}
                            </p>
                          </div>
                        </button>
                      ))
                    )}
                  </div>
                )}
              </div>
            )}
          </div>

          {/* Monto */}
          <div>
            <label className="block text-xs font-medium text-gray-700 mb-1">Monto bruto (S/)</label>
            <input
              type="number"
              step="0.01"
              min="1"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              placeholder="Ej: 100.00"
              className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#E31E24]"
            />
          </div>

          {/* Método */}
          <div>
            <label className="block text-xs font-medium text-gray-700 mb-1">Método de pago</label>
            <select
              value={paymentMethod}
              onChange={(e) => setPaymentMethod(e.target.value as any)}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#E31E24]"
            >
              <option value="admin_manual">Admin manual (sin comisión)</option>
              <option value="cash">Efectivo</option>
              <option value="transfer">Transferencia</option>
            </select>
          </div>

          {/* Breakdown en vivo */}
          {breakdown && (
            <div className="bg-gray-50 border border-gray-200 rounded-lg p-4 space-y-1">
              <p className="text-xs font-semibold text-gray-700 uppercase mb-2">Desglose</p>
              <div className="flex justify-between text-sm">
                <span className="text-gray-600">Bruto:</span>
                <span className="font-medium">S/ {breakdown.grossAmount.toFixed(2)}</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-gray-600">Comisión MercadoPago (4.49%):</span>
                <span className="text-orange-600">-S/ {breakdown.mpCommission.toFixed(2)}</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-gray-600">IGV MP (S/ 0.55 fijo):</span>
                <span className="text-orange-600">-S/ {breakdown.mpIgv.toFixed(2)}</span>
              </div>
              <div className="border-t border-gray-300 mt-2 pt-2 flex justify-between text-base font-bold">
                <span className="text-gray-900">Neto acreditado:</span>
                <span className="text-green-600">S/ {breakdown.netAmount.toFixed(2)}</span>
              </div>
            </div>
          )}

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
            disabled={submitting || !selectedDriver || grossNumber <= 0}
            className="px-5 py-2 bg-[#E31E24] hover:bg-[#B5181D] text-white rounded-lg text-sm font-medium disabled:opacity-50 flex items-center gap-2"
          >
            {submitting && <Loader2 className="w-4 h-4 animate-spin" />}
            Confirmar recarga
          </button>
        </div>
      </div>
    </div>
  )
}
