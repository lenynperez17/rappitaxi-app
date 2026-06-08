/**
 * Backend Proxy de Maps con CASCADA DE PROVEEDORES.
 *
 * Estrategia: maximizar uso de proveedores gratis, Google solo como último recurso.
 *
 *   Routing (Directions):
 *     1. OSRM self-host (VPS Nynel) ─ GRATIS ilimitado
 *     2. Mapbox Directions API ────── GRATIS hasta 100k req/mes
 *     3. Google Directions API ────── caro, solo emergencia
 *
 *   Geocoding (forward/reverse) y Places (Autocomplete/Details):
 *     1. Mapbox API ──────────────── GRATIS hasta 100k req/mes
 *     2. Google API ─────────────── caro, solo emergencia
 *     (OSRM no provee geocoding ni places)
 *
 * Las 3 callables exigen auth (request.auth) — solo usuarios autenticados de
 * Plus App pueden consumirlas. Cache in-memory 1h para reducir aún más calls
 * a proveedores cuando varios usuarios buscan lo mismo.
 *
 * Env vars requeridas en functions/.env:
 *   OSRM_URL              — ej. https://osrm.nynelmkt.cloud
 *   MAPBOX_ACCESS_TOKEN   — pk.eyJ1Ijo... (gratis sin tarjeta)
 *   GOOGLE_MAPS_API_KEY   — fallback (puede quedar vacío si se acepta degradar)
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import axios from 'axios';
import { randomUUID } from 'node:crypto';

const OSRM_URL = (process.env.OSRM_URL || '').replace(/\/$/, '');
const MAPBOX_TOKEN = process.env.MAPBOX_ACCESS_TOKEN || '';
const GOOGLE_KEY = process.env.GOOGLE_MAPS_API_KEY || '';

const CACHE_TTL_MS = 60 * 60 * 1000; // 1 hora

interface CacheEntry<T> {
  value: T;
  expiresAt: number;
}

const directionsCache = new Map<string, CacheEntry<DirectionsResult>>();
const autocompleteCache = new Map<string, CacheEntry<AutocompleteResult>>();
const placeDetailsCache = new Map<string, CacheEntry<PlaceDetailsResult>>();

interface DirectionsResult {
  /** Polyline encoded (formato Google polyline5, todos los proveedores se normalizan a esto). */
  polyline: string;
  distanceMeters: number;
  durationSeconds: number;
  /** Indica qué proveedor terminó respondiendo — útil para métricas/logs. */
  provider: 'osrm' | 'mapbox' | 'google';
}

interface AutocompletePrediction {
  description: string;
  placeId: string;
  mainText: string;
  secondaryText: string;
  /** Distancia en metros desde `proximity` (si se pasó). Null si no aplica. */
  distanceMeters?: number | null;
}

interface AutocompleteResult {
  predictions: AutocompletePrediction[];
  provider: 'mapbox' | 'google';
}

interface PlaceDetailsResult {
  placeId: string;
  name: string;
  formattedAddress: string;
  lat: number;
  lng: number;
  provider: 'mapbox' | 'google';
}

// ════════════════════════════════════════════════════════════════════
// Helpers compartidos
// ════════════════════════════════════════════════════════════════════

function getCached<T>(map: Map<string, CacheEntry<T>>, key: string): T | null {
  const entry = map.get(key);
  if (!entry) return null;
  if (entry.expiresAt < Date.now()) {
    map.delete(key);
    return null;
  }
  return entry.value;
}

function setCached<T>(map: Map<string, CacheEntry<T>>, key: string, value: T): void {
  map.set(key, { value, expiresAt: Date.now() + CACHE_TTL_MS });
}

function assertAuth(auth: unknown): asserts auth is { uid: string } {
  if (!auth || typeof (auth as { uid?: unknown }).uid !== 'string') {
    throw new HttpsError('unauthenticated', 'Usuario no autenticado');
  }
}

// Nota: OSRM y Mapbox aceptan ?geometries=polyline para devolver polyline encoded
// directo (igual formato que Google). No necesitamos decodificar/re-encodear GeoJSON.

// ════════════════════════════════════════════════════════════════════
// PROVIDER 1: OSRM (self-hosted, free unlimited)
// ════════════════════════════════════════════════════════════════════

