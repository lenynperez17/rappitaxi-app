/**
 * Storage local en el VPS.
 *
 * Estructura en disco:
 *   $STORAGE_ROOT/{scope}/{userId}/{uuid}.{ext}
 *
 * Nginx sirve /media/* con X-Accel-Redirect emitido por /api/media/[...key].
 * Los archivos nunca son directamente accesibles — todo pasa por route handler
 * que valida ownership o flag `is_public`.
 */
import fs from 'node:fs/promises'
import path from 'node:path'
import { createHash, randomUUID } from 'node:crypto'

export const STORAGE_ROOT = process.env.STORAGE_ROOT ?? '/var/www/Rapi-Team-App-Api/storage'

export type StorageScope =
  | 'profile_photo'
  | 'driver_license'
  | 'vehicle_photo'
  | 'vehicle_registration'
  | 'criminal_record'
  | 'identity_front'
  | 'identity_back'
  | 'soat'
  | 'chat_attachment'
  | 'misc'

const ALLOWED_MIME: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/jpg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'image/heic': 'heic',
  'application/pdf': 'pdf',
}

/** Detecta MIME por magic bytes (más confiable que confiar en el header). */
export function sniffMime(buf: Buffer): string | null {
  if (buf.length < 4) return null
  const hex = buf.subarray(0, 12).toString('hex')
  if (hex.startsWith('ffd8ff')) return 'image/jpeg'
  if (hex.startsWith('89504e470d0a1a0a')) return 'image/png'
  if (hex.startsWith('52494646') && buf.subarray(8, 12).toString('ascii') === 'WEBP') return 'image/webp'
  if (hex.startsWith('25504446')) return 'application/pdf'
  // Ronda 59 Bug#2: HEIC file-type box es 'ftyp' en offset 4 + brand en 8..12.
  // iPhone iOS 11+ emite 'mif1' como brand por defecto; antes solo detectábamos
  // literal 'ftypheic' → HEICs de iPhone se rechazaban como mime_not_allowed.
  if (buf.length >= 12 && buf.subarray(4, 8).toString('ascii') === 'ftyp') {
    const brand = buf.subarray(8, 12).toString('ascii')
    if (/^(heic|heix|heim|heis|hevc|hevx|mif1|msf1)$/.test(brand)) return 'image/heic'
  }
  return null
}

export function extForMime(mime: string): string | null {
  return ALLOWED_MIME[mime] ?? null
}

export function isMimeAllowed(mime: string): boolean {
  return mime in ALLOWED_MIME
}

/** Guarda un buffer en $STORAGE_ROOT/scope/userId/{uuid}.{ext}. Devuelve la key. */
export async function saveBuffer(
  scope: StorageScope,
  userId: string,
  buf: Buffer,
  mime: string,
): Promise<{ key: string; absPath: string; sha256: string; size: number }> {
  const ext = extForMime(mime)
  if (!ext) throw new Error('mime_not_allowed')

  // Sanitizar userId: solo hex/uuid — reject barra o dots
  if (!/^[a-zA-Z0-9-]{6,64}$/.test(userId)) {
    throw new Error('invalid_user_id')
  }
  const dir = path.join(STORAGE_ROOT, scope, userId)
  await fs.mkdir(dir, { recursive: true })
  const filename = `${randomUUID()}.${ext}`
  const absPath = path.join(dir, filename)
  await fs.writeFile(absPath, buf, { mode: 0o644 })

  const sha256 = createHash('sha256').update(buf).digest('hex')
  const key = path.posix.join(scope, userId, filename)
  return { key, absPath, sha256, size: buf.length }
}

/**
 * Rechaza cualquier storage key sospechosa antes de tocar el filesystem.
 * Defense-in-depth: aunque el endpoint /api/media/[...key] ya valida contra
 * `..` y `/`, si algún nuevo caller olvida la validación, aquí paramos el
 * path traversal (evitamos leer/borrar cosas fuera de STORAGE_ROOT).
 */
function assertSafeKey(storageKey: string): string {
  if (
    typeof storageKey !== 'string' ||
    storageKey.length === 0 ||
    storageKey.includes('..') ||
    storageKey.includes('\0') ||
    storageKey.startsWith('/') ||
    storageKey.startsWith('\\') ||
    path.isAbsolute(storageKey)
  ) {
    throw new Error('invalid_storage_key')
  }
  const abs = path.resolve(STORAGE_ROOT, storageKey)
  const rootAbs = path.resolve(STORAGE_ROOT)
  if (!abs.startsWith(rootAbs + path.sep) && abs !== rootAbs) {
    throw new Error('invalid_storage_key')
  }
  return abs
}

/** Elimina archivo físico. Tolera ENOENT. */
export async function deleteFile(storageKey: string): Promise<void> {
  const abs = assertSafeKey(storageKey)
  try {
    await fs.unlink(abs)
  } catch (e: unknown) {
    if ((e as NodeJS.ErrnoException).code !== 'ENOENT') throw e
  }
}

/** Path absoluto para X-Accel-Redirect. La key ya debe estar validada. */
export function absPath(storageKey: string): string {
  return assertSafeKey(storageKey)
}
