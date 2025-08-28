import { EventEmitter } from 'events';
import * as admin from 'firebase-admin';
import { Server, Socket } from 'socket.io';
import crypto from 'crypto';
import { logger } from '@shared/utils/logger';
import { AppError } from '@shared/middleware/error-handler';
import { sendBulkNotification, notificationService } from '../notifications/services/notification-service';

// 💬 Tipos de mensajes
export enum MessageType {
  TEXT = 'text',
  IMAGE = 'image',
  AUDIO = 'audio',
  VIDEO = 'video',
  LOCATION = 'location',
  FILE = 'file',
  SYSTEM = 'system',
  QUICK_REPLY = 'quick_reply'
}

// 📊 Estados de mensaje
export enum MessageStatus {
  SENDING = 'sending',
  SENT = 'sent',
  DELIVERED = 'delivered',
  READ = 'read',
  FAILED = 'failed'
}

// 💼 Interfaz de Mensaje
export interface ChatMessage {
  id: string;
  conversationId: string;
  senderId: string;
  senderName: string;
  senderRole: 'passenger' | 'driver' | 'admin' | 'system';
  recipientId: string;
  type: MessageType;
  content: string;
  metadata?: {
    imageUrl?: string;
    audioUrl?: string;
    videoUrl?: string;
    fileUrl?: string;
    fileName?: string;
    fileSize?: number;
    duration?: number; // Para audio/video
    location?: {
      latitude: number;
      longitude: number;
      address?: string;
    };
    quickReplies?: string[]; // Respuestas rápidas sugeridas
  };
  status: MessageStatus;
  deliveredAt?: Date;
  readAt?: Date;
  editedAt?: Date;
  deletedAt?: Date;
  replyTo?: string; // ID del mensaje al que responde
  reactions?: Map<string, string>; // userId -> emoji
  createdAt: Date;
  updatedAt: Date;
}

// 🗨️ Interfaz de Conversación
export interface ChatConversation {
  id: string;
  rideId?: string; // Asociado a un viaje específico
  participants: {
    passengerId: string;
    passengerName: string;
    passengerAvatar?: string;
    driverId: string;
    driverName: string;
    driverAvatar?: string;
  };
  lastMessage?: {
    id: string;
    content: string;
    senderId: string;
    timestamp: Date;
    type: MessageType;
  };
  unreadCount: {
    passenger: number;
    driver: number;
  };
  isActive: boolean;
  isPinned: boolean;
  isMuted: {
    passenger: boolean;
    driver: boolean;
  };
  typingStatus: {
    passenger: boolean;
    driver: boolean;
  };
  startedAt: Date;
  endedAt?: Date;
  createdAt: Date;
  updatedAt: Date;
}

// 🎯 Templates de mensajes predefinidos
const MESSAGE_TEMPLATES = {
  driver: {
    greeting: [
      '¡Hola! Soy tu conductor. Ya estoy en camino 🚗',
      '¡Buenos días! En unos minutos llego a recogerte',
      'Hola, ya salí hacia tu ubicación. Tiempo estimado: {eta} minutos'
    ],
    arrival: [
      'Ya llegué, te espero afuera 📍',
      'Estoy en el punto de recogida',
      'Ya estoy aquí. {vehicleInfo}'
    ],
    delay: [
      'Disculpa, hay tráfico. Llegaré en {minutes} minutos',
      'Tendré una demora de aproximadamente {minutes} minutos',
      'El tráfico está complicado, pero ya estoy cerca'
    ],
    quickReplies: [
      'Sí', 'No', 'En camino', 'Ya llegué', '5 minutos más', 'OK'
    ]
  },
  passenger: {
    greeting: [
      'Hola, gracias por aceptar mi viaje',
      'Perfecto, te espero',
      'Genial, aquí estoy esperando'
    ],
    location: [
      'Estoy en {landmark}',
      'Me puedes encontrar cerca de {reference}',
      'Estoy usando {clothing}'
    ],
    delay: [
      'Dame 5 minutos más por favor',
      'Ya bajo, un momento',
      'Disculpa la demora, ya salgo'
    ],
    quickReplies: [
      'OK', 'Gracias', 'En camino', 'Ya salgo', '2 minutos', 'Perfecto'
    ]
  }
};

