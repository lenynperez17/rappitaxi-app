import { HttpsError } from 'firebase-functions/v2/https'
import * as admin from 'firebase-admin'

/**
 * Validates that the calling uid belongs to an admin user.
 * Reads users/{uid} and checks isAdmin === true or userType === 'admin'.
 * Throws HttpsError('permission-denied') otherwise.
 */
export async function ensureAdmin(uid: string): Promise<void> {
  const snap = await admin.firestore().collection('users').doc(uid).get()
  const data = snap.data()
  if (!data?.isAdmin && data?.userType !== 'admin') {
    throw new HttpsError('permission-denied', 'Solo administradores')
  }
}

/**
 * Collects all FCM tokens for a user across the various shapes used
 * across the app codebase (fcmTokens[], fcmToken, deviceTokens{}).
 * Dedupes and removes empty values.
 */
export async function getUserFcmTokens(userId: string): Promise<string[]> {
  const userSnap = await admin.firestore().collection('users').doc(userId).get()
  if (!userSnap.exists) return []
  const data = userSnap.data() ?? {}
  const tokens: string[] = []
  if (Array.isArray(data.fcmTokens)) tokens.push(...data.fcmTokens)
  if (typeof data.fcmToken === 'string' && data.fcmToken) tokens.push(data.fcmToken)
  if (data.deviceTokens && typeof data.deviceTokens === 'object') {
    tokens.push(...(Object.values(data.deviceTokens) as string[]))
  }
  return [...new Set(tokens.filter((t) => typeof t === 'string' && t.length > 0))]
}
