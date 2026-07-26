/**
 * Cliente HTTP para el backend Node en VPS.
 * Persiste JWT en localStorage. Auto-refresh en 401.
 */

const BASE_URL = (import.meta.env.VITE_API_URL as string | undefined) ?? 'https://rapi-team-api.nynelmkt.cloud'

const LS_ACCESS = 'rapi_admin_access_token'
const LS_REFRESH = 'rapi_admin_refresh_token'

export class AdminApiError extends Error {
  status: number
  code: string
  constructor(status: number, code: string, message?: string) {
    super(message ?? code)
    this.status = status
    this.code = code
  }
}

export interface AdminUser {
  id: string
  fullName: string | null
  displayName: string | null
  email: string | null
  phone: string | null
  userType: 'passenger' | 'driver' | 'dual' | 'admin'
  isAdmin: boolean
  isActive: boolean
  isVerified: boolean
  phoneVerified: boolean
  emailVerified: boolean
  profileComplete: boolean
  authProvider: string | null
  profilePhotoUrl: string | null
  suspendedAt: string | null
  suspendedReason: string | null
  deletedAt: string | null
  createdAt: string
  updatedAt: string
  createdFrom?: 'mobile' | 'admin_panel' | 'oauth_google' | 'oauth_apple' | 'import' | 'unknown'
}

export interface AdminUserListResponse {
  success: true
  users: AdminUser[]
  page: number
  pageSize: number
  total: number
  totalPages: number
}

export interface AdminDriver {
  id: string; fullName: string | null; email: string | null; phone: string | null
  userType: string; isActive: boolean; isVerified: boolean
  profilePhotoUrl: string | null; suspendedAt: string | null
  createdAt: string; totalTrips: number; avgRating: number | null
  createdFrom?: 'mobile' | 'admin_panel' | 'oauth_google' | 'oauth_apple' | 'import' | 'unknown'
}

export interface AdminTrip {
  id: string; passengerId: string | null; driverId: string | null
  passengerName: string | null; passengerPhone: string | null
  driverName: string | null; driverPhone: string | null
  status: string; pickupAddress: string | null; destinationAddress: string | null
  distanceMeters: number | null; durationSeconds: number | null
  estimatedFare: number | null; finalFare: number | null
  paymentMethod: string | null; vehicleType: string | null
  passengerRating: number | null; driverRating: number | null
  cancelledBy: string | null; cancelledReason: string | null
  createdAt: string; acceptedAt: string | null; completedAt: string | null
}

export interface AdminRecharge {
  id: string; driverId: string; driverName: string | null
  driverPhone: string | null; driverEmail: string | null
  amount: number; method: string; status: string
  reference: string | null; notes: string | null
  approvedBy: string | null; externalRef: string | null
  createdAt: string; approvedAt: string | null
}

export interface AdminEmergency {
  id: string; userId: string | null; rideId: string | null
  userName: string | null; userPhone: string | null
  type: string; status: string
  latitude: number | null; longitude: number | null
  address: string | null; description: string | null
  resolvedBy: string | null; resolvedAt: string | null
  createdAt: string
}

export interface AdminStats {
  users: { total: number; passengers: number; drivers: number; dual: number; admins: number; active: number; suspended: number }
  trips: { total: number; today: number; completed: number; cancelled: number }
  recharges: { total: number; today: number; month: number }
  emergencies: { total: number; active: number }
}

class AdminApi {
  get accessToken() { return localStorage.getItem(LS_ACCESS) }
  get refreshToken() { return localStorage.getItem(LS_REFRESH) }

  setSession(access: string, refresh: string) {
    localStorage.setItem(LS_ACCESS, access)
    localStorage.setItem(LS_REFRESH, refresh)
  }
  clearSession() {
    localStorage.removeItem(LS_ACCESS)
    localStorage.removeItem(LS_REFRESH)
  }

  async loginWithEmail(email: string, password: string): Promise<AdminUser> {
    const data = await this.rawFetch<{ user: AdminUser; jwt: string; refreshToken: string }>(
      '/api/auth/admin/login',
      { method: 'POST', body: { email, password }, skipAuth: true },
    )
    this.setSession(data.jwt, data.refreshToken)
    return data.user
  }

  async changePassword(userId: string, password: string): Promise<void> {
    await this.rawFetch(`/api/admin/users/${userId}/password`, { method: 'PUT', body: { password } })
  }