// 🚀 Servicio de Chat
class ChatService extends EventEmitter {
  private io: Server | null = null;
  private activeConnections: Map<string, Socket> = new Map();
  private typingTimers: Map<string, NodeJS.Timeout> = new Map();

  /**
   * Inicializar servicio con Socket.io
   */
  initialize(io: Server): void {
    this.io = io;
    logger.info('💬 ChatService inicializado con Socket.io');
  }

  /**
   * 📝 Crear nueva conversación
   */
  async createConversation(data: {
    rideId?: string;
    passengerId: string;
    passengerName: string;
    passengerAvatar?: string;
    driverId: string;
    driverName: string;
    driverAvatar?: string;
  }): Promise<ChatConversation> {
    try {
      // Verificar si ya existe una conversación activa
      const existingQuery = await admin.firestore()
        .collection('conversations')
        .where('participants.passengerId', '==', data.passengerId)
        .where('participants.driverId', '==', data.driverId)
        .where('isActive', '==', true)
        .get();

      if (!existingQuery.empty) {
        return existingQuery.docs[0].data() as ChatConversation;
      }

      const conversationId = crypto.randomBytes(16).toString('hex');
      const conversation: ChatConversation = {
        id: conversationId,
        rideId: data.rideId,
        participants: {
          passengerId: data.passengerId,
          passengerName: data.passengerName,
          passengerAvatar: data.passengerAvatar,
          driverId: data.driverId,
          driverName: data.driverName,
          driverAvatar: data.driverAvatar
        },
        unreadCount: {
          passenger: 0,
          driver: 0
        },
        isActive: true,
        isPinned: false,
        isMuted: {
          passenger: false,
          driver: false
        },
        typingStatus: {
          passenger: false,
          driver: false
        },
        startedAt: new Date(),
        createdAt: new Date(),
        updatedAt: new Date()
      };

      await admin.firestore()
        .collection('conversations')
        .doc(conversationId)
        .set(conversation);

      // Enviar mensaje de sistema
      await this.sendSystemMessage(conversationId, 'Conversación iniciada');

      // Notificar a ambos participantes
      this.emitToUser(data.passengerId, 'conversation:created', conversation);
      this.emitToUser(data.driverId, 'conversation:created', conversation);

      logger.info(`Nueva conversación creada: ${conversationId}`);
      return conversation;
    } catch (error) {
      logger.error('Error creando conversación:', error);
      throw new AppError('Error al crear conversación', 500, 'CONVERSATION_CREATE_ERROR');
    }
  }

