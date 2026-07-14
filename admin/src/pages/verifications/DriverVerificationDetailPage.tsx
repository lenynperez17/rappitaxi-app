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
          <h3 className="font-semibold text-gray-900">Marcar verificado manualmente</h3>
          <button
            onClick={() => void verify()}
            disabled={busy}
            className="inline-flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded-lg text-sm font-medium hover:bg-green-700 disabled:opacity-60"
          >
            {busy ? <Loader2 className="w-4 h-4 animate-spin" /> : <ShieldCheck className="w-4 h-4" />}
            Marcar como verificado
          </button>
          <p className="text-xs text-gray-500">
            Verificación manual sin revisión de documentos individuales.
          </p>
        </div>
      )}

      <DocumentsSection driverId={driverId!} onFlash={setFlash} onError={setActionError} />
    </div>
  )
}

// ============================================================================
// Sección de documentos del driver — lista + aprobar/rechazar
// ============================================================================
function DocumentsSection({ driverId, onFlash, onError }: {
  driverId: string; onFlash: (msg: string) => void; onError: (msg: string) => void
}) {
  const [docs, setDocs] = useState<Array<{ id: string; docType: string; fileUrl: string; status: string; rejectionReason: string | null; createdAt: string }>>([])
  const [loading, setLoading] = useState(true)
  const [reviewingId, setReviewingId] = useState<string | null>(null)

  const load = async () => {
    setLoading(true)
    try {
      const r = await adminApi.listDocuments({ driverId, status: 'all', pageSize: 50 })
      setDocs(r.documents)
    } catch (e) {
      onError(e instanceof AdminApiError ? e.message : 'Error cargando documentos')
    } finally { setLoading(false) }
  }

  useEffect(() => { void load(); /* eslint-disable-next-line react-hooks/exhaustive-deps */ }, [driverId])

  const review = async (id: string, status: 'approved' | 'rejected') => {
    if (reviewingId) return
    let rejectionReason: string | undefined
    if (status === 'rejected') {
      const r = window.prompt('Motivo del rechazo (obligatorio):')
      if (!r?.trim()) return
      rejectionReason = r.trim()
    }
    setReviewingId(id)
    try {
      const res = await adminApi.reviewDocument(id, { status, rejectionReason })
      onFlash(status === 'approved'
        ? `Documento aprobado${res.driverVerified ? '. Driver verificado automáticamente.' : ''}`
        : 'Documento rechazado')
      await load()
    } catch (e) {
      onError(e instanceof AdminApiError ? e.message : 'Error revisando documento')
    } finally { setReviewingId(null) }
  }

  const STATUS_BADGE: Record<string, string> = {
    pending: 'bg-yellow-100 text-yellow-700',
    approved: 'bg-green-100 text-green-700',
    rejected: 'bg-red-100 text-red-700',
    expired: 'bg-gray-100 text-gray-700',
  }
  const STATUS_LABEL: Record<string, string> = {
    pending: 'Pendiente', approved: 'Aprobado', rejected: 'Rechazado', expired: 'Expirado',
  }

  return (
    <div className="bg-white rounded-xl border border-gray-200 p-6 space-y-4">
      <div className="flex items-center justify-between">
        <h3 className="font-semibold text-gray-900">Documentos ({docs.length})</h3>
        <button type="button" onClick={() => void load()} className="text-xs text-gray-600 hover:text-gray-900">
          Recargar
        </button>
      </div>
      {loading ? (
        <div className="flex items-center gap-2 text-sm text-gray-500">
          <Loader2 className="w-4 h-4 animate-spin" /> Cargando documentos…
        </div>
      ) : docs.length === 0 ? (
        <p className="text-sm text-gray-500">Este conductor aún no ha subido documentos.</p>
      ) : (
        <div className="space-y-2">
          {docs.map((d) => (
            <div key={d.id} className="border border-gray-200 rounded-lg p-3 flex items-center justify-between gap-3">
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-2">
                  <span className="font-mono text-xs text-gray-600">{d.docType}</span>
                  <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${STATUS_BADGE[d.status] ?? ''}`}>
                    {STATUS_LABEL[d.status] ?? d.status}
                  </span>
                </div>
                {d.rejectionReason && (
                  <p className="text-xs text-red-600 mt-1">Motivo: {d.rejectionReason}</p>
                )}
                <a href={d.fileUrl} target="_blank" rel="noreferrer" className="text-xs text-blue-600 hover:underline">Ver archivo</a>
              </div>
              {d.status === 'pending' && (
                <div className="flex gap-1 flex-shrink-0">
                  <button
                    type="button"
                    onClick={() => void review(d.id, 'approved')}
                    disabled={reviewingId === d.id}
                    className="px-2 py-1 text-xs bg-green-600 text-white rounded hover:bg-green-700 disabled:opacity-50"
                  >
                    {reviewingId === d.id ? '…' : 'Aprobar'}
                  </button>
                  <button
                    type="button"
                    onClick={() => void review(d.id, 'rejected')}
                    disabled={reviewingId === d.id}
                    className="px-2 py-1 text-xs bg-red-600 text-white rounded hover:bg-red-700 disabled:opacity-50"
                  >
                    Rechazar
                  </button>
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