  async listUsers(params: {
    type?: string
    search?: string
    status?: string
    page?: number
    pageSize?: number
  } = {}): Promise<AdminUserListResponse> {
    const qp = new URLSearchParams()
    for (const [k, v] of Object.entries(params)) {
      if (v !== undefined && v !== '' && v !== null) qp.set(k, String(v))
    }
    return this.rawFetch<AdminUserListResponse>(`/api/admin/users?${qp.toString()}`, { method: 'GET' })
  }

  async getUser(id: string): Promise<AdminUser> {
    const data = await this.rawFetch<{ user: AdminUser }>(`/api/admin/users/${id}`, { method: 'GET' })
    return data.user
  }

  async createUser(input: {
    userType: 'passenger' | 'driver' | 'dual' | 'admin'
    fullName?: string
    email?: string
    phone?: string
    isAdmin?: boolean
    isVerified?: boolean
    profileComplete?: boolean
  }): Promise<AdminUser> {
    const data = await this.rawFetch<{ user: AdminUser }>('/api/admin/users', {
      method: 'POST', body: input,
    })
    return data.user
  }

  async updateUser(id: string, patch: Partial<AdminUser>): Promise<AdminUser> {
    const data = await this.rawFetch<{ user: AdminUser }>(`/api/admin/users/${id}`, {
      method: 'PATCH', body: patch,
    })
    return data.user
  }

  async deleteUser(id: string): Promise<void> {
    await this.rawFetch(`/api/admin/users/${id}`, { method: 'DELETE' })
  }

  async suspendUser(id: string, reason?: string): Promise<void> {
    await this.rawFetch(`/api/admin/users/${id}/suspend`, {
      method: 'POST', body: reason ? { reason } : {},
    })
  }

  async reactivateUser(id: string): Promise<void> {
    await this.rawFetch(`/api/admin/users/${id}/suspend`, { method: 'DELETE' })
  }

  // ─── Dominio admin ────────────────────────────────────────────────

  async listDrivers(params: {
    search?: string; status?: string; page?: number; pageSize?: number
  } = {}): Promise<{ drivers: AdminDriver[]; total: number; page: number; totalPages: number }> {
    const qp = new URLSearchParams()
    for (const [k, v] of Object.entries(params)) if (v !== undefined && v !== '' && v !== null) qp.set(k, String(v))
    return this.rawFetch(`/api/admin/drivers?${qp.toString()}`, { method: 'GET' })
  }

  async listTrips(params: {
    status?: string; driverId?: string; passengerId?: string;
    search?: string; fromDate?: string; toDate?: string; page?: number; pageSize?: number
  } = {}): Promise<{ trips: AdminTrip[]; total: number; page: number; totalPages: number }> {
    const qp = new URLSearchParams()
    for (const [k, v] of Object.entries(params)) if (v !== undefined && v !== '' && v !== null) qp.set(k, String(v))
    return this.rawFetch(`/api/admin/trips?${qp.toString()}`, { method: 'GET' })
  }

  async createTrip(input: {
    passengerId: string
    driverId?: string | null
    pickupAddress: string
    pickupLat: number
    pickupLng: number
    destinationAddress: string
    destinationLat: number
    destinationLng: number
    estimatedFare?: number
    vehicleType?: string
    paymentMethod?: string
    status?: string
  }): Promise<{ trip: { id: string; status: string; createdAt: string }; fanout: { notified: number; fcmSent: number } }> {
    return this.rawFetch('/api/admin/trips', { method: 'POST', body: input })
  }

  async reverseGeocode(lat: number, lng: number): Promise<{ address: string; displayName: string | null }> {
    return this.rawFetch(`/api/admin/geocode/reverse?lat=${lat}&lng=${lng}`, { method: 'GET' })
  }