  /**
   * 💬 Enviar mensaje
   */
  async sendMessage(data: {
    conversationId: string;
    senderId: string;
    senderName: string;
    senderRole: 'passenger' | 'driver';
    content: string;
    type?: MessageType;
    metadata?: any;
    replyTo?: string;
  }): Promise<ChatMessage> {
    try {
      // Validar conversación
      const conversationDoc = await admin.firestore()
        .collection('conversations')
        .doc(data.conversationId)
        .get();

      if (!conversationDoc.exists) {
        throw new AppError('Conversación no encontrada', 404, 'CONVERSATION_NOT_FOUND');
      }

      const conversation = conversationDoc.data() as ChatConversation;

      if (!conversation.isActive) {
        throw new AppError('La conversación está cerrada', 400, 'CONVERSATION_CLOSED');
      }

      // Determinar destinatario
      const recipientId = data.senderRole === 'passenger' 
        ? conversation.participants.driverId 
        : conversation.participants.passengerId;

      // Crear mensaje
      const messageId = crypto.randomBytes(16).toString('hex');
      const message: ChatMessage = {
        id: messageId,
        conversationId: data.conversationId,
        senderId: data.senderId,
        senderName: data.senderName,
        senderRole: data.senderRole,
        recipientId,
        type: data.type || MessageType.TEXT,
        content: data.content,
        metadata: data.metadata,
        status: MessageStatus.SENDING,
        replyTo: data.replyTo,
        reactions: new Map(),
        createdAt: new Date(),
        updatedAt: new Date()
      };

      // Guardar mensaje
      await admin.firestore()
        .collection('messages')
        .doc(messageId)
        .set(message);

      // Actualizar estado a SENT
      message.status = MessageStatus.SENT;
      await admin.firestore()
        .collection('messages')
        .doc(messageId)
        .update({ status: MessageStatus.SENT });

      // Actualizar última actividad de conversación
      await admin.firestore()
        .collection('conversations')
        .doc(data.conversationId)
        .update({
          lastMessage: {
            id: messageId,
            content: data.content,
            senderId: data.senderId,
            timestamp: new Date(),
            type: data.type || MessageType.TEXT
          },
          [`unreadCount.${data.senderRole === 'passenger' ? 'driver' : 'passenger'}`]: 
            admin.firestore.FieldValue.increment(1),
          updatedAt: new Date()
        });

      // Emitir mensaje en tiempo real
      this.emitToUser(recipientId, 'message:new', message);
      this.emitToUser(data.senderId, 'message:sent', message);

      // Verificar si el destinatario está conectado
      if (this.activeConnections.has(recipientId)) {
        // Marcar como entregado
        message.status = MessageStatus.DELIVERED;
        message.deliveredAt = new Date();
        
        await admin.firestore()
          .collection('messages')
          .doc(messageId)
          .update({ 
            status: MessageStatus.DELIVERED,
            deliveredAt: message.deliveredAt 
          });

        this.emitToUser(data.senderId, 'message:delivered', { messageId });
      }

      // Enviar notificación push si no está muted
      const isMuted = data.senderRole === 'passenger' 
        ? conversation.isMuted.driver 
        : conversation.isMuted.passenger;

      if (!isMuted && !this.activeConnections.has(recipientId)) {
        await this.sendMessageNotification(recipientId, message);
      }

      logger.info(`Mensaje enviado: ${messageId}`);
      return message;
    } catch (error) {
      logger.error('Error enviando mensaje:', error);
      throw error;
    }
  }

  /**
   * 📤 Enviar mensaje de sistema
   */
  async sendSystemMessage(conversationId: string, content: string): Promise<void> {
    const messageId = crypto.randomBytes(16).toString('hex');
    const message: ChatMessage = {
      id: messageId,
      conversationId,
      senderId: 'system',
      senderName: 'Sistema',
      senderRole: 'system',
      recipientId: 'all',
      type: MessageType.SYSTEM,
      content,
      status: MessageStatus.SENT,
      createdAt: new Date(),
      updatedAt: new Date()
    };

    await admin.firestore()
      .collection('messages')
      .doc(messageId)
      .set(message);

    // Emitir a todos los participantes
    const conversationDoc = await admin.firestore()
      .collection('conversations')
      .doc(conversationId)
      .get();

    if (conversationDoc.exists) {
      const conversation = conversationDoc.data() as ChatConversation;
      this.emitToUser(conversation.participants.passengerId, 'message:system', message);
      this.emitToUser(conversation.participants.driverId, 'message:system', message);
    }
  }

  /**
   * ✅ Marcar mensaje como leído
   */
  async markAsRead(data: {
    messageId: string;
    userId: string;
  }): Promise<void> {
    try {
      const messageDoc = await admin.firestore()
        .collection('messages')
        .doc(data.messageId)
        .get();

      if (!messageDoc.exists) {
        throw new AppError('Mensaje no encontrado', 404, 'MESSAGE_NOT_FOUND');
      }

      const message = messageDoc.data() as ChatMessage;

      // Solo el destinatario puede marcar como leído
      if (message.recipientId !== data.userId) {
        throw new AppError('No autorizado', 403, 'UNAUTHORIZED');
      }

      // Actualizar estado
      await admin.firestore()
        .collection('messages')
        .doc(data.messageId)
        .update({
          status: MessageStatus.READ,
          readAt: new Date()
        });

      // Actualizar contador de no leídos
      const role = message.senderRole === 'passenger' ? 'driver' : 'passenger';
      await admin.firestore()
        .collection('conversations')
        .doc(message.conversationId)
        .update({
          [`unreadCount.${role}`]: admin.firestore.FieldValue.increment(-1)
        });

      // Notificar al remitente
      this.emitToUser(message.senderId, 'message:read', {
        messageId: data.messageId,
        readAt: new Date()
      });

      logger.info(`Mensaje marcado como leído: ${data.messageId}`);
    } catch (error) {
      logger.error('Error marcando mensaje como leído:', error);
      throw error;
    }
  }

