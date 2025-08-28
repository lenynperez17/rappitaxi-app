import * as admin from 'firebase-admin';
import { EventEmitter } from 'events';
import crypto from 'crypto';
import { logger } from '@shared/utils/logger';
import { AppError } from '@shared/middleware/error-handler';
import twilio from 'twilio';
import sgMail from '@sendgrid/mail';
import axios from 'axios';
import { Request, Response } from 'express';
import { ApiResponse, PaginationInfo } from '@shared/types/api';
import * as schedule from 'node-schedule';
import Bull from 'bull';
import Redis from 'ioredis';

// Configuración de servicios externos
const twilioClient = twilio(
  process.env.TWILIO_ACCOUNT_SID!, 
  process.env.TWILIO_AUTH_TOKEN!
);
sgMail.setApiKey(process.env.SENDGRID_API_KEY!);

// Redis para caché y cola de reintentos
const redis = new Redis({
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT || '6379'),
  password: process.env.REDIS_PASSWORD,
});

// Cola de procesamiento de notificaciones
const notificationQueue = new Bull('notifications', {
  redis: {
    host: process.env.REDIS_HOST || 'localhost',
    port: parseInt(process.env.REDIS_PORT || '6379'),
    password: process.env.REDIS_PASSWORD,
  },
});

// Tipos de notificaciones
export enum NotificationType {
  // Viaje
  RIDE_REQUEST = 'ride_request',
  RIDE_ACCEPTED = 'ride_accepted',
  RIDE_REJECTED = 'ride_rejected',
  RIDE_CANCELLED = 'ride_cancelled',
  RIDE_STARTED = 'ride_started',
  RIDE_COMPLETED = 'ride_completed',
  DRIVER_ARRIVED = 'driver_arrived',
  DRIVER_NEARBY = 'driver_nearby',
  ROUTE_CHANGED = 'route_changed',
  
  // Negociación
  NEGOTIATION_OFFER = 'negotiation_offer',
  NEGOTIATION_COUNTER_OFFER = 'negotiation_counter_offer',
  NEGOTIATION_ACCEPTED = 'negotiation_accepted',
  NEGOTIATION_REJECTED = 'negotiation_rejected',
  NEGOTIATION_EXPIRED = 'negotiation_expired',
  
  // Pagos
  PAYMENT_PROCESSED = 'payment_processed',
  PAYMENT_FAILED = 'payment_failed',
  PAYMENT_REFUNDED = 'payment_refunded',
  WALLET_TOPPED_UP = 'wallet_topped_up',
  WALLET_WITHDRAWAL = 'wallet_withdrawal',
  
  // Chat
  NEW_MESSAGE = 'new_message',
  MESSAGE_READ = 'message_read',
  TYPING_INDICATOR = 'typing_indicator',
  
  // Sistema
  SYSTEM_UPDATE = 'system_update',
  MAINTENANCE = 'maintenance',
  PROMOTION = 'promotion',
  VERIFICATION = 'verification',
  SECURITY_ALERT = 'security_alert',
  EMERGENCY_ALERT = 'emergency_alert',
  
  // Cuenta
  ACCOUNT_VERIFIED = 'account_verified',
  ACCOUNT_SUSPENDED = 'account_suspended',
  PASSWORD_RESET = 'password_reset',
  TWO_FACTOR_CODE = 'two_factor_code',
  
  // Conductor
  DRIVER_APPROVED = 'driver_approved',
  DRIVER_REJECTED = 'driver_rejected',
  DRIVER_DOCUMENTS_EXPIRING = 'driver_documents_expiring',
  DRIVER_RATING_LOW = 'driver_rating_low',
  
  // Otros
  RATING_REMINDER = 'rating_reminder',
  FEEDBACK_RECEIVED = 'feedback_received',
  SUPPORT_TICKET_UPDATE = 'support_ticket_update',
  SCHEDULED_RIDE_REMINDER = 'scheduled_ride_reminder',
  SHARED_RIDE_UPDATE = 'shared_ride_update',
}

// Canales de notificación
export enum NotificationChannel {
  PUSH = 'push',
  EMAIL = 'email',
  SMS = 'sms',
  WHATSAPP = 'whatsapp',
  IN_APP = 'in_app',
}

// Prioridades
export enum NotificationPriority {
  LOW = 'low',
  NORMAL = 'normal',
  HIGH = 'high',
  CRITICAL = 'critical',
}

// Interfaces
export interface Notification {
  id: string;
  userId: string;
  type: NotificationType;
  title: string;
  body: string;
  data?: Record<string, any>;
  channels: NotificationChannel[];
  priority: NotificationPriority;
  read: boolean;
  readAt?: Date;
  sentAt?: Date;
  createdAt: Date;
  updatedAt?: Date;
  scheduledFor?: Date;
  expiresAt?: Date;
  retryCount?: number;
  errorMessage?: string;
  metadata?: {
    template?: string;
    locale?: string;
    groupId?: string;
    tags?: string[];
  };
}

export interface NotificationPreferences {
  userId: string;
  channels: {
    push: boolean;
    email: boolean;
    sms: boolean;
    whatsapp: boolean;
    inApp: boolean;
  };
  types: Record<NotificationType, boolean>;
  quietHours?: {
    enabled: boolean;
    start: string; // "22:00"
    end: string;   // "08:00"
    timezone: string;
  };
  language: string;
  frequency?: {
    maxPerHour?: number;
    maxPerDay?: number;
  };
}

export interface NotificationTemplate {
  id: string;
  name: string;
  type: NotificationType;
  channels: NotificationChannel[];
  templates: {
    [key in NotificationChannel]?: {
      title?: string;
      body: string;
      subject?: string; // Para email
      htmlBody?: string; // Para email
      mediaUrl?: string; // Para WhatsApp/Push
      buttons?: Array<{
        text: string;
        action: string;
        url?: string;
      }>;
    };
  };
  variables: string[]; // Variables disponibles en la plantilla
  createdAt: Date;
  updatedAt?: Date;
}

export interface DeviceToken {
  token: string;
  platform: 'ios' | 'android' | 'web';
  deviceId?: string;
  deviceInfo?: {
    model?: string;
    osVersion?: string;
    appVersion?: string;
  };
  registeredAt: Date;
  lastUsedAt?: Date;
  isActive: boolean;
}

export interface NotificationBatch {
  id: string;
  name: string;
  status: 'pending' | 'processing' | 'completed' | 'failed';
  targetAudience: {
    userIds?: string[];
    roles?: string[];
    segments?: string[];
    conditions?: Record<string, any>;
  };
  notification: Omit<Notification, 'userId' | 'id'>;
  stats?: {
    total: number;
    sent: number;
    delivered: number;
    read: number;
    failed: number;
  };
  createdAt: Date;
  startedAt?: Date;
  completedAt?: Date;
  error?: string;
}

/**
 * Servicio completo de notificaciones con FCM, Email, SMS, WhatsApp
 */
export class NotificationService extends EventEmitter {
  private static instance: NotificationService;
  private scheduledJobs: Map<string, schedule.Job> = new Map();
  private templateCache: Map<string, NotificationTemplate> = new Map();
  
  private constructor() {
    super();
    this.initializeQueue();
    this.loadTemplates();
  }
  
  static getInstance(): NotificationService {
    if (!NotificationService.instance) {
      NotificationService.instance = new NotificationService();
    }
    return NotificationService.instance;
  }
  
