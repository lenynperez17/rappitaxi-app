import { lazy, Suspense } from 'react'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { useAuth } from './hooks/useAuth'
import { AdminApiError } from './lib/adminApi'
import { AdminLayout } from './components/layout/AdminLayout'
import { LoginPage } from './pages/LoginPage'
import { DashboardPage } from './pages/DashboardPage'
import { UsersPage } from './pages/users/UsersPage'
import { UserDetailPage } from './pages/users/UserDetailPage'
import { DriversPage } from './pages/drivers/DriversPage'
import { TripsPage } from './pages/trips/TripsPage'
import { FinancialPage } from './pages/financial/FinancialPage'
import { AnalyticsPage } from './pages/analytics/AnalyticsPage'
import { EmergenciesPage } from './pages/emergencies/EmergenciesPage'
import { PromotionsPage } from './pages/promotions/PromotionsPage'
import { SettingsPage } from './pages/settings/SettingsPage'
/**
 * Ronda 270: el mapa se carga aparte.
 *
 * Arrastra Leaflet y MapLibre, que juntos pesan un megabyte largo. Metidos en
 * el paquete principal, quien entra a ver una factura desde el móvil se lo
 * descarga igual sin llegar a abrir el mapa. Así solo lo paga quien lo usa.
 */
const LiveMapPage = lazy(() =>
  import('./pages/map/LiveMapPage').then((m) => ({ default: m.LiveMapPage })),
)
import { RechargesPage } from './pages/recharges/RechargesPage'
import { RechargeDetailPage } from './pages/recharges/RechargeDetailPage'
import { InvoicesPage } from './pages/recharges/InvoicesPage'
import { CreditNotesPage } from './pages/recharges/CreditNotesPage'
import { VerificationsPage } from './pages/verifications/VerificationsPage'
import { DriverVerificationDetailPage } from './pages/verifications/DriverVerificationDetailPage'
import { DocumentTypesPage } from './pages/verifications/DocumentTypesPage'
import { ServiceTypesPage } from './pages/settings/ServiceTypesPage'
import { CancellationsPage } from './pages/cancellations/CancellationsPage'

/**
 * Ronda 287: las páginas pasan a cargar con useQuery.
 *
 * `staleTime` de 30 s en vez de 5 min: antes cada visita pedía datos frescos,
 * y en recargas o facturas cinco minutos de retraso son un saldo equivocado en
 * pantalla. Con 30 s se muestra al instante lo que hay en caché y se refresca
 * por detrás si ya envejeció.
 *
 * Un error 4xx no se arregla reintentando (sesión caducada, sin permiso, no
 * existe): se reintenta solo lo que puede ser pasajero, como un 5xx o la red.
 */
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30_000,
      retry: (failureCount, error) =>
        !(error instanceof AdminApiError && error.status >= 400 && error.status < 500) && failureCount < 1,
    },
  },
})

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated, isLoading } = useAuth()

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="flex flex-col items-center gap-4">
          <div className="w-10 h-10 border-4 border-[#E31E24] border-t-transparent rounded-full animate-spin" />
          <p className="text-sm text-gray-500">Verificando sesión...</p>
        </div>
      </div>
    )
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />
  }

  return <>{children}</>
}

function AppRoutes() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route
        path="/"
        element={
          <ProtectedRoute>
            <AdminLayout />
          </ProtectedRoute>
        }
      >
        <Route index element={<Navigate to="/dashboard" replace />} />
        <Route path="dashboard" element={<DashboardPage />} />
        <Route path="users" element={<UsersPage />} />
        <Route path="users/:userId" element={<UserDetailPage />} />
        <Route path="drivers" element={<DriversPage />} />
        <Route path="verifications" element={<VerificationsPage />} />
        {/* Ronda 279: antes de la ruta con parámetro, si no `:driverId`
            capturaría "documentos" como si fuera un id de conductor. */}
        <Route path="verifications/documentos" element={<DocumentTypesPage />} />
        <Route path="verifications/:driverId" element={<DriverVerificationDetailPage />} />
        <Route path="cancellations" element={<CancellationsPage />} />
        <Route path="trips" element={<TripsPage />} />
        <Route path="recharges" element={<RechargesPage />} />
        <Route path="recharges/:rechargeId" element={<RechargeDetailPage />} />
        <Route path="invoices" element={<InvoicesPage />} />
        <Route path="credit-notes" element={<CreditNotesPage />} />
        <Route path="financial" element={<FinancialPage />} />
        <Route path="analytics" element={<AnalyticsPage />} />
        <Route path="emergencies" element={<EmergenciesPage />} />
        <Route path="promotions" element={<PromotionsPage />} />
        <Route
          path="map"
          element={
            <Suspense fallback={
              <div className="h-full flex items-center justify-center bg-gray-50">
                <div className="flex flex-col items-center gap-3">
                  <div className="w-8 h-8 border-4 border-[#E31E24] border-t-transparent rounded-full animate-spin" />
                  <p className="text-sm text-gray-500">Cargando el mapa…</p>
                </div>
              </div>
            }>
              <LiveMapPage />
            </Suspense>
          }
        />
        <Route path="settings" element={<SettingsPage />} />
        {/* Ronda 281: los servicios van aparte de Configuración porque
            SettingsPage solo sabe pintar valores sueltos. */}
        <Route path="settings/servicios" element={<ServiceTypesPage />} />
        <Route path="*" element={<Navigate to="/dashboard" replace />} />
      </Route>
      {/* Ronda 108: catch-all top-level para URLs fuera del árbol protegido.
          Antes el * anidado dentro de "/" no matcheaba desde ciertas rutas
          y dejaba shell vacío entre re-evaluaciones de router. */}
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <AppRoutes />
      </BrowserRouter>
    </QueryClientProvider>
  )
}
