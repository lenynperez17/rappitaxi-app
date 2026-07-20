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
            <div className="mt-3 flex flex-wrap items-center gap-2">
              {user.isVerified ? (
                <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs bg-green-100 text-green-700">
                  <CheckCircle2 className="w-3 h-3" /> Verificado
                </span>
              ) : (
                <span className="px-2 py-0.5 rounded-full text-xs bg-yellow-100 text-yellow-700">Pendiente de verificación</span>
              )}
              <OriginBadge createdFrom={user.createdFrom} />
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

// Badge que indica el origen del registro del user.
function OriginBadge({ createdFrom }: { createdFrom?: string }) {
  const meta: Record<string, { label: string; cls: string; icon: string }> = {
    mobile:        { label: 'App móvil',     cls: 'bg-blue-100 text-blue-800',       icon: '📱' },
    admin_panel:   { label: 'Panel web',     cls: 'bg-purple-100 text-purple-800',   icon: '🖥️' },
    oauth_google:  { label: 'Google Sign-In', cls: 'bg-red-50 text-red-700',          icon: '🔑' },
    oauth_apple:   { label: 'Apple Sign-In',  cls: 'bg-gray-100 text-gray-800',       icon: '' },
    import:        { label: 'Importado',      cls: 'bg-amber-100 text-amber-800',     icon: '📥' },
    unknown:       { label: 'Origen desconocido', cls: 'bg-gray-100 text-gray-500',  icon: '❔' },
  }
  const m = meta[createdFrom ?? 'unknown'] ?? meta.unknown
  return (
    <span className={`px-2 py-0.5 rounded-full text-xs inline-flex items-center gap-1 ${m.cls}`} title={`Registro creado desde: ${m.label}`}>
      <span>{m.icon}</span> {m.label}
    </span>
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
  const [uploadingType, setUploadingType] = useState<string | null>(null)

  const uploadForType = async (docType: string, file: File) => {
    setUploadingType(docType)
    try {
      await adminApi.uploadDocumentForDriver(driverId, docType, file)
      onFlash(`Documento "${docType}" cargado. Ahora aparece como Pendiente.`)
      await load()
    } catch (e) {
      onError(e instanceof AdminApiError ? e.message : 'Error subiendo el archivo')
    } finally { setUploadingType(null) }
  }

  const onFilePick = (docType: string) => (e: React.ChangeEvent<HTMLInputElement>) => {
    const f = e.target.files?.[0]
    e.target.value = '' // permitir re-elegir el mismo archivo si se reintenta
    if (f) void uploadForType(docType, f)
  }

  const DOC_TYPES = [
    'dni_front', 'dni_back', 'license_front', 'license_back', 'soat',
    'tarjeta_propiedad', 'ownership', 'selfie', 'vehicle_photo',
  ] as const
  const missingTypes = DOC_TYPES.filter((t) => !docs.some((d) => d.docType === t))

  const openPreview = async (doc: { id: string; docType: string; fileUrl: string }) => {
    try {
      const blob = await adminApi.fetchMediaBlob(doc.fileUrl)
      const url = URL.createObjectURL(blob)
      setPreview({ url, docType: doc.docType, mime: blob.type || 'application/octet-stream' })
    } catch (e) {
      onError(e instanceof AdminApiError ? e.message : 'No se pudo cargar el documento')
    }
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
  const DOC_LABEL: Record<string, string> = {
    dni_front: 'DNI (frente)',
    dni_back: 'DNI (reverso)',
    license_front: 'Licencia de conducir (frente)',
    license_back: 'Licencia de conducir (reverso)',
    soat: 'SOAT vigente',
    tarjeta_propiedad: 'Tarjeta de propiedad (frente)',
    ownership: 'Tarjeta de propiedad (reverso)',
    selfie: 'Selfie del conductor',
    vehicle_photo: 'Foto del vehículo',
    other: 'Otro documento',
  }
  const docLabel = (t: string) => DOC_LABEL[t] ?? t.replace(/_/g, ' ')

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
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          {docs.map((d) => (
            <div key={d.id} className="border border-gray-200 rounded-lg p-3 flex flex-col gap-3">
              <div className="flex items-center gap-2 justify-between">
                <span className="text-sm text-gray-800 truncate font-medium">{docLabel(d.docType)}</span>
                <span className={`px-2 py-0.5 rounded-full text-xs font-medium flex-shrink-0 ${STATUS_BADGE[d.status] ?? ''}`}>
                  {STATUS_LABEL[d.status] ?? d.status}
                </span>
              </div>
              <DocThumbnail
                doc={d}
                onExpand={() => void openPreview(d)}
              />
              {d.rejectionReason && (
                <p className="text-xs text-red-600">Motivo: {d.rejectionReason}</p>
              )}
              <div className="flex gap-2">
                {d.status === 'pending' ? (
                  <>
                    <button
                      type="button"
                      onClick={() => void review(d.id, 'approved')}
                      disabled={reviewingId === d.id}
                      className="flex-1 px-3 py-1.5 text-xs bg-green-600 text-white rounded hover:bg-green-700 disabled:opacity-50 font-medium"
                    >
                      {reviewingId === d.id ? 'Procesando…' : 'Aprobar'}
                    </button>
                    <button
                      type="button"
                      onClick={() => void review(d.id, 'rejected')}
                      disabled={reviewingId === d.id}
                      className="flex-1 px-3 py-1.5 text-xs bg-red-600 text-white rounded hover:bg-red-700 disabled:opacity-50 font-medium"
                    >
                      Rechazar
                    </button>
                  </>
                ) : (
                  <span className="text-xs text-gray-500">Ya revisado</span>
                )}
                <label className="px-3 py-1.5 text-xs bg-gray-100 text-gray-700 rounded hover:bg-gray-200 cursor-pointer font-medium">
                  {uploadingType === d.docType ? 'Subiendo…' : 'Reemplazar'}
                  <input type="file" accept="image/*,application/pdf" className="hidden" onChange={onFilePick(d.docType)} disabled={uploadingType === d.docType} />
                </label>
              </div>
            </div>
          ))}
        </div>
      )}

      {missingTypes.length > 0 && (
        <div className="mt-4 border-t border-gray-200 pt-4">
          <p className="text-sm font-semibold text-gray-800 mb-2">Subir documentos faltantes</p>
          <p className="text-xs text-gray-500 mb-3">
            El driver aún no subió estos tipos. Puedes cargarlos desde acá — quedarán como <em>Pendiente</em> y podrás aprobarlos igual que los que sube el driver desde la app.
          </p>
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
            {missingTypes.map((t) => (
              <label
                key={t}
                className="flex flex-col items-center justify-center gap-1 p-3 border border-dashed border-gray-300 rounded-lg cursor-pointer hover:border-blue-400 hover:bg-blue-50 text-xs text-gray-700 text-center"
              >
                <span className="font-medium text-gray-800">{docLabel(t)}</span>
                <span className="text-gray-500">
                  {uploadingType === t ? 'Subiendo…' : '+ Elegir archivo'}
                </span>
                <input type="file" accept="image/*,application/pdf" className="hidden" onChange={onFilePick(t)} disabled={uploadingType === t} />
              </label>
            ))}
          </div>
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
              <h4 className="font-semibold text-gray-900 text-sm">{docLabel(preview.docType)}</h4>
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

// Miniatura autocargada. Al hacer click abre el modal grande.
function DocThumbnail({
  doc,
  onExpand,
}: {
  doc: { id: string; fileUrl: string; docType: string }
  onExpand: () => void
}) {
  const [state, setState] = useState<
    | { kind: 'loading' }
    | { kind: 'image'; url: string }
    | { kind: 'pdf'; url: string }
    | { kind: 'other'; mime: string }
    | { kind: 'error'; msg: string }
  >({ kind: 'loading' })

  useEffect(() => {
    let objectUrl: string | null = null
    let cancelled = false
    ;(async () => {
      try {
        const blob = await adminApi.fetchMediaBlob(doc.fileUrl)
        if (cancelled) return
        objectUrl = URL.createObjectURL(blob)
        const mime = blob.type || ''
        if (mime.startsWith('image/')) setState({ kind: 'image', url: objectUrl })
        else if (mime === 'application/pdf') setState({ kind: 'pdf', url: objectUrl })
        else setState({ kind: 'other', mime })
      } catch (e) {
        if (!cancelled) setState({ kind: 'error', msg: e instanceof AdminApiError ? e.message : 'error' })
      }
    })()
    return () => {
      cancelled = true
      if (objectUrl) URL.revokeObjectURL(objectUrl)
    }
  }, [doc.id, doc.fileUrl])

  const baseCls =
    'w-full h-56 rounded-md border border-gray-200 bg-gray-50 flex items-center justify-center overflow-hidden'

  if (state.kind === 'loading') {
    return (
      <div className={baseCls}>
        <Loader2 className="w-5 h-5 animate-spin text-gray-400" />
      </div>
    )
  }
  if (state.kind === 'error') {
    return <div className={`${baseCls} text-xs text-red-600 px-2 text-center`}>Error: {state.msg}</div>
  }
  if (state.kind === 'image') {
    return (
      <button
        type="button"
        onClick={onExpand}
        className={`${baseCls} cursor-zoom-in hover:border-blue-400 transition-colors p-0 group`}
        aria-label={`Ampliar ${doc.docType}`}
      >
        <img
          src={state.url}
          alt={doc.docType}
          className="w-full h-full object-contain group-hover:scale-105 transition-transform bg-gray-50"
        />
      </button>
    )
  }
  if (state.kind === 'pdf') {
    return (
      <button
        type="button"
        onClick={onExpand}
        className={`${baseCls} cursor-zoom-in hover:border-blue-400 flex-col text-xs text-gray-600 gap-1`}
      >
        <span className="text-3xl">📄</span>
        <span>PDF · click para ver</span>
      </button>
    )
  }
  return (
    <button
      type="button"
      onClick={onExpand}
      className={`${baseCls} cursor-pointer hover:border-blue-400 flex-col text-xs text-gray-500 gap-1`}
    >
      <span className="text-3xl">📎</span>
      <span>{state.mime || 'archivo'}</span>
    </button>
  )
}
