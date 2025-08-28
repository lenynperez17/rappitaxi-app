import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../shared/providers/riverpod_compat.dart';

import '../../../../shared/models/chat_message_model.dart';
import '../../../../shared/providers/user_provider.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/repositories/chat_repository.dart';

// Proveedor del repositorio de chat
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl();
});

// Proveedor de mensajes para un viaje específico
final chatMessagesProvider = StreamProvider.family<List<ChatMessageModel>, String>((ref, rideId) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.getMessagesForRide(rideId);
});

// Proveedor de mensajes no leídos para un viaje específico
final unreadMessagesCountProvider = StreamProvider.family<int, String>((ref, rideId) {
  final repository = ref.watch(chatRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  
  if (user == null) return Stream.value(0);
  
  return repository.getUnreadMessagesCount(rideId, user.id);
});

// Proveedor de acciones de chat
final chatActionsProvider = Provider.family<ChatActions, String>((ref, rideId) {
  final repository = ref.watch(chatRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  
  return ChatActions(
    repository: repository,
    rideId: rideId,
    currentUser: user,
  );
});

class ChatActions {
  final ChatRepository repository;
  final String rideId;
  final dynamic currentUser;

  ChatActions({
    required this.repository,
    required this.rideId,
    required this.currentUser,
  });

  Future<void> sendMessage(String message) async {
    if (currentUser == null || message.trim().isEmpty) return;

    await repository.sendMessage(
      rideId: rideId,
      senderId: currentUser.id,
      senderName: currentUser.name,
      senderRole: currentUser.role,
      message: message.trim(),
    );
  }

  Future<void> sendImage(String imagePath) async {
    if (currentUser == null) return;

    await repository.sendImage(
      rideId: rideId,
      senderId: currentUser.id,
      senderName: currentUser.name,
      senderRole: currentUser.role,
      imagePath: imagePath,
    );
  }

  Future<void> sendLocation(double latitude, double longitude) async {
    if (currentUser == null) return;

    await repository.sendLocation(
      rideId: rideId,
      senderId: currentUser.id,
      senderName: currentUser.name,
      senderRole: currentUser.role,
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<void> markMessagesAsRead() async {
    if (currentUser == null) return;

    await repository.markMessagesAsRead(rideId, currentUser.id);
  }
}