  /**
   * Inicializar cola de procesamiento
   */
  private initializeQueue() {
    // Procesar notificaciones en cola
    notificationQueue.process('send', async (job) => {
      const { userId, notification, channels } = job.data;
      return this.processNotification(userId, notification, channels);
    });
    
    // Procesar lotes
    notificationQueue.process('batch', async (job) => {
      const { batch } = job.data;
      return this.processBatch(batch);
    });
    
    // Manejar reintentos
    notificationQueue.on('failed', async (job, err) => {
      logger.error('Notification job failed', {
        jobId: job.id,
        error: err.message,
        attempts: job.attemptsMade,
      });
      
      if (job.attemptsMade < 3) {
        await job.retry();
      } else {
        await this.handleFailedNotification(job.data);
      }
    });
    
    // Limpiar trabajos antiguos
    notificationQueue.clean(24 * 3600 * 1000); // 24 horas
  }
  
  /**
   * Cargar plantillas de notificación
   */
  private async loadTemplates() {
    try {
      const templatesSnapshot = await admin.firestore()
        .collection('notification_templates')
        .get();
      
      templatesSnapshot.docs.forEach(doc => {
        const template = doc.data() as NotificationTemplate;
        this.templateCache.set(template.name, template);
      });
      
      logger.info('Notification templates loaded', {
        count: this.templateCache.size,
      });
    } catch (error: any) {
      logger.error('Error loading notification templates', error);
    }
  }
  
  /**
   * Enviar notificación a un usuario
   */
  async sendNotification(data: {
    userId: string;
    type: NotificationType;
    title?: string;
    body?: string;
    templateName?: string;
    templateData?: Record<string, any>;
    channels?: NotificationChannel[];
    priority?: NotificationPriority;
    data?: Record<string, any>;
    scheduledFor?: Date;
    expiresAt?: Date;
  }): Promise<Notification> {
    const {
      userId,
      type,
      templateName,
      templateData = {},
      channels,
      priority = NotificationPriority.NORMAL,
      scheduledFor,
      expiresAt,
    } = data;
    
    // Obtener preferencias del usuario
    const preferences = await this.getUserPreferences(userId);
    
    // Verificar si el usuario tiene las notificaciones habilitadas
    if (!this.shouldSendNotification(preferences, type)) {
      throw new AppError(
        'Usuario ha deshabilitado este tipo de notificación',
        400,
        'NOTIFICATION_DISABLED'
      );
    }
    
    // Determinar canales a usar
    const selectedChannels = channels || this.getDefaultChannels(type, preferences);
    
    // Verificar horario silencioso
    if (this.isQuietHours(preferences)) {
      // Programar para después del horario silencioso
      const nextAvailableTime = this.getNextAvailableTime(preferences);
      data.scheduledFor = nextAvailableTime;
    }
    
    // Crear notificación
    let notification: Notification;
    
    if (templateName) {
      // Usar plantilla
      notification = await this.createNotificationFromTemplate(
        userId,
        type,
        templateName,
        templateData,
        selectedChannels,
        priority
      );
    } else {
      // Crear notificación directa
      notification = await this.createNotification(
        userId,
        type,
        data.title!,
        data.body!,
        data.data || {},
        selectedChannels,
        priority
      );
    }
    
    // Si tiene fecha programada, programar para después
    if (scheduledFor && scheduledFor > new Date()) {
      await this.scheduleNotification(notification, scheduledFor);
    } else {
      // Enviar inmediatamente
      await this.queueNotification(notification);
    }
    
    // Emitir evento
    this.emit('notification:sent', notification);
    
    return notification;
  }
  
  /**
   * Enviar notificación usando plantilla
   */
  async sendTemplatedNotification(data: {
    userId: string;
    templateName: string;
    templateData: Record<string, any>;
    channels?: NotificationChannel[];
    priority?: NotificationPriority;
    scheduledFor?: Date;
  }): Promise<Notification> {
    const template = this.templateCache.get(data.templateName);
    
    if (!template) {
      throw new AppError(
        'Plantilla de notificación no encontrada',
        404,
        'TEMPLATE_NOT_FOUND'
      );
    }
    
    return this.sendNotification({
      userId: data.userId,
      type: template.type,
      templateName: data.templateName,
      templateData: data.templateData,
      channels: data.channels || Object.keys(template.templates) as NotificationChannel[],
      priority: data.priority,
      scheduledFor: data.scheduledFor,
    });
  }
  
