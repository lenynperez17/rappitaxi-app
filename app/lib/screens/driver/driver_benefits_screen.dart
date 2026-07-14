import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/l10n/driver_strings.dart';
import '../../services/rapi_api_client.dart';
import 'driver_benefit_detail_screen.dart';

class DriverBenefitsScreen extends StatefulWidget {
  const DriverBenefitsScreen({super.key});

  @override
  State<DriverBenefitsScreen> createState() => _DriverBenefitsScreenState();
}

class _DriverBenefitsScreenState extends State<DriverBenefitsScreen> {
  // Internal level key from Firestore ('Básico' or 'Platino')
  final String _level = 'Básico';
  double _rating = 5.0;
  int _tripsCompleted = 0;
  int _tripsToNextLevel = 60;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final api = RapiApiClient.instance;
      // Rating y datos del driver desde el perfil.
      double rating = 5.0;
      try {
        final profile = await api.myDriverProfile();
        final r = profile['rating'] ?? profile['ratingAvg'];
        if (r is num) rating = r.toDouble();
      } catch (_) {}

      // Cantidad de viajes completados de la semana actual.
      final today = DateTime.now();
      final startOfWeek = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: today.weekday - 1));

      int tripCount = 0;
      try {
        final resp = await api.listRides(
          role: 'driver',
          status: 'completed',
          pageSize: 200,
        );
        final rawList = (resp['rides'] as List?) ?? const [];
        for (final r in rawList) {
          if (r is! Map) continue;
          final ts = r['completedAt'] ?? r['completed_at'];
          if (ts is String) {
            final dt = DateTime.tryParse(ts);
            if (dt != null && !dt.isBefore(startOfWeek)) tripCount++;
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _rating = rating;
          _tripsCompleted = tripCount;
          _tripsToNextLevel = (60 - _tripsCompleted).clamp(0, 60);
        });
      }
    } catch (_) {
      // Silencioso: mantenemos defaults.
    }
  }

  // Calculate end of current week (Sunday)
  String _getLevelEndDate(DriverStrings ds) {
    final now = DateTime.now();
    final endOfWeek = now.add(Duration(days: 7 - now.weekday));
    final months = ds.monthNames;
    return '${endOfWeek.day} de ${months[endOfWeek.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final ds = DriverStrings(Localizations.localeOf(context).languageCode);
    final levelEndDate = _getLevelEndDate(ds);
    final progress = (_tripsCompleted / 60).clamp(0.0, 1.0);
    final ratingMet = _rating >= 4.80;

    return Scaffold(
      backgroundColor: AppColors.getSurface(context),
      body: SafeArea(
        child: Column(
          children: [
            // Back button
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.arrow_back, size: 28, color: AppColors.getTextPrimary(context)),
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Level header with light pink background
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFE8F0),
                      ),
                      child: Column(
                        children: [
                          // Diamond icon
                          Icon(Icons.diamond, size: 80, color: AppColors.rappiRed.withValues(alpha: 0.6)),
                          const SizedBox(height: 16),
                          Text(_level == 'Platino' ? ds.platinum : ds.basic, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
                          const SizedBox(height: 4),
                          Text(ds.yourLevelUntil(levelEndDate), style: TextStyle(fontSize: 15, color: AppColors.getTextSecondary(context))),
                        ],
                      ),
                    ),

                    // "Want to get Platinum?" section
                    Container(
                      color: const Color(0xFFFFE8F0),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ds.wantPlatinum,
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context)),
                          ),
                          const SizedBox(height: 20),

                          // Trip requirement
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.info_outline, size: 18, color: AppColors.getTextSecondary(context)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(ds.complete60TripsBy(levelEndDate),
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context)),
                                    ),
                                    const SizedBox(height: 10),
                                    // Progress bar
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: LinearProgressIndicator(
                                              value: progress,
                                              backgroundColor: Colors.grey[300],
                                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.rappiRed),
                                              minHeight: 6,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(Icons.diamond, size: 20, color: AppColors.rappiRed.withValues(alpha: 0.5)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(ds.tripsRemaining(_tripsToNextLevel),
                                      style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Rating requirement
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.getSurface(context),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  ratingMet ? Icons.check_circle : Icons.info_outline,
                                  size: 24,
                                  color: ratingMet ? AppColors.success : AppColors.getTextSecondary(context),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(ds.keepRating480,
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context)),
                                      ),
                                      Text(
                                        ds.yourRatingIs(_rating.toStringAsFixed(2)),
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ratingMet ? AppColors.success : AppColors.error),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right, color: AppColors.getTextSecondary(context)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // "Your benefits" section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Text(ds.yourBenefits,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context)),
                      ),
                    ),
                    _buildBenefitTile(
                      icon: Icons.percent,
                      iconBgColor: const Color(0xFFE3F2FD),
                      iconColor: const Color(0xFF1976D2),
                      title: ds.lowServicePayments,
                      subtitle: ds.lowServicePaymentsDesc,
                      locked: false,
                      pageIndex: 0,
                    ),

                    const SizedBox(height: 8),

                    // "Get more with Platinum" section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Text(ds.getMoreWithPlatinum,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context)),
                      ),
                    ),
                    _buildBenefitTile(
                      icon: Icons.sort,
                      iconBgColor: Colors.grey[100]!,
                      iconColor: Colors.grey[600]!,
                      title: ds.firstToGetRequests,
                      subtitle: ds.firstToGetRequestsDesc,
                      locked: true,
                      pageIndex: 1,
                    ),
                    _buildBenefitTile(
                      icon: Icons.headset_mic_outlined,
                      iconBgColor: Colors.grey[100]!,
                      iconColor: Colors.grey[600]!,
                      title: ds.highPrioritySupport,
                      subtitle: ds.highPrioritySupportDesc,
                      locked: true,
                      pageIndex: 2,
                    ),
                    _buildBenefitTile(
                      icon: Icons.send,
                      iconBgColor: Colors.grey[100]!,
                      iconColor: Colors.grey[600]!,
                      title: ds.autoAcceptRequests,
                      subtitle: ds.autoAcceptRequestsDesc,
                      locked: true,
                      pageIndex: 3,
                    ),
                    _buildBenefitTile(
                      icon: Icons.star_border,
                      iconBgColor: Colors.grey[100]!,
                      iconColor: Colors.grey[600]!,
                      title: ds.featuredProfile,
                      subtitle: ds.featuredProfileDesc,
                      locked: true,
                      pageIndex: 4,
                    ),
                    _buildBenefitTile(
                      icon: Icons.local_offer_outlined,
                      iconBgColor: Colors.grey[100]!,
                      iconColor: Colors.grey[600]!,
                      title: ds.partnerBonus,
                      subtitle: ds.partnerBonusDesc,
                      locked: true,
                      pageIndex: 5,
                    ),

                    const SizedBox(height: 16),

                    // CTA banner
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.rappiRed, AppColors.rappiRed.withValues(alpha: 0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.lock_open, size: 64, color: Colors.white70),
                          const SizedBox(height: 16),
                          Text(
                            ds.unlockPlatinumTrips(_tripsToNextLevel),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.rappiRed,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: Text(ds.goToRequestList, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Footer
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Text(ds.aboutRappiTeamLevels,
                          style: TextStyle(fontSize: 15, color: AppColors.getTextSecondary(context)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitTile({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool locked,
    required int pageIndex,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DriverBenefitDetailScreen(initialIndex: pageIndex)),
        ),
        child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.getSurface(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Icon with optional lock badge
            Stack(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                if (locked)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppColors.getSurface(context),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.lock, size: 12, color: AppColors.getTextSecondary(context)),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context))),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.getTextSecondary(context)),
          ],
        ),
      ),
      ),
    );
  }
}
