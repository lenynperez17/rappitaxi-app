import { useParams, Link } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { ArrowLeft, Loader2, Mail, Phone, Calendar, User as UserIcon, ShieldCheck, CheckCircle2, XCircle } from 'lucide-react'
import { adminApi, AdminApiError } from '../../lib/adminApi'
import { queryKeys } from '../../lib/queryKeys'
import { Avatar } from '../../components/Avatar'
import { pickPhotoUrl } from '../../lib/photoUrl'
import { formatDateTime } from '../../utils/timeFormat'
import { DateTime } from '../../components/DateTime'

/**
 * Ronda 283: mismos colores que en la lista de usuarios, para que la misma
 * persona no cambie de color según la pantalla. Sin 'driver', que ya no existe.
 */
const TYPE_BADGES: Record<string, string> = {
  passenger: 'bg-blue-100 text-blue-700',
  dual: 'bg-orange-100 text-orange-700',
  admin: 'bg-red-100 text-red-700',
}
/** Ronda 283: sin "Dual" (jerga) ni "driver" (ya no existe). Ver `UsersPage`. */
const TYPE_LABEL: Record<string, string> = {
  passenger: 'Pasajero',
  dual: 'Conductor y pasajero',
  admin: 'Admin',
}

export function UserDetailPage() {
  const { userId } = useParams<{ userId: string }>()
  // Ronda 190 IDOR-UI: navegar rápido A→B no puede enseñar los datos de A con
  // la URL de B. Antes lo evitaba un flag `cancelled`; ahora cada usuario tiene
  // su propia clave de caché y la respuesta de A nunca llega a la vista de B.
  const userQuery = useQuery({
    queryKey: queryKeys.users.detail(userId ?? ''),
    queryFn: () => adminApi.getUser(userId!),
    enabled: !!userId,
  })
  const user = userQuery.data ?? null
  const loading = userQuery.isPending
  const error = userQuery.isError
    ? (userQuery.error instanceof AdminApiError ? userQuery.error.message : 'Error cargando usuario')
    : null

  if (loading) return (
    <div className="flex items-center justify-center h-64 text-gray-500">
      <Loader2 className="w-5 h-5 animate-spin mr-2" /> Cargando...
    </div>
  )
  if (error || !user) return (
    <div className="space-y-4">
      <Link to="/users" className="inline-flex items-center gap-2 text-sm text-gray-600 hover:text-gray-900">
        <ArrowLeft className="w-4 h-4" /> Volver a usuarios
      </Link>
      <div className="p-4 rounded-lg bg-red-50 border border-red-200 text-sm text-red-700">
        {error ?? 'Usuario no encontrado'}
      </div>
    </div>
  )

  return (
    <div className="space-y-6">
      <Link to="/users" className="inline-flex items-center gap-2 text-sm text-gray-600 hover:text-gray-900">
        <ArrowLeft className="w-4 h-4" /> Volver a usuarios
      </Link>

      <div className="bg-white rounded-2xl border border-gray-200 p-6">
        <div className="flex items-start gap-4">
          <Avatar name={user.fullName ?? user.email ?? undefined} src={pickPhotoUrl(user.profilePhotoUrl)} size="xl" />
          {/* Ronda 283: `min-w-0`. Un hijo de un flex no encoge por debajo del
              ancho de su contenido salvo que se le diga, así que un ID largo
              ensanchaba la tarjeta y desbordaba en pantallas estrechas. El ID
              se parte en varias líneas en vez de recortarse: recortado no se
              podría copiar, que es para lo único que está ahí. */}
          <div className="flex-1 min-w-0">
            <h1 className="text-2xl font-bold text-gray-900 break-words">{user.fullName ?? '(sin nombre)'}</h1>
            <p className="text-sm text-gray-500 mt-1">
              <code className="bg-gray-100 px-1 rounded break-all">{user.id}</code>
            </p>
            <div className="mt-3 flex flex-wrap items-center gap-2">
              <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium ${TYPE_BADGES[user.userType] ?? 'bg-gray-100 text-gray-700'}`}>
                {user.userType === 'admin' && <ShieldCheck className="w-3 h-3" />}
                {TYPE_LABEL[user.userType] ?? user.userType}
              </span>
              {user.deletedAt ? (
                <span className="px-2 py-0.5 rounded-full text-xs bg-gray-200 text-gray-700">Eliminado</span>
              ) : user.suspendedAt ? (
                <span className="px-2 py-0.5 rounded-full text-xs bg-red-100 text-red-700">Suspendido</span>
              ) : (
                <span className="px-2 py-0.5 rounded-full text-xs bg-green-100 text-green-700">Activo</span>
              )}
              {user.isVerified && (
                <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs bg-blue-100 text-blue-700">
                  <CheckCircle2 className="w-3 h-3" /> Verificado
                </span>
              )}
            </div>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <Section title="Contacto">
          <Info icon={Mail} label="Email" value={user.email ?? '—'} verified={user.emailVerified} />
          <Info icon={Phone} label="Teléfono" value={user.phone ?? '—'} verified={user.phoneVerified} />
        </Section>

        <Section title="Cuenta">
          <Info icon={UserIcon} label="Provider" value={user.authProvider ?? 'phone'} />
          {/* `Info` recibe texto, así que aquí se formatea directamente en vez
              de usar <DateTime>. Mismo formato dd/MM/yyyy HH:mm. */}
          <Info icon={Calendar} label="Creado" value={formatDateTime(user.createdAt)} />
          <Info icon={Calendar} label="Actualizado" value={formatDateTime(user.updatedAt)} />
          {user.suspendedAt && (
            <div className="p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700">
              <strong>Suspendido:</strong> {user.suspendedReason ?? 'sin motivo'}
              {/* Ronda 273: decía el motivo pero no cuándo. Para saber si una
                  suspensión es de hoy o de hace tres meses hacía falta la BD. */}
              <div className="text-xs text-red-600 mt-1">
                El <DateTime value={user.suspendedAt} />
              </div>
            </div>
          )}
        </Section>
      </div>

      <p className="text-xs text-gray-500 text-center">
        Para editar este usuario, ve a la lista de usuarios y usa el menú de acciones.
      </p>
    </div>
  )
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="bg-white rounded-xl border border-gray-200 p-6 space-y-3">
      <h3 className="font-semibold text-gray-900">{title}</h3>
      {children}
    </div>
  )
}

function Info({ icon: Icon, label, value, verified }: { icon: React.ElementType; label: string; value: string; verified?: boolean }) {
  return (
    <div className="flex items-center gap-3 text-sm">
      <Icon className="w-4 h-4 text-gray-400 shrink-0" />
      {/* Ronda 283: ver la nota de la cabecera — sin `min-w-0` un correo largo
          desbordaba la ficha en lugar de recortarse. */}
      <div className="flex-1 min-w-0">
        <div className="text-xs text-gray-500">{label}</div>
        <div className="font-medium text-gray-900 flex items-center gap-1">
          <span className="truncate" title={value}>{value}</span>
          {verified === true && <CheckCircle2 className="w-3 h-3 text-green-500" />}
          {verified === false && <XCircle className="w-3 h-3 text-gray-300" />}
        </div>
      </div>
    </div>
  )
}
