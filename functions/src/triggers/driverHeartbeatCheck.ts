import { onSchedule } from 'firebase-functions/v2/scheduler'
import * as admin from 'firebase-admin'
import { Timestamp } from 'firebase-admin/firestore'

/**
 * Scheduled job that flips `isOnline: false` on drivers whose `lastSeen`
 * is older than HEARTBEAT_TIMEOUT_MS. Prevents "ghost online" drivers
 * left over when the mobile app closes without an explicit disconnect.
 *
 * Runs every 2 minutes. Each driver's mobile heartbeat is every 5 s,
 * so a 5 min threshold gives ample margin for transient network drops.
 *
 * Patches BOTH `users/{uid}` (used by admin panel) AND `drivers/{uid}`
 * (used by ride dispatching) so they stay consistent.
 */

const HEARTBEAT_TIMEOUT_MS = 5 * 60_000 // 5 minutes

export const driverHeartbeatCheck = onSchedule(
  {
    schedule: 'every 2 minutes',
    timeZone: 'America/Lima',
    region: 'us-central1',
  },
  async () => {
    const cutoff = Timestamp.fromMillis(Date.now() - HEARTBEAT_TIMEOUT_MS)
    const firestore = admin.firestore()

    const stats = { users: 0, drivers: 0 }

    // Patch users collection
    stats.users = await flipOffline(firestore.collection('users'), cutoff)

    // Patch drivers collection (separate place where the mobile writes too)
    stats.drivers = await flipOffline(firestore.collection('drivers'), cutoff)

    console.log(
      `driverHeartbeatCheck: marked offline → users=${stats.users}, drivers=${stats.drivers}`,
    )
  },
)

/**
 * Queries the given collection for docs with `isOnline=true` and
 * `lastSeen < cutoff`, then batches updates to flip isOnline=false.
 * Returns the count of docs updated.
 */
async function flipOffline(
  ref: admin.firestore.CollectionReference,
  cutoff: Timestamp,
): Promise<number> {
  const snap = await ref
    .where('isOnline', '==', true)
    .where('lastSeen', '<', cutoff)
    .limit(500)
    .get()

  if (snap.empty) return 0

  const batch = admin.firestore().batch()
  const now = admin.firestore.FieldValue.serverTimestamp()
  for (const doc of snap.docs) {
    batch.update(doc.ref, {
      isOnline: false,
      wentOfflineAt: now,
      wentOfflineReason: 'heartbeat_timeout',
    })
  }
  await batch.commit()
  return snap.size
}
