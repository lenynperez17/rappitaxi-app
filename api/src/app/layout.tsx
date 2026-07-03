// Minimal root layout — the API doesn't serve HTML, only JSON routes.
// Next.js still requires a root layout even for API-only apps.
export const metadata = {
  title: 'Rapi Team API',
  description: 'Rapi Team mobile backend',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="es">
      <body>{children}</body>
    </html>
  )
}