  /**
   * Enviar notificación push vía FCM
   */
  async sendPushNotification(data: {
    userId?: string;
    tokens?: string[];
    title: string;
    body: string;
    imageUrl?: string;
    data?: Record<string, any>;
    priority?: 'high' | 'normal';
    ttl?: number;
    topic?: string;
    condition?: string;
  }): Promise<{
    successCount: number;
    failureCount: number;
    invalidTokens: string[];
  }> {
    const { userId, tokens, title, body, imageUrl, data, priority = 'high', ttl = 3600, topic, condition } = data;
    
    let deviceTokens: string[] = [];
    
    // Obtener tokens del usuario o usar los proporcionados
    if (userId) {
      const userTokens = await this.getUserDeviceTokens(userId);
      deviceTokens = userTokens.map(t => t.token);
    } else if (tokens) {
      deviceTokens = tokens;
    }
    
    if (!topic && !condition && deviceTokens.length === 0) {
      throw new AppError(
        'No hay tokens de dispositivo disponibles',
        404,
        'NO_DEVICE_TOKENS'
      );
    }
    
    // Construir mensaje FCM
    const message: any = {
      notification: {
        title,
        body,
      },
      data: {
        ...data,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        notification_type: 'push',
        timestamp: new Date().toISOString(),
      },
      android: {
        priority,
        ttl: ttl * 1000, // TTL en milisegundos
        notification: {
          sound: 'default',
          channelId: 'default',
          priority: priority === 'high' ? 'max' : 'default',
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title,
              body,
            },
            badge: 1,
            sound: 'default',
            'content-available': 1,
          },
        },
      },
      webpush: {
        notification: {
          title,
          body,
          icon: '/icon-192x192.png',
          badge: '/badge-72x72.png',
          vibrate: [200, 100, 200],
          requireInteraction: priority === 'high',
        },
      },
    };
    
    if (imageUrl) {
      message.notification.image = imageUrl;
      message.android.notification.image = imageUrl;
      message.apns.fcmOptions = { imageUrl };
      message.webpush.notification.image = imageUrl;
    }
    
    let response: any;
    const invalidTokens: string[] = [];
    
    try {
      if (topic) {
        // Enviar a tópico
        message.topic = topic;
        response = await admin.messaging().send(message);
        
        return {
          successCount: 1,
          failureCount: 0,
          invalidTokens: [],
        };
      } else if (condition) {
        // Enviar con condición
        message.condition = condition;
        response = await admin.messaging().send(message);
        
        return {
          successCount: 1,
          failureCount: 0,
          invalidTokens: [],
        };
      } else {
        // Enviar a tokens específicos
        message.tokens = deviceTokens;
        response = await admin.messaging().sendMulticast(message);
        
        // Procesar respuestas para identificar tokens inválidos
        response.responses.forEach((resp: any, idx: number) => {
          if (!resp.success) {
            const errorCode = resp.error?.code;
            if (
              errorCode === 'messaging/invalid-registration-token' ||
              errorCode === 'messaging/registration-token-not-registered'
            ) {
              invalidTokens.push(deviceTokens[idx]);
            }
            
            logger.warn('FCM send failed', {
              token: deviceTokens[idx],
              error: resp.error?.message,
              code: errorCode,
            });
          }
        });
        
        // Limpiar tokens inválidos
        if (userId && invalidTokens.length > 0) {
          await this.removeInvalidTokens(userId, invalidTokens);
        }
        
        return {
          successCount: response.successCount || 0,
          failureCount: response.failureCount || 0,
          invalidTokens,
        };
      }
    } catch (error: any) {
      logger.error('Error sending push notification', {
        error: error.message,
        userId,
        tokensCount: deviceTokens.length,
      });
      throw error;
    }
  }
  
  /**
   * Enviar notificación por email usando SendGrid
   */
  async sendEmailNotification(data: {
    to: string;
    subject: string;
    text?: string;
    html?: string;
    templateId?: string;
    dynamicTemplateData?: Record<string, any>;
    from?: string;
    replyTo?: string;
    attachments?: Array<{
      content: string;
      filename: string;
      type: string;
      disposition?: string;
    }>;
  }): Promise<void> {
    try {
      const msg: any = {
        to: data.to,
        from: data.from || process.env.SENDGRID_FROM_EMAIL || 'noreply@rappitaxi.com',
        subject: data.subject,
      };
      
      if (data.replyTo) {
        msg.replyTo = data.replyTo;
      }
      
      if (data.templateId) {
        // Usar plantilla dinámica de SendGrid
        msg.templateId = data.templateId;
        msg.dynamicTemplateData = data.dynamicTemplateData;
      } else {
        // Usar contenido directo
        if (data.text) msg.text = data.text;
        if (data.html) msg.html = data.html;
      }
      
      if (data.attachments) {
        msg.attachments = data.attachments;
      }
      
      await sgMail.send(msg);
      
      logger.info('Email notification sent', {
        to: data.to,
        subject: data.subject,
        templateId: data.templateId,
      });
    } catch (error: any) {
      logger.error('Error sending email notification', {
        error: error.message,
        to: data.to,
        subject: data.subject,
      });
      throw error;
    }
  }
  
  /**
   * Enviar notificación por SMS usando Twilio
   */
  async sendSMSNotification(data: {
    to: string;
    body: string;
    from?: string;
    mediaUrl?: string;
  }): Promise<void> {
    try {
      const message = await twilioClient.messages.create({
        body: data.body,
        from: data.from || process.env.TWILIO_PHONE_NUMBER!,
        to: data.to,
        ...(data.mediaUrl && { mediaUrl: [data.mediaUrl] }),
      });
      
      logger.info('SMS notification sent', {
        to: data.to,
        messageId: message.sid,
        status: message.status,
      });
    } catch (error: any) {
      logger.error('Error sending SMS notification', {
        error: error.message,
        to: data.to,
      });
      throw error;
    }
  }
  
  /**
   * Enviar notificación por WhatsApp usando Twilio
   */
  async sendWhatsAppNotification(data: {
    to: string;
    body: string;
    mediaUrl?: string;
  }): Promise<void> {
    try {
      const message = await twilioClient.messages.create({
        body: data.body,
        from: `whatsapp:${process.env.TWILIO_WHATSAPP_NUMBER}`,
        to: `whatsapp:${data.to}`,
        ...(data.mediaUrl && { mediaUrl: [data.mediaUrl] }),
      });
      
      logger.info('WhatsApp notification sent', {
        to: data.to,
        messageId: message.sid,
        status: message.status,
      });
    } catch (error: any) {
      logger.error('Error sending WhatsApp notification', {
        error: error.message,
        to: data.to,
      });
      throw error;
    }
  }
  
  /**
   * Registrar token FCM de dispositivo
   */
  async registerFCMToken(data: {
    userId: string;
    token: string;
    platform: 'ios' | 'android' | 'web';
    deviceId?: string;
    deviceInfo?: {
      model?: string;
      osVersion?: string;
      appVersion?: string;
    };
  }): Promise<void> {
    const { userId, token, platform, deviceId, deviceInfo } = data;
    
    try {
      // Verificar si el token ya existe
      const existingTokens = await this.getUserDeviceTokens(userId);
      const existingToken = existingTokens.find(t => t.token === token);
      
      if (existingToken) {
        // Actualizar timestamp de último uso
        await admin.firestore()
          .collection('user_device_tokens')
          .doc(userId)
          .update({
            [`tokens.${token}.lastUsedAt`]: new Date(),
          });
      } else {
        // Agregar nuevo token
        const newToken: DeviceToken = {
          token,
          platform,
          deviceId,
          deviceInfo,
          registeredAt: new Date(),
          isActive: true,
        };
        
        await admin.firestore()
          .collection('user_device_tokens')
          .doc(userId)
          .set(
            {
              tokens: admin.firestore.FieldValue.arrayUnion(newToken),
              updatedAt: new Date(),
            },
            
          );
        
        // Suscribir a tópicos según el rol del usuario
        await this.subscribeToUserTopics(userId, token);
      }
      
      logger.info('FCM token registered', {
        userId,
        platform,
        deviceId,
      });
    } catch (error: any) {
      logger.error('Error registering FCM token', {
        error: error.message,
        userId,
        platform,
      });
      throw error;
    }
  }
  
  /**
   * Desregistrar token FCM
   */
  async unregisterFCMToken(userId: string, token: string): Promise<void> {
    try {
      const tokensDoc = await admin.firestore()
        .collection('user_device_tokens')
        .doc(userId)
        .get();
      
      if (tokensDoc.exists) {
        const tokensData = tokensDoc.data();
        const tokens = tokensData?.tokens || [];
        const updatedTokens = tokens.filter((t: DeviceToken) => t.token !== token);
        
        await admin.firestore()
          .collection('user_device_tokens')
          .doc(userId)
          .update({
            tokens: updatedTokens,
            updatedAt: new Date(),
          });
        
        // Desuscribir de tópicos
        await this.unsubscribeFromAllTopics(token);
      }
      
      logger.info('FCM token unregistered', {
        userId,
        token: token.substring(0, 10) + '...',
      });
    } catch (error: any) {
      logger.error('Error unregistering FCM token', {
        error: error.message,
        userId,
      });
      throw error;
    }
  }

  /**
   * Actualizar preferencias de notificación del usuario
   */
  async updateUserPreferences(data: {
    userId: string;
    channels?: Partial<NotificationPreferences['channels']>;
    types?: Partial<NotificationPreferences['types']>;
    quietHours?: NotificationPreferences['quietHours'];
    language?: string;
    frequency?: NotificationPreferences['frequency'];
  }): Promise<NotificationPreferences> {
    const { userId, ...updates } = data;
    
    try {
      // Obtener preferencias actuales
      const currentPrefs = await this.getUserPreferences(userId);
      
      // Mezclar con actualizaciones
      const updatedPrefs: NotificationPreferences = {
        ...currentPrefs,
        ...updates,
        channels: {
          ...currentPrefs.channels,
          ...updates.channels,
        },
        types: {
          ...currentPrefs.types,
          ...updates.types,
        },
      };
      
      // Guardar en Firestore
      await admin.firestore()
        .collection('user_notification_preferences')
        .doc(userId)
        .set(updatedPrefs, );
      
      // Limpiar caché
      await redis.del(`prefs:${userId}`);
      
      logger.info('User preferences updated', {
        userId,
        updates,
      });
      
      return updatedPrefs;
    } catch (error: any) {
      logger.error('Error updating user preferences', {
        error: error.message,
        userId,
      });
      throw error;
    }
  }

  /**
   * Enviar notificación masiva
   */
  async sendBulkNotification(data: {
    title: string;
    body: string;
    targetAudience: {
      userIds?: string[];
      roles?: string[];
      segments?: string[];
      conditions?: Record<string, any>;
    };
    channels?: NotificationChannel[];
    priority?: NotificationPriority;
    templateName?: string;
    templateData?: Record<string, any>;
    scheduledFor?: Date;
  }): Promise<NotificationBatch> {
    const batch: NotificationBatch = {
      id: crypto.randomUUID(),
      name: `Bulk_${new Date().toISOString()}`,
      status: 'pending',
      targetAudience: data.targetAudience,
      notification: {
        type: NotificationType.SYSTEM_UPDATE,
        title: data.title,
        body: data.body,
        channels: data.channels || [NotificationChannel.PUSH],
        priority: data.priority || NotificationPriority.NORMAL,
        read: false,
        createdAt: new Date(),
      },
      createdAt: new Date(),
    };
    
    // Guardar batch en Firestore
    await admin.firestore()
      .collection('notification_batches')
      .doc(batch.id)
      .set(batch);
    
    // Programar o ejecutar inmediatamente
    if (data.scheduledFor && data.scheduledFor > new Date()) {
      // Programar para después
      const job = schedule.scheduleJob(data.scheduledFor, async () => {
        await notificationQueue.add('batch', { batch });
      });
      
      this.scheduledJobs.set(batch.id, job);
    } else {
      // Ejecutar ahora
      await notificationQueue.add('batch', { batch });
    }
    
    return batch;
  }

  /**
   * Programar notificación para enviar después
   */
  async scheduleNotification(
    notification: Notification,
    scheduledFor: Date
  ): Promise<void> {
    const job = schedule.scheduleJob(scheduledFor, async () => {
      await this.queueNotification(notification);
    });
    
    // Guardar referencia del trabajo programado
    this.scheduledJobs.set(notification.id, job);
    
    // Actualizar estado en Firestore
    await admin.firestore()
      .collection('notifications')
      .doc(notification.id)
      .update({
        scheduledFor,
        status: 'scheduled',
      });
    
    logger.info('Notification scheduled', {
      notificationId: notification.id,
      scheduledFor,
    });
  }
  
  /**
   * Cancelar notificación programada
   */
  async cancelScheduledNotification(notificationId: string): Promise<void> {
    const job = this.scheduledJobs.get(notificationId);
    
    if (job) {
      job.cancel();
      this.scheduledJobs.delete(notificationId);
      
      // Actualizar estado
      await admin.firestore()
        .collection('notifications')
        .doc(notificationId)
        .update({
          status: 'cancelled',
          cancelledAt: new Date(),
        });
      
      logger.info('Scheduled notification cancelled', {
        notificationId,
      });
    }
  }
  
  /**
   * Marcar notificación como leída
   */
  async markAsRead(userId: string, notificationId: string): Promise<void> {
    try {
      const notificationRef = admin.firestore()
        .collection('notifications')
        .doc(notificationId);
      
      const notificationDoc = await notificationRef.get();
      
      if (!notificationDoc.exists) {
        throw new AppError(
          'Notificación no encontrada',
          404,
          'NOTIFICATION_NOT_FOUND'
        );
      }
      
      const notification = notificationDoc.data() as Notification;
      
      if (notification.userId !== userId) {
        throw new AppError(
          'No autorizado para marcar esta notificación',
          403,
          'FORBIDDEN'
        );
      }
      
      await notificationRef.update({
        read: true,
        readAt: new Date(),
      });
      
      // Emitir evento
      this.emit('notification:read', {
        userId,
        notificationId,
      });
      
      logger.debug('Notification marked as read', {
        userId,
        notificationId,
      });
    } catch (error: any) {
      logger.error('Error marking notification as read', {
        error: error.message,
        userId,
        notificationId,
      });
      throw error;
    }
  }
  
  /**
   * Marcar todas las notificaciones como leídas
   */
  async markAllAsRead(userId: string): Promise<number> {
    try {
      const unreadQuery = await admin.firestore()
        .collection('notifications')
        .where('userId', '==', userId)
        .where('read', '==', false)
        .get();
      
      if (unreadQuery.empty) {
        return 0;
      }
      
      const batch = admin.firestore().batch();
      const now = new Date();
      
      unreadQuery.docs.forEach(doc => {
        batch.update(doc.ref, {
          read: true,
          readAt: now,
        });
      });
      
      await batch.commit();
      
      // Emitir evento
      this.emit('notification:all_read', {
        userId,
        count: unreadQuery.size,
      });
      
      logger.info('All notifications marked as read', {
        userId,
        count: unreadQuery.size,
      });
      
      return unreadQuery.size;
    } catch (error: any) {
      logger.error('Error marking all notifications as read', {
        error: error.message,
        userId,
      });
      throw error;
    }
  }

  /**
   * Obtener notificaciones del usuario con paginación
   */
  async getUserNotifications(data: {
    userId: string;
    page?: number;
    limit?: number;
    unreadOnly?: boolean;
    types?: NotificationType[];
    channels?: NotificationChannel[];
    startDate?: Date;
    endDate?: Date;
  }): Promise<{
    notifications: Notification[];
    pagination: PaginationInfo;
    unreadCount: number;
  }> {
    const {
      userId,
      page = 1,
      limit = 20,
      unreadOnly = false,
      types,
      channels,
      startDate,
      endDate,
    } = data;
    
    try {
      let query = admin.firestore()
        .collection('notifications')
        .where('userId', '==', userId) as any;
      
      if (unreadOnly) {
        query = query.where('read', '==', false);
      }
      
      if (types && types.length > 0) {
        query = query.where('type', 'in', types);
      }
      
      if (channels && channels.length > 0) {
        query = query.where('channels', 'array-contains-any', channels);
      }
      
      if (startDate) {
        query = query.where('createdAt', '>=', startDate);
      }
      
      if (endDate) {
        query = query.where('createdAt', '<=', endDate);
      }
      
      query = query.orderBy('createdAt', 'desc');
      
      // Obtener total
      const totalSnapshot = await query.get();
      const total = totalSnapshot.size;
      
      // Aplicar paginación
      const offset = (page - 1) * limit;
      const notificationsSnapshot = await query
        .offset(offset)
        .limit(limit)
        .get();
      
      const notifications = notificationsSnapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data(),
      })) as Notification[];
      
      const totalPages = Math.ceil(total / limit);
      const pagination: PaginationInfo = {
        page,
        limit,
        total,
        totalPages,
        hasNext: page < totalPages,
        hasPrev: page > 1,
      };
      
      // Contar no leídas
      const unreadCount = notifications.filter(n => !n.read).length;
      
      return {
        notifications,
        pagination,
        unreadCount,
      };
    } catch (error: any) {
      logger.error('Error getting user notifications', {
        error: error.message,
        userId,
      });
      throw error;
    }
  }

  /**
   * Eliminar notificación
   */
  async deleteNotification(userId: string, notificationId: string): Promise<void> {
    try {
      const notificationRef = admin.firestore()
        .collection('notifications')
        .doc(notificationId);
      
      const notificationDoc = await notificationRef.get();
      
      if (!notificationDoc.exists) {
        throw new AppError(
          'Notificación no encontrada',
          404,
          'NOTIFICATION_NOT_FOUND'
        );
      }
      
      const notification = notificationDoc.data() as Notification;
      
      if (notification.userId !== userId) {
        throw new AppError(
          'No autorizado para eliminar esta notificación',
          403,
          'FORBIDDEN'
        );
      }
      
      // Cancelar si está programada
      if (this.scheduledJobs.has(notificationId)) {
        await this.cancelScheduledNotification(notificationId);
      }
      
      await notificationRef.delete();
      
      logger.info('Notification deleted', {
        userId,
        notificationId,
      });
    } catch (error: any) {
      logger.error('Error deleting notification', {
        error: error.message,
        userId,
        notificationId,
      });
      throw error;
    }
  }

  // Métodos auxiliares privados
  
  /**
   * Obtener preferencias del usuario
   */
  private async getUserPreferences(userId: string): Promise<NotificationPreferences> {
    // Intentar obtener de caché
    const cacheKey = `prefs:${userId}`;
    const cached = await redis.get(cacheKey);
    
    if (cached) {
      return JSON.parse(cached);
    }
    
    // Obtener de Firestore
    const prefsDoc = await admin.firestore()
      .collection('user_notification_preferences')
      .doc(userId)
      .get();
    
    let preferences: NotificationPreferences;
    
    if (prefsDoc.exists) {
      preferences = prefsDoc.data() as NotificationPreferences;
    } else {
      // Preferencias por defecto
      preferences = this.getDefaultPreferences(userId);
      
      // Guardar preferencias por defecto
      await admin.firestore()
        .collection('user_notification_preferences')
        .doc(userId)
        .set(preferences);
    }
    
    // Guardar en caché por 1 hora
    await redis.set(cacheKey, JSON.stringify(preferences), 'EX', 3600);
    
    return preferences;
  }
  
  /**
   * Obtener preferencias por defecto
   */
  private getDefaultPreferences(userId: string): NotificationPreferences {
    return {
      userId,
      channels: {
        push: true,
        email: true,
        sms: false,
        whatsapp: false,
        inApp: true,
      },
      types: Object.values(NotificationType).reduce((acc, type) => {
        acc[type] = true;
        return acc;
      }, {} as Record<NotificationType, boolean>),
      language: 'es',
      frequency: {
        maxPerHour: 10,
        maxPerDay: 50,
      },
    };
  }
  
  /**
   * Verificar si se debe enviar notificación
   */
  private shouldSendNotification(
    preferences: NotificationPreferences,
    type: NotificationType
  ): boolean {
    // Verificar si el tipo está habilitado
    if (preferences.types[type] === false) {
      return false;
    }
    
    // Verificar si hay al menos un canal habilitado
    const hasEnabledChannel = Object.values(preferences.channels).some(enabled => enabled);
    
    return hasEnabledChannel;
  }
  
  /**
   * Obtener canales por defecto según el tipo
   */
  private getDefaultChannels(
    type: NotificationType,
    preferences: NotificationPreferences
  ): NotificationChannel[] {
    const channels: NotificationChannel[] = [];
    
    // Push siempre para notificaciones críticas
    const criticalTypes: NotificationType[] = [
      NotificationType.EMERGENCY_ALERT,
      NotificationType.SECURITY_ALERT,
      NotificationType.DRIVER_ARRIVED,
      NotificationType.RIDE_STARTED,
    ];
    
    if (criticalTypes.includes(type) && preferences.channels.push) {
      channels.push(NotificationChannel.PUSH);
    }
    
    // Email para notificaciones importantes
    const emailTypes: NotificationType[] = [
      NotificationType.PAYMENT_PROCESSED,
      NotificationType.PASSWORD_RESET,
      NotificationType.ACCOUNT_VERIFIED,
      NotificationType.RIDE_COMPLETED,
    ];
    
    if (emailTypes.includes(type) && preferences.channels.email) {
      channels.push(NotificationChannel.EMAIL);
    }
    
    // SMS para notificaciones urgentes
    const smsTypes: NotificationType[] = [
      NotificationType.DRIVER_ARRIVED,
      NotificationType.EMERGENCY_ALERT,
      NotificationType.TWO_FACTOR_CODE,
    ];
    
    if (smsTypes.includes(type) && preferences.channels.sms) {
      channels.push(NotificationChannel.SMS);
    }
    
    // In-app siempre que esté habilitado
    if (preferences.channels.inApp) {
      channels.push(NotificationChannel.IN_APP);
    }
    
    // Si no hay canales, usar push por defecto
    if (channels.length === 0 && preferences.channels.push) {
      channels.push(NotificationChannel.PUSH);
    }
    
    return channels;
  }
  
  /**
   * Verificar si es horario silencioso
   */
  private isQuietHours(preferences: NotificationPreferences): boolean {
    if (!preferences.quietHours?.enabled) {
      return false;
    }
    
    const { start, end, timezone } = preferences.quietHours;
    const now = new Date();
    
    // Convertir a hora local del usuario
    const userTime = new Date(
      now.toLocaleString('en-US', { timeZone: timezone })
    );
    
    const currentHour = userTime.getHours();
    const currentMinute = userTime.getMinutes();
    const currentTime = currentHour * 60 + currentMinute;
    
    const [startHour, startMinute] = start.split(':').map(Number);
    const [endHour, endMinute] = end.split(':').map(Number);
    
    const startTime = startHour * 60 + startMinute;
    const endTime = endHour * 60 + endMinute;
    
    if (startTime <= endTime) {
      // Horario normal (ej: 22:00 - 23:30)
      return currentTime >= startTime && currentTime <= endTime;
    } else {
      // Horario que cruza medianoche (ej: 22:00 - 08:00)
      return currentTime >= startTime || currentTime <= endTime;
    }
  }

  /**
   * Obtener próximo tiempo disponible para notificación
   */
  private getNextAvailableTime(preferences: NotificationPreferences): Date {
    if (!preferences.quietHours) {
      return new Date();
    }
    
    const { end, timezone } = preferences.quietHours;
    const [endHour, endMinute] = end.split(':').map(Number);
    
    const now = new Date();
    const userTime = new Date(
      now.toLocaleString('en-US', { timeZone: timezone })
    );
    
    // Establecer la hora de finalización del horario silencioso
    const nextAvailable = new Date(userTime);
    nextAvailable.setHours(endHour, endMinute, 0, 0);
    
    // Si ya pasó la hora de hoy, establecer para mañana
    if (nextAvailable <= now) {
      nextAvailable.setDate(nextAvailable.getDate() + 1);
    }
    
    return nextAvailable;
  }

  /**
   * Obtener tokens de dispositivo del usuario
   */
  private async getUserDeviceTokens(userId: string): Promise<DeviceToken[]> {
    try {
      const tokensDoc = await admin.firestore()
        .collection('user_device_tokens')
        .doc(userId)
        .get();
      
      if (!tokensDoc.exists) {
        return [];
      }
      
      const data = tokensDoc.data();
      const tokens = data?.tokens || [];
      
      // Filtrar solo tokens activos
      return tokens.filter((token: DeviceToken) => token.isActive);
    } catch (error: any) {
      logger.error('Error getting user device tokens', {
        error: error.message,
        userId,
      });
      return [];
    }
  }

  /**
   * Remover tokens inválidos
   */
  private async removeInvalidTokens(
    userId: string,
    invalidTokens: string[]
  ): Promise<void> {
    try {
      const tokensDoc = await admin.firestore()
        .collection('user_device_tokens')
        .doc(userId)
        .get();
      
      if (!tokensDoc.exists) {
        return;
      }
      
      const data = tokensDoc.data();
      const tokens = data?.tokens || [];
      
      // Marcar tokens como inactivos en lugar de eliminarlos
      const updatedTokens = tokens.map((token: DeviceToken) => {
        if (invalidTokens.includes(token.token)) {
          return {
            ...token,
            isActive: false,
            deactivatedAt: new Date(),
          };
        }
        return token;
      });
      
      await admin.firestore()
        .collection('user_device_tokens')
        .doc(userId)
        .update({
          tokens: updatedTokens,
          updatedAt: new Date(),
        });
      
      logger.info('Invalid tokens removed', {
        userId,
        count: invalidTokens.length,
      });
    } catch (error: any) {
      logger.error('Error removing invalid tokens', {
        error: error.message,
        userId,
      });
    }
  }

  /**
   * Crear notificación desde plantilla
   */
  private async createNotificationFromTemplate(
    userId: string,
    type: NotificationType,
    templateName: string,
    templateData: Record<string, any>,
    channels: NotificationChannel[],
    priority: NotificationPriority
  ): Promise<Notification> {
    const template = this.templateCache.get(templateName);
    
    if (!template) {
      throw new AppError(
        'Plantilla no encontrada',
        404,
        'TEMPLATE_NOT_FOUND'
      );
    }
    
    // Reemplazar variables en la plantilla
    const processedTemplate: any = {};
    
    for (const channel of channels) {
      const channelTemplate = template.templates[channel];
      if (channelTemplate) {
        processedTemplate[channel] = {
          title: this.replaceVariables(channelTemplate.title || '', templateData),
          body: this.replaceVariables(channelTemplate.body, templateData),
          subject: this.replaceVariables(channelTemplate.subject || '', templateData),
          htmlBody: this.replaceVariables(channelTemplate.htmlBody || '', templateData),
          mediaUrl: channelTemplate.mediaUrl,
          buttons: channelTemplate.buttons,
        };
      }
    }
    
    const notification: Notification = {
      id: crypto.randomUUID(),
      userId,
      type,
      title: processedTemplate[channels[0]]?.title || template.name,
      body: processedTemplate[channels[0]]?.body || '',
      data: templateData,
      channels,
      priority,
      read: false,
      createdAt: new Date(),
      metadata: {
        template: templateName,
        locale: 'es',
      },
    };
    
    // Guardar en Firestore
    await admin.firestore()
      .collection('notifications')
      .doc(notification.id)
      .set(notification);
    
    return notification;
  }

  /**
   * Crear notificación directa
   */
  private async createNotification(
    userId: string,
    type: NotificationType,
    title: string,
    body: string,
    data: Record<string, any>,
    channels: NotificationChannel[],
    priority: NotificationPriority
  ): Promise<Notification> {
    const notification: Notification = {
      id: crypto.randomUUID(),
      userId,
      type,
      title,
      body,
      data,
      channels,
      priority,
      read: false,
      createdAt: new Date(),
    };
    
    // Guardar en Firestore
    await admin.firestore()
      .collection('notifications')
      .doc(notification.id)
      .set(notification);
    
    return notification;
  }

  /**
   * Reemplazar variables en plantilla
   */
  private replaceVariables(
    template: string,
    data: Record<string, any>
  ): string {
    return template.replace(/\{\{(\w+)\}\}/g, (match, variable) => {
      return data[variable] || match;
    });
  }
  
  /**
   * Agregar notificación a la cola
   */
  private async queueNotification(notification: Notification): Promise<void> {
    await notificationQueue.add(
      'send',
      {
        userId: notification.userId,
        notification,
        channels: notification.channels,
      },
      {
        attempts: 3,
        backoff: {
          type: 'exponential',
          delay: 2000,
        },
        priority: this.getPriorityNumber(notification.priority),
      }
    );
  }
  
  /**
   * Convertir prioridad a número
   */
  private getPriorityNumber(priority: NotificationPriority): number {
    const priorityMap = {
      [NotificationPriority.LOW]: 10,
      [NotificationPriority.NORMAL]: 5,
      [NotificationPriority.HIGH]: 2,
      [NotificationPriority.CRITICAL]: 1,
    };
    return priorityMap[priority] || 5;
  }

  /**
   * Procesar notificación y enviar por los canales correspondientes
   */
  private async processNotification(
    userId: string,
    notification: Notification,
    channels: NotificationChannel[]
  ): Promise<void> {
    const errors: Array<{ channel: string; error: string }> = [];
    
    for (const channel of channels) {
      try {
        switch (channel) {
          case NotificationChannel.PUSH:
            await this.sendPushNotification({
              userId,
              title: notification.title,
              body: notification.body,
              data: notification.data,
            });
            break;
            
          case NotificationChannel.EMAIL:
            // Obtener email del usuario
            const userDoc = await admin.firestore()
              .collection('users')
              .doc(userId)
              .get();
            
            const email = userDoc.data()?.email;
            if (email) {
              await this.sendEmailNotification({
                to: email,
                subject: notification.title,
                text: notification.body,
                html: `<h2>${notification.title}</h2><p>${notification.body}</p>`,
              });
            }
            break;
            
          case NotificationChannel.SMS:
            // Obtener teléfono del usuario
            const userPhoneDoc = await admin.firestore()
              .collection('users')
              .doc(userId)
              .get();
            
            const phone = userPhoneDoc.data()?.phone;
            if (phone) {
              await this.sendSMSNotification({
                to: phone,
                body: `${notification.title}: ${notification.body}`,
              });
            }
            break;
            
          case NotificationChannel.WHATSAPP:
            // Obtener teléfono del usuario para WhatsApp
            const userWhatsAppDoc = await admin.firestore()
              .collection('users')
              .doc(userId)
              .get();
            
            const whatsappPhone = userWhatsAppDoc.data()?.phone;
            if (whatsappPhone) {
              await this.sendWhatsAppNotification({
                to: whatsappPhone,
                body: `*${notification.title}*\n${notification.body}`,
              });
            }
            break;
            
          case NotificationChannel.IN_APP:
            // Las notificaciones in-app ya se guardan en Firestore
            // No requiere acción adicional
            break;
        }
      } catch (error: any) {
        errors.push({
          channel,
          error: error.message,
        });
        
        logger.error('Error sending notification via channel', {
          channel,
          notificationId: notification.id,
          error: error.message,
        });
      }
    }
    
    // Actualizar estado de la notificación
    await admin.firestore()
      .collection('notifications')
      .doc(notification.id)
      .update({
        sentAt: new Date(),
        errors: errors.length > 0 ? errors : null,
      });
    
    // Si todos los canales fallaron, lanzar error
    if (errors.length === channels.length) {
      throw new AppError(
        'Todos los canales de notificación fallaron',
        500,
        'ALL_CHANNELS_FAILED'
      );
    }
  }

  /**
   * Procesar batch de notificaciones
   */
  private async processBatch(batch: NotificationBatch): Promise<void> {
    try {
      // Actualizar estado del batch
      await admin.firestore()
        .collection('notification_batches')
        .doc(batch.id)
        .update({
          status: 'processing',
          startedAt: new Date(),
        });
      
      // Obtener usuarios objetivo
      let targetUsers: string[] = [];
      
      if (batch.targetAudience.userIds) {
        targetUsers = batch.targetAudience.userIds;
      } else if (batch.targetAudience.roles) {
        // Obtener usuarios por roles
        for (const role of batch.targetAudience.roles) {
          const usersQuery = await admin.firestore()
            .collection('users')
            .where('role', '==', role)
            .where('isActive', '==', true)
            .get();
          
          targetUsers.push(...usersQuery.docs.map(doc => doc.id));
        }
      } else if (batch.targetAudience.segments) {
        // Obtener usuarios por segmentos
        // Implementar lógica de segmentación
        // Por ahora, usar todos los usuarios activos
        const usersQuery = await admin.firestore()
          .collection('users')
          .where('isActive', '==', true)
          .get();
        
        targetUsers = usersQuery.docs.map(doc => doc.id);
      }
      
      // Eliminar duplicados
      targetUsers = [...new Set(targetUsers)];
      
      // Procesar en lotes
      const batchSize = 100;
      let sentCount = 0;
      let failedCount = 0;
      
      for (let i = 0; i < targetUsers.length; i += batchSize) {
        const userBatch = targetUsers.slice(i, i + batchSize);
        
        const promises = userBatch.map(async (userId) => {
          try {
            const notification = {
              ...batch.notification,
              id: crypto.randomUUID(),
              userId,
            } as Notification;
            
            await this.processNotification(
              userId,
              notification,
              batch.notification.channels
            );
            
            return { success: true };
          } catch (error) {
            return { success: false, error };
          }
        });
        
        const results = await Promise.allSettled(promises);
        
        results.forEach(result => {
          if (result.status === 'fulfilled' && result.value.success) {
            sentCount++;
          } else {
            failedCount++;
          }
        });
      }
      
      // Actualizar estadísticas del batch
      await admin.firestore()
        .collection('notification_batches')
        .doc(batch.id)
        .update({
          status: 'completed',
          completedAt: new Date(),
          stats: {
            total: targetUsers.length,
            sent: sentCount,
            failed: failedCount,
          },
        });
      
      logger.info('Batch processed successfully', {
        batchId: batch.id,
        total: targetUsers.length,
        sent: sentCount,
        failed: failedCount,
      });
    } catch (error: any) {
      // Actualizar estado de error
      await admin.firestore()
        .collection('notification_batches')
        .doc(batch.id)
        .update({
          status: 'failed',
          error: error.message,
        });
      
      logger.error('Error processing batch', {
        batchId: batch.id,
        error: error.message,
      });
      
      throw error;
    }
  }

  /**
   * Manejar notificación fallida
   */
  private async handleFailedNotification(data: any): Promise<void> {
    const { userId, notification } = data;
    
    logger.error('Notification permanently failed', {
      notificationId: notification.id,
      userId,
      type: notification.type,
    });
    
    // Actualizar estado de la notificación
    await admin.firestore()
      .collection('notifications')
      .doc(notification.id)
      .update({
        status: 'failed',
        failedAt: new Date(),
        errorMessage: 'Máximo de reintentos alcanzado',
      });
    
    // Emitir evento de fallo
    this.emit('notification:failed', {
      notificationId: notification.id,
      userId,
    });
  }
  
  /**
   * Suscribir usuario a tópicos según su rol
   */
  private async subscribeToUserTopics(
    userId: string,
    token: string
  ): Promise<void> {
    try {
      const userDoc = await admin.firestore()
        .collection('users')
        .doc(userId)
        .get();
      
      if (!userDoc.exists) {
        return;
      }
      
      const userData = userDoc.data();
      const topics: string[] = [];
      
      // Tópico general
      topics.push('general');
      
      // Tópico por rol
      if (userData?.role) {
        topics.push(`role_${userData.role}`);
        
        // Tópicos específicos por rol
        switch (userData.role) {
          case 'driver':
            topics.push('driver_updates', 'new_rides');
            break;
          case 'passenger':
            topics.push('passenger_updates', 'promotions');
            break;
          case 'admin':
            topics.push('admin_updates', 'system_alerts');
            break;
        }
      }
      
      // Tópico por ciudad
      if (userData?.city) {
        topics.push(`city_${userData.city}`);
      }
      
      // Suscribir a todos los tópicos
      for (const topic of topics) {
        await admin.messaging().subscribeToTopic([token], topic);
      }
      
      logger.debug('User subscribed to topics', {
        userId,
        topics,
      });
    } catch (error: any) {
      logger.error('Error subscribing user to topics', {
        error: error.message,
        userId,
      });
    }
  }
  
  /**
   * Desuscribir de todos los tópicos
   */
  private async unsubscribeFromAllTopics(token: string): Promise<void> {
    try {
      // Lista de todos los tópicos posibles
      const allTopics = [
        'general',
        'role_driver',
        'role_passenger',
        'role_admin',
        'driver_updates',
        'passenger_updates',
        'admin_updates',
        'new_rides',
        'promotions',
        'system_alerts',
        'system_updates',
      ];
      
      // Desuscribir de todos
      for (const topic of allTopics) {
        try {
          await admin.messaging().unsubscribeFromTopic([token], topic);
        } catch (error) {
          // Continuar si falla alguno
          logger.debug('Error unsubscribing from topic', {
            topic,
            error,
          });
        }
      }
    } catch (error: any) {
      logger.error('Error unsubscribing from all topics', {
        error: error.message,
      });
    }
  }
}

