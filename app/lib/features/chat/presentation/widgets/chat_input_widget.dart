import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class ChatInputWidget extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSendMessage;
  final VoidCallback onSendImage;
  final VoidCallback onSendLocation;

  const ChatInputWidget({
    super.key,
    required this.controller,
    required this.onSendMessage,
    required this.onSendImage,
    required this.onSendLocation,
  });

  @override
  State<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<ChatInputWidget> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Botones de acción adicionales
            if (!_hasText) ...[
              IconButton(
                onPressed: widget.onSendImage,
                icon: const Icon(Icons.camera_alt),
                style: IconButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: widget.onSendLocation,
                icon: const Icon(Icons.my_location),
                style: IconButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                ),
              ),
              const SizedBox(width: 8),
            ],
            
            // Campo de texto
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: widget.controller,
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: 'Escribe un mensaje...',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    hintStyle: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Botón de enviar
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: _hasText
                  ? FloatingActionButton.small(
                      onPressed: _sendMessage,
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      child: const Icon(Icons.send),
                    )
                  : FloatingActionButton.small(
                      onPressed: () => _showAttachmentOptions(context),
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                      foregroundColor: AppTheme.primaryColor,
                      child: const Icon(Icons.add),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage() {
    if (widget.controller.text.trim().isNotEmpty) {
      widget.onSendMessage();
    }
  }

  void _showAttachmentOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle visual
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                Text(
                  'Enviar contenido',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                
                const SizedBox(height: 20),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildAttachmentOption(
                      context,
                      'Cámara',
                      Icons.camera_alt,
                      AppTheme.primaryColor,
                      () {
                        Navigator.pop(context);
                        widget.onSendImage();
                      },
                    ),
                    _buildAttachmentOption(
                      context,
                      'Ubicación',
                      Icons.my_location,
                      AppTheme.infoColor,
                      () {
                        Navigator.pop(context);
                        widget.onSendLocation();
                      },
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentOption(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: color,
              size: 32,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}