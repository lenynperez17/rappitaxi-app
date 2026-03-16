// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../generated/l10n/app_localizations.dart'; // ✅ NUEVO: Import de localizaciones
import '../../core/theme/modern_theme.dart';
import '../../core/extensions/theme_extensions.dart'; // ✅ Extensión para colores que se adaptan al tema
import '../../core/utils/currency_formatter.dart';
import '../../widgets/animated/modern_animated_widgets.dart';
import '../../widgets/common/rappi_app_bar.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ride_provider.dart';
import '../../models/trip_model.dart';
import '../shared/rating_dialog.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _TripHistoryScreenState createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen>
    with TickerProviderStateMixin {
  late AnimationController _listAnimationController;
  late AnimationController _statsAnimationController;
  
  String _selectedFilter = 'all';
  DateTimeRange? _dateRange;
  List<TripModel> _trips = [];
  bool _isLoading = true;
  
  // Estadísticas
  Map<String, dynamic> get _stats {
    final completedTrips = _filteredTrips.where((t) => t.status == 'completed').toList();
    final totalSpent = completedTrips.fold<double>(0, (acc, trip) => acc + (trip.finalFare ?? trip.estimatedFare));
    final totalDistance = completedTrips.fold<double>(0, (acc, trip) => acc + trip.estimatedDistance);
    final avgRating = completedTrips.where((t) => t.passengerRating != null)
        .fold<double>(0, (acc, trip) => acc + (trip.passengerRating ?? 0)) /
        completedTrips.where((t) => t.passengerRating != null).length;
    
    return {
      'totalTrips': completedTrips.length,
      'totalSpent': totalSpent,
      'totalDistance': totalDistance,
      'avgRating': avgRating.isNaN ? 0.0 : avgRating,
    };
  }
  
  List<TripModel> get _filteredTrips {
    var filtered = _trips;
    
    if (_selectedFilter != 'all') {
      filtered = filtered.where((trip) => trip.status == _selectedFilter).toList();
    }
    
    if (_dateRange != null) {
      filtered = filtered.where((trip) {
        return trip.requestedAt.isAfter(_dateRange!.start) &&
               trip.requestedAt.isBefore(_dateRange!.end.add(Duration(days: 1)));
      }).toList();
    }
    
    return filtered;
  }

  @override
  void initState() {
    super.initState();
    
    _listAnimationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    
    _statsAnimationController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _loadTripsHistory();
  }

  Future<void> _loadTripsHistory() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final rideProvider = Provider.of<RideProvider>(context, listen: false);
    
    if (authProvider.currentUser != null) {
      try {
        final trips = await rideProvider.getUserTripHistory(authProvider.currentUser!.id);
        
        if (!mounted) return;
        setState(() {
          _trips = trips;
          _isLoading = false;
        });
        _listAnimationController.forward();
        _statsAnimationController.forward();
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        debugPrint('Error loading trip history: $e');
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    _statsAnimationController.dispose();
    super.dispose();
  }
  
  void _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: ModernTheme.rappiOrange,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _dateRange = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surfaceColor,
      appBar: RappiAppBar(
        title: AppLocalizations.of(context)!.tripHistory,
        showBackButton: true,
        actions: [
          IconButton(
            icon: Icon(Icons.download, color: Theme.of(context).colorScheme.onPrimary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context)!.downloading),
                  backgroundColor: ModernTheme.rappiOrange,
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Estadísticas
          AnimatedBuilder(
            animation: _statsAnimationController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, -50 * (1 - _statsAnimationController.value)),
                child: Opacity(
                  opacity: _statsAnimationController.value,
                  child: _buildStatistics(),
                ),
              );
            },
          ),
          
          // Filtros
          _buildFilters(),
          
          // Lista de viajes
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: ModernTheme.rappiOrange))
                : _filteredTrips.isEmpty
                    ? _buildEmptyState()
                    : AnimatedBuilder(
                    animation: _listAnimationController,
                    builder: (context, child) {
                      return ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: _filteredTrips.length,
                        itemBuilder: (context, index) {
                          final trip = _filteredTrips[index];
                          final delay = index * 0.1;
                          final animation = Tween<double>(
                            begin: 0,
                            end: 1,
                          ).animate(
                            CurvedAnimation(
                              parent: _listAnimationController,
                              curve: Interval(
                                delay,
                                delay + 0.5,
                                curve: Curves.easeOutBack,
                              ),
                            ),
                          );
                          
                          return AnimatedBuilder(
                            animation: animation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(50 * (1 - animation.value), 0),
                                child: Opacity(
                                  opacity: animation.value.clamp(0.0, 1.0),
                                  child: _buildTripCard(trip),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatistics() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: ModernTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: ModernTheme.rappiOrange.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            AppLocalizations.of(context)!.monthSummary,
            style: TextStyle(
              color: Theme.of(context).colorScheme.surface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: Icons.route,
                value: '${_stats['totalTrips']}',
                label: AppLocalizations.of(context)!.trips,
              ),
              _buildStatItem(
                icon: Icons.account_balance_wallet, // ✅ Cambiado de attach_money ($) a wallet
                value: ((_stats['totalSpent'] as num).toDouble()).toCurrency(),
                label: AppLocalizations.of(context)!.spent,
              ),
              _buildStatItem(
                icon: Icons.map,
                value: '${((_stats['totalDistance'] as num).toDouble()).toStringAsFixed(1)} km',
                label: AppLocalizations.of(context)!.distance,
              ),
              _buildStatItem(
                icon: Icons.star,
                value: ((_stats['avgRating'] as num).toDouble()).toStringAsFixed(1),
                label: AppLocalizations.of(context)!.rating,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.onPrimary, size: 20),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: Theme.of(context).colorScheme.surface,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  Widget _buildFilters() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Chips de filtro
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(AppLocalizations.of(context)!.all, 'all'),
                SizedBox(width: 8),
                _buildFilterChip(AppLocalizations.of(context)!.completed, 'completed'),
                SizedBox(width: 8),
                _buildFilterChip(AppLocalizations.of(context)!.cancelled, 'cancelled'),
                SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _selectDateRange,
                  icon: Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    _dateRange == null
                        ? AppLocalizations.of(context)!.date
                        : '${_dateRange!.start.day}/${_dateRange!.start.month} - ${_dateRange!.end.day}/${_dateRange!.end.month}',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ModernTheme.rappiOrange,
                    side: BorderSide(color: ModernTheme.rappiOrange),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                if (_dateRange != null) ...[
                  SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.clear, size: 20),
                    onPressed: () => setState(() => _dateRange = null),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      selectedColor: ModernTheme.rappiOrange,
      backgroundColor: Theme.of(context).colorScheme.surface,
      labelStyle: TextStyle(
        color: isSelected ? Theme.of(context).colorScheme.onPrimary : context.primaryText,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? ModernTheme.rappiOrange : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
        ),
      ),
    );
  }
  
  Widget _buildTripCard(TripModel trip) {
    // Timeline layout: línea naranja vertical a la izquierda + círculo + card
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Columna de timeline: línea naranja + círculo
            SizedBox(
              width: 32,
              child: Column(
                children: [
                  // Círculo naranja en la línea de tiempo
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _getStatusColor(trip.status),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ModernTheme.rappiOrange,
                        width: 2,
                      ),
                    ),
                  ),
                  // Línea naranja vertical
                  Expanded(
                    child: Container(
                      width: 3,
                      color: ModernTheme.rappiOrange.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12),
            // Card del viaje
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: ModernTheme.getCardShadow(context),
                ),
                child: InkWell(
                  onTap: () => _showTripDetails(trip),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header con fecha y precio
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _formatDate(trip.requestedAt),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  _formatTime(trip.requestedAt),
                                  style: TextStyle(
                                    color: context.secondaryText,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              (trip.finalFare ?? trip.estimatedFare).toCurrency(),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: ModernTheme.rappiOrange,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 16),

                        // Ruta
                        Row(
                          children: [
                            Column(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: ModernTheme.rappiOrange,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Container(
                                  width: 2,
                                  height: 30,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                                ),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: ModernTheme.error,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    trip.pickupAddress,
                                    style: TextStyle(fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 20),
                                  Text(
                                    trip.destinationAddress,
                                    style: TextStyle(fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 16),

                        // Info adicional
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: ModernTheme.rappiOrange.withValues(alpha: 0.1),
                                    child: Icon(
                                      Icons.person,
                                      size: 16,
                                      color: ModernTheme.rappiOrange,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          AppLocalizations.of(context)!.driver,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.star, size: 12, color: ModernTheme.warning),
                                            Text(
                                              ' ${(trip.driverRating ?? 5.0).toStringAsFixed(1)}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: context.secondaryText,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            if (trip.status == 'completed' && trip.passengerRating != null) ...[
                              SizedBox(width: 8),
                              Flexible(
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: ModernTheme.warning.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.star, size: 12, color: ModernTheme.warning),
                                      SizedBox(width: 3),
                                      Flexible(
                                        child: Text(
                                          AppLocalizations.of(context)!.yourRating(trip.passengerRating?.toStringAsFixed(1) ?? ''),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: ModernTheme.warning,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: context.secondaryText.withValues(alpha: 0.3),
          ),
          SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.noTrips,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: context.secondaryText,
            ),
          ),
          SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.adjustFilters,
            style: TextStyle(
              color: context.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
  
  void _showTripDetails(TripModel trip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Necesario para el modal
      builder: (context) => TripDetailsModal(trip: trip),
    );
  }
  
  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return ModernTheme.success;
      case 'cancelled':
        return ModernTheme.error;
      default:
        return context.secondaryText;
    }
  }
  
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) return AppLocalizations.of(context)!.today;
    if (difference == 1) return AppLocalizations.of(context)!.yesterday;
    if (difference < 7) return AppLocalizations.of(context)!.daysAgo(difference);

    return '${date.day}/${date.month}/${date.year}';
  }
  
  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// Modal de detalles del viaje
class TripDetailsModal extends StatefulWidget {
  final TripModel trip;
  
  const TripDetailsModal({super.key, required this.trip});
  
  @override
  // ignore: library_private_types_in_public_api
  _TripDetailsModalState createState() => _TripDetailsModalState();
}

class _TripDetailsModalState extends State<TripDetailsModal> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.tripDetails,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ID y Estado
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ID: ${widget.trip.id}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: context.secondaryText,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: widget.trip.status == 'completed' 
                            ? ModernTheme.success.withValues(alpha: 0.1)
                            : ModernTheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.trip.status == 'completed' ? AppLocalizations.of(context)!.completedStatus : AppLocalizations.of(context)!.cancelledStatus,
                          style: TextStyle(
                            color: widget.trip.status == 'completed'
                              ? ModernTheme.success
                              : ModernTheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 24),

                  // Información del viaje
                  _buildDetailSection(
                    AppLocalizations.of(context)!.tripRoute,
                    [
                      _buildDetailRow(Icons.trip_origin, AppLocalizations.of(context)!.origin, widget.trip.pickupAddress),
                      _buildDetailRow(Icons.location_on, AppLocalizations.of(context)!.destination, widget.trip.destinationAddress),
                      _buildDetailRow(Icons.route, AppLocalizations.of(context)!.distance, '${widget.trip.estimatedDistance.toStringAsFixed(1)} km'),
                      _buildDetailRow(Icons.timer, AppLocalizations.of(context)!.duration, widget.trip.tripDuration?.inMinutes.toString() ?? 'N/A min'),
                    ],
                  ),

                  SizedBox(height: 20),

                  // Información del conductor
                  _buildDetailSection(
                    AppLocalizations.of(context)!.driver,
                    [
                      _buildDetailRow(Icons.person, 'ID ${AppLocalizations.of(context)!.driver}', widget.trip.driverId ?? 'N/A'),
                      _buildDetailRow(Icons.star, AppLocalizations.of(context)!.rating, '${widget.trip.driverRating ?? 'N/A'}'),
                      _buildDetailRow(Icons.directions_car, AppLocalizations.of(context)!.vehicle, widget.trip.vehicleInfo?.toString() ?? 'N/A'),
                    ],
                  ),

                  SizedBox(height: 20),

                  // Información de pago
                  _buildDetailSection(
                    AppLocalizations.of(context)!.payment,
                    [
                      _buildDetailRow(Icons.account_balance_wallet, AppLocalizations.of(context)!.amount, (widget.trip.finalFare ?? widget.trip.estimatedFare).toCurrency()), // ✅ Cambiado de attach_money ($) a wallet
                      _buildDetailRow(Icons.payment, AppLocalizations.of(context)!.method, AppLocalizations.of(context)!.defaultCash),
                    ],
                  ),
                  
                  if (widget.trip.status == 'completed' && widget.trip.passengerRating == null) ...[
                    SizedBox(height: 24),
                    AnimatedPulseButton(
                      text: AppLocalizations.of(context)!.rateTrip,
                      icon: Icons.star,
                      onPressed: () {
                        Navigator.pop(context);
                        // Mostrar dialog de calificación
                        RatingDialog.show(
                          context: context,
                          driverName: widget.trip.driverId ?? 'Conductor',
                          driverPhoto: '', // Se obtiene del perfil del conductor desde Firebase
                          tripId: widget.trip.id,
                          onSubmit: (rating, comment, tags) async {
                            // Actualizar la calificación del viaje en Firebase
                            await _updateTripRating(widget.trip.id, rating.toDouble(), comment ?? '', tags);
                          },
                        );
                      },
                      color: ModernTheme.rappiOrange,
                    ),
                  ],
                  
                  SizedBox(height: 24),
                  
                  // Botones de acción
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showReportProblemDialog(),
                          icon: Icon(Icons.help_outline),
                          label: Text(AppLocalizations.of(context)!.reportProblem),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _generateAndShareReceipt(),
                          icon: Icon(Icons.receipt),
                          label: Text(AppLocalizations.of(context)!.viewReceipt),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Actualizar calificación del viaje en Firebase
  Future<void> _updateTripRating(String tripId, double rating, String comment, List<String> tags) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.id;

      if (userId != null) {
        // Actualizar calificación en Firebase
        await Provider.of<RideProvider>(context, listen: false)
            .updateTripRating(tripId, userId, rating, comment, tags);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.ratingSubmittedSuccessfully),
              backgroundColor: ModernTheme.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorSubmittingRating(e.toString())),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }

  // Mostrar diálogo para reportar un problema con el viaje
  void _showReportProblemDialog() {
    final TextEditingController descriptionController = TextEditingController();
    String? selectedCategory;

    // Categorías de problemas disponibles
    final problemCategories = {
      'driver_behavior': 'Comportamiento del conductor',
      'route_issue': 'Problema con la ruta',
      'payment_issue': 'Problema de pago',
      'safety_concern': 'Preocupación de seguridad',
      'vehicle_condition': 'Condición del vehículo',
      'pricing_dispute': 'Disputa de precio',
      'other': 'Otro',
    };

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.report_problem, color: ModernTheme.warning),
              SizedBox(width: 12),
              Text(
                'Reportar Problema',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selecciona la categoría del problema:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: context.primaryText,
                  ),
                ),
                SizedBox(height: 12),

                // Dropdown de categorías
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: ModernTheme.borderColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      hint: Text('Seleccionar categoría'),
                      value: selectedCategory,
                      items: problemCategories.entries.map((entry) {
                        return DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedCategory = value;
                        });
                      },
                    ),
                  ),
                ),

                SizedBox(height: 16),

                Text(
                  'Describe el problema:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: context.primaryText,
                  ),
                ),
                SizedBox(height: 12),

                // Campo de descripción
                TextField(
                  controller: descriptionController,
                  maxLines: 5,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: 'Por favor describe el problema en detalle...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),

                SizedBox(height: 8),

                // Información del viaje
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Información del viaje:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: context.secondaryText,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'ID: ${widget.trip.id}',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.secondaryText,
                        ),
                      ),
                      Text(
                        'Fecha: ${widget.trip.requestedAt.day}/${widget.trip.requestedAt.month}/${widget.trip.requestedAt.year}',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                descriptionController.dispose();
                Navigator.pop(dialogContext);
              },
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: selectedCategory == null || descriptionController.text.trim().isEmpty
                  ? null
                  : () async {
                      final description = descriptionController.text.trim();
                      Navigator.pop(dialogContext);

                      await _submitProblemReport(
                        category: selectedCategory!,
                        categoryName: problemCategories[selectedCategory]!,
                        description: description,
                      );

                      descriptionController.dispose();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.warning,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: Text('Enviar Reporte'),
            ),
          ],
        ),
      ),
    );
  }

  // Enviar reporte de problema a Firebase
  Future<void> _submitProblemReport({
    required String category,
    required String categoryName,
    required String description,
  }) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.id;
      final userName = authProvider.currentUser?.fullName ?? 'Usuario';

      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      // Obtener el nombre del conductor desde vehicleInfo si está disponible
      final driverName = widget.trip.vehicleInfo?['driverName'] ?? 'Conductor';

      // Crear documento en la colección supportTickets
      final reportData = {
        'userId': userId,
        'userName': userName,
        'tripId': widget.trip.id,
        'driverId': widget.trip.driverId,
        'driverName': driverName,
        'category': category,
        'categoryName': categoryName,
        'description': description,
        'status': 'pending', // pending, in_review, resolved, closed
        'priority': _determinePriority(category), // high, medium, low
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'tripDate': widget.trip.requestedAt,
        'tripOrigin': widget.trip.pickupAddress,
        'tripDestination': widget.trip.destinationAddress,
        'tripPrice': widget.trip.finalFare ?? widget.trip.estimatedFare,
        'resolved': false,
        'adminResponse': null,
        'resolvedAt': null,
      };

      await FirebaseFirestore.instance
          .collection('supportTickets')
          .add(reportData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Theme.of(context).colorScheme.onPrimary),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Reporte enviado exitosamente. Nuestro equipo lo revisará pronto.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                  ),
                ),
              ],
            ),
            backgroundColor: ModernTheme.success,
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Theme.of(context).colorScheme.onPrimary),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error al enviar reporte: ${e.toString()}',
                    style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                  ),
                ),
              ],
            ),
            backgroundColor: ModernTheme.error,
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Determinar prioridad del ticket según la categoría
  String _determinePriority(String category) {
    switch (category) {
      case 'safety_concern':
        return 'high';
      case 'driver_behavior':
      case 'payment_issue':
        return 'medium';
      default:
        return 'low';
    }
  }

  // Generar y compartir recibo PDF del viaje
  Future<void> _generateAndShareReceipt() async {
    try {
      // Mostrar indicador de carga
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onPrimary),
                  ),
                ),
                SizedBox(width: 12),
                Text('Generando recibo PDF...'),
              ],
            ),
            backgroundColor: ModernTheme.rappiOrange,
            duration: Duration(seconds: 2),
          ),
        );
      }

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userName = authProvider.currentUser?.fullName ?? 'Usuario';
      final userEmail = authProvider.currentUser?.email ?? '';

      // Crear documento PDF
      final pdf = pw.Document();

      // Agregar página al PDF
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Encabezado con logo y título
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'RAPPI TEAM',
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#10B981'),
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Recibo de Viaje',
                          style: pw.TextStyle(
                            fontSize: 16,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Recibo #${widget.trip.id.substring(0, 8).toUpperCase()}',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Fecha: ${widget.trip.requestedAt.day}/${widget.trip.requestedAt.month}/${widget.trip.requestedAt.year}',
                          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                        ),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 32),
                pw.Divider(thickness: 2, color: PdfColor.fromHex('#10B981')),
                pw.SizedBox(height: 24),

                // Información del pasajero
                pw.Text(
                  'INFORMACIÓN DEL PASAJERO',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800,
                  ),
                ),
                pw.SizedBox(height: 12),
                _buildPdfRow('Nombre', userName),
                _buildPdfRow('Email', userEmail),
                _buildPdfRow('ID Usuario', authProvider.currentUser?.id.substring(0, 12) ?? ''),

                pw.SizedBox(height: 24),

                // Información del conductor
                pw.Text(
                  'INFORMACIÓN DEL CONDUCTOR',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800,
                  ),
                ),
                pw.SizedBox(height: 12),
                _buildPdfRow('Nombre', widget.trip.vehicleInfo?['driverName'] ?? 'Conductor'),
                _buildPdfRow('Vehículo', '${widget.trip.vehicleInfo?['brand'] ?? ''} ${widget.trip.vehicleInfo?['model'] ?? ''}'.trim().isNotEmpty ? '${widget.trip.vehicleInfo?['brand']} ${widget.trip.vehicleInfo?['model']}' : 'No especificado'),
                _buildPdfRow('Placa', widget.trip.vehicleInfo?['plate'] ?? 'No especificado'),

                pw.SizedBox(height: 24),

                // Detalles del viaje
                pw.Text(
                  'DETALLES DEL VIAJE',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800,
                  ),
                ),
                pw.SizedBox(height: 12),
                _buildPdfRow('Origen', widget.trip.pickupAddress),
                _buildPdfRow('Destino', widget.trip.destinationAddress),
                _buildPdfRow('Distancia', '${widget.trip.estimatedDistance.toStringAsFixed(2)} km'),
                _buildPdfRow('Duración', widget.trip.tripDuration != null ? '${widget.trip.tripDuration!.inMinutes} min' : 'N/A'),
                _buildPdfRow('Fecha y Hora', _formatDateTime(widget.trip.requestedAt)),
                _buildPdfRow('Estado', _getStatusText(widget.trip.status)),

                pw.SizedBox(height: 24),

                // Información de pago
                pw.Container(
                  padding: pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F3F4F6'),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'INFORMACIÓN DE PAGO',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey800,
                        ),
                      ),
                      pw.SizedBox(height: 12),
                      _buildPdfRow('Método de pago', widget.trip.vehicleInfo?['paymentMethod'] ?? 'Efectivo'),
                      _buildPdfRow('Tarifa estimada', 'S/. ${widget.trip.estimatedFare.toStringAsFixed(2)}'),
                      if (widget.trip.finalFare != null)
                        _buildPdfRow('Tarifa final', 'S/. ${widget.trip.finalFare!.toStringAsFixed(2)}'),
                      pw.SizedBox(height: 8),
                      pw.Divider(),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'TOTAL PAGADO',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            'S/. ${(widget.trip.finalFare ?? widget.trip.estimatedFare).toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#10B981'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 24),

                // Calificación si existe
                if (widget.trip.driverRating != null && widget.trip.driverRating! > 0) ...[
                  pw.Text(
                    'CALIFICACIÓN AL CONDUCTOR',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey800,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    children: [
                      pw.Text(
                        '${widget.trip.driverRating!.toStringAsFixed(1)} ⭐',
                        style: pw.TextStyle(fontSize: 16),
                      ),
                      if (widget.trip.driverComment != null && widget.trip.driverComment!.isNotEmpty) ...[
                        pw.SizedBox(width: 12),
                        pw.Expanded(
                          child: pw.Text(
                            '"${widget.trip.driverComment}"',
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontStyle: pw.FontStyle.italic,
                              color: PdfColors.grey600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  pw.SizedBox(height: 16),
                ],

                // Pie de página
                pw.Spacer(),
                pw.Divider(),
                pw.SizedBox(height: 8),
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'Gracias por viajar con Rappi Team',
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Para soporte, contacta a: soporte@rapiteam.app',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Guardar PDF en almacenamiento temporal
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/recibo_${widget.trip.id.substring(0, 8)}.pdf');
      await file.writeAsBytes(await pdf.save());

      // Compartir el PDF
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Recibo de viaje - Rappi Team',
        text: 'Recibo del viaje del ${widget.trip.requestedAt.day}/${widget.trip.requestedAt.month}/${widget.trip.requestedAt.year}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Theme.of(context).colorScheme.onPrimary),
                SizedBox(width: 12),
                Text('Recibo PDF generado y compartido exitosamente'),
              ],
            ),
            backgroundColor: ModernTheme.success,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Theme.of(context).colorScheme.onPrimary),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Error al generar PDF: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: ModernTheme.error,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // Helper para construir filas del PDF
  pw.Widget _buildPdfRow(String label, String value) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                fontSize: 11,
                color: PdfColors.grey600,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Formatear fecha y hora
  String _formatDateTime(DateTime dateTime) {
    final months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return '${dateTime.day} de ${months[dateTime.month - 1]} de ${dateTime.year}, ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // Obtener texto del estado
  String _getStatusText(String status) {
    switch (status) {
      case 'completed':
        return 'Completado';
      case 'cancelled':
        return 'Cancelado';
      case 'in_progress':
        return 'En progreso';
      default:
        return status;
    }
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: context.primaryText,
          ),
        ),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
  
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.secondaryText),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(color: context.secondaryText),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}