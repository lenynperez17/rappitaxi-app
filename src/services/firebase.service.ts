/**
 * 🔥 Firebase Admin SDK Service - Configuración Enterprise
 * Sistema centralizado de Firebase para autenticación, storage y notificaciones
 */

import * as admin from 'firebase-admin';
import { initializeFirebaseAdmin, getFirestore, getAuth, getMessaging, getStorage } from '../config/firebase-init';
import { logger } from '../utils/logger';

export class FirebaseService {
  private static instance: FirebaseService;
  private db: admin.firestore.Firestore;
  private auth: admin.auth.Auth;
  private messaging: admin.messaging.Messaging;
  private storage: admin.storage.Storage;
  private initialized: boolean = false;

  private constructor() {
    this.initializeFirebase();
  }

  private initializeFirebase(): void {
    try {
      // Usar la inicialización unificada
      initializeFirebaseAdmin();

      // Obtener las instancias de los servicios
      this.db = getFirestore();
      this.auth = getAuth();
      this.messaging = getMessaging();
      this.storage = getStorage();

      this.initialized = true;
      logger.info('✅ Firebase Admin SDK inicializado correctamente desde FirebaseService');
    } catch (error) {
      logger.error('❌ Error inicializando Firebase Admin SDK:', error);
      // En modo test, continuar sin lanzar error
      if (process.env.NODE_ENV === 'test') {
        logger.warn('⚠️ Continuando en modo test sin Firebase completamente inicializado');
        // Inicializar con valores por defecto para tests
        this.db = admin.firestore();
        this.auth = admin.auth();
        this.messaging = admin.messaging();
        this.storage = admin.storage();
        this.initialized = true;
      } else {
        throw new Error('Error crítico: No se pudo inicializar Firebase');
      }
    }
  }

  // Singleton pattern
  public static getInstance(): FirebaseService {
    if (!FirebaseService.instance) {
      FirebaseService.instance = new FirebaseService();
    }
    return FirebaseService.instance;
  }

  // ========== AUTENTICACIÓN ==========

  /**
   * Crear usuario personalizado con rol
   */
  async createUser(email: string, password: string, displayName: string, role: 'passenger' | 'driver' | 'admin'): Promise<admin.auth.UserRecord> {
    try {
      const user = await this.auth.createUser({
        email,
        password,
        displayName,
        emailVerified: false
      });

      // Establecer claims personalizados para roles
      await this.auth.setCustomUserClaims(user.uid, { 
        role, 
        createdAt: Date.now(),
        isActive: true
      });

      // Crear documento de usuario en Firestore
      await this.db.collection('users').doc(user.uid).set({
        uid: user.uid,
        email,
        displayName,
        role,
        photoURL: null,
        phoneNumber: null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastLogin: null,
        isActive: true,
        isVerified: false,
        profile: {
          firstName: '',
          lastName: '',
          dateOfBirth: null,
          gender: null,
          address: null,
          emergencyContact: null
        },
        preferences: {
          language: 'es',
          currency: 'MXN',
          notifications: {
            rides: true,
            promotions: true,
            news: true,
            email: true,
            sms: true,
            push: true
          }
        },
        stats: role === 'driver' ? {
          totalRides: 0,
          rating: 5.0,
          earnings: 0,
          cancelRate: 0,
          acceptanceRate: 100
        } : {
          totalRides: 0,
          favoriteDrivers: [],
          savedLocations: []
        }
      });

      logger.info(`✅ Usuario creado: ${user.uid} - ${email} - Rol: ${role}`);
      return user;
    } catch (error) {
      logger.error('Error creando usuario:', error);
      throw error;
    }
  }

  /**
   * Verificar token personalizado
   */
  async verifyIdToken(idToken: string): Promise<admin.auth.DecodedIdToken> {
    try {
      const decodedToken = await this.auth.verifyIdToken(idToken);
      return decodedToken;
    } catch (error) {
      logger.error('Error verificando token:', error);
      throw error;
    }
  }

