// Root page — solo mensaje de servicio activo. La UI vive en admin/ (Vite en Hostinger).
export const dynamic = 'force-static'

export default function RootPage() {
  return (
    <main style={{ padding: 40, fontFamily: 'system-ui' }}>
      <h1>Rapi Team API</h1>
      <p>API backend running. See <code>/api/health</code> for status.</p>
    </main>
  )
}
