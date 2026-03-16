import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'firebase_service.dart';
import 'notification_service.dart';

/// Servicio completo para el sistema de chat
/// ✅ IMPLEMENTACIÓN CON FIRESTORE (más estable que Realtime Database)
/// Incluye: Firestore, Mensajes multimedia, Estado de lectura, Notificaciones
class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final FirebaseService _firebaseService = FirebaseService();
  final NotificationService _notificationService = NotificationService();

  bool _initialized = false;
  String? _currentUserId;
  String? _currentUserRole;

  // ✅ Usar Firestore en lugar de Realtime Database
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  // Colecciones de Firestore
  static const String chatsCollection = 'chats';
  static const String messagesCollection = 'messages';
  static const String presenceCollection = 'userPresence';

  // Streams para mensajes en tiempo real
  final Map<String, Stream<List<ChatMessage>>> _chatStreams = {};

  /// Inicializar el servicio de chat ✅ IMPLEMENTACIÓN CON FIRESTORE
  Future<void> initialize({
    required String userId,
    required String userRole,
  }) async {
    _currentUserId = userId;
    _currentUserRole = userRole;
    if (_initialized) return;

    try {
      await _firebaseService.initialize();
      await _notificationService.initialize();

      // ✅ Configurar presencia del usuario en Firestore
      await _setupUserPresence();

      _initialized = true;
      debugPrint('💬 ChatService: Inicializado para usuario $userId');

      await _firebaseService.analytics.logEvent(
        name: 'chat_service_initialized',
        parameters: {
          'user_id': userId,
          'user_role': userRole,
        },
      );

    } catch (e) {
      debugPrint('💬 ChatService: Error inicializando - $e');
      await _firebaseService.crashlytics.recordError(e, null);
      _initialized = true; // Marcar como inicializado para evitar loops
    }
  }

  /// Enviar mensaje de texto ✅ IMPLEMENTACIÓN CON FIRESTORE
  Future<bool> sendTextMessage({
    required String rideId,
    required String senderId,
    required String senderName,
    required String message,
    required String senderRole, // 'passenger' o 'driver'
  }) async {
    try {
      // ✅ Crear documento de mensaje en Firestore
      final docRef = _firestore
          .collection(chatsCollection)
          .doc(rideId)
          .collection(messagesCollection)
          .doc();

      final chatMessage = ChatMessage(
        id: docRef.id,
        rideId: rideId,
        senderId: senderId,
        senderName: senderName,
        message: message,
        messageType: MessageType.text,
        senderRole: senderRole,
        timestamp: DateTime.now(),
        isRead: false,
      );

      // Guardar mensaje en Firestore
      await docRef.set(chatMessage.toFirestoreMap());

      // Actualizar metadatos del chat
      await _updateChatMetadata(rideId, chatMessage);

      // La notificación al destinatario se envía vía FCM desde Cloud Functions,
      // NO localmente (para evitar que el remitente reciba su propio mensaje)

      debugPrint('💬 ChatService: Mensaje enviado en viaje $rideId');

      await _firebaseService.analytics.logEvent(
        name: 'chat_message_sent',
        parameters: {
          'ride_id': rideId,
          'sender_role': senderRole,
          'message_type': 'text',
        },
      );

      return true;
    } catch (e) {
      debugPrint('💬 ChatService: Error enviando mensaje - $e');
      await _firebaseService.crashlytics.recordError(e, null);
      return false;
    }
  }

  /// Enviar mensaje multimedia ✅ IMPLEMENTACIÓN CON FIRESTORE
  Future<bool> sendMultimediaMessage({
    required String rideId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required File mediaFile,
    required MessageType messageType,
    String? caption,
  }) async {
    try {
      // Subir archivo a Firebase Storage
      final uploadResult = await _uploadMediaFile(rideId, mediaFile, messageType);
      if (!uploadResult.success) {
        return false;
      }

      // ✅ Crear documento de mensaje en Firestore
      final docRef = _firestore
          .collection(chatsCollection)
          .doc(rideId)
          .collection(messagesCollection)
          .doc();

      final chatMessage = ChatMessage(
        id: docRef.id,
        rideId: rideId,
        senderId: senderId,
        senderName: senderName,
        message: caption ?? '',
        messageType: messageType,
        mediaUrl: uploadResult.downloadUrl,
        mediaFileName: uploadResult.fileName,
        senderRole: senderRole,
        timestamp: DateTime.now(),
        isRead: false,
      );

      // Guardar mensaje en Firestore
      await docRef.set(chatMessage.toFirestoreMap());

      // Actualizar metadatos del chat
      await _updateChatMetadata(rideId, chatMessage);

      // La notificación al destinatario se envía vía FCM desde Cloud Functions,
      // NO localmente (para evitar que el remitente reciba su propio mensaje)

      debugPrint('💬 ChatService: Mensaje multimedia enviado en viaje $rideId');

      await _firebaseService.analytics.logEvent(
        name: 'chat_message_sent',
        parameters: {
          'ride_id': rideId,
          'sender_role': senderRole,
          'message_type': messageType.toString(),
        },
      );

      return true;
    } catch (e) {
      debugPrint('💬 ChatService: Error enviando mensaje multimedia - $e');
      await _firebaseService.crashlytics.recordError(e, null);
      return false;
    }
  }

  // Método legacy mantenido para compatibilidad
  Future<bool> sendMessage({
    required String rideId,
    required String senderId,
    required String senderName,
    required String message,
    required String senderRole,
  }) async {
    return sendTextMessage(
      rideId: rideId,
      senderId: senderId,
      senderName: senderName,
      message: message,
      senderRole: senderRole,
    );
  }

  /// Marcar mensajes como leídos ✅ IMPLEMENTACIÓN CON FIRESTORE
  Future<void> markMessagesAsRead(String rideId, String userId) async {
    try {
      // Obtener mensajes no leídos de otros usuarios
      final messagesQuery = await _firestore
          .collection(chatsCollection)
          .doc(rideId)
          .collection(messagesCollection)
          .where('isRead', isEqualTo: false)
          .get();

      if (messagesQuery.docs.isNotEmpty) {
        final batch = _firestore.batch();
        int count = 0;

        for (final doc in messagesQuery.docs) {
          final data = doc.data();
          // Marcar como leído solo si no es el remitente
          if (data['senderId'] != userId) {
            batch.update(doc.reference, {
              'isRead': true,
              'readAt': FieldValue.serverTimestamp(),
            });
            count++;
          }
        }

        if (count > 0) {
          await batch.commit();
          debugPrint('💬 ChatService: $count mensajes marcados como leídos');
        }
      }

      await _firebaseService.analytics.logEvent(
        name: 'chat_messages_marked_read',
        parameters: {
          'ride_id': rideId,
          'user_id': userId,
        },
      );
    } catch (e) {
      debugPrint('💬 ChatService: Error marcando mensajes como leídos - $e');
      await _firebaseService.crashlytics.recordError(e, null);
    }
  }

  /// Obtener número de mensajes no leídos ✅ IMPLEMENTACIÓN CON FIRESTORE
  Future<int> getUnreadCount(String rideId, String userId) async {
    try {
      final snapshot = await _firestore
          .collection(chatsCollection)
          .doc(rideId)
          .collection(messagesCollection)
          .where('isRead', isEqualTo: false)
          .get();

      int count = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['senderId'] != userId) {
          count++;
        }
      }

      return count;
    } catch (e) {
      debugPrint('💬 ChatService: Error obteniendo conteo de no leídos - $e');
      return 0;
    }
  }

  /// Obtener stream de mensajes en tiempo real ✅ IMPLEMENTACIÓN CON FIRESTORE
  Stream<List<ChatMessage>> getChatMessages(String rideId) {
    // Always create a fresh stream to avoid stale cached errors
    _chatStreams[rideId] = _firestore
        .collection(chatsCollection)
        .doc(rideId)
        .collection(messagesCollection)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      final List<ChatMessage> messages = [];

      for (final doc in snapshot.docs) {
        try {
          final message = ChatMessage.fromFirestoreDoc(doc);
          messages.add(message);
        } catch (e) {
          debugPrint('💬 ChatService: Error parseando mensaje ${doc.id} - $e');
        }
      }

      return messages;
    }).handleError((error) {
      debugPrint('💬 ChatService: Error en stream de mensajes - $error');
      _chatStreams.remove(rideId);
      return <ChatMessage>[];
    });

    return _chatStreams[rideId]!;
  }

  // Enviar mensaje predefinido
  Future<bool> sendQuickMessage({
    required String rideId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required QuickMessageType type,
  }) async {
    final message = _getQuickMessageText(type, senderRole);
    return sendMessage(
      rideId: rideId,
      senderId: senderId,
      senderName: senderName,
      message: message,
      senderRole: senderRole,
    );
  }

  // Obtener texto de mensaje rápido
  String _getQuickMessageText(QuickMessageType type, String senderRole) {
    if (senderRole == 'driver') {
      switch (type) {
        case QuickMessageType.onMyWay:
          return 'Estoy en camino';
        case QuickMessageType.arrived:
          return 'He llegado, te espero';
        case QuickMessageType.waiting:
          return 'Esperando en el punto de encuentro';
        case QuickMessageType.trafficDelay:
          return 'Hay tráfico, llegaré en unos minutos';
        case QuickMessageType.cantFind:
          return 'No puedo encontrar la ubicación exacta';
      }
    } else {
      switch (type) {
        case QuickMessageType.onMyWay:
          return 'Ya voy saliendo';
        case QuickMessageType.arrived:
          return 'Ya estoy aquí';
        case QuickMessageType.waiting:
          return 'Te estoy esperando';
        case QuickMessageType.trafficDelay:
          return 'Puedes esperar un poco más?';
        case QuickMessageType.cantFind:
          return 'No te veo, dónde estás?';
      }
    }
  }

  // Compartir ubicación
  Future<bool> shareLocation({
    required String rideId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required double latitude,
    required double longitude,
  }) async {
    final message = '📍 Mi ubicación: https://maps.google.com/?q=$latitude,$longitude';
    return sendMessage(
      rideId: rideId,
      senderId: senderId,
      senderName: senderName,
      message: message,
      senderRole: senderRole,
    );
  }

  /// Limpiar chat de un viaje ✅ IMPLEMENTACIÓN CON FIRESTORE
  Future<void> clearChat(String rideId) async {
    try {
      // Eliminar todos los mensajes del chat
      final messagesSnapshot = await _firestore
          .collection(chatsCollection)
          .doc(rideId)
          .collection(messagesCollection)
          .get();

      final batch = _firestore.batch();
      for (final doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Eliminar el documento del chat
      await _firestore.collection(chatsCollection).doc(rideId).delete();

      _chatStreams.remove(rideId);
      debugPrint('💬 ChatService: Chat limpiado para viaje $rideId');
    } catch (e) {
      debugPrint('💬 ChatService: Error limpiando chat - $e');
    }
  }

  /// Configurar presencia del usuario ✅ IMPLEMENTACIÓN CON FIRESTORE
  Future<void> _setupUserPresence() async {
    if (_currentUserId == null) return;

    try {
      await _firestore.collection(presenceCollection).doc(_currentUserId!).set({
        'online': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'role': _currentUserRole,
      }, SetOptions(merge: true));

      debugPrint('💬 ChatService: Presencia de usuario configurada');
    } catch (e) {
      debugPrint('💬 ChatService: Error configurando presencia - $e');
    }
  }

  /// Actualizar metadatos del chat ✅ IMPLEMENTACIÓN CON FIRESTORE
  Future<void> _updateChatMetadata(String rideId, ChatMessage message) async {
    try {
      await _firestore.collection(chatsCollection).doc(rideId).set({
        'lastMessage': message.message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSender': message.senderName,
        'lastSenderRole': message.senderRole,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('💬 ChatService: Error actualizando metadatos del chat - $e');
    }
  }

  /// Subir archivo multimedia ✅ IMPLEMENTACIÓN REAL
  Future<MediaUploadResult> _uploadMediaFile(String rideId, File file, MessageType messageType) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final storageRef = _firebaseService.storage
          .ref()
          .child('chat_media')
          .child(rideId)
          .child(fileName);

      final uploadTask = storageRef.putFile(file);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return MediaUploadResult.success(
        downloadUrl: downloadUrl,
        fileName: fileName,
      );
    } catch (e) {
      debugPrint('💬 ChatService: Error uploading media file - $e');
      return MediaUploadResult.error('Error subiendo archivo: $e');
    }
  }

  /// Obtener estado de presencia de usuario ✅ IMPLEMENTACIÓN CON FIRESTORE
  Stream<UserPresence> getUserPresence(String userId) {
    return _firestore
        .collection(presenceCollection)
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        DateTime lastSeen = DateTime.now();
        if (data['lastSeen'] != null) {
          if (data['lastSeen'] is Timestamp) {
            lastSeen = (data['lastSeen'] as Timestamp).toDate();
          }
        }
        return UserPresence(
          online: data['online'] ?? false,
          lastSeen: lastSeen,
          role: data['role'],
        );
      }
      return UserPresence(online: false, lastSeen: DateTime.now());
    });
  }

  void dispose() {
    _chatStreams.clear();
  }

  // Getters
  bool get isInitialized => _initialized;
  String? get currentUserId => _currentUserId;
  String? get currentUserRole => _currentUserRole;
}