// Instancia singleton del servicio
export const notificationService = NotificationService.getInstance();

// Funciones de conveniencia para compatibilidad con código existente

/**
 * Enviar notificación de viaje (compatibilidad)
 */
export const sendRideNotification = async (
  userId: string,
  type: string,
  data: any
): Promise<void> => {
  try {
    await notificationService.sendNotification({
      userId,
      type: type as NotificationType,
      title: data.title || 'Notificación',
      body: data.body || data.message || '',
      data,
    });
  } catch (error: any) {
    logger.error('Error sending ride notification', {
      error: error.message,
      userId,
      type,
    });
  }
};

/**
 * Enviar notificación de bienvenida
 */
export const sendWelcomeNotification = async (
  userId: string,
  userName: string,
  verificationLink: string
): Promise<void> => {
  try {
    await notificationService.sendTemplatedNotification({
      userId,
      templateName: 'welcome',
      templateData: {
        userName,
        verificationLink,
      },
      channels: [NotificationChannel.EMAIL, NotificationChannel.PUSH],
    });
  } catch (error: any) {
    logger.error('Error sending welcome notification', {
      error: error.message,
      userId,
    });
  }
};

/**
 * Enviar notificación de restablecimiento de contraseña
 */
export const sendPasswordResetNotification = async (
  userId: string,
  userName: string,
  resetLink: string
): Promise<void> => {
  try {
    await notificationService.sendTemplatedNotification({
      userId,
      templateName: 'password_reset',
      templateData: {
        userName,
        resetLink,
      },
      channels: [NotificationChannel.EMAIL],
    });
  } catch (error: any) {
    logger.error('Error sending password reset notification', {
      error: error.message,
      userId,
    });
  }
};

