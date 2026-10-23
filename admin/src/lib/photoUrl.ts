/**
 * Normaliza la URL de foto de perfil que devuelve la API para pasarla a <Avatar>.
 *
 * Ronda 287: antes vivía en Avatar.tsx como `pickPhotoUrl(data: any)` y buscaba
 * `data.profilePhotoUrl` dentro de un objeto, pero todas las páginas le pasaban
 * ya la URL (`pickPhotoUrl(d.profilePhotoUrl)`). Leer `.profilePhotoUrl` de un
 * string da `undefined`, así que el panel nunca mostraba fotos, solo iniciales.
 */
export function pickPhotoUrl(url: string | null | undefined): string | null {
  const trimmed = url?.trim()
  return trimmed ? trimmed : null
}
