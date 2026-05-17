import { useEffect, useMemo, useState } from 'react'
import { useParams, Link, useNavigate } from 'react-router-dom'
import {
  doc,
  getDoc,
  collection,
  query,
  where,
  orderBy,
  limit,
  getDocs,
} from 'firebase/firestore'
import { httpsCallable } from 'firebase/functions'
import { db, functions } from '../../config/firebase'
import { formatPEN } from '../../utils/currency'
import { relativeTime, toDate } from '../../utils/timeFormat'
import {
  ArrowLeft,
  Loader2,
  Phone,
  Mail,
  Shield,
  Power,
  KeyRound,
  AlertCircle,
  CheckCircle2,
  Copy,
} from 'lucide-react'
import { Avatar, pickPhotoUrl } from '../../components/Avatar'

type Tab = 'info' | 'rides' | 'recharges' | 'wallet' | 'documents'

export function UserDetailPage() {
  const { userId } = useParams<{ userId: string }>()
  const navigate = useNavigate()
  const [tab, setTab] = useState<Tab>('info')
  const [user, setUser] = useState<any | null>(null)
  const [loading, setLoading] = useState(true)
  const [actionState, setActionState] = useState<{
    busy: boolean
    error: string | null
    success: string | null
    resetLink?: string | null
  }>({ busy: false, error: null, success: null })

  useEffect(() => {
    if (!userId) return
    void loadUser()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [userId])

  const loadUser = async () => {
    if (!userId) return
    setLoading(true)
    try {
      const snap = await getDoc(doc(db, 'users', userId))
      if (!snap.exists()) {
        setUser(null)
      } else {
        setUser({ id: snap.id, ...snap.data() })
      }
    } finally {
      setLoading(false)
    }
  }

  const isDriver = user?.userType === 'driver' || user?.userType === 'dual'
  const isSuspended = user?.isActive === false

  const callAdmin = async (
    fnName: 'suspendUser' | 'reactivateUser' | 'sendPasswordResetForUser',
    payload: Record<string, any>,
  ): Promise<any> => {
    setActionState({ busy: true, error: null, success: null })
    try {
      const fn = httpsCallable(functions, fnName)
      const res = await fn(payload)
      return res.data
    } catch (err: any) {
      setActionState({ busy: false, error: err?.message ?? 'Error', success: null })
      throw err
    }
  }

  const handleSuspend = async () => {
    if (!userId) return
    const reason = window.prompt('Razón de suspensión:')
    if (!reason?.trim()) return
    try {
      await callAdmin('suspendUser', { userId, reason: reason.trim() })
      setActionState({ busy: false, error: null, success: 'Usuario suspendido' })
      await loadUser()
    } catch {/* state set by callAdmin */}
  }

  const handleReactivate = async () => {
    if (!userId) return
    if (!confirm('¿Reactivar este usuario?')) return
    try {
      await callAdmin('reactivateUser', { userId })
      setActionState({ busy: false, error: null, success: 'Usuario reactivado' })
      await loadUser()
    } catch {/* state set by callAdmin */}
  }

  const handlePasswordReset = async () => {
    if (!userId) return
    try {
      const data = (await callAdmin('sendPasswordResetForUser', { userId })) as {
        ok: boolean
        email: string
        link: string
      }
      setActionState({
        busy: false,
        error: null,
        success: `Link generado para ${data.email}`,
        resetLink: data.link,
      })
    } catch {/* state set by callAdmin */}
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center py-16">
        <Loader2 className="w-6 h-6 animate-spin text-[#E31E24]" />
      </div>
    )
  }
  if (!user) {
    return (
      <div className="text-center py-16">
        <p className="text-gray-500">Usuario no encontrado</p>
        <button onClick={() => navigate(-1)} className="mt-3 text-[#E31E24] text-sm hover:underline">
          Volver
        </button>
      </div>
    )
  }

  const fullName = user.fullName || user.name || '(sin nombre)'
  const createdAt = toDate(user.createdAt)

  return (
    <div className="space-y-5">
      {/* Back link */}
      <button onClick={() => navigate(-1)} className="flex items-center gap-1 text-sm text-gray-600 hover:text-gray-900">
        <ArrowLeft className="w-4 h-4" /> Volver
      </button>

      {/* Header card */}
      <div className="bg-white rounded-xl border border-gray-200 p-5">
        <div className="flex items-start justify-between gap-4 flex-wrap">
          <div className="flex items-center gap-4">
            <Avatar src={pickPhotoUrl(user)} name={fullName} size="xl" />
            <div>
              <h1 className="text-xl font-bold text-gray-900">{fullName}</h1>
              <div className="mt-1 flex items-center gap-2 flex-wrap text-sm text-gray-600">
                {user.email && (
                  <span className="flex items-center gap-1"><Mail className="w-3.5 h-3.5" /> {user.email}</span>
                )}
                {(user.phone || user.phoneNumber) && (
                  <a href={`tel:${user.phone ?? user.phoneNumber}`} className="flex items-center gap-1 text-blue-600 hover:underline">
                    <Phone className="w-3.5 h-3.5" /> {user.phone ?? user.phoneNumber}
                  </a>
                )}
              </div>
              <div className="mt-2 flex items-center gap-2 flex-wrap">
                <Badge label={user.userType ?? '—'} color="gray" />
                {isDriver && user.driverStatus && (
                  <Badge label={user.driverStatus} color={user.driverStatus === 'approved' ? 'green' : 'yellow'} />
                )}
                {isSuspended ? (
                  <Badge label="Suspendido" color="red" />
                ) : (
                  <Badge label="Activo" color="green" />
                )}
                {createdAt && (
                  <span className="text-xs text-gray-500">Registrado {createdAt.toLocaleDateString('es-PE')}</span>
                )}
              </div>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <button
              onClick={handlePasswordReset}
              disabled={actionState.busy}
              className="flex items-center gap-1.5 text-xs px-3 py-1.5 border border-gray-300 rounded-lg hover:bg-gray-50 disabled:opacity-50"
            >
              <KeyRound className="w-3.5 h-3.5" /> Resetear contraseña
            </button>
            {isSuspended ? (
              <button
                onClick={handleReactivate}
                disabled={actionState.busy}
                className="flex items-center gap-1.5 text-xs px-3 py-1.5 bg-green-600 hover:bg-green-700 text-white rounded-lg disabled:opacity-50"
              >
                <Power className="w-3.5 h-3.5" /> Reactivar
              </button>
            ) : (
              <button
                onClick={handleSuspend}
                disabled={actionState.busy}
                className="flex items-center gap-1.5 text-xs px-3 py-1.5 bg-red-600 hover:bg-red-700 text-white rounded-lg disabled:opacity-50"
              >
                <Shield className="w-3.5 h-3.5" /> Suspender
              </button>
            )}
          </div>
        </div>

        {actionState.error && (
          <div className="mt-3 bg-red-50 border border-red-200 rounded-lg p-2.5 flex items-start gap-2 text-xs text-red-700">
            <AlertCircle className="w-4 h-4 mt-0.5 flex-shrink-0" />
            <span>{actionState.error}</span>
          </div>
        )}
        {actionState.success && (
          <div className="mt-3 bg-green-50 border border-green-200 rounded-lg p-2.5 flex items-start gap-2 text-xs text-green-700">
            <CheckCircle2 className="w-4 h-4 mt-0.5 flex-shrink-0" />
            <div className="flex-1">
              <p>{actionState.success}</p>
              {actionState.resetLink && (
                <div className="mt-2 flex items-center gap-2 bg-white border border-green-200 rounded p-2">
                  <code className="text-[10px] flex-1 truncate text-gray-700">{actionState.resetLink}</code>
                  <button
                    onClick={() => {
                      navigator.clipboard.writeText(actionState.resetLink!)
                    }}
                    title="Copiar"
                    className="text-green-700 hover:text-green-900"
                  >
                    <Copy className="w-3.5 h-3.5" />
                  </button>
                </div>
              )}
            </div>
          </div>
        )}
      </div>

      {/* Tabs */}
      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        <div className="border-b border-gray-200 px-4 flex gap-1 overflow-x-auto">
          <TabButton active={tab === 'info'} onClick={() => setTab('info')}>Info</TabButton>
          <TabButton active={tab === 'rides'} onClick={() => setTab('rides')}>Viajes</TabButton>
          {isDriver && <TabButton active={tab === 'recharges'} onClick={() => setTab('recharges')}>Recargas</TabButton>}
          {isDriver && <TabButton active={tab === 'wallet'} onClick={() => setTab('wallet')}>Wallet</TabButton>}
          {isDriver && <TabButton active={tab === 'documents'} onClick={() => setTab('documents')}>Documentos</TabButton>}
        </div>

        <div className="p-4">
          {tab === 'info' && <InfoTab user={user} />}
          {tab === 'rides' && <RidesTab userId={user.id} />}
          {tab === 'recharges' && isDriver && <RechargesTab driverId={user.id} />}
          {tab === 'wallet' && isDriver && <WalletTab driverId={user.id} />}
          {tab === 'documents' && isDriver && (
            <div className="text-sm">
              <Link
                to={`/verifications/${user.id}`}
                className="inline-flex items-center gap-1 text-[#E31E24] hover:underline"
              >
                Ver documentos en /verifications →
              </Link>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

// ============================================================
// Tab: Info
// ============================================================
function InfoTab({ user }: { user: any }) {
  const fields: Array<[string, any]> = [
    ['ID', user.id],
    ['Nombre completo', user.fullName ?? user.name ?? '—'],
    ['Email', user.email ?? '—'],
    ['Teléfono', user.phone ?? user.phoneNumber ?? '—'],
    ['Tipo de usuario', user.userType ?? '—'],
    ['Estado driver', user.driverStatus ?? '—'],
    ['Activo', user.isActive === false ? 'No' : 'Sí'],
    ['Online', user.isOnline ? 'Sí' : 'No'],
    ['Última conexión', relativeTime(toDate(user.lastSeen))],
    ['Rating', user.rating?.toFixed(1) ?? '—'],
    ['Total viajes', user.totalTrips ?? 0],
    ['Documento', `${user.documentType ?? ''} ${user.documentNumber ?? ''}`.trim() || '—'],
    ['Dirección fiscal', user.fiscalAddress ?? '—'],
    ['Suspendido por', user.suspendedReason ?? '—'],
  ]

  return (
    <dl className="grid grid-cols-1 md:grid-cols-2 gap-x-6 gap-y-2 text-sm">
      {fields.map(([label, value]) => (
        <div key={label} className="flex flex-col py-1.5 border-b border-gray-100">
          <dt className="text-xs text-gray-500">{label}</dt>
          <dd className="text-gray-900 font-medium break-words">{String(value)}</dd>
        </div>
      ))}
    </dl>
  )
}

// ============================================================
// Tab: Rides
// ============================================================
function RidesTab({ userId }: { userId: string }) {
  const [rides, setRides] = useState<any[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    void load()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [userId])

  const load = async () => {
    setLoading(true)
    try {
      // Query both as passenger and as driver in parallel
      const [asPassenger, asDriver] = await Promise.all([
        getDocs(query(collection(db, 'rides'), where('passengerId', '==', userId), orderBy('createdAt', 'desc'), limit(50))),
        getDocs(query(collection(db, 'rides'), where('driverId', '==', userId), orderBy('createdAt', 'desc'), limit(50))),
      ])
      const all: any[] = [
        ...asPassenger.docs.map((d) => ({ id: d.id, role: 'passenger', ...d.data() })),
        ...asDriver.docs.map((d) => ({ id: d.id, role: 'driver', ...d.data() })),
      ]
      all.sort((a: any, b: any) => {
        const da = toDate(a.createdAt)?.getTime() ?? 0
        const db_ = toDate(b.createdAt)?.getTime() ?? 0
        return db_ - da
      })
      setRides(all.slice(0, 50))
    } finally {
      setLoading(false)
    }
  }

  if (loading) return <div className="text-center py-6 text-gray-400 text-sm">Cargando...</div>
  if (rides.length === 0) return <div className="text-center py-6 text-gray-400 text-sm">Sin viajes</div>

  return (
    <table className="w-full text-sm">
      <thead className="text-xs text-gray-500">
        <tr>
          <th className="text-left py-1.5">Fecha</th>
          <th className="text-left">Rol</th>
          <th className="text-left">Estado</th>
          <th className="text-left">Origen → Destino</th>
          <th className="text-right">Tarifa</th>
        </tr>
      </thead>
      <tbody className="divide-y divide-gray-100">
        {rides.map((r) => {
          const date = toDate(r.createdAt)
          return (
            <tr key={r.id} className="hover:bg-gray-50">
              <td className="py-2 text-gray-700 whitespace-nowrap">{date?.toLocaleDateString('es-PE') ?? '—'}</td>
              <td className="text-gray-700">{r.role}</td>
              <td>
                <span className="text-xs px-2 py-0.5 rounded bg-gray-100 text-gray-700">{r.status ?? '—'}</span>
              </td>
              <td className="text-gray-700 max-w-xs truncate">
                {(r.pickupAddress ?? r.pickup?.address) ?? '—'} → {(r.destinationAddress ?? r.destination?.address) ?? '—'}
              </td>
              <td className="text-right text-gray-900 font-medium">
                {formatPEN(r.finalFare ?? r.estimatedFare ?? 0)}
              </td>
            </tr>
          )
        })}
      </tbody>
    </table>
  )
}

// ============================================================
// Tab: Recharges
// ============================================================
function RechargesTab({ driverId }: { driverId: string }) {
  const [items, setItems] = useState<any[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    void load()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [driverId])

  const load = async () => {
    setLoading(true)
    try {
      const snap = await getDocs(
        query(collection(db, 'driverRecharges'), where('driverId', '==', driverId), orderBy('createdAt', 'desc'), limit(50)),
      )
      setItems(snap.docs.map((d) => ({ id: d.id, ...d.data() })))
    } finally {
      setLoading(false)
    }
  }

  if (loading) return <div className="text-center py-6 text-gray-400 text-sm">Cargando...</div>
  if (items.length === 0) return <div className="text-center py-6 text-gray-400 text-sm">Sin recargas</div>

  return (
    <table className="w-full text-sm">
      <thead className="text-xs text-gray-500">
        <tr>
          <th className="text-left py-1.5">Fecha</th>
          <th className="text-left">Método</th>
          <th className="text-left">Estado</th>
          <th className="text-right">Bruto</th>
          <th className="text-right">Neto</th>
        </tr>
      </thead>
      <tbody className="divide-y divide-gray-100">
        {items.map((r) => {
          const date = toDate(r.createdAt)
          return (
            <tr key={r.id}>
              <td className="py-2 whitespace-nowrap">{date?.toLocaleDateString('es-PE') ?? '—'}</td>
              <td className="text-gray-700">{r.paymentMethod ?? '—'}</td>
              <td>
                <span className="text-xs px-2 py-0.5 rounded bg-gray-100 text-gray-700">{r.status ?? '—'}</span>
              </td>
              <td className="text-right text-gray-700">{formatPEN(r.grossAmount ?? 0)}</td>
              <td className="text-right text-gray-900 font-medium">{formatPEN(r.netAmount ?? 0)}</td>
            </tr>
          )
        })}
      </tbody>
    </table>
  )
}

// ============================================================
// Tab: Wallet
// ============================================================
function WalletTab({ driverId }: { driverId: string }) {
  const [wallet, setWallet] = useState<any | null>(null)
  const [txns, setTxns] = useState<any[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    void load()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [driverId])

  const load = async () => {
    setLoading(true)
    try {
      const [walletSnap, txnsSnap] = await Promise.all([
        getDoc(doc(db, 'wallets', driverId)),
        getDocs(
          query(
            collection(db, 'walletTransactions'),
            where('walletId', '==', driverId),
            orderBy('createdAt', 'desc'),
            limit(20),
          ),
        ),
      ])
      setWallet(walletSnap.exists() ? { id: walletSnap.id, ...walletSnap.data() } : null)
      setTxns(txnsSnap.docs.map((d) => ({ id: d.id, ...d.data() })))
    } finally {
      setLoading(false)
    }
  }

  const totalIn = useMemo(
    () => txns.filter((t) => Number(t.amount) > 0).reduce((sum, t) => sum + Number(t.amount), 0),
    [txns],
  )

  if (loading) return <div className="text-center py-6 text-gray-400 text-sm">Cargando...</div>

  return (
    <div className="space-y-4">
      <div className="grid grid-cols-3 gap-3">
        <SummaryCard label="Balance actual" value={formatPEN(wallet?.balance ?? 0)} accent="text-green-700" />
        <SummaryCard label="Total ganancias" value={formatPEN(wallet?.totalEarnings ?? 0)} />
        <SummaryCard label="Últimas entradas" value={formatPEN(totalIn)} />
      </div>

      {txns.length === 0 ? (
        <div className="text-center py-6 text-gray-400 text-sm">Sin transacciones</div>
      ) : (
        <table className="w-full text-sm">
          <thead className="text-xs text-gray-500">
            <tr>
              <th className="text-left py-1.5">Fecha</th>
              <th className="text-left">Tipo</th>
              <th className="text-left">Descripción</th>
              <th className="text-right">Monto</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {txns.map((t) => {
              const date = toDate(t.createdAt)
              const amount = Number(t.amount ?? 0)
              return (
                <tr key={t.id}>
                  <td className="py-2 whitespace-nowrap">{date?.toLocaleString('es-PE') ?? '—'}</td>
                  <td className="text-gray-700">{t.type ?? '—'}</td>
                  <td className="text-gray-700">{t.description ?? '—'}</td>
                  <td className={`text-right font-medium ${amount >= 0 ? 'text-green-700' : 'text-red-700'}`}>
                    {amount >= 0 ? '+' : ''}
                    {formatPEN(amount)}
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
      )}
    </div>
  )
}

// ============================================================
// Reusable UI
// ============================================================
function TabButton({
  active,
  onClick,
  children,
}: {
  active: boolean
  onClick: () => void
  children: React.ReactNode
}) {
  return (
    <button
      onClick={onClick}
      className={`px-4 py-2.5 text-sm font-medium border-b-2 -mb-px ${
        active ? 'border-[#E31E24] text-[#E31E24]' : 'border-transparent text-gray-600 hover:text-gray-900'
      }`}
    >
      {children}
    </button>
  )
}

function Badge({ label, color }: { label: string; color: 'green' | 'red' | 'yellow' | 'gray' }) {
  const colors: Record<string, string> = {
    green: 'bg-green-100 text-green-700',
    red: 'bg-red-100 text-red-700',
    yellow: 'bg-yellow-100 text-yellow-700',
    gray: 'bg-gray-100 text-gray-700',
  }
  return <span className={`text-xs px-2 py-0.5 rounded ${colors[color]}`}>{label}</span>
}

function SummaryCard({ label, value, accent }: { label: string; value: string; accent?: string }) {
  return (
    <div className="bg-gray-50 border border-gray-200 rounded-lg p-3">
      <p className="text-[11px] text-gray-500">{label}</p>
      <p className={`text-lg font-bold mt-0.5 ${accent ?? 'text-gray-900'}`}>{value}</p>
    </div>
  )
}
