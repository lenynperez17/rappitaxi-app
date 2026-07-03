import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  output: 'standalone',
  poweredByHeader: false,
  reactStrictMode: true,
  serverExternalPackages: ['pg', 'firebase-admin', '@simplewebauthn/server'],
}

export default nextConfig
