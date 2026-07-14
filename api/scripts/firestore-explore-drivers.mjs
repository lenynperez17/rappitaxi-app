#!/usr/bin/env node
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, resolve } from 'node:path'
import admin from 'firebase-admin'

const __dirname = dirname(fileURLToPath(import.meta.url))
const sa = JSON.parse(readFileSync(resolve(__dirname, '../keys/rapi-team-firebase-admin.json'), 'utf8'))
admin.initializeApp({ credential: admin.credential.cert(sa), projectId: sa.project_id })
const db = admin.firestore()

for (const coll of ['drivers', 'driver_applications', 'deleted_users_log']) {
  const snap = await db.collection(coll).get()
  console.log(`\n=== ${coll}: ${snap.size} docs ===`)
  if (snap.size === 0) continue
  const first = snap.docs[0]
  const d = first.data()
  console.log('  id:', first.id)
  for (const [k, v] of Object.entries(d)) {
    const preview = typeof v === 'string' ? v.slice(0, 80) : JSON.stringify(v)?.slice(0, 80)
    console.log(`  ${k}: ${preview}`)
  }
  const statuses = {}
  for (const doc of snap.docs) {
    const s = doc.data().status || doc.data().driverStatus || '(sin status)'
    statuses[s] = (statuses[s] || 0) + 1
  }
  console.log('  Estados:', statuses)
}

// ¿Cuántos users en Auth NO tienen doc en Firestore?
console.log('\n=== Auth sin doc en users ===')
const usersSnap = await db.collection('users').get()
const firestoreUids = new Set(usersSnap.docs.map(d => d.id))
let orphans = 0
let nextPageToken
do {
  const page = await admin.auth().listUsers(1000, nextPageToken)
  for (const u of page.users) {
    if (!firestoreUids.has(u.uid)) {
      orphans++
      if (orphans <= 5) {
        console.log(`  orphan: ${u.uid.slice(0,10)}… email=${u.email || '(sin)'} phone=${u.phoneNumber || '(sin)'}`)
      }
    }
  }
  nextPageToken = page.pageToken
} while (nextPageToken)
console.log(`Total en Auth sin doc: ${orphans}`)
process.exit(0)