  /**
   * ⌨️ Indicador de escritura
   */
  async setTypingStatus(data: {
    conversationId: string;
    userId: string;
    userRole: 'passenger' | 'driver';
    isTyping: boolean;
  }): Promise<void> {
    try {
      // Limpiar timer anterior si existe
      const timerKey = `${data.conversationId}_${data.userId}`;
      if (this.typingTimers.has(timerKey)) {
        clearTimeout(this.typingTimers.get(timerKey)!);
        this.typingTimers.delete(timerKey);
      }

      // Actualizar estado en Firestore
      await admin.firestore()
        .collection('conversations')
        .doc(data.conversationId)
        .update({
          [`typingStatus.${data.userRole}`]: data.isTyping,
          updatedAt: new Date()
        });

      // Obtener conversación para notificar al otro usuario
      const conversationDoc = await admin.firestore()
        .collection('conversations')
        .doc(data.conversationId)
        .get();

      if (conversationDoc.exists) {
        const conversation = conversationDoc.data() as ChatConversation;
        const recipientId = data.userRole === 'passenger' 
          ? conversation.participants.driverId 
          : conversation.participants.passengerId;

        // Emitir evento de typing
        this.emitToUser(recipientId, 'typing:status', {
          conversationId: data.conversationId,
          userId: data.userId,
          isTyping: data.isTyping
        });

        // Auto-desactivar typing después de 5 segundos
        if (data.isTyping) {
          const timer = setTimeout(() => {
            this.setTypingStatus({
              ...data,
              isTyping: false
            });
          }, 5000);
          this.typingTimers.set(timerKey, timer);
        }
      }
    } catch (error) {
      logger.error('Error actualizando estado de escritura:', error);
    }
  }

  /**
   * 📎 Enviar archivo/imagen
   */
  async sendMedia(data: {
    conversationId: string;
    senderId: string;
    senderName: string;
    senderRole: 'passenger' | 'driver';
    type: MessageType.IMAGE | MessageType.AUDIO | MessageType.VIDEO | MessageType.FILE;
    fileUrl: string;
    fileName?: string;
    fileSize?: number;
    duration?: number;
    thumbnailUrl?: string;
  }): Promise<ChatMessage> {
    const metadata: any = {
      fileName: data.fileName,
      fileSize: data.fileSize
    };

    switch (data.type) {
      case MessageType.IMAGE:
        metadata.imageUrl = data.fileUrl;
        metadata.thumbnailUrl = data.thumbnailUrl;
        break;
      case MessageType.AUDIO:
        metadata.audioUrl = data.fileUrl;
        metadata.duration = data.duration;
        break;
      case MessageType.VIDEO:
        metadata.videoUrl = data.fileUrl;
        metadata.duration = data.duration;
        metadata.thumbnailUrl = data.thumbnailUrl;
        break;
      case MessageType.FILE:
        metadata.fileUrl = data.fileUrl;
        break;
    }

    return this.sendMessage({
      conversationId: data.conversationId,
      senderId: data.senderId,
      senderName: data.senderName,
      senderRole: data.senderRole,
      content: data.fileName || 'Archivo multimedia',
      type: data.type,
      metadata
    });
  }

  /**
   * 📍 Compartir ubicación
   */
  async shareLocation(data: {
    conversationId: string;
    senderId: string;
    senderName: string;
    senderRole: 'passenger' | 'driver';
    latitude: number;
    longitude: number;
    address?: string;
  }): Promise<ChatMessage> {
    return this.sendMessage({
      conversationId: data.conversationId,
      senderId: data.senderId,
      senderName: data.senderName,
      senderRole: data.senderRole,
      content: data.address || 'Ubicación compartida',
      type: MessageType.LOCATION,
      metadata: {
        location: {
          latitude: data.latitude,
          longitude: data.longitude,
          address: data.address
        }
      }
    });
  }

