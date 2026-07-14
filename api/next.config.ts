import type { NextConfig } from 'next'
import path from 'node:path'

const nextConfig: NextConfig = {
  output: 'standalone',
  poweredByHeader: false,
  reactStrictMode: true,
  serverExternalPackages: ['pg', 'firebase-admin', '@simplewebauthn/server'],
  // Fijar el workspace root para Turbopack — si no, infiere ../app (la carpeta
  // Flutter) y falla al no encontrar next/package.json ahí.
  turbopack: {
    root: path.resolve(__dirname),
  },
}

export default nextConfig
