import { useEffect, useRef } from 'react'
import { useMap, useMapsLibrary } from '@vis.gl/react-google-maps'

export interface LatLng {
  lat: number
  lng: number
}

interface RoutePolylineProps {
  origin: LatLng | null
  destination: LatLng | null
  strokeColor?: string
  /**
   * If true, the map will auto-fit bounds to include the route every time
   * a new route is computed.
   */
  fitBounds?: boolean
  /**
   * Optional callback with route metadata (distance/duration) for display.
   */
  onRouteInfo?: (info: { distanceMeters: number; durationSeconds: number } | null) => void
}

/**
 * Draws a real driving route between origin and destination using
 * Google Maps DirectionsService.
 *
 * Note: `@vis.gl/react-google-maps` does not export a Polyline component,
 * so this wrapper uses the classic `google.maps.Polyline` API via
 * `useMap()` and the `routes` library, with proper cleanup.
 *
 * Debounced 800 ms to avoid burning DirectionsService quota while the
 * admin is still typing pickup/destination.
 */
export function RoutePolyline({
  origin,
  destination,
  strokeColor = '#E31E24',
  fitBounds = true,
  onRouteInfo,
}: RoutePolylineProps) {
  const map = useMap()
  const routesLib = useMapsLibrary('routes')
  const polylineRef = useRef<google.maps.Polyline | null>(null)
  const serviceRef = useRef<google.maps.DirectionsService | null>(null)

  useEffect(() => {
    if (!routesLib) return
    serviceRef.current = new routesLib.DirectionsService()
  }, [routesLib])

  useEffect(() => {
    if (!map || !routesLib) return

    // Always clear the previous polyline first
    if (polylineRef.current) {
      polylineRef.current.setMap(null)
      polylineRef.current = null
    }
    onRouteInfo?.(null)

    if (!origin || !destination || !serviceRef.current) return

    // Debounce so we don't fire the API on every keystroke
    const handle = setTimeout(() => {
      serviceRef.current!.route(
        {
          origin,
          destination,
          travelMode: google.maps.TravelMode.DRIVING,
          provideRouteAlternatives: false,
        },
        (result, status) => {
          if (status !== google.maps.DirectionsStatus.OK || !result?.routes?.[0]) {
            console.warn('DirectionsService failed:', status)
            return
          }
          const route = result.routes[0]
          const path = route.overview_path

          polylineRef.current = new google.maps.Polyline({
            path,
            strokeColor,
            strokeOpacity: 0.85,
            strokeWeight: 5,
            map,
          })

          // Compute metadata for display
          const leg = route.legs[0]
          if (leg && onRouteInfo) {
            onRouteInfo({
              distanceMeters: leg.distance?.value ?? 0,
              durationSeconds: leg.duration?.value ?? 0,
            })
          }

          if (fitBounds && route.bounds) {
            map.fitBounds(route.bounds, 80)
          }
        },
      )
    }, 800)

    return () => {
      clearTimeout(handle)
      if (polylineRef.current) {
        polylineRef.current.setMap(null)
        polylineRef.current = null
      }
    }
  }, [map, routesLib, origin, destination, strokeColor, fitBounds, onRouteInfo])

  // This component renders nothing — the polyline is attached to the map directly
  return null
}
