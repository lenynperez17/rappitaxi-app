import { useEffect, useMemo, useRef, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import {
  Search, Phone, Mail, Plus, MoreVertical, Trash2, Edit, Ban, CheckCircle2,
  ShieldCheck, User as UserIcon, X, AlertCircle, Loader2, KeyRound,
} from 'lucide-react'
import { adminApi, AdminApiError, type AdminUser } from '../../lib/adminApi'
import { FloatingLayer } from '../../components/FloatingLayer'
import { Avatar, pickPhotoUrl } from '../../components/Avatar'
import { DateTime } from '../../components/DateTime'

/**
 * Ronda 282: se acabó el tipo 'driver'.
 *
 * Toda cuenta nace como pasajero y se promueve a conductor desde ahí, así que
 * quien conduce es 'dual' — puede aceptar viajes y también pedirlos. El tipo
 * 'driver' era una reliquia con una sola cuenta, y tenerlo en el desplegable
 * permitía seguir creando cuentas que ninguna de las dos cosas.
 *
 * "Dual" tampoco se le enseña ya a nadie: es jerga interna. Quien administra
 * ve "Conductor", que es lo que esa persona es.
 */
type UserTypeFilter = 'all' | 'passenger' | 'dual' | 'admin'
type StatusFilter = 'all' | 'active' | 'suspended' | 'deleted'

/**
 * Ronda 283: valores admitidos en la URL. Se comprueban en vez de confiar en
 * lo que venga: `?status=loquesea` dejaría la pantalla pidiendo un filtro que
 * el backend rechaza, y se vería como si no cargara.
 */
const TIPOS_VALIDOS: readonly UserTypeFilter[] = ['all', 'passenger', 'dual', 'admin']
const ESTADOS_VALIDOS: readonly StatusFilter[] = ['all', 'active', 'suspended', 'deleted']

function leerFiltro<T extends string>(
  valor: string | null,
  validos: readonly T[],
  porDefecto: T,
): T {
  return valor && (validos as readonly string[]).includes(valor) ? (valor as T) : porDefecto
}

const USER_TYPE_OPTIONS: Array<{ value: UserTypeFilter; label: string }> = [
  { value: 'all', label: 'Todos' },
  { value: 'passenger', label: 'Pasajeros' },
  { value: 'dual', label: 'Conductores' },
  { value: 'admin', label: 'Administradores' },
]

const TYPE_BADGES: Record<string, string> = {
  passenger: 'bg-blue-100 text-blue-700',
  dual: 'bg-orange-100 text-orange-700',
  admin: 'bg-red-100 text-red-700',
}

const TYPE_LABEL: Record<string, string> = {
  passenger: 'Pasajero',
  dual: 'Conductor',
  admin: 'Admin',
}

export function UsersPage() {
  const [users, setUsers] = useState<AdminUser[]>([])
  const [total, setTotal] = useState(0)
  const [loading, setLoading] = useState(true)
  const [searchParams, setSearchParams] = useSearchParams()
  const [search, setSearch] = useState('')
  /**
   * Ronda 283: los filtros arrancan desde la URL.
   *
   * El Inicio enlaza aquí con un filtro puesto —"Usuarios suspendidos" o
   * "Pasajeros"— y antes esos parámetros se ignoraban: se caía en la lista
   * general. Con "suspendidos" era peor que inútil, porque esta pantalla abre
   * por defecto en `active` y el usuario suspendido que ibas a ver era
   * justamente el que quedaba fuera.
   */
  const [typeFilter, setTypeFilter] = useState<UserTypeFilter>(
    () => leerFiltro(searchParams.get('type'), TIPOS_VALIDOS, 'all'),
  )
  const [statusFilter, setStatusFilter] = useState<StatusFilter>(
    () => leerFiltro(searchParams.get('status'), ESTADOS_VALIDOS, 'active'),
  )
  const [page, setPage] = useState(1)
  const [showCreate, setShowCreate] = useState(false)
  const [editUser, setEditUser] = useState<AdminUser | null>(null)
  /**
   * Ronda 283: se guarda también el botón que abrió el menú, no solo el id.
   *
   * El menú ya no se pinta dentro de la fila —ahí lo recortaba el `overflow`
   * de la tabla y en las últimas filas salía cortado— sino en una capa aparte
   * que necesita saber junto a qué botón colocarse. Ver `FloatingLayer`.
   */
  const [openMenu, setOpenMenu] = useState<{ id: string; el: HTMLElement } | null>(null)
  /** Cerrarlo desde las acciones, que solo necesitan eso. */
  const setOpenMenuId = (id: string | null) => {
    if (id === null) setOpenMenu(null)
  }
  const [flash, setFlash] = useState<{ kind: 'ok' | 'err'; msg: string } | null>(null)
  // Ronda 189: ref-set síncrono contra doble-delete por user.
  const deletingRef = useRef<Set<string>>(new Set())
  const [resetPasswordUser, setResetPasswordUser] = useState<AdminUser | null>(null)

  // Deep-link: /users?edit=<userId> abre el modal de edición. Se usa desde
  // DriversPage → "Editar" para reutilizar el mismo UI de edición sin
  // duplicarlo. Si el user no está en la lista actual (filtro distinto),
  // hacemos GET directo del user.
  useEffect(() => {
    const editId = searchParams.get('edit')
    if (!editId || editUser) return
    const target = users.find((u) => u.id === editId)
    if (target) {
      setEditUser(target)
      searchParams.delete('edit')
      setSearchParams(searchParams, { replace: true })
      return
    }
    // Fallback: usuario no visible con los filtros actuales.
    void (async () => {
      try {
        const u = await adminApi.getUser(editId)
        setEditUser(u)
        searchParams.delete('edit')
        setSearchParams(searchParams, { replace: true })
      } catch { /* silent — el user simplemente no existe */ }
    })()
  }, [users, searchParams, setSearchParams, editUser])

  const load = async () => {
    setLoading(true)
    try {
      const resp = await adminApi.listUsers({
        type: typeFilter !== 'all' ? typeFilter : undefined,
        status: statusFilter,
        search: search || undefined,
        page,
        pageSize: 200,
      })
      setUsers(resp.users)
      setTotal(resp.total)
    } catch (err) {
      const msg = err instanceof AdminApiError ? err.message : 'Error cargando usuarios'
      setFlash({ kind: 'err', msg })
      setUsers([])
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { void load() }, [typeFilter, statusFilter, page])

  // Debounce del search: reseteamos page a 1 y dejamos que el efecto de arriba
  // (que depende de page) haga el fetch. Ronda 110: usar functional setPage
  // que devuelve el prev anterior + evaluar en tiempo real para saber si
  // efectivamente cambió. Si cambió, el efecto de arriba dispara (skip load);
  // si no cambió (ya era 1), forzamos load. Antes: closure de setTimeout leía
  // page al momento de programar → doble fetch cuando el user tipeaba en page>1.
  useEffect(() => {
    const t = setTimeout(() => {
      let pageChanged = false
      setPage((prev) => {
        if (prev !== 1) { pageChanged = true; return 1 }
        return prev
      })
      // Solo si NO cambió page (ya era 1), el efecto de arriba no disparará
      // → forzamos load. Si cambió, el efecto lo hará y evitamos duplicado.
      if (!pageChanged) void load()
    }, 350)
    return () => clearTimeout(t)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [search])

  useEffect(() => {
    if (!flash) return
    const t = setTimeout(() => setFlash(null), 4000)
    return () => clearTimeout(t)
  }, [flash])

  const counters = useMemo(() => {
    const c = { passenger: 0, dual: 0, admin: 0 }
    for (const u of users) {
      if (u.isAdmin || u.userType === 'admin') c.admin += 1
      else if (u.userType === 'passenger') c.passenger += 1
      else if (u.userType === 'dual') c.dual += 1
    }
    return c
  }, [users])

  const handleSuspend = async (u: AdminUser) => {
    const reason = window.prompt(`Motivo de suspensión de ${u.fullName ?? u.email ?? u.phone}:`, '')
    if (reason === null) return
    try {
      await adminApi.suspendUser(u.id, reason || undefined)
      setFlash({ kind: 'ok', msg: 'Usuario suspendido' })
      await load()
    } catch (err) {
      setFlash({ kind: 'err', msg: err instanceof AdminApiError ? err.message : 'Error suspendiendo' })
    }
    setOpenMenuId(null)
  }

  const handleReactivate = async (u: AdminUser) => {
    try {
      await adminApi.reactivateUser(u.id)
      setFlash({ kind: 'ok', msg: 'Usuario reactivado' })
      await load()
    } catch (err) {
      setFlash({ kind: 'err', msg: err instanceof AdminApiError ? err.message : 'Error reactivando' })
    }
    setOpenMenuId(null)
  }

  const handleDelete = async (u: AdminUser) => {
    if (deletingRef.current.has(u.id)) return
    const label = u.fullName ?? u.email ?? u.phone ?? u.id.slice(0, 8)
    if (!window.confirm(`¿Eliminar permanentemente a "${label}"?\n\nEsta acción anonimiza la cuenta (soft delete) y revoca todas sus sesiones. NO se puede deshacer.`)) return
    deletingRef.current.add(u.id)
    try {
      await adminApi.deleteUser(u.id)
      setFlash({ kind: 'ok', msg: 'Usuario eliminado' })
      await load()
    } catch (err) {
      setFlash({ kind: 'err', msg: err instanceof AdminApiError ? err.message : 'Error eliminando' })
    } finally {
      deletingRef.current.delete(u.id)
      setOpenMenuId(null)
    }
  }

  const handleResetPassword = (u: AdminUser) => {
    // Abre el modal seguro (con input type=password enmascarado) en vez de
    // window.prompt() que muestra la clave en texto plano y ofrece autofill.
    setResetPasswordUser(u)
    setOpenMenuId(null)
  }

  const submitResetPassword = async (u: AdminUser, newPassword: string) => {
    try {
      await adminApi.changePassword(u.id, newPassword)
      setFlash({ kind: 'ok', msg: 'Contraseña reseteada correctamente' })
      setResetPasswordUser(null)
    } catch (err) {
      setFlash({ kind: 'err', msg: err instanceof AdminApiError ? err.message : 'Error reseteando contraseña' })
    }
  }

  return (
    <div className="space-y-6" onClick={() => setOpenMenuId(null)}>
      <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Usuarios</h1>
          <p className="text-sm text-gray-500 mt-1">
            Total: <strong>{total}</strong> · {counters.passenger} pasajeros ·{' '}
            {counters.dual} conductores · {counters.admin} admins
          </p>
        </div>
        <button
          onClick={() => setShowCreate(true)}
          className="inline-flex items-center gap-2 px-4 py-2 bg-orange-600 text-white rounded-lg hover:bg-orange-700 font-medium shadow-sm"
        >
          <Plus className="w-4 h-4" />
          Crear usuario
        </button>
      </div>

      {flash && (
        <div className={`p-3 rounded-lg border text-sm flex items-center gap-2 ${
          flash.kind === 'ok'
            ? 'bg-green-50 border-green-200 text-green-700'
            : 'bg-red-50 border-red-200 text-red-700'
        }`}>
          {flash.kind === 'ok' ? <CheckCircle2 className="w-4 h-4" /> : <AlertCircle className="w-4 h-4" />}
          {flash.msg}
        </div>
      )}

      <div className="bg-white rounded-xl border border-gray-200 p-4 flex flex-col md:flex-row gap-3">
        <div className="flex-1 relative">
          <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Buscar por nombre, correo, teléfono o ID..."
            className="w-full pl-10 pr-3 py-2 border border-gray-200 rounded-lg text-sm"
          />
        </div>
        <div className="flex gap-2">
          <select
            value={typeFilter}
            onChange={(e) => { setTypeFilter(e.target.value as UserTypeFilter); setPage(1) }}
            className="border border-gray-200 rounded-lg px-3 py-2 text-sm"
          >
            {USER_TYPE_OPTIONS.map((o) => (
              <option key={o.value} value={o.value}>{o.label}</option>
            ))}
          </select>
          <select
            value={statusFilter}
            onChange={(e) => { setStatusFilter(e.target.value as StatusFilter); setPage(1) }}
            className="border border-gray-200 rounded-lg px-3 py-2 text-sm"
          >
            <option value="active">Activos</option>
            <option value="suspended">Suspendidos</option>
            <option value="deleted">Eliminados</option>
            <option value="all">Todos</option>
          </select>
        </div>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        {loading ? (
          <div className="p-12 text-center text-gray-500 flex items-center justify-center gap-2">
            <Loader2 className="w-4 h-4 animate-spin" />
            Cargando...
          </div>
        ) : users.length === 0 ? (
          <div className="p-12 text-center text-gray-500">
            <UserIcon className="w-10 h-10 mx-auto mb-3 text-gray-300" />
            No se encontraron usuarios
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-gray-50 text-gray-500 text-xs uppercase">
                <tr>
                  <th className="text-left px-4 py-3">Usuario</th>
                  <th className="text-left px-4 py-3">Contacto</th>
                  <th className="text-left px-4 py-3">Tipo</th>
                  <th className="text-left px-4 py-3">Estado</th>
                  <th className="text-left px-4 py-3">Origen</th>
                  <th className="text-left px-4 py-3">Creado</th>
                  <th className="text-right px-4 py-3">Acciones</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {users.map((u) => (
                  <tr key={u.id} className="hover:bg-gray-50">
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-3">
                        <Avatar
                          name={u.fullName ?? u.email ?? undefined}
                          src={pickPhotoUrl(u.profilePhotoUrl)}
                        />
                        <div className="min-w-0">
                          <Link
                            to={`/users/${u.id}`}
                            className="font-medium text-gray-900 hover:text-orange-600 truncate block max-w-[220px]"
                          >
                            {u.fullName ?? '(sin nombre)'}
                          </Link>
                          <div className="text-xs text-gray-400 truncate max-w-[220px]">{u.id}</div>
                        </div>
                      </div>
                    </td>
                    <td className="px-4 py-3 text-gray-700">
                      {u.email && (
                        <div className="flex items-center gap-1 text-xs">
                          <Mail className="w-3 h-3 text-gray-400" />
                          <span className="truncate max-w-[200px]">{u.email}</span>
                        </div>
                      )}
                      {u.phone && (
                        <div className="flex items-center gap-1.5 text-xs flex-wrap">
                          <Phone className="w-3 h-3 text-gray-400 shrink-0" />
                          <span>{u.phone}</span>
                          {/* Ronda 283: si el número está verificado por SMS.
                              Va pegado al teléfono a propósito: en este panel
                              "Verificado" ya significa otra cosa —los
                              documentos del conductor— y una etiqueta suelta
                              en su propia columna se confundiría con aquella.
                              Aquí no hay duda de a qué se refiere. */}
                          {u.phoneVerified ? (
                            <span
                              title="Número verificado: esta persona recibió un código por SMS en este teléfono y lo introdujo."
                              className="inline-flex items-center gap-0.5 px-1.5 py-0.5 rounded-full bg-green-50 text-green-700 font-medium"
                            >
                              <CheckCircle2 className="w-3 h-3" /> SMS
                            </span>
                          ) : (
                            <span
                              title="Número sin verificar: nadie ha comprobado que este teléfono sea suyo. Es lo normal en cuentas creadas con Google o Apple, donde el número se escribe a mano."
                              className="inline-flex items-center gap-0.5 px-1.5 py-0.5 rounded-full bg-amber-50 text-amber-700 font-medium"
                            >
                              <AlertCircle className="w-3 h-3" /> sin verificar
                            </span>
                          )}
                        </div>
                      )}
                      {!u.email && !u.phone && <span className="text-xs text-gray-400">—</span>}
                    </td>
                    <td className="px-4 py-3">
                      <span
                        className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium ${
                          TYPE_BADGES[u.userType] ?? 'bg-gray-100 text-gray-700'
                        }`}
                      >
                        {u.userType === 'admin' && <ShieldCheck className="w-3 h-3" />}
                        {TYPE_LABEL[u.userType] ?? u.userType}
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      {u.deletedAt ? (
                        <span className="text-xs bg-gray-200 text-gray-700 px-2 py-0.5 rounded-full">Eliminado</span>
                      ) : u.suspendedAt ? (
                        <span className="text-xs bg-red-100 text-red-700 px-2 py-0.5 rounded-full">Suspendido</span>
                      ) : u.isActive ? (
                        <span className="text-xs bg-green-100 text-green-700 px-2 py-0.5 rounded-full">Activo</span>
                      ) : (
                        <span className="text-xs bg-gray-100 text-gray-500 px-2 py-0.5 rounded-full">Inactivo</span>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      <OriginBadgeUsers createdFrom={u.createdFrom} />
                    </td>
                    <td className="px-4 py-3 text-xs text-gray-500">
                      <DateTime value={u.createdAt} />
                    </td>
                    <td className="px-4 py-3 text-right relative">
                      <button
                        onClick={(e) => {
                          e.stopPropagation()
                          const boton = e.currentTarget
                          setOpenMenu((prev) =>
                            prev?.id === u.id ? null : { id: u.id, el: boton })
                        }}
                        className="p-1 hover:bg-gray-100 rounded"
                      >
                        <MoreVertical className="w-4 h-4 text-gray-500" />
                      </button>
                      {/* Ronda 283: en una capa fuera de la tabla. Dentro, el
                          `overflow` del contenedor lo recortaba y en las
                          últimas filas el menú salía cortado. */}
                      {openMenu?.id === u.id && (
                        <FloatingLayer
                          anchor={openMenu.el}
                          align="right"
                          onClose={() => setOpenMenu(null)}
                        >
                        <div
                          onClick={(e) => e.stopPropagation()}
                          className="bg-white border border-gray-200 rounded-lg shadow-lg py-1 min-w-[180px]"
                        >
                          <button
                            onClick={() => { setEditUser(u); setOpenMenuId(null) }}
                            className="w-full flex items-center gap-2 px-3 py-2 text-sm hover:bg-gray-50"
                          >
                            <Edit className="w-4 h-4" /> Ver / Editar
                          </button>
                          {!u.deletedAt && u.suspendedAt && (
                            <button
                              onClick={() => void handleReactivate(u)}
                              className="w-full flex items-center gap-2 px-3 py-2 text-sm hover:bg-gray-50 text-green-700"
                            >
                              <CheckCircle2 className="w-4 h-4" /> Reactivar
                            </button>
                          )}
                          {!u.deletedAt && !u.suspendedAt && (
                            <button
                              onClick={() => void handleSuspend(u)}
                              className="w-full flex items-center gap-2 px-3 py-2 text-sm hover:bg-gray-50 text-orange-700"
                            >
                              <Ban className="w-4 h-4" /> Suspender
                            </button>
                          )}
                          {!u.deletedAt && (u.email || u.userType === 'admin') && (
                            <button
                              onClick={() => handleResetPassword(u)}
                              className="w-full flex items-center gap-2 px-3 py-2 text-sm hover:bg-gray-50"
                            >
                              <KeyRound className="w-4 h-4" /> Resetear contraseña
                            </button>
                          )}
                          {!u.deletedAt && (
                            <button
                              onClick={() => void handleDelete(u)}
                              className="w-full flex items-center gap-2 px-3 py-2 text-sm hover:bg-red-50 text-red-600"
                            >
                              <Trash2 className="w-4 h-4" /> Eliminar
                            </button>
                          )}
                        </div>
                        </FloatingLayer>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {showCreate && (
        <CreateUserModal
          onClose={() => setShowCreate(false)}
          onCreated={() => {
            setShowCreate(false)
            setFlash({ kind: 'ok', msg: 'Usuario creado exitosamente' })
            void load()
          }}
        />
      )}

      {editUser && (
        <EditUserModal
          user={editUser}
          onClose={() => setEditUser(null)}
          onUpdated={() => {
            setEditUser(null)
            setFlash({ kind: 'ok', msg: 'Usuario actualizado' })
            void load()
          }}
        />
      )}

      {resetPasswordUser && (
        <ResetPasswordModal
          user={resetPasswordUser}
          onClose={() => setResetPasswordUser(null)}
          onSubmit={(pw) => submitResetPassword(resetPasswordUser, pw)}
        />
      )}
    </div>
  )
}

// ============================================================================
// Modal: Resetear contraseña (input type=password, no window.prompt)
// ============================================================================
function ResetPasswordModal({
  user, onClose, onSubmit,
}: { user: AdminUser; onClose: () => void; onSubmit: (pw: string) => Promise<void> }) {
  const [password, setPassword] = useState('')
  const [confirm, setConfirm] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const label = user.fullName ?? user.email ?? user.phone ?? user.id.slice(0, 8)

  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    setError(null)
    if (password.length < 8) return setError('Mínimo 8 caracteres')
    if (!/[A-Z]/.test(password) || !/[a-z]/.test(password) || !/\d/.test(password)) {
      return setError('Debe incluir mayúsculas, minúsculas y números')
    }
    if (password !== confirm) return setError('Las contraseñas no coinciden')
    setSubmitting(true)
    try {
      await onSubmit(password)
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div className="fixed inset-0 bg-black/60 z-[500] flex items-center justify-center p-4">
      {/* Ronda 283: mismo motivo que en el resto de modales — que pueda
          desplazarse si la ventana es baja. */}
      <div className="bg-white rounded-2xl w-full max-w-md shadow-2xl max-h-[90vh] overflow-y-auto">
        <div className="p-5 border-b flex items-center justify-between">
          <h3 className="text-lg font-semibold">Resetear contraseña</h3>
          <button type="button" onClick={onClose} className="text-gray-400 hover:text-gray-600">
            <X className="w-5 h-5" />
          </button>
        </div>
        <form onSubmit={handleSubmit} className="p-5 space-y-4">
          <p className="text-sm text-gray-600">
            Nueva contraseña para <strong>{label}</strong>. Se cerrarán todas sus sesiones activas.
          </p>
          <div>
            <label className="block text-xs font-medium text-gray-700 mb-1">Nueva contraseña</label>
            <input
              type={showPassword ? 'text' : 'password'}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm font-mono"
              autoComplete="new-password"
              autoFocus
              disabled={submitting}
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-700 mb-1">Confirmar contraseña</label>
            <input
              type={showPassword ? 'text' : 'password'}
              value={confirm}
              onChange={(e) => setConfirm(e.target.value)}
              className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm font-mono"
              autoComplete="new-password"
              disabled={submitting}
            />
          </div>
          <label className="flex items-center gap-2 text-xs text-gray-600">
            <input
              type="checkbox"
              checked={showPassword}
              onChange={(e) => setShowPassword(e.target.checked)}
            />
            Mostrar contraseñas
          </label>
          {error && <p className="text-xs text-red-600 bg-red-50 border border-red-200 rounded-lg p-2">{error}</p>}
          <div className="flex justify-end gap-2 pt-2">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 rounded-lg text-sm text-gray-700 hover:bg-gray-50"
              disabled={submitting}
            >
              Cancelar
            </button>
            <button
              type="submit"
              disabled={submitting}
              className="px-4 py-2 rounded-lg text-sm bg-[#E31E24] text-white hover:bg-[#B5181D] disabled:opacity-50"
            >
              {submitting ? 'Reseteando…' : 'Resetear'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

// ============================================================================
// Modal: Crear usuario
// ============================================================================
function CreateUserModal({
  onClose, onCreated,
}: { onClose: () => void; onCreated: () => void }) {
  const [userType, setUserType] = useState<'passenger' | 'dual' | 'admin'>('passenger')
  const [fullName, setFullName] = useState('')
  const [email, setEmail] = useState('')
  const [phone, setPhone] = useState('')
  const [isVerified, setIsVerified] = useState(false)
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError(null)

    if (!email && !phone) {
      setError('Debes ingresar al menos email o teléfono')
      return
    }

    const cleanPhone = phone.trim()
    const normalizedPhone = cleanPhone
      ? cleanPhone.startsWith('+') ? cleanPhone : `+51${cleanPhone.replace(/^\+?51/, '')}`
      : undefined

    setSubmitting(true)
    try {
      await adminApi.createUser({
        userType,
        fullName: fullName.trim() || undefined,
        email: email.trim().toLowerCase() || undefined,
        phone: normalizedPhone,
        isVerified,
      })
      onCreated()
    } catch (err) {
      setError(err instanceof AdminApiError ? err.message : 'Error creando usuario')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div
      className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4"
      onClick={onClose}
    >
      <div
        onClick={(e) => e.stopPropagation()}
        className="bg-white rounded-2xl shadow-xl max-w-lg w-full max-h-[90vh] overflow-y-auto"
      >
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-200">
          <h2 className="text-lg font-semibold text-gray-900">Crear nuevo usuario</h2>
          <button onClick={onClose} className="p-1 hover:bg-gray-100 rounded">
            <X className="w-5 h-5 text-gray-500" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Tipo de usuario</label>
            <div className="grid grid-cols-2 gap-2">
              {/* Ronda 282: sin 'driver'. La restricción de la base de datos
                  ya lo rechaza (migración 027), así que dejarlo aquí solo
                  servía para que el guardado fallara. */}
              {(['passenger', 'dual', 'admin'] as const).map((t) => (
                <button
                  key={t}
                  type="button"
                  onClick={() => setUserType(t)}
                  className={`px-3 py-2 rounded-lg text-sm border-2 transition ${
                    userType === t
                      ? 'border-orange-500 bg-orange-50 text-orange-700 font-medium'
                      : 'border-gray-200 text-gray-700 hover:border-gray-300'
                  }`}
                >
                  {TYPE_LABEL[t]}
                </button>
              ))}
            </div>
            <p className="text-xs text-gray-500 mt-1">
              {userType === 'dual' && '“Dual” puede actuar como pasajero y conductor.'}
              {userType === 'admin' && '“Admin” tiene acceso completo al panel.'}
            </p>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Nombre completo <span className="text-gray-400">(opcional)</span>
            </label>
            <input
              type="text"
              value={fullName}
              onChange={(e) => setFullName(e.target.value)}
              placeholder="Ej. Juan Pérez"
              className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Correo electrónico
            </label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="usuario@correo.com"
              className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Teléfono <span className="text-gray-400">(formato E.164 o 9 dígitos)</span>
            </label>
            <input
              type="tel"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              placeholder="+51999888777 o 999888777"
              className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm"
            />
            <p className="text-xs text-gray-500 mt-1">
              Debes ingresar al menos email o teléfono
            </p>
          </div>

          <label className="flex items-center gap-2 cursor-pointer">
            <input
              type="checkbox"
              checked={isVerified}
              onChange={(e) => setIsVerified(e.target.checked)}
              className="rounded border-gray-300"
            />
            <span className="text-sm text-gray-700">Marcar como verificado</span>
          </label>

          {error && (
            <div className="p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700 flex items-center gap-2">
              <AlertCircle className="w-4 h-4" /> {error}
            </div>
          )}

          <div className="flex gap-2 pt-4">
            <button
              type="button"
              onClick={onClose}
              disabled={submitting}
              className="flex-1 px-4 py-2 border border-gray-200 rounded-lg text-sm font-medium text-gray-700 hover:bg-gray-50"
            >
              Cancelar
            </button>
            <button
              type="submit"
              disabled={submitting}
              className="flex-1 px-4 py-2 bg-orange-600 text-white rounded-lg text-sm font-medium hover:bg-orange-700 disabled:opacity-60 flex items-center justify-center gap-2"
            >
              {submitting && <Loader2 className="w-4 h-4 animate-spin" />}
              Crear usuario
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

// ============================================================================
// Modal: Editar usuario
// ============================================================================
function EditUserModal({
  user, onClose, onUpdated,
}: { user: AdminUser; onClose: () => void; onUpdated: () => void }) {
  const [userType, setUserType] = useState<'passenger' | 'dual' | 'admin'>(user.userType)
  const [fullName, setFullName] = useState(user.fullName ?? '')
  const [email, setEmail] = useState(user.email ?? '')
  const [phone, setPhone] = useState(user.phone ?? '')
  const [isVerified, setIsVerified] = useState(user.isVerified)
  const [isAdmin, setIsAdmin] = useState(user.isAdmin)
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError(null)

    if (!email.trim() && !phone.trim()) {
      setError('Debes tener al menos email o teléfono')
      return
    }

    const normalizedPhone = phone.trim()
      ? phone.trim().startsWith('+') ? phone.trim() : `+51${phone.trim().replace(/^\+?51/, '')}`
      : null

    setSubmitting(true)
    try {
      await adminApi.updateUser(user.id, {
        userType,
        fullName: fullName.trim() || null,
        email: email.trim().toLowerCase() || null,
        phone: normalizedPhone,
        isVerified,
        isAdmin,
      } as Partial<AdminUser>)
      onUpdated()
    } catch (err) {
      setError(err instanceof AdminApiError ? err.message : 'Error actualizando usuario')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div
      className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4"
      onClick={onClose}
    >
      <div
        onClick={(e) => e.stopPropagation()}
        className="bg-white rounded-2xl shadow-xl max-w-lg w-full max-h-[90vh] overflow-y-auto"
      >
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-200">
          <div>
            <h2 className="text-lg font-semibold text-gray-900">Editar usuario</h2>
            <p className="text-xs text-gray-500 mt-0.5">{user.id}</p>
          </div>
          <button onClick={onClose} className="p-1 hover:bg-gray-100 rounded">
            <X className="w-5 h-5 text-gray-500" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Tipo de usuario</label>
            <div className="grid grid-cols-2 gap-2">
              {/* Ronda 282: sin 'driver'. La restricción de la base de datos
                  ya lo rechaza (migración 027), así que dejarlo aquí solo
                  servía para que el guardado fallara. */}
              {(['passenger', 'dual', 'admin'] as const).map((t) => (
                <button
                  key={t}
                  type="button"
                  onClick={() => setUserType(t)}
                  className={`px-3 py-2 rounded-lg text-sm border-2 transition ${
                    userType === t
                      ? 'border-orange-500 bg-orange-50 text-orange-700 font-medium'
                      : 'border-gray-200 text-gray-700 hover:border-gray-300'
                  }`}
                >
                  {TYPE_LABEL[t]}
                </button>
              ))}
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Nombre completo</label>
            <input
              type="text"
              value={fullName}
              onChange={(e) => setFullName(e.target.value)}
              className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Correo electrónico</label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Teléfono</label>
            <input
              type="tel"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm"
            />
          </div>

          <div className="space-y-2 pt-2 border-t border-gray-100">
            <label className="flex items-center gap-2 cursor-pointer">
              <input
                type="checkbox"
                checked={isVerified}
                onChange={(e) => setIsVerified(e.target.checked)}
                className="rounded border-gray-300"
              />
              <span className="text-sm text-gray-700">Verificado</span>
            </label>
            <label className="flex items-center gap-2 cursor-pointer">
              <input
                type="checkbox"
                checked={isAdmin}
                onChange={(e) => setIsAdmin(e.target.checked)}
                className="rounded border-gray-300"
              />
              <span className="text-sm text-gray-700">Admin (acceso al panel)</span>
            </label>
          </div>

          {error && (
            <div className="p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700 flex items-center gap-2">
              <AlertCircle className="w-4 h-4" /> {error}
            </div>
          )}

          <div className="flex gap-2 pt-4">
            <button
              type="button"
              onClick={onClose}
              disabled={submitting}
              className="flex-1 px-4 py-2 border border-gray-200 rounded-lg text-sm font-medium text-gray-700 hover:bg-gray-50"
            >
              Cancelar
            </button>
            <button
              type="submit"
              disabled={submitting}
              className="flex-1 px-4 py-2 bg-orange-600 text-white rounded-lg text-sm font-medium hover:bg-orange-700 disabled:opacity-60 flex items-center justify-center gap-2"
            >
              {submitting && <Loader2 className="w-4 h-4 animate-spin" />}
              Guardar cambios
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}


function OriginBadgeUsers({ createdFrom }: { createdFrom?: string }) {
  const meta: Record<string, { label: string; icon: string; cls: string }> = {
    mobile:        { label: 'App',    icon: '📱', cls: 'bg-blue-100 text-blue-800' },
    admin_panel:   { label: 'Panel',  icon: '🖥️', cls: 'bg-purple-100 text-purple-800' },
    oauth_google:  { label: 'Google', icon: '🔑', cls: 'bg-red-50 text-red-700' },
    oauth_apple:   { label: 'Apple',  icon: '', cls: 'bg-gray-100 text-gray-800' },
    import:        { label: 'Import', icon: '📥', cls: 'bg-amber-100 text-amber-800' },
    unknown:       { label: '?',      icon: '❔', cls: 'bg-gray-100 text-gray-500' },
  }
  const m = meta[createdFrom ?? 'unknown'] ?? meta.unknown
  return (
    <span title={`Registro creado desde: ${m.label}`} className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs ${m.cls}`}>
      {m.icon} {m.label}
    </span>
  )
}