  async getLive(): Promise<{
    activeTrips: Array<{
      id: string; status: string
      pickupAddress: string | null; destinationAddress: string | null
      pickupLat: number | null; pickupLng: number | null
      destinationLat: number | null; destinationLng: number | null
      estimatedFare: number | null; createdAt: string; acceptedAt: string | null
      passenger: { id: string; fullName: string | null; phone: string | null } | null
      driver: { id: string; fullName: string | null; phone: string | null; latitude: number | null; longitude: number | null } | null
    }>
    onlineDrivers: Array<{
      driverId: string; fullName: string | null; phone: string | null
      profilePhotoUrl: string | null; rating: number | null
      latitude: number | null; longitude: number | null
      vehicleType: string | null; activeRideId: string | null
      lastHeartbeat: string | null; minutesSinceHeartbeat: number | null
    }>
    offlineDrivers: Array<{
      driverId: string; fullName: string | null; phone: string | null
      profilePhotoUrl: string | null; rating: number | null
      latitude: number | null; longitude: number | null
      vehicleType: string | null; activeRideId: string | null
      lastHeartbeat: string | null; minutesSinceHeartbeat: number | null
    }>
    counts: { activeTrips: number; onlineDrivers: number; offlineDrivers: number }
  }> {
    return this.rawFetch('/api/admin/live', { method: 'GET' })
  }

  async listRecharges(params: {
    status?: string; driverId?: string; method?: string;
    fromDate?: string; toDate?: string; page?: number; pageSize?: number
  } = {}): Promise<{ recharges: AdminRecharge[]; total: number; page: number; totalPages: number }> {
    const qp = new URLSearchParams()
    for (const [k, v] of Object.entries(params)) if (v !== undefined && v !== '' && v !== null) qp.set(k, String(v))
    return this.rawFetch(`/api/admin/recharges?${qp.toString()}`, { method: 'GET' })
  }

  async createRecharge(input: {
    driverId: string; amount: number; method: string; reference?: string; notes?: string
  }): Promise<{ id: string; amount: number; method: string }> {
    return this.rawFetch(`/api/admin/recharges`, { method: 'POST', body: input })
  }

  async refundRecharge(
    rechargeId: string,
    reason: string,
  ): Promise<{ success: boolean; rechargeId?: string; refundedAmount?: number; noop?: boolean; message?: string }> {
    return this.rawFetch(`/api/admin/recharges/${rechargeId}/refund`, {
      method: 'POST',
      body: { reason },
    })
  }

  async listEmergencies(params: {
    status?: string; type?: string; page?: number; pageSize?: number
  } = {}): Promise<{ emergencies: AdminEmergency[]; total: number; page: number; totalPages: number }> {
    const qp = new URLSearchParams()
    for (const [k, v] of Object.entries(params)) if (v !== undefined && v !== '' && v !== null) qp.set(k, String(v))
    return this.rawFetch(`/api/admin/emergencies?${qp.toString()}`, { method: 'GET' })
  }

  async updateEmergency(
    id: string,
    input: { status: string; notes?: string },
  ): Promise<{ emergency: { id: string; status: string; resolvedAt: string | null } }> {
    return this.rawFetch(`/api/admin/emergencies/${id}`, { method: 'PATCH', body: input })
  }

  // ─── Documentos de driver ─────────────────────────────────────
  async listDocuments(params: {
    status?: string; driverId?: string; page?: number; pageSize?: number
  } = {}): Promise<{
    documents: Array<{
      id: string; driverId: string; docType: string; fileUrl: string;
      status: string; rejectionReason: string | null; reviewedAt: string | null;
      expiresAt: string | null; createdAt: string;
      driver: { id: string; fullName: string | null; email: string | null; phone: string | null };
    }>;
    total: number;
  }> {
    const qp = new URLSearchParams()
    for (const [k, v] of Object.entries(params)) if (v !== undefined && v !== '' && v !== null) qp.set(k, String(v))
    return this.rawFetch(`/api/admin/documents?${qp.toString()}`, { method: 'GET' })
  }

  /**
   * Sube un archivo COMO admin en nombre de un driver (útil para drivers
   * creados desde el panel que aún no instalaron la app). El archivo se
   * guarda con user_id=driverId para que él pueda descargarlo.
   */
  async uploadDocumentForDriver(driverId: string, docType: string, file: File): Promise<{
    document: { id: string; driverId: string; docType: string; status: string; fileUrl: string }
    created: boolean
  }> {
    const form = new FormData()
    form.append('docType', docType)
    form.append('file', file)
    const headers: Record<string, string> = {}
    if (this.accessToken) headers['Authorization'] = `Bearer ${this.accessToken}`
    const r = await fetch(`${BASE_URL}/api/admin/drivers/${driverId}/documents`, {
      method: 'POST', headers, body: form,
    })
    if (r.status === 401 && this.refreshToken) {
      const refreshed = await this.attemptRefresh()
      if (refreshed) {
        headers['Authorization'] = `Bearer ${this.accessToken}`
        const r2 = await fetch(`${BASE_URL}/api/admin/drivers/${driverId}/documents`, {
          method: 'POST', headers, body: form,
        })
        if (!r2.ok) {
          const data = await r2.json().catch(() => ({}))
          throw new AdminApiError(r2.status, data?.error ?? 'upload_failed', data?.message ?? `HTTP ${r2.status}`)
        }
        return r2.json()
      }
    }
    if (!r.ok) {
      const data = await r.json().catch(() => ({}))
      throw new AdminApiError(r.status, data?.error ?? 'upload_failed', data?.message ?? `HTTP ${r.status}`)
    }
    return r.json()
  }

