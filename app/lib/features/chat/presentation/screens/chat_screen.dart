import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../../shared/providers/riverpod_compat.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/chat_message_model.dart';
import '../../../../shared/models/ride_model.dart';
import '../../../../shared/providers/user_provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_message_widget.dart';
import '../widgets/chat_input_widget.dart';
import '../widgets/chat_location_widget.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final RideModel ride;

  const ChatScreen({
    super.key,
    required this.ride,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    
    // Marcar mensajes como leídos al abrir el chat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatActions = ref.read(chatActionsProvider(widget.ride.id));
      chatActions.markMessagesAsRead();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.ride.id));
    final currentUser = ref.watch(currentUserProvider);
    final otherUser = _getOtherUser(currentUser);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey[200],
              backgroundImage: otherUser?.photoUrl != null
                  ? NetworkImage(otherUser!.photoUrl!)
                  : null,
              child: otherUser?.photoUrl == null
                  ? Icon(
                      Icons.person,
                      color: Colors.grey[400],
                      size: 18,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    otherUser?.name ?? 'Usuario',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    currentUser?.role == 'driver' ? 'Pasajero' : 'Conductor',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () => _showCallDialog(),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'location':
                  _sendCurrentLocation();
                  break;
                case 'image':
                  _pickAndSendImage();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'location',
                child: Row(
                  children: [
                    Icon(Icons.my_location, size: 18),
                    SizedBox(width: 8),
                    Text('Enviar ubicación'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'image',
                child: Row(
                  children: [
                    Icon(Icons.photo_camera, size: 18),
                    SizedBox(width: 8),
                    Text('Enviar imagen'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Información del viaje
          _buildTripInfoHeader(),
          
          // Lista de mensajes
          Expanded(
            child: messagesAsync.when(
              data: (messages) => _buildMessagesList(messages),
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error al cargar mensajes',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => ref.refresh(chatMessagesProvider(widget.ride.id)),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Input de mensaje
          ChatInputWidget(
            controller: _messageController,
            onSendMessage: _sendMessage,
            onSendImage: _pickAndSendImage,
            onSendLocation: _sendCurrentLocation,
          ),
        ],
      ),
    );
  }

  Widget _buildTripInfoHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.directions_car,
            color: AppTheme.primaryColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Viaje en curso',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'S/ ${widget.ride.fare?.toStringAsFixed(2) ?? '0.00'}',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(List<ChatMessageModel> messages) {
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No hay mensajes aún',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Inicia la conversación enviando un mensaje',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    // Auto-scroll al final cuando lleguen nuevos mensajes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isFromCurrentUser = _isFromCurrentUser(message);
        final showDateSeparator = _shouldShowDateSeparator(messages, index);

        return Column(
          children: [
            if (showDateSeparator) _buildDateSeparator(message.timestamp),
            ChatMessageWidget(
              message: message,
              isFromCurrentUser: isFromCurrentUser,
              onLocationTap: message.messageType == 'location'
                  ? () => _showLocationDialog(
                        message.latitude!,
                        message.longitude!,
                      )
                  : null,
            ).animate(delay: Duration(milliseconds: index * 50))
                .fadeIn(duration: 300.ms)
                .slideX(begin: isFromCurrentUser ? 0.3 : -0.3),
          ],
        );
      },
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);
    
    String dateText;
    if (messageDate == today) {
      dateText = 'Hoy';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      dateText = 'Ayer';
    } else {
      dateText = '${date.day}/${date.month}/${date.year}';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey[300])),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              dateText,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey[300])),
        ],
      ),
    );
  }

  bool _shouldShowDateSeparator(List<ChatMessageModel> messages, int index) {
    if (index == 0) return true;
    
    final currentMessage = messages[index];
    final previousMessage = messages[index - 1];
    
    final currentDate = DateTime(
      currentMessage.timestamp.year,
      currentMessage.timestamp.month,
      currentMessage.timestamp.day,
    );
    
    final previousDate = DateTime(
      previousMessage.timestamp.year,
      previousMessage.timestamp.month,
      previousMessage.timestamp.day,
    );
    
    return currentDate != previousDate;
  }

  bool _isFromCurrentUser(ChatMessageModel message) {
    final currentUser = ref.read(currentUserProvider);
    return currentUser?.id == message.senderId;
  }

  dynamic _getOtherUser(dynamic currentUser) {
    if (currentUser?.role == 'driver') {
      // Si el usuario actual es conductor, mostrar info del pasajero
      // Por ahora retornar null ya que no tenemos passengerInfo en RideModel
      return null;
    } else {
      // Si el usuario actual es pasajero, mostrar info del conductor
      return widget.ride.driverInfo;
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final chatActions = ref.read(chatActionsProvider(widget.ride.id));
    await chatActions.sendMessage(_messageController.text);
    _messageController.clear();
  }

  Future<void> _pickAndSendImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        final chatActions = ref.read(chatActionsProvider(widget.ride.id));
        await chatActions.sendImage(image.path);
      }
    } catch (e) {
      _showErrorSnackBar('Error al enviar imagen');
    }
  }

  Future<void> _sendCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final chatActions = ref.read(chatActionsProvider(widget.ride.id));
      await chatActions.sendLocation(
        position.latitude,
        position.longitude,
      );
    } catch (e) {
      _showErrorSnackBar('Error al obtener ubicación');
    }
  }

  void _showLocationDialog(double latitude, double longitude) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ChatLocationWidget(
          latitude: latitude,
          longitude: longitude,
        ),
      ),
    );
  }

  void _showCallDialog() {
    final otherUser = _getOtherUser(ref.read(currentUserProvider));
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Llamar a ${otherUser?.name ?? 'Usuario'}'),
        content: Text(
          '¿Deseas llamar a ${otherUser?.phone ?? 'este número'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implementar llamada real
              _showErrorSnackBar('Función de llamada próximamente...');
            },
            child: const Text('Llamar'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
      ),
    );
  }
}