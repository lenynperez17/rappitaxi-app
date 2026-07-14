import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive_bottom_sheet.dart';
import '../../core/l10n/driver_strings.dart';
import '../../services/rapi_api_client.dart';

class DriverOrderHistoryScreen extends StatefulWidget {
  const DriverOrderHistoryScreen({super.key});

  @override
  State<DriverOrderHistoryScreen> createState() => _DriverOrderHistoryScreenState();
}

class _DriverOrderHistoryScreenState extends State<DriverOrderHistoryScreen> {
  int _selectedFilter = 0; // 0=All, 1=City rides, 2=Delivery
  List<Map<String, dynamic>> _trips = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() => _isLoading = true);

    try {
      // Historial de viajes del driver desde el backend Node.
      final resp = await RapiApiClient.instance.listRides(
        role: 'driver',
        pageSize: 50,
      );
      final rawList = (resp['rides'] as List?) ?? const [];

      List<Map<String, dynamic>> trips = [];
      for (final r in rawList) {
        if (r is! Map) continue;
        trips.add(Map<String, dynamic>.from(r));
      }

      // Filtro cliente por tipo (el backend aún no filtra por type).
      if (_selectedFilter == 1) {
        trips = trips.where((t) => (t['type'] ?? 'ride') == 'ride').toList();
      } else if (_selectedFilter == 2) {
        trips = trips.where((t) => t['type'] == 'delivery').toList();
      }

      if (mounted) {
        setState(() {
          _trips = trips;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Timestamps del backend llegan como ISO-8601 (columna TIMESTAMP en Postgres).
  DateTime? _parseTs(dynamic v) {
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ds = DriverStrings(Localizations.localeOf(context).languageCode);
    return Scaffold(
      backgroundColor: AppColors.getSurface(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.arrow_back, size: 28, color: AppColors.getTextPrimary(context)),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                ds.requestHistory,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.getTextPrimary(context)),
              ),
            ),
            const SizedBox(height: 16),

            // Filter pills
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildFilterChip(Icons.list, ds.all, 0, ds),
                  const SizedBox(width: 8),
                  _buildFilterChip(null, ds.rides, 1, ds),
                  const SizedBox(width: 8),
                  _buildFilterChip(null, ds.deliveries, 2, ds),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _trips.isEmpty
                      ? _buildEmptyState(ds)
                      : _buildTripsList(ds),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(DriverStrings ds) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Car illustration placeholder
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: AppColors.rappiRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 20,
                    top: 20,
                    child: Transform.rotate(
                      angle: -0.2,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.rappiRed.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 25,
                    bottom: 30,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.rappiRed.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  Icon(Icons.directions_car, size: 80, color: AppColors.rappiRed.withValues(alpha: 0.5)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              ds.noRequestHistory,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.getTextPrimary(context)),
            ),
            const SizedBox(height: 8),
            Text(
              ds.allRequestsShownIn24h,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: AppColors.getTextSecondary(context), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripsList(DriverStrings ds) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _trips.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.getBorder(context)),
      itemBuilder: (context, index) {
        final trip = _trips[index];
        final fare = ((trip['finalFare'] ?? trip['fare'] ?? trip['final_fare'] ?? 0) as num).toDouble();
        final completedAt = _parseTs(trip['completedAt'] ?? trip['completed_at']);
        final pickup = trip['pickupAddress'] ?? trip['pickup'] ?? '';
        final destination = trip['destinationAddress'] ?? trip['destination'] ?? '';
        final status = trip['status'] ?? 'completed';

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: status == 'completed'
                  ? AppColors.rappiRed.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              status == 'completed' ? Icons.check : Icons.close,
              color: status == 'completed' ? AppColors.rappiRed : Colors.grey,
            ),
          ),
          title: Text(
            'S/ ${fare.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context)),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (completedAt != null)
                Text(
                  _formatDateTime(completedAt, ds),
                  style: TextStyle(fontSize: 13, color: AppColors.getTextSecondary(context)),
                ),
              if (pickup.isNotEmpty)
                Text(
                  '$pickup → $destination',
                  style: TextStyle(fontSize: 13, color: AppColors.getTextSecondary(context)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          trailing: Icon(Icons.chevron_right, color: AppColors.getTextSecondary(context)),
          onTap: () {
            _showTripDetail(trip, ds);
          },
        );
      },
    );
  }

  void _showTripDetail(Map<String, dynamic> trip, DriverStrings ds) {
    final fare = ((trip['finalFare'] ?? trip['fare'] ?? trip['final_fare'] ?? 0) as num).toDouble();
    final pickup = trip['pickupAddress'] ?? trip['pickup'] ?? 'N/A';
    final destination = trip['destinationAddress'] ?? trip['destination'] ?? 'N/A';
    final completedAt = _parseTs(trip['completedAt'] ?? trip['completed_at']);

    showResponsiveBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ds.tripDetail, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
            const SizedBox(height: 16),
            _detailRow(Icons.monetization_on, ds.fare, 'S/ ${fare.toStringAsFixed(2)}'),
            if (completedAt != null)
              _detailRow(Icons.access_time, ds.completedAt, _formatDateTime(completedAt, ds)),
            _detailRow(Icons.location_on, ds.pickup, pickup),
            _detailRow(Icons.flag, ds.destination, destination),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.rappiRed),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 13, color: AppColors.getTextSecondary(context))),
                Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.getTextPrimary(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt, DriverStrings ds) {
    final months = ds.monthAbbreviations;
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildFilterChip(IconData? icon, String label, int index, DriverStrings ds) {
    final isSelected = _selectedFilter == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = index);
        _loadTrips();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.getTextPrimary(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? Colors.transparent : AppColors.getBorder(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: isSelected ? AppColors.getSurface(context) : AppColors.getTextPrimary(context)),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.getSurface(context) : AppColors.getTextPrimary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
