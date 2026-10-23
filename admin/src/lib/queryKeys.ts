import type { adminApi } from './adminApi'

/**
 * Ronda 287: fábrica tipada de claves de TanStack Query.
 *
 * Jerarquía `[recurso] → [recurso, 'list', filtros] / [recurso, 'detail', id]`:
 * invalidar `queryKeys.x.all` refresca listas y detalles del recurso, e
 * invalidar `queryKeys.x.lists()` solo las listas. Los filtros se tipan con los
 * parámetros reales de cada método de `adminApi`, así la clave no puede
 * desincronizarse de la petición que cachea.
 */
type FiltersOf<K extends keyof typeof adminApi> =
  (typeof adminApi)[K] extends (params?: infer P, ...rest: never[]) => unknown ? NonNullable<P> : never

export const queryKeys = {
  /** KPIs globales: los comparten Inicio, Analítica y Financiero. */
  stats: {
    all: ['stats'] as const,
  },
  users: {
    all: ['users'] as const,
    lists: () => [...queryKeys.users.all, 'list'] as const,
    list: (filters: FiltersOf<'listUsers'>) => [...queryKeys.users.lists(), filters] as const,
    detail: (id: string) => [...queryKeys.users.all, 'detail', id] as const,
  },
  drivers: {
    all: ['drivers'] as const,
    lists: () => [...queryKeys.drivers.all, 'list'] as const,
    list: (filters: FiltersOf<'listDrivers'>) => [...queryKeys.drivers.lists(), filters] as const,
  },
  trips: {
    all: ['trips'] as const,
    lists: () => [...queryKeys.trips.all, 'list'] as const,
    list: (filters: FiltersOf<'listTrips'>) => [...queryKeys.trips.lists(), filters] as const,
  },
  documents: {
    all: ['documents'] as const,
    lists: () => [...queryKeys.documents.all, 'list'] as const,
    list: (filters: FiltersOf<'listDocuments'>) => [...queryKeys.documents.lists(), filters] as const,
  },
  recharges: {
    all: ['recharges'] as const,
    lists: () => [...queryKeys.recharges.all, 'list'] as const,
    list: (filters: FiltersOf<'listRecharges'>) => [...queryKeys.recharges.lists(), filters] as const,
  },
  emergencies: {
    all: ['emergencies'] as const,
    lists: () => [...queryKeys.emergencies.all, 'list'] as const,
    list: (filters: FiltersOf<'listEmergencies'>) => [...queryKeys.emergencies.lists(), filters] as const,
  },
  cancellations: {
    all: ['cancellations'] as const,
    lists: () => [...queryKeys.cancellations.all, 'list'] as const,
    list: (filters: FiltersOf<'listCancellations'>) => [...queryKeys.cancellations.lists(), filters] as const,
  },
  invoices: {
    all: ['invoices'] as const,
    lists: () => [...queryKeys.invoices.all, 'list'] as const,
    list: (filters: FiltersOf<'listInvoices'>) => [...queryKeys.invoices.lists(), filters] as const,
  },
  creditNotes: {
    all: ['creditNotes'] as const,
    lists: () => [...queryKeys.creditNotes.all, 'list'] as const,
    list: (filters: FiltersOf<'listCreditNotes'>) => [...queryKeys.creditNotes.lists(), filters] as const,
  },
  vouchers: {
    all: ['vouchers'] as const,
    list: () => [...queryKeys.vouchers.all, 'list'] as const,
  },
  settings: {
    all: ['settings'] as const,
  },
  /** Foto del mapa en vivo: conductores en línea, desconectados y viajes activos. */
  live: {
    all: ['live'] as const,
  },
  /**
   * Ruta real de un viaje. `routeKey` ya codifica viaje + coordenadas (ver
   * LiveMapPage), así que solo cambia cuando el conductor se mueve.
   */
  directions: {
    all: ['directions'] as const,
    route: (routeKey: string) => [...queryKeys.directions.all, routeKey] as const,
  },
  /** Autocompletado de direcciones, sesgado por el centro del mapa al teclear. */
  places: {
    all: ['places'] as const,
    search: (text: string, center: { lat: number; lng: number } | null) =>
      [...queryKeys.places.all, text, center] as const,
  },
  serviceTypes: {
    all: ['serviceTypes'] as const,
  },
  documentTypes: {
    all: ['documentTypes'] as const,
  },
} as const