  /**
   * Generar token personalizado para autenticación
   */
  async createCustomToken(uid: string, claims?: object): Promise<string> {
    try {
      const token = await this.auth.createCustomToken(uid, claims);
      return token;
    } catch (error) {
      logger.error('Error creando token personalizado:', error);
      throw error;
    }
  }

  // ========== FIRESTORE ==========

  /**
   * Obtener usuario por ID
   */
  async getUserById(uid: string): Promise<any> {
    try {
      const userDoc = await this.db.collection('users').doc(uid).get();
      if (!userDoc.exists) {
        throw new Error('Usuario no encontrado');
      }
      return { id: userDoc.id, ...userDoc.data() };
    } catch (error) {
      logger.error('Error obteniendo usuario:', error);
      throw error;
    }
  }

  /**
   * Actualizar perfil de usuario
   */
  async updateUserProfile(uid: string, data: any): Promise<void> {
    try {
      await this.db.collection('users').doc(uid).update({
        ...data,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      logger.info(`✅ Perfil actualizado: ${uid}`);
    } catch (error) {
      logger.error('Error actualizando perfil:', error);
      throw error;
    }
  }

  /**
   * Crear viaje en Firestore
   */
  async createRide(rideData: any): Promise<string> {
    try {
      const ride = await this.db.collection('rides').add({
        ...rideData,
        status: 'searching',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      logger.info(`✅ Viaje creado: ${ride.id}`);
      return ride.id;
    } catch (error) {
      logger.error('Error creando viaje:', error);
      throw error;
    }
  }

  /**
   * Buscar conductores cercanos
   */
  async findNearbyDrivers(latitude: number, longitude: number, radiusKm: number = 5): Promise<any[]> {
    try {
      // Cálculo de límites geográficos (aproximación)
      const lat = 0.0144927536231884; // grados por km
      const lon = 0.0181818181818182; // grados por km

      const lowerLat = latitude - (lat * radiusKm);
      const upperLat = latitude + (lat * radiusKm);
      const lowerLon = longitude - (lon * radiusKm);
      const upperLon = longitude + (lon * radiusKm);

      const driversSnapshot = await this.db.collection('drivers')
        .where('isOnline', '==', true)
        .where('isAvailable', '==', true)
        .where('location.latitude', '>=', lowerLat)
        .where('location.latitude', '<=', upperLat)
        .get();

      const nearbyDrivers: any[] = [];
      driversSnapshot.forEach(doc => {
        const driver = doc.data();
        // Filtro adicional para longitud
        if (driver.location.longitude >= lowerLon && driver.location.longitude <= upperLon) {
          // Calcular distancia real
          const distance = this.calculateDistance(
            latitude, longitude,
            driver.location.latitude, driver.location.longitude
          );
          if (distance <= radiusKm) {
            nearbyDrivers.push({
              id: doc.id,
              ...driver,
              distance
            });
          }
        }
      });

      // Ordenar por distancia
      nearbyDrivers.sort((a, b) => a.distance - b.distance);
      logger.info(`✅ Encontrados ${nearbyDrivers.length} conductores en ${radiusKm}km`);
      
      return nearbyDrivers;
    } catch (error) {
      logger.error('Error buscando conductores:', error);
      throw error;
    }
  }

  /**
   * Calcular distancia entre dos puntos (Haversine)
   */
  private calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
    const R = 6371; // Radio de la Tierra en km
    const dLat = this.deg2rad(lat2 - lat1);
    const dLon = this.deg2rad(lon2 - lon1);
    const a = 
      Math.sin(dLat/2) * Math.sin(dLat/2) +
      Math.cos(this.deg2rad(lat1)) * Math.cos(this.deg2rad(lat2)) * 
      Math.sin(dLon/2) * Math.sin(dLon/2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    const distance = R * c;
    return distance;
  }

  private deg2rad(deg: number): number {
    return deg * (Math.PI/180);
  }

  // ========== NOTIFICACIONES PUSH ==========

  /**
   * Enviar notificación push a un dispositivo
   */
  async sendPushNotification(token: string, title: string, body: string, data?: any): Promise<string> {
    try {
      const message: admin.messaging.Message = {
        notification: {
          title,
          body,
        },
        data: data || {},
        token,
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
            channelId: 'rides'
          }
        },
        apns: {
          payload: {
            aps: {
              alert: {
                title,
                body
              },
              sound: 'default',
              badge: 1
            }
          }
        }
      };

      const response = await this.messaging.send(message);
      logger.info(`✅ Notificación enviada: ${response}`);
      return response;
    } catch (error) {
      logger.error('Error enviando notificación:', error);
      throw error;
    }
  }

  /**
   * Enviar notificación a múltiples dispositivos
   */
  async sendMulticastNotification(tokens: string[], title: string, body: string, data?: any): Promise<admin.messaging.BatchResponse> {
    try {
      const message: admin.messaging.MulticastMessage = {
        notification: {
          title,
          body,
        },
        data: data || {},
        tokens,
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK'
          }
        },
        apns: {
          payload: {
            aps: {
              alert: {
                title,
                body
              },
              sound: 'default'
            }
          }
        }
      };

      const response = await this.messaging.sendMulticast(message);
      logger.info(`✅ Notificaciones enviadas: ${response.successCount} éxitos, ${response.failureCount} fallos`);
      return response;
    } catch (error) {
      logger.error('Error enviando notificaciones múltiples:', error);
      throw error;
    }
  }

