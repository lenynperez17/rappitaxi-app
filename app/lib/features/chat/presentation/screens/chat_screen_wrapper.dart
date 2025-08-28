import 'package:flutter/material.dart';

// Wrapper simplificado para ChatScreen que maneja los parámetros del router
class ChatScreenWrapper extends StatelessWidget {
  final String rideId;
  final String otherUserId;
  final String otherUserName;
  
  const ChatScreenWrapper({
    super.key,
    required this.rideId,
    this.otherUserId = '',
    this.otherUserName = '',
  });
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat con $otherUserName'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'Chat para viaje #$rideId',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Función de chat en desarrollo',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

// Alias para compatibilidad
class ChatScreen extends ChatScreenWrapper {
  const ChatScreen({
    super.key,
    required super.rideId,
    super.otherUserId = '',
    super.otherUserName = '',
  });
}