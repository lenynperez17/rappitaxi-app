import { useEffect, useRef, useState } from 'react'
import { Link } from 'react-router-dom'
import { Search, Loader2, AlertCircle, ShieldCheck, Phone, Mail, CheckCircle2, ChevronRight } from 'lucide-react'
import { adminApi, AdminApiError, type AdminDriver } from '../../lib/adminApi'
import { Avatar, pickPhotoUrl } from '../../components/Avatar'
import { relativeTime, toDate } from '../../utils/timeFormat'

export function VerificationsPage() {
  const [drivers, setDrivers] = useState<AdminDriver[]>([])
  const [total, setTotal] = useState(0)
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [status, setStatus] = useState<'unverified' | 'verified' | 'all'>('unverified')
  const [error, setError] = useState<string | null>(null)

  // Ronda 113: request id (mismo patrón Rondas 111/112).
  const requestSeq = useRef(0)

  const load = async () => {
    const seq = ++requestSeq.current
    setLoading(true); setError(null)
    try {
      const resp = await adminApi.listDrivers({
        status: status !== 'all' ? status : undefined,
        search: search || undefined,
        pageSize: 100,
      })
      if (seq !== requestSeq.current) return
      setDrivers(resp.drivers); setTotal(resp.total)
    } catch (err) {
      if (seq !== requestSeq.current) return
      setError(err instanceof AdminApiError ? err.message : 'Error cargando verificaciones')
    } finally { if (seq === requestSeq.current) setLoading(false) }
  }

  // Ronda 214: un solo useEffect (evita doble fetch en mount).
  useEffect(() => {
    const t = setTimeout(() => void load(), search ? 350 : 0)
    return () => clearTimeout(t)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [status, search])

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Verificaciones</h1>
        <p className="text-sm text-gray-500 mt-1">Conductores pendientes de verificación</p>
      </div>

      {error && (
        <div className="p-3 rounded-lg bg-red-50 border border-red-200 text-sm text-red-700 flex items-center gap-2">
          <AlertCircle className="w-4 h-4" /> {error}
        </div>
      )}

      <div className="bg-white rounded-xl border border-gray-200 p-4 flex flex-col md:flex-row gap-3">
        <div className="flex-1 relative">
          <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input value={search} onChange={(e) => setSearch(e.target.value)}
            placeholder="Buscar conductor..." type="text"
            className="w-full pl-10 pr-3 py-2 border border-gray-200 rounded-lg text-sm" />
        </div>
        <select value={status} onChange={(e) => setStatus(e.target.value as typeof status)}
          className="border border-gray-200 rounded-lg px-3 py-2 text-sm">
          <option value="unverified">Pendientes{status === 'unverified' ? ` (${total})` : ''}</option>
          <option value="verified">Verificados{status === 'verified' ? ` (${total})` : ''}</option>
          <option value="all">Todos{status === 'all' ? ` (${total})` : ''}</option>
        </select>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        {loading ? (
          <div className="p-12 text-center text-gray-500 flex items-center justify-center gap-2">
            <Loader2 className="w-4 h-4 animate-spin" /> Cargando...
          </div>
        ) : drivers.length === 0 ? (
          <div className="p-12 text-center text-gray-500">
            <ShieldCheck className="w-10 h-10 mx-auto mb-3 text-gray-300" />
            No hay conductores en esta categoría
          </div>
        ) : (
          <ul className="divide-y divide-gray-100">
            {drivers.map((d) => (
              <li key={d.id}>
                <Link
                  to={`/verifications/${d.id}`}
                  className="p-4 hover:bg-gray-50 flex items-center gap-4 group"
                >
                  <Avatar name={d.fullName ?? undefined} src={pickPhotoUrl(d.profilePhotoUrl)} />
                  <div className="flex-1 min-w-0">
                    <div className="font-medium text-gray-900 truncate">{d.fullName ?? '(sin nombre)'}</div>
                    <div className="flex items-center gap-3 text-xs text-gray-500 mt-1">
                      {d.phone && <span className="inline-flex items-center gap-1"><Phone className="w-3 h-3" /> {d.phone}</span>}
                      {d.email && <span className="inline-flex items-center gap-1"><Mail className="w-3 h-3" /> {d.email}</span>}
                    </div>
                  </div>
                  <div className="text-right flex flex-col items-end gap-1">
                    <div className="flex items-center gap-1 flex-wrap justify-end">
                      {d.isVerified ? (
                        <span className="inline-flex items-center gap-1 text-xs bg-green-100 text-green-700 px-2 py-0.5 rounded-full">
                          <CheckCircle2 className="w-3 h-3" /> Verificado
                        </span>
                      ) : (
                        <span className="text-xs bg-yellow-100 text-yellow-700 px-2 py-0.5 rounded-full">Pendiente</span>
                      )}
                      <OriginBadgeCompact createdFrom={d.createdFrom} />
                    </div>
                    <div className="text-xs text-gray-400 mt-1">{relativeTime(toDate(d.createdAt))}</div>
                  </div>
                  <ChevronRight className="w-4 h-4 text-gray-300 group-hover:text-gray-500 transition-colors" />
                </Link>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  )
}

// Chip compacto sin texto — solo emoji + tooltip. Para listados densos.
function OriginBadgeCompact({ createdFrom }: { createdFrom?: string }) {
  const meta: Record<string, { title: string; icon: string; cls: string }> = {
    mobile:        { title: 'Registrado desde el app móvil',    icon: '📱', cls: 'bg-blue-100 text-blue-800' },
    admin_panel:   { title: 'Creado desde el panel web',        icon: '🖥️', cls: 'bg-purple-100 text-purple-800' },
    oauth_google:  { title: 'Registrado con Google Sign-In',    icon: '🔑', cls: 'bg-red-50 text-red-700' },
    oauth_apple:   { title: 'Registrado con Apple Sign-In',     icon: '', cls: 'bg-gray-100 text-gray-800' },
    import:        { title: 'Importado desde otro sistema',      icon: '📥', cls: 'bg-amber-100 text-amber-800' },
    unknown:       { title: 'Origen desconocido',                icon: '❔', cls: 'bg-gray-100 text-gray-500' },
  }
  const m = meta[createdFrom ?? 'unknown'] ?? meta.unknown
  return (
    <span title={m.title} className={`text-xs px-1.5 py-0.5 rounded-full ${m.cls}`}>
      {m.icon}
    </span>
  )
}
