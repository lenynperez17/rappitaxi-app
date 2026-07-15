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

// Ronda 34 Bug#1: X-Real-IP tiene prioridad sobre X-Forwarded-For — nuestro
// nginx lo setea con $remote_addr (IP real del socket TCP) y no puede ser
// spoofeado desde el cliente. X-Forwarded-For sí es forjable si Next.js está
// expuesto directamente (aunque nginx nos protege, defense-in-depth).
// Fallback 'unknown' se conserva pero rate-limit externo (nginx) atrapa DoS.
function extractClientIp(req: NextRequest): string {
  const realIp = req.headers.get('x-real-ip')?.trim()
  if (realIp && realIp.length > 0) return realIp
  const xff = req.headers.get('x-forwarded-for')
  if (xff) {
    // Con XFF confiamos SOLO en la última IP (la que nuestro proxy agrega),
    // no la primera (que el cliente puede haber forjado).
    const parts = xff.split(',').map((s) => s.trim()).filter(Boolean)
    if (parts.length > 0) return parts[parts.length - 1]
  }
  return 'unknown'
}

export function ipRateLimit(
  req: NextRequest,
  key: string,
  opts: { max: number; windowMs: number },
): { ok: boolean; remaining: number } {
  const ip = extractClientIp(req)
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
