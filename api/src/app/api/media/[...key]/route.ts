/**
 * GET /api/media/<scope>/<userId>/<uuid>.<ext>
 *
 * Sirve archivos autorizados. Estrategia:
 *   1. Buscar la row storage_files por storage_key
 *   2. Autorización:
 *      - is_public=true → cualquier user autenticado puede leerlo
 *      - is_public=false → solo el owner
 *   3. Devolver X-Accel-Redirect a /_media_internal/{key} — Nginx sirve
 *      el archivo del disco con headers eficientes (sendfile).
 *
 * Requiere configuración Nginx que tenga:
 *   location /_media_internal/ {
 *     internal;
 *     alias /var/www/Rapi-Team-App-Api/storage/;
 *   }
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { maybeOne } from '@/lib/db'

export const runtime = 'nodejs'

interface StorageRow {
  id: string
  user_id: string
  storage_key: string
  mime: string
  is_public: boolean
  deleted_at: Date | null
}

export async function GET(
  req: NextRequest,
  ctx: { params: Promise<{ key: string[] }> },
) {
  const { key: parts } = await ctx.params
  const storageKey = parts.join('/')

  // Path traversal defense
  if (storageKey.includes('..') || storageKey.startsWith('/')) {
    return NextResponse.json({ error: 'invalid_key' }, { status: 400 })
  }

  const file = await maybeOne<StorageRow>(
    `SELECT id, user_id, storage_key, mime, is_public, deleted_at
       FROM storage_files WHERE storage_key = $1 LIMIT 1`,
    [storageKey],
  )
  if (!file || file.deleted_at) {
    return NextResponse.json({ error: 'not_found' }, { status: 404 })
  }

  // Autenticación siempre requerida (mismo si is_public — no exponer sin JWT)
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  const isOwner = file.user_id === auth.userId
  if (!file.is_public && !isOwner) {
    return NextResponse.json({ error: 'forbidden' }, { status: 403 })
  }

  // Emitir X-Accel-Redirect: Nginx sirve el archivo directamente
  const headers = new Headers({
    'X-Accel-Redirect': `/_media_internal/${storageKey}`,
    'Content-Type': file.mime,
    'Cache-Control': file.is_public ? 'public, max-age=86400' : 'private, no-cache',
  })
  return new NextResponse(null, { status: 200, headers })
}
