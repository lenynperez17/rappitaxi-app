import { create } from 'zustand'
import type { User } from '../types/user'

interface AuthState {
  adminUser: User | null
  isLoading: boolean
  isAuthenticated: boolean
  setAuth: (adminUser: User | null) => void
  setLoading: (loading: boolean) => void
  logout: () => void
}

export const useAuthStore = create<AuthState>((set) => ({
  adminUser: null,
  isLoading: true,
  isAuthenticated: false,
  setAuth: (adminUser) => set({ adminUser, isAuthenticated: !!adminUser }),
  setLoading: (loading) => set({ isLoading: loading }),
  logout: () => set({ adminUser: null, isAuthenticated: false }),
}))
