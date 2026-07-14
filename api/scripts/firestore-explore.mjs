#!/usr/bin/env node
/**
 * Explora la colección `users` de Firestore rapi-team
 * — solo LEE, no toca Postgres.
 *
 * Objetivo: saber cuántos users hay, sus roles, y qué campos usan
 * ANTES de escribir el script de migración definitivo.
 *
 * Uso:  node scripts/firestore-explore.mjs
 */
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, resolve } from 'node:path'
import admin from 'firebase-admin'

const __dirname = dirname(fileURLToPath(import.meta.url))
const SA_PATH = resolve(__dirname, '../keys/rapi-team-firebase-admin.json')
const sa = JSON.parse(readFileSync(SA_PATH, 'utf8'))

admin.initializeApp({ credential: admin.credential.cert(sa), projectId: sa.project_id })
const db = admin.firestore()

console.log(`Proyecto Firestore: ${sa.project_id}`)
console.log(`Service account: ${sa.client_email}`)
console.log('')

// 1) Listar colecciones raíz
console.log('=== Colecciones raíz ===')
const roots = await db.listCollections()
for (const c of roots) console.log(`  - ${c.id}`)
console.log('')

// 2) Contar users
const usersSnap = await db.collection('users').get()
console.log(`=== users: ${usersSnap.size} documentos ===`)

// 3) Distribución por rol
const byRole = {}
const bySrc = { hasPhone: 0, hasEmail: 0, hasFullName: 0, hasDisplayName: 0 }
const sampleFields = new Set()
let first = true
for (const doc of usersSnap.docs) {
  const d = doc.data()
  const role = d.userType || d.role || d.type || '(sin rol)'
  byRole[role] = (byRole[role] || 0) + 1
  if (d.phone || d.phoneNumber) bySrc.hasPhone++
  if (d.email) bySrc.hasEmail++
  if (d.fullName) bySrc.hasFullName++
  if (d.displayName) bySrc.hasDisplayName++
  if (first) {
    for (const k of Object.keys(d)) sampleFields.add(k)
    console.log('\n=== Ejemplo de campos (primer doc) ===')
    console.log('  id:', doc.id)
    for (const [k, v] of Object.entries(d)) {
      const preview = typeof v === 'string' ? v.slice(0, 60) : JSON.stringify(v)?.slice(0, 60)
      console.log(`  ${k}: ${preview}`)
    }
    first = false
  } else {
    for (const k of Object.keys(d)) sampleFields.add(k)
  }
}

console.log('\n=== Distribución por rol ===')
for (const [r, n] of Object.entries(byRole)) console.log(`  ${r}: ${n}`)

console.log('\n=== Cobertura de campos ===')
console.log('  con phone:', bySrc.hasPhone)
console.log('  con email:', bySrc.hasEmail)
console.log('  con fullName:', bySrc.hasFullName)
console.log('  con displayName:', bySrc.hasDisplayName)

console.log('\n=== Todos los nombres de campo vistos ===')
console.log('  ' + Array.from(sampleFields).sort().join(', '))

// 4) Firebase Auth: cuántos usuarios hay en Auth
console.log('\n=== Firebase Auth ===')
try {
  let total = 0
  let nextPageToken
  do {
    const page = await admin.auth().listUsers(1000, nextPageToken)
    total += page.users.length
    nextPageToken = page.pageToken
  } while (nextPageToken)
  console.log(`  usuarios en Firebase Auth: ${total}`)
} catch (e) {
  console.log('  no se pudo listar Firebase Auth:', e.message)
}

process.exit(0)
