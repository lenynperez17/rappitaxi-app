import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

// Custom domain rapi-team.nynelmkt.cloud -> base '/'
export default defineConfig({
  base: '/',
  plugins: [
    react(),
    tailwindcss(),
  ],
})
