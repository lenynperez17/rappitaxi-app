import { useState } from 'react'

interface AvatarProps {
  src?: string | null
  name?: string | null
  size?: 'xs' | 'sm' | 'md' | 'lg' | 'xl'
  className?: string
}

const SIZE_CLASSES: Record<NonNullable<AvatarProps['size']>, string> = {
  xs: 'w-6 h-6 text-[10px]',
  sm: 'w-8 h-8 text-xs',
  md: 'w-10 h-10 text-sm',
  lg: 'w-12 h-12 text-base',
  xl: 'w-16 h-16 text-xl',
}

const COLOR_PALETTE = [
  '#EF4444', '#F97316', '#F59E0B', '#EAB308',
  '#84CC16', '#22C55E', '#10B981', '#14B8A6',
  '#06B6D4', '#3B82F6', '#6366F1', '#8B5CF6',
  '#A855F7', '#D946EF', '#EC4899', '#F43F5E',
]

function colorFromName(name: string): string {
  let hash = 0
  for (let i = 0; i < name.length; i++) {
    hash = (hash << 5) - hash + name.charCodeAt(i)
    hash |= 0
  }
  return COLOR_PALETTE[Math.abs(hash) % COLOR_PALETTE.length]
}

function initialsOf(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean)
  if (parts.length === 0) return '?'
  if (parts.length === 1) return parts[0]!.slice(0, 2).toUpperCase()
  return (parts[0]![0]! + parts[1]![0]!).toUpperCase()
}

/**
 * Renders a user avatar. If `src` is a valid URL it shows the image and
 * falls back to colored initials on load error. Otherwise it shows colored
 * initials directly. The background color is deterministically derived
 * from the user's name so it stays stable across renders.
 */
export function Avatar({ src, name, size = 'md', className = '' }: AvatarProps) {
  const [broken, setBroken] = useState(false)
  const safeName = (name ?? '').trim() || '?'
  const initials = initialsOf(safeName)
  const color = colorFromName(safeName)
  const hasValidSrc = !!src && !broken && typeof src === 'string' && src.startsWith('http')

  return (
    <div
      className={`${SIZE_CLASSES[size]} rounded-full overflow-hidden flex items-center justify-center font-semibold text-white shrink-0 ${className}`}
      style={hasValidSrc ? undefined : { backgroundColor: color }}
      title={safeName}
    >
      {hasValidSrc ? (
        <img
          src={src!}
          alt={safeName}
          className="w-full h-full object-cover"
          onError={() => setBroken(true)}
          loading="lazy"
        />
      ) : (
        <span>{initials}</span>
      )}
    </div>
  )
}

/**
 * Picks the best available photo url from a user document, falling back
 * across the various field names used in the app codebase.
 */
export function pickPhotoUrl(data: any): string | null {
  return (
    data?.profilePhotoUrl ||
    data?.photoUrl ||
    data?.photoURL ||
    data?.avatarUrl ||
    null
  )
}
