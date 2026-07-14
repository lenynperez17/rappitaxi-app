import { Construction } from 'lucide-react'

export function OrderPanel() {
  return (
    <div className="p-8 text-center text-gray-500 bg-white rounded-xl border border-gray-200">
      <Construction className="w-10 h-10 mx-auto mb-3 text-orange-500" />
      <p className="text-sm">
        Panel de asignación manual en migración al backend Node.
      </p>
    </div>
  )
}
