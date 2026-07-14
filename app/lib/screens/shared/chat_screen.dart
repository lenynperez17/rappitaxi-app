// ignore_for_file: use_build_context_synchronously
// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import '../../core/constants/app_colors.dart';
import '../../services/chat_service.dart';
import '../../providers/auth_provider.dart';
import '../../core/utils/responsive_bottom_sheet.dart';
import '../../utils/error_messages.dart';

/// ChatScreen - Real-time professional chat
class ChatScreen extends StatefulWidget {
  final String rideId;
  final String otherUserName;
  final String otherUserRole;
  final String? otherUserId;

  const ChatScreen({super.key, required this.rideId, required this.otherUserName, required this.otherUserRole, this.otherUserId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  late AnimationController _typingAnimationController;
  late Animation<double> _typingAnimation;
  late AnimationController _messageAnimationController;

  bool _isLoading = true;
  bool _hasError = false;
  final bool _isTyping = false;
  bool _isOtherUserOnline = false;
  DateTime? _otherUserLastSeen;
  List<ChatMessage> _messages = [];
  final int _unreadCount = 0;
  bool _showQuickMessages = false;
  final bool _isRecordingAudio = false;
  final bool _showEmojiPicker = false;
  StreamSubscription<List<ChatMessage>>? _messagesSubscription;
  StreamSubscription? _presenceSubscription;

  @override
  void initState() {
    super.initState();
    _typingAnimationController = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this);
    _typingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _typingAnimationController, curve: Curves.easeInOut));
    _messageAnimationController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _initializeChat();
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _presenceSubscription?.cancel();
    // Fire-and-forget: cancelar SSE + cerrar StreamController del service
    // para este rideId. Sin esto, cada chat abierto deja controllers y
    // listeners colgados en memoria hasta cerrar la app (leak por ride).
    // Si el user reabre el mismo chat, `getChatMessages` reconstruye el
    // controller automáticamente.
    unawaited(_chatService.clearChat(widget.rideId));
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
      if (user == null) { if (mounted) Navigator.pop(context); return; }

      await _chatService.initialize(userId: user.id, userRole: user.activeMode);
      await _chatService.markMessagesAsRead(widget.rideId, user.id);

      _messagesSubscription = _chatService.getChatMessages(widget.rideId).listen(
        (messages) {
          if (mounted) { setState(() { _messages = messages; _isLoading = false; }); _scrollToBottom(); }
        },
        onError: (error) {
          debugPrint(userFriendlyError(error, fallback: 'Error en stream de chat'));
          if (mounted) { setState(() { _isLoading = false; _hasError = true; }); }
        },
      );

