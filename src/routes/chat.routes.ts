import { Router, Request, Response, NextFunction } from 'express';
import { body, param, query, validationResult } from 'express-validator';
import admin from 'firebase-admin';
import { logger } from '../utils/logger';
import twilio from 'twilio';

const router = Router();
const db = admin.firestore();

// Configurar Twilio para VoIP (si está disponible)
let twilioClient: twilio.Twilio | null = null;
if (process.env.TWILIO_ACCOUNT_SID && process.env.TWILIO_AUTH_TOKEN) {
  twilioClient = twilio(
    process.env.TWILIO_ACCOUNT_SID,
    process.env.TWILIO_AUTH_TOKEN
  );
}

// Tipos de datos
interface ChatMessage {
  id?: string;
  rideId: string;
  senderId: string;
  senderType: 'passenger' | 'driver';
  senderName?: string;
  text: string;
  type: 'text' | 'image' | 'audio' | 'location';
  imageUrl?: string;
  audioUrl?: string;
  location?: {
    latitude: number;
    longitude: number;
  };
  timestamp: FirebaseFirestore.Timestamp;
  read: boolean;
  delivered: boolean;
}

interface VoiceCall {
  id?: string;
  rideId: string;
  callerId: string;
  callerType: 'passenger' | 'driver';
  receiverId: string;
  receiverType: 'passenger' | 'driver';
  status: 'initiated' | 'ringing' | 'answered' | 'ended' | 'missed' | 'rejected';
  startTime: FirebaseFirestore.Timestamp;
  endTime?: FirebaseFirestore.Timestamp;
  duration?: number;
  recordingUrl?: string;
}

// Middleware de validación común
const handleValidationErrors = (req: Request, res: Response, next: NextFunction): void => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    res.status(400).json({
      success: false,
      message: 'Errores de validación',
      errors: errors.array()
    });
    return;
  }
  next();
};

// Middleware para verificar autenticación
const authMiddleware = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) {
      res.status(401).json({ success: false, message: 'Token no proporcionado' });
      return;
    }
    
    const decodedToken = await admin.auth().verifyIdToken(token);
    req['userId'] = decodedToken.uid;
    req['userRole'] = decodedToken.role || 'passenger';
    next();
  } catch (error) {
    res.status(401).json({ success: false, message: 'Token inválido' });
  }
};

// Validaciones para enviar mensaje
const sendMessageValidation = [
  body('rideId')
    .isString()
    .notEmpty()
    .withMessage('ID de viaje requerido'),
  body('text')
    .optional()
    .isString()
    .isLength({ min: 1, max: 1000 })
    .withMessage('El mensaje debe tener entre 1 y 1000 caracteres'),
  body('type')
    .isIn(['text', 'image', 'audio', 'location'])
    .withMessage('Tipo de mensaje inválido'),
  body('imageUrl')
    .optional()
    .isURL()
    .withMessage('URL de imagen inválida'),
  body('audioUrl')
    .optional()
    .isURL()
    .withMessage('URL de audio inválida'),
  body('location')
    .optional()
    .isObject()
    .withMessage('Ubicación debe ser un objeto'),
  body('location.latitude')
    .optional()
    .isFloat({ min: -90, max: 90 })
    .withMessage('Latitud inválida'),
  body('location.longitude')
    .optional()
    .isFloat({ min: -180, max: 180 })
    .withMessage('Longitud inválida'),
  handleValidationErrors
];

// Validación para obtener mensajes
const getMessagesValidation = [
  param('rideId')
    .isString()
    .notEmpty()
    .withMessage('ID de viaje requerido'),
  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 })
    .withMessage('Límite debe ser entre 1 y 100'),
  query('before')
    .optional()
    .isISO8601()
    .withMessage('Fecha debe ser válida'),
  handleValidationErrors
];

// Validación para marcar como leído
const markAsReadValidation = [
  param('rideId')
    .isString()
    .notEmpty()
    .withMessage('ID de viaje requerido'),
  body('messageIds')
    .isArray()
    .withMessage('IDs de mensajes debe ser un array'),
  body('messageIds.*')
    .isString()
    .withMessage('Cada ID de mensaje debe ser una cadena'),
  handleValidationErrors
];

