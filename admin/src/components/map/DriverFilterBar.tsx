import { Filter, Calendar } from 'lucide-react'
import { useState } from 'react'

export type DriverFilterMode = 'online_now' | 'today' | 'week' | 'month' | 'custom'

export interface DriverFilterValue {
  mode: DriverFilterMode
  customFrom?: Date | null
}

interface DriverFilterBarProps {
  value: DriverFilterValue
  onChange: (val: DriverFilterValue) => void
  onlineCount: number
  ghostCount: number
  offlineCount: number
}

const PRESET_OPTIONS: Array<{ value: DriverFilterMode; label: string }> = [
  { value: 'online_now', label: 'Solo online ahora' },
  { value: 'today', label: 'Activos hoy (24h)' },
  { value: 'week', label: 'Última semana (7d)' },
  { value: 'month', label: 'Último mes (30d)' },
  { value: 'custom', label: 'Personalizado…' },
]

export function DriverFilterBar({
  value,
  onChange,
  onlineCount,
  ghostCount,
  offlineCount,
}: DriverFilterBarProps) {
  const [showCustom, setShowCustom] = useState(value.mode === 'custom')

  const handleModeChange = (mode: DriverFilterMode) => {
    setShowCustom(mode === 'custom')
    onChange({ mode, customFrom: mode === 'custom' ? value.customFrom ?? null : null })
  }

  return (
    <div className="flex flex-wrap items-center gap-3 text-sm">
      <div className="flex items-center gap-2 text-gray-700">
        <Filter className="w-4 h-4 text-gray-500" />
        <span className="font-medium">Filtrar:</span>
      </div>

      <select
        value={value.mode}
        onChange={(e) => handleModeChange(e.target.value as DriverFilterMode)}
        className="px-3 py-1.5 border border-gray-300 rounded-lg bg-white text-sm focus:outline-none focus:ring-2 focus:ring-[#E31E24]"
      >
        {PRESET_OPTIONS.map((opt) => (
          <option key={opt.value} value={opt.value}>
            {opt.label}
          </option>
        ))}
      </select>

      {showCustom && (
        <div className="flex items-center gap-2 text-gray-700">
          <Calendar className="w-4 h-4 text-gray-500" />
          <span className="text-xs">Desde:</span>
          <input
            type="datetime-local"
            value={value.customFrom ? toLocalInput(value.customFrom) : ''}
            onChange={(e) =>
              onChange({
                mode: 'custom',
                customFrom: e.target.value ? new Date(e.target.value) : null,
              })
            }
            className="px-2 py-1 border border-gray-300 rounded text-xs"
          />
        </div>
      )}

      <div className="ml-auto flex items-center gap-3 text-xs">
        <Badge color="#10B981" label="online" count={onlineCount} />
        <Badge color="#F59E0B" label="fantasma" count={ghostCount} />
        <Badge color="#9CA3AF" label="offline" count={offlineCount} />
      </div>
    </div>
  )
}

function Badge({ color, label, count }: { color: string; label: string; count: number }) {
  return (
    <span className="flex items-center gap-1 text-gray-700">
      <span
        className="inline-block w-2.5 h-2.5 rounded-full"
        style={{ backgroundColor: color }}
      />
      <strong>{count}</strong>
      <span className="text-gray-500">{label}</span>
    </span>
  )
}

function toLocalInput(d: Date): string {
  const pad = (n: number) => n.toString().padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
}

/**
 * Returns the cutoff Date for filtering drivers' lastSeen.
 * Drivers with lastSeen >= cutoff are included.
 */
export function getCutoffDate(filter: DriverFilterValue): Date | null {
  const now = Date.now()
  switch (filter.mode) {
    case 'online_now':
      // Only consider drivers seen in the last 5 minutes (heartbeat window)
      return new Date(now - 5 * 60_000)
    case 'today':
      return new Date(now - 24 * 60 * 60_000)
    case 'week':
      return new Date(now - 7 * 24 * 60 * 60_000)
    case 'month':
      return new Date(now - 30 * 24 * 60 * 60_000)
    case 'custom':
      return filter.customFrom ?? null
    default:
      return null
  }
}
