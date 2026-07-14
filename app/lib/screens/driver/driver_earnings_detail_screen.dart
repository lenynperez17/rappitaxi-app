import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/l10n/driver_strings.dart';
import '../../services/rapi_api_client.dart';
import 'driver_order_history_screen.dart';
import 'driver_achievements_screen.dart';

class DriverEarningsDetailScreen extends StatefulWidget {
  final double todayEarnings;
  final double targetEarnings;

  const DriverEarningsDetailScreen({
    super.key,
    required this.todayEarnings,
    required this.targetEarnings,
  });

  @override
  State<DriverEarningsDetailScreen> createState() => _DriverEarningsDetailScreenState();
}

class _DriverEarningsDetailScreenState extends State<DriverEarningsDetailScreen> {
  int _selectedFilter = 0; // 0=Día, 1=Semana, 2=Mes
  DateTime _selectedDate = DateTime.now();
  double _earnings = 0;
  int _tripCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _earnings = widget.todayEarnings;
    _loadEarnings();
  }

  Future<void> _loadEarnings() async {
    setState(() => _isLoading = true);

    try {
      DateTime startDate;
      DateTime endDate;

      if (_selectedFilter == 0) {
        // Day
        startDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        endDate = startDate.add(const Duration(days: 1));
      } else if (_selectedFilter == 1) {
        // Week
        final weekday = _selectedDate.weekday;
        startDate = _selectedDate.subtract(Duration(days: weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        endDate = startDate.add(const Duration(days: 7));
      } else {
        // Month
        startDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
        endDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
      }

      // TODO(node-migration): reemplazar con endpoint agregador
      // /api/drivers/me/earnings?from=&to= cuando exista.
      // Por ahora traemos rides completados del driver y filtramos por rango.
      final resp = await RapiApiClient.instance.listRides(
        role: 'driver',
        status: 'completed',
        pageSize: 200,
      );
      final rawList = (resp['rides'] as List?) ?? const [];

      double total = 0;
      int tripCount = 0;
      for (final r in rawList) {
        if (r is! Map) continue;
        final ts = r['completedAt'] ?? r['completed_at'];
        DateTime? dt;
        if (ts is String) dt = DateTime.tryParse(ts);
        if (dt == null) continue;
        if (dt.isBefore(startDate) || !dt.isBefore(endDate)) continue;
        final fare = r['finalFare'] ?? r['fare'] ?? r['final_fare'] ?? 0;
        if (fare is num) total += fare.toDouble();
        tripCount++;
      }

      if (mounted) {
        setState(() {
          _earnings = total;
          _tripCount = tripCount;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateDate(int direction) {
    setState(() {
      if (_selectedFilter == 0) {
        _selectedDate = _selectedDate.add(Duration(days: direction));
      } else if (_selectedFilter == 1) {
        _selectedDate = _selectedDate.add(Duration(days: 7 * direction));
      } else {
        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + direction, _selectedDate.day);
      }
    });
    _loadEarnings();
  }

  String _formatDate(DriverStrings ds) {
    final months = ds.monthAbbreviations;
    if (_selectedFilter == 0) {
      return '${months[_selectedDate.month - 1]} ${_selectedDate.day}, ${_selectedDate.year}';
    } else if (_selectedFilter == 1) {
      final weekday = _selectedDate.weekday;
      final start = _selectedDate.subtract(Duration(days: weekday - 1));
      final end = start.add(const Duration(days: 6));
      return '${months[start.month - 1]} ${start.day} – ${months[end.month - 1]} ${end.day}';
    } else {
      return '${months[_selectedDate.month - 1]} ${_selectedDate.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ds = DriverStrings(Localizations.localeOf(context).languageCode);
    final remaining = (widget.targetEarnings - _earnings).clamp(0.0, widget.targetEarnings);
    final progress = widget.targetEarnings > 0 ? (_earnings / widget.targetEarnings).clamp(0.0, 1.0) : 0.0;
    final estimatedTrips = remaining.toInt();

    return Scaffold(
      backgroundColor: AppColors.getSurface(context),
      body: SafeArea(
        child: Column(
          children: [
            // Close button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close, size: 28, color: AppColors.getTextPrimary(context)),
                ),
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    // Filter pills
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildFilterPill(ds.day, 0, ds),
                          const SizedBox(width: 8),
                          _buildFilterPill(ds.week, 1, ds),
                          const SizedBox(width: 8),
                          _buildFilterPill(ds.month, 2, ds),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Date label
                    Text(
                      _formatDate(ds),
                      style: TextStyle(fontSize: 15, color: AppColors.getTextSecondary(context)),
                    ),
                    const SizedBox(height: 8),

                    // Earnings with arrows
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () => _navigateDate(-1),
                          child: Icon(Icons.chevron_left, size: 32, color: AppColors.getTextSecondary(context)),
                        ),
                        const SizedBox(width: 16),
                        _isLoading
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(
                                _earnings.toStringAsFixed(2),
                                style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: AppColors.getTextPrimary(context)),
                              ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () => _navigateDate(1),
                          child: Icon(Icons.chevron_right, size: 32, color: AppColors.getTextSecondary(context)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Daily income plan card
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.rappiRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                ds.dailyIncomePlan,
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context)),
                              ),
                              Text(
                                '${ds.objective}: S/ ${widget.targetEarnings.toInt()}',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.white.withValues(alpha: 0.6),
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.rappiRed),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            ds.remaining(remaining.toInt(), estimatedTrips),
                            style: TextStyle(fontSize: 15, color: AppColors.getTextPrimary(context)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Empty state
                    if (_tripCount == 0) ...[
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.getBackground(context),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.home_outlined, size: 40, color: AppColors.getTextSecondary(context)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        ds.noCompletedRequests,
                        style: TextStyle(fontSize: 18, color: AppColors.getTextSecondary(context)),
                      ),
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: AppColors.rappiRed, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              ds.tripsCompletedCount(_tripCount),
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // Bottom items
            Divider(height: 1, color: AppColors.getBorder(context)),
            ListTile(
              leading: Icon(Icons.list_alt, color: AppColors.getTextPrimary(context)),
              title: Text(ds.requestHistoryShort, style: TextStyle(fontSize: 16, color: AppColors.getTextPrimary(context))),
              trailing: Icon(Icons.chevron_right, color: AppColors.getTextSecondary(context)),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverOrderHistoryScreen())),
            ),
            Divider(height: 1, color: AppColors.getBorder(context)),
            ListTile(
              leading: Icon(Icons.flag, color: AppColors.getTextPrimary(context)),
              title: Text(ds.achievements, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
              trailing: Icon(Icons.chevron_right, color: AppColors.getTextSecondary(context)),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverAchievementsScreen())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(String label, int index, DriverStrings ds) {
    final isSelected = _selectedFilter == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = index);
        _loadEarnings();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.getTextPrimary(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? Colors.transparent : AppColors.getBorder(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.getSurface(context) : AppColors.getTextPrimary(context),
          ),
        ),
      ),
    );
  }
}
