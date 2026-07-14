import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive_bottom_sheet.dart';
import '../../core/l10n/driver_strings.dart';
import '../../services/rapi_api_client.dart';

class DriverAchievementsScreen extends StatefulWidget {
  const DriverAchievementsScreen({super.key});

  @override
  State<DriverAchievementsScreen> createState() => _DriverAchievementsScreenState();
}

class _DriverAchievementsScreenState extends State<DriverAchievementsScreen> {
  List<Map<String, dynamic>> _achievements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    // TODO(node-migration): reemplazar con endpoint /api/drivers/me/bonifications
    // cuando exista. Por ahora derivamos logros semanales a partir del historial
    // de viajes que ya expone /api/rides?role=driver.
    try {
      await _generateFromTrips();
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateFromTrips() async {
    try {
      final api = RapiApiClient.instance;
      // Traer viajes completados del driver (una sola página razonable).
      final resp = await api.listRides(
        role: 'driver',
        status: 'completed',
        pageSize: 200,
      );
      final rawList = (resp['rides'] as List?) ?? const [];

      // Convertir el timestamp de completado a DateTime.
      final completedAts = <DateTime>[];
      for (final r in rawList) {
        if (r is! Map) continue;
        final ts = r['completedAt'] ?? r['completed_at'];
        if (ts is String) {
          final dt = DateTime.tryParse(ts);
          if (dt != null) completedAts.add(dt);
        }
      }

      final now = DateTime.now();
      final List<Map<String, dynamic>> generated = [];

      for (int i = 0; i < 8; i++) {
        final weekStart = now.subtract(Duration(days: 7 * i + now.weekday - 1));
        final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
        final end = start.add(const Duration(days: 7));

        final tripCount = completedAts
            .where((dt) => !dt.isBefore(start) && dt.isBefore(end))
            .length;
        if (tripCount == 0 && i > 0) continue;

        double bonus = (tripCount * 1.5).roundToDouble();
        if (bonus < 10) bonus = 10 + (i * 3).toDouble();

        generated.add({
          'startDate': start,
          'endDate': end.subtract(const Duration(days: 1)),
          'amount': bonus,
          'status': tripCount >= 5 ? 'completed' : 'expired',
          'tripCount': tripCount,
          'requiredTrips': 5,
        });
      }

      if (mounted) {
        setState(() {
          _achievements = generated;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ds = DriverStrings(Localizations.localeOf(context).languageCode);
    return Scaffold(
      backgroundColor: AppColors.getSurface(context),
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
                    child: Icon(Icons.chevron_left, size: 30, color: AppColors.getTextPrimary(context)),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(ds.achievements, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 30),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _achievements.isEmpty
                      ? _buildEmptyState(ds)
                      : _buildAchievementsList(ds),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(DriverStrings ds) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emoji_events, size: 64, color: AppColors.getTextSecondary(context).withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            ds.noAchievementsYet,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.getTextSecondary(context)),
          ),
          const SizedBox(height: 8),
          Text(
            ds.completeTripsToUnlock,
            style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsList(DriverStrings ds) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _achievements.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.getBorder(context)),
      itemBuilder: (context, index) {
        final achievement = _achievements[index];
        final status = achievement['status'] ?? 'expired';
        final isCompleted = status == 'completed';
        final amount = (achievement['amount'] ?? 0).toDouble();
        final startDate = achievement['startDate'] as DateTime?;
        final endDate = achievement['endDate'] as DateTime?;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isCompleted
                  ? AppColors.rappiRed.withValues(alpha: 0.15)
                  : const Color(0xFFFFCDD2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted ? Icons.check : Icons.close,
              color: isCompleted ? AppColors.rappiRed : Colors.red,
              size: 26,
            ),
          ),
          title: Text(
            _formatDateRange(startDate, endDate, isCompleted, ds),
            style: TextStyle(
              fontSize: 14,
              color: AppColors.getTextSecondary(context),
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              ds.bonusAmount(amount.toInt()),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(context),
              ),
            ),
          ),
          trailing: Icon(Icons.chevron_right, color: AppColors.getTextSecondary(context)),
          onTap: () => _showAchievementDetail(achievement, ds),
        );
      },
    );
  }

  String _formatDateRange(DateTime? start, DateTime? end, bool isCompleted, DriverStrings ds) {
    if (start == null) return isCompleted ? ds.completed : ds.expired;

    final months = ds.monthAbbreviations;
    final prefix = isCompleted ? ds.completed : ds.expired;

    if (end != null) {
      return '$prefix • ${months[start.month - 1]} ${start.day} – ${end.day}';
    }
    return '$prefix • ${months[start.month - 1]} ${start.day}';
  }

  void _showAchievementDetail(Map<String, dynamic> achievement, DriverStrings ds) {
    final status = achievement['status'] ?? 'expired';
    final isCompleted = status == 'completed';
    final amount = (achievement['amount'] ?? 0).toDouble();
    final tripCount = achievement['tripCount'] ?? 0;
    final requiredTrips = achievement['requiredTrips'] ?? 5;

    showResponsiveBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppColors.rappiRed.withValues(alpha: 0.15)
                      : const Color(0xFFFFCDD2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCompleted ? Icons.check : Icons.close,
                  color: isCompleted ? AppColors.rappiRed : Colors.red,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isCompleted ? ds.bonusObtained : ds.bonusExpired,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context)),
              ),
              const SizedBox(height: 8),
              Text(
                ds.bonusAmount(amount.toInt()),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.rappiRed),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.getBackground(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(ds.tripsCompleted, style: TextStyle(color: AppColors.getTextSecondary(context))),
                        Text('$tripCount / $requiredTrips', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: requiredTrips > 0 ? (tripCount / requiredTrips).clamp(0.0, 1.0) : 0,
                        backgroundColor: AppColors.getBorder(context),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isCompleted ? AppColors.rappiRed : Colors.red.shade300,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isCompleted ? ds.completedRequiredTrips : ds.didNotCompleteTrips,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
    );
  }
}