async function fetchOSRMDirections(
  originLat: number,
  originLng: number,
  destLat: number,
  destLng: number,
): Promise<DirectionsResult> {
  if (!OSRM_URL) throw new Error('OSRM_URL no configurado');

  // OSRM espera: /route/v1/{profile}/{lng1,lat1};{lng2,lat2}
  // overview=full → geometría completa; geometries=polyline → encoded polyline directo
  const url = `${OSRM_URL}/route/v1/driving/${originLng},${originLat};${destLng},${destLat}`;
  const response = await axios.get(url, {
    params: { overview: 'full', geometries: 'polyline' },
    timeout: 8000,
  });

  const data = response.data;
  if (data?.code !== 'Ok') {
    throw new Error(`OSRM code=${data?.code} message=${data?.message ?? ''}`);
  }

  const route = data.routes?.[0];
  if (!route?.geometry) throw new Error('OSRM sin rutas');

  return {
    polyline: route.geometry,
    distanceMeters: Math.round(route.distance ?? 0),
    durationSeconds: Math.round(route.duration ?? 0),
    provider: 'osrm',
  };
}

// ════════════════════════════════════════════════════════════════════
// PROVIDER 2: Mapbox (free 100k/mes)
// ════════════════════════════════════════════════════════════════════

async function fetchMapboxDirections(
  originLat: number,
  originLng: number,
  destLat: number,
  destLng: number,
): Promise<DirectionsResult> {
  if (!MAPBOX_TOKEN) throw new Error('MAPBOX_ACCESS_TOKEN no configurado');

  const url = `https://api.mapbox.com/directions/v5/mapbox/driving/${originLng},${originLat};${destLng},${destLat}`;
  const response = await axios.get(url, {
    params: {
      overview: 'full',
      geometries: 'polyline',
      access_token: MAPBOX_TOKEN,
    },
    timeout: 8000,
  });

  const route = response.data?.routes?.[0];
  if (!route?.geometry) throw new Error('Mapbox sin rutas');

  return {
    polyline: route.geometry,
    distanceMeters: Math.round(route.distance ?? 0),
    durationSeconds: Math.round(route.duration ?? 0),
    provider: 'mapbox',
  };
}

async function fetchMapboxAutocomplete(
  query: string,
  countryCode: string,
  languageCode: string,
  userLat?: number,
  userLng?: number,
  sessionToken?: string,
): Promise<AutocompleteResult> {
  if (!MAPBOX_TOKEN) throw new Error('MAPBOX_ACCESS_TOKEN no configurado');

  // Search Box API v1 (no v5 Geocoding legacy).
  // Razón: Geocoding v5 — incluso con types=poi — tiene cobertura pobre de POIs
  // famosos en LatAm. Verificado: "parque kennedy" desde Lima en v5 NO retorna
  // el POI de Miraflores; en Search Box SÍ. Search Box está diseñada para
  // autocomplete interactivo con ranking optimizado para lugares populares.
  // proximity: Mapbox prioriza resultados cercanos. Formato "lng,lat".
  // session_token: empareja /suggest con /retrieve como "sesión" para facturación
  // (free tier 100k sesiones/mes vs N llamadas individuales).
  const params: Record<string, unknown> = {
    q: query,
    language: languageCode,
    country: countryCode,
    limit: 7,
    session_token: sessionToken ?? randomUUID(),
    access_token: MAPBOX_TOKEN,
  };
  if (typeof userLat === 'number' && typeof userLng === 'number') {
    params.proximity = `${userLng},${userLat}`;
  }

  const url = `https://api.mapbox.com/search/searchbox/v1/suggest`;
  const response = await axios.get(url, {
    params,
    timeout: 4000, // Si Mapbox demora más, asumir falla y caer a Google rápido
  });

  const suggestions = (response.data?.suggestions ?? []) as Array<{
    name?: string;
    mapbox_id?: string;
    place_formatted?: string;
    full_address?: string;
    feature_type?: string;
    distance?: number; // ← metros desde proximity, solo si se pasó proximity
    poi_category?: string[]; // ← categorías Mapbox (park, restaurant, etc.)
  }>;
  const predictions: AutocompletePrediction[] = suggestions
    .filter((s) => s.mapbox_id) // descartar suggestions sin ID (no se podrían retrieve)
    // Filtrar POIs sin categoría: Airbnbs sin contexto comercial, baños
    // públicos ("SSHH"), y similares devuelven poi_category vacío y son ruido
    // para una app de taxi. Address/place/locality NO tienen poi_category y
    // por eso quedan exentos del filtro.
    .filter((s) => {
      if (s.feature_type !== 'poi') return true;
      const cats = s.poi_category;
      return Array.isArray(cats) && cats.length > 0;
    })
    .map((s) => {
      const name = s.name ?? '';
      const secondary = s.place_formatted ?? s.full_address ?? '';
      return {
        description: secondary ? `${name}, ${secondary}` : name,
        placeId: s.mapbox_id ?? '',
        mainText: name,
        secondaryText: secondary,
        distanceMeters: typeof s.distance === 'number' ? Math.round(s.distance) : null,
      };
    });

  return { predictions, provider: 'mapbox' };
}

