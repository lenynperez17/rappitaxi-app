import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/l10n/driver_strings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';

class DriverNotificationsScreen extends StatefulWidget {
  const DriverNotificationsScreen({super.key});

  @override
  State<DriverNotificationsScreen> createState() =>
      _DriverNotificationsScreenState();
}

class _DriverNotificationsScreenState extends State<DriverNotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    final ds = DriverStrings(Localizations.localeOf(context).languageCode);
    final auth = context.watch<AuthProvider>();
    final userId = auth.currentUser?.id;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.menu,
                        size: 28, color: AppColors.getTextPrimary(context)),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(ds.notifications,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 28),
                ],
              ),
            ),

            // Notifications list — usamos NotificationProvider (backend Node + SSE)
            // en vez de Firestore.
            Expanded(
              child: userId == null
                  ? Center(child: Text(ds.loginToSeeNotifications))
                  : Consumer<NotificationProvider>(
                      builder: (context, np, _) {
                        if (np.isLoading && np.notifications.isEmpty) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final items = np.notifications;

                        if (items.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.notifications_none,
                                    size: 64, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                Text(ds.noNotifications,
                                    style: TextStyle(
                                        color: Colors.grey[500], fontSize: 16)),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final n = items[index];
                            final message = n.body.isNotEmpty ? n.body : n.title;
                            final createdAt = n.timestamp;
                            // Ronda 234 fix: formato 12h correcto (antes:
                            // "0:30 a.m." era en realidad 12:30 a.m.,
                            // "13:30 p.m." era 1:30 p.m.).
                            final h24 = createdAt.hour;
                            final h12 = h24 == 0 ? 12 : (h24 > 12 ? h24 - 12 : h24);
                            final dateStr =
                                '$h12:${createdAt.minute.toString().padLeft(2, '0')} ${h24 >= 12 ? 'p.m.' : 'a.m.'}';

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.getSurface(context),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: AppColors.getBorder(context)
                                        .withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(message,
                                      style: TextStyle(
                                          fontSize: 15,
                                          color:
                                              AppColors.getTextPrimary(context),
                                          height: 1.4)),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Text(dateStr,
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: AppColors.getTextSecondary(
                                                context))),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
