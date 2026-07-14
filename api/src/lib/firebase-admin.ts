/**
 * Firebase Admin SDK — lazy singleton init.
 *
 * IMPORTANTE: no inicializamos al import; lo hacemos al primer uso. Esto
 * evita que Next.js "Collect page data" (que ejecuta module top-level)
 * falle si las env vars no están disponibles en el momento del build.
 */
import { initializeApp, getApps, cert, App } from 'firebase-admin/app'
import { getFirestore, Firestore } from 'firebase-admin/firestore'
import { getAuth, Auth } from 'firebase-admin/auth'
import { getMessaging, Messaging } from 'firebase-admin/messaging'

let cachedApp: App | null = null

function getPrivateKey(): string {
  const key = process.env.FIREBASE_PRIVATE_KEY
  if (!key) throw new Error('FIREBASE_PRIVATE_KEY no configurado')
  if (key.includes('\n') && key.includes('-----BEGIN')) return key
  return key.replace(/\\n/g, '\n')
}

function getApp(): App {
  if (cachedApp) return cachedApp
  const existing = getApps()
  if (existing.length > 0) {
    cachedApp = existing[0]!
    return cachedApp
  }
  cachedApp = initializeApp({
    credential: cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: getPrivateKey(),
    }),
    projectId: process.env.FIREBASE_PROJECT_ID,
  })
  return cachedApp
}

// Proxies lazy: no ejecutan getApp() hasta que se accede a una propiedad.
export const db: Firestore = new Proxy({} as Firestore, {
  get(_t, p) {
    const real = getFirestore(getApp()) as unknown as Record<string | symbol, unknown>
    const v = real[p as string | symbol]
    return typeof v === 'function' ? (v as (...args: unknown[]) => unknown).bind(real) : v
  },
})

export const auth: Auth = new Proxy({} as Auth, {
  get(_t, p) {
    const real = getAuth(getApp()) as unknown as Record<string | symbol, unknown>
    const v = real[p as string | symbol]
    return typeof v === 'function' ? (v as (...args: unknown[]) => unknown).bind(real) : v
  },
})

export const messaging: Messaging = new Proxy({} as Messaging, {
  get(_t, p) {
    const real = getMessaging(getApp()) as unknown as Record<string | symbol, unknown>
    const v = real[p as string | symbol]
    return typeof v === 'function' ? (v as (...args: unknown[]) => unknown).bind(real) : v
  },
})

// Aliases de compatibilidad
export { db as adminDb, auth as adminAuth, messaging as adminMessaging }

export async function isUserAdmin(uid: string): Promise<boolean> {
  try {
    const userDoc = await db.collection('users').doc(uid).get()
    if (!userDoc.exists) return false
    const userData = userDoc.data()
    return userData?.userType === 'admin' || userData?.role === 'admin'
  } catch (error) {
    console.error('Error verificando rol de admin:', error)
    return false
  }
}

/**
 * Firma un Firebase Custom Token para `uid`. Retorna null si Firebase Admin
 * no está configurado (durante la transición híbrida, si el service account
 * de rapi-team todavía no está en el .env, la app cliente cae en fallback
 * y usa solo el JWT del backend).
 */
export async function mintFirebaseCustomToken(
  uid: string,
  claims: Record<string, unknown> = {},
): Promise<string | null> {
  if (!process.env.FIREBASE_PRIVATE_KEY || !process.env.FIREBASE_CLIENT_EMAIL) {
    console.warn('[firebase-admin] Custom token skipped: FIREBASE_* not configured')
    return null
  }
  try {
    return await auth.createCustomToken(uid, claims)
  } catch (err) {
    console.error('[firebase-admin] createCustomToken failed:', err)
    return null
  }
}

export async function getUserData(uid: string) {
  try {
    const userDoc = await db.collection('users').doc(uid).get()
    if (!userDoc.exists) return null
    return { id: userDoc.id, ...userDoc.data() }
  } catch (error) {
    console.error('Error obteniendo datos de usuario:', error)
    return null
  }
}
