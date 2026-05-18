/**
 * Inicialización unificada de Firebase Admin SDK
 * Soporta tanto variables de entorno como archivo de credenciales
 */

import * as admin from 'firebase-admin';
import * as path from 'path';
import * as fs from 'fs';
import dotenv from 'dotenv';

dotenv.config();

let firebaseInitialized = false;

export function initializeFirebaseAdmin() {
  // Si ya está inicializado, no hacer nada
  if (firebaseInitialized || admin.apps.length > 0) {
    console.log('✅ Firebase Admin ya está inicializado');
    return;
  }

  try {
    let credential: admin.credential.Credential;
    
    // Primero intentar con GOOGLE_APPLICATION_CREDENTIALS (para tests)
    if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      const serviceAccountPath = path.resolve(process.env.GOOGLE_APPLICATION_CREDENTIALS);
      
      if (fs.existsSync(serviceAccountPath)) {
        console.log('🔑 Usando archivo de credenciales:', serviceAccountPath);
        const serviceAccount = require(serviceAccountPath);
        credential = admin.credential.cert(serviceAccount);
      } else {
        console.warn('⚠️ Archivo de credenciales no encontrado:', serviceAccountPath);
        throw new Error('Archivo de credenciales no encontrado');
      }
    }
    // Si no hay archivo, intentar con variables de entorno individuales
    else if (process.env.FIREBASE_PRIVATE_KEY && process.env.FIREBASE_CLIENT_EMAIL) {
      console.log('🔑 Usando variables de entorno para credenciales');
      const serviceAccountConfig: any = {
        projectId: process.env.FIREBASE_PROJECT_ID || 'rapi-team',
        privateKey: (process.env.FIREBASE_PRIVATE_KEY || '').replace(/\\n/g, '\n'),
        clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      };
      
      // Agregar campos opcionales si están disponibles
      if (process.env.FIREBASE_PRIVATE_KEY_ID) {
        serviceAccountConfig.privateKeyId = process.env.FIREBASE_PRIVATE_KEY_ID;
      }
      if (process.env.FIREBASE_CLIENT_ID) {
        serviceAccountConfig.clientId = process.env.FIREBASE_CLIENT_ID;
      }
      
      credential = admin.credential.cert(serviceAccountConfig);
    }
    // Como último recurso, intentar con el archivo en la raíz del proyecto
    else {
      const defaultServiceAccountPath = path.resolve(__dirname, '../../rapi-team-firebase-adminsdk-fbsvc-deb77aff98.json');
      
      if (fs.existsSync(defaultServiceAccountPath)) {
        console.log('🔑 Usando archivo de credenciales por defecto:', defaultServiceAccountPath);
        const serviceAccount = require(defaultServiceAccountPath);
        credential = admin.credential.cert(serviceAccount);
      } else {
        // Si estamos en modo test, intentar Application Default Credentials
        if (process.env.NODE_ENV === 'test') {
          console.log('🔑 Intentando con Application Default Credentials (test mode)');
          credential = admin.credential.applicationDefault();
        } else {
          throw new Error('No se encontraron credenciales de Firebase válidas');
        }
      }
    }

    // Inicializar Firebase Admin con las credenciales encontradas
    admin.initializeApp({
      credential: credential,
      projectId: process.env.FIREBASE_PROJECT_ID || 'rapi-team',
      databaseURL: process.env.FIREBASE_DATABASE_URL || 'https://rapi-team-default-rtdb.firebaseio.com',
      storageBucket: process.env.FIREBASE_STORAGE_BUCKET || 'rapi-team.firebasestorage.app'
    });

    // Configurar Firestore
    const db = admin.firestore();
    db.settings({
      ignoreUndefinedProperties: true,
      timestampsInSnapshots: true
    });

    firebaseInitialized = true;
    console.log('✅ Firebase Admin inicializado correctamente');
    console.log('📊 Project ID:', process.env.FIREBASE_PROJECT_ID || 'rapi-team');
    
  } catch (error) {
    console.error('❌ Error inicializando Firebase Admin:', error);
    
    // En modo test, intentar continuar de todos modos
    if (process.env.NODE_ENV === 'test') {
      console.log('⚠️ Continuando en modo test sin Firebase inicializado completamente');
    } else {
      throw error;
    }
  }
}

// Función helper para reinicializar (útil para tests)
export function resetFirebaseAdmin() {
  if (admin.apps.length > 0) {
    admin.apps.forEach(app => {
      app?.delete();
    });
  }
  firebaseInitialized = false;
}

// Exportar instancias de servicios
export function getFirestore() {
  initializeFirebaseAdmin();
  return admin.firestore();
}

export function getAuth() {
  initializeFirebaseAdmin();
  return admin.auth();
}

export function getMessaging() {
  initializeFirebaseAdmin();
  return admin.messaging();
}

export function getStorage() {
  initializeFirebaseAdmin();
  return admin.storage();
}

// Inicializar automáticamente al importar
initializeFirebaseAdmin();