  async reviewDocument(
    id: string,
    input: { status: 'approved' | 'rejected' | 'expired'; rejectionReason?: string; expiresAt?: string },
  ): Promise<{ document: { id: string; status: string }; driverVerified: boolean | null }> {
    return this.rawFetch(`/api/admin/documents/${id}`, { method: 'PATCH', body: input })
  }

  /**
   * Devuelve el archivo protegido de /api/media/... como Blob autenticado.
   * El endpoint requiere Authorization Bearer, así que un simple <a href>
   * responde 401. Este helper hace el fetch con token y devuelve un Blob
   * que se puede convertir a ObjectURL para previsualizar en un modal.
   */
  async fetchMediaBlob(fileUrl: string): Promise<Blob> {
    // fileUrl puede ser absoluto (https://...) o relativo (/api/media/...).
    const url = fileUrl.startsWith('http') ? fileUrl : `${BASE_URL}${fileUrl}`
    const headers: Record<string, string> = {}
    if (this.accessToken) headers['Authorization'] = `Bearer ${this.accessToken}`
    const r = await fetch(url, { headers })
    if (r.status === 401 && this.refreshToken) {
      const refreshed = await this.attemptRefresh()
      if (refreshed) headers['Authorization'] = `Bearer ${this.accessToken}`
      const r2 = await fetch(url, { headers })
      if (!r2.ok) throw new AdminApiError(r2.status, 'media_fetch_failed', `HTTP ${r2.status} al descargar el archivo`)
      return r2.blob()
    }
    if (!r.ok) throw new AdminApiError(r.status, 'media_fetch_failed', `HTTP ${r.status} al descargar el archivo`)
    return r.blob()
  }

  // ─── Facturación (invoices) ────────────────────────────────────
  async listInvoices(params: {
    status?: string; type?: string; customerId?: string;
    search?: string; fromDate?: string; toDate?: string; page?: number; pageSize?: number
  } = {}): Promise<{ invoices: AdminInvoice[]; total: number; page: number; totalPages: number }> {
    const qp = new URLSearchParams()
    for (const [k, v] of Object.entries(params)) if (v !== undefined && v !== '' && v !== null) qp.set(k, String(v))
    return this.rawFetch(`/api/admin/invoices?${qp.toString()}`, { method: 'GET' })
  }

  async getInvoice(id: string): Promise<{ invoice: AdminInvoice }> {
    return this.rawFetch(`/api/admin/invoices/${id}`, { method: 'GET' })
  }

  async createInvoice(input: {
    documentType: 'receipt' | 'invoice' | 'boleta'
    customerId?: string | null
    customerDocType?: 'DNI' | 'RUC' | 'CE' | 'PASSPORT'
    customerDoc?: string
    customerName: string
    customerEmail?: string
    customerAddress?: string
    rechargeId?: string | null
    rideId?: string | null
    items: Array<{ description: string; quantity: number; unitPrice: number }>
    includeIgv?: boolean
  }): Promise<{ invoice: AdminInvoice }> {
    return this.rawFetch('/api/admin/invoices', { method: 'POST', body: input })
  }

  async voidInvoice(id: string, notes?: string): Promise<{ invoice: AdminInvoice }> {
    return this.rawFetch(`/api/admin/invoices/${id}`, { method: 'PATCH', body: { status: 'voided', notes } })
  }

