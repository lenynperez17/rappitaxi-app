import { useState } from 'react'
import { Link } from 'react-router-dom'
import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { Search, Loader2, AlertCircle, ShieldCheck, Phone, Mail, CheckCircle2, ChevronRight, FileText } from 'lucide-react'
import { adminApi, AdminApiError, type AdminDriver } from '../../lib/adminApi'
import { queryKeys } from '../../lib/queryKeys'
import { useDebouncedValue } from '../../hooks/useDebouncedValue'
import { Avatar } from '../../components/Avatar'
import { pickPhotoUrl } from '../../lib/photoUrl'
import { DateTime } from '../../components/DateTime'

export function VerificationsPage() {
  const [search, setSearch] = useState('')
  /**
   * Ronda 283: abre mostrando TODOS.
   *
   * Abría en "Pendientes", y como no había ninguno la pantalla se veía vacía
   * con un "No hay conductores en esta categoría" que se lee como una avería
   * —de hecho así se reportó—. Y aunque hubiera pendientes, entrar sin poder
   * ver a los ya aprobados obliga a cambiar el filtro para responder a la
   * pregunta más normal: quién está verificado y quién no.
   *
   * Con "Todos" siempre hay algo en pantalla, y el resumen de abajo dice de un
   * vistazo cuántos hay de cada clase.
   */
  const [status, setStatus] = useState<'unverified' | 'verified' | 'all'>('all')

  // Ronda 287: mismo esquema que DriversPage (sustituye al `requestSeq` de la
  // Ronda 113 y al efecto único de la 214). Comparte caché con Conductores:
  // verificar a alguien desde su ficha refresca las dos listas.
  const debouncedSearch = useDebouncedValue(search, 350)
  const filters = {
    status: status !== 'all' ? status : undefined,
    search: debouncedSearch || undefined,
    pageSize: 100,
  }
  const driversQuery = useQuery({
    queryKey: queryKeys.drivers.list(filters),
    queryFn: () => adminApi.listDrivers(filters),
    placeholderData: keepPreviousData,
  })
  const drivers: AdminDriver[] = driversQuery.data?.drivers ?? []
  const total = driversQuery.data?.total ?? 0
  const loading = driversQuery.isPending
  const error = driversQuery.isError
    ? (driversQuery.error instanceof AdminApiError ? driversQuery.error.message : 'Error cargando verificaciones')
    : null

  return (
    <div className="space-y-6">
      <div className="flex items-start justify-between gap-4 flex-wrap">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Verificaciones</h1>
          {/* Ronda 283: el subtítulo decía "Conductores pendientes de
              verificación" y la pantalla ya no lista solo los pendientes. */}
          <p className="text-sm text-gray-500 mt-1">
            Quién tiene el alta aprobada y quién sigue esperando
          </p>
        </div>
        {/* Ronda 279: acceso al catálogo de documentos. */}
        <Link
          to="/verifications/documentos"
          className="inline-flex items-center gap-2 px-4 py-2 rounded-lg border border-gray-200 text-sm font-medium text-gray-700 hover:bg-gray-50"
        >
          <FileText className="w-4 h-4" /> Documentos solicitados
        </Link>
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
          <option value="all">Todos{status === 'all' ? ` (${total})` : ''}</option>
          <option value="unverified">Pendientes{status === 'unverified' ? ` (${total})` : ''}</option>
          <option value="verified">Verificados{status === 'verified' ? ` (${total})` : ''}</option>
        </select>
      </div>

      {/* Ronda 283: el reparto de un vistazo. Antes el número de pendientes
          solo se veía si estabas mirando ese filtro, así que para saber si
          tenías trabajo esperando había que ir a buscarlo. */}
      {status === 'all' && !loading && drivers.length > 0 && (
        <div className="bg-white rounded-xl border border-gray-200 p-4 flex flex-wrap gap-6 text-sm">
          <div>
            <div className="text-gray-500">Aprobados</div>
            <div className="text-xl font-semibold text-green-700 tabular-nums">
              {drivers.filter((d) => d.isVerified).length}
            </div>
          </div>
          <div>
            <div className="text-gray-500">Pendientes</div>
            <div className={`text-xl font-semibold tabular-nums ${
              drivers.some((d) => !d.isVerified) ? 'text-amber-700' : 'text-gray-400'
            }`}>
              {drivers.filter((d) => !d.isVerified).length}
            </div>
          </div>
          {total > drivers.length && (
            <p className="text-xs text-gray-400 self-end">
              Reparto de los {drivers.length} que se ven, de {total} en total.
            </p>
          )}
        </div>
      )}

      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        {loading ? (
          <div className="p-12 text-center text-gray-500 flex items-center justify-center gap-2">
            <Loader2 className="w-4 h-4 animate-spin" /> Cargando...
          </div>
        ) : drivers.length === 0 ? (
          /* Ronda 283: decía "No hay conductores en esta categoría", que con el
             filtro de pendientes vacío se leía como que la pantalla estaba
             rota. Ahora dice qué pasa y ofrece la salida. */
          <div className="p-12 text-center text-gray-500">
            <ShieldCheck className="w-10 h-10 mx-auto mb-3 text-gray-300" />
            {search ? (
              <p>Ningún conductor coincide con «{search}».</p>
            ) : status === 'unverified' ? (
              <>
                <p className="font-medium text-gray-700">No hay nadie esperando aprobación.</p>
                <p className="text-sm mt-1">
                  Todos los conductores registrados ya tienen el alta aprobada.{' '}
                  <button onClick={() => setStatus('all')} className="text-orange-600 hover:underline">
                    Ver todos
                  </button>
                </p>
              </>
            ) : status === 'verified' ? (
              <>
                <p className="font-medium text-gray-700">Todavía no has aprobado a ningún conductor.</p>
                <button onClick={() => setStatus('all')} className="text-sm mt-1 text-orange-600 hover:underline">
                  Ver todos
                </button>
              </>
            ) : (
              <p>Aún no hay conductores registrados.</p>
            )}
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
                    <div className="text-xs text-gray-400 mt-1"><DateTime value={d.createdAt} /></div>
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
