/**
 * GET /api/account/export
 * Auth: Bearer <access_token>
 *
 * Retorna todos los datos personales del user en JSON.
 * Cumple GDPR Art. 20 "right to data portability" + Google Play "Data Safety"
 * que exige acceso a datos si la app ofrece delete.
 *
 * NO incluye:
 *   - password_hash (nunca)
 *   - private FCM tokens (device-specific)
 *   - refresh_token secrets
 *   - metadata interna de auditoría (auth_events con IP/UA de otros)
 *
 * SÍ incluye: perfil, rides, wallet_transactions, invoices, credit_notes,
 * emergencies, emergency_contacts, favorites, payment_methods, vehículos,
 * documentos (solo metadatos, no las fotos — el user las tiene ya).
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { query, maybeOne } from '@/lib/db'
import { ipRateLimit } from '@/lib/rate-limit'

export const runtime = 'nodejs'

export async function GET(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  // Rate limit: 3 exports/hora por IP. Sin esto, 100 concurrent GETs
  // podían disparar 8+ heavy queries + ~50MB JSON, spike DB + CPU.
  const rl = ipRateLimit(req, 'gdpr-export', { max: 3, windowMs: 60 * 60_000 })
  if (!rl.ok) {
    return NextResponse.json(
      { success: false, error: 'rate_limited',
        message: 'Máximo 3 exportaciones por hora. Espera unos minutos.' },
      { status: 429 },
    )
  }

  const user = await maybeOne(
    `SELECT id, full_name, display_name, email, phone, phone_number, user_type,
            is_admin, is_active, is_verified, email_verified, phone_verified,
            profile_photo_url, profile_complete, auth_provider,
            created_at, updated_at
       FROM users WHERE id = $1`,
    [auth.userId],
  )
  if (!user) {
    return NextResponse.json({ success: false, error: 'user_not_found' }, { status: 404 })
  }

  // Datos de viajes (como passenger o driver)
  const rides = await query(
    `SELECT id, passenger_id, driver_id, status, payment_method, vehicle_type,
            estimated_fare, final_fare, distance_meters, duration_seconds,
            pickup_address, pickup_lat, pickup_lng,
            destination_address, destination_lat, destination_lng,
            passenger_rating, driver_rating,
            cancelled_by, cancelled_reason,
            accepted_at, started_at, completed_at, created_at
       FROM rides
       WHERE passenger_id = $1 OR driver_id = $1
       ORDER BY created_at DESC LIMIT 1000`,
    [auth.userId],
  )

  // Wallet transactions — excluir type='commission' (ver migración 019).
  // Esas filas usan user_id como bucket contable, no representan transacción
  // real del usuario. Incluirlas en el export GDPR/LPDP crea evidencia legal
  // firmada donde el sistema declara "+ S/X por comisión de viaje" al pasajero.
  const walletTx = await query(
    `SELECT id, type, amount, description, status, ride_id, external_ref,
            balance_after, completed_at, created_at
       FROM wallet_transactions
       WHERE user_id = $1 AND type != 'commission'
       ORDER BY created_at DESC LIMIT 5000`,
    [auth.userId],
  )

  // Invoices (como customer). Ronda 84: incluir voided_at para no exportar
  // documentos anulados como evidencia fiscal válida.
  const invoices = await query(
    `SELECT id, series, correlative, document_type, customer_name,
            customer_doc, customer_doc_type, subtotal, igv, total, status,
            issued_at, voided_at,
            metadata->>'voidReason' AS void_reason
       FROM invoices
       WHERE customer_id = $1
       ORDER BY issued_at DESC LIMIT 500`,
    [auth.userId],
  )
  // Credit notes emitidas contra facturas del usuario (Ronda 84):
  // el docstring GDPR/Art.20 prometia incluirlas y no lo hacía.
  const creditNotes = await query(
    `SELECT cn.id, cn.series, cn.correlative, cn.invoice_id,
            cn.reason, cn.reason_notes, cn.amount, cn.status, cn.issued_at
       FROM credit_notes cn
       JOIN invoices i ON i.id = cn.invoice_id
       WHERE i.customer_id = $1
       ORDER BY cn.issued_at DESC LIMIT 500`,
    [auth.userId],
  )

  // Emergencies (solo propias)
  const emergencies = await query(
    `SELECT id, type, status, latitude, longitude, address, description,
            resolved_at, created_at
       FROM emergencies
       WHERE user_id = $1
       ORDER BY created_at DESC LIMIT 100`,
    [auth.userId],
  )

  // Emergency contacts
  const emergencyContacts = await query(
    `SELECT id, name, phone, relationship, is_primary, created_at
       FROM emergency_contacts
       WHERE user_id = $1`,
    [auth.userId],
  )

  // Favoritos
  const favorites = await query(
    `SELECT id, label, address, latitude, longitude, icon, created_at
       FROM user_favorites
       WHERE user_id = $1
       ORDER BY created_at DESC LIMIT 100`,
    [auth.userId],
  )

  // Payment methods (solo metadata, nunca full card number)
  const paymentMethods = await query(
    `SELECT id, method_type, label, is_default, created_at
       FROM user_payment_methods
       WHERE user_id = $1`,
    [auth.userId],
  )

  // Driver-specific (si aplica)
  const isDriver = (user as { user_type: string }).user_type === 'driver'
    || (user as { user_type: string }).user_type === 'dual'

  const vehicles = isDriver
    ? await query(
        `SELECT id, vehicle_type, plate, make, model, color, year, is_active, created_at
           FROM driver_vehicles WHERE driver_id = $1`,
        [auth.userId],
      )
    : []

  const documents = isDriver
    ? await query(
        `SELECT id, doc_type, status, rejection_reason, reviewed_at,
                expires_at, created_at, updated_at
           FROM driver_documents WHERE driver_id = $1`,
        [auth.userId],
      )
    : []

  const bankAccounts = isDriver
    ? await query(
        `SELECT id, bank_name, account_type,
                RIGHT(account_number, 4) AS account_last4,
                RIGHT(cci, 4) AS cci_last4,
                holder_name, holder_document, is_default, is_active, created_at
           FROM driver_bank_accounts WHERE driver_id = $1`,
        [auth.userId],
      )
    : []

  const withdrawals = isDriver
    ? await query(
        `SELECT id, bank_account_id, amount, fee, net_amount, status,
                reject_reason, approved_at, completed_at, created_at
           FROM wallet_withdrawals WHERE driver_id = $1
           ORDER BY created_at DESC LIMIT 500`,
        [auth.userId],
      )
    : []

  return NextResponse.json({
    success: true,
    exportedAt: new Date().toISOString(),
    userId: auth.userId,
    notice: 'Este archivo contiene tus datos personales según GDPR Art. 20 / Google Play Data Safety.',
    profile: user,
    rides,
    walletTransactions: walletTx,
    invoices,
    creditNotes,
    emergencies,
    emergencyContacts,
    favorites,
    paymentMethods,
    driver: isDriver ? {
      vehicles,
      documents,
      bankAccounts,
      withdrawals,
    } : null,
  })
}
