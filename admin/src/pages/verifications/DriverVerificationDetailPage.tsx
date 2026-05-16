import { useEffect, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { doc, getDoc, collection, getDocs } from 'firebase/firestore'
import { httpsCallable } from 'firebase/functions'
import { db, functions } from '../../config/firebase'
import {
  ArrowLeft, Loader2, CheckCircle2, XCircle, FileText, Image as ImageIcon,
  ExternalLink, ShieldCheck, AlertCircle, Phone, Mail, Car,
} from 'lucide-react'
import {
  EXPECTED_DOCUMENTS,
  type DriverForVerification,
  type DriverDocument,
} from '../../types/driverDocument'

interface DocsMap {
  [docId: string]: DriverDocument
}

export function DriverVerificationDetailPage() {
  const { driverId } = useParams<{ driverId: string }>()
  const [driver, setDriver] = useState<DriverForVerification | null>(null)
  const [docs, setDocs] = useState<DocsMap>({})
  const [loading, setLoading] = useState(true)
  const [acting, setActing] = useState(false)
  const [feedback, setFeedback] = useState<{ kind: 'ok' | 'err'; msg: string } | null>(null)

  useEffect(() => {
    if (!driverId) return
    void load()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [driverId])

  const load = async () => {
    setLoading(true)
    try {
      // Load user
      const userSnap = await getDoc(doc(db, 'users', driverId!))
      if (userSnap.exists()) {
        setDriver({ id: userSnap.id, ...(userSnap.data() as any) })
      }

      // Load all documents under drivers/{driverId}/documents/
      const docsSnap = await getDocs(collection(db, 'drivers', driverId!, 'documents'))
      const map: DocsMap = {}
      docsSnap.docs.forEach((d) => {
        map[d.id] = { id: d.id, ...(d.data() as any) } as DriverDocument
      })
      setDocs(map)
    } catch (err) {
      console.error('Load detail error:', err)
    } finally {
      setLoading(false)
    }
  }

  const handleApproveDriver = async () => {
    if (!driverId) return
    // Verificar que todos los docs requeridos estén aprobados
    const missing = EXPECTED_DOCUMENTS.filter((expected) => {
      if (!expected.isRequired) return false
      const d = docs[expected.id]
      return !d || d.status !== 'approved'
    })
    if (missing.length > 0) {
      setFeedback({
        kind: 'err',
        msg: `Faltan documentos por aprobar: ${missing.map((m) => m.name).join(', ')}`,
      })
      return
    }
    if (!confirm(`¿Aprobar al conductor ${driver?.fullName || driver?.name}? Recibirá una notificación y podrá empezar a aceptar viajes.`)) {
      return
    }
    setActing(true)
    setFeedback(null)
    try {
      const fn = httpsCallable<{ driverId: string }, { ok: boolean }>(functions, 'approveDriver')
      await fn({ driverId })
      setFeedback({ kind: 'ok', msg: 'Conductor aprobado y notificado correctamente.' })
      await load()
    } catch (err: any) {
      console.error(err)
      setFeedback({ kind: 'err', msg: err?.message || 'Error al aprobar conductor' })
    } finally {
      setActing(false)
    }
  }

  const handleApproveDoc = async (docId: string) => {
    if (!driverId) return
    setActing(true)
    setFeedback(null)
    try {
      const fn = httpsCallable<{ driverId: string; docId: string }, { ok: boolean }>(functions, 'approveDriverDocument')
      await fn({ driverId, docId })
      setFeedback({ kind: 'ok', msg: 'Documento aprobado' })
      await load()
    } catch (err: any) {
      setFeedback({ kind: 'err', msg: err?.message || 'Error' })
    } finally {
      setActing(false)
    }
  }

  const handleRejectDoc = async (docId: string, docName: string) => {
    if (!driverId) return
    const reason = prompt(`Motivo del rechazo de "${docName}":\n(El conductor recibirá este mensaje en su app)`)
    if (!reason || !reason.trim()) return
    setActing(true)
    setFeedback(null)
    try {
      const fn = httpsCallable<{ driverId: string; docId: string; reason: string }, { ok: boolean }>(functions, 'rejectDriverDocument')
      await fn({ driverId, docId, reason: reason.trim() })
      setFeedback({ kind: 'ok', msg: 'Documento rechazado. Conductor notificado.' })
      await load()
    } catch (err: any) {
      setFeedback({ kind: 'err', msg: err?.message || 'Error' })
    } finally {
      setActing(false)
    }
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <Loader2 className="w-8 h-8 text-[#E31E24] animate-spin" />
      </div>
    )
  }

  if (!driver) {
    return (
      <div className="bg-white rounded-xl border border-gray-200 p-8 text-center">
        <p className="text-gray-500">Conductor no encontrado.</p>
        <Link to="/verifications" className="text-[#E31E24] hover:underline mt-2 inline-block">
          Volver
        </Link>
      </div>
    )
  }

  const requiredApproved = EXPECTED_DOCUMENTS.filter((e) => e.isRequired)
    .every((e) => docs[e.id]?.status === 'approved')
  const isAlreadyApproved = driver.driverStatus === 'approved' && driver.documentVerified === true

  return (
    <div className="space-y-6">
      <Link to="/verifications" className="inline-flex items-center gap-2 text-sm text-gray-500 hover:text-gray-900">
        <ArrowLeft className="w-4 h-4" /> Volver a verificaciones
      </Link>

      {/* Cabecera */}
      <div className="bg-white rounded-xl border border-gray-200 p-6">
        <div className="flex items-start justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">{driver.fullName || driver.name || 'Sin nombre'}</h1>
            <div className="mt-2 space-y-1 text-sm text-gray-600">
              {driver.email && <p className="flex items-center gap-1"><Mail className="w-3.5 h-3.5" /> {driver.email}</p>}
              {(driver.phone || driver.phoneNumber) && (
                <p className="flex items-center gap-1"><Phone className="w-3.5 h-3.5" /> {driver.phone || driver.phoneNumber}</p>
              )}
              {driver.driverProfile?.documentNumber && (
                <p className="text-xs text-gray-500">DNI: {driver.driverProfile.documentNumber}</p>
              )}
              {driver.vehicleInfo?.make && (
                <p className="flex items-center gap-1 text-xs text-gray-500">
                  <Car className="w-3.5 h-3.5" />
                  {driver.vehicleInfo.make} {driver.vehicleInfo.model} {driver.vehicleInfo.year} · placa {driver.vehicleInfo.plate}
                </p>
              )}
            </div>
          </div>
          <div className="text-right">
            <p className="text-xs text-gray-500 uppercase">Estado actual</p>
            <p className="text-lg font-bold text-gray-900 capitalize">{driver.driverStatus ?? 'sin datos'}</p>
            {isAlreadyApproved && (
              <span className="inline-flex items-center gap-1 text-xs text-green-700 mt-1">
                <CheckCircle2 className="w-3 h-3" /> Cuenta activa
              </span>
            )}
          </div>
        </div>
      </div>

      {/* Feedback */}
      {feedback && (
        <div
          className={`rounded-xl border p-4 flex items-start gap-3 ${
            feedback.kind === 'ok' ? 'bg-emerald-50 border-emerald-200 text-emerald-800' : 'bg-red-50 border-red-200 text-red-800'
          }`}
        >
          {feedback.kind === 'ok' ? <CheckCircle2 className="w-5 h-5 mt-0.5" /> : <AlertCircle className="w-5 h-5 mt-0.5" />}
          <p className="text-sm">{feedback.msg}</p>
        </div>
      )}

      {/* Documents grid */}
      <div className="bg-white rounded-xl border border-gray-200 p-6">
        <h2 className="text-sm font-semibold text-gray-900 mb-4 flex items-center gap-2">
          <FileText className="w-4 h-4" /> Documentos del conductor ({Object.values(docs).filter((d) => d.status === 'approved').length}/{EXPECTED_DOCUMENTS.length})
        </h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {EXPECTED_DOCUMENTS.map((expected) => {
            const d = docs[expected.id]
            return (
              <DocumentCard
                key={expected.id}
                expected={expected}
                doc={d}
                acting={acting}
                onApprove={() => handleApproveDoc(expected.id)}
                onReject={() => handleRejectDoc(expected.id, expected.name)}
              />
            )
          })}
        </div>
      </div>

      {/* Aprobar conductor global */}
      <div className="bg-white rounded-xl border border-gray-200 p-6">
        <div className="flex items-center justify-between gap-4 flex-wrap">
          <div>
            <h2 className="text-base font-semibold text-gray-900">
              {isAlreadyApproved ? '✅ Conductor ya aprobado' : 'Aprobar conductor'}
            </h2>
            <p className="text-sm text-gray-500 mt-1">
              {isAlreadyApproved
                ? 'Esta cuenta ya está activa. Si necesitas revocar, debes hacerlo desde Firestore manualmente.'
                : requiredApproved
                ? 'Todos los documentos requeridos están aprobados. Puedes aprobar la cuenta.'
                : 'Aprueba primero todos los documentos requeridos para habilitar este botón.'}
            </p>
          </div>
          <button
            onClick={handleApproveDriver}
            disabled={acting || isAlreadyApproved || !requiredApproved}
            className="flex items-center gap-2 px-5 py-2.5 bg-green-600 hover:bg-green-700 text-white rounded-lg font-medium disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {acting ? <Loader2 className="w-4 h-4 animate-spin" /> : <ShieldCheck className="w-4 h-4" />}
            Aprobar y activar
          </button>
        </div>
      </div>
    </div>
  )
}

function DocumentCard({
  expected,
  doc,
  acting,
  onApprove,
  onReject,
}: {
  expected: { id: string; name: string; description: string; isRequired: boolean }
  doc: DriverDocument | undefined
  acting: boolean
  onApprove: () => void
  onReject: () => void
}) {
  const status = doc?.status ?? 'missing'
  const hasFile = !!doc?.fileUrl

  const isPdf = doc?.fileUrl?.toLowerCase().includes('.pdf') || doc?.fileUrl?.toLowerCase().includes('pdf')

  const statusStyles: Record<string, { bg: string; label: string }> = {
    approved: { bg: 'bg-green-100 text-green-700', label: 'Aprobado' },
    pending: { bg: 'bg-yellow-100 text-yellow-700', label: 'Pendiente revisión' },
    rejected: { bg: 'bg-red-100 text-red-700', label: 'Rechazado' },
    expired: { bg: 'bg-amber-100 text-amber-700', label: 'Vencido' },
    missing: { bg: 'bg-gray-100 text-gray-500', label: 'No subido' },
  }
  const cfg = statusStyles[status] ?? statusStyles.missing

  return (
    <div className="border border-gray-200 rounded-lg p-4 space-y-3">
      <div className="flex items-start justify-between">
        <div>
          <p className="font-medium text-gray-900 text-sm">
            {expected.name}
            {expected.isRequired ? (
              <span className="ml-1 text-red-500">*</span>
            ) : (
              <span className="ml-1 text-xs text-gray-400">(opcional)</span>
            )}
          </p>
          <p className="text-xs text-gray-500 mt-0.5">{expected.description}</p>
        </div>
        <span className={`text-xs px-2 py-0.5 rounded font-medium whitespace-nowrap ${cfg.bg}`}>{cfg.label}</span>
      </div>

      {hasFile ? (
        <div className="border border-gray-200 rounded-lg bg-gray-50 overflow-hidden">
          {isPdf ? (
            <a
              href={doc!.fileUrl!}
              target="_blank"
              rel="noreferrer"
              className="flex items-center justify-center gap-2 py-8 text-blue-600 hover:underline text-sm"
            >
              <FileText className="w-5 h-5" /> Ver PDF
            </a>
          ) : (
            <a href={doc!.fileUrl!} target="_blank" rel="noreferrer" className="block">
              <img
                src={doc!.fileUrl!}
                alt={expected.name}
                className="w-full h-40 object-cover hover:opacity-90 transition-opacity"
              />
            </a>
          )}
          <div className="px-3 py-2 flex items-center justify-between text-xs text-gray-500 border-t border-gray-200">
            <span className="flex items-center gap-1">
              {isPdf ? <FileText className="w-3 h-3" /> : <ImageIcon className="w-3 h-3" />}
              {doc?.uploadDate?.toDate?.().toLocaleDateString('es-PE') ?? '—'}
            </span>
            <a href={doc!.fileUrl!} target="_blank" rel="noreferrer" className="text-blue-600 hover:underline flex items-center gap-1">
              Abrir <ExternalLink className="w-3 h-3" />
            </a>
          </div>
        </div>
      ) : (
        <div className="border border-dashed border-gray-300 rounded-lg p-6 text-center text-xs text-gray-400">
          El conductor aún no subió este documento
        </div>
      )}

      {doc?.rejectionReason && status === 'rejected' && (
        <div className="bg-red-50 border border-red-200 rounded-lg p-2 text-xs text-red-700">
          <strong>Motivo:</strong> {doc.rejectionReason}
        </div>
      )}

      {hasFile && status !== 'approved' && (
        <div className="flex gap-2">
          <button
            onClick={onApprove}
            disabled={acting}
            className="flex-1 px-3 py-1.5 bg-green-600 hover:bg-green-700 text-white text-xs font-medium rounded disabled:opacity-50 flex items-center justify-center gap-1"
          >
            <CheckCircle2 className="w-3.5 h-3.5" /> Aprobar
          </button>
          <button
            onClick={onReject}
            disabled={acting}
            className="flex-1 px-3 py-1.5 bg-red-600 hover:bg-red-700 text-white text-xs font-medium rounded disabled:opacity-50 flex items-center justify-center gap-1"
          >
            <XCircle className="w-3.5 h-3.5" /> Rechazar
          </button>
        </div>
      )}

      {status === 'approved' && (
        <button
          onClick={onReject}
          disabled={acting}
          className="w-full px-3 py-1.5 bg-white border border-red-300 hover:bg-red-50 text-red-700 text-xs font-medium rounded disabled:opacity-50"
        >
          Revertir (rechazar)
        </button>
      )}
    </div>
  )
}
