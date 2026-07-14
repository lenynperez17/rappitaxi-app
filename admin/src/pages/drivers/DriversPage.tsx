import { useEffect, useState } from 'react'
import { Search, Phone, Mail, Star, Car, Loader2, CheckCircle2, AlertCircle } from 'lucide-react'
import { adminApi, AdminApiError, type AdminDriver } from '../../lib/adminApi'
import { Avatar, pickPhotoUrl } from '../../components/Avatar'
import { relativeTime, toDate } from '../../utils/timeFormat'

type StatusFilter = 'all' | 'active' | 'suspended' | 'verified' | 'unverified'

const STATUS_OPTIONS: Array<{ value: StatusFilter; label: string }> = [
  { value: 'all', label: 'Todos' },
  { value: 'active', label: 'Activos' },
  { value: 'suspended', label: 'Suspendidos' },
  { value: 'verified', label: 'Verificados' },
  { value: 'unverified', label: 'Sin verificar' },
]

export function DriversPage() {
  const [drivers, setDrivers] = useState<AdminDriver[]>([])
  const [total, setTotal] = useState(0)
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [status, setStatus] = useState<StatusFilter>('all')
  const [error, setError] = useState<string | null>(null)

  const load = async () => {
    setLoading(true)
    setError(null)
    try {
      const resp = await adminApi.listDrivers({
        status: status !== 'all' ? status : undefined,
        search: search || undefined,
        pageSize: 100,
      })
      setDrivers(resp.drivers)
      setTotal(resp.total)
    } catch (err) {
      setError(err instanceof AdminApiError ? err.message : 'Error cargando conductores')
      setDrivers([])
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { void load() }, [status])
  useEffect(() => {
    const t = setTimeout(() => void load(), 350)
    return () => clearTimeout(t)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [search])

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Conductores</h1>
        <p className="text-sm text-gray-500 mt-1">Total: <strong>{total}</strong></p>
      </div>

      {error && (
        <div className="p-3 rounded-lg bg-red-50 border border-red-200 text-sm text-red-700 flex items-center gap-2">
          <AlertCircle className="w-4 h-4" /> {error}
        </div>
      )}

      <div className="bg-white rounded-xl border border-gray-200 p-4 flex flex-col md:flex-row gap-3">
        <div className="flex-1 relative">
          <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Buscar por nombre, correo o teléfono..."
            className="w-full pl-10 pr-3 py-2 border border-gray-200 rounded-lg text-sm"
          />
        </div>
        <select
          value={status}
          onChange={(e) => setStatus(e.target.value as StatusFilter)}
          className="border border-gray-200 rounded-lg px-3 py-2 text-sm"
        >
          {STATUS_OPTIONS.map((o) => (
            <option key={o.value} value={o.value}>{o.label}</option>
          ))}
        </select>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        {loading ? (
          <div className="p-12 text-center text-gray-500 flex items-center justify-center gap-2">
            <Loader2 className="w-4 h-4 animate-spin" /> Cargando conductores...
          </div>
        ) : drivers.length === 0 ? (
          <div className="p-12 text-center text-gray-500">
            <Car className="w-10 h-10 mx-auto mb-3 text-gray-300" />
            No hay conductores registrados
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-gray-50 text-gray-500 text-xs uppercase">
                <tr>
                  <th className="text-left px-4 py-3">Conductor</th>
                  <th className="text-left px-4 py-3">Contacto</th>
                  <th className="text-left px-4 py-3">Tipo</th>
                  <th className="text-center px-4 py-3">Viajes</th>
                  <th className="text-center px-4 py-3">Rating</th>
                  <th className="text-left px-4 py-3">Estado</th>
                  <th className="text-left px-4 py-3">Registro</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {drivers.map((d) => (
                  <tr key={d.id} className="hover:bg-gray-50">
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-3">
                        <Avatar
                          name={d.fullName ?? d.email ?? undefined}
                          src={pickPhotoUrl(d.profilePhotoUrl)}
                        />
                        <div className="min-w-0">
                          <div className="font-medium text-gray-900 truncate max-w-[200px]">
                            {d.fullName ?? '(sin nombre)'}
                          </div>
                          <div className="text-xs text-gray-400 truncate max-w-[200px]">{d.id}</div>
                        </div>
                      </div>
                    </td>
                    <td className="px-4 py-3 text-gray-700">
                      {d.email && (
                        <div className="flex items-center gap-1 text-xs">
                          <Mail className="w-3 h-3 text-gray-400" />
                          <span className="truncate max-w-[180px]">{d.email}</span>
                        </div>
                      )}
                      {d.phone && (
                        <div className="flex items-center gap-1 text-xs">
                          <Phone className="w-3 h-3 text-gray-400" /> {d.phone}
                        </div>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${
                        d.userType === 'dual' ? 'bg-purple-100 text-purple-700' : 'bg-orange-100 text-orange-700'
                      }`}>
                        {d.userType === 'dual' ? 'Dual' : 'Conductor'}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-center text-gray-700 font-medium">{d.totalTrips}</td>
                    <td className="px-4 py-3 text-center">
                      {d.avgRating !== null ? (
                        <span className="inline-flex items-center gap-1 text-xs">
                          <Star className="w-3 h-3 fill-yellow-400 text-yellow-400" />
                          {d.avgRating.toFixed(2)}
                        </span>
                      ) : <span className="text-gray-400 text-xs">—</span>}
                    </td>
                    <td className="px-4 py-3">
                      {d.suspendedAt ? (
                        <span className="text-xs bg-red-100 text-red-700 px-2 py-0.5 rounded-full">Suspendido</span>
                      ) : d.isVerified ? (
                        <span className="inline-flex items-center gap-1 text-xs bg-green-100 text-green-700 px-2 py-0.5 rounded-full">
                          <CheckCircle2 className="w-3 h-3" /> Verificado
                        </span>
                      ) : d.isActive ? (
                        <span className="text-xs bg-yellow-100 text-yellow-700 px-2 py-0.5 rounded-full">Sin verificar</span>
                      ) : (
                        <span className="text-xs bg-gray-100 text-gray-500 px-2 py-0.5 rounded-full">Inactivo</span>
                      )}
                    </td>
                    <td className="px-4 py-3 text-xs text-gray-500">
                      {relativeTime(toDate(d.createdAt))}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  )
}
