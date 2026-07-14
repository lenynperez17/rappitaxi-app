import 'dart:async';
import 'package:flutter/material.dart';
import '../services/rapi_api_client.dart';
import '../services/rapi_sse_client.dart';
import '../utils/logger.dart';

// ---------------------------------------------------------------------------
// Helpers de parseo (reemplazan Firebase Timestamp → ISO 8601 string)
// ---------------------------------------------------------------------------

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  if (v is int) {
    // Puede venir en segundos o milisegundos
    return v > 1000000000000
        ? DateTime.fromMillisecondsSinceEpoch(v)
        : DateTime.fromMillisecondsSinceEpoch(v * 1000);
  }
  return null;
}

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
      senderId: (map['senderId'] ?? map['sender_id'] ?? '').toString(),
      senderName: (map['senderName'] ?? map['sender_name'] ?? '').toString(),
      senderRole:
          (map['senderRole'] ?? map['sender_role'] ?? 'passenger').toString(),
      receiverId: (map['receiverId'] ?? map['receiver_id'] ?? '').toString(),
      tripId: (map['tripId'] ?? map['rideId'] ?? map['ride_id'] ?? '')
          .toString(),
      message: (map['message'] ?? map['body'] ?? '').toString(),
      imageUrl: (map['imageUrl'] ??
              map['attachmentUrl'] ??
              map['attachment_url']) as String?,
      type: MessageType.values.firstWhere(
        (e) => e.toString() == 'MessageType.${map['type']}',
        orElse: () => MessageType.text,
      ),
      status: MessageStatus.values.firstWhere(
        (e) => e.toString() == 'MessageStatus.${map['status']}',
        orElse: () => MessageStatus.sent,
      ),
      timestamp: _parseDate(map['timestamp'] ??
              map['createdAt'] ??
              map['created_at']) ??
          DateTime.now(),
      metadata: map['metadata'] as Map<String, dynamic>?,
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
      'timestamp': timestamp.toIso8601String(),
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
        participantsMap[key] =
            ParticipantInfo.fromMap(value as Map<String, dynamic>);
      });
    }

    return ChatConversation(
      id: id,
      tripId: (map['tripId'] ?? map['rideId'] ?? map['ride_id'] ?? '')
          .toString(),
      participantIds: List<String>.from(map['participantIds'] ?? const []),
      participants: participantsMap,
      lastMessage: map['lastMessage'] as String?,
      lastMessageTime: _parseDate(map['lastMessageTime']),
      unreadCount: (map['unreadCount'] as num?)?.toInt() ?? 0,
      isActive: map['isActive'] as bool? ?? true,
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
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
      name: (map['name'] ?? '').toString(),
      role: (map['role'] ?? '').toString(),
      photoUrl: map['photoUrl'] as String?,
      isOnline: map['isOnline'] as bool? ?? false,
      lastSeen: _parseDate(map['lastSeen']),
    );
  }
}

class ChatProvider extends ChangeNotifier {
  final RapiApiClient _api = RapiApiClient.instance;
  final RapiSseClient _sse = RapiSseClient.instance;

  // Estado
  List<ChatMessage> _messages = [];
  final List<ChatConversation> _conversations = [];
  ChatConversation? _activeConversation;
  bool _isLoading = false;
  String? _error;
  bool _isTyping = false;
  String? _typingUserId;
  bool _isSendingMessage = false;

  // Datos del usuario autenticado (cacheados al inicializar el chat)
  String? _currentUserId;
  String? _currentUserName;
  String? _currentUserRole;

  // Subscriptions al stream SSE — cancelar en dispose
  StreamSubscription<Map<String, dynamic>>? _messagesSubscription;

  // Getters (interfaz publica identica a la version Firebase)
  List<ChatMessage> get messages => _messages;
  List<ChatConversation> get conversations => _conversations;
  ChatConversation? get activeConversation => _activeConversation;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isTyping => _isTyping;
  String? get typingUserId => _typingUserId;
  bool get isSendingMessage => _isSendingMessage;

  // ---------------------------------------------------------------------------
  // Inicializar chat para un viaje
  // ---------------------------------------------------------------------------

