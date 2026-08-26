/**
 * Página a la que MercadoPago devuelve al usuario después de pagar.
 *
 * Ronda 280. `wallet/recharge/checkout/route.ts` lleva desde siempre unos
 * `back_urls` apuntando a `<api>/mp/return?status=…&ref=…`, y con
 * `auto_return: 'approved'` MercadoPago redirige aquí solo. Pero esta página
 * **no existía**: quien pagaba aterrizaba en un 404 del servidor.
 *
 * Dentro de la app casi nunca se llega a ver, porque la vista web intercepta
 * esta URL y cierra el checkout. Existe para lo demás: cuando el pago se abre
 * en el navegador del teléfono, o cuando el usuario vuelve atrás a mano.
 */
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Pago · Rapi Team',
  description: 'Resultado del pago en Rapi Team.',
}

const COPY: Record<string, { titulo: string; detalle: string; color: string }> = {
  success: {
    titulo: 'Pago recibido',
    detalle:
      'Ya puedes volver a la aplicación. Tu saldo aparecerá en unos segundos; ' +
      'si no lo ves, cierra y vuelve a abrir la billetera.',
    color: '#00A000',
  },
  pending: {
    titulo: 'Pago en proceso',
    detalle:
      'MercadoPago aún está confirmando el pago. Puedes volver a la aplicación: ' +
      'tu saldo se actualizará en cuanto se confirme.',
    color: '#E8A33D',
  },
  failure: {
    titulo: 'El pago no se completó',
    detalle:
      'No se te ha cobrado nada. Puedes volver a la aplicación e intentarlo de nuevo.',
    color: '#D32F2F',
  },
}

export default async function MercadoPagoReturnPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string; ref?: string }>
}) {
  const { status } = await searchParams
  const copy = COPY[status ?? ''] ?? {
    titulo: 'Volviendo a Rapi Team',
    detalle: 'Puedes cerrar esta ventana y volver a la aplicación.',
    color: '#FF6B00',
  }

  return (
    <main
      style={{
        maxWidth: '520px',
        margin: '0 auto',
        padding: '96px 24px',
        fontFamily: 'system-ui, -apple-system, Segoe UI, Roboto, sans-serif',
        textAlign: 'center',
      }}
    >
      <div
        style={{
          width: '72px',
          height: '72px',
          borderRadius: '50%',
          background: copy.color,
          margin: '0 auto 24px',
        }}
      />
      <h1 style={{ fontSize: '26px', margin: '0 0 12px', color: '#1a1a1a' }}>
        {copy.titulo}
      </h1>
      <p style={{ fontSize: '16px', lineHeight: 1.6, color: '#555', margin: 0 }}>
        {copy.detalle}
      </p>
    </main>
  )
}
