import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/design/rt_colors.dart';
import '../../core/design/rt_gradients.dart';
import '../../core/design/rt_tokens.dart';
import '../../core/design/rt_typography.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/rt_animated_list_item.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_badge.dart';
import '../../core/widgets/rt_button.dart';
import '../../core/widgets/rt_card.dart';
import '../../core/widgets/rt_empty_state.dart';
import '../../core/widgets/rt_loading_state.dart';
import '../../core/widgets/rt_section_header.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../core/widgets/rt_stats_card.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../models/trip_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ride_provider.dart';
import '../../utils/firestore_error_handler.dart';
import '../shared/rating_dialog.dart';

/// Pantalla de historial de viajes del pasajero.
/// Muestra estadísticas, filtros y lista de viajes con detalle en modal.
class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  String _selectedFilter = 'all';
  DateTimeRange? _dateRange;
  List<TripModel> _trips = [];
  bool _isLoading = true;

  // -- Estadísticas calculadas --

  Map<String, dynamic> get _stats {
    final completed =
        _filteredTrips.where((t) => t.status == 'completed').toList();
    final totalSpent = completed.fold<double>(
        0, (acc, t) => acc + (t.finalFare ?? t.estimatedFare));
    final totalDistance =
        completed.fold<double>(0, (acc, t) => acc + t.estimatedDistance);
    final rated = completed.where((t) => t.passengerRating != null);
    final avgRating = rated.isEmpty
        ? 0.0
        : rated.fold<double>(0, (acc, t) => acc + (t.passengerRating ?? 0)) /
            rated.length;

    return {
      'totalTrips': completed.length,
      'totalSpent': totalSpent,
      'totalDistance': totalDistance,
      'avgRating': avgRating,
    };
  }

  List<TripModel> get _filteredTrips {
    var filtered = _trips;

    if (_selectedFilter != 'all') {
      filtered = filtered.where((t) => t.status == _selectedFilter).toList();
    }

    if (_dateRange != null) {
      filtered = filtered.where((t) {
        return t.requestedAt.isAfter(_dateRange!.start) &&
            t.requestedAt
                .isBefore(_dateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }

    return filtered;
  }

  // -- Ciclo de vida --

  @override
  void initState() {
    super.initState();
    _loadTripsHistory();
  }

  Future<void> _loadTripsHistory() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ride = Provider.of<RideProvider>(context, listen: false);

    if (auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final trips = await ride.getUserTripHistory(auth.currentUser!.id);
      if (!mounted) return;
      setState(() {
        _trips = trips;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      debugPrint('Error cargando historial: $e');
    }
  }

  // -- Helpers --

  void _showMsg(String msg, RtSnackbarType type) {
    if (!mounted) return;
    RtSnackbar.show(context, message: msg, type: type);
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: RtColors.brand),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return RtColors.success;
      case 'cancelled':
        return RtColors.error;
      default:
        return RtColors.neutral500;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  String _formatDate(DateTime date) {
    final l10n = AppLocalizations.of(context)!;
    final diff = DateTime.now().difference(date).inDays;
    if (diff == 0) return l10n.today;
    if (diff == 1) return l10n.yesterday;
    if (diff < 7) return l10n.daysAgo(diff);
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  // -- Build principal --

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor:
          Theme.of(context).brightness == Brightness.dark
              ? RtColors.neutral950
              : RtColors.neutral50,
      appBar: RtAppBar(
        title: l10n.tripHistory,
        variant: RtAppBarVariant.solid,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_rounded, size: RtIconSize.sm),
            onPressed: _selectDateRange,
            tooltip: l10n.date,
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded, size: RtIconSize.sm),
            onPressed: () => _showMsg(l10n.downloading, RtSnackbarType.info),
            tooltip: l10n.downloading,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: RtColors.brand,
        backgroundColor: Theme.of(context).colorScheme.surface,
        onRefresh: _loadTripsHistory,
        child: _isLoading
            ? const Padding(
                padding: EdgeInsets.all(RtSpacing.base),
                child: RtLoadingState.list(),
              )
            : CustomScrollView(
                slivers: [
                  // Estadísticas
                  SliverToBoxAdapter(child: _buildStatsRow()),
                  // Filtros
                  SliverToBoxAdapter(child: _buildFilters()),
                  // Rango de fecha activo
                  if (_dateRange != null)
                    SliverToBoxAdapter(child: _buildDateRangeChip()),
                  // Lista o estado vacio
                  if (_filteredTrips.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: RtEmptyState(
                        icon: Icons.history_rounded,
                        title: l10n.noTrips,
                        description: l10n.adjustFilters,
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: RtSpacing.base,
                        vertical: RtSpacing.sm,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => RtAnimatedListItem(
                            index: i,
                            child: _buildTripCard(_filteredTrips[i]),
                          ),
                          childCount: _filteredTrips.length,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  // -- Widgets de estadísticas --

  Widget _buildStatsRow() {
    final stats = _stats;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          RtSpacing.base, RtSpacing.base, RtSpacing.base, RtSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: RtStatsCard(
              label: l10n.trips,
              value: '${stats['totalTrips']}',
              icon: Icons.route_rounded,
              iconColor: RtColors.brand,
              gradient: RtGradients.brand,
            ),
          ),
          const SizedBox(width: RtSpacing.sm),
          Expanded(
            child: RtStatsCard(
              label: l10n.spent,
              value: (stats['totalSpent'] as double).toCurrency(),
              icon: Icons.account_balance_wallet_rounded,
              iconColor: RtColors.success,
            ),
          ),
          const SizedBox(width: RtSpacing.sm),
          Expanded(
            child: RtStatsCard(
              label: l10n.distance,
              value:
                  '${(stats['totalDistance'] as double).toStringAsFixed(1)} km',
              icon: Icons.map_rounded,
              iconColor: RtColors.info,
            ),
          ),
        ],
      ),
    );
  }

  // -- Filtros --

  Widget _buildFilters() {
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
          horizontal: RtSpacing.base, vertical: RtSpacing.sm),
      child: Row(
        children: [
          _buildFilterChip(l10n.all, 'all'),
          const SizedBox(width: RtSpacing.sm),
          _buildFilterChip(l10n.completed, 'completed'),
          const SizedBox(width: RtSpacing.sm),
          _buildFilterChip(l10n.cancelled, 'cancelled'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = value),
      selectedColor: RtColors.brand,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? RtColors.neutral800
          : RtColors.white,
      labelStyle: RtTypo.labelMedium.copyWith(
        color: isSelected ? RtColors.white : RtColors.neutral600,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: RtRadius.borderFull,
        side: BorderSide(
          color: isSelected ? RtColors.brand : RtColors.neutral300,
        ),
      ),
    );
  }

  Widget _buildDateRangeChip() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: RtSpacing.base),
      child: Row(
        children: [
          RtBadge(
            label:
                '${_dateRange!.start.day}/${_dateRange!.start.month} - ${_dateRange!.end.day}/${_dateRange!.end.month}',
            color: RtColors.info,
            variant: RtBadgeVariant.subtle,
            icon: Icons.calendar_today_rounded,
          ),
          const SizedBox(width: RtSpacing.sm),
          GestureDetector(
            onTap: () => setState(() => _dateRange = null),
            child: const Icon(
                Icons.close_rounded, size: RtIconSize.sm, color: RtColors.neutral500),
          ),
        ],
      ),
    );
  }

  // -- Card de viaje --

  Widget _buildTripCard(TripModel trip) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fare = (trip.finalFare ?? trip.estimatedFare).toCurrency();
    final color = _statusColor(trip.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: RtSpacing.md),
      child: RtCard(
        variant: RtCardVariant.elevated,
        onTap: () => _showTripDetails(trip),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado: fecha + precio
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(_statusIcon(trip.status),
                          color: color, size: RtIconSize.sm),
                    ),
                    const SizedBox(width: RtSpacing.md),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_formatDate(trip.requestedAt),
                            style: RtTypo.labelLarge),
                        Text(_formatTime(trip.requestedAt),
                            style: RtTypo.bodySmall
                                .copyWith(color: RtColors.neutral500)),
                      ],
                    ),
                  ],
                ),
                Text(fare,
                    style: RtTypo.titleMedium
                        .copyWith(color: RtColors.brand)),
              ],
            ),

            const SizedBox(height: RtSpacing.base),

            // Ruta: puntos verde y rojo conectados con linea
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: RtColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 28,
                      color: isDark ? RtColors.neutral600 : RtColors.neutral300,
                    ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: RtColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: RtSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(trip.pickupAddress,
                          style: RtTypo.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 18),
                      Text(trip.destinationAddress,
                          style: RtTypo.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: RtSpacing.md),

            // Pie: conductor + rating
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: RtColors.brand.withValues(alpha: 0.1),
                        child: const Icon(Icons.person_rounded,
                            size: 14, color: RtColors.brand),
                      ),
                      const SizedBox(width: RtSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.driver,
                                style: RtTypo.labelSmall
                                    .copyWith(fontWeight: FontWeight.w600)),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded,
                                    size: 12, color: RtColors.warning),
                                const SizedBox(width: 2),
                                Text(
                                  (trip.driverRating ?? 5.0)
                                      .toStringAsFixed(1),
                                  style: RtTypo.labelSmall
                                      .copyWith(color: RtColors.neutral500),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (trip.status == 'completed' &&
                    trip.passengerRating != null)
                  RtBadge(
                    label: l10n.yourRating(
                        trip.passengerRating?.toStringAsFixed(1) ?? ''),
                    color: RtColors.warning,
                    variant: RtBadgeVariant.subtle,
                    icon: Icons.star_rounded,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // -- Modal de detalles --

  void _showTripDetails(TripModel trip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TripDetailsModal(trip: trip),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// Modal de detalles del viaje
// ══════════════════════════════════════════════════════════════════════

class TripDetailsModal extends StatefulWidget {
  final TripModel trip;

  const TripDetailsModal({super.key, required this.trip});

  @override
  State<TripDetailsModal> createState() => _TripDetailsModalState();
}

class _TripDetailsModalState extends State<TripDetailsModal> {
  void _showMsg(String msg, RtSnackbarType type) {
    if (!mounted) return;
    RtSnackbar.show(context, message: msg, type: type);
  }

  // -- Build principal del modal --

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trip = widget.trip;
    final isCompleted = trip.status == 'completed';
    final statusColor = isCompleted ? RtColors.success : RtColors.error;
    final statusText = isCompleted ? l10n.completedStatus : l10n.cancelledStatus;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: isDark ? RtColors.neutral900 : RtColors.white,
        borderRadius: RtRadius.sheetTop,
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: RtSpacing.md),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: RtColors.neutral300,
              borderRadius: RtRadius.borderFull,
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(RtSpacing.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.tripDetails, style: RtTypo.headingSmall),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: RtSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ID y estado
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('ID: ${trip.id}',
                          style: RtTypo.bodySmall
                              .copyWith(color: RtColors.neutral500)),
                      RtBadge(
                        label: statusText,
                        color: statusColor,
                        variant: RtBadgeVariant.subtle,
                      ),
                    ],
                  ),

                  const SizedBox(height: RtSpacing.xl),

                  // Ruta
                  _buildDetailSection(
                    l10n.tripRoute,
                    [
                      _buildDetailRow(Icons.trip_origin_rounded,
                          l10n.origin, trip.pickupAddress),
                      _buildDetailRow(Icons.location_on_rounded,
                          l10n.destination, trip.destinationAddress),
                      _buildDetailRow(Icons.route_rounded, l10n.distance,
                          '${trip.estimatedDistance.toStringAsFixed(1)} km'),
                      _buildDetailRow(
                          Icons.timer_rounded,
                          l10n.duration,
                          trip.tripDuration?.inMinutes.toString() ??
                              'N/A min'),
                    ],
                  ),

                  const SizedBox(height: RtSpacing.lg),

                  // Conductor
                  _buildDetailSection(
                    l10n.driver,
                    [
                      _buildDetailRow(Icons.person_rounded,
                          'ID ${l10n.driver}', trip.driverId ?? 'N/A'),
                      _buildDetailRow(Icons.star_rounded, l10n.rating,
                          '${trip.driverRating ?? 'N/A'}'),
                      _buildDetailRow(
                          Icons.directions_car_rounded,
                          l10n.vehicle,
                          trip.vehicleInfo?.toString() ?? 'N/A'),
                    ],
                  ),

                  const SizedBox(height: RtSpacing.lg),

                  // Pago
                  _buildDetailSection(
                    l10n.payment,
                    [
                      _buildDetailRow(
                          Icons.account_balance_wallet_rounded,
                          l10n.amount,
                          (trip.finalFare ?? trip.estimatedFare).toCurrency()),
                      _buildDetailRow(Icons.payment_rounded, l10n.method,
                          l10n.defaultCash),
                    ],
                  ),

                  // Boton calificar (si no ha calificado)
                  if (isCompleted && trip.passengerRating == null) ...[
                    const SizedBox(height: RtSpacing.xl),
                    SizedBox(
                      width: double.infinity,
                      child: RtButton(
                        label: l10n.rateTrip,
                        icon: Icons.star_rounded,
                        variant: RtButtonVariant.primary,
                        onPressed: () {
                          Navigator.pop(context);
                          RatingDialog.show(
                            context: context,
                            driverName: trip.driverId ?? 'Conductor',
                            driverPhoto: '',
                            tripId: trip.id,
                            onSubmit: (rating, comment, tags) async {
                              await _updateTripRating(
                                  trip.id, rating.toDouble(), comment ?? '', tags);
                            },
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: RtSpacing.xl),

                  // Botones de accion
                  Row(
                    children: [
                      Expanded(
                        child: RtButton(
                          label: l10n.reportProblem,
                          icon: Icons.help_outline_rounded,
                          variant: RtButtonVariant.outlined,
                          onPressed: _showReportProblemDialog,
                        ),
                      ),
                      const SizedBox(width: RtSpacing.md),
                      Expanded(
                        child: RtButton(
                          label: l10n.viewReceipt,
                          icon: Icons.receipt_rounded,
                          variant: RtButtonVariant.outlined,
                          onPressed: _generateAndShareReceipt,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: RtSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -- Seccion y fila de detalle reutilizables --

  Widget _buildDetailSection(String title, List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RtSectionHeader(title: title),
        const SizedBox(height: RtSpacing.sm),
        Container(
          padding: const EdgeInsets.all(RtSpacing.base),
          decoration: BoxDecoration(
            color: isDark ? RtColors.neutral800 : RtColors.neutral50,
            borderRadius: RtRadius.borderMd,
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: RtSpacing.xs + 2),
      child: Row(
        children: [
          Icon(icon, size: RtIconSize.sm, color: RtColors.neutral500),
          const SizedBox(width: RtSpacing.md),
          Expanded(
            flex: 2,
            child: Text(label,
                style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: RtSpacing.sm),
          Expanded(
            flex: 3,
            child: Text(value,
                style: RtTypo.bodySmall.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }

  // -- Calificación del viaje --

  Future<void> _updateTripRating(
      String tripId, double rating, String comment, List<String> tags) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.currentUser?.id;
    if (userId == null) return;

    final l10n = AppLocalizations.of(context)!;
    final ride = Provider.of<RideProvider>(context, listen: false);

    try {
      await ride.updateTripRating(tripId, userId, rating, comment, tags);
      if (!mounted) return;
      _showMsg(l10n.ratingSubmittedSuccessfully, RtSnackbarType.success);
    } catch (e) {
      if (!mounted) return;
      _showMsg(FirestoreErrorHandler.getSpanishMessage(e), RtSnackbarType.error);
    }
  }

  // -- Reporte de problema --

  void _showReportProblemDialog() {
    final descController = TextEditingController();
    String? selectedCategory;

    final categories = {
      'driver_behavior': 'Comportamiento del conductor',
      'route_issue': 'Problema con la ruta',
      'payment_issue': 'Problema de pago',
      'safety_concern': 'Preocupacion de seguridad',
      'vehicle_condition': 'Condicion del vehículo',
      'pricing_dispute': 'Disputa de precio',
      'other': 'Otro',
    };

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: RtRadius.borderLg),
          title: Row(
            children: [
              const Icon(Icons.report_problem_rounded, color: RtColors.warning),
              const SizedBox(width: RtSpacing.md),
              Text('Reportar Problema', style: RtTypo.titleLarge),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Selecciona la categoria del problema:',
                    style: RtTypo.labelMedium),
                const SizedBox(height: RtSpacing.md),

                // Dropdown categorias
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: RtSpacing.md),
                  decoration: BoxDecoration(
                    border: Border.all(color: RtColors.neutral300),
                    borderRadius: RtRadius.borderMd,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      hint: const Text('Seleccionar categoria'),
                      value: selectedCategory,
                      items: categories.entries
                          .map((e) => DropdownMenuItem(
                              value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedCategory = v),
                    ),
                  ),
                ),

                const SizedBox(height: RtSpacing.base),
                Text('Describe el problema:', style: RtTypo.labelMedium),
                const SizedBox(height: RtSpacing.md),

                TextField(
                  controller: descController,
                  maxLines: 5,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: 'Por favor describe el problema en detalle...',
                    border: OutlineInputBorder(borderRadius: RtRadius.borderMd),
                    contentPadding: const EdgeInsets.all(RtSpacing.base),
                  ),
                ),

                const SizedBox(height: RtSpacing.sm),

                // Info del viaje
                Container(
                  padding: const EdgeInsets.all(RtSpacing.md),
                  decoration: BoxDecoration(
                    color: RtColors.neutral100,
                    borderRadius: RtRadius.borderSm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Información del viaje:',
                          style: RtTypo.labelSmall
                              .copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: RtSpacing.xs),
                      Text('ID: ${widget.trip.id}',
                          style: RtTypo.labelSmall
                              .copyWith(color: RtColors.neutral500)),
                      Text(
                          'Fecha: ${widget.trip.requestedAt.day}/${widget.trip.requestedAt.month}/${widget.trip.requestedAt.year}',
                          style: RtTypo.labelSmall
                              .copyWith(color: RtColors.neutral500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                descController.dispose();
                Navigator.pop(dialogCtx);
              },
              child: const Text('Cancelar'),
            ),
            RtButton(
              label: 'Enviar Reporte',
              variant: RtButtonVariant.primary,
              size: RtButtonSize.small,
              onPressed: selectedCategory == null ||
                      descController.text.trim().isEmpty
                  ? null
                  : () async {
                      final desc = descController.text.trim();
                      Navigator.pop(dialogCtx);
                      await _submitProblemReport(
                        category: selectedCategory!,
                        categoryName: categories[selectedCategory]!,
                        description: desc,
                      );
                      descController.dispose();
                    },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitProblemReport({
    required String category,
    required String categoryName,
    required String description,
  }) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.currentUser?.id;
    final userName = auth.currentUser?.fullName ?? 'Usuario';

    if (userId == null) {
      _showMsg('Usuario no autenticado', RtSnackbarType.error);
      return;
    }

    try {
      final driverName =
          widget.trip.vehicleInfo?['driverName'] ?? 'Conductor';

      await FirebaseFirestore.instance.collection('supportTickets').add({
        'userId': userId,
        'userName': userName,
        'tripId': widget.trip.id,
        'driverId': widget.trip.driverId,
        'driverName': driverName,
        'category': category,
        'categoryName': categoryName,
        'description': description,
        'status': 'pending',
        'priority': _determinePriority(category),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'tripDate': widget.trip.requestedAt,
        'tripOrigin': widget.trip.pickupAddress,
        'tripDestination': widget.trip.destinationAddress,
        'tripPrice': widget.trip.finalFare ?? widget.trip.estimatedFare,
        'resolved': false,
        'adminResponse': null,
        'resolvedAt': null,
      });

      _showMsg(
          'Reporte enviado exitosamente. Nuestro equipo lo revisará pronto.',
          RtSnackbarType.success);
    } catch (e) {
      _showMsg(FirestoreErrorHandler.getSpanishMessage(e), RtSnackbarType.error);
    }
  }

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

  // -- Generacion de recibo PDF --

  Future<void> _generateAndShareReceipt() async {
    try {
      _showMsg('Generando recibo PDF...', RtSnackbarType.info);

      final auth = Provider.of<AuthProvider>(context, listen: false);
      final userName = auth.currentUser?.fullName ?? 'Usuario';
      final userEmail = auth.currentUser?.email ?? '';
      final trip = widget.trip;

      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Encabezado
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('RAPITEAM',
                          style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#E31E24'))),
                      pw.SizedBox(height: 4),
                      pw.Text('Recibo de Viaje',
                          style: pw.TextStyle(
                              fontSize: 16, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                          'Recibo #${trip.id.substring(0, 8).toUpperCase()}',
                          style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text(
                          'Fecha: ${trip.requestedAt.day}/${trip.requestedAt.month}/${trip.requestedAt.year}',
                          style: pw.TextStyle(
                              fontSize: 10, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 32),
              pw.Divider(
                  thickness: 2, color: PdfColor.fromHex('#E31E24')),
              pw.SizedBox(height: 24),

              // Pasajero
              _pdfSectionTitle('INFORMACION DEL PASAJERO'),
              pw.SizedBox(height: 12),
              _pdfRow('Nombre', userName),
              _pdfRow('Email', userEmail),
              _pdfRow('ID Usuario',
                  auth.currentUser?.id.substring(0, 12) ?? ''),
              pw.SizedBox(height: 24),

              // Conductor
              _pdfSectionTitle('INFORMACION DEL CONDUCTOR'),
              pw.SizedBox(height: 12),
              _pdfRow('Nombre',
                  trip.vehicleInfo?['driverName'] ?? 'Conductor'),
              _pdfRow(
                  'Vehículo',
                  '${trip.vehicleInfo?['brand'] ?? ''} ${trip.vehicleInfo?['model'] ?? ''}'
                              .trim()
                              .isNotEmpty
                      ? '${trip.vehicleInfo?['brand']} ${trip.vehicleInfo?['model']}'
                      : 'No especificado'),
              _pdfRow(
                  'Placa', trip.vehicleInfo?['plate'] ?? 'No especificado'),
              pw.SizedBox(height: 24),

              // Detalles del viaje
              _pdfSectionTitle('DETALLES DEL VIAJE'),
              pw.SizedBox(height: 12),
              _pdfRow('Origen', trip.pickupAddress),
              _pdfRow('Destino', trip.destinationAddress),
              _pdfRow('Distancia',
                  '${trip.estimatedDistance.toStringAsFixed(2)} km'),
              _pdfRow(
                  'Duracion',
                  trip.tripDuration != null
                      ? '${trip.tripDuration!.inMinutes} min'
                      : 'N/A'),
              _pdfRow('Fecha y Hora', _formatDateTime(trip.requestedAt)),
              _pdfRow('Estado', _getStatusText(trip.status)),
              pw.SizedBox(height: 24),

              // Pago
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F3F4F6'),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _pdfSectionTitle('INFORMACION DE PAGO'),
                    pw.SizedBox(height: 12),
                    _pdfRow('Método de pago',
                        trip.vehicleInfo?['paymentMethod'] ?? 'Efectivo'),
                    _pdfRow('Tarifa estimada',
                        'S/. ${trip.estimatedFare.toStringAsFixed(2)}'),
                    if (trip.finalFare != null)
                      _pdfRow('Tarifa final',
                          'S/. ${trip.finalFare!.toStringAsFixed(2)}'),
                    pw.SizedBox(height: 8),
                    pw.Divider(),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('TOTAL PAGADO',
                            style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold)),
                        pw.Text(
                            'S/. ${(trip.finalFare ?? trip.estimatedFare).toStringAsFixed(2)}',
                            style: pw.TextStyle(
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColor.fromHex('#E31E24'))),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),

              // Calificación
              if (trip.driverRating != null && trip.driverRating! > 0) ...[
                _pdfSectionTitle('CALIFICACION AL CONDUCTOR'),
                pw.SizedBox(height: 8),
                pw.Row(
                  children: [
                    pw.Text('${trip.driverRating!.toStringAsFixed(1)} *',
                        style: const pw.TextStyle(fontSize: 16)),
                    if (trip.driverComment != null &&
                        trip.driverComment!.isNotEmpty) ...[
                      pw.SizedBox(width: 12),
                      pw.Expanded(
                        child: pw.Text('"${trip.driverComment}"',
                            style: pw.TextStyle(
                                fontSize: 11,
                                fontStyle: pw.FontStyle.italic,
                                color: PdfColors.grey600)),
                      ),
                    ],
                  ],
                ),
                pw.SizedBox(height: 16),
              ],

              // Pie
              pw.Spacer(),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('Gracias por viajar con RapiTeam',
                        style: pw.TextStyle(
                            fontSize: 12, color: PdfColors.grey600)),
                    pw.SizedBox(height: 4),
                    pw.Text(
                        'Para soporte, contacta a: soporte@rapiteam.app',
                        style: pw.TextStyle(
                            fontSize: 10, color: PdfColors.grey500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      final output = await getTemporaryDirectory();
      final file =
          File('${output.path}/recibo_${trip.id.substring(0, 8)}.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Recibo de viaje - RapiTeam',
        text:
            'Recibo del viaje del ${trip.requestedAt.day}/${trip.requestedAt.month}/${trip.requestedAt.year}',
      );

      _showMsg('Recibo PDF generado y compartido exitosamente',
          RtSnackbarType.success);
    } catch (e) {
      _showMsg(FirestoreErrorHandler.getSpanishMessage(e), RtSnackbarType.error);
    }
  }

  // -- Helpers del PDF --

  pw.Widget _pdfSectionTitle(String title) {
    return pw.Text(title,
        style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800));
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text('$label:',
                style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
    ];
    return '${dt.day} de ${months[dt.month - 1]} de ${dt.year}, '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

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
}
