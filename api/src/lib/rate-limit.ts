/**
 * Rate limit por IP en memoria (proceso PM2 único).
 * Uso: `const rl = ipRateLimit(req, 'sms-send', { max: 10, windowMs: 3600_000 })`.
 * En cluster/multi-nodo esto sería inseguro; por ahora corremos single-instance.
 */
import type { NextRequest } from 'next/server'

const buckets = new Map<string, { count: number; resetAt: number }>()

// Purga de entries expirados. Se ejecuta cada N llamadas para amortizar el
// costo. Sin esto, un attacker con IPs rotativas hace crecer el Map sin
// bound → heap OOM (B#14).
let callsSincePurge = 0
const PURGE_EVERY = 500
function purgeExpired(now: number): void {
  for (const [k, v] of buckets) {
    if (v.resetAt < now) buckets.delete(k)
  }
}

export function ipRateLimit(
  req: NextRequest,
  key: string,
  opts: { max: number; windowMs: number },
): { ok: boolean; remaining: number } {
  const ip =
    req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ??
    req.headers.get('x-real-ip') ??
    'unknown'
  const bucketKey = `${key}:${ip}`
  const now = Date.now()

  if (++callsSincePurge >= PURGE_EVERY) {
    callsSincePurge = 0
    purgeExpired(now)
  }

  const bucket = buckets.get(bucketKey)
  if (!bucket || bucket.resetAt < now) {
    buckets.set(bucketKey, { count: 1, resetAt: now + opts.windowMs })
    return { ok: true, remaining: opts.max - 1 }
  }
  if (bucket.count >= opts.max) return { ok: false, remaining: 0 }
  bucket.count += 1
  return { ok: true, remaining: opts.max - bucket.count }
}
