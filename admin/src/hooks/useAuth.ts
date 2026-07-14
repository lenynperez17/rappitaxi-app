import { useEffect } from 'react'
import { useAuthStore } from '../stores/authStore'
import { adminApi, AdminApiError } from '../lib/adminApi'
import type { User } from '../types/user'

/**
 * Autenticación 100% via backend Node. Login email + password.
 */
function toAdminUserData(me: {
  id: string; fullName: string | null; email: string | null;
  phone: string | null; userType: string; isAdmin: boolean; isActive: boolean
}): User {
  return {
    id: me.id,
    fullName: me.fullName ?? undefined,
    email: me.email ?? undefined,
    phone: me.phone ?? undefined,
    userType: me.userType,
    isAdmin: me.isAdmin,
    isActive: me.isActive,
  } as User
}

export function useAuth() {
  const store = useAuthStore()

  useEffect(() => {
    void (async () => {
      try {
        const me = await adminApi.me()
        if (me && (me.isAdmin || me.userType === 'admin')) {
          store.setAuth(toAdminUserData(me))
        } else {
          if (me) await adminApi.logout()
          store.setAuth(null)
        }
      } catch (err) {
        // Solo forzamos logout si el backend nos dijo explícitamente que la
        // sesión es inválida (401/403). Un error transient (500/timeout/red)
        // NO debe deslogar al admin — se mantiene la sesión guardada.
        if (err instanceof AdminApiError && (err.status === 401 || err.status === 403)) {
          store.setAuth(null)
        }
        // Cualquier otro error: dejar el store como está y solo apagar loading.
      } finally {
        store.setLoading(false)
      }
    })()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const login = async (email: string, password: string): Promise<void> => {
    const me = await adminApi.loginWithEmail(email, password)
    if (!me.isAdmin && me.userType !== 'admin') {
      await adminApi.logout()
      throw new Error('No tienes permisos de administrador.')
    }
    store.setAuth(toAdminUserData(me))
  }

  const handleLogout = async () => {
    try { await adminApi.logout() } catch { /* ignore */ }
    store.logout()
  }

  return {
    firebaseUser: null,
    adminUser: store.adminUser,
    isLoading: store.isLoading,
    isAuthenticated: store.isAuthenticated,
    login,
    logout: handleLogout,
  }
}