  Future<void> initializeChatForTrip(
    String tripId,
    String otherUserId,
    String otherUserName,
    String otherUserRole,
  ) async {
    _setLoading(true);
    try {
      // Obtener info del usuario autenticado desde el backend
      final me = await _api.me();
      if (me == null) throw Exception('Usuario no autenticado');

      _currentUserId = (me['id'] ?? me['uid'] ?? me['userId'] ?? '').toString();
      _currentUserName =
          (me['name'] ?? me['fullName'] ?? me['displayName'] ?? 'Usuario')
              .toString();
      _currentUserRole = (me['role'] ?? 'passenger').toString();

      if (_currentUserId!.isEmpty) {
        throw Exception('No se pudo determinar el ID del usuario');
      }

      // Construir la conversacion en memoria. En el backend, chat esta
      // enlazado a rides — no existe una colección conversations separada.
      // Se usa el rideId como identificador de la conversación.
      _activeConversation = ChatConversation(
        id: tripId,
        tripId: tripId,
        participantIds: [_currentUserId!, otherUserId],
        participants: {
          _currentUserId!: ParticipantInfo(
            name: _currentUserName!,
            role: _currentUserRole!,
            photoUrl: me['photoUrl'] as String?,
            isOnline: true,
            lastSeen: DateTime.now(),
          ),
          otherUserId: ParticipantInfo(
            name: otherUserName,
            role: otherUserRole,
            isOnline: false,
          ),
        },
        unreadCount: 0,
        isActive: true,
        createdAt: DateTime.now(),
      );

      // Estado inicial: cargar mensajes desde el endpoint HTTP
      await _loadInitialMessages(tripId);

      // Configurar suscripcion SSE para mensajes nuevos
      _setupMessageStream(tripId);

      // Marcar mensajes como leidos
      await markMessagesAsRead(tripId);

      _setLoading(false);
    } catch (e) {
      _setError('Error al inicializar chat: $e');
      _setLoading(false);
    }
  }

  // Carga inicial de mensajes via HTTP
  Future<void> _loadInitialMessages(String tripId) async {
    try {
      final resp = await _api.listRideMessages(tripId);
      final raw = resp['messages'] ?? resp['data'] ?? resp['items'] ?? const [];
      final List list = raw is List ? raw : const [];
      _messages = list
          .whereType<Map<String, dynamic>>()
          .map((m) => ChatMessage.fromMap(
                m,
                (m['id'] ?? m['messageId'] ?? '').toString(),
              ))
          .toList()
        // El API generalmente ordena ASC; la UI antigua esperaba DESC
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      notifyListeners();
    } catch (e) {
      AppLogger.error('Error cargando mensajes iniciales', e);
    }
  }

  // Configurar stream de mensajes (SSE)
  void _setupMessageStream(String tripId) {
    _messagesSubscription?.cancel();
    _messagesSubscription = _sse.newMessages.listen((event) {
      // Filtrar por rideId — el stream es global
      final eventRideId =
          (event['rideId'] ?? event['tripId'] ?? event['ride_id'] ?? '')
              .toString();
      if (eventRideId != tripId) return;

      // El evento puede traer el mensaje anidado en 'message' o inline
      final Map<String, dynamic> raw = (event['message'] is Map)
          ? Map<String, dynamic>.from(event['message'] as Map)
          : event;

      final msgId = (raw['id'] ?? raw['messageId'] ?? '').toString();
      if (msgId.isEmpty) return;

      // Evitar duplicados si el mensaje ya esta en la lista (p. ej. si fue
      // agregado optimisticamente al enviar)
      final existingIndex = _messages.indexWhere((m) => m.id == msgId);
      final message = ChatMessage.fromMap(raw, msgId);
      if (existingIndex >= 0) {
        _messages[existingIndex] = message;
      } else {
        // Insertar al inicio (lista ordenada DESC por timestamp)
        _messages.insert(0, message);
      }
      notifyListeners();
    }, onError: (Object e) {
      AppLogger.error('Error en stream de mensajes SSE', e);
    });
  }

  // ---------------------------------------------------------------------------
  // Enviar mensaje
  // ---------------------------------------------------------------------------

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

    _isSendingMessage = true;
    notifyListeners();

