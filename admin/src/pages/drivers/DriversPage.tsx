import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { collection, query, where, getDocs, orderBy, limit } from 'firebase/firestore'
import { db } from '../../config/firebase'
import { Search, Car, Phone, ShieldCheck } from 'lucide-react'
import { Avatar, pickPhotoUrl } from '../../components/Avatar'
import { relativeTime, toDate } from '../../utils/timeFormat'
import { formatPEN } from '../../utils/currency'

interface DriverRow {
  id: string
  fullName?: string
  name?: string
  email?: string
  phone?: string
  phoneNumber?: string
  userType?: string
  driverStatus?: string
  isActive?: boolean
  isOnline?: boolean
  totalTrips?: number
  totalEarnings?: number
  balance?: number
  rating?: number
  createdAt?: any
  vehicleInfo?: {
    make?: string
    model?: string
    year?: string | number
    plate?: string
    color?: string
  }
  profilePhotoUrl?: string
  photoUrl?: string
  documentNumber?: string
}

const STATUS_FILTERS: Array<{ value: 'all' | string; label: string }> = [
  { value: 'all', label: 'Todos' },
  { value: 'approved', label: 'Aprobados' },
  { value: 'pending_approval', label: 'Pendientes' },
  { value: 'pending_documents', label: 'Faltan docs' },
  { value: 'rejected', label: 'Rechazados' },
  { value: 'suspended', label: 'Suspendidos' },
]

const STATUS_BADGE: Record<string, { bg: string; label: string }> = {
  approved: { bg: 'bg-green-100 text-green-700', label: 'Aprobado' },
  pending_approval: { bg: 'bg-yellow-100 text-yellow-700', label: 'Por aprobar' },
  pending_documents: { bg: 'bg-amber-100 text-amber-700', label: 'Faltan docs' },
  rejected: { bg: 'bg-red-100 text-red-700', label: 'Rechazado' },
  suspended: { bg: 'bg-gray-200 text-gray-700', label: 'Suspendido' },
}

