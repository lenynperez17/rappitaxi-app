import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/design/design_system.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_animated_widgets.dart';

class CommunicationScreen extends StatefulWidget {
  final Map<String, dynamic>? tripData;

  const CommunicationScreen({super.key, this.tripData});

  @override
  State<CommunicationScreen> createState() => _CommunicationScreenState();
}

class _CommunicationScreenState extends State<CommunicationScreen>
    with TickerProviderStateMixin {
  // Controladores
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Controladores de animacion
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  // Estado de comunicación
  bool _isTyping = false;
  int _callDuration = 0;
  Timer? _callTimer;
  Timer? _typingTimer;

  // Flag para prevenir operaciones después de dispose
  bool _isDisposed = false;

  // Mensajes
  final List<ChatMessage> _messages = [];

  // Respuestas rápidas
  final List<String> _quickResponses = [
    'Ya llegue, estoy esperando',
    'Voy en camino',
    'Llegare en 5 minutos',
    'Hay mucho trafico',
    'No encuentro la dirección',
    'Puedes salir?',
    'Estoy en la puerta principal',
    'Necesito cancelar el viaje',
  ];

  // Info del pasajero - Se llenara con datos reales
  final Map<String, dynamic> _passengerInfo = {
    'name': 'Pasajero',
    'photo': '',
    'rating': 5.0,
    'trips': 0,
    'phone': '',
    'pickup': '',
    'destination': '',
  };

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _fadeController.forward();
    _initializeChat();
  }

  @override
  void dispose() {
    _isDisposed = true;

    _messageController.dispose();
    _scrollController.dispose();
    _fadeController.dispose();
    _pulseController.dispose();
    _callTimer?.cancel();
    _callTimer = null;
    _typingTimer?.cancel();
    _typingTimer = null;
    super.dispose();
  }

  void _initializeChat() {
    _messages.add(
      ChatMessage(
        id: '1',
        text: 'Hola, soy tu conductor. Ya estoy en camino a recogerte.',
        isDriver: true,
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        status: MessageStatus.read,
      ),
    );

    _messages.add(
      ChatMessage(
        id: '2',
        text: 'Perfecto! Estare esperando en la puerta principal',
        isDriver: false,
        timestamp: DateTime.now().subtract(const Duration(minutes: 4)),
        status: MessageStatus.read,
      ),
    );

    setState(() {});
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isDriver: true,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    );

    setState(() {
      _messages.add(message);
      _messageController.clear();
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        message.status = MessageStatus.sent;
      });
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        message.status = MessageStatus.read;
      });
      _simulatePassengerResponse();
    });
  }

  void _simulatePassengerResponse() {
    setState(() {
      _isTyping = true;
    });

    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(
            ChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              text: _getRandomResponse(),
              isDriver: false,
              timestamp: DateTime.now(),
              status: MessageStatus.read,
            ),
          );
        });

        Future.delayed(const Duration(milliseconds: 100), () {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
      }
    });
  }

  String _getRandomResponse() {
    final responses = [
      'De acuerdo',
      'Gracias por avisar',
      'Te espero aquí',
      'Ok, entendido',
      'Perfecto',
      'Sin problema',
    ];
    return responses[DateTime.now().millisecond % responses.length];
  }

  void _startCall() {
    setState(() {
      _callDuration = 0;
    });

    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _callDuration++;
      });
    });

    _showCallDialog();
  }

  void _endCall() {
    _callTimer?.cancel();
    Navigator.pop(context);
  }

  void _showCallDialog() {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                RtColors.rapiteamBlack,
                RtColors.rapiteamBlack.withValues(alpha: 0.9),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Llamando a',
                style: TextStyle(
                  color: colorScheme.surface.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _passengerInfo['name'],
                style: TextStyle(
                  color: colorScheme.surface,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                _passengerInfo['phone'],
                style: TextStyle(
                  color: colorScheme.surface.withValues(alpha: 0.7),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),

              // Avatar con animacion de pulso
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: CircleAvatar(
                      radius: 60,
                      backgroundImage: NetworkImage(_passengerInfo['photo']),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Duracion de llamada
              Text(
                _formatCallDuration(_callDuration),
                style: TextStyle(
                  color: colorScheme.surface,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),

              // Acciones de llamada
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCallAction(
                    Icons.volume_up,
                    'Altavoz',
                    colorScheme.surface,
                    () {},
                  ),
                  _buildCallAction(
                    Icons.mic_off,
                    'Silenciar',
                    colorScheme.surface,
                    () {},
                  ),
                  _buildCallAction(
                    Icons.dialpad,
                    'Teclado',
                    colorScheme.surface,
                    () {},
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Boton de colgar
              GestureDetector(
                onTap: _endCall,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: const BoxDecoration(
                    color: RtColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.call_end,
                    color: colorScheme.surface,
                    size: 32,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallAction(IconData icon, String label, Color color, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCallDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: RtAppBar(
        titleWidget: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: NetworkImage(_passengerInfo['photo']),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _passengerInfo['name'],
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 14, color: RtColors.warning),
                      const SizedBox(width: 4),
                      Text(
                        '${_passengerInfo['rating']}',
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_passengerInfo['trips']} viajes',
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        variant: RtAppBarVariant.solid,
        actions: [
          IconButton(
            icon: const Icon(Icons.call, color: RtColors.brand),
            onPressed: _startCall,
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: colorScheme.onSurface.withValues(alpha: 0.6)),
            onPressed: () => _showOptionsMenu(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de info del viaje
          Container(
            padding: const EdgeInsets.all(12),
            color: RtColors.brand.withValues(alpha: 0.1),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: RtColors.brand, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recogida: ${_passengerInfo['pickup']}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        'Destino: ${_passengerInfo['destination']}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Mensajes del chat
          Expanded(
            child: AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isTyping && index == _messages.length) {
                        return _buildTypingIndicator();
                      }
                      return _buildMessage(_messages[index]);
                    },
                  ),
                );
              },
            ),
          ),

          // Respuestas rápidas
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _quickResponses.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(_quickResponses[index]),
                    onPressed: () => _sendMessage(_quickResponses[index]),
                    backgroundColor: RtColors.brand.withValues(alpha: 0.1),
                    labelStyle: const TextStyle(
                      color: RtColors.brand,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Entrada de mensaje
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.onSurface.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Boton de adjuntar
                  IconButton(
                    icon: Icon(Icons.attach_file, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                    onPressed: () => _showAttachmentOptions(),
                  ),

                  // Campo de texto
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Escribe un mensaje...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: _sendMessage,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Boton de enviar
                  Container(
                    decoration: const BoxDecoration(
                      color: RtColors.brand,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.send, color: colorScheme.surface),
                      onPressed: () => _sendMessage(_messageController.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    final isDriver = message.isDriver;
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: isDriver ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: isDriver ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDriver ? RtColors.brand : colorScheme.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isDriver ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight: isDriver ? const Radius.circular(4) : const Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.onSurface.withValues(alpha: 0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: isDriver ? colorScheme.surface : colorScheme.onSurface,
                      fontSize: 14,
                    ),
                  ),
                  if (message.attachment != null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getAttachmentIcon(message.attachment!['type']),
                            color: isDriver ? colorScheme.surface : RtColors.brand,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            message.attachment!['name'],
                            style: TextStyle(
                              color: isDriver ? colorScheme.surface : colorScheme.onSurface,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
                if (isDriver) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.status == MessageStatus.sending
                        ? Icons.access_time
                        : message.status == MessageStatus.sent
                            ? Icons.done
                            : Icons.done_all,
                    size: 14,
                    color: message.status == MessageStatus.read
                        ? RtColors.info
                        : colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colorScheme.onSurface.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ModernLoadingIndicator(
              color: RtColors.brand,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Escribiendo...',
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  IconData _getAttachmentIcon(String type) {
    switch (type) {
      case 'image':
        return Icons.image;
      case 'location':
        return Icons.location_on;
      case 'audio':
        return Icons.mic;
      default:
        return Icons.attach_file;
    }
  }

  void _showAttachmentOptions() {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enviar',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(
                  Icons.image,
                  'Foto',
                  RtColors.info,
                  () {
                    Navigator.pop(context);
                    _sendAttachment('image', 'Foto.jpg');
                  },
                ),
                _buildAttachmentOption(
                  Icons.location_on,
                  'Ubicación',
                  RtColors.brand,
                  () {
                    Navigator.pop(context);
                    _sendAttachment('location', 'Mi ubicación actual');
                  },
                ),
                _buildAttachmentOption(
                  Icons.mic,
                  'Audio',
                  RtColors.warning,
                  () {
                    Navigator.pop(context);
                    _sendAttachment('audio', 'Mensaje de voz');
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _sendAttachment(String type, String name) {
    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: type == 'location' ? 'Comparti mi ubicación' : 'Archivo adjunto',
      isDriver: true,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
      attachment: {
        'type': type,
        'name': name,
      },
    );

    setState(() {
      _messages.add(message);
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        message.status = MessageStatus.sent;
      });
    });
  }

  void _showOptionsMenu() {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Ver perfil del pasajero'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('Ver ubicación en mapa'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.report),
              title: const Text('Reportar problema'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: RtColors.error),
              title: const Text('Bloquear usuario',
                  style: TextStyle(color: RtColors.error)),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Modelo de mensaje de chat
class ChatMessage {
  final String id;
  final String text;
  final bool isDriver;
  final DateTime timestamp;
  MessageStatus status;
  final Map<String, dynamic>? attachment;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isDriver,
    required this.timestamp,
    required this.status,
    this.attachment,
  });
}

enum MessageStatus { sending, sent, read }