/// Modelo de mensaje de chat completo ✅ IMPLEMENTACIÓN REAL
class ChatMessage {
  final String id;
  final String rideId;
  final String senderId;
  final String senderName;
  final String message;
  final MessageType messageType;
  final String? mediaUrl;
  final String? mediaFileName;
  final String senderRole;
  final DateTime timestamp;
  bool isRead;
  final DateTime? readAt;

  ChatMessage({
    required this.id,
    required this.rideId,
    required this.senderId,
    required this.senderName,
    required this.message,
    this.messageType = MessageType.text,
    this.mediaUrl,
    this.mediaFileName,
    required this.senderRole,
    required this.timestamp,
    required this.isRead,
    this.readAt,
  });

  /// ✅ Convertir a mapa para Firestore
  Map<String, dynamic> toFirestoreMap() {
    return {
      'rideId': rideId,
      'senderId': senderId,
      'senderName': senderName,
      'message': message,
      'messageType': messageType.toString(),
      'mediaUrl': mediaUrl,
      'mediaFileName': mediaFileName,
      'senderRole': senderRole,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
    };
  }

  /// ✅ Crear desde documento de Firestore
  factory ChatMessage.fromFirestoreDoc(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>? ?? {};
    DateTime timestamp = DateTime.now();
    if (map['timestamp'] != null) {
      if (map['timestamp'] is Timestamp) {
        timestamp = (map['timestamp'] as Timestamp).toDate();
      }
    }
    DateTime? readAt;
    if (map['readAt'] != null && map['readAt'] is Timestamp) {
      readAt = (map['readAt'] as Timestamp).toDate();
    }

    return ChatMessage(
      id: doc.id,
      rideId: map['rideId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      message: map['message'] ?? '',
      messageType: MessageType.values.firstWhere(
        (type) => type.toString() == map['messageType'],
        orElse: () => MessageType.text,
      ),
      mediaUrl: map['mediaUrl'],
      mediaFileName: map['mediaFileName'],
      senderRole: map['senderRole'] ?? '',
      timestamp: timestamp,
      isRead: map['isRead'] ?? false,
      readAt: readAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rideId': rideId,
      'senderId': senderId,
      'senderName': senderName,
      'message': message,
      'messageType': messageType.toString(),
      'mediaUrl': mediaUrl,
      'mediaFileName': mediaFileName,
      'senderRole': senderRole,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'readAt': readAt?.toIso8601String(),
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] ?? '',
      rideId: map['rideId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      message: map['message'] ?? '',
      messageType: MessageType.values.firstWhere(
        (type) => type.toString() == map['messageType'],
        orElse: () => MessageType.text,
      ),
      mediaUrl: map['mediaUrl'],
      mediaFileName: map['mediaFileName'],
      senderRole: map['senderRole'] ?? '',
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      isRead: map['isRead'] ?? false,
      readAt: map['readAt'] != null ? DateTime.tryParse(map['readAt']) : null,
    );
  }
}

/// Enums para el sistema de chat ✅ IMPLEMENTACIÓN REAL

enum MessageType {
  text,
  image,
  audio,
  video,
  file,
  location,
}

enum QuickMessageType {
  onMyWay,
  arrived,
  waiting,
  trafficDelay,
  cantFind,
}

/// Clases de datos para el sistema de chat ✅ IMPLEMENTACIÓN REAL

class MediaUploadResult {
  final bool success;
  final String? downloadUrl;
  final String? fileName;
  final String? error;