// Validación para llamada VoIP
const voiceCallValidation = [
  body('rideId')
    .isString()
    .notEmpty()
    .withMessage('ID de viaje requerido'),
  body('receiverId')
    .isString()
    .notEmpty()
    .withMessage('ID del receptor requerido'),
  handleValidationErrors
];

// POST /api/v1/chat/send - Enviar mensaje
router.post('/send', authMiddleware, sendMessageValidation, async (req: Request, res: Response): Promise<void> => {
  try {
    const { rideId, text, type, imageUrl, audioUrl, location } = req.body;
    const senderId = req['userId'];
    const senderType = req['userRole'] as 'passenger' | 'driver';
    
    logger.info('💬 Send message', { rideId, senderId, type });
    
    // Verificar que el viaje existe y el usuario está involucrado
    const rideDoc = await db.collection('rides').doc(rideId).get();
    if (!rideDoc.exists) {
      res.status(404).json({
        success: false,
        message: 'Viaje no encontrado'
      });
      return;
    }
    
    const rideData = rideDoc.data();
    
    // Verificar permisos
    if (senderType === 'passenger' && rideData?.passengerId !== senderId) {
      res.status(403).json({
        success: false,
        message: 'No tienes permiso para enviar mensajes en este viaje'
      });
      return;
    }
    
    if (senderType === 'driver' && rideData?.driverId !== senderId) {
      res.status(403).json({
        success: false,
        message: 'No tienes permiso para enviar mensajes en este viaje'
      });
      return;
    }
    
    // Obtener información del remitente
    const senderDoc = await db.collection('users').doc(senderId).get();
    const senderData = senderDoc.data();
    
    // Crear el mensaje
    const message: ChatMessage = {
      rideId,
      senderId,
      senderType,
      senderName: senderData?.name || 'Usuario',
      text: text || '',
      type,
      timestamp: admin.firestore.FieldValue.serverTimestamp() as FirebaseFirestore.Timestamp,
      read: false,
      delivered: false
    };
    
    // Agregar campos opcionales según el tipo
    if (type === 'image' && imageUrl) {
      message.imageUrl = imageUrl;
    } else if (type === 'audio' && audioUrl) {
      message.audioUrl = audioUrl;
    } else if (type === 'location' && location) {
      message.location = location;
    } else if (type === 'text' && !text) {
      res.status(400).json({
        success: false,
        message: 'Texto requerido para mensajes de tipo texto'
      });
      return;
    }
    
    // Guardar el mensaje en Firestore
    const chatRef = db.collection('chats').doc(rideId);
    const messagesRef = chatRef.collection('messages');
    const messageDoc = await messagesRef.add(message);
    
    // Actualizar el último mensaje en el chat
    await chatRef.set({
      lastMessage: text || `[${type}]`,
      lastMessageTime: admin.firestore.FieldValue.serverTimestamp(),
      lastMessageSender: senderId,
      unreadCount: admin.firestore.FieldValue.increment(1)
    }, { merge: true });
    
    // Determinar el receptor
    const receiverId = senderType === 'passenger' ? rideData?.driverId : rideData?.passengerId;
    
    // Enviar notificación push al receptor
    if (receiverId) {
      const receiverDoc = await db.collection('users').doc(receiverId).get();
      const receiverData = receiverDoc.data();
      
      if (receiverData?.fcmToken) {
        const notificationBody = type === 'text' 
          ? text 
          : type === 'image' 
            ? '📷 Imagen' 
            : type === 'audio' 
              ? '🎵 Audio' 
              : '📍 Ubicación';
        
        await admin.messaging().send({
          token: receiverData.fcmToken,
          notification: {
            title: `Mensaje de ${senderData?.name || 'Usuario'}`,
            body: notificationBody
          },
          data: {
            type: 'chat_message',
            rideId,
            messageId: messageDoc.id,
            senderId,
            messageType: type
          },
          android: {
            priority: 'high',
            notification: {
              channelId: 'chat_messages',
              sound: 'default'
            }
          },
          apns: {
            payload: {
              aps: {
                alert: {
                  title: `Mensaje de ${senderData?.name || 'Usuario'}`,
                  body: notificationBody
                },
                sound: 'default',
                badge: 1
              }
            }
          }
        });
      }
      
      // Marcar como entregado
      await messageDoc.update({
        delivered: true,
        deliveredAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }
    
    res.status(201).json({
      success: true,
      message: 'Mensaje enviado exitosamente',
      data: {
        messageId: messageDoc.id,
        ...message,
        timestamp: new Date()
      }
    });
    
  } catch (error) {
    logger.error('Error enviando mensaje:', error);
    res.status(500).json({
      success: false,
      message: 'Error interno del servidor'
    });
  }
});

// GET /api/v1/chat/:rideId/messages - Obtener mensajes del chat
router.get('/:rideId/messages', authMiddleware, getMessagesValidation, async (req: Request, res: Response): Promise<void> => {
  try {
    const { rideId } = req.params;
    const { limit = 50, before } = req.query;
    const userId = req['userId'];
    const userRole = req['userRole'];
    
    logger.info('💬 Get messages', { rideId, userId, limit });
    
    // Verificar que el viaje existe y el usuario está involucrado
    const rideDoc = await db.collection('rides').doc(rideId).get();
    if (!rideDoc.exists) {
      res.status(404).json({
        success: false,
        message: 'Viaje no encontrado'
      });
      return;
    }
    
    const rideData = rideDoc.data();
    
    // Verificar permisos
    const isPassenger = userRole === 'passenger' && rideData?.passengerId === userId;
    const isDriver = userRole === 'driver' && rideData?.driverId === userId;
    
    if (!isPassenger && !isDriver) {
      res.status(403).json({
        success: false,
        message: 'No tienes permiso para ver estos mensajes'
      });
      return;
    }
    
    // Construir query para obtener mensajes
    let query = db.collection('chats')
      .doc(rideId)
      .collection('messages')
      .orderBy('timestamp', 'desc')
      .limit(Number(limit));
    
    // Si se proporciona 'before', obtener mensajes anteriores a esa fecha
    if (before) {
      const beforeDate = new Date(before as string);
      query = query.where('timestamp', '<', beforeDate);
    }
    
    const messagesSnapshot = await query.get();
    
    const messages = messagesSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
    
    // Marcar mensajes como leídos si son del otro usuario
    const unreadMessages = messages.filter(msg => 
      msg.senderId !== userId && !msg.read
    );
    
    if (unreadMessages.length > 0) {
      const batch = db.batch();
      
      for (const msg of unreadMessages) {
        const msgRef = db.collection('chats')
          .doc(rideId)
          .collection('messages')
          .doc(msg.id);
        
        batch.update(msgRef, {
          read: true,
          readAt: admin.firestore.FieldValue.serverTimestamp()
        });
      }
      
      await batch.commit();
      
      // Actualizar contador de no leídos
      await db.collection('chats').doc(rideId).update({
        unreadCount: 0
      });
    }
    
    // Obtener información de los participantes
    const participantIds = new Set<string>();
    if (rideData?.passengerId) participantIds.add(rideData.passengerId);
    if (rideData?.driverId) participantIds.add(rideData.driverId);
    
    const participantsData = {};
    for (const participantId of participantIds) {
      const userDoc = await db.collection('users').doc(participantId).get();
      if (userDoc.exists) {
        participantsData[participantId] = {
          name: userDoc.data()?.name,
          photoUrl: userDoc.data()?.photoUrl,
          role: participantId === rideData?.driverId ? 'driver' : 'passenger'
        };
      }
    }
    
    res.json({
      success: true,
      message: 'Mensajes obtenidos exitosamente',
      data: {
        messages: messages.reverse(), // Devolver en orden cronológico
        participants: participantsData,
        totalUnread: 0
      }
    });
    
  } catch (error) {
    logger.error('Error obteniendo mensajes:', error);
    res.status(500).json({
      success: false,
      message: 'Error interno del servidor'
    });
  }
});

// PUT /api/v1/chat/:rideId/read - Marcar mensajes como leídos
router.put('/:rideId/read', authMiddleware, markAsReadValidation, async (req: Request, res: Response): Promise<void> => {
  try {
    const { rideId } = req.params;
    const { messageIds } = req.body;
    const userId = req['userId'];
    
    logger.info('✓ Mark messages as read', { rideId, messageIds: messageIds.length });
    
    // Verificar permisos
    const rideDoc = await db.collection('rides').doc(rideId).get();
    if (!rideDoc.exists) {
      res.status(404).json({
        success: false,
        message: 'Viaje no encontrado'
      });
      return;
    }
    
    const batch = db.batch();
    
    for (const messageId of messageIds) {
      const msgRef = db.collection('chats')
        .doc(rideId)
        .collection('messages')
        .doc(messageId);
      
      batch.update(msgRef, {
        read: true,
        readAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }
    
    await batch.commit();
    
    // Actualizar contador de no leídos
    const unreadSnapshot = await db.collection('chats')
      .doc(rideId)
      .collection('messages')
      .where('senderId', '!=', userId)
      .where('read', '==', false)
      .get();
    
    await db.collection('chats').doc(rideId).update({
      unreadCount: unreadSnapshot.size
    });
    
    res.json({
      success: true,
      message: 'Mensajes marcados como leídos',
      data: {
        markedCount: messageIds.length
      }
    });
    
  } catch (error) {
    logger.error('Error marcando mensajes como leídos:', error);
    res.status(500).json({
      success: false,
      message: 'Error interno del servidor'
    });
  }
});

// POST /api/v1/chat/call - Iniciar llamada VoIP
router.post('/call', authMiddleware, voiceCallValidation, async (req: Request, res: Response): Promise<void> => {
  try {
    const { rideId, receiverId } = req.body;
    const callerId = req['userId'];
    const callerType = req['userRole'] as 'passenger' | 'driver';
    
    logger.info('📞 Initiate VoIP call', { rideId, callerId, receiverId });
    
    // Verificar que el viaje existe
    const rideDoc = await db.collection('rides').doc(rideId).get();
    if (!rideDoc.exists) {
      res.status(404).json({
        success: false,
        message: 'Viaje no encontrado'
      });
      return;
    }
    
    const rideData = rideDoc.data();
    
    // Verificar permisos
    const isValidCall = 
      (callerType === 'passenger' && rideData?.passengerId === callerId && rideData?.driverId === receiverId) ||
      (callerType === 'driver' && rideData?.driverId === callerId && rideData?.passengerId === receiverId);
    
    if (!isValidCall) {
      res.status(403).json({
        success: false,
        message: 'No tienes permiso para realizar esta llamada'
      });
      return;
    }
    
    // Obtener información de ambos usuarios
    const [callerDoc, receiverDoc] = await Promise.all([
      db.collection('users').doc(callerId).get(),
      db.collection('users').doc(receiverId).get()
    ]);
    
    const callerData = callerDoc.data();
    const receiverData = receiverDoc.data();
    
    // Crear registro de llamada
    const callData: VoiceCall = {
      rideId,
      callerId,
      callerType,
      receiverId,
      receiverType: callerType === 'passenger' ? 'driver' : 'passenger',
      status: 'initiated',
      startTime: admin.firestore.FieldValue.serverTimestamp() as FirebaseFirestore.Timestamp
    };
    
    const callDoc = await db.collection('calls').add(callData);
    const callId = callDoc.id;
    
    // Si Twilio está configurado, crear sala de llamada
    let twilioRoom = null;
    if (twilioClient) {
      try {
        // Crear una sala de video/voz en Twilio
        twilioRoom = await twilioClient.video.rooms.create({
          uniqueName: `ride-${rideId}-call-${callId}`,
          type: 'peer-to-peer',
          statusCallback: `${process.env.API_URL}/webhooks/twilio/room-status`,
          maxParticipants: 2
        });
        
        // Generar tokens de acceso para ambos participantes
        const AccessToken = require('twilio').jwt.AccessToken;
        const VideoGrant = AccessToken.VideoGrant;
        
        const callerToken = new AccessToken(
          process.env.TWILIO_ACCOUNT_SID,
          process.env.TWILIO_API_KEY,
          process.env.TWILIO_API_SECRET,
          { identity: callerId }
        );
        
        const callerGrant = new VideoGrant({
          room: twilioRoom.uniqueName
        });
        callerToken.addGrant(callerGrant);
        
        const receiverToken = new AccessToken(
          process.env.TWILIO_ACCOUNT_SID,
          process.env.TWILIO_API_KEY,
          process.env.TWILIO_API_SECRET,
          { identity: receiverId }
        );
        
        const receiverGrant = new VideoGrant({
          room: twilioRoom.uniqueName
        });
        receiverToken.addGrant(receiverGrant);
        
        // Actualizar registro con información de Twilio
        await callDoc.update({
          twilioRoomSid: twilioRoom.sid,
          twilioRoomName: twilioRoom.uniqueName
        });
      } catch (twilioError) {
        logger.error('Error configurando Twilio:', twilioError);
        // Continuar sin Twilio
      }
    }
    
    // Enviar notificación push al receptor
    if (receiverData?.fcmToken) {
      await admin.messaging().send({
        token: receiverData.fcmToken,
        notification: {
          title: 'Llamada entrante',
          body: `${callerData?.name || 'Usuario'} te está llamando`
        },
        data: {
          type: 'incoming_call',
          callId,
          rideId,
          callerId,
          callerName: callerData?.name || 'Usuario',
          callerPhoto: callerData?.photoUrl || '',
          twilioRoom: twilioRoom?.uniqueName || ''
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'calls',
            sound: 'ringtone',
            priority: 'max',
            visibility: 'public'
          }
        },
        apns: {
          payload: {
            aps: {
              alert: {
                title: 'Llamada entrante',
                body: `${callerData?.name || 'Usuario'} te está llamando`
              },
              sound: 'ringtone.caf',
              badge: 1,
              contentAvailable: true
            }
          }
        }
      });
    }
    
    res.status(201).json({
      success: true,
      message: 'Llamada iniciada',
      data: {
        callId,
        status: 'initiated',
        twilioRoom: twilioRoom?.uniqueName || null,
        callerToken: twilioRoom ? 'TOKEN_AQUÍ' : null // En producción, devolver el token real
      }
    });
    
  } catch (error) {
    logger.error('Error iniciando llamada:', error);
    res.status(500).json({
      success: false,
      message: 'Error interno del servidor'
    });
  }
});

// POST /api/v1/chat/call/:callId/answer - Responder llamada
router.post('/call/:callId/answer', authMiddleware, async (req: Request, res: Response): Promise<void> => {
  try {
    const { callId } = req.params;
    const userId = req['userId'];
    
    logger.info('📞 Answer call', { callId, userId });
    
    const callDoc = await db.collection('calls').doc(callId).get();
    if (!callDoc.exists) {
      res.status(404).json({
        success: false,
        message: 'Llamada no encontrada'
      });
      return;
    }
    
    const callData = callDoc.data() as VoiceCall;
    
    // Verificar que el usuario es el receptor
    if (callData.receiverId !== userId) {
      res.status(403).json({
        success: false,
        message: 'No puedes responder esta llamada'
      });
      return;
    }
    
    // Actualizar estado de la llamada
    await callDoc.ref.update({
      status: 'answered',
      answeredAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Generar token de Twilio si está configurado
    let receiverToken = null;
    if (twilioClient && callData.twilioRoomName) {
      const AccessToken = require('twilio').jwt.AccessToken;
      const VideoGrant = AccessToken.VideoGrant;
      
      const token = new AccessToken(
        process.env.TWILIO_ACCOUNT_SID,
        process.env.TWILIO_API_KEY,
        process.env.TWILIO_API_SECRET,
        { identity: userId }
      );
      
      const grant = new VideoGrant({
        room: callData.twilioRoomName
      });
      token.addGrant(grant);
      
      receiverToken = token.toJwt();
    }
    
    res.json({
      success: true,
      message: 'Llamada respondida',
      data: {
        callId,
        status: 'answered',
        twilioRoom: callData.twilioRoomName || null,
        receiverToken
      }
    });
    
  } catch (error) {
    logger.error('Error respondiendo llamada:', error);
    res.status(500).json({
      success: false,
      message: 'Error interno del servidor'
    });
  }
});

// POST /api/v1/chat/call/:callId/end - Finalizar llamada
router.post('/call/:callId/end', authMiddleware, async (req: Request, res: Response): Promise<void> => {
  try {
    const { callId } = req.params;
    const userId = req['userId'];
    
    logger.info('📞 End call', { callId, userId });
    
    const callDoc = await db.collection('calls').doc(callId).get();
    if (!callDoc.exists) {
      res.status(404).json({
        success: false,
        message: 'Llamada no encontrada'
      });
      return;
    }
    
    const callData = callDoc.data() as VoiceCall;
    
    // Verificar que el usuario está en la llamada
    if (callData.callerId !== userId && callData.receiverId !== userId) {
      res.status(403).json({
        success: false,
        message: 'No puedes finalizar esta llamada'
      });
      return;
    }
    
    // Calcular duración si la llamada fue respondida
    let duration = 0;
    if (callData.status === 'answered' && callData.answeredAt) {
      const startTime = callData.answeredAt.toDate();
      const endTime = new Date();
      duration = Math.floor((endTime.getTime() - startTime.getTime()) / 1000);
    }
    
    // Actualizar estado de la llamada
    await callDoc.ref.update({
      status: 'ended',
      endTime: admin.firestore.FieldValue.serverTimestamp(),
      duration,
      endedBy: userId
    });
    
    // Finalizar sala de Twilio si existe
    if (twilioClient && callData.twilioRoomSid) {
      try {
        await twilioClient.video.rooms(callData.twilioRoomSid).update({
          status: 'completed'
        });
      } catch (twilioError) {
        logger.error('Error finalizando sala de Twilio:', twilioError);
      }
    }
    
    // Registrar en el historial del viaje
    await db.collection('ride_events').add({
      rideId: callData.rideId,
      type: 'call_ended',
      callId,
      duration,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
    
    res.json({
      success: true,
      message: 'Llamada finalizada',
      data: {
        callId,
        duration,
        status: 'ended'
      }
    });
    
  } catch (error) {
    logger.error('Error finalizando llamada:', error);
    res.status(500).json({
      success: false,
      message: 'Error interno del servidor'
    });
  }
});

// POST /api/v1/chat/call/:callId/reject - Rechazar llamada
router.post('/call/:callId/reject', authMiddleware, async (req: Request, res: Response): Promise<void> => {
  try {
    const { callId } = req.params;
    const userId = req['userId'];
    
    logger.info('📞 Reject call', { callId, userId });
    
    const callDoc = await db.collection('calls').doc(callId).get();
    if (!callDoc.exists) {
      res.status(404).json({
        success: false,
        message: 'Llamada no encontrada'
      });
      return;
    }
    
    const callData = callDoc.data() as VoiceCall;
    
    // Verificar que el usuario es el receptor
    if (callData.receiverId !== userId) {
      res.status(403).json({
        success: false,
        message: 'No puedes rechazar esta llamada'
      });
      return;
    }
    
    // Actualizar estado de la llamada
    await callDoc.ref.update({
      status: 'rejected',
      endTime: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Notificar al llamador
    const callerDoc = await db.collection('users').doc(callData.callerId).get();
    const callerFcmToken = callerDoc.data()?.fcmToken;
    
    if (callerFcmToken) {
      await admin.messaging().send({
        token: callerFcmToken,
        notification: {
          title: 'Llamada rechazada',
          body: 'Tu llamada fue rechazada'
        },
        data: {
          type: 'call_rejected',
          callId
        }
      });
    }
    
    res.json({
      success: true,
      message: 'Llamada rechazada',
      data: {
        callId,
        status: 'rejected'
      }
    });
    
  } catch (error) {
    logger.error('Error rechazando llamada:', error);
    res.status(500).json({
      success: false,
      message: 'Error interno del servidor'
    });
  }
});

// GET /api/v1/chat/:rideId/typing - Indicador de escritura
router.post('/:rideId/typing', authMiddleware, async (req: Request, res: Response): Promise<void> => {
  try {
    const { rideId } = req.params;
    const { isTyping } = req.body;
    const userId = req['userId'];
    
    logger.debug('✍️ Typing indicator', { rideId, userId, isTyping });
    
    // Actualizar estado de escritura en Firestore
    await db.collection('chats').doc(rideId).set({
      [`typing_${userId}`]: isTyping,
      [`typingTimestamp_${userId}`]: isTyping 
        ? admin.firestore.FieldValue.serverTimestamp()
        : admin.firestore.FieldValue.delete()
    }, { merge: true });
    
    res.json({
      success: true,
      message: 'Estado de escritura actualizado'
    });
    
  } catch (error) {
    logger.error('Error actualizando indicador de escritura:', error);
    res.status(500).json({
      success: false,
      message: 'Error interno del servidor'
    });
  }
});

export default router;