  /**
   * 😀 Agregar reacción a mensaje
   */
  async addReaction(data: {
    messageId: string;
    userId: string;
    emoji: string;
  }): Promise<void> {
    try {
      await admin.firestore()
        .collection('messages')
        .doc(data.messageId)
        .update({
          [`reactions.${data.userId}`]: data.emoji,
          updatedAt: new Date()
        });

      // Obtener mensaje para notificar
      const messageDoc = await admin.firestore()
        .collection('messages')
        .doc(data.messageId)
        .get();

      if (messageDoc.exists) {
        const message = messageDoc.data() as ChatMessage;
        
        // Notificar a ambos usuarios
        this.emitToUser(message.senderId, 'message:reaction', {
          messageId: data.messageId,
          userId: data.userId,
          emoji: data.emoji
        });

        if (message.recipientId !== data.userId) {
          this.emitToUser(message.recipientId, 'message:reaction', {
            messageId: data.messageId,
            userId: data.userId,
            emoji: data.emoji
          });
        }
      }
    } catch (error) {
      logger.error('Error agregando reacción:', error);
      throw error;
    }
  }

  /**
   * 🗑️ Eliminar mensaje
   */
  async deleteMessage(data: {
    messageId: string;
    userId: string;
  }): Promise<void> {
    try {
      const messageDoc = await admin.firestore()
        .collection('messages')
        .doc(data.messageId)
        .get();

      if (!messageDoc.exists) {
        throw new AppError('Mensaje no encontrado', 404, 'MESSAGE_NOT_FOUND');
      }

      const message = messageDoc.data() as ChatMessage;

      // Solo el remitente puede eliminar su mensaje
      if (message.senderId !== data.userId) {
        throw new AppError('No autorizado', 403, 'UNAUTHORIZED');
      }

      // Soft delete
      await admin.firestore()
        .collection('messages')
        .doc(data.messageId)
        .update({
          content: 'Mensaje eliminado',
          deletedAt: new Date(),
          updatedAt: new Date()
        });

      // Notificar a ambos usuarios
      const deleteEvent = {
        messageId: data.messageId,
        deletedAt: new Date()
      };

      this.emitToUser(message.senderId, 'message:deleted', deleteEvent);
      this.emitToUser(message.recipientId, 'message:deleted', deleteEvent);

      logger.info(`Mensaje eliminado: ${data.messageId}`);
    } catch (error) {
      logger.error('Error eliminando mensaje:', error);
      throw error;
    }
  }

  /**
   * 📜 Obtener historial de mensajes
   */
  async getMessageHistory(data: {
    conversationId: string;
    userId: string;
    limit?: number;
    before?: Date;
  }): Promise<ChatMessage[]> {
    try {
      // Verificar que el usuario es participante
      const conversationDoc = await admin.firestore()
        .collection('conversations')
        .doc(data.conversationId)
        .get();

      if (!conversationDoc.exists) {
        throw new AppError('Conversación no encontrada', 404, 'CONVERSATION_NOT_FOUND');
      }

      const conversation = conversationDoc.data() as ChatConversation;
      const isParticipant = 
        data.userId === conversation.participants.passengerId ||
        data.userId === conversation.participants.driverId;

      if (!isParticipant) {
        throw new AppError('No autorizado', 403, 'UNAUTHORIZED');
      }

      // Construir query
      let query = admin.firestore()
        .collection('messages')
        .where('conversationId', '==', data.conversationId)
        .orderBy('createdAt', 'desc')
        .limit(data.limit || 50);

      if (data.before) {
        query = query.where('createdAt', '<', data.before);
      }

      const messagesSnapshot = await query.get();
      const messages = messagesSnapshot.docs.map(doc => doc.data() as ChatMessage);

      // Marcar mensajes no leídos como entregados
      const undeliveredMessages = messages.filter(
        m => m.recipientId === data.userId && m.status === MessageStatus.SENT
      );

      if (undeliveredMessages.length > 0) {
        const batch = admin.firestore().batch();
        undeliveredMessages.forEach(msg => {
          batch.update(
            admin.firestore().collection('messages').doc(msg.id),
            { 
              status: MessageStatus.DELIVERED,
              deliveredAt: new Date()
            }
          );
        });
        await batch.commit();
      }

      return messages.reverse(); // Devolver en orden cronológico
    } catch (error) {
      logger.error('Error obteniendo historial:', error);
      throw error;
    }
  }

