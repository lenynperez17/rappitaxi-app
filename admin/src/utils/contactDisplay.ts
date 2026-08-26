/**
 * Ronda 279 — cómo se muestra el contacto de alguien en los listados.
 *
 * Al borrar una cuenta, el backend deja una lápida: sustituye el correo por
 * `deleted-<uuid>@rapiteam.local` para liberar la dirección real sin romper las
 * claves foráneas de los viajes y las recargas que esa persona dejó atrás.
 *
 * Ese correo es un detalle interno, y se estaba pintando tal cual en el panel:
 * en el módulo Financiero salía una fila con un guion por nombre y
 * `deleted-748d9a74-…@rapiteam.local` debajo. No le dice nada a quien lee el
 * listado y ensucia la pantalla.
 */

const TOMBSTONE_DOMAIN = '@rapiteam.local'

/** `true` si ese correo es la lápida de una cuenta borrada. */
export function isDeletedAccountEmail(email: string | null | undefined): boolean {
  return typeof email === 'string' && email.endsWith(TOMBSTONE_DOMAIN)
}

/**
 * El contacto que tiene sentido enseñar: el teléfono si lo hay, si no el
 * correo, y nada si el correo es una lápida.
 */
export function contactLine(
  phone: string | null | undefined,
  email: string | null | undefined,
): string {
  if (phone) return phone
  if (email && !isDeletedAccountEmail(email)) return email
  return ''
}

/** El nombre que tiene sentido enseñar cuando la cuenta ya no existe. */
export function nameOrDeleted(name: string | null | undefined): string {
  return name && name.trim().length > 0 ? name : 'Cuenta eliminada'
}