  // ─── Notas de crédito ──────────────────────────────────────────
  async listCreditNotes(params: {
    status?: string; invoiceId?: string; search?: string;
    fromDate?: string; toDate?: string; page?: number; pageSize?: number
  } = {}): Promise<{ creditNotes: AdminCreditNote[]; total: number; page: number; totalPages: number }> {
    const qp = new URLSearchParams()
    for (const [k, v] of Object.entries(params)) if (v !== undefined && v !== '' && v !== null) qp.set(k, String(v))
    return this.rawFetch(`/api/admin/credit-notes?${qp.toString()}`, { method: 'GET' })
  }

  async createCreditNote(input: {
    invoiceId: string
    reason: 'anulacion' | 'devolucion' | 'descuento_global' | 'descuento_item' | 'ajuste_precio' | 'otros'
    reasonNotes?: string
    amount?: number
  }): Promise<{ creditNote: AdminCreditNote }> {
    return this.rawFetch('/api/admin/credit-notes', { method: 'POST', body: input })
  }

  async nearbyDrivers(params: {
    latitude: number
    longitude: number
    radiusKm?: number
    vehicleType?: string
    limit?: number
  }): Promise<{ drivers: Array<{
    driverId: string
    fullName: string | null
    profilePhotoUrl: string | null
    rating: number | null
    vehicleType: string | null
    latitude: number
    longitude: number
    distanceKm: number | null
  }> }> {
    return this.rawFetch('/api/drivers/nearby', { method: 'POST', body: params })
  }

  // ─── App settings ─────────────────────────────────────────────
  async listSettings(): Promise<{ settings: Array<{
    key: string; value: unknown; description: string | null; updatedAt: string
  }> }> {
    return this.rawFetch('/api/admin/settings', { method: 'GET' })
  }

  async updateSettings(updates: Record<string, unknown>): Promise<{ updated: number }> {
    return this.rawFetch('/api/admin/settings', { method: 'PATCH', body: { updates } })
  }

  // ─── Vales / promociones ───────────────────────────────────────
  async listVales(): Promise<{ vales: Array<{
    id: string; code: string; description: string | null; discountType: string;
    discountValue: number; maxUses: number | null; usedCount: number;
    minRideAmount: number | null; startsAt: string | null; expiresAt: string | null;
    isActive: boolean; createdAt: string
  }> }> {
    return this.rawFetch('/api/admin/vales', { method: 'GET' })
  }

  async createVale(input: {
    code: string; description?: string; discountType: 'percent' | 'flat';
    discountValue: number; maxUses?: number; perUserLimit?: number;
    minRideAmount?: number; startsAt?: string; expiresAt?: string;
  }): Promise<{ vale: { id: string; code: string } }> {
    return this.rawFetch('/api/admin/vales', { method: 'POST', body: input })
  }

  async getStats(): Promise<AdminStats> {
    const data = await this.rawFetch<{ stats: AdminStats }>(`/api/admin/stats`, { method: 'GET' })
    return data.stats
  }

  async me(): Promise<AdminUser | null> {
    if (!this.accessToken) return null
    try {
      const data = await this.rawFetch<{ user: AdminUser }>('/api/auth/me', { method: 'GET' })
      return data.user
    } catch {
      return null
    }
  }

  async logout(): Promise<void> {
    // Ronda 107 SECURITY: si el access token expiró y rawFetch dispara auto-
    // refresh, el body ya serializado enviaba el refresh viejo (ya revocado
    // por la rotación) → backend intentaba revocar RT_OLD (no-op) y RT_NEW
    // quedaba vivo. Fix: leer refreshToken JUSTO antes del envío. Usamos
    // fetch directo para garantizar que se lea al momento del request.
    if (this.accessToken) {
      try {
        // Auto-refresh proactivo si el access está expirado, para que el
        // header Authorization ya lleve el nuevo access y el body lleve
        // el refresh que corresponde a esa sesión activa.
        // (Si falla el refresh, igual limpiamos localStorage abajo.)
        const rt = this.refreshToken
        if (rt) {
          const headers: Record<string, string> = { 'Content-Type': 'application/json' }
          if (this.accessToken) headers['Authorization'] = `Bearer ${this.accessToken}`
          const doFetch = () => fetch(`${BASE_URL}/api/auth/logout`, {
            method: 'POST',
            headers,
            body: JSON.stringify({ refreshToken: this.refreshToken }),
          })
          let r = await doFetch()
          if (r.status === 401) {
            const refreshed = await this.attemptRefresh()
            if (refreshed) {
              headers['Authorization'] = `Bearer ${this.accessToken}`
              // Re-serializar body con el refresh actualizado tras rotación.
              await fetch(`${BASE_URL}/api/auth/logout`, {
                method: 'POST',
                headers,
                body: JSON.stringify({ refreshToken: this.refreshToken }),
              })
            }
          }
          void r
        }
      } catch { /* ignore */ }
    }
    this.clearSession()
  }