export function DriversPage() {
  const [drivers, setDrivers] = useState<DriverRow[]>([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState<string>('all')

  useEffect(() => {
    void load()
  }, [])

  const load = async () => {
    setLoading(true)
    try {
      const snap = await getDocs(
        query(
          collection(db, 'users'),
          where('userType', 'in', ['driver', 'dual']),
          orderBy('createdAt', 'desc'),
          limit(500),
        ),
      )
      setDrivers(snap.docs.map((d) => ({ id: d.id, ...(d.data() as any) })))
    } catch (err) {
      console.error('DriversPage load error:', err)
      try {
        const fb = await getDocs(
          query(collection(db, 'users'), where('userType', 'in', ['driver', 'dual']), limit(500)),
        )
        setDrivers(fb.docs.map((d) => ({ id: d.id, ...(d.data() as any) })))
      } catch (e2) {
        console.error('Fallback failed:', e2)
        setDrivers([])
      }
    } finally {
      setLoading(false)
    }
  }

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    return drivers.filter((d) => {
      if (statusFilter !== 'all' && d.driverStatus !== statusFilter) return false
      if (!q) return true
      return (
        d.fullName?.toLowerCase().includes(q) ||
        d.name?.toLowerCase().includes(q) ||
        d.email?.toLowerCase().includes(q) ||
        d.phone?.includes(q) ||
        d.phoneNumber?.includes(q) ||
        d.vehicleInfo?.plate?.toLowerCase().includes(q) ||
        d.documentNumber?.toLowerCase().includes(q) ||
        d.id.toLowerCase().includes(q)
      )
    })
  }, [drivers, search, statusFilter])

  const counters = useMemo(() => {
    let online = 0
    let approved = 0
    let pending = 0
    for (const d of drivers) {
      if (d.isOnline) online += 1
      if (d.driverStatus === 'approved') approved += 1
      else if (d.driverStatus === 'pending_approval' || d.driverStatus === 'pending_documents')
        pending += 1
    }
    return { online, approved, pending }
  }, [drivers])

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Conductores</h1>
        <p className="text-sm text-gray-500 mt-1">
          {drivers.length} totales · <strong className="text-green-700">{counters.online} online</strong>{' '}
          · {counters.approved} aprobados · {counters.pending} pendientes
        </p>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 p-4 flex flex-col md:flex-row gap-3">
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          className="px-3 py-2 border border-gray-300 rounded-lg text-sm bg-white focus:outline-none focus:ring-2 focus:ring-[#E31E24]"
        >
          {STATUS_FILTERS.map((opt) => (
            <option key={opt.value} value={opt.value}>
              {opt.label}
            </option>
          ))}
        </select>
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <input
            type="text"
            placeholder="Buscar por nombre, email, teléfono, placa o DNI..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full pl-9 pr-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#E31E24]"
          />
        </div>
        <span className="text-xs text-gray-500 self-center whitespace-nowrap">
          {filtered.length} resultado{filtered.length !== 1 ? 's' : ''}
        </span>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Conductor</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Contacto</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Vehículo</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Placa</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Estado</th>
                <th className="text-right px-4 py-3 font-medium text-gray-600">Balance</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Rating</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Viajes</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Registro</th>
                <th></th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {loading ? (
                <tr>
                  <td colSpan={10} className="text-center py-12 text-gray-400">
                    Cargando...
                  </td>
                </tr>
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={10} className="text-center py-12 text-gray-400">
                    Sin conductores
                  </td>
                </tr>
              ) : (
                filtered.map((d) => {
                  const fullName = d.fullName || d.name || '(sin nombre)'
                  const status = d.driverStatus ?? 'pending_documents'
                  const badge = STATUS_BADGE[status] ?? { bg: 'bg-gray-100 text-gray-700', label: status }
                  const vehicle = d.vehicleInfo
                  return (
                    <tr key={d.id} className="hover:bg-gray-50">
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-3">
                          <div className="relative">
                            <Avatar src={pickPhotoUrl(d)} name={fullName} size="md" />
                            {d.isOnline && (
                              <span
                                className="absolute -bottom-0.5 -right-0.5 w-2.5 h-2.5 bg-green-500 border-2 border-white rounded-full"
                                title="Online"
                              />
                            )}
                          </div>
                          <div className="min-w-0">
                            <p className="font-medium text-gray-900 truncate max-w-[160px]">{fullName}</p>
                            {d.documentNumber && (
                              <p className="text-[11px] text-gray-500">DNI: {d.documentNumber}</p>
                            )}
                          </div>
                        </div>
                      </td>
                      <td className="px-4 py-3">
                        {d.email && (
                          <p className="text-xs text-gray-700 truncate max-w-[200px]">{d.email}</p>
                        )}
                        {(d.phone || d.phoneNumber) && (
                          <a
                            href={`tel:${d.phone ?? d.phoneNumber}`}
                            className="text-xs text-blue-600 hover:underline flex items-center gap-1"
                          >
                            <Phone className="w-3 h-3" />
                            {d.phone ?? d.phoneNumber}
                          </a>
                        )}
                      </td>
                      <td className="px-4 py-3 text-xs text-gray-700">
                        {vehicle?.make ? (
                          <>
                            <Car className="w-3 h-3 inline mr-1 text-gray-500" />
                            {vehicle.make} {vehicle.model}
                            {vehicle.year && <span className="text-gray-400"> · {vehicle.year}</span>}
                            {vehicle.color && <span className="text-gray-400"> · {vehicle.color}</span>}
                          </>
                        ) : (
                          <span className="text-gray-400">—</span>
                        )}
                      </td>
                      <td className="px-4 py-3 text-xs font-mono text-gray-700">
                        {vehicle?.plate ?? '—'}
                      </td>
                      <td className="px-4 py-3">
                        <span className={`text-xs px-2 py-0.5 rounded font-medium ${badge.bg}`}>
                          {badge.label}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-right text-gray-900 font-medium whitespace-nowrap">
                        {formatPEN(d.balance ?? 0)}
                      </td>
                      <td className="px-4 py-3 text-gray-700">
                        {d.rating != null ? `⭐ ${d.rating.toFixed(1)}` : '—'}
                      </td>
                      <td className="px-4 py-3 text-gray-700">{d.totalTrips ?? 0}</td>
                      <td className="px-4 py-3 text-xs text-gray-600 whitespace-nowrap">
                        {relativeTime(toDate(d.createdAt))}
                      </td>
                      <td className="px-4 py-3 text-right whitespace-nowrap">
                        <div className="flex items-center justify-end gap-2">
                          {status !== 'approved' && (
                            <Link
                              to={`/verifications/${d.id}`}
                              className="inline-flex items-center gap-1 text-[#E31E24] hover:underline text-xs"
                              title="Verificar documentos"
                            >
                              <ShieldCheck className="w-3.5 h-3.5" /> Docs
                            </Link>
                          )}
                          <Link
                            to={`/users/${d.id}`}
                            className="text-[#E31E24] hover:underline text-xs"
                          >
                            Ver
                          </Link>
                        </div>
                      </td>
                    </tr>
                  )
                })
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}
