import 'dart:async';
import 'package:flutter/material.dart';
// ignore_for_file: unnecessary_cast
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/logger.dart';

// Modelo para mensaje de chat
class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String senderRole; // 'passenger', 'driver', 'support'
  final String receiverId;
  final String tripId;
  final String message;
  final String? imageUrl;
  final MessageType type;
  final MessageStatus status;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.receiverId,
    required this.tripId,
    required this.message,
    this.imageUrl,
    required this.type,
    required this.status,
    required this.timestamp,
    this.metadata,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map, String id) {
    return ChatMessage(
      id: id,
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      senderRole: map['senderRole'] ?? 'passenger',
      receiverId: map['receiverId'] ?? '',
      tripId: map['tripId'] ?? '',
      message: map['message'] ?? '',
      imageUrl: map['imageUrl'],
      type: MessageType.values.firstWhere(
        (e) => e.toString() == 'MessageType.${map['type']}',
        orElse: () => MessageType.text,
      ),
      status: MessageStatus.values.firstWhere(
        (e) => e.toString() == 'MessageStatus.${map['status']}',
        orElse: () => MessageStatus.sent,
      ),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: map['metadata'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'receiverId': receiverId,
      'tripId': tripId,
      'message': message,
      'imageUrl': imageUrl,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'timestamp': Timestamp.fromDate(timestamp),
      'metadata': metadata,
    };
  }
}

enum MessageType { text, image, location, audio, system }
enum MessageStatus { sending, sent, delivered, read, failed }

// Modelo para conversación
class ChatConversation {
  final String id;
  final String tripId;
  final List<String> participantIds;
  final Map<String, ParticipantInfo> participants;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final bool isActive;
  final DateTime createdAt;

  ChatConversation({
    required this.id,
    required this.tripId,
    required this.participantIds,
    required this.participants,
    this.lastMessage,
    this.lastMessageTime,
    required this.unreadCount,
    required this.isActive,
    required this.createdAt,
  });

