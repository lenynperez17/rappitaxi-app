import { useEffect, useRef, useState } from 'react'
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
  // Ronda 165: useRef síncrono cierra la ventana de race entre onClick y el
  // re-render de setBusy(true) — dos taps rápidos evitan doble PATCH →
  // dobles push, doble audit log, dobles side-effects (bonos, credit seed).
  const busyRef = useRef(false)

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
    if (!driverId || busyRef.current) return
    busyRef.current = true
    setBusy(true)
    try {
      const updated = await adminApi.updateUser(driverId, { isVerified: true })
      setUser(updated); setFlash('Conductor verificado exitosamente'); setActionError(null)
    } catch (err) {
      // NO usamos setError(): eso descartaría la vista completa. En su lugar,
      // mostramos el error en un banner sin bloquear el resto del contenido.
      setActionError(err instanceof AdminApiError ? err.message : 'Error verificando')
    } finally {
      busyRef.current = false
      setBusy(false)
    }
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
  // Ronda 165: ref síncrono cierra ventana de race que setReviewingId(id)
  // (asíncrono via React state) deja abierta entre onClick y re-render.
  const reviewingRef = useRef<string | null>(null)
  const [preview, setPreview] = useState<{ url: string; docType: string; mime: string } | null>(null)
  const [previewLoadingId, setPreviewLoadingId] = useState<string | null>(null)

  const openPreview = async (doc: { id: string; docType: string; fileUrl: string }) => {
    setPreviewLoadingId(doc.id)
    try {
      const blob = await adminApi.fetchMediaBlob(doc.fileUrl)
      const url = URL.createObjectURL(blob)
      setPreview({ url, docType: doc.docType, mime: blob.type || 'application/octet-stream' })
    } catch (e) {
      onError(e instanceof AdminApiError ? e.message : 'No se pudo cargar el documento')
    } finally { setPreviewLoadingId(null) }
  }

  const closePreview = () => {
    if (preview) URL.revokeObjectURL(preview.url)
    setPreview(null)
  }

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
    if (reviewingRef.current) return
    let rejectionReason: string | undefined
    if (status === 'rejected') {
      const r = window.prompt('Motivo del rechazo (obligatorio):')
      if (!r?.trim()) return
      rejectionReason = r.trim()
    }
    reviewingRef.current = id
    setReviewingId(id)
    try {
      const res = await adminApi.reviewDocument(id, { status, rejectionReason })
      onFlash(status === 'approved'
        ? `Documento aprobado${res.driverVerified ? '. Driver verificado automáticamente.' : ''}`
        : 'Documento rechazado')
      await load()
    } catch (e) {
      onError(e instanceof AdminApiError ? e.message : 'Error revisando documento')
    } finally {
      reviewingRef.current = null
      setReviewingId(null)
    }
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
                <button
                  type="button"
                  onClick={() => void openPreview(d)}
                  disabled={previewLoadingId === d.id}
                  className="text-xs text-blue-600 hover:underline disabled:opacity-50"
                >
                  {previewLoadingId === d.id ? 'Cargando…' : 'Ver archivo'}
                </button>
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

      {preview && (
        <div
          className="fixed inset-0 z-50 bg-black/80 flex items-center justify-center p-4"
          onClick={closePreview}
          role="dialog"
          aria-modal="true"
        >
          <div
            className="bg-white rounded-xl max-w-4xl w-full max-h-[90vh] overflow-hidden flex flex-col"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between p-4 border-b border-gray-200">
              <h4 className="font-semibold text-gray-900 font-mono text-sm">{preview.docType}</h4>
              <div className="flex items-center gap-2">
                <a
                  href={preview.url}
                  download={`${preview.docType}.${preview.mime.includes('pdf') ? 'pdf' : 'jpg'}`}
                  className="text-xs px-3 py-1.5 bg-gray-100 text-gray-700 rounded hover:bg-gray-200"
                >
                  Descargar
                </a>
                <button
                  type="button"
                  onClick={closePreview}
                  className="text-xs px-3 py-1.5 bg-gray-100 text-gray-700 rounded hover:bg-gray-200"
                >
                  Cerrar
                </button>
              </div>
            </div>
            <div className="flex-1 overflow-auto bg-gray-100 flex items-center justify-center p-4">
              {preview.mime.startsWith('image/') ? (
                <img src={preview.url} alt={preview.docType} className="max-w-full max-h-full object-contain" />
              ) : preview.mime === 'application/pdf' ? (
                <iframe src={preview.url} title={preview.docType} className="w-full h-[70vh] border-0" />
              ) : (
                <div className="text-center text-sm text-gray-600">
                  <p>Vista previa no disponible para este tipo de archivo ({preview.mime}).</p>
                  <a href={preview.url} download className="text-blue-600 hover:underline mt-2 inline-block">
                    Descargar archivo
                  </a>
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
