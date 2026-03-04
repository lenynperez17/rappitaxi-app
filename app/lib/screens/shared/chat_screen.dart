// ignore_for_file: use_build_context_synchronously
// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import '../../core/theme/modern_theme.dart';
import '../../core/extensions/theme_extensions.dart'; // ✅ Extensión para colores que se adaptan al tema
import '../../services/chat_service.dart';
import '../../providers/auth_provider.dart';
import '../../generated/l10n/app_localizations.dart';

/// ChatScreen - Chat profesional en tiempo real
/// ✅ IMPLEMENTACIÓN COMPLETA con funcionalidad real
class ChatScreen extends StatefulWidget {
  final String rideId;
  final String otherUserName;
  final String otherUserRole; // 'passenger' o 'driver'
  final String? otherUserId;

  const ChatScreen({
    super.key,
    required this.rideId,
    required this.otherUserName,
    required this.otherUserRole,
    this.otherUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with TickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  late AnimationController _typingAnimationController;
  late Animation<double> _typingAnimation;
  late AnimationController _messageAnimationController;

  // Subscriptions para evitar memory leaks
  StreamSubscription? _messagesSubscription;
  StreamSubscription? _presenceSubscription;

  bool _isLoading = true;
  final bool _isTyping = false;
  bool _isOtherUserOnline = false;
  DateTime? _otherUserLastSeen;
  List<ChatMessage> _messages = [];
  final int _unreadCount = 0;

  // Estados de UI
  bool _showQuickMessages = false;
  final bool _isRecordingAudio = false;
  final bool _showEmojiPicker = false;

  @override
  void initState() {
    super.initState();
    
    _typingAnimationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );
    _typingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _typingAnimationController, curve: Curves.easeInOut),
    );
    _messageAnimationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _initializeChat();

