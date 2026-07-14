import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

// Custom domain panel-rapi-team.nyneln8n.com -> base '/'
export default defineConfig({
  base: '/',
  plugins: [
    react(),
    tailwindcss(),
  ],
})
