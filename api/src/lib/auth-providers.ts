/**
 * Helpers para obtener los proveedores de auth (Google, Apple, Phone, Email)
 * de cada usuario desde Firebase Auth Admin SDK.
 *
 * La fuente de verdad es `providerData[]` de Firebase Auth — NO los campos
 * `authProvider` / `authProviders` de Firestore, que están inconsistentes
 * (algunos users no tienen ninguno, otros tienen string, otros array).
 */
import { auth } from '@/lib/firebase-admin';

export type AuthProviderLabel = 'google' | 'apple' | 'phone' | 'email' | 'facebook' | string;

/**
 * Mapea providerId de Firebase Auth a un label corto para badges del admin.
 */
export function normalizeProviderId(providerId: string): AuthProviderLabel {
  if (providerId === 'google.com') return 'google';
  if (providerId === 'apple.com') return 'apple';
  if (providerId === 'phone') return 'phone';
  if (providerId === 'password') return 'email';
  if (providerId === 'facebook.com') return 'facebook';
  return providerId;
}

/**
 * Trae los providers de auth para los uids dados via Firebase Auth Admin SDK.
 * Batches de 100 (límite de `auth.getUsers`). Falla silenciosamente por user —
 * si un user no existe en Auth (solo en Firestore) devuelve array vacío.
 *
 * @returns Mapa uid → array de labels (['google', 'phone'] etc.)
 */
export async function getAuthProvidersForUsers(
  uids: string[],
): Promise<Map<string, AuthProviderLabel[]>> {
  const providersByUid = new Map<string, AuthProviderLabel[]>();
  if (uids.length === 0) return providersByUid;

  const batches: Promise<{ users: { uid: string; providerData: { providerId: string }[] }[] }>[] = [];
  for (let i = 0; i < uids.length; i += 100) {
    const slice = uids.slice(i, i + 100).map(uid => ({ uid }));
    batches.push(auth.getUsers(slice));
  }

  try {
    const results = await Promise.all(batches);
    for (const result of results) {
      for (const userRecord of result.users) {
        providersByUid.set(
          userRecord.uid,
          userRecord.providerData.map(p => normalizeProviderId(p.providerId)),
        );
      }
    }
  } catch (error) {
    // Si Firebase Auth falla, devolvemos lo que hayamos podido recolectar.
    // No bloqueamos la lista de usuarios por esto.
    console.error('Error obteniendo authProviders desde Firebase Auth:', error);
  }

  return providersByUid;
}