// Controladores HTTP para compatibilidad con rutas existentes

/**
 * Obtener notificaciones del usuario
 */
export const getUserNotifications = async (
  req: Request,
  res: Response
): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }
  
  try {
    const result = await notificationService.getUserNotifications({
      userId: req.userId,
      page: parseInt(req.query.page as string) || 1,
      limit: parseInt(req.query.limit as string) || 20,
      unreadOnly: req.query.unreadOnly === 'true',
    });
    
    res.json({
      success: true,
      data: result,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    throw error;
  }
};

/**
 * Marcar notificación como leída
 */
export const markNotificationAsRead = async (
  req: Request,
  res: Response
): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }
  
  const { notificationId } = req.params;
  
  try {
    await notificationService.markAsRead(req.userId, notificationId);
    
    res.json({
      success: true,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    throw error;
  }
};

/**
 * Marcar todas las notificaciones como leídas
 */
export const markAllNotificationsAsRead = async (
  req: Request,
  res: Response
): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }
  
  try {
    const count = await notificationService.markAllAsRead(req.userId);
    
    res.json({
      success: true,
      data: { updatedCount: count },
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    throw error;
  }
};

/**
 * Eliminar notificación
 */
export const deleteNotification = async (
  req: Request,
  res: Response
): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }
  
  const { notificationId } = req.params;
  
  try {
    await notificationService.deleteNotification(req.userId, notificationId);
    
    res.json({
      success: true,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    throw error;
  }
};

/**
 * Obtener conteo de notificaciones no leídas
 */
export const getUnreadCount = async (
  req: Request,
  res: Response
): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }
  
  try {
    const result = await notificationService.getUserNotifications({
      userId: req.userId,
      unreadOnly: true,
      limit: 0, // Solo queremos el conteo
    });
    
    res.json({
      success: true,
      data: { unreadCount: result.pagination.total },
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    throw error;
  }
};

/**
 * Actualizar preferencias de notificación
 */
export const updateNotificationPreferences = async (
  req: Request,
  res: Response
): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }
  
  try {
    const preferences = await notificationService.updateUserPreferences({
      userId: req.userId,
      ...req.body,
    });
    
    res.json({
      success: true,
      data: { preferences },
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    throw error;
  }
};

/**
 * Obtener preferencias de notificación
 */
export const getNotificationPreferences = async (
  req: Request,
  res: Response
): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }
  
  try {
    const preferences = await notificationService.getUserPreferences(req.userId);
    
    res.json({
      success: true,
      data: { preferences },
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    throw error;
  }
};

/**
 * Registrar token de dispositivo
 */
export const registerDeviceToken = async (
  req: Request,
  res: Response
): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }
  
  const { token, platform, deviceId, deviceInfo } = req.body;
  
  if (!token || !platform) {
    throw new AppError('Token y plataforma requeridos', 400, 'VALIDATION_ERROR');
  }
  
  try {
    await notificationService.registerFCMToken({
      userId: req.userId,
      token,
      platform,
      deviceId,
      deviceInfo,
    });
    
    res.json({
      success: true,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    throw error;
  }
};

/**
 * Desregistrar token de dispositivo
 */
export const unregisterDeviceToken = async (
  req: Request,
  res: Response
): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }
  
  const { token } = req.body;
  
  if (!token) {
    throw new AppError('Token requerido', 400, 'VALIDATION_ERROR');
  }
  
  try {
    await notificationService.unregisterFCMToken(req.userId, token);
    
    res.json({
      success: true,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    throw error;
  }
};

/**
 * Enviar notificación masiva (solo admin)
 */
export const sendBulkNotification = async (
  req: Request,
  res: Response
): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }
  
  // Verificar permisos de admin
  // TODO: Implementar verificación de rol admin
  
  try {
    const batch = await notificationService.sendBulkNotification(req.body);
    
    res.json({
      success: true,
      data: { batch },
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    throw error;
  }
};

/**
 * Enviar notificación de prueba (solo admin)
 */
export const sendTestNotification = async (
  req: Request,
  res: Response
): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }
  
  try {
    const { targetUserId, title, message, type = 'info' } = req.body;
    
    const notification = await notificationService.sendNotification({
      userId: targetUserId,
      type: type as any,
      title,
      body: message,
      priority: NotificationPriority.NORMAL,
      data: {
        testNotification: true,
        sentBy: req.userId
      }
    });
    
    res.json({
      success: true,
      data: { notification },
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    throw error;
  }
};

/**
 * Obtener historial de notificaciones (admin)
 */
export const getNotificationHistory = async (
  req: Request,
  res: Response
): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }
  
  try {
    const { page = 1, limit = 50, type, startDate, endDate } = req.query as any;
    
    const db = admin.firestore();
    let query = db.collection('notifications')
      .orderBy('createdAt', 'desc')
      .limit(parseInt(limit));
    
    if (type) {
      query = query.where('type', '==', type) as any;
    }
    
    if (startDate) {
      query = query.where('createdAt', '>=', admin.firestore.Timestamp.fromDate(new Date(startDate))) as any;
    }
    
    if (endDate) {
      query = query.where('createdAt', '<=', admin.firestore.Timestamp.fromDate(new Date(endDate))) as any;
    }
    
    const snapshot = await query.get();
    const notifications = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
    
    res.json({
      success: true,
      data: {
        notifications,
        total: notifications.length,
        page: parseInt(page),
        limit: parseInt(limit)
      },
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    throw error;
  }
};

/**
 * Suscribir a topic de notificaciones
 */
export const subscribeToTopic = async (
  req: Request,
  res: Response
): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }
  
  try {
    const { topic } = req.params;
    const { deviceToken } = req.body;
    
    if (!deviceToken) {
      throw new AppError('Token de dispositivo requerido', 400, 'DEVICE_TOKEN_REQUIRED');
    }
    
    // Suscribir al topic usando Firebase Messaging
    await admin.messaging().subscribeToTopic([deviceToken], topic);
    
    // Registrar suscripción en base de datos
    const db = admin.firestore();
    await db.collection('topic_subscriptions').add({
      userId: req.userId,
      topic,
      deviceToken,
      subscribedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    res.json({
      success: true,
      data: { message: `Suscrito al topic: ${topic}` },
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    throw error;
  }
};

/**
 * Desuscribir de topic de notificaciones
 */
export const unsubscribeFromTopic = async (
  req: Request,
  res: Response
): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }
  
  try {
    const { topic } = req.params;
    const { deviceToken } = req.body;
    
    if (!deviceToken) {
      throw new AppError('Token de dispositivo requerido', 400, 'DEVICE_TOKEN_REQUIRED');
    }
    
    // Desuscribir del topic usando Firebase Messaging
    await admin.messaging().unsubscribeFromTopic([deviceToken], topic);
    
    // Remover suscripción de base de datos
    const db = admin.firestore();
    const subscriptionQuery = await db.collection('topic_subscriptions')
      .where('userId', '==', req.userId)
      .where('topic', '==', topic)
      .where('deviceToken', '==', deviceToken)
      .get();
    
    const batch = db.batch();
    subscriptionQuery.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
    await batch.commit();
    
    res.json({
      success: true,
      data: { message: `Desuscrito del topic: ${topic}` },
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    throw error;
  }
};