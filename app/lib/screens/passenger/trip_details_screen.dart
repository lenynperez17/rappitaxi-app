import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/design/rt_colors.dart';
import '../../core/design/rt_tokens.dart';
import '../../core/design/rt_typography.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_avatar.dart';
import '../../core/widgets/rt_badge.dart';
import '../../core/widgets/rt_button.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../utils/firestore_error_handler.dart';
import '../../utils/logger.dart';

// ============================================================
// Modelos
// ============================================================

enum TripStatus { requested, driverAssigned, inProgress, completed, cancelled }

enum TripEventType {
  requested,
  driverAssigned,
  driverArrived,
  tripStarted,
  tripCompleted,
  paymentProcessed,
}

class LatLng {
  final double latitude;
  final double longitude;
  LatLng(this.latitude, this.longitude);
}

class TripLocation {
  final String address;
  final LatLng coordinates;
  final String landmark;

  TripLocation({
    required this.address,
    required this.coordinates,
    required this.landmark,
  });
}

class DriverInfo {
  final String id;
  final String name;
  final double rating;
  final int totalTrips;
  final String phone;
  final String photo;
  final VehicleInfo vehicle;

  DriverInfo({
    required this.id,
    required this.name,
    required this.rating,
    required this.totalTrips,
    required this.phone,
    required this.photo,
    required this.vehicle,
  });
}

class VehicleInfo {
  final String make;
  final String model;
  final int year;
  final String color;
  final String plate;

  VehicleInfo({
    required this.make,
    required this.model,
    required this.year,
    required this.color,
    required this.plate,
  });
}

class TripPricing {
  final double baseFare;
  final double distanceFare;
  final double timeFare;
  final double tip;
  final double discount;
  final double total;
  final String paymentMethod;

  TripPricing({
    required this.baseFare,
    required this.distanceFare,
    required this.timeFare,
    required this.tip,
    required this.discount,
    required this.total,
    required this.paymentMethod,
  });
}

class TripEvent {
  final DateTime time;
  final TripEventType type;
  final String description;

  TripEvent({
    required this.time,
    required this.type,
    required this.description,
  });
}

class TripReceipt {
  final String receiptNumber;
  final DateTime issueDate;
  final double taxAmount;
  final double subtotal;

  TripReceipt({
    required this.receiptNumber,
    required this.issueDate,
    required this.taxAmount,
    required this.subtotal,
  });
}

class TripDetail {
  final String id;
  final TripStatus status;
  final DateTime date;
  final TripLocation pickupLocation;
  final TripLocation destinationLocation;
  final DriverInfo driver;
  final TripPricing pricing;
  final List<TripEvent> timeline;
  final double distance;
  final int duration;
  final int? rating;
  final String? comment;
  final TripReceipt receipt;

  TripDetail({
    required this.id,
    required this.status,
    required this.date,
    required this.pickupLocation,
    required this.destinationLocation,
    required this.driver,
    required this.pricing,
    required this.timeline,
    required this.distance,
    required this.duration,
    this.rating,
    this.comment,
    required this.receipt,
  });
}

// ============================================================
// Pantalla principal
// ============================================================

class TripDetailsScreen extends StatefulWidget {
  final String tripId;