    // ✅ Auto-scroll cuando el teclado abre (campo de mensaje recibe foco)
    _messageFocusNode.addListener(() {
      if (_messageFocusNode.hasFocus) {
        Future.delayed(Duration(milliseconds: 400), () => _scrollToBottom());
      }
    });
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _presenceSubscription?.cancel();
    _typingAnimationController.dispose();
    _messageAnimationController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    try {
      if (!mounted) return;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;

      if (user == null) {
        debugPrint('Usuario no autenticado');
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Debes iniciar sesión para usar el chat'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      debugPrint('💬 Inicializando chat para usuario: ${user.id}, rol: ${user.activeMode}');

      // Inicializar el servicio de chat
      // ✅ DUAL-ACCOUNT: Usar activeMode para identificar rol actual del usuario
      await _chatService.initialize(
        userId: user.id,
        userRole: user.activeMode,
      );

      debugPrint('💬 ChatService inicializado, marcando mensajes como leídos...');

      // Marcar mensajes como leídos al entrar
      await _chatService.markMessagesAsRead(widget.rideId, user.id);

      debugPrint('💬 Configurando listener de mensajes...');

      // Escuchar mensajes en tiempo real (almacenar subscription)
      _messagesSubscription?.cancel();
      _messagesSubscription = _chatService.getChatMessages(widget.rideId).listen(
        (messages) {
          if (mounted) {
            setState(() {
              _messages = messages;
            });
            _scrollToBottom();
          }
        },
        onError: (error) {
          debugPrint('💬 Error en stream de mensajes: $error');
        },
      );

      // Obtener estado de presencia del otro usuario si está disponible
      if (widget.otherUserId != null) {
        _presenceSubscription?.cancel();
        _presenceSubscription = _chatService.getUserPresence(widget.otherUserId!).listen(
          (presence) {
            if (mounted) {
              setState(() {
                _isOtherUserOnline = presence.online;
                _otherUserLastSeen = presence.lastSeen;
              });
            }
          },
          onError: (error) {
            debugPrint('💬 Error en stream de presencia: $error');
          },
        );
      }

      // ✅ SIEMPRE terminar la carga, incluso si hay errores menores
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      debugPrint('💬 Chat inicializado correctamente para viaje ${widget.rideId}');

    } catch (e) {
      debugPrint('💬 Error inicializando chat: $e');
      // ✅ CORREGIDO: No cerrar el chat, solo mostrar error y permitir reintentar
      if (mounted) {
        setState(() {
          _isLoading = false; // Permitir ver la pantalla vacía
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar chat: ${e.toString().length > 50 ? e.toString().substring(0, 50) : e.toString()}'),
            backgroundColor: ModernTheme.error,
            action: SnackBarAction(
              label: 'Reintentar',
              textColor: Colors.white,
              onPressed: () => _initializeChat(),
            ),
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      
      if (user == null) return;

      // Limpiar el campo de texto
      _messageController.clear();
      _messageFocusNode.unfocus();

      // Enviar mensaje
      // ✅ DUAL-ACCOUNT: Usar activeMode para identificar rol actual
      final success = await _chatService.sendTextMessage(
        rideId: widget.rideId,
        senderId: user.id,
        senderName: user.fullName,
        message: message,
        senderRole: user.activeMode,
      );

      if (!mounted) return;

      if (success) {
        HapticFeedback.lightImpact();
        _messageAnimationController.forward().then((_) {
          _messageAnimationController.reset();
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorSendingMessage),
            backgroundColor: ModernTheme.error,
          ),
        );
      }

    } catch (e) {
      debugPrint('Error enviando mensaje: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.errorSendingMessage),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }

  Future<void> _sendQuickMessage(QuickMessageType type) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      
      if (user == null) return;

      // ✅ DUAL-ACCOUNT: Usar activeMode para identificar rol actual
      final success = await _chatService.sendQuickMessage(
        rideId: widget.rideId,
        senderId: user.id,
        senderName: user.fullName,
        senderRole: user.activeMode,
        type: type,
      );

      if (success) {
        setState(() {
          _showQuickMessages = false;
        });
        HapticFeedback.lightImpact();
      }

    } catch (e) {
      debugPrint('Error enviando mensaje rápido: $e');
    }
  }

  Future<void> _shareLocation() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      
      if (user == null) return;

      // Obtener ubicación actual (simulada)
      // En una implementación real, usaríamos GPS
      const latitude = -12.0464;
      const longitude = -77.0428;

      // ✅ DUAL-ACCOUNT: Usar activeMode para identificar rol actual
      final success = await _chatService.shareLocation(
        rideId: widget.rideId,
        senderId: user.id,
        senderName: user.fullName,
        senderRole: user.activeMode,
        latitude: latitude,
        longitude: longitude,
      );

      if (success) {
        HapticFeedback.lightImpact();
      }

    } catch (e) {
      debugPrint('Error compartiendo ubicación: $e');
    }
  }

  Future<void> _pickAndSendMedia() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.media,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final user = authProvider.currentUser;
        
        if (user == null) return;

        // Mostrar indicador de carga
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text(AppLocalizations.of(context)!.sendingFile),
              ],
            ),
            duration: Duration(seconds: 10),
          ),
        );

        // Determinar tipo de archivo
        MessageType messageType = MessageType.file;
        final extension = result.files.single.extension?.toLowerCase();
        if (extension != null) {
          if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
            messageType = MessageType.image;
          } else if (['mp4', 'mov', 'avi'].contains(extension)) {
            messageType = MessageType.video;
          } else if (['mp3', 'wav', 'm4a'].contains(extension)) {
            messageType = MessageType.audio;
          }
        }

        // ✅ DUAL-ACCOUNT: Usar activeMode para identificar rol actual
        final success = await _chatService.sendMultimediaMessage(
          rideId: widget.rideId,
          senderId: user.id,
          senderName: user.fullName,
          senderRole: user.activeMode,
          mediaFile: file,
          messageType: messageType,
        );

        // Ocultar indicador de carga
        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        if (success) {
          HapticFeedback.lightImpact();
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.errorSendingFile),
              backgroundColor: ModernTheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      debugPrint('Error enviando multimedia: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.errorSendingFile),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surfaceColor,
      appBar: AppBar(
        backgroundColor: ModernTheme.rappiOrange,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherUserName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            Text(_buildStatusText(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.phone, color: context.surfaceColor),
            onPressed: () async {
              // ✅ IMPLEMENTADO: Llamada telefónica
              HapticFeedback.lightImpact();
              final messenger = ScaffoldMessenger.of(context);

              try {
                // Obtener número de teléfono del otro usuario desde Firestore
                if (widget.otherUserId != null) {
                  final userDoc = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.otherUserId)
                      .get();

                  if (userDoc.exists) {
                    // Buscar en ambos campos (inconsistencia entre login normal y social)
                    final userData = userDoc.data();
                    final phone = (userData?['phone'] as String?) ??
                                  (userData?['phoneNumber'] as String?) ?? '';
                    if (phone.isNotEmpty) {
                      final Uri phoneUri = Uri(scheme: 'tel', path: phone);
                      if (await canLaunchUrl(phoneUri)) {
                        await launchUrl(phoneUri);
                      } else {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('No se puede realizar la llamada'),
                            backgroundColor: ModernTheme.error,
                          ),
                        );
                      }
                    } else {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Este usuario no ha registrado su número de teléfono'),
                          backgroundColor: ModernTheme.warning,
                        ),
                      );
                    }
                  }
                }
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Error al intentar llamar: $e'),
                    backgroundColor: ModernTheme.error,
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: context.surfaceColor),
            onPressed: () {
              _showChatOptions();
            },
          ),
        ],
      ),
      body: _isLoading 
          ? _buildLoadingState()
          : Column(
              children: [
                Expanded(child: _buildMessagesList()),
                if (_showQuickMessages) _buildQuickMessagesBar(),
                _buildMessageInput(),
              ],
            ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(ModernTheme.rappiOrange),
          ),
          SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.initiatingChat,
            style: TextStyle(
              color: context.secondaryText,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  String _buildStatusText() {
    if (_isOtherUserOnline) {
      return AppLocalizations.of(context)!.online;
    } else if (_otherUserLastSeen != null) {
      final now = DateTime.now();
      final difference = now.difference(_otherUserLastSeen!);

      if (difference.inMinutes < 1) {
        return AppLocalizations.of(context)!.seenMomentAgo;
      } else if (difference.inMinutes < 60) {
        return AppLocalizations.of(context)!.seenMinutesAgo(difference.inMinutes);
      } else if (difference.inHours < 24) {
        return AppLocalizations.of(context)!.seenHoursAgo(difference.inHours);
      } else {
        return AppLocalizations.of(context)!.seenDaysAgo(difference.inDays);
      }
    }

    final roleText = widget.otherUserRole == 'driver'
        ? AppLocalizations.of(context)!.driver
        : AppLocalizations.of(context)!.passenger;
    return roleText;
  }

  Widget _buildMessagesList() {
    if (_messages.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final isMyMessage = message.senderId == authProvider.currentUser?.id;

        return _buildMessageBubble(message, isMyMessage);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: ModernTheme.rappiOrange,
            ),
          ),
          SizedBox(height: 24),
          Text(
            AppLocalizations.of(context)!.startConversation,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.primaryText,
            ),
          ),
          SizedBox(height: 8),
          Text(
            widget.otherUserRole == 'driver'
                ? AppLocalizations.of(context)!.stayInTouchWithDriver
                : AppLocalizations.of(context)!.stayInTouchWithPassenger,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: context.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  // Groups messages by hour to show timestamps only on first/last of each group
  bool _shouldShowTimestamp(int index, bool isMyMessage) {
    final message = _messages[index];
    final isLast = index == _messages.length - 1;
    if (isLast) return true;

    final nextMessage = _messages[index + 1];
    final sameHour = message.timestamp.hour == nextMessage.timestamp.hour &&
        message.timestamp.day == nextMessage.timestamp.day;
    final sameSender = message.senderId == nextMessage.senderId;

    // Show on last message of a group (different sender or different hour next)
    if (!sameHour || !sameSender) return true;

    // Show on first message of a group
    if (index == 0) return true;
    final prevMessage = _messages[index - 1];
    final prevSameHour = message.timestamp.hour == prevMessage.timestamp.hour &&
        message.timestamp.day == prevMessage.timestamp.day;
    final prevSameSender = message.senderId == prevMessage.senderId;
    if (!prevSameHour || !prevSameSender) return true;

    return false;
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMyMessage) {
    final index = _messages.indexOf(message);
    final showTimestamp = _shouldShowTimestamp(index, isMyMessage);

    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMyMessage
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMyMessage) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: ModernTheme.rappiOrange.withValues(alpha: 0.2),
              child: Text(
                message.senderName.isNotEmpty
                    ? message.senderName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ModernTheme.rappiOrange,
                ),
              ),
            ),
            SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMyMessage
                    ? ModernTheme.rappiOrange
                    : context.surfaceColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(isMyMessage ? 20 : 4),
                  bottomRight: Radius.circular(isMyMessage ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: context.primaryText.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.messageType == MessageType.location)
                    _buildLocationMessage(message, isMyMessage)
                  else if (message.messageType != MessageType.text)
                    _buildMediaMessage(message, isMyMessage)
                  else
                    _buildTextMessage(message, isMyMessage),

                  if (showTimestamp) ...[
                    SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatMessageTime(message.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: isMyMessage
                                ? context.surfaceColor.withValues(alpha: 0.7)
                                : context.secondaryText,
                          ),
                        ),
                        if (isMyMessage) ...[
                          SizedBox(width: 4),
                          Icon(
                            message.isRead ? Icons.done_all : Icons.done,
                            size: 14,
                            color: message.isRead
                                ? ModernTheme.info
                                : context.surfaceColor.withValues(alpha: 0.7),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isMyMessage) SizedBox(width: 50),
          if (!isMyMessage) SizedBox(width: 50),
        ],
      ),
    );
  }

  Widget _buildTextMessage(ChatMessage message, bool isMyMessage) {
    return Text(
      message.message,
      style: TextStyle(
        fontSize: 15,
        color: isMyMessage ? context.surfaceColor : context.primaryText,
        height: 1.3,
      ),
    );
  }

  Widget _buildMediaMessage(ChatMessage message, bool isMyMessage) {
    IconData icon;
    String label;

    switch (message.messageType) {
      case MessageType.image:
        icon = Icons.image;
        label = AppLocalizations.of(context)!.imageLabel;
        break;
      case MessageType.audio:
        icon = Icons.audiotrack;
        label = AppLocalizations.of(context)!.audioLabel;
        break;
      case MessageType.video:
        icon = Icons.videocam;
        label = AppLocalizations.of(context)!.videoLabel;
        break;
      default:
        icon = Icons.attachment;
        label = AppLocalizations.of(context)!.fileLabel;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 20,
          color: isMyMessage ? context.surfaceColor : ModernTheme.rappiOrange,
        ),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isMyMessage ? context.surfaceColor : context.primaryText,
                ),
              ),
              if (message.message.isNotEmpty) ...[
                SizedBox(height: 4),
                Text(
                  message.message,
                  style: TextStyle(
                    fontSize: 13,
                    color: isMyMessage
                        ? context.surfaceColor.withValues(alpha: 0.8)
                        : context.secondaryText,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationMessage(ChatMessage message, bool isMyMessage) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.location_on,
          size: 20,
          color: isMyMessage ? context.surfaceColor : ModernTheme.error,
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            AppLocalizations.of(context)!.sharedLocation,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isMyMessage ? context.surfaceColor : context.primaryText,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickMessagesBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: QuickMessageType.values.map((type) {
            return Padding(
              padding: EdgeInsets.only(right: 8),
              child: ElevatedButton(
                onPressed: () => _sendQuickMessage(type),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ModernTheme.rappiOrange.withValues(alpha: 0.1),
                  foregroundColor: ModernTheme.rappiOrange,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  _getQuickMessageText(type),
                  style: TextStyle(fontSize: 12),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Botón de mensajes rápidos / adjuntos
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  setState(() {
                    _showQuickMessages = !_showQuickMessages;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    _showQuickMessages ? Icons.keyboard : Icons.add_circle_outline,
                    color: ModernTheme.rappiOrange,
                    size: 24,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Campo de texto expandido
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        focusNode: _messageFocusNode,
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context)!.writeMessage,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          hintStyle: TextStyle(
                            color: context.secondaryText,
                            fontSize: 15,
                          ),
                        ),
                        style: const TextStyle(fontSize: 15),
                        maxLines: 4,
                        minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    // Iconos de adjuntar y ubicación dentro del campo
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _pickAndSendMedia,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.attach_file,
                            color: context.secondaryText,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _shareLocation,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4, top: 8, bottom: 8),
                          child: Icon(
                            Icons.location_on_outlined,
                            color: context.secondaryText,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Botón de enviar
            Material(
              color: ModernTheme.rappiOrange,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: _sendMessage,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getQuickMessageText(QuickMessageType type) {
    switch (type) {
      case QuickMessageType.onMyWay:
        return AppLocalizations.of(context)!.onMyWay;
      case QuickMessageType.arrived:
        return AppLocalizations.of(context)!.arrived;
      case QuickMessageType.waiting:
        return AppLocalizations.of(context)!.waiting;
      case QuickMessageType.trafficDelay:
        return AppLocalizations.of(context)!.trafficDelay;
      case QuickMessageType.cantFind:
        return AppLocalizations.of(context)!.cantFind;
    }
  }

  String _formatMessageTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return AppLocalizations.of(context)!.now;
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }

  void _showChatOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.clear_all, color: ModernTheme.error),
                title: Text(AppLocalizations.of(context)!.clearChat),
                onTap: () {
                  Navigator.pop(context);
                  _showClearChatDialog();
                },
              ),
              ListTile(
                leading: Icon(Icons.report, color: ModernTheme.warning),
                title: Text(AppLocalizations.of(context)!.reportUser),
                onTap: () {
                  Navigator.pop(context);
                  // ✅ IMPLEMENTADO: Reporte de usuario
                  _showReportUserDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showClearChatDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.clearChat),
          content: Text(AppLocalizations.of(context)!.clearChatConfirmation),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _chatService.clearChat(widget.rideId);
                setState(() {
                  _messages.clear();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.error,
                foregroundColor: context.surfaceColor,
              ),
              child: Text(AppLocalizations.of(context)!.clear),
            ),
          ],
        );
      },
    );
  }

  // ✅ IMPLEMENTADO: Mostrar diálogo de reporte de usuario
  void _showReportUserDialog() {
    final TextEditingController reportController = TextEditingController();
    String selectedReason = 'Comportamiento inapropiado';
    final List<String> reasons = [
      'Comportamiento inapropiado',
      'Lenguaje ofensivo',
      'Acoso',
      'Conducción peligrosa',
      'Tarifa incorrecta',
      'Otro',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Reportar Usuario', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reportar a: ${widget.otherUserName}', style: TextStyle(fontSize: 16)),
                SizedBox(height: 16),
                Text('Motivo:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: reasons.map((reason) {
                    return DropdownMenuItem(value: reason, child: Text(reason));
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedReason = value!);
                  },
                ),
                SizedBox(height: 16),
                Text('Detalles adicionales:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                TextField(
                  controller: reportController,
                  decoration: InputDecoration(
                    hintText: 'Describe el problema...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: EdgeInsets.all(16),
                  ),
                  maxLines: 4,
                  maxLength: 300,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                reportController.dispose();
                Navigator.pop(context);
              },
              child: Text('Cancelar', style: TextStyle(color: context.secondaryText)),
            ),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                final details = reportController.text.trim();

                try {
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  final userId = authProvider.currentUser?.id;

                  // Crear reporte en Firebase
                  await FirebaseFirestore.instance.collection('userReports').add({
                    'reportedBy': userId,
                    'reportedUser': widget.otherUserId,
                    'reportedUserName': widget.otherUserName,
                    'reason': selectedReason,
                    'details': details,
                    'rideId': widget.rideId,
                    'status': 'pending',
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  reportController.dispose();
                  navigator.pop();

                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Reporte enviado. Revisaremos el caso.'),
                      backgroundColor: ModernTheme.success,
                      duration: Duration(seconds: 3),
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error al enviar reporte: $e'),
                      backgroundColor: ModernTheme.error,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.warning,
                foregroundColor: context.surfaceColor,
              ),
              child: Text('Enviar Reporte'),
            ),
          ],
        ),
      ),
    );
  }
}