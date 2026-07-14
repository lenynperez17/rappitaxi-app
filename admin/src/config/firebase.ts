/**
 * Firebase config — RETIRADO.
 *
 * El panel admin ya no depende de Firebase. Toda la autenticación y CRUD pasan
 * por el backend Node (rapi-team-api.nynelmkt.cloud) sobre Postgres.
 *
 * Este archivo se mantiene con shims vacíos para no romper imports pendientes
 * que puedan quedar en el bundle. Si algún código intenta usarlos, tira error.
 */
const notAvailable: ProxyHandler<object> = {
  get() { throw new Error('Firebase fue retirado del panel. Usa adminApi en su lugar.') },
}

export const auth = new Proxy({}, notAvailable) as never
export const db = new Proxy({}, notAvailable) as never
export const storage = new Proxy({}, notAvailable) as never
export const functions = new Proxy({}, notAvailable) as never

export default {}
