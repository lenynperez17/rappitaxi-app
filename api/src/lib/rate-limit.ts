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
// Ronda 125: normalizar IPv4-mapped IPv6 + case IPv6 para evitar buckets
// duplicados. Cliente dual-stack alternando IPv4/IPv6 (o WiFi/cellular)
// producía buckets separados y ipRateLimit efectivamente doblado → un
// attacker lo exploitaba alternando familias IP para brute-force.
function normalizeIp(ip: string): string {
  let s = ip.toLowerCase().trim()
  // Strip IPv4-mapped IPv6 prefix: ::ffff:1.2.3.4 → 1.2.3.4
  if (s.startsWith('::ffff:')) s = s.slice(7)
  return s
}

function extractClientIp(req: NextRequest): string {
  const realIp = req.headers.get('x-real-ip')?.trim()
  if (realIp && realIp.length > 0) return normalizeIp(realIp)
  const xff = req.headers.get('x-forwarded-for')
  if (xff) {
    // Con XFF confiamos SOLO en la última IP (la que nuestro proxy agrega),
    // no la primera (que el cliente puede haber forjado).
    const parts = xff.split(',').map((s) => s.trim()).filter(Boolean)
    if (parts.length > 0) return normalizeIp(parts[parts.length - 1])
  }
  return 'unknown'
}

export function ipRateLimit(
  req: NextRequest,
  key: string,
  opts: { max: number; windowMs: number },
): { ok: boolean; remaining: number } {
  const ip = extractClientIp(req)
  return keyedRateLimit(`${key}:${ip}`, opts)
}

// Ronda 57 Bug#2: rate-limit por key arbitraria (email/user_id) además del IP.
// Un botnet distribuido puede rotar IPs para brute-forcear un email sin
// disparar ipRateLimit → esto agrega el otro eje (bucket por email).
export function keyedRateLimit(
  bucketKey: string,
  opts: { max: number; windowMs: number },
): { ok: boolean; remaining: number } {
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
