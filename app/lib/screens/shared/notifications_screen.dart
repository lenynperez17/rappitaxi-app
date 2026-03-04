// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/extensions/theme_extensions.dart';

/// Pantalla de notificaciones completa conectada a Firebase Firestore
/// ✅ IMPLEMENTACIÓN REAL CON FIREBASE - SIN MOCKS
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser?.uid;

    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notificaciones'),
          backgroundColor: AppColors.rappiWhite,
        ),
        body: const Center(
          child: Text('Debes iniciar sesión para ver las notificaciones'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          'Notificaciones',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.rappiWhite,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        actions: [
          // Marcar todas como leídas
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Marcar todas como leídas',
            onPressed: () => _markAllAsRead(currentUserId),
          ),
          // Eliminar todas
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Eliminar todas',
            onPressed: () => _deleteAllNotifications(currentUserId),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('notifications')
            .where('userId', isEqualTo: currentUserId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // Cargando
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: ModernTheme.error),
                  const SizedBox(height: 16),
                  Text('Error al cargar notificaciones:\n${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          // Sin notificaciones
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off, size: 64, color: context.secondaryText.withOpacity(0.4)),
                  const SizedBox(height: 16),
                  Text(
                    'No tienes notificaciones',
                    style: TextStyle(fontSize: 18, color: context.secondaryText),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data!.docs;

          // Agrupar notificaciones por: Hoy, Ayer, Anteriores
          final now = DateTime.now();
          final todayStart = DateTime(now.year, now.month, now.day);
          final yesterdayStart = todayStart.subtract(const Duration(days: 1));

          final todayDocs = notifications.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final ts = data['createdAt'] as Timestamp?;
            if (ts == null) return false;
            return ts.toDate().isAfter(todayStart);
          }).toList();

          final yesterdayDocs = notifications.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final ts = data['createdAt'] as Timestamp?;
            if (ts == null) return false;
            final date = ts.toDate();
            return date.isAfter(yesterdayStart) && !date.isAfter(todayStart);
          }).toList();

          final olderDocs = notifications.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final ts = data['createdAt'] as Timestamp?;
            if (ts == null) return true;
            return !ts.toDate().isAfter(yesterdayStart);
          }).toList();

          return CustomScrollView(
            slivers: [
              if (todayDocs.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _buildGroupHeader('Hoy'),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final doc = todayDocs[index];
                      return _buildNotificationCard(
                          doc.id, doc.data() as Map<String, dynamic>);
                    },
                    childCount: todayDocs.length,
                  ),
                ),
              ],
              if (yesterdayDocs.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _buildGroupHeader('Ayer'),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final doc = yesterdayDocs[index];
                      return _buildNotificationCard(
                          doc.id, doc.data() as Map<String, dynamic>);
                    },
                    childCount: yesterdayDocs.length,
                  ),
                ),
              ],
              if (olderDocs.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _buildGroupHeader('Anteriores'),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final doc = olderDocs[index];
                      return _buildNotificationCard(
                          doc.id, doc.data() as Map<String, dynamic>);
                    },
                    childCount: olderDocs.length,
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          );
        },
      ),
    );
  }

  // Header de grupo con texto uppercase en gris
  Widget _buildGroupHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: context.secondaryText,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  /// Construir tarjeta de notificación individual
  Widget _buildNotificationCard(String notificationId, Map<String, dynamic> data) {
    final title = data['title'] ?? 'Notificación';
    final body = data['body'] ?? '';
    final isRead = data['isRead'] ?? false;
    final type = data['type'] ?? 'info';
    final createdAt = data['createdAt'] as Timestamp?;
    final payload = data['payload'] as String?;

    return Dismissible(
      key: Key(notificationId),
      background: Container(
        color: ModernTheme.success,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Icon(Icons.done, color: Theme.of(context).colorScheme.onPrimary),
      ),
      secondaryBackground: Container(
        color: ModernTheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onPrimary),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _markAsRead(notificationId);
          return false;
        } else {
          return await _confirmDelete(context);
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          _deleteNotification(notificationId);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: isRead
              ? Theme.of(context).colorScheme.surface
              : ModernTheme.info.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          // Borde izquierdo naranja para no leídas
          border: isRead
              ? null
              : Border(
                  left: BorderSide(
                    color: AppColors.rappiOrange,
                    width: 4,
                  ),
                ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: SizedBox(
            width: 40,
            height: 40,
            child: _getNotificationIcon(type, isRead),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (body.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(color: AppColors.textSecondary),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (createdAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  _formatTimestamp(createdAt),
                  style: TextStyle(fontSize: 12, color: context.secondaryText),
                ),
              ],
            ],
          ),
          trailing: !isRead
              ? Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.rappiOrange,
                    shape: BoxShape.circle,
                  ),
                )
              : null,
          onTap: () => _handleNotificationTap(notificationId, payload, isRead),
        ),
      ),
    );
  }

  /// Obtener icono según tipo de notificación
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
        iconColor = ModernTheme.success;
        break;
      case 'emergency':
        iconData = Icons.warning;
        iconColor = ModernTheme.error;
        break;
      case 'promotion':
        iconData = Icons.local_offer;
        iconColor = ModernTheme.warning;
        break;
      case 'system':
        iconData = Icons.info;
        iconColor = ModernTheme.info;
        break;
      default:
        iconData = Icons.notifications;
        iconColor = context.secondaryText;
    }

    return CircleAvatar(
      radius: 20,
      backgroundColor: isRead ? iconColor.withOpacity(0.15) : iconColor,
      child: Icon(
        iconData,
        color: isRead ? iconColor : Theme.of(context).colorScheme.onPrimary,
        size: 20,
      ),
    );
  }

  /// Formatear timestamp a texto legible
  String _formatTimestamp(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Ahora';
    } else if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays}d';
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    }
  }

  /// Manejar tap en notificación
  Future<void> _handleNotificationTap(
    String notificationId,
    String? payload,
    bool isRead,
  ) async {
    // Marcar como leída si no lo está
    if (!isRead) {
      await _markAsRead(notificationId);
    }

    // Navegar según el payload
    if (payload != null && payload.isNotEmpty) {
      if (payload.startsWith('ride:')) {
        final rideId = payload.substring(5);
        Navigator.pushNamed(
          context,
          '/shared/trip-details',
          arguments: {'rideId': rideId},
        );
      } else if (payload == 'driver_earnings') {
        Navigator.pushNamed(context, '/driver/earnings');
      } else if (payload == 'passenger_promotions') {
        Navigator.pushNamed(context, '/passenger/promotions');
      }
    }
  }

  /// Marcar notificación como leída
  Future<void> _markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint('❌ Error marcando notificación como leída: $e');
    }
  }

  /// Marcar todas las notificaciones como leídas
  Future<void> _markAllAsRead(String userId) async {
    try {
      final batch = _firestore.batch();
      final unreadNotifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in unreadNotifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Todas las notificaciones marcadas como leídas'),
            backgroundColor: ModernTheme.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error marcando todas como leídas: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  /// Confirmar eliminación
  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Eliminar notificación'),
            content: const Text('¿Estás seguro de que quieres eliminar esta notificación?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: ModernTheme.error),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Eliminar notificación individual
  Future<void> _deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notificación eliminada')),
        );
      }
    } catch (e) {
      debugPrint('❌ Error eliminando notificación: $e');
    }
  }

  /// Eliminar todas las notificaciones
  Future<void> _deleteAllNotifications(String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar todas las notificaciones'),
        content: const Text('¿Estás seguro? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ModernTheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar todas'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final batch = _firestore.batch();
      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in notifications.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Todas las notificaciones eliminadas'),
            backgroundColor: ModernTheme.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error eliminando todas las notificaciones: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}