async function fetchMapboxPlaceDetails(
  placeId: string,
  sessionToken?: string,
): Promise<PlaceDetailsResult> {
  if (!MAPBOX_TOKEN) throw new Error('MAPBOX_ACCESS_TOKEN no configurado');

  // Search Box retrieve — toma el mapbox_id devuelto por /suggest.
  // Debe usar el MISMO session_token que el /suggest correspondiente para
  // que Mapbox cobre como una sesión (free tier).
  const url = `https://api.mapbox.com/search/searchbox/v1/retrieve/${encodeURIComponent(placeId)}`;
  const response = await axios.get(url, {
    params: {
      session_token: sessionToken ?? randomUUID(),
      access_token: MAPBOX_TOKEN,
    },
    timeout: 8000,
  });

  const features = (response.data?.features ?? []) as Array<{
    properties?: { name?: string; full_address?: string; place_formatted?: string; mapbox_id?: string };
    geometry?: { coordinates?: [number, number] };
  }>;
  if (features.length === 0) throw new Error('Mapbox retrieve sin features');

  const f = features[0];
  const coords = f.geometry?.coordinates;
  if (!coords || coords.length < 2) throw new Error('Mapbox place sin coordenadas');

  return {
    placeId: f.properties?.mapbox_id ?? placeId,
    name: f.properties?.name ?? '',
    formattedAddress: f.properties?.full_address ?? f.properties?.place_formatted ?? '',
    lng: coords[0],
    lat: coords[1],
    provider: 'mapbox',
  };
}

// ════════════════════════════════════════════════════════════════════
// PROVIDER 3: Google (último recurso, caro)
// ════════════════════════════════════════════════════════════════════

async function fetchGoogleDirections(
  originLat: number,
  originLng: number,
  destLat: number,
  destLng: number,
  mode: string,
): Promise<DirectionsResult> {
  if (!GOOGLE_KEY) throw new Error('GOOGLE_MAPS_API_KEY no configurado');

  const response = await axios.get('https://maps.googleapis.com/maps/api/directions/json', {
    params: {
      origin: `${originLat},${originLng}`,
      destination: `${destLat},${destLng}`,
      mode,
      key: GOOGLE_KEY,
    },
    timeout: 10000,
  });

  if (response.data?.status !== 'OK') {
    throw new Error(`Google status=${response.data?.status} ${response.data?.error_message ?? ''}`);
  }

  const route = response.data?.routes?.[0];
  const leg = route?.legs?.[0];
  if (!route?.overview_polyline?.points || !leg) throw new Error('Google sin rutas');

  return {
    polyline: route.overview_polyline.points,
    distanceMeters: leg.distance?.value ?? 0,
    durationSeconds: leg.duration?.value ?? 0,
    provider: 'google',
  };
}

async function fetchGoogleAutocomplete(
  query: string,
  sessionToken: string | undefined,
  countryCode: string,
  languageCode: string,
  userLat?: number,
  userLng?: number,
): Promise<AutocompleteResult> {
  if (!GOOGLE_KEY) throw new Error('GOOGLE_MAPS_API_KEY no configurado');

  // location + radius: Google prioriza resultados dentro del círculo de N metros.
  // 20 km cubre toda Lima Metropolitana (~50km de extremo a extremo).
  // Sin estos params, Google ordena por relevancia textual sin sesgo geográfico.
  const params: Record<string, unknown> = {
    input: query,
    sessiontoken: sessionToken,
    language: languageCode,
    components: `country:${countryCode}`,
    key: GOOGLE_KEY,
  };
  if (typeof userLat === 'number' && typeof userLng === 'number') {
    params.location = `${userLat},${userLng}`;
    params.radius = 20000; // 20 km
  }

  const response = await axios.get('https://maps.googleapis.com/maps/api/place/autocomplete/json', {
    params,
    timeout: 10000,
  });

  const status = response.data?.status;
  if (status !== 'OK' && status !== 'ZERO_RESULTS') {
    throw new Error(`Google Places status=${status}`);
  }

  const predictions: AutocompletePrediction[] = (response.data?.predictions ?? []).map((p: {
    description: string;
    place_id: string;
    structured_formatting?: { main_text?: string; secondary_text?: string };
  }) => ({
    description: p.description,
    placeId: p.place_id,
    mainText: p.structured_formatting?.main_text ?? p.description,
    secondaryText: p.structured_formatting?.secondary_text ?? '',
  }));

  return { predictions, provider: 'google' };
}