  factory ChatConversation.fromMap(Map<String, dynamic> map, String id) {
    final participantsMap = <String, ParticipantInfo>{};
    if (map['participants'] != null) {
      (map['participants'] as Map<String, dynamic>).forEach((key, value) {
        participantsMap[key] = ParticipantInfo.fromMap(value);
      });
    }

    return ChatConversation(
      id: id,
      tripId: map['tripId'] ?? '',
      participantIds: List<String>.from(map['participantIds'] ?? []),
      participants: participantsMap,
      lastMessage: map['lastMessage'],
      lastMessageTime: (map['lastMessageTime'] as Timestamp?)?.toDate(),
      unreadCount: map['unreadCount'] ?? 0,
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class ParticipantInfo {
  final String name;
  final String role;
  final String? photoUrl;
  final bool isOnline;
  final DateTime? lastSeen;

  ParticipantInfo({
    required this.name,
    required this.role,
    this.photoUrl,
    required this.isOnline,
    this.lastSeen,
  });

  factory ParticipantInfo.fromMap(Map<String, dynamic> map) {
    return ParticipantInfo(
      name: map['name'] ?? '',
      role: map['role'] ?? '',
      photoUrl: map['photoUrl'],
      isOnline: map['isOnline'] ?? false,
      lastSeen: (map['lastSeen'] as Timestamp?)?.toDate(),
    );
  }
}

class ChatProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Estado
  List<ChatMessage> _messages = [];
  List<ChatConversation> _conversations = [];
  ChatConversation? _activeConversation;
  bool _isLoading = false;
  String? _error;
  bool _isTyping = false;
  String? _typingUserId;
  final bool _isSendingMessage = false;
  
  // Controladores para streams
  Stream<QuerySnapshot>? _messagesStream;
  Stream<QuerySnapshot>? _conversationsStream;
  Stream<DocumentSnapshot>? _typingStream;

  // Subscriptions para evitar memory leaks
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  StreamSubscription<DocumentSnapshot>? _typingSubscription;
  StreamSubscription<QuerySnapshot>? _conversationsSubscription;
  
  // Getters
  List<ChatMessage> get messages => _messages;
  List<ChatConversation> get conversations => _conversations;
  ChatConversation? get activeConversation => _activeConversation;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isTyping => _isTyping;
  String? get typingUserId => _typingUserId;
  bool get isSendingMessage => _isSendingMessage;

  // Inicializar chat para un viaje
  Future<void> initializeChatForTrip(String tripId, String otherUserId, String otherUserName, String otherUserRole) async {
    _setLoading(true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      // Buscar conversación existente
      final existingConversation = await _firestore
          .collection('conversations')
          .where('tripId', isEqualTo: tripId)
          .where('participantIds', arrayContains: user.uid)
          .limit(1)
          .get();

      String conversationId;

      if (existingConversation.docs.isNotEmpty) {
        // Usar conversación existente
        conversationId = existingConversation.docs.first.id;
        _activeConversation = ChatConversation.fromMap(
          existingConversation.docs.first.data(),
          conversationId,
        );
      } else {
        // Crear nueva conversación
        final currentUserDoc = await _firestore.collection('users').doc(user.uid).get();
        final currentUserData = currentUserDoc.data() ?? {};

        final conversationData = {
          'tripId': tripId,
          'participantIds': [user.uid, otherUserId],
          'participants': {
            user.uid: {
              'name': currentUserData['name'] ?? 'Usuario',
              'role': currentUserData['role'] ?? 'passenger',
              'photoUrl': currentUserData['photoUrl'],
              'isOnline': true,
              'lastSeen': FieldValue.serverTimestamp(),
            },
            otherUserId: {
              'name': otherUserName,
              'role': otherUserRole,
              'photoUrl': null,
              'isOnline': false,
              'lastSeen': FieldValue.serverTimestamp(),
            },
          },
          'lastMessage': null,
          'lastMessageTime': null,
          'unreadCount': 0,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        };

        final docRef = await _firestore.collection('conversations').add(conversationData);
        conversationId = docRef.id;
        
        _activeConversation = ChatConversation(
          id: conversationId,
          tripId: tripId,
          participantIds: [user.uid, otherUserId],
          participants: {},
          unreadCount: 0,
          isActive: true,
          createdAt: DateTime.now(),
        );
      }

      // Configurar stream de mensajes
      _setupMessageStream(conversationId);
      
      // Configurar stream de estado de escritura
      _setupTypingStream(conversationId);
      
      // Marcar mensajes como leídos
      await markMessagesAsRead(conversationId);
      
      _setLoading(false);
    } catch (e) {
      _setError('Error al inicializar chat: $e');
      _setLoading(false);
    }
  }

  // Configurar stream de mensajes
  void _setupMessageStream(String conversationId) {
    _messagesStream = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots();

    _messagesSubscription?.cancel();
    _messagesSubscription = _messagesStream?.handleError((error) {
      // Error en stream de mensajes
    }).listen((snapshot) {
      _messages = snapshot.docs
          .map((doc) => ChatMessage.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      notifyListeners();
    });
  }

  // Configurar stream de estado de escritura
  void _setupTypingStream(String conversationId) {
    _typingStream = _firestore
        .collection('conversations')
        .doc(conversationId)
        .snapshots();

    _typingSubscription?.cancel();
    _typingSubscription = _typingStream?.handleError((error) {
      // Error en stream de typing
    }).listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        final typingData = data is Map<String, dynamic> ? data['typing'] : null;

        if (typingData != null) {
          final user = _auth.currentUser;
          typingData.forEach((userId, isTyping) {
            if (userId != user?.uid && isTyping == true) {
              _isTyping = true;
              _typingUserId = userId;
            } else {
              _isTyping = false;
              _typingUserId = null;
            }
          });
        }
      }
      notifyListeners();
    });
  }

  // Enviar mensaje
  Future<bool> sendMessage({
    required String message,
    String? imageUrl,
    MessageType type = MessageType.text,
    Map<String, dynamic>? metadata,
  }) async {
    if (_activeConversation == null) {
      _setError('No hay conversación activa');
      return false;
    }

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final currentUserDoc = await _firestore.collection('users').doc(user.uid).get();
      final currentUserData = currentUserDoc.data() ?? {};

      // Determinar receptor
      final receiverId = _activeConversation!.participantIds
          .firstWhere((id) => id != user.uid);

      final chatMessage = ChatMessage(
        id: '',
        senderId: user.uid,
        senderName: currentUserData['name'] ?? 'Usuario',
        senderRole: currentUserData['role'] ?? 'passenger',
        receiverId: receiverId,
        tripId: _activeConversation!.tripId,
        message: message,
        imageUrl: imageUrl,
        type: type,
        status: MessageStatus.sending,
        timestamp: DateTime.now(),
        metadata: metadata,
      );

      // Agregar mensaje a la colección
      final messageRef = await _firestore
          .collection('conversations')
          .doc(_activeConversation!.id)
          .collection('messages')
          .add(chatMessage.toMap());

      // Actualizar conversación
      await _firestore
          .collection('conversations')
          .doc(_activeConversation!.id)
          .update({
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Actualizar estado del mensaje
      await messageRef.update({'status': 'sent'});

      // Enviar notificación push al receptor
      await _sendPushNotification(receiverId, message, currentUserData['name'] ?? 'Usuario');

      return true;
    } catch (e) {
      _setError('Error al enviar mensaje: $e');
      return false;
    }
  }

  // Marcar mensajes como leídos
  Future<void> markMessagesAsRead(String conversationId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Obtener mensajes no leídos
      final unreadMessages = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .where('receiverId', isEqualTo: user.uid)
          .where('status', isNotEqualTo: 'read')
          .get();

      // Batch update
      final batch = _firestore.batch();
      
      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {'status': 'read'});
      }

