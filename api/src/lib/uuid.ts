/**
 * Helper compartido para validar UUIDs antes de pasarlos a Postgres.
 * Sin este check, un `WHERE id = 'abc'` sobre una columna UUID tira 22P02
 * (invalid input syntax for uuid) → 500 opaco al usuario. El check reduce
 * a 400 explícito.
 */
const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

export function isUuid(s: string | null | undefined): boolean {
  if (!s) return false
  return UUID_RE.test(s)
}

/**
 * Ronda 272: identificador de usuario.
 *
 * `users.id` es **text**, no uuid, porque la app nació en Firebase y al migrar
 * al backend propio las cuentas de entonces conservaron su UID
 * (`WyAwOzqKEbdpSky5qHH2hI8dF6J3`, 28 caracteres sin guiones). Las creadas
 * después sí son UUID. Hoy conviven ambos formatos: 49 de 111 cuentas activas
 * son del primero.
 *
 * Validarlas con `isUuid` —como venían haciendo las rutas de administración—
 * rechazaba de plano a esas 49 con un 400: no se las podía ver, ni editar, ni
 * suspender, ni borrar, ni cambiarles la contraseña. Y el 22P02 del que
 * protegía `isUuid` ni siquiera puede darse aquí: sobre una columna de texto
 * cualquier cadena es una comparación válida.
 *
 * Se acepta lo que ambos formatos tienen en común y nada más: la consulta va
 * parametrizada, así que esto no defiende de inyección —de eso ya se encarga
 * el driver—, sino que descarta basura antes de llegar a la base de datos.
 */
const USER_ID_RE = /^[A-Za-z0-9_-]{1,128}$/

export function isUserId(s: string | null | undefined): boolean {
  if (!s) return false
  return USER_ID_RE.test(s)
}
