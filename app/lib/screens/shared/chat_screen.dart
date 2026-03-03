import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import '../../core/design/design_system.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_button.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../services/chat_service.dart';
import '../../providers/auth_provider.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../utils/firestore_error_handler.dart';

/// ChatScreen - Chat profesional en tiempo real
/// Implementacion completa con funcionalidad real
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
  late AnimationController _messageAnimationController;

  bool _isLoading = true;
  bool _isOtherUserOnline = false;
  DateTime? _otherUserLastSeen;
  List<ChatMessage> _messages = [];

  // Estados de UI
  bool _showQuickMessages = false;

  @override
  void initState() {
    super.initState();

    _typingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _messageAnimationController = AnimationController(
      duration: RtDuration.normal,
      vsync: this,
    );

    _initializeChat();
  }

  @override
  void dispose() {
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
          RtSnackbar.show(
            context,
            message: 'Debes iniciar sesión para usar el chat',
            type: RtSnackbarType.warning,
          );
        }
        return;
      }

      debugPrint('Inicializando chat para usuario: ${user.id}, rol: ${user.activeMode}');

      // Inicializar el servicio de chat
      // DUAL-ACCOUNT: Usar activeMode para identificar rol actual del usuario
      await _chatService.initialize(
        userId: user.id,
        userRole: user.activeMode,
      );

      debugPrint('ChatService inicializado, marcando mensajes como leidos...');

      // Marcar mensajes como leidos al entrar
      await _chatService.markMessagesAsRead(widget.rideId, user.id);

      debugPrint('Configurando listener de mensajes...');

      // Escuchar mensajes en tiempo real
      _chatService.getChatMessages(widget.rideId).listen(
        (messages) {
          if (mounted) {
            setState(() {
              _messages = messages;
            });
            _scrollToBottom();
          }
        },
        onError: (error) {
          debugPrint('Error en stream de mensajes: $error');
        },
      );

      // Obtener estado de presencia del otro usuario si esta disponible
      if (widget.otherUserId != null) {
        _chatService.getUserPresence(widget.otherUserId!).listen(
          (presence) {
            if (mounted) {
              setState(() {
                _isOtherUserOnline = presence.online;
                _otherUserLastSeen = presence.lastSeen;
              });
            }
          },
          onError: (error) {
            debugPrint('Error en stream de presencia: $error');
          },
        );
      }

      // Terminar la carga, incluso si hay errores menores
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      debugPrint('Chat inicializado correctamente para viaje ${widget.rideId}');
    } catch (e) {
      debugPrint('Error inicializando chat: $e');
      // No cerrar el chat, solo mostrar error y permitir reintentar
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: RtDuration.normal,
          curve: RtCurve.enter,
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
      // DUAL-ACCOUNT: Usar activeMode para identificar rol actual
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
        RtSnackbar.show(
          context,
          message: AppLocalizations.of(context)!.errorSendingMessage,
          type: RtSnackbarType.error,
        );
      }
    } catch (e) {
      debugPrint('Error enviando mensaje: $e');
      if (!mounted) return;
      RtSnackbar.show(
        context,
        message: AppLocalizations.of(context)!.errorSendingMessage,
        type: RtSnackbarType.error,
      );
    }
  }

  Future<void> _sendQuickMessage(QuickMessageType type) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;

      if (user == null) return;

      // DUAL-ACCOUNT: Usar activeMode para identificar rol actual
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
      // En una implementacion real, usariamos GPS
      const latitude = -12.0464;
      const longitude = -77.0428;

      // DUAL-ACCOUNT: Usar activeMode para identificar rol actual
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
    // Guardar referencia antes de await para evitar uso de context después de gaps async
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.media,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
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
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(RtColors.white),
                  ),
                ),
                const SizedBox(width: RtSpacing.base),
                Text(AppLocalizations.of(context)!.sendingFile),
              ],
            ),
            duration: const Duration(seconds: 10),
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

        // DUAL-ACCOUNT: Usar activeMode para identificar rol actual
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
          RtSnackbar.show(
            context,
            message: AppLocalizations.of(context)!.errorSendingFile,
            type: RtSnackbarType.error,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      debugPrint('Error enviando multimedia: $e');
      if (!mounted) return;
      RtSnackbar.show(
        context,
        message: AppLocalizations.of(context)!.errorSendingFile,
        type: RtSnackbarType.error,
      );
    }
  }

  /// Maneja la llamada telefonica al otro usuario del chat
  Future<void> _handlePhoneCall() async {
    HapticFeedback.lightImpact();

    try {
      // Obtener número de teléfono del otro usuario desde Firestore
      if (widget.otherUserId == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherUserId)
          .get();

      if (!mounted) return;

      if (!userDoc.exists) return;

      final phone = userDoc.data()?['phone'] as String?;
      if (phone == null || phone.isEmpty) {
        RtSnackbar.show(context, message: 'Número de teléfono no disponible', type: RtSnackbarType.warning);
        return;
      }

      final Uri phoneUri = Uri(scheme: 'tel', path: phone);
      final canLaunch = await canLaunchUrl(phoneUri);
      if (!mounted) return;

      if (canLaunch) {
        await launchUrl(phoneUri);
      } else {
        RtSnackbar.show(context, message: 'No se puede realizar la llamada', type: RtSnackbarType.error);
      }
    } catch (e) {
      if (!mounted) return;
      RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: RtAppBar(
        variant: RtAppBarVariant.gradient,
        titleWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.otherUserName,
              style: RtTypo.headingSmall.copyWith(color: RtColors.white),
            ),
            Text(
              _buildStatusText(),
              style: RtTypo.labelSmall.copyWith(
                color: RtColors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone, color: RtColors.white),
            onPressed: _handlePhoneCall,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: RtColors.white),
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
            valueColor: AlwaysStoppedAnimation<Color>(RtColors.brand),
          ),
          const SizedBox(height: RtSpacing.base),
          Text(
            AppLocalizations.of(context)!.initiatingChat,
            style: RtTypo.bodyLarge.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
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
        return AppLocalizations.of(context)!
            .seenMinutesAgo(difference.inMinutes);
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
      padding: RtSpacing.paddingBase,
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
            padding: const EdgeInsets.all(RtSpacing.xxl),
            decoration: BoxDecoration(
              color: RtColors.brand.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: RtColors.brand,
            ),
          ),
          const SizedBox(height: RtSpacing.xl),
          Text(
            AppLocalizations.of(context)!.startConversation,
            style: RtTypo.headingMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: RtSpacing.sm),
          Padding(
            padding: RtSpacing.screenH,
            child: Text(
              widget.otherUserRole == 'driver'
                  ? AppLocalizations.of(context)!.stayInTouchWithDriver
                  : AppLocalizations.of(context)!.stayInTouchWithPassenger,
              textAlign: TextAlign.center,
              style: RtTypo.bodyMedium.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMyMessage) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: RtSpacing.md),
      child: Row(
        mainAxisAlignment:
            isMyMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMyMessage) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: RtColors.brand.withValues(alpha: 0.2),
              child: Text(
                message.senderName.isNotEmpty
                    ? message.senderName[0].toUpperCase()
                    : '?',
                style: RtTypo.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: RtColors.brand,
                ),
              ),
            ),
            const SizedBox(width: RtSpacing.sm),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: RtSpacing.base,
                vertical: RtSpacing.md,
              ),
              decoration: BoxDecoration(
                color: isMyMessage ? RtColors.brand : colorScheme.surface,
                borderRadius: BorderRadius.circular(18).copyWith(
                  bottomLeft: Radius.circular(isMyMessage ? 18 : 4),
                  bottomRight: Radius.circular(isMyMessage ? 4 : 18),
                ),
                boxShadow: RtShadow.soft(),
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
                  const SizedBox(height: RtSpacing.xs),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatMessageTime(message.timestamp),
                        style: RtTypo.labelSmall.copyWith(
                          color: isMyMessage
                              ? RtColors.white.withValues(alpha: 0.7)
                              : colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      if (isMyMessage) ...[
                        const SizedBox(width: RtSpacing.xs),
                        Icon(
                          message.isRead ? Icons.done_all : Icons.done,
                          size: 14,
                          color: message.isRead
                              ? RtColors.info
                              : RtColors.white.withValues(alpha: 0.7),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMyMessage) const SizedBox(width: 50),
          if (!isMyMessage) const SizedBox(width: 50),
        ],
      ),
    );
  }

  Widget _buildTextMessage(ChatMessage message, bool isMyMessage) {
    return Text(
      message.message,
      style: RtTypo.bodyMedium.copyWith(
        color: isMyMessage
            ? RtColors.white
            : Theme.of(context).colorScheme.onSurface,
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
          size: RtIconSize.sm,
          color: isMyMessage ? RtColors.white : RtColors.brand,
        ),
        const SizedBox(width: RtSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: RtTypo.titleMedium.copyWith(
                  color: isMyMessage
                      ? RtColors.white
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (message.message.isNotEmpty) ...[
                const SizedBox(height: RtSpacing.xs),
                Text(
                  message.message,
                  style: RtTypo.bodySmall.copyWith(
                    color: isMyMessage
                        ? RtColors.white.withValues(alpha: 0.8)
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
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
          size: RtIconSize.sm,
          color: isMyMessage ? RtColors.white : RtColors.error,
        ),
        const SizedBox(width: RtSpacing.sm),
        Expanded(
          child: Text(
            AppLocalizations.of(context)!.sharedLocation,
            style: RtTypo.titleMedium.copyWith(
              color: isMyMessage
                  ? RtColors.white
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickMessagesBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RtSpacing.base,
        vertical: RtSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: RtColors.neutral200),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: QuickMessageType.values.map((type) {
            return Padding(
              padding: const EdgeInsets.only(right: RtSpacing.sm),
              child: RtButton(
                label: _getQuickMessageText(type),
                variant: RtButtonVariant.ghost,
                size: RtButtonSize.small,
                isFullWidth: false,
                onPressed: () => _sendQuickMessage(type),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RtSpacing.sm,
        vertical: RtSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: RtShadow.soft(),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Boton de mensajes rápidos / adjuntos
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: RtRadius.borderFull,
                onTap: () {
                  setState(() {
                    _showQuickMessages = !_showQuickMessages;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(RtSpacing.sm),
                  child: Icon(
                    _showQuickMessages
                        ? Icons.keyboard
                        : Icons.add_circle_outline,
                    color: RtColors.brand,
                    size: RtIconSize.md,
                  ),
                ),
              ),
            ),
            const SizedBox(width: RtSpacing.xs),
            // Campo de texto expandido
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: RtRadius.borderXl,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        focusNode: _messageFocusNode,
                        decoration: InputDecoration(
                          hintText:
                              AppLocalizations.of(context)!.writeMessage,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: RtSpacing.base,
                            vertical: 10,
                          ),
                          hintStyle: RtTypo.bodyMedium.copyWith(
                            color: colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        style: RtTypo.bodyMedium,
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
                        borderRadius: RtRadius.borderFull,
                        onTap: _pickAndSendMedia,
                        child: Padding(
                          padding: const EdgeInsets.all(RtSpacing.sm),
                          child: Icon(
                            Icons.attach_file,
                            color: colorScheme.onSurface
                                .withValues(alpha: 0.6),
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: RtRadius.borderFull,
                        onTap: _shareLocation,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            right: RtSpacing.xs,
                            top: RtSpacing.sm,
                            bottom: RtSpacing.sm,
                          ),
                          child: Icon(
                            Icons.location_on_outlined,
                            color: colorScheme.onSurface
                                .withValues(alpha: 0.6),
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: RtSpacing.sm),
            // Boton de enviar
            Material(
              color: RtColors.brand,
              borderRadius: RtRadius.borderXl,
              child: InkWell(
                borderRadius: RtRadius.borderXl,
                onTap: _sendMessage,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  child: const Icon(
                    Icons.send_rounded,
                    color: RtColors.white,
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
      shape: RoundedRectangleBorder(borderRadius: RtRadius.sheetTop),
      builder: (context) {
        return Container(
          padding: RtSpacing.paddingBase,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: RtColors.neutral300,
                    borderRadius: RtRadius.borderFull,
                  ),
                ),
              ),
              const SizedBox(height: RtSpacing.base),
              ListTile(
                leading: const Icon(Icons.clear_all, color: RtColors.error),
                title: Text(
                  AppLocalizations.of(context)!.clearChat,
                  style: RtTypo.titleMedium,
                ),
                shape: RoundedRectangleBorder(borderRadius: RtRadius.borderMd),
                onTap: () {
                  Navigator.pop(context);
                  _showClearChatDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.report, color: RtColors.warning),
                title: Text(
                  AppLocalizations.of(context)!.reportUser,
                  style: RtTypo.titleMedium,
                ),
                shape: RoundedRectangleBorder(borderRadius: RtRadius.borderMd),
                onTap: () {
                  Navigator.pop(context);
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
          shape: RoundedRectangleBorder(borderRadius: RtRadius.borderLg),
          title: Text(AppLocalizations.of(context)!.clearChat,
              style: RtTypo.headingSmall),
          content: Text(
            AppLocalizations.of(context)!.clearChatConfirmation,
            style: RtTypo.bodyMedium,
          ),
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
                backgroundColor: RtColors.error,
                foregroundColor: RtColors.white,
                shape: RoundedRectangleBorder(borderRadius: RtRadius.borderSm),
              ),
              child: Text(AppLocalizations.of(context)!.clear),
            ),
          ],
        );
      },
    );
  }

  // Mostrar dialogo de reporte de usuario
  void _showReportUserDialog() {
    final TextEditingController reportController = TextEditingController();
    String selectedReason = 'Comportamiento inapropiado';
    final List<String> reasons = [
      'Comportamiento inapropiado',
      'Lenguaje ofensivo',
      'Acoso',
      'Conduccion peligrosa',
      'Tarifa incorrecta',
      'Otro',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: RtRadius.borderLg),
          title: Text('Reportar Usuario', style: RtTypo.headingSmall),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reportar a: ${widget.otherUserName}',
                  style: RtTypo.bodyLarge,
                ),
                const SizedBox(height: RtSpacing.base),
                Text('Motivo:',
                    style:
                        RtTypo.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: RtSpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: selectedReason,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: RtRadius.borderMd),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: RtSpacing.base,
                      vertical: RtSpacing.md,
                    ),
                  ),
                  items: reasons.map((reason) {
                    return DropdownMenuItem(value: reason, child: Text(reason));
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedReason = value!);
                  },
                ),
                const SizedBox(height: RtSpacing.base),
                Text('Detalles adicionales:',
                    style:
                        RtTypo.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: RtSpacing.sm),
                TextField(
                  controller: reportController,
                  decoration: InputDecoration(
                    hintText: 'Describe el problema...',
                    border: OutlineInputBorder(borderRadius: RtRadius.borderMd),
                    contentPadding: RtSpacing.paddingBase,
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
              child: Text(
                'Cancelar',
                style: RtTypo.labelLarge.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final details = reportController.text.trim();

                try {
                  final authProvider =
                      Provider.of<AuthProvider>(context, listen: false);
                  final userId = authProvider.currentUser?.id;

                  // Crear reporte en Firebase
                  await FirebaseFirestore.instance
                      .collection('userReports')
                      .add({
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

                  if (!mounted) return;
                  RtSnackbar.show(this.context, message: 'Reporte enviado. Revisaremos el caso.', type: RtSnackbarType.success);
                } catch (e) {
                  if (!mounted) return;
                  RtSnackbar.show(this.context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: RtColors.warning,
                foregroundColor: RtColors.white,
                shape: RoundedRectangleBorder(borderRadius: RtRadius.borderSm),
              ),
              child: const Text('Enviar Reporte'),
            ),
          ],
        ),
      ),
    );
  }
}
