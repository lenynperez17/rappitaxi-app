import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'firebase_service.dart';
import 'notification_service.dart';
import 'rapi_api_client.dart';
import 'rapi_sse_client.dart';

/// Servicio de chat.
///
/// Antes usaba Firestore (`chats/{rideId}/messages`) + Firebase Storage.
/// Tras la migración al backend Node:
///   - HTTP: RapiApiClient.listRideMessages / sendRideMessage / markMessagesRead
///   - Realtime: RapiSseClient.newMessages
///   - Storage: RapiApiClient.uploadFile
///
/// La API pública (initialize, sendTextMessage, sendMessage, sendMultimediaMessage,
/// markMessagesAsRead, getUnreadCount, getChatMessages, shareLocation, clearChat,
/// getUserPresence, ChatMessage, MessageType, QuickMessageType, MediaUploadResult,
/// UserPresence, ChatMetadata) se preserva para no romper pantallas existentes.
class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final FirebaseService _firebaseService = FirebaseService();
  final NotificationService _notificationService = NotificationService();

  bool _initialized = false;
  String? _currentUserId;
  String? _currentUserRole;

  // Cache local de mensajes por rideId — se hidrata con HTTP + SSE
  final Map<String, List<ChatMessage>> _messagesByRide = {};

  // Broadcast controllers por rideId. Se crea uno al pedir getChatMessages(rideId).
  final Map<String, StreamController<List<ChatMessage>>> _chatControllers = {};

  // Suscripciones al stream SSE global. Una por chat activo.
  final Map<String, StreamSubscription<Map<String, dynamic>>> _sseSubscriptions =
      {};

  /// Inicializa el servicio de chat.
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

      // Asegurar que el stream SSE está corriendo
      RapiSseClient.instance.start();

      _initialized = true;
      debugPrint('ChatService inicializado para usuario $userId');

      await _firebaseService.analytics.logEvent(
        name: 'chat_service_initialized',
        parameters: {
          'user_id': userId,
          'user_role': userRole,
        },
      );
    } catch (e) {
      debugPrint('ChatService: error inicializando - $e');
      await _firebaseService.crashlytics.recordError(e, null);
      _initialized = true; // Evitar bucles
    }
  }

  /// Envía un mensaje de texto vía backend Node.
  Future<bool> sendTextMessage({
    required String rideId,
    required String senderId,
    required String senderName,
    required String message,
    required String senderRole,
  }) async {
    try {
      final res = await RapiApiClient.instance.sendRideMessage(
        rideId,
        body: message,
      );

      final msg = _messageFromJson(rideId, res, fallbackSenderName: senderName);
      if (msg != null) {
        _appendMessage(rideId, msg);
      }

      debugPrint('ChatService: mensaje enviado en viaje $rideId');
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
      debugPrint('ChatService: error enviando mensaje - $e');
      await _firebaseService.crashlytics.recordError(e, null);
      return false;
    }
  }

  /// Envía un mensaje multimedia. Primero sube el archivo al backend, luego
  /// envía un mensaje cuyo `text` referencia la URL retornada.
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
      final uploadResult = await _uploadMediaFile(rideId, mediaFile, messageType);
      if (!uploadResult.success) return false;

      // El backend acepta `body` (texto) + `attachmentUrl` para adjuntos.
      // El campo `mediaUrl` local se completa con la URL retornada del upload.
      final res = await RapiApiClient.instance.sendRideMessage(
        rideId,
        body: caption ?? '',
        attachmentUrl: uploadResult.downloadUrl,
      );

      final msg = _messageFromJson(rideId, res, fallbackSenderName: senderName);
      if (msg != null) {
        final enriched = ChatMessage(
          id: msg.id,
          rideId: msg.rideId,
          senderId: msg.senderId,
          senderName: msg.senderName,
          message: msg.message,
          messageType: messageType,
          mediaUrl: uploadResult.downloadUrl,
          mediaFileName: uploadResult.fileName,
          senderRole: msg.senderRole,
          timestamp: msg.timestamp,
          isRead: msg.isRead,
          readAt: msg.readAt,
        );
        _appendMessage(rideId, enriched);
      }

      debugPrint('ChatService: mensaje multimedia enviado en viaje $rideId');
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
      debugPrint('ChatService: error enviando mensaje multimedia - $e');
      await _firebaseService.crashlytics.recordError(e, null);
      return false;
    }
  }

  /// Alias legado.
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

  /// Marca todos los mensajes del viaje como leídos (delegado al backend).
  Future<void> markMessagesAsRead(String rideId, String userId) async {
    try {
      await RapiApiClient.instance.markMessagesRead(rideId);
      // Actualizar cache local — marcar como leídos todos los mensajes ajenos
      final list = _messagesByRide[rideId];
      if (list != null) {
        var changed = false;
        for (final m in list) {
          if (m.senderId != userId && !m.isRead) {
            m.isRead = true;
            changed = true;
          }
        }
        if (changed) _emit(rideId);
      }
      debugPrint('ChatService: mensajes marcados como leídos en $rideId');
      await _firebaseService.analytics.logEvent(
        name: 'chat_messages_marked_read',
        parameters: {'ride_id': rideId, 'user_id': userId},
      );
    } catch (e) {
      debugPrint('ChatService: error marcando mensajes como leídos - $e');
      await _firebaseService.crashlytics.recordError(e, null);
    }
  }

  /// Cuenta cuántos mensajes hay no leídos que no envió `userId`.
  Future<int> getUnreadCount(String rideId, String userId) async {
    try {
      final res = await RapiApiClient.instance.listRideMessages(rideId);
      final raw = (res['messages'] as List?) ?? (res['data'] as List?) ?? const [];
      var count = 0;
      for (final item in raw) {
        if (item is Map) {
          final m = item.cast<String, dynamic>();
          final senderId = m['senderId']?.toString();
          final isRead = m['isRead'] as bool? ?? false;
          if (!isRead && senderId != userId) count++;
        }
      }
      return count;
    } catch (e) {
      debugPrint('ChatService: error obteniendo conteo no leídos - $e');
      return 0;
    }
  }

  /// Stream de mensajes del viaje en tiempo real.
  ///
  /// Al primer llamado por rideId:
  /// 1. Hidrata mensajes con HTTP (`listRideMessages`)
  /// 2. Se suscribe a RapiSseClient.newMessages filtrando por rideId
  Stream<List<ChatMessage>> getChatMessages(String rideId) {
    var controller = _chatControllers[rideId];
    if (controller != null && !controller.isClosed) {
      // Ya existe stream activo — re-emitir cache actual
      if (_messagesByRide[rideId] != null) {
        // No hace falta hacer nada extra; el listener recibirá el estado
        // actual la próxima vez que emitamos.
      }
      return controller.stream;
    }

    controller = StreamController<List<ChatMessage>>.broadcast(
      onCancel: () {
        // No cerramos el controller aquí porque puede haber múltiples oyentes
      },
    );
    _chatControllers[rideId] = controller;

    // Hidratar con HTTP
    _hydrateFromHttp(rideId);

    // Suscribirse a SSE
    RapiSseClient.instance.start();
    _sseSubscriptions[rideId] =
        RapiSseClient.instance.newMessages.listen((event) {
      final eventRideId = event['rideId']?.toString();
      if (eventRideId != null && eventRideId != rideId) return;
      final msg = _messageFromJson(rideId, event);
      if (msg != null) _appendMessage(rideId, msg);
    });

    return controller.stream;
  }

  Future<void> _hydrateFromHttp(String rideId) async {
    try {
      final res = await RapiApiClient.instance.listRideMessages(rideId);
      final raw = (res['messages'] as List?) ?? (res['data'] as List?) ?? const [];
      final list = <ChatMessage>[];
      for (final item in raw) {
        if (item is Map) {
          final msg = _messageFromJson(rideId, item.cast<String, dynamic>());
          if (msg != null) list.add(msg);
        }
      }
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      _messagesByRide[rideId] = list;
      _emit(rideId);
    } catch (e) {
      debugPrint('ChatService: error hidratando mensajes - $e');
    }
  }

  void _appendMessage(String rideId, ChatMessage msg) {
    final list = _messagesByRide.putIfAbsent(rideId, () => <ChatMessage>[]);
    // Evitar duplicados por id
    final idx = list.indexWhere((m) => m.id == msg.id);
    if (idx >= 0) {
      list[idx] = msg;
    } else {
      list.add(msg);
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }
    _emit(rideId);
  }

  void _emit(String rideId) {
    final ctl = _chatControllers[rideId];
    if (ctl == null || ctl.isClosed) return;
    ctl.add(List<ChatMessage>.unmodifiable(_messagesByRide[rideId] ?? const []));
  }

  /// Envía un mensaje rápido (predefinido).
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

  /// Comparte una ubicación como mensaje de texto (con URL de Google Maps).
  Future<bool> shareLocation({
    required String rideId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final locationUrl = 'https://maps.google.com/?q=$latitude,$longitude';
      final res = await RapiApiClient.instance.sendRideMessage(
        rideId,
        body: '📍 Ubicación compartida: $locationUrl',
      );

      final msg = _messageFromJson(rideId, res, fallbackSenderName: senderName);
      if (msg != null) {
        final enriched = ChatMessage(
          id: msg.id,
          rideId: rideId,
          senderId: senderId,
          senderName: senderName,
          message: '📍 Ubicación compartida',
          messageType: MessageType.location,
          mediaUrl: locationUrl,
          senderRole: senderRole,
          timestamp: msg.timestamp,
          isRead: false,
        );
        _appendMessage(rideId, enriched);
      }
      return true;
    } catch (e) {
      debugPrint('Error sharing location: $e');
      return false;
    }
  }

  /// Limpia el chat local del viaje (no hay endpoint para borrar en el backend).
  Future<void> clearChat(String rideId) async {
    try {
      _messagesByRide.remove(rideId);
      await _sseSubscriptions[rideId]?.cancel();
      _sseSubscriptions.remove(rideId);
      final ctl = _chatControllers.remove(rideId);
      await ctl?.close();
      debugPrint('ChatService: chat cache limpiado para $rideId');
    } catch (e) {
      debugPrint('ChatService: error limpiando chat - $e');
    }
  }

  /// Estado de presencia del usuario.
  ///
  /// El backend Node no expone presencia por WebSocket todavía; devolvemos un
  /// stream que emite una única vez el estado "online" cuando la sesión existe.
  Stream<UserPresence> getUserPresence(String userId) async* {
    yield UserPresence(
      online: RapiApiClient.instance.isSignedIn,
      lastSeen: DateTime.now(),
      role: null,
    );
  }

  /// Sube un archivo multimedia al backend Node.
  Future<MediaUploadResult> _uploadMediaFile(
      String rideId, File file, MessageType messageType) async {
    try {
      final result = await RapiApiClient.instance.uploadFile(
        file: file,
        scope: 'chat/$rideId',
      );
      final url = result['url'] as String?;
      final key = result['key'] as String?;
      if (url == null || url.isEmpty) {
        return MediaUploadResult.error('El backend no devolvió URL');
      }
      return MediaUploadResult.success(
        downloadUrl: url,
        fileName: key ?? file.path.split(Platform.pathSeparator).last,
      );
    } catch (e) {
      debugPrint('ChatService: error subiendo archivo - $e');
      return MediaUploadResult.error('Error subiendo archivo: $e');
    }
  }

  /// Parsea un mensaje JSON del backend Node al modelo local.
  ChatMessage? _messageFromJson(
    String rideId,
    Map<String, dynamic> raw, {
    String? fallbackSenderName,
  }) {
    try {
      // El backend puede devolver el mensaje envuelto en {message: {...}} o suelto
      final map = (raw['message'] as Map?)?.cast<String, dynamic>() ?? raw;

      final id = (map['id'] ?? map['messageId'] ?? '').toString();
      if (id.isEmpty) return null;

      final ts = _parseDate(map['timestamp'] ?? map['createdAt']) ??
          DateTime.now();
      final readAt = _parseDate(map['readAt']);

      final typeStr = (map['messageType'] ?? map['type'] ?? 'text').toString();
      final messageType = MessageType.values.firstWhere(
        (t) =>
            t.toString() == typeStr ||
            t.name == typeStr ||
            t.toString().endsWith('.$typeStr'),
        orElse: () => MessageType.text,
      );

      return ChatMessage(
        id: id,
        rideId: (map['rideId'] ?? rideId).toString(),
        senderId: (map['senderId'] ?? '').toString(),
        senderName:
            (map['senderName'] ?? fallbackSenderName ?? '').toString(),
        message: (map['text'] ?? map['message'] ?? '').toString(),
        messageType: messageType,
        mediaUrl: map['mediaUrl']?.toString(),
        mediaFileName: map['mediaFileName']?.toString(),
        senderRole: (map['senderRole'] ?? '').toString(),
        timestamp: ts,
        isRead: map['isRead'] as bool? ?? false,
        readAt: readAt,
      );
    } catch (e) {
      debugPrint('ChatService: error parseando mensaje - $e');
      return null;
    }
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  Future<void> dispose() async {
    for (final sub in _sseSubscriptions.values) {
      await sub.cancel();
    }
    _sseSubscriptions.clear();
    for (final ctl in _chatControllers.values) {
      await ctl.close();
    }
    _chatControllers.clear();
    _messagesByRide.clear();
  }

  bool get isInitialized => _initialized;
  String? get currentUserId => _currentUserId;
  String? get currentUserRole => _currentUserRole;
}

/// Modelo de mensaje de chat.
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

class MediaUploadResult {
  final bool success;
  final String? downloadUrl;
  final String? fileName;
  final String? error;

  MediaUploadResult.success({
    required this.downloadUrl,
    required this.fileName,
  })  : success = true,
        error = null;

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
