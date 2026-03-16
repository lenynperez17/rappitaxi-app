// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/theme/modern_theme.dart';
import '../../core/extensions/theme_extensions.dart'; // ✅ Extensión para colores que se adaptan al tema
import '../../widgets/animated/modern_animated_widgets.dart';

class CommunicationScreen extends StatefulWidget {
  final Map<String, dynamic>? tripData;
  
  const CommunicationScreen({super.key, this.tripData});
  
  @override
  _CommunicationScreenState createState() => _CommunicationScreenState();
}

class _CommunicationScreenState extends State<CommunicationScreen> 
    with TickerProviderStateMixin {
  // Controllers
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  
  // Communication state
  bool _isTyping = false;
  bool _isCalling = false;
  int _callDuration = 0;
  Timer? _callTimer;
  Timer? _typingTimer;

  // Estado de llamada
  bool _isSpeakerOn = false;
  bool _isMuted = false;

  // ✅ Flag para prevenir operaciones después de dispose
  bool _isDisposed = false;

  // Messages
  final List<ChatMessage> _messages = [];
  
  // Quick responses
  final List<String> _quickResponses = [
    'Ya llegué, estoy esperando',
    'Voy en camino',
    'Llegaré en 5 minutos',
    'Hay mucho tráfico',
    'No encuentro la dirección',
    '¿Puedes salir?',
    'Estoy en la puerta principal',
    'Necesito cancelar el viaje',
  ];
  
  // Passenger info - Se llenará con datos reales
  final Map<String, dynamic> _passengerInfo = {
    'name': 'Pasajero',
    'photo': '', // Se llenará con datos reales
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
      duration: Duration(milliseconds: 500),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
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
    // ✅ Marcar como disposed ANTES de cancelar recursos
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
    // Add initial automated message
    _messages.add(
      ChatMessage(
        id: '1',
        text: 'Hola, soy tu conductor. Ya estoy en camino a recogerte.',
        isDriver: true,
        timestamp: DateTime.now().subtract(Duration(minutes: 5)),
        status: MessageStatus.read,
      ),
    );
    
    _messages.add(
      ChatMessage(
        id: '2',
        text: 'Perfecto! Estaré esperando en la puerta principal',
        isDriver: false,
        timestamp: DateTime.now().subtract(Duration(minutes: 4)),
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
    
    // Scroll to bottom
    Future.delayed(Duration(milliseconds: 100), () {
      if (!mounted) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });

    // Simulate message sent
    Future.delayed(Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        message.status = MessageStatus.sent;
      });
    });

    // Simulate message read
    Future.delayed(Duration(seconds: 2), () {
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
    
    _typingTimer = Timer(Duration(seconds: 2), () {
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
        
        // Scroll to bottom
        Future.delayed(Duration(milliseconds: 100), () {
          if (!mounted) return;
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
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
      _isCalling = true;
      _callDuration = 0;
    });
    
    _callTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      // ✅ TRIPLE VERIFICACIÓN para prevenir setState después de dispose
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
    
    // Show calling dialog
    _showCallDialog();
  }
  
  void _endCall() {
    _callTimer?.cancel();
    setState(() {
      _isCalling = false;
      _isSpeakerOn = false;
      _isMuted = false;
    });
    Navigator.pop(context);
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isSpeakerOn ? 'Altavoz activado' : 'Altavoz desactivado'),
        backgroundColor: ModernTheme.rappiOrange,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isMuted ? 'Micrófono silenciado' : 'Micrófono activado'),
        backgroundColor: _isMuted ? ModernTheme.warning : ModernTheme.rappiOrange,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _showDialpad() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Teclado DTMF',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                for (var digit in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#'])
                  _buildDialpadButton(digit),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDialpadButton(String digit) {
    return InkWell(
      onTap: () {
        // Reproducir tono DTMF (feedback visual por ahora)
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tono: $digit'),
            duration: Duration(milliseconds: 300),
            backgroundColor: ModernTheme.rappiOrange,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: ModernTheme.rappiOrange.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ModernTheme.rappiOrange.withValues(alpha:0.3)),
        ),
        child: Center(
          child: Text(
            digit,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: ModernTheme.rappiOrange,
            ),
          ),
        ),
      ),
    );
  }

  void _showCallDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                ModernTheme.rappiBlack,
                ModernTheme.rappiBlack.withValues(alpha: 0.9),
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
                  color: context.surfaceColor.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 8),
              Text(
                _passengerInfo['name'],
                style: TextStyle(
                  color: context.surfaceColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 8),
              Text(
                _passengerInfo['phone'],
                style: TextStyle(
                  color: context.surfaceColor.withValues(alpha: 0.7),
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 24),
              
              // Avatar with pulse animation
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: CircleAvatar(
                      radius: 60,
                      backgroundImage: (_passengerInfo['photo'] != null && _passengerInfo['photo'].toString().isNotEmpty && _passengerInfo['photo'].toString().startsWith('http'))
                          ? NetworkImage(_passengerInfo['photo'])
                          : null,
                    ),
                  );
                },
              ),
              SizedBox(height: 24),
              
              // Call duration
              Text(
                _formatCallDuration(_callDuration),
                style: TextStyle(
                  color: context.surfaceColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 32),
              
              // Call actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCallAction(
                    _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                    _isSpeakerOn ? 'Altavoz On' : 'Altavoz',
                    _isSpeakerOn ? ModernTheme.rappiOrange : context.surfaceColor,
                    _toggleSpeaker,
                  ),
                  _buildCallAction(
                    _isMuted ? Icons.mic_off : Icons.mic,
                    _isMuted ? 'Silenciado' : 'Silenciar',
                    _isMuted ? ModernTheme.error : context.surfaceColor,
                    _toggleMute,
                  ),
                  _buildCallAction(
                    Icons.dialpad,
                    'Teclado',
                    context.surfaceColor,
                    _showDialpad,
                  ),
                ],
              ),
              SizedBox(height: 24),
              
              // End call button
              GestureDetector(
                onTap: _endCall,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: ModernTheme.error,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.call_end,
                    color: context.surfaceColor,
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
        padding: EdgeInsets.all(12),
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
            SizedBox(height: 8),
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
    return Scaffold(
      backgroundColor: context.surfaceColor,
      // UI: Quick actions como grupo de FABs en la esquina inferior derecha
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // FAB: Ubicacion
          FloatingActionButton.small(
            heroTag: 'fab_location',
            backgroundColor: Theme.of(context).colorScheme.surface,
            onPressed: () => _showPassengerLocation(),
            child: Icon(Icons.location_on, color: ModernTheme.rappiOrange),
          ),
          const SizedBox(height: 8),
          // FAB: Chat
          FloatingActionButton.small(
            heroTag: 'fab_chat',
            backgroundColor: ModernTheme.info,
            onPressed: () => _sendMessage(_messageController.text),
            child: const Icon(Icons.chat, color: Colors.white),
          ),
          const SizedBox(height: 8),
          // FAB: Llamar
          FloatingActionButton(
            heroTag: 'fab_call',
            backgroundColor: ModernTheme.rappiOrange,
            onPressed: _startCall,
            child: const Icon(Icons.call, color: Colors.white),
          ),
        ],
      ),
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: (_passengerInfo['photo'] != null && _passengerInfo['photo'].toString().isNotEmpty && _passengerInfo['photo'].toString().startsWith('http'))
                  ? NetworkImage(_passengerInfo['photo'])
                  : null,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _passengerInfo['name'],
                    style: TextStyle(
                      color: context.primaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.star, size: 14, color: ModernTheme.accentYellow),
                      SizedBox(width: 4),
                      Text(
                        '${_passengerInfo['rating']}',
                        style: TextStyle(
                          color: context.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '${_passengerInfo['trips']} viajes',
                        style: TextStyle(
                          color: context.secondaryText,
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
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: context.secondaryText),
            onPressed: () => _showOptionsMenu(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Trip info bar
          Container(
            padding: EdgeInsets.all(12),
            color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: ModernTheme.rappiOrange, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recogida: ${_passengerInfo['pickup']}',
                        style: TextStyle(fontSize: 12),
                      ),
                      Text(
                        'Destino: ${_passengerInfo['destination']}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Chat messages
          Expanded(
            child: AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.all(16),
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
          
          // Quick responses
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: _quickResponses.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(_quickResponses[index]),
                    onPressed: () => _sendMessage(_quickResponses[index]),
                    backgroundColor: ModernTheme.rappiOrange.withValues(alpha: 0.1),
                    labelStyle: TextStyle(
                      color: ModernTheme.rappiOrange,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 8),
          
          // Message input
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              boxShadow: [
                BoxShadow(
                  color: context.primaryText.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Attach button
                  IconButton(
                    icon: Icon(Icons.attach_file, color: context.secondaryText),
                    onPressed: () => _showAttachmentOptions(),
                  ),
                  
                  // Text field
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: context.backgroundColor,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Escribe un mensaje...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: _sendMessage,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  
                  // Send button
                  Container(
                    decoration: BoxDecoration(
                      color: ModernTheme.rappiOrange,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.send, color: context.surfaceColor),
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
    
    return Align(
      alignment: isDriver ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: isDriver ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDriver ? ModernTheme.rappiOrange : context.surfaceColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: isDriver ? Radius.circular(16) : Radius.circular(4),
                  bottomRight: isDriver ? Radius.circular(4) : Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: context.primaryText.withValues(alpha: 0.05),
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: isDriver ? context.surfaceColor : context.primaryText,
                      fontSize: 14,
                    ),
                  ),
                  if (message.attachment != null)
                    Container(
                      margin: EdgeInsets.only(top: 8),
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.surfaceColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getAttachmentIcon(message.attachment!['type']),
                            color: isDriver ? context.surfaceColor : ModernTheme.rappiOrange,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            message.attachment!['name'],
                            style: TextStyle(
                              color: isDriver ? context.surfaceColor : context.primaryText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    color: context.secondaryText,
                    fontSize: 11,
                  ),
                ),
                if (isDriver) ...[
                  SizedBox(width: 4),
                  Icon(
                    message.status == MessageStatus.sending
                        ? Icons.access_time
                        : message.status == MessageStatus.sent
                            ? Icons.done
                            : Icons.done_all,
                    size: 14,
                    color: message.status == MessageStatus.read
                        ? ModernTheme.primaryBlue
                        : context.secondaryText,
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
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: context.primaryText.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ModernLoadingIndicator(
              color: ModernTheme.rappiOrange,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              'Escribiendo...',
              style: TextStyle(
                color: context.secondaryText,
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enviar',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(
                  Icons.image,
                  'Foto',
                  ModernTheme.primaryBlue,
                  () {
                    Navigator.pop(context);
                    _sendAttachment('image', 'Foto.jpg');
                  },
                ),
                _buildAttachmentOption(
                  Icons.location_on,
                  'Ubicación',
                  ModernTheme.rappiOrange,
                  () {
                    Navigator.pop(context);
                    _sendAttachment('location', 'Mi ubicación actual');
                  },
                ),
                _buildAttachmentOption(
                  Icons.mic,
                  'Audio',
                  ModernTheme.accentYellow,
                  () {
                    Navigator.pop(context);
                    _sendAttachment('audio', 'Mensaje de voz');
                  },
                ),
              ],
            ),
            SizedBox(height: 20),
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
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
  
  void _sendAttachment(String type, String name) {
    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: type == 'location' ? 'Compartí mi ubicación' : 'Archivo adjunto',
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
    
    // Simulate sending
    Future.delayed(Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        message.status = MessageStatus.sent;
      });
    });
  }
  
  // UI: placeholder para mostrar ubicacion del pasajero
  void _showPassengerLocation() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Mostrando ubicacion del pasajero'),
        backgroundColor: ModernTheme.rappiOrange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.person),
              title: Text('Ver perfil del pasajero'),
              onTap: () {
                Navigator.pop(context);
                _showPassengerProfile();
              },
            ),
            ListTile(
              leading: Icon(Icons.location_on),
              title: Text('Ver ubicación en mapa'),
              onTap: () {
                Navigator.pop(context);
                _openLocationInMap();
              },
            ),
            ListTile(
              leading: Icon(Icons.report),
              title: Text('Reportar problema'),
              onTap: () {
                Navigator.pop(context);
                _showReportDialog();
              },
            ),
            ListTile(
              leading: Icon(Icons.block, color: ModernTheme.error),
              title: Text('Bloquear usuario',
                style: TextStyle(color: ModernTheme.error)),
              onTap: () {
                Navigator.pop(context);
                _showBlockUserDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPassengerProfile() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Perfil del Pasajero'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: ModernTheme.rappiOrange.withValues(alpha:0.2),
              child: Text(
                (_passengerInfo['name'] as String).isNotEmpty
                    ? (_passengerInfo['name'] as String)[0].toUpperCase()
                    : 'P',
                style: TextStyle(fontSize: 32, color: ModernTheme.rappiOrange),
              ),
            ),
            SizedBox(height: 16),
            Text(
              _passengerInfo['name'] ?? 'Pasajero',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star, color: Colors.amber, size: 20),
                SizedBox(width: 4),
                Text('${_passengerInfo['rating']}'),
                SizedBox(width: 16),
                Icon(Icons.directions_car, color: ModernTheme.rappiOrange, size: 20),
                SizedBox(width: 4),
                Text('${_passengerInfo['trips']} viajes'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _openLocationInMap() {
    final pickup = _passengerInfo['pickup'] ?? '';
    if (pickup.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Abriendo mapa con ubicación de recogida...'),
          backgroundColor: ModernTheme.rappiOrange,
        ),
      );
      // En una implementación completa, abriría Google Maps con la ubicación
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ubicación no disponible'),
          backgroundColor: ModernTheme.warning,
        ),
      );
    }
  }

  void _showReportDialog() {
    final reportController = TextEditingController();
    String selectedIssue = 'Comportamiento inapropiado';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Reportar Problema'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedIssue,
                decoration: InputDecoration(
                  labelText: 'Tipo de problema',
                  border: OutlineInputBorder(),
                ),
                items: [
                  'Comportamiento inapropiado',
                  'Ubicación incorrecta',
                  'No se presentó',
                  'Cancelación injustificada',
                  'Otro',
                ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setDialogState(() => selectedIssue = v!),
              ),
              SizedBox(height: 16),
              TextField(
                controller: reportController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Describe el problema...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                reportController.dispose();
                Navigator.pop(context);
              },
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (reportController.text.trim().isNotEmpty) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Reporte enviado. Gracias por tu feedback.'),
                      backgroundColor: ModernTheme.success,
                    ),
                  );
                }
                reportController.dispose();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.rappiOrange,
              ),
              child: Text('Enviar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockUserDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bloquear Usuario'),
        content: Text(
          '¿Estás seguro de que deseas bloquear a este usuario? '
          'No podrás recibir viajes de este pasajero en el futuro.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Usuario bloqueado exitosamente'),
                  backgroundColor: ModernTheme.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.error,
            ),
            child: Text('Bloquear'),
          ),
        ],
      ),
    );
  }
}

// Chat message model
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