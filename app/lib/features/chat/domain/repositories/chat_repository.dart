import '../../../../shared/models/chat_message_model.dart';

abstract class ChatRepository {
  // Obtener mensajes de un viaje
  Stream<List<ChatMessageModel>> getMessagesForRide(String rideId);
  
  // Enviar mensaje de texto
  Future<void> sendMessage({
    required String rideId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String message,
  });
  
  // Enviar imagen
  Future<void> sendImage({
    required String rideId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String imagePath,
  });
  
  // Enviar ubicación
  Future<void> sendLocation({
    required String rideId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required double latitude,
    required double longitude,
  });
  
  // Marcar mensajes como leídos
  Future<void> markMessagesAsRead(String rideId, String userId);
  
  // Obtener número de mensajes no leídos
  Stream<int> getUnreadMessagesCount(String rideId, String userId);
}