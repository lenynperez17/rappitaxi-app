import { useEffect, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { ArrowLeft, Loader2, Mail, Phone, Calendar, User as UserIcon, ShieldCheck, CheckCircle2, XCircle } from 'lucide-react'
import { adminApi, AdminApiError, type AdminUser } from '../../lib/adminApi'
import { Avatar, pickPhotoUrl } from '../../components/Avatar'
import { relativeTime, toDate } from '../../utils/timeFormat'

const TYPE_BADGES: Record<string, string> = {
  passenger: 'bg-blue-100 text-blue-700',
  driver: 'bg-orange-100 text-orange-700',
  dual: 'bg-purple-100 text-purple-700',
  admin: 'bg-red-100 text-red-700',
}
const TYPE_LABEL: Record<string, string> = { passenger: 'Pasajero', driver: 'Conductor', dual: 'Dual', admin: 'Admin' }

export function UserDetailPage() {
  const { userId } = useParams<{ userId: string }>()
  const [user, setUser] = useState<AdminUser | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!userId) return
    // Ronda 190 IDOR-UI: cancellation al cambiar userId. Antes: si el fetch
    // de user A resolvía DESPUÉS del de B (navegación rápida A→B), setUser
    // sobrescribía con datos de A → panel mostraba PII de A pero URL decía B.
    let cancelled = false
    setUser(null)
    setError(null)
    setLoading(true)
    void (async () => {
      try {
        const u = await adminApi.getUser(userId)
        if (!cancelled) setUser(u)
      } catch (err) {
        if (!cancelled) setError(err instanceof AdminApiError ? err.message : 'Error cargando usuario')
      } finally {
        if (!cancelled) setLoading(false)
      }
    })()
    return () => { cancelled = true }
  }, [userId])

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
          <div className="flex-1">
            <h1 className="text-2xl font-bold text-gray-900">{user.fullName ?? '(sin nombre)'}</h1>
            <p className="text-sm text-gray-500 mt-1"><code className="bg-gray-100 px-1 rounded">{user.id}</code></p>
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
          <Info icon={Calendar} label="Creado" value={relativeTime(toDate(user.createdAt))} />
          <Info icon={Calendar} label="Actualizado" value={relativeTime(toDate(user.updatedAt))} />
          {user.suspendedAt && (
            <div className="p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700">
              <strong>Suspendido:</strong> {user.suspendedReason ?? 'sin motivo'}
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
      <Icon className="w-4 h-4 text-gray-400" />
      <div className="flex-1">
        <div className="text-xs text-gray-500">{label}</div>
        <div className="font-medium text-gray-900 flex items-center gap-1">
          {value}
          {verified === true && <CheckCircle2 className="w-3 h-3 text-green-500" />}
          {verified === false && <XCircle className="w-3 h-3 text-gray-300" />}
        </div>
      </div>
    </div>
  )
}