      // Resetear contador de no leídos
      batch.update(
        _firestore.collection('conversations').doc(conversationId),
        {'unreadCount': 0},
      );

      await batch.commit();
    } catch (e) {
      AppLogger.error('Error marcando mensajes como leídos', e);
    }
  }

  // Actualizar estado de escritura
  Future<void> updateTypingStatus(bool isTyping) async {
    if (_activeConversation == null) return;

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore
          .collection('conversations')
          .doc(_activeConversation!.id)
          .update({
        'typing.${user.uid}': isTyping,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.error('Error actualizando estado de escritura', e);
    }
  }

  // Cargar conversaciones del usuario
  Future<void> loadUserConversations() async {
    _setLoading(true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      _conversationsStream = _firestore
          .collection('conversations')
          .where('participantIds', arrayContains: user.uid)
          .orderBy('lastMessageTime', descending: true)
          .snapshots();

      _conversationsSubscription?.cancel();
      _conversationsSubscription = _conversationsStream?.handleError((error) {
        // Error en stream de conversaciones
      }).listen((snapshot) {
        _conversations = snapshot.docs
            .map((doc) => ChatConversation.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList();
        notifyListeners();
      });

      _setLoading(false);
    } catch (e) {
      _setError('Error al cargar conversaciones: $e');
      _setLoading(false);
    }
  }

  // Enviar mensaje predefinido
  Future<bool> sendQuickMessage(String template) async {
    final quickMessages = {
      'arrived': 'He llegado al punto de recogida',
      'waiting': 'Estoy esperando en el lugar acordado',
      'on_way': 'Estoy en camino',
      'delayed': 'Llegaré con un poco de retraso',
      'thanks': 'Gracias por el viaje',
      'problem': 'Hay un problema con el viaje',
    };

    final message = quickMessages[template] ?? template;
    return await sendMessage(message: message);
  }

  // Enviar ubicación
  Future<bool> sendLocation(double lat, double lng, String address) async {
    return await sendMessage(
      message: address,
      type: MessageType.location,
      metadata: {
        'lat': lat,
        'lng': lng,
        'address': address,
      },
    );
  }

  // Finalizar conversación
  Future<void> endConversation() async {
    if (_activeConversation == null) return;

    try {
      await _firestore
          .collection('conversations')
          .doc(_activeConversation!.id)
          .update({
        'isActive': false,
        'endedAt': FieldValue.serverTimestamp(),
      });

      // Enviar mensaje del sistema
      await sendMessage(
        message: 'La conversación ha finalizado',
        type: MessageType.system,
      );

      _activeConversation = null;
      _messages.clear();
      notifyListeners();
    } catch (e) {
      AppLogger.error('Error al finalizar conversación', e);
    }
  }

  // Enviar notificación push
  Future<void> _sendPushNotification(String userId, String message, String senderName) async {
    try {
      // Aquí integrarías con tu servicio de notificaciones push
      // Por ejemplo, FCM o OneSignal
      AppLogger.info('Enviando notificación push a $userId: $message');
    } catch (e) {
      AppLogger.error('Error enviando notificación push', e);
    }
  }

  // Limpiar chat
  void clearChat() {
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
    _typingSubscription?.cancel();
    _typingSubscription = null;
    _conversationsSubscription?.cancel();
    _conversationsSubscription = null;
    _messages.clear();
    _activeConversation = null;
    _isTyping = false;
    _typingUserId = null;
    notifyListeners();
  }

  // Helpers
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    if (error != null) {
      AppLogger.error(error, null);
    }
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    clearChat();
    super.dispose();
  }
}