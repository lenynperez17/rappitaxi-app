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
