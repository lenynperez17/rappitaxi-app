import { defineConfig, type Plugin } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

/** Límite de tamaño para el código propio, el mismo que trae Vite por defecto. */
const CHUNK_LIMIT_KB = 500

/**
 * Chunks de terceros que superan el límite por naturaleza y no se pueden partir.
 * `leaflet-mapbox-gl` es mapbox-gl (1,8 MB minificado, un solo módulo): se carga
 * bajo demanda desde VectorBasemap y solo lo descarga quien abre el mapa.
 */
const OVERSIZED_VENDOR_CHUNKS = ['leaflet-mapbox-gl']

/**
 * Ronda 287: sustituye el aviso global de Vite. Subir `chunkSizeWarningLimit`
 * para que quepa mapbox-gl dejaría crecer sin aviso al paquete principal; así
 * la vigilancia de 500 kB sigue intacta para todo lo que no sea esa librería.
 */
function chunkSizeGuard(): Plugin {
  return {
    name: 'rapi-chunk-size-guard',
    apply: 'build',
    generateBundle(_options, bundle) {
      for (const chunk of Object.values(bundle)) {
        if (chunk.type !== 'chunk') continue
        if (OVERSIZED_VENDOR_CHUNKS.some((name) => chunk.name === name)) continue
        const kb = Buffer.byteLength(chunk.code) / 1024
        if (kb > CHUNK_LIMIT_KB) {
          this.warn(`El chunk ${chunk.fileName} pesa ${kb.toFixed(0)} kB (límite ${CHUNK_LIMIT_KB} kB)`)
        }
      }
    },
  }
}

// Custom domain rapi-team.nynelmkt.cloud -> base '/'
export default defineConfig({
  base: '/',
  plugins: [
    react(),
    tailwindcss(),
    chunkSizeGuard(),
  ],
  build: {
    // El aviso nativo se desactiva aquí; lo reemplaza chunkSizeGuard().
    chunkSizeWarningLimit: Number.POSITIVE_INFINITY,
  },
})
