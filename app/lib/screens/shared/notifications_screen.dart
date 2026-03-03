import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../core/design/design_system.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_loading_state.dart';
import '../../core/widgets/rt_button.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../utils/firestore_error_handler.dart';

/// Pantalla de notificaciones completa conectada a Firebase Firestore
/// Implementacion real con Firebase, sin mocks
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser?.uid;

    if (currentUserId == null) {
      return Scaffold(
        appBar: const RtAppBar(
          title: 'Notificaciones',
          variant: RtAppBarVariant.solid,
        ),
        body: Center(
          child: Text(
            'Debes iniciar sesión para ver las notificaciones',
            style: RtTypo.bodyLarge.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: RtAppBar(
        title: 'Notificaciones',
        variant: RtAppBarVariant.solid,
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
            return const Padding(
              padding: EdgeInsets.all(RtSpacing.base),
              child: RtLoadingState.list(),
            );
          }

          // Error
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: RtColors.error),
                  const SizedBox(height: RtSpacing.base),
                  Padding(
                    padding: RtSpacing.screenH,
                    child: Text(
                      'Error al cargar notificaciones:\n${snapshot.error}',
                      style: RtTypo.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: RtSpacing.base),
                  RtButton(
                    label: 'Reintentar',
                    onPressed: () => setState(() {}),
                    isFullWidth: false,
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
                  Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(
                      color: RtColors.neutral100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications_off,
                      size: 48,
                      color: RtColors.neutral400,
                    ),
                  ),
                  const SizedBox(height: RtSpacing.xl),
                  Text(
                    'No tienes notificaciones',
                    style: RtTypo.headingSmall.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data!.docs;

          return ListView.builder(
            padding: RtSpacing.paddingBase,
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notificationDoc = notifications[index];
              final notificationData =
                  notificationDoc.data() as Map<String, dynamic>;

              return _buildNotificationCard(
                notificationDoc.id,
                notificationData,
              );
            },
          );
        },
      ),
    );
  }

  /// Construir tarjeta de notificación individual
  Widget _buildNotificationCard(
      String notificationId, Map<String, dynamic> data) {
    final title = data['title'] ?? 'Notificación';
    final body = data['body'] ?? '';
    final isRead = data['isRead'] ?? false;
    final type = data['type'] ?? 'info';
    final createdAt = data['createdAt'] as Timestamp?;
    final payload = data['payload'] as String?;

    return Dismissible(
      key: Key(notificationId),
      background: Container(
        decoration: BoxDecoration(
          color: RtColors.success,
          borderRadius: RtRadius.borderMd,
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: RtSpacing.lg),
        child: const Icon(Icons.done, color: RtColors.white),
      ),
      secondaryBackground: Container(
        decoration: BoxDecoration(
          color: RtColors.error,
          borderRadius: RtRadius.borderMd,
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: RtSpacing.lg),
        child: const Icon(Icons.delete, color: RtColors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Marcar como leída
          await _markAsRead(notificationId);
          return false;
        } else {
          // Eliminar
          return await _confirmDelete(context);
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          _deleteNotification(notificationId);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: RtSpacing.md),
        decoration: BoxDecoration(
          color: isRead
              ? Theme.of(context).colorScheme.surface
              : RtColors.infoLight,
          borderRadius: RtRadius.borderMd,
          boxShadow: RtShadow.soft(),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: RtRadius.borderMd,
          child: InkWell(
            borderRadius: RtRadius.borderMd,
            onTap: () =>
                _handleNotificationTap(notificationId, payload, isRead),
            child: Padding(
              padding: RtSpacing.paddingBase,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _getNotificationIcon(type, isRead),
                  const SizedBox(width: RtSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: RtTypo.titleMedium.copyWith(
                            fontWeight:
                                isRead ? FontWeight.normal : FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (body.isNotEmpty) ...[
                          const SizedBox(height: RtSpacing.xs),
                          Text(
                            body,
                            style: RtTypo.bodySmall.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (createdAt != null) ...[
                          const SizedBox(height: RtSpacing.xs),
                          Text(
                            _formatTimestamp(createdAt),
                            style: RtTypo.labelSmall.copyWith(
                              color: RtColors.neutral400,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!isRead) ...[
                    const SizedBox(width: RtSpacing.sm),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: RtColors.info,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
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
        iconColor = RtColors.brand;
        break;
      case 'payment':
        iconData = Icons.account_balance_wallet;
        iconColor = RtColors.success;
        break;
      case 'emergency':
        iconData = Icons.warning;
        iconColor = RtColors.error;
        break;
      case 'promotion':
        iconData = Icons.local_offer;
        iconColor = RtColors.warning;
        break;
      case 'system':
        iconData = Icons.info;
        iconColor = RtColors.info;
        break;
      default:
        iconData = Icons.notifications;
        iconColor = RtColors.neutral500;
    }

    return CircleAvatar(
      backgroundColor:
          isRead ? iconColor.withValues(alpha: 0.2) : iconColor,
      child: Icon(
        iconData,
        color: isRead ? iconColor : RtColors.white,
        size: RtIconSize.sm,
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
    // Marcar como leída si no lo esta
    if (!isRead) {
      await _markAsRead(notificationId);
    }

    // Navegar según el payload
    if (payload != null && payload.isNotEmpty) {
      if (payload.startsWith('ride:')) {
        final rideId = payload.substring(5);
        if (!mounted) return;
        Navigator.pushNamed(
          context,
          '/shared/trip-details',
          arguments: {'rideId': rideId},
        );
      } else if (payload == 'driver_earnings') {
        if (!mounted) return;
        Navigator.pushNamed(context, '/driver/earnings-details');
      } else if (payload == 'passenger_promotions') {
        if (!mounted) return;
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
      debugPrint('Error marcando notificación como leída: $e');
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
        RtSnackbar.show(
          context,
          message: 'Todas las notificaciones marcadas como leídas',
          type: RtSnackbarType.success,
        );
      }
    } catch (e) {
      debugPrint('Error marcando todas como leídas: $e');
      if (mounted) {
        RtSnackbar.show(
          context,
          message: FirestoreErrorHandler.getSpanishMessage(e),
          type: RtSnackbarType.error,
        );
      }
    }
  }

  /// Confirmar eliminacion
  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: RtRadius.borderLg,
            ),
            title: Text(
              'Eliminar notificación',
              style: RtTypo.headingSmall,
            ),
            content: Text(
              'Estás seguro de que quieres eliminar esta notificación?',
              style: RtTypo.bodyMedium,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: RtColors.error,
                  foregroundColor: RtColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: RtRadius.borderSm,
                  ),
                ),
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
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .delete();
      if (mounted) {
        RtSnackbar.show(
          context,
          message: 'Notificación eliminada',
          type: RtSnackbarType.info,
        );
      }
    } catch (e) {
      debugPrint('Error eliminando notificación: $e');
    }
  }

  /// Eliminar todas las notificaciones
  Future<void> _deleteAllNotifications(String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: RtRadius.borderLg,
        ),
        title: Text(
          'Eliminar todas las notificaciones',
          style: RtTypo.headingSmall,
        ),
        content: Text(
          'Estás seguro? Esta accion no se puede deshacer.',
          style: RtTypo.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: RtColors.error,
              foregroundColor: RtColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: RtRadius.borderSm,
              ),
            ),
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
        RtSnackbar.show(
          context,
          message: 'Todas las notificaciones eliminadas',
          type: RtSnackbarType.success,
        );
      }
    } catch (e) {
      debugPrint('Error eliminando todas las notificaciones: $e');
      if (mounted) {
        RtSnackbar.show(
          context,
          message: FirestoreErrorHandler.getSpanishMessage(e),
          type: RtSnackbarType.error,
        );
      }
    }
  }
}
