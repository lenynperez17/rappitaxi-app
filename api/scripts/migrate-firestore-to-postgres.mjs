#!/usr/bin/env node
/**
 * Migra usuarios desde Firestore (rapi-team) a Postgres.
 * — Idempotente: correr N veces produce el mismo resultado.
 * — Preserva el uid de Firestore como `users.id` para que rides/vales antiguos
 *   sigan apuntando al mismo user (queda sincronizado con Firebase Auth uid).
 *
 * Colecciones que migra:
 *   - users     → user_type = passenger | dual | admin (según Firestore)
 *   - drivers   → user_type = 'driver' + perfil vehicular
 *
 * NO migra:
 *   - Usuarios de Firebase Auth SIN doc en Firestore (rol desconocido).
 *   - deleted_users_log (ya están eliminados).
 *
 * Uso:
 *   node scripts/migrate-firestore-to-postgres.mjs [--dry-run] [--verbose]
 *
 * Variables de entorno (lee .env automáticamente):
 *   POSTGRES_URL   → conexión a rapi_team db
 *   FIRESTORE_SA   → ruta al service account (default: ./keys/rapi-team-firebase-admin.json)
 */
import { readFileSync, existsSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, resolve } from 'node:path'
import admin from 'firebase-admin'
import pg from 'pg'
import 'dotenv/config'

const __dirname = dirname(fileURLToPath(import.meta.url))
const DRY = process.argv.includes('--dry-run')
const VERBOSE = process.argv.includes('--verbose')

const SA_PATH = process.env.FIRESTORE_SA || resolve(__dirname, '../keys/rapi-team-firebase-admin.json')
if (!existsSync(SA_PATH)) {
  console.error(`ERROR: service account no encontrado en ${SA_PATH}`)
  process.exit(1)
}
const sa = JSON.parse(readFileSync(SA_PATH, 'utf8'))
admin.initializeApp({ credential: admin.credential.cert(sa), projectId: sa.project_id })
const db = admin.firestore()

const PG_URL = process.env.POSTGRES_URL || process.env.DATABASE_URL
if (!PG_URL) { console.error('ERROR: POSTGRES_URL o DATABASE_URL requerido'); process.exit(1) }
const pool = new pg.Pool({ connectionString: PG_URL })

// ─── Helpers ───────────────────────────────────────────────────────

const tsToDate = (ts) => {
  if (!ts) return null
  if (ts._seconds !== undefined) return new Date(ts._seconds * 1000 + Math.floor((ts._nanoseconds || 0) / 1e6))
  if (ts.toDate) return ts.toDate()
  if (typeof ts === 'string') { const d = new Date(ts); return isNaN(d) ? null : d }
  return null
}

const normalizePhone = (raw) => {
  if (!raw) return null
  const s = String(raw).trim()
  if (!s) return null
  const digits = s.replace(/[^\d+]/g, '')
  if (!digits) return null
  if (digits.startsWith('+')) return digits
  if (digits.startsWith('51') && digits.length === 11) return `+${digits}`
  if (digits.length === 9 && digits.startsWith('9')) return `+51${digits}`
  return digits.startsWith('+') ? digits : `+${digits}`
}

const normEmail = (e) => (typeof e === 'string' ? e.trim().toLowerCase() : null) || null

/** Mapea un doc de Firestore `users` a columnas de Postgres `users`. */
function mapUserDoc(id, d) {
  const email = normEmail(d.email)
  const phone = normalizePhone(d.phone || d.phoneNumber)
  const rawType = (d.userType || d.role || 'passenger').toLowerCase()
  const userType = ['passenger','driver','dual','admin'].includes(rawType) ? rawType : 'passenger'
  const isAdmin = d.isAdmin === true || rawType === 'admin'
  return {
    id,
    full_name: d.fullName || d.displayName || null,
    display_name: d.displayName || d.fullName || null,
    email,
    phone,
    phone_number: phone,
    profile_photo_url: d.profilePhotoUrl || null,
    user_type: isAdmin ? 'admin' : userType,
    auth_provider: d.authProvider || (Array.isArray(d.authProviders) ? d.authProviders[0] : null),
    is_admin: isAdmin,
    is_active: d.isActive !== false, // default true
    is_verified: d.isVerified === true,
    phone_verified: d.phoneVerified === true,
    email_verified: d.emailVerified === true,
    profile_complete: d.profileComplete === true || d.onboardingComplete === true,
    google_uid: d.authProvider === 'google' ? id : null,
    apple_uid: d.authProvider === 'apple' ? id : null,
    created_at: tsToDate(d.createdAt),
    updated_at: tsToDate(d.updatedAt),
  }
}

/** Mapea un doc de la colección `drivers` a `users` con user_type='driver'. */
function mapDriverDoc(id, d) {
  const email = normEmail(d.email)
  const phone = normalizePhone(d.phone || d.phoneNumber)
  return {
    id, // userId = uid Firebase Auth
    full_name: d.fullName || null,
    display_name: d.fullName || null,
    email,
    phone,
    phone_number: phone,
    profile_photo_url: d.profilePhotoUrl || null,
    user_type: 'driver',
    auth_provider: d.authProvider || null,
    is_admin: false,
    is_active: d.isActive !== false,
    is_verified: d.isVerified === true || d.verificationStatus === 'approved',
    phone_verified: d.phoneVerified === true,
    email_verified: d.emailVerified === true,
    profile_complete: d.onboardingComplete === true || d.status !== 'pending_approval',
    google_uid: d.authProvider === 'google' ? id : null,
    apple_uid: d.authProvider === 'apple' ? id : null,
    created_at: tsToDate(d.createdAt),
    updated_at: tsToDate(d.updatedAt),
  }
}

