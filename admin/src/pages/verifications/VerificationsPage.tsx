import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { collection, query, where, orderBy, getDocs, limit } from 'firebase/firestore'
import { db } from '../../config/firebase'
import { ShieldCheck, Loader2, Search, Car, CheckCircle2, Clock, XCircle } from 'lucide-react'
import type { DriverForVerification, DriverApprovalStatus } from '../../types/driverDocument'

const STATUS_FILTERS: Array<{ value: 'pending_approval' | 'all' | DriverApprovalStatus; label: string }> = [
  { value: 'pending_approval', label: 'Pendientes' },
  { value: 'approved', label: 'Aprobados' },
  { value: 'rejected', label: 'Rechazados' },
  { value: 'all', label: 'Todos' },
]

export function VerificationsPage() {
  const [drivers, setDrivers] = useState<DriverForVerification[]>([])
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState<'pending_approval' | 'all' | DriverApprovalStatus>('pending_approval')
  const [search, setSearch] = useState('')

  useEffect(() => {
    void load()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filter])

  const load = async () => {
    setLoading(true)
    try {
      const constraints: any[] = [
        where('userType', 'in', ['driver', 'dual']),
        orderBy('createdAt', 'desc'),
        limit(200),
      ]
      if (filter !== 'all') {
        constraints.unshift(where('driverStatus', '==', filter))
      }
      const snap = await getDocs(query(collection(db, 'users'), ...constraints))
      setDrivers(snap.docs.map((d) => ({ id: d.id, ...(d.data() as Omit<DriverForVerification, 'id'>) })))
    } catch (err) {
      console.error('VerificationsPage load error:', err)
      // Fallback sin orderBy si falta el índice
      try {
        const fallback = await getDocs(query(
          collection(db, 'users'),
          where('userType', 'in', ['driver', 'dual']),
          limit(200),
        ))
        const all = fallback.docs.map((d) => ({ id: d.id, ...(d.data() as Omit<DriverForVerification, 'id'>) }))
        const filtered = filter === 'all' ? all : all.filter((d) => d.driverStatus === filter)
        setDrivers(filtered)
      } catch (e2) {
        console.error('Fallback failed:', e2)
        setDrivers([])
      }
    } finally {
      setLoading(false)
    }
  }

  const filtered = drivers.filter((d) => {
    if (!search.trim()) return true
    const q = search.toLowerCase()
    return (
      d.fullName?.toLowerCase().includes(q) ||
      d.name?.toLowerCase().includes(q) ||
      d.email?.toLowerCase().includes(q) ||
      d.phone?.includes(q) ||
      d.phoneNumber?.includes(q)
    )
  })

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
          <ShieldCheck className="w-7 h-7 text-[#E31E24]" /> Verificaciones de Conductores
        </h1>
        <p className="text-sm text-gray-500 mt-1">
          Revisa los documentos subidos por los conductores y aprueba sus cuentas para que puedan operar
        </p>
      </div>

      {/* Filtros */}
      <div className="bg-white rounded-xl border border-gray-200 p-4 flex flex-col sm:flex-row gap-3">
        <div className="flex flex-wrap gap-2">
          {STATUS_FILTERS.map((f) => (
            <button
              key={f.value}
              onClick={() => setFilter(f.value)}
              className={`px-3 py-1.5 rounded-lg text-sm font-medium transition-colors ${
                filter === f.value
                  ? 'bg-[#E31E24] text-white'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              }`}
            >
              {f.label}
            </button>
          ))}
        </div>
        <div className="relative flex-1">
          <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Buscar por nombre, email o teléfono..."
            className="w-full pl-10 pr-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#E31E24]"
          />
        </div>
        <span className="text-xs text-gray-500 self-center">{filtered.length} conductor{filtered.length !== 1 ? 'es' : ''}</span>
      </div>

      {/* Tabla */}
      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Conductor</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Contacto</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Vehículo</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Documento</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Estado</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Solicitado</th>
                <th className="text-right px-4 py-3 font-medium text-gray-600">Acción</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {loading ? (
                <tr>
                  <td colSpan={7} className="text-center py-12 text-gray-400">
                    <Loader2 className="w-6 h-6 animate-spin mx-auto" />
                  </td>
                </tr>
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={7} className="text-center py-12 text-gray-400">
                    <ShieldCheck className="w-8 h-8 mx-auto mb-2 text-gray-300" />
                    Sin conductores en este estado
                  </td>
                </tr>
              ) : (
                filtered.map((d) => <DriverRow key={d.id} driver={d} />)
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}

function DriverRow({ driver }: { driver: DriverForVerification }) {
  const date = driver.createdAt?.toDate?.() ?? new Date()
  const vehicle = driver.vehicleInfo
  return (
    <tr className="hover:bg-gray-50">
      <td className="px-4 py-3">
        <p className="font-medium text-gray-900 truncate max-w-[200px]">
          {driver.fullName || driver.name || 'Sin nombre'}
        </p>
        {driver.driverProfile?.documentNumber && (
          <p className="text-xs text-gray-500">DNI: {driver.driverProfile.documentNumber}</p>
        )}
      </td>
      <td className="px-4 py-3">
        <p className="text-xs text-gray-700 truncate max-w-[200px]">{driver.email || '—'}</p>
        <p className="text-xs text-gray-500">{driver.phone || driver.phoneNumber || '—'}</p>
      </td>
      <td className="px-4 py-3">
        {vehicle?.make ? (
          <>
            <p className="text-xs text-gray-700">
              <Car className="w-3 h-3 inline mr-1" />
              {vehicle.make} {vehicle.model}
            </p>
            <p className="text-xs font-mono text-gray-500">{vehicle.plate ?? '—'}</p>
          </>
        ) : (
          <span className="text-xs text-gray-400">—</span>
        )}
      </td>
      <td className="px-4 py-3">
        {driver.documentVerified === true ? (
          <span className="text-xs text-green-700 flex items-center gap-1">
            <CheckCircle2 className="w-3 h-3" /> Verificado
          </span>
        ) : (
          <span className="text-xs text-gray-500 flex items-center gap-1">
            <Clock className="w-3 h-3" /> Sin verificar
          </span>
        )}
      </td>
      <td className="px-4 py-3">
        <StatusBadge status={driver.driverStatus} />
      </td>
      <td className="px-4 py-3 text-xs text-gray-600">
        {date.toLocaleDateString('es-PE', { day: '2-digit', month: 'short' })}
      </td>
      <td className="px-4 py-3 text-right">
        <Link
          to={`/verifications/${driver.id}`}
          className="inline-flex items-center gap-1 px-3 py-1.5 bg-[#E31E24] text-white text-xs font-medium rounded-lg hover:bg-[#B5181D]"
        >
          Revisar
        </Link>
      </td>
    </tr>
  )
}

function StatusBadge({ status }: { status?: DriverApprovalStatus }) {
  const map: Record<string, { bg: string; label: string; icon: React.ReactNode }> = {
    pending_documents: { bg: 'bg-amber-100 text-amber-700', label: 'Faltan docs', icon: <Clock className="w-3 h-3" /> },
    pending_approval: { bg: 'bg-yellow-100 text-yellow-700', label: 'Por aprobar', icon: <Clock className="w-3 h-3" /> },
    approved: { bg: 'bg-green-100 text-green-700', label: 'Aprobado', icon: <CheckCircle2 className="w-3 h-3" /> },
    rejected: { bg: 'bg-red-100 text-red-700', label: 'Rechazado', icon: <XCircle className="w-3 h-3" /> },
  }
  const cfg = map[status ?? ''] ?? { bg: 'bg-gray-100 text-gray-700', label: status || '—', icon: null }
  return (
    <span className={`text-xs px-2 py-0.5 rounded font-medium inline-flex items-center gap-1 ${cfg.bg}`}>
      {cfg.icon}
      {cfg.label}
    </span>
  )
}
