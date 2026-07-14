import { useState } from 'react'
import { Outlet, useLocation } from 'react-router-dom'
import { Sidebar } from './Sidebar'
import { TopHeader } from './TopHeader'

// Rutas que ocupan toda la altura sin padding — típicamente mapas o dashboards
// interactivos que necesitan aprovechar cada píxel.
const FULLSCREEN_ROUTES = ['/map']

export function AdminLayout() {
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false)
  const [mobileSidebarOpen, setMobileSidebarOpen] = useState(false)
  const location = useLocation()
  const isFullscreen = FULLSCREEN_ROUTES.some((p) => location.pathname === p || location.pathname.startsWith(p + '/'))

  return (
    <div className="flex h-screen bg-gray-50 overflow-hidden">
      {mobileSidebarOpen && (
        <div
          className="fixed inset-0 bg-black/50 z-20 lg:hidden"
          onClick={() => setMobileSidebarOpen(false)}
        />
      )}

      <Sidebar
        collapsed={sidebarCollapsed}
        mobileOpen={mobileSidebarOpen}
        onMobileClose={() => setMobileSidebarOpen(false)}
      />

      <div className="flex-1 flex flex-col overflow-hidden min-w-0">
        <TopHeader
          onMenuClick={() => setMobileSidebarOpen(true)}
          onToggleSidebar={() => setSidebarCollapsed(!sidebarCollapsed)}
          sidebarCollapsed={sidebarCollapsed}
        />
        <main className={isFullscreen ? 'flex-1 overflow-hidden' : 'flex-1 overflow-y-auto p-4 lg:p-6'}>
          <Outlet />
        </main>
      </div>
    </div>
  )
}