/** Inserta con ON CONFLICT DO NOTHING. Devuelve {inserted, existed}. */
async function upsertUser(client, u) {
  const cols = Object.keys(u)
  const vals = Object.values(u).map(v => v === undefined ? null : v)
  const placeholders = cols.map((_, i) => `$${i + 1}`).join(', ')
  const sql = `
    INSERT INTO users (${cols.join(', ')})
    VALUES (${placeholders})
    ON CONFLICT (id) DO NOTHING
    RETURNING id
  `
  const r = await client.query(sql, vals)
  return { inserted: r.rowCount === 1, existed: r.rowCount === 0 }
}

/** Verifica si `email` (case-insensitive) ya está tomado por OTRO id. */
async function emailCollisionWith(client, email, myId) {
  if (!email) return null
  const r = await client.query('SELECT id FROM users WHERE LOWER(email) = $1 AND id <> $2 LIMIT 1', [email.toLowerCase(), myId])
  return r.rows[0]?.id || null
}

// ─── Main ──────────────────────────────────────────────────────────

async function main() {
  console.log(`Modo: ${DRY ? 'DRY-RUN (no escribe)' : 'EJECUCIÓN REAL'}`)
  console.log(`Proyecto Firestore: ${sa.project_id}`)
  console.log(`Postgres: ${PG_URL.replace(/:[^:@]+@/, ':****@')}`)
  console.log('')

  const client = await pool.connect()
  try {
    // ─── Paso 1: users ────────────────────────────────────────────
    console.log('▶ Leyendo colección users …')
    const usersSnap = await db.collection('users').get()
    console.log(`  ${usersSnap.size} docs encontrados`)

    const stats = { users: { inserted: 0, existed: 0, skipped: 0, collision: 0 } }

    for (const doc of usersSnap.docs) {
      const u = mapUserDoc(doc.id, doc.data())
      if (!u.email && !u.phone) {
        stats.users.skipped++
        if (VERBOSE) console.log(`  ⏭  ${doc.id.slice(0,8)}… sin email ni phone`)
        continue
      }
      const collision = await emailCollisionWith(client, u.email, u.id)
      if (collision) {
        stats.users.collision++
        console.log(`  ⚠️  email colisión: ${u.email} ya usado por ${collision} (nuevo id ${u.id.slice(0,8)}…)`)
        continue
      }
      if (DRY) {
        stats.users.inserted++
        if (VERBOSE) console.log(`  + ${u.user_type.padEnd(10)} ${u.email || u.phone} (${u.full_name})`)
      } else {
        const { inserted } = await upsertUser(client, u)
        if (inserted) { stats.users.inserted++; if (VERBOSE) console.log(`  ✓ ${u.user_type.padEnd(10)} ${u.email || u.phone}`) }
        else { stats.users.existed++ }
      }
    }

    // ─── Paso 2: drivers ─────────────────────────────────────────
    console.log('\n▶ Leyendo colección drivers …')
    const driversSnap = await db.collection('drivers').get()
    console.log(`  ${driversSnap.size} docs encontrados`)
    stats.drivers = { inserted: 0, existed: 0, skipped: 0, collision: 0, upgraded: 0 }

    for (const doc of driversSnap.docs) {
      const d = mapDriverDoc(doc.id, doc.data())
      if (!d.email && !d.phone) { stats.drivers.skipped++; continue }

      // Si ya existe en users (porque también estaba en la colección users), UPGRADE a driver
      const existing = await client.query('SELECT id, user_type FROM users WHERE id = $1', [d.id])
      if (existing.rowCount) {
        const currentType = existing.rows[0].user_type
        if (currentType === 'passenger') {
          if (DRY) {
            stats.drivers.upgraded++
            console.log(`  ↑ upgrade ${d.id.slice(0,8)}… passenger → driver (${d.full_name})`)
          } else {
            await client.query(
              `UPDATE users SET user_type = 'driver', is_verified = $2, updated_at = now() WHERE id = $1`,
              [d.id, d.is_verified],
            )
            stats.drivers.upgraded++
            if (VERBOSE) console.log(`  ↑ ${d.email || d.phone} promovido a driver`)
          }
        } else {
          stats.drivers.existed++
        }
        continue
      }

      const collision = await emailCollisionWith(client, d.email, d.id)
      if (collision) {
        stats.drivers.collision++
        console.log(`  ⚠️  driver email colisión: ${d.email} ya usado por ${collision}`)
        continue
      }

      if (DRY) {
        stats.drivers.inserted++
        console.log(`  + driver ${d.email || d.phone} (${d.full_name})`)
      } else {
        const { inserted } = await upsertUser(client, d)
        if (inserted) { stats.drivers.inserted++; if (VERBOSE) console.log(`  ✓ driver ${d.email || d.phone}`) }
        else { stats.drivers.existed++ }
      }
    }

    // ─── Resumen ──────────────────────────────────────────────────
    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
    console.log('RESUMEN')
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
    console.log('users:  ', stats.users)
    console.log('drivers:', stats.drivers)

    const totalRes = await client.query("SELECT COUNT(*)::int AS n FROM users WHERE deleted_at IS NULL")
    console.log(`\nTotal en Postgres users (activos): ${totalRes.rows[0].n}`)

    if (DRY) console.log('\n(DRY-RUN — nada se escribió a Postgres)')
  } finally {
    client.release()
    await pool.end()
  }
}

main().catch(e => { console.error(e); process.exit(1) })