async function fetchGooglePlaceDetails(
  placeId: string,
  sessionToken: string | undefined,
): Promise<PlaceDetailsResult> {
  if (!GOOGLE_KEY) throw new Error('GOOGLE_MAPS_API_KEY no configurado');

  const response = await axios.get('https://maps.googleapis.com/maps/api/place/details/json', {
    params: {
      place_id: placeId,
      sessiontoken: sessionToken,
      fields: 'place_id,name,formatted_address,geometry/location',
      language: 'es',
      key: GOOGLE_KEY,
    },
    timeout: 10000,
  });

  if (response.data?.status !== 'OK') throw new Error(`Google Place Details status=${response.data?.status}`);

  const place = response.data?.result;
  if (!place?.geometry?.location) throw new Error('Google place sin coordenadas');

  return {
    placeId: place.place_id,
    name: place.name ?? '',
    formattedAddress: place.formatted_address ?? '',
    lat: place.geometry.location.lat,
    lng: place.geometry.location.lng,
    provider: 'google',
  };
}

// ════════════════════════════════════════════════════════════════════
// CALLABLES (expuestos al cliente)
// ════════════════════════════════════════════════════════════════════

/**
 * Proxy de Directions con cascada OSRM → Mapbox → Google.
 * Input:  { originLat, originLng, destLat, destLng, mode? }
 * Output: { polyline, distanceMeters, durationSeconds, provider }
 */
export const directionsProxy = onCall(async (request) => {
  assertAuth(request.auth);

  const { originLat, originLng, destLat, destLng, mode } = request.data ?? {};
  if (
    typeof originLat !== 'number' ||
    typeof originLng !== 'number' ||
    typeof destLat !== 'number' ||
    typeof destLng !== 'number'
  ) {
    throw new HttpsError('invalid-argument', 'Coordenadas inválidas');
  }
  const travelMode = typeof mode === 'string' ? mode : 'driving';

  const fmt = (v: number) => v.toFixed(5);
  const cacheKey = `${fmt(originLat)},${fmt(originLng)}|${fmt(destLat)},${fmt(destLng)}|${travelMode}`;

  const cached = getCached(directionsCache, cacheKey);
  if (cached) {
    console.log(`[mapsProxy] directions CACHE HIT ${cacheKey} provider=${cached.provider}`);
    return cached;
  }

  // Cascada de proveedores (de gratis a caro). Cada uno solo se intenta si el anterior tira excepción.
  const providers = [
    { name: 'osrm', fn: () => fetchOSRMDirections(originLat, originLng, destLat, destLng) },
    { name: 'mapbox', fn: () => fetchMapboxDirections(originLat, originLng, destLat, destLng) },
    { name: 'google', fn: () => fetchGoogleDirections(originLat, originLng, destLat, destLng, travelMode) },
  ];

  const errors: string[] = [];
  for (const provider of providers) {
    try {
      const result = await provider.fn();
      setCached(directionsCache, cacheKey, result);
      console.log(`[mapsProxy] directions ✅ ${provider.name} ${cacheKey} ${result.distanceMeters}m`);
      return result;
    } catch (error: unknown) {
      const msg = (error as { message?: string })?.message || String(error);
      errors.push(`${provider.name}:${msg}`);
      console.warn(`[mapsProxy] directions ❌ ${provider.name} falló: ${msg}`);
    }
  }

  throw new HttpsError('unavailable', `Todos los proveedores de directions fallaron: ${errors.join(' | ')}`);
});

/**
 * Proxy de Places Autocomplete con cascada Mapbox → Google.
 * Input:  { query, sessionToken?, languageCode?, countryCode?, userLat?, userLng? }
 * Output: { predictions: [...], provider }
 *
 * userLat/userLng sesgan resultados a la cercanía del usuario.
 * Sin esos coords, los resultados son de todo el país (mala UX para apps tipo taxi).
 */
