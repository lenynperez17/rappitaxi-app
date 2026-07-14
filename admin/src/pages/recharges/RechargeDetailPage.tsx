import { Link, useParams } from 'react-router-dom'
import { ArrowLeft, CreditCard } from 'lucide-react'

export function RechargeDetailPage() {
  const { rechargeId } = useParams<{ rechargeId: string }>()
  return (
    <div className="space-y-6">
      <Link to="/recharges" className="inline-flex items-center gap-2 text-sm text-gray-600 hover:text-gray-900">
        <ArrowLeft className="w-4 h-4" /> Volver a recargas
      </Link>
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Detalle recarga</h1>
        <p className="text-sm text-gray-500 mt-1">ID: <code className="bg-gray-100 px-1 rounded">{rechargeId}</code></p>
      </div>
      <div className="bg-white rounded-xl border border-gray-200 p-8 text-center text-gray-500">
        <CreditCard className="w-10 h-10 mx-auto mb-3 text-gray-300" />
        Vista de detalle pendiente de migración. Usa la lista de recargas por ahora.
      </div>
    </div>
  )
}
