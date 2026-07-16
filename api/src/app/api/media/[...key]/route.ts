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

  // Path traversal defense — endurecido (Ronda 20 MEDIUM#1). El check anterior
  // solo bloqueaba `..` literal, no URL-encoded (%2E%2E, %2e%2e), backslashes
  // (Windows-style), NUL bytes, ni double-slash. Aunque Next.js normalmente
  // decodifica antes de aquí, cualquier variante que sobreviva se combina con
  // X-Accel-Redirect + normalización de nginx → riesgo de leer /etc/passwd.
  // Whitelist mejor que blacklist: solo permitir alfanuméricos + guiones/dots/slash.
  if (storageKey.length === 0 || storageKey.length > 512) {
    return NextResponse.json({ error: 'invalid_key' }, { status: 400 })
  }
  if (!/^[A-Za-z0-9._\/-]+$/.test(storageKey)) {
    return NextResponse.json({ error: 'invalid_key' }, { status: 400 })
  }
  if (storageKey.includes('..') || storageKey.startsWith('/') || storageKey.includes('//') || storageKey.startsWith('.')) {
    return NextResponse.json({ error: 'invalid_key' }, { status: 400 })
  }

  // Ronda 132 SECURITY: autenticar ANTES del SELECT.
  //   1. DoS amplification: request anónimo disparaba una query pg;
  //      spammear /api/media/<random> saturaba Postgres sin costo (sin
  //      pasar por rate-limit de auth).
  //   2. Enumeration oracle: key inexistente → 404, key existente pero
  //      sin auth → 401 → attacker deduce existencia de archivos ajenos
  //      con solo curl + random UUIDs.
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  const file = await maybeOne<StorageRow>(
    `SELECT id, user_id, storage_key, mime, is_public, deleted_at
       FROM storage_files WHERE storage_key = $1 LIMIT 1`,
    [storageKey],
  )
  if (!file || file.deleted_at) {
    return NextResponse.json({ error: 'not_found' }, { status: 404 })
  }

  const isOwner = file.user_id === auth.userId
  // Los admins pueden ver cualquier archivo (necesario para verificación
  // manual de documentos de drivers). Sin este check, el flow "pending →
  // approved" era imposible: el admin no podía ver el documento.
  let isAdmin = false
  if (!file.is_public && !isOwner) {
    const adminCheck = await maybeOne<{ is_admin: boolean; user_type: string }>(
      'SELECT is_admin, user_type FROM users WHERE id = $1',
      [auth.userId],
    )
    isAdmin = !!(adminCheck && (adminCheck.is_admin || adminCheck.user_type === 'admin'))
    if (!isAdmin) {
      return NextResponse.json({ error: 'forbidden' }, { status: 403 })
    }
  }

  // Emitir X-Accel-Redirect: Nginx sirve el archivo directamente
  const headers = new Headers({
    'X-Accel-Redirect': `/_media_internal/${storageKey}`,
    'Content-Type': file.mime,
    'Cache-Control': file.is_public ? 'public, max-age=86400' : 'private, no-cache',
  })
  return new NextResponse(null, { status: 200, headers })
}
