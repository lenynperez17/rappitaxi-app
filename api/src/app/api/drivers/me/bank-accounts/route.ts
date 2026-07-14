/**
 * GET/POST /api/drivers/me/bank-accounts
 * Cuentas bancarias del conductor autenticado (para retiros).
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { query, tx } from '@/lib/db'
import type { PoolClient } from 'pg'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

interface BankAccountRow {
  id: string
  bank_name: string
  account_type: 'savings' | 'checking'
  account_number: string
  cci: string | null
  holder_name: string
  holder_document: string
  is_default: boolean
  is_active: boolean
  created_at: Date
}

export async function GET(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response
  const rows = await query<BankAccountRow>(
    `SELECT id, bank_name, account_type, account_number, cci, holder_name,
            holder_document, is_default, is_active, created_at
       FROM driver_bank_accounts
      WHERE driver_id = $1 AND is_active = true
      ORDER BY is_default DESC, created_at DESC`,
    [auth.userId],
  )
  return NextResponse.json({
    success: true,
    accounts: rows.map((a) => ({
      id: a.id,
      bankName: a.bank_name,
      accountType: a.account_type,
      accountNumber: a.account_number,
      cci: a.cci,
      holderName: a.holder_name,
      holderDocument: a.holder_document,
      isDefault: a.is_default,
      createdAt: a.created_at,
    })),
  })
}

export async function POST(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  let body: {
    bankName?: string
    accountType?: string
    accountNumber?: string
    cci?: string
    holderName?: string
    holderDocument?: string
    isDefault?: boolean
  } = {}
  try { body = await req.json() } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }
  const bankName = body.bankName?.trim()
  const accountType = body.accountType?.trim()
  const accountNumber = body.accountNumber?.trim()
  const holderName = body.holderName?.trim()
  const holderDocument = body.holderDocument?.trim()
  const cci = body.cci?.trim() || null
  const isDefault = body.isDefault === true

  if (!bankName || !accountType || !accountNumber || !holderName || !holderDocument) {
    return NextResponse.json({ success: false, error: 'missing_fields' }, { status: 400 })
  }
  if (accountType !== 'savings' && accountType !== 'checking') {
    return NextResponse.json({ success: false, error: 'invalid_account_type' }, { status: 400 })
  }

  try {
    const acc = await tx(async (client: PoolClient) => {
      if (isDefault) {
        await client.query(
          `UPDATE driver_bank_accounts SET is_default = false WHERE driver_id = $1`,
          [auth.userId],
        )
      }
      const r = await client.query<BankAccountRow>(
        `INSERT INTO driver_bank_accounts
         (driver_id, bank_name, account_type, account_number, cci, holder_name, holder_document, is_default)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         RETURNING id, bank_name, account_type, account_number, cci, holder_name,
                   holder_document, is_default, is_active, created_at`,
        [auth.userId, bankName, accountType, accountNumber, cci, holderName, holderDocument, isDefault],
      )
      return r.rows[0]
    })
    return NextResponse.json({
      success: true,
      account: {
        id: acc.id,
        bankName: acc.bank_name,
        accountType: acc.account_type,
        accountNumber: acc.account_number,
        cci: acc.cci,
        holderName: acc.holder_name,
        holderDocument: acc.holder_document,
        isDefault: acc.is_default,
        createdAt: acc.created_at,
      },
    }, { status: 201 })
  } catch (e: unknown) {
    const err = e as { code?: string }
    if (err?.code === '23505') {
      return NextResponse.json({ success: false, error: 'account_already_exists' }, { status: 409 })
    }
    console.error('[bank-accounts POST]', e)
    return NextResponse.json({ success: false, error: 'internal_error' }, { status: 500 })
  }
}
