/**
 * PM2 ecosystem para Rapi-Team-App-Api (VPS).
 * Se hace SCP a /var/www/Rapi-Team-App-Api/ecosystem.config.cjs y luego:
 *   pm2 delete Rapi-Team-App-Api 2>/dev/null; pm2 start ecosystem.config.cjs; pm2 save
 *
 * IMPORTANTE: Next 16 standalone server.js NO lee .env — hay que pasarlo todo
 * por env aquí. El archivo .env real vive en el VPS y no se commitea.
 */
const fs = require('fs')
const path = require('path')

// Cargar el .env manualmente porque PM2 no lo hace por sí solo con standalone
function loadDotenv(file) {
  const out = {}
  if (!fs.existsSync(file)) return out
  const lines = fs.readFileSync(file, 'utf-8').split(/\r?\n/)
  for (const line of lines) {
    const t = line.trim()
    if (!t || t.startsWith('#')) continue
    const idx = t.indexOf('=')
    if (idx === -1) continue
    let k = t.slice(0, idx).trim()
    let v = t.slice(idx + 1).trim()
    // quitar comillas si las tiene
    if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) {
      v = v.slice(1, -1)
    }
    out[k] = v
  }
  return out
}

const envFromFile = loadDotenv(path.join(__dirname, '.env'))

module.exports = {
  apps: [
    {
      name: 'Rapi-Team-App-Api',
      script: '.next/standalone/server.js',
      cwd: __dirname,
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      max_restarts: 20,
      min_uptime: 10000,
      max_memory_restart: '512M',
      env: {
        NODE_ENV: 'production',
        PORT: '3120',
        HOSTNAME: '127.0.0.1',
        ...envFromFile,
        // fijar overrides que SIEMPRE deben ganar
        PORT_OVERRIDE: '3120',
      },
    },
  ],
}