  const TripDetailsScreen({super.key, required this.tripId});

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  TripDetail? _tripDetail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTripDetails();
  }

  Future<void> _loadTripDetails() async {
    try {
      final tripDoc = await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.tripId)
          .get();

      if (!tripDoc.exists) {
        if (mounted) {
          setState(() => _isLoading = false);
          RtSnackbar.show(
            context,
            message: 'Viaje no encontrado',
            type: RtSnackbarType.error,
          );
          Navigator.pop(context);
        }
        return;
      }

      final tripData = tripDoc.data()!;

      // Información del conductor
      final driverDoc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(tripData['driverId'])
          .get();

      final driverData = driverDoc.exists ? driverDoc.data()! : null;

      // Parsear estado
      final status = _parseStatus(tripData['status']);

      // Timeline desde eventos
      final List<TripEvent> timeline = [];
      if (tripData['events'] != null) {
        for (final event in (tripData['events'] as List)) {
          timeline.add(TripEvent(
            time: (event['timestamp'] as Timestamp).toDate(),
            type: _parseEventType(event['type']),
            description: event['description'] ?? '',
          ));
        }
      }

      if (mounted) {
        setState(() {
          _tripDetail = TripDetail(
            id: widget.tripId,
            status: status,
            date: (tripData['createdAt'] as Timestamp).toDate(),
            pickupLocation: TripLocation(
              address: tripData['pickup']?['address'] ?? 'Dirección no disponible',
              coordinates: LatLng(
                tripData['pickup']?['lat'] ?? 0.0,
                tripData['pickup']?['lng'] ?? 0.0,
              ),
              landmark: tripData['pickup']?['landmark'] ?? '',
            ),
            destinationLocation: TripLocation(
              address: tripData['destination']?['address'] ?? 'Dirección no disponible',
              coordinates: LatLng(
                tripData['destination']?['lat'] ?? 0.0,
                tripData['destination']?['lng'] ?? 0.0,
              ),
              landmark: tripData['destination']?['landmark'] ?? '',
            ),
            driver: driverData != null
                ? DriverInfo(
                    id: tripData['driverId'],
                    name: driverData['name'] ?? 'Conductor',
                    rating: (driverData['rating'] ?? 0.0).toDouble(),
                    totalTrips: driverData['totalTrips'] ?? 0,
                    phone: driverData['phoneNumber'] ?? '',
                    photo: driverData['photoUrl'] ?? '',
                    vehicle: VehicleInfo(
                      make: driverData['vehicleMake'] ?? '',
                      model: driverData['vehicleModel'] ?? '',
                      year: driverData['vehicleYear'] ?? 0,
                      color: driverData['vehicleColor'] ?? '',
                      plate: driverData['vehiclePlate'] ?? '',
                    ),
                  )
                : DriverInfo(
                    id: tripData['driverId'] ?? '',
                    name: 'Conductor no disponible',
                    rating: 0.0,
                    totalTrips: 0,
                    phone: '',
                    photo: '',
                    vehicle: VehicleInfo(
                      make: 'N/A',
                      model: 'N/A',
                      year: 0,
                      color: 'N/A',
                      plate: 'N/A',
                    ),
                  ),
            pricing: TripPricing(
              baseFare: (tripData['pricing']?['baseFare'] ?? 0.0).toDouble(),
              distanceFare: (tripData['pricing']?['distanceFare'] ?? 0.0).toDouble(),
              timeFare: (tripData['pricing']?['timeFare'] ?? 0.0).toDouble(),
              tip: (tripData['pricing']?['tip'] ?? 0.0).toDouble(),
              discount: (tripData['pricing']?['discount'] ?? 0.0).toDouble(),
              total: (tripData['pricing']?['total'] ?? 0.0).toDouble(),
              paymentMethod: tripData['paymentMethod'] ?? 'No especificado',
            ),
            timeline: timeline,
            distance: (tripData['distance'] ?? 0.0).toDouble(),
            duration: tripData['duration'] ?? 0,
            rating: tripData['rating'],
            comment: tripData['comment'],
            receipt: TripReceipt(
              receiptNumber: 'REC-${widget.tripId}',
              issueDate: (tripData['createdAt'] as Timestamp).toDate(),
              taxAmount: (tripData['pricing']?['tax'] ?? 0.0).toDouble(),
              subtotal: (tripData['pricing']?['subtotal'] ?? 0.0).toDouble(),
            ),
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('Error al cargar detalles del viaje: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        RtSnackbar.show(
          context,
          message: FirestoreErrorHandler.getSpanishMessage(e),
          type: RtSnackbarType.error,
        );
        Navigator.pop(context);
      }
    }
  }

  TripStatus _parseStatus(String? status) {
    switch (status) {
      case 'completed':
        return TripStatus.completed;
      case 'cancelled':
        return TripStatus.cancelled;
      case 'in_progress':
        return TripStatus.inProgress;
      case 'requested':
        return TripStatus.requested;
      default:
        return TripStatus.requested;
    }
  }

  TripEventType _parseEventType(String? type) {
    switch (type) {
      case 'requested':
        return TripEventType.requested;
      case 'driver_assigned':
        return TripEventType.driverAssigned;
      case 'driver_arrived':
        return TripEventType.driverArrived;
      case 'trip_started':
        return TripEventType.tripStarted;
      case 'trip_completed':
        return TripEventType.tripCompleted;
      case 'payment_processed':
        return TripEventType.paymentProcessed;
      default:
        return TripEventType.requested;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RtColors.neutral50,
      appBar: RtAppBar(
        title: 'Detalles del Viaje',
        variant: RtAppBarVariant.gradient,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: _shareTrip,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: _handleMenuAction,
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'receipt',
                child: Row(
                  children: [
                    Icon(Icons.receipt, size: 18),
                    SizedBox(width: RtSpacing.sm),
                    Text('Ver recibo'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'repeat',
                child: Row(
                  children: [
                    Icon(Icons.repeat, size: 18),
                    SizedBox(width: RtSpacing.sm),
                    Text('Repetir viaje'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.report, size: 18, color: RtColors.error),
                    const SizedBox(width: RtSpacing.sm),
                    Text(
                      'Reportar problema',
                      style: RtTypo.bodyMedium.copyWith(color: RtColors.error),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: RtColors.brand),
            )
          : _buildTripDetails(),
    );
  }

  // ============================================================
  // Contenido principal
  // ============================================================

  Widget _buildTripDetails() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildStatusHeader(),
          _buildRouteSection(),
          _buildDriverSection(),
          _buildPricingSection(),
          _buildTimelineSection(),
          if (_tripDetail!.status == TripStatus.completed)
            _buildRatingSection(),
          const SizedBox(height: RtSpacing.xl),
        ],
      ),
    );
  }

  // ============================================================
  // Header de estado
  // ============================================================

  Widget _buildStatusHeader() {
    final trip = _tripDetail!;
    final statusColor = _getStatusColor();

    return Container(
      margin: const EdgeInsets.all(RtSpacing.base),
      padding: const EdgeInsets.all(RtSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor, statusColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: RtRadius.borderLg,
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(RtSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getStatusIcon(),
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: RtSpacing.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getStatusText(),
                      style: RtTypo.headingSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'ID: ${trip.id}',
                      style: RtTypo.bodySmall.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Text(
                trip.pricing.total.toCurrency(),
                style: RtTypo.headingMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: RtSpacing.base),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('${trip.distance} km', 'Distancia', Icons.straighten),
              _buildStatItem('${trip.duration} min', 'Duracion', Icons.schedule),
              _buildStatItem(_formatDate(trip.date), 'Fecha', Icons.calendar_today),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(height: RtSpacing.xs),
        Text(
          value,
          style: RtTypo.labelMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: RtTypo.labelSmall.copyWith(color: Colors.white70),
        ),
      ],
    );
  }

  // ============================================================
  // Seccion de ruta
  // ============================================================

  Widget _buildRouteSection() {
    return _buildSection(
      'Ruta del Viaje',
      Icons.route,
      RtColors.info,
      [
        _buildLocationCard(
          'Punto de recogida',
          _tripDetail!.pickupLocation,
          RtColors.success,
          Icons.my_location,
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: RtSpacing.sm),
          child: Row(
            children: [
              const SizedBox(width: RtSpacing.xl),
              Expanded(
                child: Container(
                  height: 2,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [RtColors.success, RtColors.error],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: RtSpacing.xl),
            ],
          ),
        ),
        _buildLocationCard(
          'Destino',
          _tripDetail!.destinationLocation,
          RtColors.error,
          Icons.location_on,
        ),
      ],
    );
  }

  Widget _buildLocationCard(
    String title,
    TripLocation location,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(RtSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: RtRadius.borderMd,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(RtSpacing.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: RtIconSize.sm),
          ),
          const SizedBox(width: RtSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: RtTypo.labelSmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  location.address,
                  style: RtTypo.bodyMedium.copyWith(
                    color: RtColors.neutral800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (location.landmark.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    location.landmark,
                    style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Seccion del conductor
  // ============================================================

  Widget _buildDriverSection() {
    final driver = _tripDetail!.driver;

    return _buildSection(
      'Información del Conductor',
      Icons.person,
      RtColors.brand,
      [
        Row(
          children: [
            RtAvatar(
              imageUrl: driver.photo,
              name: driver.name,
              size: RtAvatarSize.large,
            ),
            const SizedBox(width: RtSpacing.base),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    driver.name,
                    style: RtTypo.headingSmall.copyWith(
                      color: RtColors.neutral900,
                    ),
                  ),
                  const SizedBox(height: RtSpacing.xs),
                  Row(
                    children: [
                      ...List.generate(5, (index) {
                        return Icon(
                          Icons.star,
                          size: 16,
                          color: index < driver.rating.floor()
                              ? Colors.amber
                              : RtColors.neutral300,
                        );
                      }),
                      const SizedBox(width: RtSpacing.sm),
                      Text(
                        '${driver.rating} (${driver.totalTrips} viajes)',
                        style: RtTypo.bodySmall.copyWith(
                          color: RtColors.neutral500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _callDriver,
              icon: const Icon(Icons.phone, color: RtColors.info),
            ),
            IconButton(
              onPressed: _messageDriver,
              icon: const Icon(Icons.message, color: RtColors.brand),
            ),
          ],
        ),
        const SizedBox(height: RtSpacing.base),
        Container(
          padding: const EdgeInsets.all(RtSpacing.md),
          decoration: BoxDecoration(
            color: RtColors.neutral100,
            borderRadius: RtRadius.borderMd,
          ),
          child: Row(
            children: [
              const Icon(Icons.directions_car, color: RtColors.neutral500),
              const SizedBox(width: RtSpacing.md),
              Expanded(
                child: Text(
                  '${driver.vehicle.color} ${driver.vehicle.make} ${driver.vehicle.model} ${driver.vehicle.year}',
                  style: RtTypo.bodyMedium.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              RtBadge(
                label: driver.vehicle.plate,
                variant: RtBadgeVariant.subtle,
                color: RtColors.brand,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // Seccion de precios
  // ============================================================

  Widget _buildPricingSection() {
    final pricing = _tripDetail!.pricing;

    return _buildSection(
      'Desglose del Precio',
      Icons.receipt,
      RtColors.accentAmber,
      [
        _buildPriceRow('Tarifa base', pricing.baseFare),
        _buildPriceRow('Por distancia (${_tripDetail!.distance} km)', pricing.distanceFare),
        _buildPriceRow('Por tiempo (${_tripDetail!.duration} min)', pricing.timeFare),
        if (pricing.tip > 0) _buildPriceRow('Propina', pricing.tip),
        if (pricing.discount > 0)
          _buildPriceRow('Descuento', -pricing.discount, isDiscount: true),
        const Divider(),
        _buildPriceRow('Total', pricing.total, isTotal: true),
        const SizedBox(height: RtSpacing.md),
        Container(
          padding: const EdgeInsets.all(RtSpacing.md),
          decoration: BoxDecoration(
            color: RtColors.neutral100,
            borderRadius: RtRadius.borderMd,
          ),
          child: Row(
            children: [
              const Icon(Icons.payment, color: RtColors.neutral500),
              const SizedBox(width: RtSpacing.md),
              Text(
                'Método de pago: ${pricing.paymentMethod}',
                style: RtTypo.bodyMedium.copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow(
    String label,
    double amount, {
    bool isTotal = false,
    bool isDiscount = false,
  }) {
    Color? textColor;
    if (isTotal) {
      textColor = RtColors.brand;
    } else if (isDiscount) {
      textColor = RtColors.success;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: (isTotal ? RtTypo.titleMedium : RtTypo.bodyMedium).copyWith(
              color: textColor ?? RtColors.neutral800,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            amount.toCurrencyWithSign(),
            style: (isTotal ? RtTypo.titleMedium : RtTypo.bodyMedium).copyWith(
              color: textColor ?? RtColors.neutral800,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Seccion de cronologia
  // ============================================================

  Widget _buildTimelineSection() {
    return _buildSection(
      'Cronologia del Viaje',
      Icons.timeline,
      RtColors.accentPurple,
      [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _tripDetail!.timeline.length,
          itemBuilder: (context, index) {
            final event = _tripDetail!.timeline[index];
            final isLast = index == _tripDetail!.timeline.length - 1;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getEventColor(event.type),
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 40,
                        color: RtColors.neutral300,
                      ),
                  ],
                ),
                const SizedBox(width: RtSpacing.md),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: isLast ? 0 : RtSpacing.base,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.description,
                          style: RtTypo.bodyMedium.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _formatTime(event.time),
                          style: RtTypo.bodySmall.copyWith(
                            color: RtColors.neutral500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ============================================================
  // Seccion de calificación
  // ============================================================

  Widget _buildRatingSection() {
    return _buildSection(
      'Tu Calificación',
      Icons.star,
      Colors.amber,
      [
        Row(
          children: [
            ...List.generate(5, (index) {
              return Icon(
                Icons.star,
                size: 24,
                color: index < _tripDetail!.rating!
                    ? Colors.amber
                    : RtColors.neutral300,
              );
            }),
            const SizedBox(width: RtSpacing.md),
            Text(
              '${_tripDetail!.rating}/5',
              style: RtTypo.titleMedium.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        if (_tripDetail!.comment != null &&
            _tripDetail!.comment!.isNotEmpty) ...[
          const SizedBox(height: RtSpacing.md),
          Container(
            padding: const EdgeInsets.all(RtSpacing.md),
            decoration: BoxDecoration(
              color: RtColors.neutral100,
              borderRadius: RtRadius.borderMd,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.format_quote, color: RtColors.neutral400),
                const SizedBox(width: RtSpacing.sm),
                Expanded(
                  child: Text(
                    _tripDetail!.comment!,
                    style: RtTypo.bodyMedium.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ============================================================
  // Widget de seccion reutilizable
  // ============================================================

  Widget _buildSection(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: RtSpacing.base,
        vertical: RtSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: RtRadius.borderLg,
        boxShadow: RtShadow.soft(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(RtSpacing.base),
            child: Row(
              children: [
                Icon(icon, color: color, size: RtIconSize.sm),
                const SizedBox(width: RtSpacing.sm),
                Text(
                  title,
                  style: RtTypo.titleMedium.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              RtSpacing.base,
              0,
              RtSpacing.base,
              RtSpacing.base,
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Helpers de estado
  // ============================================================

  Color _getStatusColor() {
    switch (_tripDetail!.status) {
      case TripStatus.completed:
        return RtColors.success;
      case TripStatus.cancelled:
        return RtColors.error;
      case TripStatus.inProgress:
        return RtColors.warning;
      case TripStatus.requested:
      case TripStatus.driverAssigned:
        return RtColors.neutral500;
    }
  }

  IconData _getStatusIcon() {
    switch (_tripDetail!.status) {
      case TripStatus.completed:
        return Icons.check_circle;
      case TripStatus.cancelled:
        return Icons.cancel;
      case TripStatus.inProgress:
        return Icons.directions_car;
      case TripStatus.requested:
      case TripStatus.driverAssigned:
        return Icons.info;
    }
  }

  String _getStatusText() {
    switch (_tripDetail!.status) {
      case TripStatus.completed:
        return 'Viaje Completado';
      case TripStatus.cancelled:
        return 'Viaje Cancelado';
      case TripStatus.inProgress:
        return 'Viaje en Progreso';
      case TripStatus.requested:
        return 'Viaje Solicitado';
      case TripStatus.driverAssigned:
        return 'Conductor Asignado';
    }
  }

  Color _getEventColor(TripEventType type) {
    switch (type) {
      case TripEventType.requested:
        return RtColors.info;
      case TripEventType.driverAssigned:
        return RtColors.accentAmber;
      case TripEventType.driverArrived:
        return RtColors.accentPurple;
      case TripEventType.tripStarted:
        return RtColors.success;
      case TripEventType.tripCompleted:
        return RtColors.brand;
      case TripEventType.paymentProcessed:
        return RtColors.accentEmerald;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // Acciones
  // ============================================================

  Future<void> _shareTrip() async {
    final trip = _tripDetail;
    if (trip == null) return;

    try {
      final text = '''
Viaje RapiTeam

Desde: ${trip.pickupLocation.address}
Hasta: ${trip.destinationLocation.address}

Costo: ${trip.pricing.total.toCurrencyWithSign()}
Duracion: ${trip.duration} min
Distancia: ${trip.distance.toStringAsFixed(1)} km

Calificación: ${trip.rating != null ? '${trip.rating}/5' : 'Sin calificar'}

Conductor: ${trip.driver.name}
Placa: ${trip.driver.vehicle.plate}

Fecha: ${_formatDate(trip.date)} ${_formatTime(trip.date)}

ID de viaje: ${trip.id}
''';

      await Share.share(text, subject: 'Detalles de mi viaje en RapiTeam');
    } catch (e) {
      AppLogger.error('Error al compartir viaje: $e');
      if (mounted) {
        RtSnackbar.show(
          context,
          message: FirestoreErrorHandler.getSpanishMessage(e),
          type: RtSnackbarType.error,
        );
      }
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'receipt':
        _showReceipt();
        break;
      case 'repeat':
        _repeatTrip();
        break;
      case 'report':
        _reportProblem();
        break;
    }
  }

  Future<void> _showReceipt() async {
    final trip = _tripDetail;
    if (trip == null) return;

    try {
      RtSnackbar.show(
        context,
        message: 'Generando recibo PDF...',
        type: RtSnackbarType.info,
      );

      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'RECIBO DE VIAJE',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Center(child: pw.Text('RapiTeam', style: pw.TextStyle(fontSize: 16))),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Recibo N: ${trip.receipt.receiptNumber}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text('Fecha: ${_formatDate(trip.date)}'),
                ],
              ),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 20),
              pw.Text('DETALLES DEL VIAJE',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              _buildPdfRow('Origen', trip.pickupLocation.address),
              _buildPdfRow('Destino', trip.destinationLocation.address),
              _buildPdfRow('Distancia', '${trip.distance.toStringAsFixed(1)} km'),
              _buildPdfRow('Duracion', '${trip.duration} min'),
              pw.SizedBox(height: 20),
              pw.Text('CONDUCTOR',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              _buildPdfRow('Nombre', trip.driver.name),
              _buildPdfRow('Vehículo',
                  '${trip.driver.vehicle.color} ${trip.driver.vehicle.make} ${trip.driver.vehicle.model}'),
              _buildPdfRow('Placa', trip.driver.vehicle.plate),
              pw.SizedBox(height: 20),
              pw.Text('DESGLOSE DE COSTOS',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              _buildPdfRow('Tarifa base', trip.pricing.baseFare.toCurrencyWithSign()),
              _buildPdfRow('Por distancia', trip.pricing.distanceFare.toCurrencyWithSign()),
              _buildPdfRow('Por tiempo', trip.pricing.timeFare.toCurrencyWithSign()),
              if (trip.pricing.tip > 0)
                _buildPdfRow('Propina', trip.pricing.tip.toCurrencyWithSign()),
              if (trip.pricing.discount > 0)
                _buildPdfRow('Descuento', '- ${trip.pricing.discount.toCurrencyWithSign()}'),
              pw.Divider(thickness: 2),
              _buildPdfRow('TOTAL', trip.pricing.total.toCurrencyWithSign(), isTotal: true),
              pw.SizedBox(height: 10),
              _buildPdfRow('Método de pago', trip.pricing.paymentMethod),
              pw.Spacer(),
              pw.Center(
                child: pw.Text(
                  'Gracias por viajar con RapiTeam',
                  style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'Recibo_RapiTeam_${trip.id}.pdf',
      );
    } catch (e) {
      AppLogger.error('Error al generar recibo PDF: $e');
      if (mounted) {
        RtSnackbar.show(
          context,
          message: FirestoreErrorHandler.getSpanishMessage(e),
          type: RtSnackbarType.error,
        );
      }
    }
  }

  pw.Widget _buildPdfRow(String label, String value, {bool isTotal = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _repeatTrip() async {
    final trip = _tripDetail;
    if (trip == null) return;

    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: RtRadius.borderLg),
          title: const Text('Repetir viaje?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Se creará una nueva solicitud con:'),
              const SizedBox(height: RtSpacing.md),
              Row(
                children: [
                  const Icon(Icons.my_location, size: 16, color: RtColors.success),
                  const SizedBox(width: RtSpacing.sm),
                  Expanded(
                    child: Text(
                      trip.pickupLocation.address,
                      style: RtTypo.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: RtSpacing.sm),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: RtColors.error),
                  const SizedBox(width: RtSpacing.sm),
                  Expanded(
                    child: Text(
                      trip.destinationLocation.address,
                      style: RtTypo.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            RtButton(
              label: 'Repetir viaje',
              size: RtButtonSize.small,
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      );

      if (confirm != true || !mounted) return;

      Navigator.pushReplacementNamed(
        context,
        '/passenger/home',
        arguments: {
          'pickupAddress': trip.pickupLocation.address,
          'pickupLatLng': trip.pickupLocation.coordinates,
          'destinationAddress': trip.destinationLocation.address,
          'destinationLatLng': trip.destinationLocation.coordinates,
        },
      );
    } catch (e) {
      AppLogger.error('Error al repetir viaje: $e');
      if (mounted) {
        RtSnackbar.show(
          context,
          message: FirestoreErrorHandler.getSpanishMessage(e),
          type: RtSnackbarType.error,
        );
      }
    }
  }

  Future<void> _reportProblem() async {
    final trip = _tripDetail;
    if (trip == null) return;

    try {
      final issue = await showDialog<String>(
        context: context,
        builder: (context) => _ReportDialog(tripId: trip.id),
      );

      if (issue == null || issue.isEmpty || !mounted) return;

      RtSnackbar.show(
        context,
        message: 'Enviando reporte...',
        type: RtSnackbarType.info,
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      await FirebaseFirestore.instance.collection('supportTickets').add({
        'userId': user.uid,
        'tripId': trip.id,
        'issue': issue,
        'status': 'open',
        'priority': 'medium',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'metadata': {
          'tripDate': trip.date.toIso8601String(),
          'driverId': trip.driver.id,
          'driverName': trip.driver.name,
          'fare': trip.pricing.total,
        },
      });

      if (mounted) {
        RtSnackbar.show(
          context,
          message: 'Reporte enviado. Te contactaremos pronto.',
          type: RtSnackbarType.success,
        );
      }
    } catch (e) {
      AppLogger.error('Error al reportar problema: $e');
      if (mounted) {
        RtSnackbar.show(
          context,
          message: FirestoreErrorHandler.getSpanishMessage(e),
          type: RtSnackbarType.error,
        );
      }
    }
  }

  void _callDriver() {
    RtSnackbar.show(
      context,
      message: 'Llamando a ${_tripDetail!.driver.name}...',
      type: RtSnackbarType.info,
    );
  }

  void _messageDriver() {
    RtSnackbar.show(
      context,
      message: 'Abriendo chat con ${_tripDetail!.driver.name}...',
      type: RtSnackbarType.info,
    );
  }
}

// ============================================================
// Dialogo de reporte
// ============================================================

class _ReportDialog extends StatefulWidget {
  final String tripId;
  const _ReportDialog({required this.tripId});

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _controller = TextEditingController();
  String? _selectedIssue;

  static const List<String> _issues = [
    'Conductor no llego',
    'Cobro incorrecto',
    'Mala conduccion',
    'Vehículo sucio',
    'Conductor grosero',
    'Ruta incorrecta',
    'Demora excesiva',
    'Otro',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: RtRadius.borderLg),
      title: Row(
        children: [
          const Icon(Icons.report_problem, color: RtColors.warning),
          const SizedBox(width: RtSpacing.md),
          Text(
            'Reportar problema',
            style: RtTypo.headingSmall.copyWith(color: RtColors.neutral900),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tipo de problema',
              style: RtTypo.labelMedium.copyWith(
                color: RtColors.neutral700,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: RtSpacing.sm),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: RtColors.neutral300),
                borderRadius: RtRadius.borderMd,
              ),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedIssue,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: RtSpacing.base,
                    vertical: RtSpacing.sm,
                  ),
                  border: InputBorder.none,
                  hintText: 'Selecciona un tipo',
                ),
                items: _issues.map((issue) {
                  return DropdownMenuItem(value: issue, child: Text(issue));
                }).toList(),
                onChanged: (value) => setState(() => _selectedIssue = value),
              ),
            ),
            const SizedBox(height: RtSpacing.base),
            Text(
              'Descripción (opcional)',
              style: RtTypo.labelMedium.copyWith(
                color: RtColors.neutral700,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: RtSpacing.sm),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Cuéntanos más sobre el problema...',
                border: OutlineInputBorder(borderRadius: RtRadius.borderMd),
                contentPadding: const EdgeInsets.all(RtSpacing.md),
              ),
              maxLines: 4,
              maxLength: 500,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        RtButton(
          label: 'Enviar reporte',
          size: RtButtonSize.small,
          variant: RtButtonVariant.secondary,
          onPressed: _selectedIssue == null
              ? null
              : () {
                  final fullIssue = _selectedIssue! +
                      (_controller.text.isNotEmpty
                          ? ': ${_controller.text}'
                          : '');
                  Navigator.pop(context, fullIssue);
                },
        ),
      ],
    );
  }
}