    try {
      final rideId = _activeConversation!.tripId;

      // Enviar al backend. El endpoint acepta body y attachmentUrl.
      final resp = await _api.sendRideMessage(
        rideId,
        body: message,
        attachmentUrl: imageUrl,
      );

      // Insertar el mensaje devuelto localmente (el SSE tambien lo emitira,
      // pero el dedupe por id evita duplicados)
      final Map<String, dynamic> raw =
          (resp['message'] is Map) ? Map<String, dynamic>.from(resp['message'] as Map) : resp;
      final msgId = (raw['id'] ?? raw['messageId'] ?? '').toString();
      if (msgId.isNotEmpty) {
        final chatMessage = ChatMessage.fromMap(raw, msgId);
        final idx = _messages.indexWhere((m) => m.id == msgId);
        if (idx >= 0) {
          _messages[idx] = chatMessage;
        } else {
          _messages.insert(0, chatMessage);
        }
      }

      _isSendingMessage = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSendingMessage = false;
      _setError('Error al enviar mensaje: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Marcar mensajes como leidos
  // ---------------------------------------------------------------------------

  Future<void> markMessagesAsRead(String conversationId) async {
    try {
      // conversationId == rideId (equivalencia en el nuevo modelo)
      final rideId = _activeConversation?.tripId ?? conversationId;
      await _api.markMessagesRead(rideId);

      // Actualizar estado local: marcar mensajes recibidos como read
      final myId = _currentUserId;
      if (myId != null) {
        _messages = _messages.map((m) {
          if (m.receiverId == myId && m.status != MessageStatus.read) {
            return ChatMessage(
              id: m.id,
              senderId: m.senderId,
              senderName: m.senderName,
              senderRole: m.senderRole,
              receiverId: m.receiverId,
              tripId: m.tripId,
              message: m.message,
              imageUrl: m.imageUrl,
              type: m.type,
              status: MessageStatus.read,
              timestamp: m.timestamp,
              metadata: m.metadata,
            );
          }
          return m;
        }).toList();
        notifyListeners();
      }
    } catch (e) {
      AppLogger.error('Error marcando mensajes como leídos', e);
    }
  }

  // ---------------------------------------------------------------------------
  // Actualizar estado de escritura
  // ---------------------------------------------------------------------------

  Future<void> updateTypingStatus(bool isTyping) async {
    if (_activeConversation == null) return;
    // El backend actual no expone un endpoint de "typing indicator".
    // Se mantiene la firma publica para no romper llamadas existentes.
    // Cuando el backend lo soporte, aqui se enviara al server.
    _isTyping = isTyping;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Cargar conversaciones del usuario
  // ---------------------------------------------------------------------------

  Future<void> loadUserConversations() async {
    _setLoading(true);
    try {
      // El backend no tiene una coleccion "conversations" — el chat esta
      // enlazado a rides. Se derivan las conversaciones de los rides recientes.
      final resp = await _api.listRides(pageSize: 50);
      final raw = resp['rides'] ?? resp['data'] ?? resp['items'] ?? const [];
      final List list = raw is List ? raw : const [];

      _conversations.clear();
      for (final item in list.whereType<Map<String, dynamic>>()) {
        final rideId = (item['id'] ?? item['rideId'] ?? '').toString();
        if (rideId.isEmpty) continue;
        final participants = <String>[];
        final passengerId =
            (item['passengerId'] ?? item['passenger_id'] ?? '').toString();
        final driverId =
            (item['driverId'] ?? item['driver_id'] ?? '').toString();
        if (passengerId.isNotEmpty) participants.add(passengerId);
        if (driverId.isNotEmpty) participants.add(driverId);

        _conversations.add(ChatConversation(
          id: rideId,
          tripId: rideId,
          participantIds: participants,
          participants: const {},
          lastMessage: item['lastMessage'] as String?,
          lastMessageTime: _parseDate(item['lastMessageTime'] ??
              item['updatedAt'] ??
              item['updated_at']),
          unreadCount: (item['unreadCount'] as num?)?.toInt() ?? 0,
          isActive:
              (item['status'] as String? ?? '').toLowerCase() != 'completed' &&
                  (item['status'] as String? ?? '').toLowerCase() != 'cancelled',
          createdAt: _parseDate(item['createdAt'] ?? item['created_at']) ??
              DateTime.now(),
        ));
      }

      notifyListeners();
      _setLoading(false);
    } catch (e) {
      _setError('Error al cargar conversaciones: $e');
      _setLoading(false);
    }
  }

  // ---------------------------------------------------------------------------
  // Enviar mensaje predefinido
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Enviar ubicacion
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Finalizar conversacion
  // ---------------------------------------------------------------------------

  Future<void> endConversation() async {
    if (_activeConversation == null) return;

    try {
      // Enviar mensaje del sistema al backend (opcional, best-effort)
      await sendMessage(
        message: 'La conversación ha finalizado',
        type: MessageType.system,
      );
    } catch (e) {
      AppLogger.error('Error al finalizar conversación', e);
    } finally {
      // Limpiar suscripcion y estado local
      await _messagesSubscription?.cancel();
      _messagesSubscription = null;
      _activeConversation = null;
      _messages.clear();
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Limpiar chat
  // ---------------------------------------------------------------------------

  void clearChat() {
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
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