  MediaUploadResult.success({
    required this.downloadUrl,
    required this.fileName,
  }) : success = true, error = null;

  MediaUploadResult.error(this.error)
      : success = false,
        downloadUrl = null,
        fileName = null;
}

class UserPresence {
  final bool online;
  final DateTime lastSeen;
  final String? role;

  UserPresence({
    required this.online,
    required this.lastSeen,
    this.role,
  });
}

class ChatMetadata {
  final String rideId;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? lastSender;
  final String? lastSenderRole;
  final int messageCount;

  ChatMetadata({
    required this.rideId,
    this.lastMessage,
    this.lastMessageTime,
    this.lastSender,
    this.lastSenderRole,
    this.messageCount = 0,
  });

  factory ChatMetadata.fromMap(Map<String, dynamic> map) {
    return ChatMetadata(
      rideId: map['rideId'] ?? '',
      lastMessage: map['lastMessage'],
      lastMessageTime: map['lastMessageTime'] != null 
          ? DateTime.tryParse(map['lastMessageTime'])
          : null,
      lastSender: map['lastSender'],
      lastSenderRole: map['lastSenderRole'],
      messageCount: map['messageCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'rideId': rideId,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.toIso8601String(),
      'lastSender': lastSender,
      'lastSenderRole': lastSenderRole,
      'messageCount': messageCount,
    };
  }
}