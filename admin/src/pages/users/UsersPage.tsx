import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { collection, query, getDocs, orderBy, limit } from 'firebase/firestore'
import { db } from '../../config/firebase'
import { Search, Phone, Mail } from 'lucide-react'
import { Avatar, pickPhotoUrl } from '../../components/Avatar'
import { relativeTime, toDate } from '../../utils/timeFormat'

type UserTypeFilter = 'all' | 'passenger' | 'driver' | 'dual' | 'admin'

interface UserRow {
  id: string
  fullName?: string
  name?: string
  email?: string
  phone?: string
  phoneNumber?: string
  userType?: string
  driverStatus?: string
  isActive?: boolean
  totalTrips?: number
  rating?: number
  createdAt?: any
  profilePhotoUrl?: string
  photoUrl?: string
  documentNumber?: string
  isOnline?: boolean
  isAdmin?: boolean
}

const USER_TYPE_OPTIONS: Array<{ value: UserTypeFilter; label: string }> = [
  { value: 'all', label: 'Todos' },
  { value: 'passenger', label: 'Pasajeros' },
  { value: 'driver', label: 'Conductores' },
  { value: 'dual', label: 'Dual' },
  { value: 'admin', label: 'Administradores' },
]

const TYPE_BADGES: Record<string, string> = {
  passenger: 'bg-blue-100 text-blue-700',
  driver: 'bg-orange-100 text-orange-700',
  dual: 'bg-purple-100 text-purple-700',
  admin: 'bg-red-100 text-red-700',
}

