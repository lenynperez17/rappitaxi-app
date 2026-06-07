import { useState, type FormEvent } from 'react'
import { Navigate } from 'react-router-dom'
import { Eye, EyeOff, AlertCircle, Loader2, X, CheckCircle2 } from 'lucide-react'
import { sendPasswordResetEmail } from 'firebase/auth'
import { auth } from '../config/firebase'
import { useAuth } from '../hooks/useAuth'

export function LoginPage() {
  const { login, isAuthenticated, isLoading } = useAuth()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [error, setError] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [showForgot, setShowForgot] = useState(false)

  if (!isLoading && isAuthenticated) {
    return <Navigate to="/dashboard" replace />
  }

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault()
    setError('')
    setSubmitting(true)
    try {
      await login(email, password)
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Error al iniciar sesion'
      if (message.includes('invalid-credential') || message.includes('wrong-password') || message.includes('user-not-found')) {
        setError('Correo o contrasena incorrectos.')
      } else if (message.includes('permisos')) {
        setError(message)
      } else if (message.includes('too-many-requests')) {
        setError('Demasiados intentos. Intenta mas tarde.')
      } else {
        setError(message)
      }
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-20 h-20 rounded-2xl shadow-lg shadow-red-500/30 mb-4 overflow-hidden bg-white">
            <img src="/icon-192.png" alt="Rapi Team" className="w-full h-full object-contain" />
          </div>
          <h1 className="text-2xl font-bold text-white">Rapi Team</h1>
          <p className="text-gray-400 text-sm mt-1">Panel de Administracion</p>
        </div>

        <div className="bg-white rounded-2xl shadow-2xl p-8">
          <h2 className="text-lg font-semibold text-gray-900 mb-6">Iniciar sesion</h2>

          {error && (
            <div className="flex items-center gap-3 p-3 bg-red-50 border border-red-200 rounded-lg mb-5 text-sm text-red-700">
              <AlertCircle className="w-4 h-4 flex-shrink-0" />
              <span>{error}</span>
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label htmlFor="email" className="block text-sm font-medium text-gray-700 mb-1">
                Correo electronico
              </label>
              <input
                id="email"
                type="email"
                autoComplete="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="admin@rapiteam.com"
                className="w-full px-4 py-2.5 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#E31E24] focus:border-transparent transition-shadow"
              />
            </div>

            <div>
              <label htmlFor="password" className="block text-sm font-medium text-gray-700 mb-1">
                Contrasena
              </label>
              <div className="relative">
                <input
                  id="password"
                  type={showPassword ? 'text' : 'password'}
                  autoComplete="current-password"
                  required
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••"
                  className="w-full px-4 py-2.5 pr-10 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#E31E24] focus:border-transparent transition-shadow"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
                  aria-label={showPassword ? 'Ocultar contrasena' : 'Mostrar contrasena'}
                >
                  {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                </button>
              </div>
            </div>

            <button
              type="submit"
              disabled={submitting}
              className="w-full py-3 px-4 bg-[#E31E24] hover:bg-[#B5181D] text-white text-sm font-semibold rounded-lg transition-colors disabled:opacity-60 flex items-center justify-center gap-2 mt-2"
            >
              {submitting && <Loader2 className="w-4 h-4 animate-spin" />}
              {submitting ? 'Ingresando...' : 'Ingresar'}
            </button>

            <button
              type="button"
              onClick={() => setShowForgot(true)}
              className="block mx-auto text-xs text-gray-500 hover:text-[#E31E24] hover:underline"
            >
              ¿Olvidaste tu contraseña?
            </button>
          </form>
        </div>

        {showForgot && <ForgotPasswordModal initialEmail={email} onClose={() => setShowForgot(false)} />}

        <p className="text-center text-gray-500 text-xs mt-6">
          Solo para administradores autorizados &middot; Rapi Team Peru
        </p>
      </div>
    </div>
  )
}

// ============================================================
// Forgot password modal
// ============================================================

function ForgotPasswordModal({
  initialEmail,
  onClose,
}: {
  initialEmail: string
  onClose: () => void
}) {
  const [resetEmail, setResetEmail] = useState(initialEmail)
  const [busy, setBusy] = useState(false)
  const [success, setSuccess] = useState(false)
  const [err, setErr] = useState<string | null>(null)

  const submit = async (e: FormEvent) => {
    e.preventDefault()
    if (!resetEmail.trim()) {
      setErr('Ingresa tu correo')
      return
    }
    setErr(null)
    setBusy(true)
    try {
      await sendPasswordResetEmail(auth, resetEmail.trim())
      setSuccess(true)
    } catch (e: any) {
      const code = e?.code ?? ''
      if (code === 'auth/invalid-email') setErr('Correo inválido')
      else if (code === 'auth/too-many-requests')
        setErr('Demasiados intentos. Espera unos minutos.')
      else setErr('No se pudo enviar el correo. Verifica el email.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-4">
      <div className="bg-white rounded-xl shadow-2xl w-full max-w-sm">
        <div className="px-5 py-3 border-b border-gray-200 flex items-center justify-between">
          <h3 className="text-base font-semibold text-gray-900">Recuperar contraseña</h3>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-700">
            <X className="w-4 h-4" />
          </button>
        </div>
        <form onSubmit={submit} className="p-5 space-y-3">
          {success ? (
            <div className="bg-green-50 border border-green-200 rounded-lg p-3 flex items-start gap-2 text-sm text-green-700">
              <CheckCircle2 className="w-4 h-4 mt-0.5 flex-shrink-0" />
              <p>
                Si <strong>{resetEmail}</strong> existe, recibirás un correo con instrucciones para
                restablecer tu contraseña. Revisa también el spam.
              </p>
            </div>
          ) : (
            <>
              <p className="text-xs text-gray-600">
                Te enviaremos un correo con un enlace para restablecer tu contraseña.
              </p>
              <input
                type="email"
                autoFocus
                required
                value={resetEmail}
                onChange={(e) => setResetEmail(e.target.value)}
                placeholder="admin@rapiteam.com"
                className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#E31E24]"
              />
              {err && (
                <div className="bg-red-50 border border-red-200 rounded-lg p-2 flex items-start gap-2 text-xs text-red-700">
                  <AlertCircle className="w-4 h-4 mt-0.5 flex-shrink-0" />
                  <span>{err}</span>
                </div>
              )}
            </>
          )}
        </form>
        <div className="px-5 py-3 border-t border-gray-200 bg-gray-50 flex justify-end gap-2">
          <button
            onClick={onClose}
            className="px-4 py-2 text-sm border border-gray-300 rounded-lg hover:bg-gray-100"
          >
            {success ? 'Cerrar' : 'Cancelar'}
          </button>
          {!success && (
            <button
              onClick={submit as any}
              disabled={busy}
              className="px-4 py-2 bg-[#E31E24] hover:bg-[#B5181D] text-white text-sm font-medium rounded-lg disabled:opacity-50 flex items-center gap-2"
            >
              {busy && <Loader2 className="w-4 h-4 animate-spin" />}
              Enviar email
            </button>
          )}
        </div>
      </div>
    </div>
  )
}
