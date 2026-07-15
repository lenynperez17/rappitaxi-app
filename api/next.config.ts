import type { NextConfig } from 'next'
import path from 'node:path'

const nextConfig: NextConfig = {
  output: 'standalone',
  poweredByHeader: false,
  reactStrictMode: true,
  serverExternalPackages: ['pg', 'firebase-admin', '@simplewebauthn/server'],
  turbopack: {
    root: path.resolve(__dirname),
  },
  // Ronda 16 MEDIUM#3: security headers. La API maneja PII + facturación SUNAT
  // — sin defense-in-depth, cualquier XSS futuro o embed adversarial en un iframe
  // se convierte en compromiso total.
  async headers() {
    return [
      {
        source: '/:path*',
        headers: [
          { key: 'X-Frame-Options', value: 'DENY' },
          { key: 'X-Content-Type-Options', value: 'nosniff' },
          { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
          { key: 'Permissions-Policy', value: 'geolocation=(), microphone=(), camera=(), payment=()' },
          { key: 'Strict-Transport-Security', value: 'max-age=63072000; includeSubDomains; preload' },
          // CSP conservador: la API solo devuelve JSON, no HTML — bloqueamos todo
          // menos el mínimo para que /api/health y /favicon rendericen si algún
          // browser accede directo.
          { key: 'Content-Security-Policy', value: "default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'" },
        ],
      },
    ]
  },
}

export default nextConfig
