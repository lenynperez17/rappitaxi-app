/**
 * POST /api/storage/upload
 * Auth: Bearer <access_token>
 * Content-Type: multipart/form-data
 * Fields: file (blob), scope (string)
 *
 * Sube un archivo al disco del VPS. Valida MIME por magic bytes,
 * límite de tamaño, y persiste metadatos en Postgres.
 *
 * Response: { success, id, key, url, mime, size }
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { query } from '@/lib/db'
import {
  saveBuffer, sniffMime, isMimeAllowed, deleteFile,
  type StorageScope,
} from '@/lib/storage'

export const runtime = 'nodejs'

const MAX_SIZE_MB = Number(process.env.STORAGE_MAX_SIZE_MB ?? 15)
const MAX_SIZE = MAX_SIZE_MB * 1024 * 1024

const ALLOWED_SCOPES: StorageScope[] = [
  'profile_photo', 'driver_license', 'vehicle_photo', 'vehicle_registration',
  'criminal_record', 'identity_front', 'identity_back', 'soat',
  'chat_attachment', 'misc',
]

// Qué scopes son públicos (accesibles sin auth por otros users)
const PUBLIC_SCOPES = new Set<StorageScope>(['profile_photo', 'vehicle_photo'])

export async function POST(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  let form: FormData
  try {
    form = await req.formData()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_multipart' }, { status: 400 })
  }

  const scopeStr = String(form.get('scope') ?? '')
  const scope = ALLOWED_SCOPES.find((s) => s === scopeStr)
  if (!scope) {
    return NextResponse.json({ success: false, error: 'invalid_scope' }, { status: 400 })
  }

  const file = form.get('file')
  if (!(file instanceof File)) {
    return NextResponse.json({ success: false, error: 'missing_file' }, { status: 400 })
  }
  if (file.size === 0) {
    return NextResponse.json({ success: false, error: 'empty_file' }, { status: 400 })
  }
  if (file.size > MAX_SIZE) {
    return NextResponse.json({
      success: false, error: 'file_too_large',
      message: `Máximo ${MAX_SIZE_MB} MB`,
      maxSizeMb: MAX_SIZE_MB,
    }, { status: 413 })
  }

  const ab = await file.arrayBuffer()
  const buf = Buffer.from(ab)
  // Ronda 60 Bug#1: NO fallback a file.type (controlado por cliente).
  // Antes: attacker mandaba .exe/.sh/HTML con Content-Type:image/jpeg y
  // sniffMime devolvía null → check pasaba → archivo persistido y servido.
  // Ahora: si sniffMime no reconoce los magic bytes, rechazar.
  const sniffedMime = sniffMime(buf)
  if (!sniffedMime || !isMimeAllowed(sniffedMime)) {
    return NextResponse.json({
      success: false, error: 'mime_not_allowed',
      message: 'Formato no soportado. Usa JPG/PNG/WebP/HEIC/PDF.',
    }, { status: 415 })
  }

  // Ronda 60 Bug#2: rollback del archivo en disco si el INSERT falla.
  // Antes: saveBuffer escribía el archivo → si INSERT fallaba, quedaba
  // orphan en disco sin referencia DB (impossible to reference or cleanup).
  const saved = await saveBuffer(scope, auth.userId, buf, sniffedMime)
  const isPublic = PUBLIC_SCOPES.has(scope)

  try {
    const rows = await query<{ id: string }>(
      `INSERT INTO storage_files (user_id, scope, storage_key, mime, size_bytes, sha256_hex, is_public)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING id`,
      [auth.userId, scope, saved.key, sniffedMime, saved.size, saved.sha256, isPublic],
    )
    const fileId = rows[0]!.id

    // URL pública del proxy — Nginx la sirve autorizada
    const url = `/api/media/${saved.key}`

    return NextResponse.json({
      success: true,
      id: fileId,
      key: saved.key,
      url,
      mime: sniffedMime,
      size: saved.size,
      isPublic,
    })
  } catch (err) {
    // Rollback del archivo físico: si el INSERT falla, borrar el archivo
    // para no dejar huérfanos.
    try { await deleteFile(saved.key) }
    catch (unlinkErr) { console.warn('[storage/upload] rollback deleteFile failed:', unlinkErr) }
    console.error('[storage/upload] INSERT error, file rolled back:', err)
    return NextResponse.json({ success: false, error: 'storage_error' }, { status: 500 })
  }
}