  /**
   * 📋 Obtener conversaciones del usuario
   */
  async getUserConversations(userId: string, userRole: 'passenger' | 'driver'): Promise<ChatConversation[]> {
    try {
      const field = userRole === 'passenger' ? 'participants.passengerId' : 'participants.driverId';
      
      const conversationsSnapshot = await admin.firestore()
        .collection('conversations')
        .where(field, '==', userId)
        .orderBy('updatedAt', 'desc')
        .limit(20)
        .get();

      return conversationsSnapshot.docs.map(doc => doc.data() as ChatConversation);
    } catch (error) {
      logger.error('Error obteniendo conversaciones:', error);
      throw error;
    }
  }

  /**
   * 🔕 Silenciar/Desilenciar conversación
   */
  async toggleMute(data: {
    conversationId: string;
    userId: string;
    userRole: 'passenger' | 'driver';
    mute: boolean;
  }): Promise<void> {
    try {
      await admin.firestore()
        .collection('conversations')
        .doc(data.conversationId)
        .update({
          [`isMuted.${data.userRole}`]: data.mute,
          updatedAt: new Date()
        });

      logger.info(`Conversación ${data.mute ? 'silenciada' : 'desilenciada'}: ${data.conversationId}`);
    } catch (error) {
      logger.error('Error cambiando estado de silencio:', error);
      throw error;
    }
  }

  /**
   * 📌 Fijar/Desfijar conversación
   */
  async togglePin(data: {
    conversationId: string;
    userId: string;
    pin: boolean;
  }): Promise<void> {
    try {
      await admin.firestore()
        .collection('conversations')
        .doc(data.conversationId)
        .update({
          isPinned: data.pin,
          updatedAt: new Date()
        });

      logger.info(`Conversación ${data.pin ? 'fijada' : 'desfijada'}: ${data.conversationId}`);
    } catch (error) {
      logger.error('Error cambiando estado de fijado:', error);
      throw error;
    }
  }

  /**
   * 🔚 Cerrar conversación
   */
  async closeConversation(conversationId: string): Promise<void> {
    try {
      await admin.firestore()
        .collection('conversations')
        .doc(conversationId)
        .update({
          isActive: false,
          endedAt: new Date(),
          updatedAt: new Date()
        });

      // Enviar mensaje de sistema
      await this.sendSystemMessage(conversationId, 'Conversación finalizada');

      logger.info(`Conversación cerrada: ${conversationId}`);
    } catch (error) {
      logger.error('Error cerrando conversación:', error);
      throw error;
    }
  }

  /**
   * 🔔 Enviar notificación push de mensaje
   */
  private async sendMessageNotification(userId: string, message: ChatMessage): Promise<void> {
    try {
      await notificationService.sendNotification({
        userId,
        type: 'chat' as any,
        title: '💬 Nuevo mensaje',
        body: `${message.senderName}: ${message.content}`,
        data: {
          type: 'new_message',
          conversationId: message.conversationId,
          messageId: message.id,
          senderId: message.senderId,
          senderName: message.senderName
        }
      });
    } catch (error) {
      logger.error('Error enviando notificación de mensaje:', error);
    }
  }

  /**
   * 📡 Emitir evento a usuario específico
   */
  private emitToUser(userId: string, event: string, data: any): void {
    if (!this.io) return;

    const socket = this.activeConnections.get(userId);
    if (socket) {
      socket.emit(event, data);
      logger.debug(`Evento ${event} emitido a usuario ${userId}`);
    }
  }

