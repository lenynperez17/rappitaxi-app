import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { useAuth } from './hooks/useAuth'
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
import { LiveMapPage } from './pages/map/LiveMapPage'
import { RechargesPage } from './pages/recharges/RechargesPage'
import { RechargeDetailPage } from './pages/recharges/RechargeDetailPage'
import { InvoicesPage } from './pages/recharges/InvoicesPage'
import { CreditNotesPage } from './pages/recharges/CreditNotesPage'
import { VerificationsPage } from './pages/verifications/VerificationsPage'
import { DriverVerificationDetailPage } from './pages/verifications/DriverVerificationDetailPage'
import { CancellationsPage } from './pages/cancellations/CancellationsPage'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60 * 5,
      retry: 1,
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
        <Route path="map" element={<LiveMapPage />} />
        <Route path="settings" element={<SettingsPage />} />
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