export const placesAutocompleteProxy = onCall(async (request) => {
  assertAuth(request.auth);

  const { query, sessionToken, languageCode, countryCode, userLat, userLng } = request.data ?? {};
  if (typeof query !== 'string' || query.trim().length < 2) {
    throw new HttpsError('invalid-argument', 'query debe ser string con al menos 2 caracteres');
  }
  const lang = typeof languageCode === 'string' ? languageCode : 'es';
  const country = typeof countryCode === 'string' ? countryCode : 'pe';
  const lat = typeof userLat === 'number' ? userLat : undefined;
  const lng = typeof userLng === 'number' ? userLng : undefined;

  // Cache key: incluye coords bucketizadas a 2 decimales (~1.1 km de grilla).
  // Sin bucketing, cada coordenada única (cualquier punto exacto del GPS) tendría
  // su propio cache miss aunque varios usuarios estén en el mismo barrio.
  const geoBucket = lat !== undefined && lng !== undefined
    ? `${lat.toFixed(2)},${lng.toFixed(2)}`
    : 'no-geo';
  const cacheKey = `${query.toLowerCase().trim()}|${country}|${lang}|${geoBucket}`;
  const cached = getCached(autocompleteCache, cacheKey);
  if (cached) {
    console.log(`[mapsProxy] autocomplete CACHE HIT "${query}" geo=${geoBucket} provider=${cached.provider}`);
    return cached;
  }

  const providers = [
    { name: 'mapbox', fn: () => fetchMapboxAutocomplete(query, country, lang, lat, lng, sessionToken) },
    { name: 'google', fn: () => fetchGoogleAutocomplete(query, sessionToken, country, lang, lat, lng) },
  ];

  const errors: string[] = [];
  for (const provider of providers) {
    try {
      const result = await provider.fn();
      // Tratar predictions vacías como fallo del proveedor → escalar al siguiente.
      // Sin esto, Mapbox respondiendo {features: []} se considera éxito y Google
      // nunca se prueba aunque sí tenga el POI (caso "Parque Kennedy" reportado).
      if (result.predictions.length === 0) {
        throw new Error('zero results');
      }
      setCached(autocompleteCache, cacheKey, result);
      console.log(`[mapsProxy] autocomplete ✅ ${provider.name} "${query}" → ${result.predictions.length} predicciones`);
      return result;
    } catch (error: unknown) {
      const msg = (error as { message?: string })?.message || String(error);
      errors.push(`${provider.name}:${msg}`);
      console.warn(`[mapsProxy] autocomplete ❌ ${provider.name} falló: ${msg}`);
    }
  }

  throw new HttpsError('unavailable', `Todos los proveedores de places fallaron: ${errors.join(' | ')}`);
});

/**
 * Proxy de Place Details con cascada Mapbox → Google.
 * Input:  { placeId, sessionToken? }
 * Output: { placeId, name, formattedAddress, lat, lng, provider }
 *
 * Nota: el placeId debe ser del MISMO proveedor que se usó para Autocomplete
 * (Mapbox IDs son distintos a Google IDs). El cliente debe trackear de qué
 * proveedor viene el placeId. Por defecto intenta Mapbox primero (Mapbox IDs
 * empiezan con 'place.', 'poi.', etc).
 */
export const placeDetailsProxy = onCall(async (request) => {
  assertAuth(request.auth);

  const { placeId, sessionToken } = request.data ?? {};
  if (typeof placeId !== 'string' || placeId.length === 0) {
    throw new HttpsError('invalid-argument', 'placeId requerido');
  }

  const cached = getCached(placeDetailsCache, placeId);
  if (cached) {
    console.log(`[mapsProxy] placeDetails CACHE HIT ${placeId} provider=${cached.provider}`);
    return cached;
  }

  // Heurística para elegir orden de proveedor por formato de placeId:
  // - Mapbox Search Box IDs: base64 de "urn:mbxpoi:..." → empiezan con "dXJu"
  // - Mapbox legacy v5 IDs (cache antiguos): contienen '.' (ej "place.123")
  // - Google IDs: hashes opacos sin '.', empiezan con "ChIJ"
  const looksLikeMapboxId = placeId.startsWith('dXJu') || placeId.includes('.');
  const providers = looksLikeMapboxId
    ? [
        { name: 'mapbox', fn: () => fetchMapboxPlaceDetails(placeId, sessionToken) },
        { name: 'google', fn: () => fetchGooglePlaceDetails(placeId, sessionToken) },
      ]
    : [
        { name: 'google', fn: () => fetchGooglePlaceDetails(placeId, sessionToken) },
        { name: 'mapbox', fn: () => fetchMapboxPlaceDetails(placeId, sessionToken) },
      ];

  const errors: string[] = [];
  for (const provider of providers) {
    try {
      const result = await provider.fn();
      setCached(placeDetailsCache, placeId, result);
      console.log(`[mapsProxy] placeDetails ✅ ${provider.name} ${placeId}`);
      return result;
    } catch (error: unknown) {
      const msg = (error as { message?: string })?.message || String(error);
      errors.push(`${provider.name}:${msg}`);
      console.warn(`[mapsProxy] placeDetails ❌ ${provider.name} falló: ${msg}`);
    }
  }

  throw new HttpsError('unavailable', `Todos los proveedores de place details fallaron: ${errors.join(' | ')}`);
});
