import { NavLink } from 'react-router-dom'
import {
  LayoutDashboard,
  Users,
  Car,
  Route,
  DollarSign,
  BarChart3,
  AlertTriangle,
  Tag,
  Settings,
  MapPin,
  CreditCard,
  FileText,
  FileMinus,
  ShieldCheck,
  X,
  Zap,
} from 'lucide-react'
import { clsx } from 'clsx'

interface NavItem {
  label: string
  path: string
  icon: React.ComponentType<{ className?: string }>
  group?: string
}

const navItems: NavItem[] = [
  { label: 'Dashboard', path: '/dashboard', icon: LayoutDashboard },
  { label: 'Usuarios', path: '/users', icon: Users },
  { label: 'Conductores', path: '/drivers', icon: Car },
  { label: 'Verificaciones', path: '/verifications', icon: ShieldCheck },
  { label: 'Viajes', path: '/trips', icon: Route },
  // ★ NUEVO bloque de Recargas y Facturacion
  { label: 'Recargas', path: '/recharges', icon: CreditCard },
  { label: 'Facturacion', path: '/invoices', icon: FileText },
  { label: 'Notas de Credito', path: '/credit-notes', icon: FileMinus },
  { label: 'Financiero', path: '/financial', icon: DollarSign },
  { label: 'Mapa en Vivo', path: '/map', icon: MapPin },
  { label: 'Analiticas', path: '/analytics', icon: BarChart3 },
  { label: 'Emergencias', path: '/emergencies', icon: AlertTriangle },
  { label: 'Promociones', path: '/promotions', icon: Tag },
  { label: 'Configuracion', path: '/settings', icon: Settings },
]

interface SidebarProps {
  collapsed: boolean
  mobileOpen: boolean
  onMobileClose: () => void
}

export function Sidebar({ collapsed, mobileOpen, onMobileClose }: SidebarProps) {
  return (
    <aside
      className={clsx(
        'flex flex-col bg-gray-900 text-white transition-all duration-300 z-30',
        'hidden lg:flex',
        collapsed ? 'lg:w-16' : 'lg:w-60',
        'fixed inset-y-0 left-0 lg:relative',
        mobileOpen ? '!flex w-60' : 'lg:flex'
      )}
    >
      {/* Logo */}
      <div className="flex items-center gap-3 px-4 py-5 border-b border-gray-700/50 flex-shrink-0">
        <div className="w-8 h-8 rounded-lg bg-[#E31E24] flex items-center justify-center flex-shrink-0">
          <Zap className="w-5 h-5 text-white" />
        </div>
        {!collapsed && (
          <div className="overflow-hidden">
            <p className="font-bold text-sm leading-tight">Rapi Team</p>
            <p className="text-xs text-gray-400">Panel Admin</p>
          </div>
        )}
        <button
          onClick={onMobileClose}
          className="ml-auto lg:hidden p-1 text-gray-400 hover:text-white"
        >
          <X className="w-4 h-4" />
        </button>
      </div>

      {/* Nav */}
      <nav className="flex-1 overflow-y-auto py-4 px-2 space-y-0.5">
        {navItems.map((item) => (
          <NavLink
            key={item.path}
            to={item.path}
            onClick={onMobileClose}
            title={collapsed ? item.label : undefined}
            className={({ isActive }) =>
              clsx(
                'flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors group',
                isActive
                  ? 'bg-[#E31E24] text-white'
                  : 'text-gray-400 hover:bg-gray-800 hover:text-white'
              )
            }
          >
            <item.icon className="w-5 h-5 flex-shrink-0" />
            {!collapsed && <span className="truncate">{item.label}</span>}
          </NavLink>
        ))}
      </nav>

      {!collapsed && (
        <div className="px-4 py-3 border-t border-gray-700/50 flex-shrink-0">
          <p className="text-xs text-gray-500">v1.0 &middot; Rapi Team Peru</p>
        </div>
      )}
    </aside>
  )
}
