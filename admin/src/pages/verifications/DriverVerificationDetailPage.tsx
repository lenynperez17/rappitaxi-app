import { useEffect, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { ArrowLeft, Loader2, ShieldCheck, AlertCircle, CheckCircle2 } from 'lucide-react'
import { adminApi, AdminApiError, type AdminUser } from '../../lib/adminApi'
import { Avatar, pickPhotoUrl } from '../../components/Avatar'

export function DriverVerificationDetailPage() {
  const { driverId } = useParams<{ driverId: string }>()
  const [user, setUser] = useState<AdminUser | null>(null)
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(false)
  // Distinguimos entre "error del fetch inicial" (que sí bloquea la vista) y
  // "error de acción" (mostrar banner pero mantener el detalle visible).
  const [error, setError] = useState<string | null>(null)
  const [actionError, setActionError] = useState<string | null>(null)
  const [flash, setFlash] = useState<string | null>(null)

  useEffect(() => {
    if (!driverId) return
    // Reset explícito al cambiar driverId — evita mostrar datos del anterior
    // durante el fetch (stale data flash).
    setUser(null)
    setError(null)
    setFlash(null)
    void (async () => {
      setLoading(true)
      try { setUser(await adminApi.getUser(driverId)) }
      catch (err) { setError(err instanceof AdminApiError ? err.message : 'Error') }
      finally { setLoading(false) }
    })()
  }, [driverId])

  // Auto-clear del banner de éxito tras 4 segundos.
  useEffect(() => {
    if (!flash) return
    const t = setTimeout(() => setFlash(null), 4000)
    return () => clearTimeout(t)
  }, [flash])

  const verify = async () => {
    if (!driverId) return
    setBusy(true)
    try {
      const updated = await adminApi.updateUser(driverId, { isVerified: true })
      setUser(updated); setFlash('Conductor verificado exitosamente'); setActionError(null)
    } catch (err) {
      // NO usamos setError(): eso descartaría la vista completa. En su lugar,
      // mostramos el error en un banner sin bloquear el resto del contenido.
      setActionError(err instanceof AdminApiError ? err.message : 'Error verificando')
    } finally { setBusy(false) }
  }

  if (loading) return (
    <div className="flex items-center justify-center h-64 text-gray-500">
      <Loader2 className="w-5 h-5 animate-spin mr-2" /> Cargando...
    </div>
  )

  if (error || !user) return (
    <div className="space-y-4">
      <Link to="/verifications" className="inline-flex items-center gap-2 text-sm text-gray-600 hover:text-gray-900">
        <ArrowLeft className="w-4 h-4" /> Volver
      </Link>
      <div className="p-4 rounded-lg bg-red-50 border border-red-200 text-sm text-red-700 flex items-center gap-2">
        <AlertCircle className="w-4 h-4" /> {error ?? 'Conductor no encontrado'}
      </div>
    </div>
  )

  return (
    <div className="space-y-6">
      <Link to="/verifications" className="inline-flex items-center gap-2 text-sm text-gray-600 hover:text-gray-900">
        <ArrowLeft className="w-4 h-4" /> Volver a verificaciones
      </Link>

      {flash && (
        <div className="p-3 rounded-lg bg-green-50 border border-green-200 text-sm text-green-700 flex items-center gap-2">
          <CheckCircle2 className="w-4 h-4" /> {flash}
        </div>
      )}

      {actionError && (
        <div className="p-3 rounded-lg bg-red-50 border border-red-200 text-sm text-red-700 flex items-center justify-between gap-2">
          <span className="flex items-center gap-2"><AlertCircle className="w-4 h-4" /> {actionError}</span>
          <button type="button" onClick={() => setActionError(null)} className="text-red-600 hover:text-red-800 text-xs">Cerrar</button>
        </div>
      )}

      <div className="bg-white rounded-2xl border border-gray-200 p-6">
        <div className="flex items-start gap-4">
          <Avatar name={user.fullName ?? undefined} src={pickPhotoUrl(user.profilePhotoUrl)} size="xl" />
          <div className="flex-1">
            <h1 className="text-2xl font-bold text-gray-900">{user.fullName ?? '(sin nombre)'}</h1>
            <p className="text-sm text-gray-500 mt-1">{user.email ?? user.phone ?? user.id}</p>
            <div className="mt-3">
              {user.isVerified ? (
                <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs bg-green-100 text-green-700">
                  <CheckCircle2 className="w-3 h-3" /> Verificado
                </span>
              ) : (
                <span className="px-2 py-0.5 rounded-full text-xs bg-yellow-100 text-yellow-700">Pendiente de verificación</span>
              )}
            </div>
          </div>
        </div>
      </div>

      {!user.isVerified && (
        <div className="bg-white rounded-xl border border-gray-200 p-6 space-y-4">
          <h3 className="font-semibold text-gray-900">Acciones</h3>
          <button
            onClick={() => void verify()}
            disabled={busy}
            className="inline-flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded-lg text-sm font-medium hover:bg-green-700 disabled:opacity-60"
          >
            {busy ? <Loader2 className="w-4 h-4 animate-spin" /> : <ShieldCheck className="w-4 h-4" />}
            Marcar como verificado
          </button>
          <p className="text-xs text-gray-500">
            La gestión de documentos (foto de licencia, brevete, SOAT, tarjeta de propiedad) se mueve a Storage local del backend Node y se implementará en la próxima release.
          </p>
        </div>
      )}
    </div>
  )
}
