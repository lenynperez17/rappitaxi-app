// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api, use_build_context_synchronously
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/rapi_api_client.dart';
import '../../services/rapi_sse_client.dart';

/// Notifications screen — lee del backend Node via RapiApiClient y se
/// refresca en tiempo real con el stream SSE de notificaciones.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  final RapiApiClient _api = RapiApiClient.instance;
  late final AnimationController _listController;
  bool _hasAnimated = false;

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _notifications = [];

  StreamSubscription<Map<String, dynamic>>? _sseSub;

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadNotifications();
    // Suscribirse al stream SSE global para refresh en tiempo real.
    _sseSub = RapiSseClient.instance.notifications.listen((_) {
      _loadNotifications();
    });
    RapiSseClient.instance.start();
  }

  Future<void> _loadNotifications() async {
    try {
      final data = await _api.listNotifications(limit: 100);
      final raw = (data['items'] as List?) ?? (data['notifications'] as List?) ?? const [];
      final items = raw
          .whereType<Map>()
          .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
      if (!mounted) return;
      setState(() {
        _notifications = items;
        _isLoading = false;
        _error = null;
      });
      _triggerListAnimation();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _sseSub?.cancel();
    _listController.dispose();
    super.dispose();
  }

  void _triggerListAnimation() {
    if (!_hasAnimated) {
      _hasAnimated = true;
      _listController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Notificaciones'),
          backgroundColor: AppColors.getSurface(context),
        ),
        body: Center(child: Text('Inicia sesion para ver tus notificaciones')),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.getInputFill(context),
      appBar: AppBar(
        title: Text('Notificaciones',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(context))),
        backgroundColor: AppColors.getSurface(context),
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.getTextPrimary(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Marcar todas como leidas',
            onPressed: _markAllAsRead,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Eliminar todas',
            onPressed: _deleteAllNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _notifications.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadNotifications,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final n = _notifications[index];
                          final double delay = (index * 0.1).clamp(0.0, 0.6);
                          final double end = (delay + 0.4).clamp(0.0, 1.0);
                          final animation = Tween<double>(begin: 0.0, end: 1.0)
                              .animate(CurvedAnimation(
                            parent: _listController,
                            curve: Interval(delay, end, curve: Curves.easeOutCubic),
                          ));
                          return AnimatedBuilder(
                            animation: animation,
                            builder: (context, child) => Transform.translate(
                              offset: Offset(0, 30 * (1 - animation.value)),
                              child: Opacity(opacity: animation.value, child: child),
                            ),
                            child: _buildNotificationCard(n),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error al cargar notificaciones: $_error'),
          const SizedBox(height: 8),
          ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadNotifications();
              },
              child: Text('Reintentar')),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off,
              size: 64, color: AppColors.getTextSecondary(context)),
          const SizedBox(height: 16),
          Text('No tienes notificaciones',
              style: TextStyle(
                  fontSize: 18, color: AppColors.getTextSecondary(context))),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> data) {
    final id = (data['id'] ?? '').toString();
    final title = data['title'] ?? 'Notificación';
    final body = data['body'] ?? '';
    final isRead = (data['isRead'] ?? data['read'] ?? false) == true;
    final type = (data['type'] ?? 'info').toString();
    final createdAtRaw = data['createdAt'];
    final DateTime? createdAt = createdAtRaw is String
        ? DateTime.tryParse(createdAtRaw)
        : (createdAtRaw is num
            ? DateTime.fromMillisecondsSinceEpoch(createdAtRaw.toInt())
            : null);
    final payload = data['payload']?.toString();

    return Dismissible(
      key: Key(id),
      background: Container(
        color: Colors.green,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.done, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _markAsRead(id);
          return false;
        } else {
          return await _confirmDelete(context);
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          _deleteNotification(id);
        }
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: isRead
            ? AppColors.getSurface(context)
            : AppColors.rappiOrange.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: _getNotificationIcon(type, isRead),
          title: Text(title,
              style: TextStyle(
                  fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                  color: AppColors.getTextPrimary(context))),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (body.toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(body.toString(),
                    style: TextStyle(color: AppColors.getTextSecondary(context))),
              ],
              if (createdAt != null) ...[
                const SizedBox(height: 4),
                Text(_formatDateTime(createdAt),
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.getTextSecondary(context))),
              ],
            ],
          ),
          trailing: !isRead
              ? Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                      color: Colors.blue, shape: BoxShape.circle))
              : null,
          onTap: () => _handleNotificationTap(id, payload, isRead),
        ),
      ),
    );
  }

  Widget _getNotificationIcon(String type, bool isRead) {
    IconData iconData;
    Color iconColor;
    switch (type) {
      case 'ride':
        iconData = Icons.local_taxi;
        iconColor = AppColors.rappiOrange;
        break;
      case 'payment':
        iconData = Icons.account_balance_wallet;
        iconColor = Colors.green;
        break;
      case 'emergency':
        iconData = Icons.warning;
        iconColor = Colors.red;
        break;
      case 'promotion':
        iconData = Icons.local_offer;
        iconColor = Colors.orange;
        break;
      case 'system':
        iconData = Icons.info;
        iconColor = Colors.purple;
        break;
      default:
        iconData = Icons.notifications;
        iconColor = AppColors.getTextSecondary(context);
    }
    return CircleAvatar(
      backgroundColor:
          isRead ? iconColor.withValues(alpha: 0.2) : iconColor,
      child: Icon(iconData, color: isRead ? iconColor : Colors.white, size: 20),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 1) return 'Ahora';
    if (difference.inMinutes < 60) return 'Hace ${difference.inMinutes} min';
    if (difference.inHours < 24) return 'Hace ${difference.inHours}h';
    if (difference.inDays < 7) return 'Hace ${difference.inDays}d';
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }

  Future<void> _handleNotificationTap(
      String notificationId, String? payload, bool isRead) async {
    if (!isRead) await _markAsRead(notificationId);
    if (payload != null && payload.isNotEmpty) {
      if (payload.startsWith('ride:')) {
        Navigator.pushNamed(context, '/shared/trip-details',
            arguments: {'rideId': payload.substring(5)});
      } else if (payload == 'driver_earnings') {
        Navigator.pushNamed(context, '/driver/earnings-details');
      } else if (payload == 'passenger_promotions') {
        Navigator.pushNamed(context, '/passenger/promotions');
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _api.markNotificationRead(notificationId);
      if (!mounted) return;
      setState(() {
        final idx =
            _notifications.indexWhere((n) => (n['id'] ?? '').toString() == notificationId);
        if (idx != -1) {
          _notifications[idx] = {..._notifications[idx], 'isRead': true};
        }
      });
    } catch (e) {
      debugPrint('Error marcando notificacion como leida: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await _api.markAllNotificationsRead();
      if (!mounted) return;
      setState(() {
        _notifications =
            _notifications.map((n) => {...n, 'isRead': true}).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Todas las notificaciones marcadas como leidas'),
          backgroundColor: Colors.green));
    } catch (e) {
      debugPrint('Error marcando todas como leidas: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Eliminar notificacion'),
            content:
                Text('Estas seguro de que deseas eliminar esta notificacion?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Cancelar')),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('Eliminar')),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteNotification(String notificationId) async {
    // TODO(node-migration): reemplazar con endpoint DELETE /api/notifications/:id
    // cuando exista. Por ahora solo removemos localmente.
    if (!mounted) return;
    setState(() {
      _notifications
          .removeWhere((n) => (n['id'] ?? '').toString() == notificationId);
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Notificación eliminada')));
  }

  Future<void> _deleteAllNotifications() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar todas'),
        content: Text(
            'Se eliminaran todas tus notificaciones. Esta accion no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: Text('Eliminar todas')),
        ],
      ),
    );
    if (confirmed != true) return;

    // TODO(node-migration): reemplazar con endpoint DELETE /api/notifications
    // cuando exista. Por ahora solo limpiamos localmente.
    if (!mounted) return;
    setState(() => _notifications.clear());
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Todas las notificaciones eliminadas'),
        backgroundColor: Colors.green));
  }
}
