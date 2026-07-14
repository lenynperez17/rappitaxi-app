import { Menu, PanelLeftClose, PanelLeftOpen, LogOut, Bell } from 'lucide-react'
import { useAuth } from '../../hooks/useAuth'

interface TopHeaderProps {
  onMenuClick: () => void
  onToggleSidebar: () => void
  sidebarCollapsed: boolean
}

export function TopHeader({ onMenuClick, onToggleSidebar, sidebarCollapsed }: TopHeaderProps) {
  const { adminUser, logout } = useAuth()

  return (
    <header className="bg-white border-b border-gray-200 px-4 py-3 flex items-center gap-4 flex-shrink-0">
      <button
        onClick={onMenuClick}
        className="lg:hidden p-2 text-gray-500 hover:text-gray-900 hover:bg-gray-100 rounded-lg transition-colors"
        aria-label="Abrir menú"
      >
        <Menu className="w-5 h-5" />
      </button>

      <button
        onClick={onToggleSidebar}
        className="hidden lg:flex p-2 text-gray-500 hover:text-gray-900 hover:bg-gray-100 rounded-lg transition-colors"
        aria-label="Colapsar sidebar"
      >
        {sidebarCollapsed ? (
          <PanelLeftOpen className="w-5 h-5" />
        ) : (
          <PanelLeftClose className="w-5 h-5" />
        )}
      </button>

      <div className="flex-1" />

      <button
        className="relative p-2 text-gray-500 hover:text-gray-900 hover:bg-gray-100 rounded-lg transition-colors"
        aria-label="Notificaciones"
      >
        <Bell className="w-5 h-5" />
      </button>

      <div className="flex items-center gap-3 pl-3 border-l border-gray-200">
        <div className="hidden sm:block text-right">
          <p className="text-sm font-medium text-gray-900 leading-tight">
            {(adminUser?.fullName || adminUser?.name) ?? 'Administrador'}
          </p>
          <p className="text-xs text-gray-400">{adminUser?.email}</p>
        </div>
        <div className="w-8 h-8 rounded-full bg-[#E31E24] flex items-center justify-center text-white text-sm font-bold flex-shrink-0">
          {(adminUser?.fullName || adminUser?.name)?.charAt(0)?.toUpperCase() ?? 'A'}
        </div>
        <button
          onClick={logout}
          className="p-2 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition-colors"
          aria-label="Cerrar sesión"
          title="Cerrar sesión"
        >
          <LogOut className="w-4 h-4" />
        </button>
      </div>
    </header>
  )
}