  private async rawFetch<T = unknown>(
    path: string,
    opts: { method: string; body?: unknown; skipAuth?: boolean } = { method: 'GET' },
  ): Promise<T> {
    const headers: Record<string, string> = { 'Content-Type': 'application/json' }
    if (!opts.skipAuth && this.accessToken) {
      headers['Authorization'] = `Bearer ${this.accessToken}`
    }
    const doFetch = () => fetch(`${BASE_URL}${path}`, {
      method: opts.method,
      headers,
      body: opts.body ? JSON.stringify(opts.body) : undefined,
    })
    let r = await doFetch()

    if (r.status === 401 && !opts.skipAuth && this.refreshToken) {
      const refreshed = await this.attemptRefresh()
      if (refreshed) {
        headers['Authorization'] = `Bearer ${this.accessToken}`
        r = await doFetch()
      }
    }

    const text = await r.text()
    // Blindaje contra respuestas no-JSON (nginx 502, cloudflare, gateway HTML)
    // — sin este catch un SyntaxError se propaga y rompe `instanceof AdminApiError`.
    let data: Record<string, unknown> = {}
    if (text) {
      try {
        data = JSON.parse(text)
      } catch {
        // Respuesta no es JSON. Ronda 20 MEDIUM#3: no incluir el body raw en el
        // mensaje — si un componente lo renderiza con dangerouslySetInnerHTML
        // (comun para "raw error preview"), un gateway comprometido puede
        // inyectar <script> con acceso al localStorage (tokens). Solo el status
        // + code genérico.
        throw new AdminApiError(
          r.status,
          r.ok ? 'invalid_json_response' : 'gateway_error',
          `Respuesta no válida del servidor (HTTP ${r.status})`,
        )
      }
    }
    if (!r.ok) {
      const d = data as { error?: string; message?: string }
      throw new AdminApiError(r.status, d.error ?? 'http_error', d.message ?? d.error)
    }
    return data as T
  }

  private async attemptRefresh(): Promise<boolean> {
    if (!this.refreshToken) return false
    try {
      const r = await fetch(`${BASE_URL}/api/auth/refresh`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ refreshToken: this.refreshToken }),
      })
      if (!r.ok) { this.clearSession(); return false }
      const data = await r.json()
      this.setSession(data.jwt, data.refreshToken)
      return true
    } catch {
      this.clearSession()
      return false
    }
  }
}

export const adminApi = new AdminApi()

// ─── Tipos de facturación ─────────────────────────────────────────
export interface AdminInvoice {
  id: string
  series: string
  correlative: number
  number: string
  documentType: 'receipt' | 'invoice' | 'boleta'
  customerId: string | null
  customerDocType: 'DNI' | 'RUC' | 'CE' | 'PASSPORT' | null
  customerDoc: string | null
  customerName: string
  customerEmail: string | null
  customerAddress: string | null
  rechargeId: string | null
  rideId: string | null
  subtotal: number
  igv: number
  total: number
  currency: string
  items: Array<{ description: string; quantity: number; unitPrice: number; total: number }>
  status: 'issued' | 'sent' | 'paid' | 'voided' | 'sunat_pending' | 'sunat_sent' | 'sunat_error'
  pdfUrl: string | null
  xmlUrl: string | null
  issuedBy: string | null
  issuedAt: string
  voidedAt: string | null
  metadata: Record<string, unknown> | null
  createdAt: string
}

export interface AdminCreditNote {
  id: string
  series: string
  correlative: number
  number: string
  invoiceId: string
  invoiceNumber?: string
  invoiceCustomer?: string
  reason: 'anulacion' | 'devolucion' | 'descuento_global' | 'descuento_item' | 'ajuste_precio' | 'otros'
  reasonNotes: string | null
  amount: number
  status: 'issued' | 'sunat_pending' | 'sunat_sent' | 'sunat_error'
  pdfUrl: string | null
  xmlUrl: string | null
  issuedBy: string | null
  issuedAt: string
  createdAt: string
}
