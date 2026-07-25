import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive_bottom_sheet.dart';
import '../../core/l10n/driver_strings.dart';
import '../../services/rapi_api_client.dart';
import 'driver_wallet_simple_screen.dart';
import 'driver_benefits_screen.dart';
import 'driver_earnings_detail_screen.dart';
import 'driver_achievements_screen.dart';

class DriverPerformanceScreen extends StatefulWidget {
  final GlobalKey<ScaffoldState>? parentScaffoldKey;
  const DriverPerformanceScreen({super.key, this.parentScaffoldKey});

  @override
  State<DriverPerformanceScreen> createState() => _DriverPerformanceScreenState();
}

class _DriverPerformanceScreenState extends State<DriverPerformanceScreen> {
  double _todayEarnings = 0.0;
  final double _targetEarnings = 252.0;
  double _walletBalance = 0.0;
  final int _bonifications = 0;
  double _rating = 5.0;
  final String _level = 'Básico';
  final int _tripsToNextLevel = 60;
  String _profilePhoto = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final api = RapiApiClient.instance;

      // Perfil del usuario actual (rating + foto).
      double rating = 5.0;
      String photo = '';
      try {
        final resp = await api.me();
        final u = resp?['user'] as Map<String, dynamic>?;
        if (u != null) {
          final r = u['rating'] ?? u['ratingAvg'];
          if (r is num) rating = r.toDouble();
          photo = (u['profilePhotoUrl'] ?? u['photoUrl'] ?? '') as String;
        }
      } catch (_) {}

      // Balance de la billetera.
      double walletBalance = 0;
      try {
        final w = await api.walletBalance();
        final b = w['balance'] ?? w['serviceCredits'];
        if (b is num) walletBalance = b.toDouble();
      } catch (_) {}

      // Ganancias del día — sumamos rides completados hoy.
      double earnings = 0;
      try {
        final resp = await api.listRides(
          role: 'driver',
          status: 'completed',
          pageSize: 100,
        );
        final now = DateTime.now();
        final startOfDay = DateTime(now.year, now.month, now.day);
        final rawList = (resp['rides'] as List?) ?? const [];
        for (final r in rawList) {
          if (r is! Map) continue;
          final ts = r['completedAt'] ?? r['completed_at'];
          DateTime? dt;
          if (ts is String) dt = DateTime.tryParse(ts);
          if (dt == null || dt.isBefore(startOfDay)) continue;
          final fare = r['finalFare'] ?? r['fare'] ?? r['final_fare'] ?? 0;
          if (fare is num) earnings += fare.toDouble();
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _todayEarnings = earnings;
          _walletBalance = walletBalance;
          _rating = rating;
          _profilePhoto = photo;
        });
      }
    } catch (_) {
      // Silencioso: mantenemos defaults.
    }
  }

  @override
  Widget build(BuildContext context) {
    final ds = DriverStrings(Localizations.localeOf(context).languageCode);
    return Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (widget.parentScaffoldKey?.currentState != null) {
                        widget.parentScaffoldKey!.currentState!.openDrawer();
                      } else {
                        Scaffold.of(context).openDrawer();
                      }
                    },
                    child: Icon(Icons.menu, size: 28, color: AppColors.getTextPrimary(context)),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Level card
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE0EC),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // Avatar with rating badge
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 32,
                                    backgroundImage: _profilePhoto.isNotEmpty ? NetworkImage(_profilePhoto) : null,
                                    child: _profilePhoto.isEmpty ? const Icon(Icons.person, size: 32) : null,
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black87,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.star, size: 12, color: Colors.amber),
                                          const SizedBox(width: 2),
                                          Text(_rating.toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            _level == 'Básico' ? ds.basic : ds.platinum,
                                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context)),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(Icons.diamond, color: const Color(0xFFE91E63), size: 24),
                                      ],
                                    ),
                                    Text(
                                      ds.yourLevelThisWeek,
                                      style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Progress to next level
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.getSurface(context),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text(ds.tripsToPlatinum(_tripsToNextLevel), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: 0.0,
                                  backgroundColor: Colors.grey[200],
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE91E63)),
                                ),
                                const SizedBox(height: 8),
                                Text(ds.keepRating480Plus, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverBenefitsScreen())),
                              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                              child: Text(ds.viewBenefits, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Today earnings
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => DriverEarningsDetailScreen(
                          todayEarnings: _todayEarnings,
                          targetEarnings: _targetEarnings,
                        ),
                      )),
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(ds.todayEarnings, style: TextStyle(fontSize: 16, color: AppColors.getTextSecondary(context))),
                                Icon(Icons.chevron_right, color: AppColors.getTextSecondary(context)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('S/ ${_todayEarnings.toInt()}', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: AppColors.getTextPrimary(context))),
                                Text('${ds.objective}: S/${_targetEarnings.toInt()}', style: TextStyle(fontSize: 16, color: AppColors.getTextSecondary(context))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Divider(height: 1, color: AppColors.getBorder(context)),

                    // Wallet balance
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: Icon(Icons.account_balance_wallet_outlined, color: AppColors.getTextSecondary(context)),
                      title: Text('S/ ${_walletBalance.toStringAsFixed(2)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
                      subtitle: Text(ds.walletBalance, style: TextStyle(color: AppColors.getTextSecondary(context))),
                      trailing: OutlinedButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverWalletSimpleScreen())),
                        child: Text(ds.recharge),
                      ),
                    ),
                    Divider(height: 1, color: AppColors.getBorder(context)),

                    // Bonifications
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: Icon(Icons.access_time, color: AppColors.getTextSecondary(context)),
                      title: Text('$_bonifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
                      subtitle: Text(ds.bonifications, style: TextStyle(color: AppColors.getTextSecondary(context))),
                      trailing: Icon(Icons.chevron_right, color: AppColors.getTextSecondary(context)),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverWalletSimpleScreen())),
                    ),
                    Divider(height: 1, color: AppColors.getBorder(context)),

                    // Invite friends
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: Icon(Icons.group_add, color: AppColors.getTextSecondary(context)),
                        title: Text(ds.inviteFriends, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
                        subtitle: Text(ds.getS100Each, style: TextStyle(color: AppColors.getTextSecondary(context))),
                        trailing: Icon(Icons.chevron_right, color: AppColors.getTextSecondary(context)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: AppColors.getBorder(context).withValues(alpha:0.3)),
                        ),
                        onTap: () {
                          showResponsiveBottomSheet(
                            context: context,
                            builder: (ctx) => Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.group_add, size: 48, color: AppColors.rappiRed),
                                  const SizedBox(height: 16),
                                  Text(ds.inviteFriendsTitle, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
                                  const SizedBox(height: 8),
                                  Text(ds.inviteFriendsDesc, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: AppColors.getTextSecondary(context))),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(ds.invitationCodeCopied)),
                                        );
                                      },
                                      icon: const Icon(Icons.share, color: Colors.white),
                                      label: Text(ds.shareCode, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.rappiRed,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Achievements
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: Icon(Icons.flag, color: AppColors.getTextSecondary(context)),
                        title: Text(ds.achievements, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
                        trailing: Icon(Icons.chevron_right, color: AppColors.getTextSecondary(context)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: AppColors.getBorder(context).withValues(alpha:0.3)),
                        ),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverAchievementsScreen()));
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
    );
  }
}