  /**
   * 🔌 Registrar conexión de socket
   */
  registerConnection(userId: string, socket: Socket): void {
    this.activeConnections.set(userId, socket);
    logger.info(`Usuario ${userId} conectado al chat`);

    // Limpiar al desconectar
    socket.on('disconnect', () => {
      this.activeConnections.delete(userId);
      logger.info(`Usuario ${userId} desconectado del chat`);
    });
  }

  /**
   * 🎯 Obtener templates de mensajes
   */
  getMessageTemplates(role: 'passenger' | 'driver'): typeof MESSAGE_TEMPLATES[keyof typeof MESSAGE_TEMPLATES] {
    return MESSAGE_TEMPLATES[role];
  }

  /**
   * 🔍 Buscar en mensajes
   */
  async searchMessages(data: {
    conversationId: string;
    userId: string;
    query: string;
    limit?: number;
  }): Promise<ChatMessage[]> {
    try {
      // Verificar autorización
      const conversationDoc = await admin.firestore()
        .collection('conversations')
        .doc(data.conversationId)
        .get();

      if (!conversationDoc.exists) {
        throw new AppError('Conversación no encontrada', 404, 'CONVERSATION_NOT_FOUND');
      }

      const conversation = conversationDoc.data() as ChatConversation;
      const isParticipant = 
        data.userId === conversation.participants.passengerId ||
        data.userId === conversation.participants.driverId;

      if (!isParticipant) {
        throw new AppError('No autorizado', 403, 'UNAUTHORIZED');
      }

      // Buscar mensajes (simplificado, en producción usar Algolia/ElasticSearch)
      const messagesSnapshot = await admin.firestore()
        .collection('messages')
        .where('conversationId', '==', data.conversationId)
        .orderBy('createdAt', 'desc')
        .limit(data.limit || 100)
        .get();

      const messages = messagesSnapshot.docs
        .map(doc => doc.data() as ChatMessage)
        .filter(msg => 
          msg.content.toLowerCase().includes(data.query.toLowerCase()) &&
          !msg.deletedAt
        );

      return messages;
    } catch (error) {
      logger.error('Error buscando mensajes:', error);
      throw error;
    }
  }

  /**
   * 📊 Obtener estadísticas de chat
   */
  async getChatStats(conversationId: string): Promise<{
    totalMessages: number;
    messagesByType: Record<MessageType, number>;
    averageResponseTime: number;
    participantStats: {
      passenger: { sent: number; responseTime: number };
      driver: { sent: number; responseTime: number };
    };
  }> {
    try {
      const messagesSnapshot = await admin.firestore()
        .collection('messages')
        .where('conversationId', '==', conversationId)
        .orderBy('createdAt', 'asc')
        .get();

      const messages = messagesSnapshot.docs.map(doc => doc.data() as ChatMessage);

      // Calcular estadísticas
      const stats = {
        totalMessages: messages.length,
        messagesByType: {} as Record<MessageType, number>,
        averageResponseTime: 0,
        participantStats: {
          passenger: { sent: 0, responseTime: 0 },
          driver: { sent: 0, responseTime: 0 }
        }
      };

      // Contar por tipo
      Object.values(MessageType).forEach(type => {
        stats.messagesByType[type] = messages.filter(m => m.type === type).length;
      });

      // Contar por participante y calcular tiempos de respuesta
      let responseTimes: number[] = [];
      messages.forEach((msg, index) => {
        if (msg.senderRole === 'passenger') {
          stats.participantStats.passenger.sent++;
        } else if (msg.senderRole === 'driver') {
          stats.participantStats.driver.sent++;
        }

        // Calcular tiempo de respuesta
        if (index > 0 && messages[index - 1].senderId !== msg.senderId) {
          const responseTime = msg.createdAt.getTime() - messages[index - 1].createdAt.getTime();
          responseTimes.push(responseTime);
        }
      });

      // Promedios
      if (responseTimes.length > 0) {
        stats.averageResponseTime = 
          responseTimes.reduce((a, b) => a + b, 0) / responseTimes.length / 1000; // en segundos
      }

      return stats;
    } catch (error) {
      logger.error('Error obteniendo estadísticas:', error);
      throw error;
    }
  }
}

// Exportar instancia única
export const chatService = new ChatService();