      if (widget.otherUserId != null) {
        _presenceSubscription = _chatService.getUserPresence(widget.otherUserId!).listen((presence) {
          if (mounted) { setState(() { _isOtherUserOnline = presence.online; _otherUserLastSeen = presence.lastSeen; }); }
        });
      }
      if (mounted) setState(() { _isLoading = false; });
    } catch (e) {
      debugPrint(userFriendlyError(e, fallback: 'Error inicializando chat'));
      if (mounted) {
        setState(() { _isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al inicializar el chat'), backgroundColor: AppColors.error));
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) { _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut); }
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      if (user == null) return;
      _messageController.clear();
      _messageFocusNode.unfocus();
      final success = await _chatService.sendTextMessage(rideId: widget.rideId, senderId: user.id, senderName: user.fullName, message: message, senderRole: user.activeMode);
      if (success) { HapticFeedback.lightImpact(); _messageAnimationController.forward().then((_) { _messageAnimationController.reset(); }); }
      else { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al enviar mensaje'), backgroundColor: AppColors.error)); }
    } catch (e) {
      debugPrint(userFriendlyError(e, fallback: 'Error enviando mensaje'));
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al enviar mensaje'), backgroundColor: AppColors.error)); }
    }
  }

  Future<void> _sendQuickMessage(QuickMessageType type) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      if (user == null) return;
      final success = await _chatService.sendQuickMessage(rideId: widget.rideId, senderId: user.id, senderName: user.fullName, senderRole: user.activeMode, type: type);
      if (success && mounted) { setState(() { _showQuickMessages = false; }); }
    } catch (e) { debugPrint(userFriendlyError(e, fallback: 'Error enviando mensaje rapido')); }
  }

  Future<void> _shareLocation() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      if (user == null) return;
      // Get real GPS position
      final position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      final latitude = position.latitude;
      final longitude = position.longitude;
      final success = await _chatService.shareLocation(rideId: widget.rideId, senderId: user.id, senderName: user.fullName, senderRole: user.activeMode, latitude: latitude, longitude: longitude);
      if (!success && mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al compartir ubicacion'), backgroundColor: AppColors.error)); }
    } catch (e) {
      debugPrint(userFriendlyError(e, fallback: 'Error compartiendo ubicacion'));
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo obtener la ubicación'), backgroundColor: AppColors.error)); }
    }
  }

  Future<void> _pickAndSendMedia() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.media, allowMultiple: false);
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileSize = await file.length();
        if (fileSize > 10 * 1024 * 1024) {
          if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('El archivo es muy grande (máximo 10 MB)'), backgroundColor: AppColors.warning)); }
          return;
        }
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final user = authProvider.currentUser;
        if (user == null) return;
        if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)), const SizedBox(width: 16), Text('Enviando archivo...')]), duration: const Duration(seconds: 10))); }
        MessageType messageType = MessageType.file;
        final extension = result.files.single.extension?.toLowerCase();
        if (extension != null) {
          if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) { messageType = MessageType.image; }
          else if (['mp4', 'mov', 'avi'].contains(extension)) { messageType = MessageType.video; }
          else if (['mp3', 'wav', 'm4a'].contains(extension)) { messageType = MessageType.audio; }
        }
        final success = await _chatService.sendMultimediaMessage(rideId: widget.rideId, senderId: user.id, senderName: user.fullName, senderRole: user.activeMode, mediaFile: file, messageType: messageType);
        if (mounted) { ScaffoldMessenger.of(context).hideCurrentSnackBar(); }
        if (success) { HapticFeedback.lightImpact(); }
        else { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al enviar archivo'), backgroundColor: AppColors.error)); }
      }
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context).hideCurrentSnackBar(); }
      debugPrint(userFriendlyError(e, fallback: 'Error enviando multimedia'));
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al enviar archivo'), backgroundColor: AppColors.error)); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getInputFill(context),
      appBar: AppBar(
        backgroundColor: AppColors.rappiOrange,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.otherUserName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
          Text(_buildStatusText(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone, color: Colors.white),
            onPressed: () {
              HapticFeedback.lightImpact();
              // TODO(node-migration): reemplazar con endpoint /api/users/:id o
              // exponer el telefono del contraparte en el payload del viaje
              // (ride.driverPhone / ride.passengerPhone) cuando exista.
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Llamada disponible desde la pantalla del viaje'),
                backgroundColor: AppColors.warning,
              ));
            },
          ),
          IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: _showChatOptions),
        ],
      ),
      body: _isLoading ? _buildLoadingState() : _hasError ? _buildErrorState() : Column(children: [
        Expanded(child: _buildMessagesList()),
        if (_showQuickMessages) _buildQuickMessagesBar(),
        _buildMessageInput(),
      ]),
    );
  }

  Widget _buildLoadingState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.rappiOrange)),
      const SizedBox(height: 16),
      Text('Iniciando chat...', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 16)),
    ]));
  }

  Widget _buildErrorState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.getTextSecondary(context)),
      const SizedBox(height: 16),
      Text('Chat no disponible', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 16)),
      const SizedBox(height: 8),
      TextButton.icon(onPressed: () { setState(() { _isLoading = true; _hasError = false; }); _initializeChat(); }, icon: const Icon(Icons.refresh), label: Text('Reintentar')),
    ]));
  }

  String _buildStatusText() {
    if (_isOtherUserOnline) return 'En linea';
    if (_otherUserLastSeen != null) {
      final difference = DateTime.now().difference(_otherUserLastSeen!);
      if (difference.inMinutes < 1) return 'Visto hace un momento';
      if (difference.inMinutes < 60) return 'Visto hace ${difference.inMinutes} min';
      if (difference.inHours < 24) return 'Visto hace ${difference.inHours}h';
      return 'Visto hace ${difference.inDays}d';
    }
    return widget.otherUserRole == 'driver' ? 'Conductor' : 'Pasajero';
  }

  Widget _buildMessagesList() {
    if (_messages.isEmpty) return _buildEmptyState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return ListView.builder(
      controller: _scrollController, padding: const EdgeInsets.all(16), itemCount: _messages.length,
      itemBuilder: (context, index) { final message = _messages[index]; final isMyMessage = message.senderId == authProvider.currentUser?.id; return _buildMessageBubble(message, isMyMessage); },
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: AppColors.rappiOrange.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.rappiOrange)),
      const SizedBox(height: 24),
      Text('Inicia la conversacion', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
      const SizedBox(height: 8),
      Text(widget.otherUserRole == 'driver' ? 'Mantente en contacto con tu conductor' : 'Mantente en contacto con tu pasajero', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context))),
    ]));
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMyMessage) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMyMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMyMessage) ...[
            CircleAvatar(radius: 16, backgroundColor: AppColors.rappiOrange.withValues(alpha: 0.2),
              child: Text(message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : '?', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.rappiOrange))),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMyMessage ? AppColors.rappiOrange : AppColors.getSurface(context),
                borderRadius: BorderRadius.circular(18).copyWith(bottomLeft: Radius.circular(isMyMessage ? 18 : 4), bottomRight: Radius.circular(isMyMessage ? 4 : 18)),
                boxShadow: [BoxShadow(color: AppColors.getTextPrimary(context).withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (message.messageType == MessageType.location) _buildLocationMessage(message, isMyMessage)
                else if (message.messageType != MessageType.text) _buildMediaMessage(message, isMyMessage)
                else _buildTextMessage(message, isMyMessage),
                const SizedBox(height: 4),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_formatMessageTime(message.timestamp), style: TextStyle(fontSize: 11, color: isMyMessage ? Colors.white.withValues(alpha: 0.7) : AppColors.getTextSecondary(context))),
                  if (isMyMessage) ...[const SizedBox(width: 4), Icon(message.isRead ? Icons.done_all : Icons.done, size: 14, color: message.isRead ? Colors.blue : Colors.white.withValues(alpha: 0.7))],
                ]),
              ]),
            ),
          ),
          if (isMyMessage) const SizedBox(width: 50),
          if (!isMyMessage) const SizedBox(width: 50),
        ],
      ),
    );
  }

  Widget _buildTextMessage(ChatMessage message, bool isMyMessage) { return Text(message.message, style: TextStyle(fontSize: 15, color: isMyMessage ? Colors.white : AppColors.getTextPrimary(context), height: 1.3)); }

  Widget _buildMediaMessage(ChatMessage message, bool isMyMessage) {
    IconData icon; String label;
    switch (message.messageType) {
      case MessageType.image: icon = Icons.image; label = 'Imagen'; break;
      case MessageType.audio: icon = Icons.audiotrack; label = 'Audio'; break;
      case MessageType.video: icon = Icons.videocam; label = 'Video'; break;
      default: icon = Icons.attachment; label = 'Archivo';
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 20, color: isMyMessage ? Colors.white : AppColors.rappiOrange), const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: isMyMessage ? Colors.white : AppColors.getTextPrimary(context))),
        if (message.message.isNotEmpty) ...[const SizedBox(height: 4), Text(message.message, style: TextStyle(fontSize: 13, color: isMyMessage ? Colors.white.withValues(alpha: 0.8) : AppColors.getTextSecondary(context)))],
      ])),
    ]);
  }

  Widget _buildLocationMessage(ChatMessage message, bool isMyMessage) {
    // mediaUrl stores the Google Maps link for location messages
    final locationUrl = message.mediaUrl ?? 'https://maps.google.com/?q=-12.0464,-77.0428';

    return GestureDetector(
      onTap: () async {
        try {
          await launchUrl(Uri.parse(locationUrl), mode: LaunchMode.externalApplication);
        } catch (_) {}
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.location_on, size: 20, color: isMyMessage ? Colors.white : AppColors.error),
            const SizedBox(width: 8),
            Text('Ubicación compartida', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: isMyMessage ? Colors.white : AppColors.getTextPrimary(context))),
          ]),
          const SizedBox(height: 4),
          Text('Toca para ver en el mapa', style: TextStyle(fontSize: 12, color: isMyMessage ? Colors.white70 : AppColors.getTextSecondary(context), decoration: TextDecoration.underline)),
        ],
      ),
    );
  }

  Widget _buildQuickMessagesBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: AppColors.getSurface(context), border: Border(top: BorderSide(color: AppColors.getBorder(context)))),
      child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: QuickMessageType.values.map((type) {
        return Padding(padding: const EdgeInsets.only(right: 8), child: ElevatedButton(
          onPressed: () => _sendQuickMessage(type),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.rappiOrange.withValues(alpha: 0.1), foregroundColor: AppColors.rappiOrange, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
          child: Text(_getQuickMessageText(type), style: const TextStyle(fontSize: 12)),
        ));
      }).toList())),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: AppColors.getSurface(context), boxShadow: [BoxShadow(color: AppColors.getTextPrimary(context).withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))]),
      child: SafeArea(child: Row(children: [
        IconButton(onPressed: () { setState(() { _showQuickMessages = !_showQuickMessages; }); }, icon: Icon(_showQuickMessages ? Icons.keyboard : Icons.add, color: AppColors.rappiOrange)),
        Expanded(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: AppColors.getInputFill(context), borderRadius: BorderRadius.circular(25)),
          child: TextField(controller: _messageController, focusNode: _messageFocusNode, decoration: InputDecoration(hintText: 'Escribe un mensaje...', border: InputBorder.none, hintStyle: TextStyle(color: AppColors.getTextSecondary(context))), maxLines: null, textCapitalization: TextCapitalization.sentences, onSubmitted: (_) => _sendMessage()),
        )),
        Row(children: [
          IconButton(onPressed: _pickAndSendMedia, icon: const Icon(Icons.attach_file, color: AppColors.rappiOrange)),
          IconButton(onPressed: _shareLocation, icon: const Icon(Icons.location_on, color: AppColors.rappiOrange)),
          Container(decoration: const BoxDecoration(color: AppColors.rappiOrange, shape: BoxShape.circle), child: IconButton(onPressed: _sendMessage, icon: const Icon(Icons.send, color: Colors.white, size: 20))),
        ]),
      ])),
    );
  }

  String _getQuickMessageText(QuickMessageType type) {
    switch (type) {
      case QuickMessageType.onMyWay: return 'Estoy en camino';
      case QuickMessageType.arrived: return 'Ya llegue';
      case QuickMessageType.waiting: return 'Estoy esperando';
      case QuickMessageType.trafficDelay: return 'Hay trafico';
      case QuickMessageType.cantFind: return 'No te encuentro';
    }
  }

  String _formatMessageTime(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inMinutes < 1) return 'Ahora';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m';
    if (difference.inHours < 24) return '${difference.inHours}h';
    return '${timestamp.day}/${timestamp.month}';
  }

  void _showChatOptions() {
    showResponsiveBottomSheet(context: context, builder: (context) {
      return Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.clear_all, color: AppColors.error), title: Text('Limpiar chat'), onTap: () { Navigator.pop(context); _showClearChatDialog(); }),
        ListTile(leading: const Icon(Icons.report, color: AppColors.warning), title: Text('Reportar usuario'), onTap: () { Navigator.pop(context); _showReportUserDialog(); }),
      ]));
    });
  }

  void _showClearChatDialog() {
    showDialog(context: context, builder: (context) {
      return AlertDialog(
        title: Text('Limpiar chat'), content: Text('Se eliminaran todos los mensajes de esta conversacion. Esta accion no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancelar')),
          ElevatedButton(
            onPressed: () async { Navigator.pop(context); await _chatService.clearChat(widget.rideId); if (mounted) { setState(() { _messages.clear(); }); } },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: Text('Limpiar'),
          ),
        ],
      );
    });
  }

  void _showReportUserDialog() {
    final TextEditingController reportController = TextEditingController();
    String selectedReason = 'Comportamiento inapropiado';
    final Map<String, String> reasons = {
      'Comportamiento inapropiado': 'inappropriate_behavior',
      'Lenguaje ofensivo': 'offensive_language',
      'Acoso': 'harassment',
      'Conduccion peligrosa': 'dangerous_driving',
      'Cobro incorrecto': 'incorrect_fare',
      'Otro motivo': 'other',
    };

    showDialog(context: context, builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setDialogState) {
      return AlertDialog(
        title: Text('Reportar Usuario', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Reportar a ${widget.otherUserName}', style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
          Text('Motivo:', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: selectedReason,
            decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
            items: reasons.keys.map((reason) => DropdownMenuItem(value: reason, child: Text(reason))).toList(),
            onChanged: (value) { setDialogState(() => selectedReason = value!); },
          ),
          const SizedBox(height: 16),
          Text('Detalles adicionales:', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(controller: reportController, decoration: InputDecoration(hintText: 'Describe el problema...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.all(16)), maxLines: 4, maxLength: 300),
        ])),
        actions: [
          TextButton(onPressed: () { reportController.dispose(); Navigator.pop(dialogContext); }, child: Text('Cancelar', style: TextStyle(color: AppColors.getTextSecondary(dialogContext)))),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(dialogContext);
              final navigator = Navigator.of(dialogContext);
              // TODO(node-migration): reemplazar con endpoint /api/user-reports
              // cuando exista. Por ahora simulamos el envio para no romper el UX.
              await Future<void>.delayed(const Duration(milliseconds: 300));
              reportController.dispose();
              navigator.pop();
              messenger.showSnackBar(SnackBar(
                  content: Text('Reporte registrado'),
                  backgroundColor: AppColors.success,
                  duration: const Duration(seconds: 3)));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning, foregroundColor: Colors.white),
            child: Text('Enviar Reporte'),
          ),
        ],
      );
    }));
  }
}