export function UsersPage() {
  const [users, setUsers] = useState<UserRow[]>([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [typeFilter, setTypeFilter] = useState<UserTypeFilter>('all')

  useEffect(() => {
    void load()
  }, [])

  const load = async () => {
    setLoading(true)
    try {
      const snap = await getDocs(
        query(collection(db, 'users'), orderBy('createdAt', 'desc'), limit(500)),
      )
      setUsers(snap.docs.map((d) => ({ id: d.id, ...(d.data() as any) })))
    } catch (err) {
      console.error('UsersPage load error:', err)
      // Fallback without orderBy if index is missing
      try {
        const fb = await getDocs(query(collection(db, 'users'), limit(500)))
        setUsers(fb.docs.map((d) => ({ id: d.id, ...(d.data() as any) })))
      } catch (e2) {
        console.error('Fallback failed:', e2)
        setUsers([])
      }
    } finally {
      setLoading(false)
    }
  }

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    return users.filter((u) => {
      // Filtro por tipo
      if (typeFilter !== 'all') {
        if (typeFilter === 'admin') {
          if (!u.isAdmin && u.userType !== 'admin') return false
        } else if (u.userType !== typeFilter) return false
      }
      // Filtro por búsqueda
      if (!q) return true
      return (
        u.fullName?.toLowerCase().includes(q) ||
        u.name?.toLowerCase().includes(q) ||
        u.email?.toLowerCase().includes(q) ||
        u.phone?.includes(q) ||
        u.phoneNumber?.includes(q) ||
        u.documentNumber?.toLowerCase().includes(q) ||
        u.id.toLowerCase().includes(q)
      )
    })
  }, [users, search, typeFilter])

  const counters = useMemo(() => {
    const c = { passenger: 0, driver: 0, dual: 0, admin: 0 }
    for (const u of users) {
      if (u.isAdmin || u.userType === 'admin') c.admin += 1
      else if (u.userType === 'passenger') c.passenger += 1
      else if (u.userType === 'driver') c.driver += 1
      else if (u.userType === 'dual') c.dual += 1
    }
    return c
  }, [users])

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Usuarios</h1>
        <p className="text-sm text-gray-500 mt-1">
          Total: <strong>{users.length}</strong> · {counters.passenger} pasajeros ·{' '}
          {counters.driver} conductores · {counters.dual} dual · {counters.admin} admins
        </p>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 p-4 flex flex-col md:flex-row gap-3">
        <select
          value={typeFilter}
          onChange={(e) => setTypeFilter(e.target.value as UserTypeFilter)}
          className="px-3 py-2 border border-gray-300 rounded-lg text-sm bg-white focus:outline-none focus:ring-2 focus:ring-[#E31E24]"
        >
          {USER_TYPE_OPTIONS.map((opt) => (
            <option key={opt.value} value={opt.value}>
              {opt.label}
            </option>
          ))}
        </select>
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <input
            type="text"
            placeholder="Buscar por nombre, email, teléfono o DNI..."
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
                <th className="text-left px-4 py-3 font-medium text-gray-600">Usuario</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Tipo</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Contacto</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Registro</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Viajes</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Rating</th>
                <th className="text-left px-4 py-3 font-medium text-gray-600">Estado</th>
                <th></th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {loading ? (
                <tr>
                  <td colSpan={8} className="text-center py-12 text-gray-400">
                    Cargando...
                  </td>
                </tr>
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={8} className="text-center py-12 text-gray-400">
                    Sin resultados
                  </td>
                </tr>
              ) : (
                filtered.map((u) => {
                  const fullName = u.fullName || u.name || '(sin nombre)'
                  const typeLabel =
                    u.isAdmin || u.userType === 'admin' ? 'admin' : u.userType ?? '—'
                  const isSuspended = u.isActive === false
                  return (
                    <tr key={u.id} className="hover:bg-gray-50">
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-3">
                          <div className="relative">
                            <Avatar src={pickPhotoUrl(u)} name={fullName} size="md" />
                            {u.isOnline && (
                              <span
                                className="absolute -bottom-0.5 -right-0.5 w-2.5 h-2.5 bg-green-500 border-2 border-white rounded-full"
                                title="Online"
                              />
                            )}
                          </div>
                          <div className="min-w-0">
                            <p className="font-medium text-gray-900 truncate max-w-[200px]">{fullName}</p>
                            {u.documentNumber && (
                              <p className="text-[11px] text-gray-500">DNI: {u.documentNumber}</p>
                            )}
                          </div>
                        </div>
                      </td>
                      <td className="px-4 py-3">
                        <span className={`text-xs px-2 py-0.5 rounded font-medium ${TYPE_BADGES[typeLabel] ?? 'bg-gray-100 text-gray-700'}`}>
                          {typeLabel}
                        </span>
                      </td>
                      <td className="px-4 py-3">
                        {u.email && (
                          <p className="text-xs text-gray-700 flex items-center gap-1 truncate max-w-[200px]">
                            <Mail className="w-3 h-3 shrink-0" />
                            {u.email}
                          </p>
                        )}
                        {(u.phone || u.phoneNumber) && (
                          <a
                            href={`tel:${u.phone ?? u.phoneNumber}`}
                            className="text-xs text-blue-600 hover:underline flex items-center gap-1"
                          >
                            <Phone className="w-3 h-3 shrink-0" />
                            {u.phone ?? u.phoneNumber}
                          </a>
                        )}
                      </td>
                      <td className="px-4 py-3 text-xs text-gray-600 whitespace-nowrap">
                        {relativeTime(toDate(u.createdAt))}
                      </td>
                      <td className="px-4 py-3 text-gray-700">{u.totalTrips ?? 0}</td>
                      <td className="px-4 py-3 text-gray-700">
                        {u.rating != null ? `⭐ ${u.rating.toFixed(1)}` : '—'}
                      </td>
                      <td className="px-4 py-3">
                        {isSuspended ? (
                          <span className="text-xs px-2 py-0.5 rounded bg-red-100 text-red-700">Suspendido</span>
                        ) : (
                          <span className="text-xs px-2 py-0.5 rounded bg-green-100 text-green-700">Activo</span>
                        )}
                      </td>
                      <td className="px-4 py-3 text-right">
                        <Link to={`/users/${u.id}`} className="text-[#E31E24] hover:underline text-sm">
                          Ver
                        </Link>
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