  /**
   * Suscribir a topic de notificaciones
   */
  async subscribeToTopic(tokens: string[], topic: string): Promise<admin.messaging.MessagingTopicManagementResponse> {
    try {
      const response = await this.messaging.subscribeToTopic(tokens, topic);
      logger.info(`✅ Suscrito a topic ${topic}: ${response.successCount} éxitos`);
      return response;
    } catch (error) {
      logger.error('Error suscribiendo a topic:', error);
      throw error;
    }
  }

  // ========== STORAGE ==========

  /**
   * Subir archivo a Firebase Storage
   */
  async uploadFile(filePath: string, destination: string): Promise<string> {
    try {
      const bucket = this.storage.bucket();
      const file = bucket.file(destination);
      
      await bucket.upload(filePath, {
        destination,
        metadata: {
          contentType: 'auto',
          cacheControl: 'public, max-age=31536000',
        }
      });

      // Hacer el archivo público
      await file.makePublic();
      
      const publicUrl = `https://storage.googleapis.com/${bucket.name}/${destination}`;
      logger.info(`✅ Archivo subido: ${publicUrl}`);
      return publicUrl;
    } catch (error) {
      logger.error('Error subiendo archivo:', error);
      throw error;
    }
  }

  /**
   * Eliminar archivo de Storage
   */
  async deleteFile(filePath: string): Promise<void> {
    try {
      const bucket = this.storage.bucket();
      await bucket.file(filePath).delete();
      logger.info(`✅ Archivo eliminado: ${filePath}`);
    } catch (error) {
      logger.error('Error eliminando archivo:', error);
      throw error;
    }
  }

  // ========== TRANSACCIONES Y BATCH ==========

  /**
   * Ejecutar transacción en Firestore
   */
  async runTransaction<T>(updateFunction: (transaction: admin.firestore.Transaction) => Promise<T>): Promise<T> {
    try {
      return await this.db.runTransaction(updateFunction);
    } catch (error) {
      logger.error('Error en transacción:', error);
      throw error;
    }
  }

  /**
   * Operaciones batch
   */
  createBatch(): admin.firestore.WriteBatch {
    return this.db.batch();
  }

  // ========== GETTERS ==========

  get firestore(): admin.firestore.Firestore {
    if (!this.initialized) {
      throw new Error('Firebase no está inicializado');
    }
    return this.db;
  }

  get authentication(): admin.auth.Auth {
    if (!this.initialized) {
      throw new Error('Firebase no está inicializado');
    }
    return this.auth;
  }

  getMessaging(): admin.messaging.Messaging {
    if (!this.initialized) {
      throw new Error('Firebase no está inicializado');
    }
    return this.messaging;
  }

  getStorage(): admin.storage.Storage {
    if (!this.initialized) {
      throw new Error('Firebase no está inicializado');
    }
    return this.storage;
  }
}

// Exportar instancia única
export const firebaseService = FirebaseService.getInstance();
export default firebaseService;