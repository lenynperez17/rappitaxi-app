// Jest setup - REAL Firebase configuration
const path = require('path');

// Set Firebase Admin SDK credentials environment variable
process.env.GOOGLE_APPLICATION_CREDENTIALS = path.resolve(__dirname, 'rapiteam-peru-firebase-adminsdk-fbsvc-deb77aff98.json');

// Set test environment variables
process.env.JWT_SECRET = 'test-secret-key-for-rapiteam';
process.env.NODE_ENV = 'test';

console.log('✅ Firebase Real configurado con credenciales:', process.env.GOOGLE_APPLICATION_CREDENTIALS);