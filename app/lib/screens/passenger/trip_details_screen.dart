// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/extensions/theme_extensions.dart'; // ✅ Extensión para colores que se adaptan al tema
import '../../core/utils/currency_formatter.dart';
import '../../utils/logger.dart';
class TripDetailsScreen extends StatefulWidget {
  final String tripId;
  
  const TripDetailsScreen({super.key, required this.tripId});
  
  @override
  _TripDetailsScreenState createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> 
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  
  // Trip data
  TripDetail? _tripDetail;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    
    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    );
    
    _loadTripDetails();
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }
  
  void _loadTripDetails() async {
    try {
      // ✅ Consultar viaje real desde Firebase
      final tripDoc = await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.tripId)
          .get();

      if (!tripDoc.exists) {
        // Viaje no encontrado
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Viaje no encontrado'),
              backgroundColor: ModernTheme.error,
            ),
          );
          Navigator.pop(context);
        }
        return;
      }

      final tripData = tripDoc.data()!;

      // ✅ Consultar información del conductor desde Firebase
      final driverDoc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(tripData['driverId'])
          .get();

      final driverData = driverDoc.exists ? driverDoc.data()! : null;

      // ✅ Parsear estado del viaje
      TripStatus status;
      switch (tripData['status']) {
        case 'completed':
          status = TripStatus.completed;
          break;
        case 'cancelled':
          status = TripStatus.cancelled;
          break;
        case 'in_progress':
          status = TripStatus.inProgress;
          break;
        case 'requested':
          status = TripStatus.requested;
          break;
        default:
          status = TripStatus.requested;
      }

      // ✅ Construir timeline desde eventos reales de Firebase
      List<TripEvent> timeline = [];
      if (tripData['events'] != null) {
        for (var event in (tripData['events'] as List)) {
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

        _fadeController.forward();
        _slideController.forward();
      }
    } catch (e) {
      AppLogger.error('❌ Error al cargar detalles del viaje: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar el viaje: ${e.toString()}'),
            backgroundColor: ModernTheme.error,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  // ✅ Función helper para parsear tipos de eventos
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
      backgroundColor: context.surfaceColor,
      appBar: AppBar(
        backgroundColor: ModernTheme.rappiOrange,
        elevation: 0,
        title: Text(
          'Detalles del Viaje',
          style: TextStyle(
            color: Theme.of(context).colorScheme.surface,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share, color: Theme.of(context).colorScheme.onPrimary),
            onPressed: _shareTrip,
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onPrimary),
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'receipt',
                child: Row(
                  children: [
                    Icon(Icons.receipt, size: 18),
                    SizedBox(width: 8),
                    Text('Ver recibo'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'repeat',
                child: Row(
                  children: [
                    Icon(Icons.repeat, size: 18),
                    SizedBox(width: 8),
                    Text('Repetir viaje'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.report, size: 18, color: ModernTheme.error),
                    SizedBox(width: 8),
                    Text('Reportar problema', style: TextStyle(color: ModernTheme.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading ? _buildLoadingState() : _buildTripDetailsWithMap(),
    );
  }
  
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(ModernTheme.rappiOrange),
          ),
          SizedBox(height: 16),
          Text(
            'Cargando detalles del viaje...',
            style: TextStyle(
              color: context.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Layout con mapa en la parte superior (40% de la pantalla)
  /// y detalles en DraggableScrollableSheet desde abajo
  Widget _buildTripDetailsWithMap() {
    return Stack(
      children: [
        // Mapa placeholder en la parte superior (40% de la pantalla)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: MediaQuery.of(context).size.height * 0.42,
          child: Container(
            color: Colors.grey.shade200,
            child: Stack(
              children: [
                // Fondo representando el mapa con gradiente
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.blueGrey.shade100,
                        Colors.blueGrey.shade200,
                      ],
                    ),
                  ),
                ),
                // Icono de mapa centrado
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.map_outlined,
                        size: 64,
                        color: ModernTheme.rappiOrange.withValues(alpha: 0.5),
                      ),
                      SizedBox(height: 8),
                      // Ruta origen → destino sobre el "mapa"
                      if (_tripDetail != null)
                        Container(
                          margin: EdgeInsets.symmetric(horizontal: 24),
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Column(
                                children: [
                                  Icon(Icons.radio_button_checked, size: 16, color: ModernTheme.success),
                                  Container(width: 2, height: 20, color: Colors.grey.shade300),
                                  Icon(Icons.location_on, size: 16, color: ModernTheme.error),
                                ],
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _tripDetail!.pickupLocation.address,
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      _tripDetail!.destinationLocation.address,
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // DraggableScrollableSheet con los detalles del viaje
        DraggableScrollableSheet(
          initialChildSize: 0.62, // Inicia ocupando 62% (deja 38% para el mapa)
          minChildSize: 0.35,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Handle
                  Container(
                    margin: EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Contenido scrolleable
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _fadeAnimation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _fadeAnimation.value,
                          child: ListView(
                            controller: scrollController,
                            padding: EdgeInsets.zero,
                            children: [
                              _buildStatusHeader(),
                              _buildRouteSection(),
                              _buildDriverSection(),
                              _buildPricingSection(),
                              _buildTimelineSection(),
                              if (_tripDetail!.status == TripStatus.completed)
                                _buildRatingSection(),
                              SizedBox(height: 24),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTripDetails() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Trip status header
                _buildStatusHeader(),

                // Route information
                _buildRouteSection(),

                // Driver information
                _buildDriverSection(),

                // Pricing breakdown
                _buildPricingSection(),

                // Trip timeline
                _buildTimelineSection(),

                // Rating and feedback
                if (_tripDetail!.status == TripStatus.completed)
                  _buildRatingSection(),

                SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildStatusHeader() {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - _slideAnimation.value)),
          child: Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _getStatusGradient(),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _getStatusColor().withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getStatusIcon(),
                        color: Theme.of(context).colorScheme.surface,
                        size: 28,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getStatusText(),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.surface,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'ID: ${_tripDetail!.id}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _tripDetail!.pricing.total.toCurrency(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.surface,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      '${_tripDetail!.distance} km',
                      'Distancia',
                      Icons.straighten,
                    ),
                    _buildStatItem(
                      '${_tripDetail!.duration} min',
                      'Duración',
                      Icons.schedule,
                    ),
                    _buildStatItem(
                      _formatDate(_tripDetail!.date),
                      'Fecha',
                      Icons.calendar_today,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7), size: 16),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Theme.of(context).colorScheme.surface,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  Widget _buildRouteSection() {
    return _buildSection(
      'Ruta del Viaje',
      Icons.route,
      ModernTheme.primaryBlue,
      [
        _buildLocationCard(
          'Punto de recogida',
          _tripDetail!.pickupLocation,
          ModernTheme.success,
          Icons.my_location,
        ),
        Container(
          margin: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(width: 24),
              Expanded(
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [ModernTheme.success, ModernTheme.error],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 24),
            ],
          ),
        ),
        _buildLocationCard(
          'Destino',
          _tripDetail!.destinationLocation,
          ModernTheme.error,
          Icons.location_on,
        ),
      ],
    );
  }
  
  Widget _buildLocationCard(String title, TripLocation location, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  location.address,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                if (location.landmark.isNotEmpty) ...[
                  SizedBox(height: 2),
                  Text(
                    location.landmark,
                    style: TextStyle(
                      color: context.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDriverSection() {
    return _buildSection(
      'Información del Conductor',
      Icons.person,
      ModernTheme.rappiOrange,
      [
        Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: ModernTheme.rappiOrange,
              child: Text(
                _tripDetail!.driver.name.split(' ').map((n) => n[0]).take(2).join(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.surface,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _tripDetail!.driver.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            Icons.star,
                            size: 16,
                            color: index < _tripDetail!.driver.rating.floor()
                                ? Colors.amber
                                : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                          );
                        }),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '${_tripDetail!.driver.rating} (${_tripDetail!.driver.totalTrips} viajes)',
                        style: TextStyle(
                          color: context.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _callDriver,
              icon: Icon(Icons.phone, color: ModernTheme.primaryBlue),
            ),
            IconButton(
              onPressed: _messageDriver,
              icon: Icon(Icons.message, color: ModernTheme.rappiOrange),
            ),
          ],
        ),
        SizedBox(height: 16),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.directions_car, color: context.secondaryText),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${_tripDetail!.driver.vehicle.color} ${_tripDetail!.driver.vehicle.make} ${_tripDetail!.driver.vehicle.model} ${_tripDetail!.driver.vehicle.year}',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _tripDetail!.driver.vehicle.plate,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: ModernTheme.rappiOrange,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildPricingSection() {
    return _buildSection(
      'Desglose del Precio',
      Icons.receipt,
      Colors.orange,
      [
        _buildPriceRow('Tarifa base', _tripDetail!.pricing.baseFare),
        _buildPriceRow('Por distancia (${_tripDetail!.distance} km)', _tripDetail!.pricing.distanceFare),
        _buildPriceRow('Por tiempo (${_tripDetail!.duration} min)', _tripDetail!.pricing.timeFare),
        if (_tripDetail!.pricing.tip > 0)
          _buildPriceRow('Propina', _tripDetail!.pricing.tip),
        if (_tripDetail!.pricing.discount > 0)
          _buildPriceRow('Descuento', -_tripDetail!.pricing.discount, isDiscount: true),
        Divider(),
        _buildPriceRow('Total', _tripDetail!.pricing.total, isTotal: true),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.payment, color: context.secondaryText),
              SizedBox(width: 12),
              Text(
                'Método de pago: ${_tripDetail!.pricing.paymentMethod}',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildPriceRow(String label, double amount, {bool isTotal = false, bool isDiscount = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
              color: isDiscount ? ModernTheme.success : null,
            ),
          ),
          Text(
            amount.toCurrencyWithSign(),
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              fontSize: isTotal ? 16 : 14,
              color: isTotal 
                  ? ModernTheme.rappiOrange 
                  : isDiscount 
                      ? ModernTheme.success 
                      : null,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTimelineSection() {
    return _buildSection(
      'Cronología del Viaje',
      Icons.timeline,
      Colors.purple,
      [
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
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
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                      ),
                  ],
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.description,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _formatTime(event.time),
                          style: TextStyle(
                            color: context.secondaryText,
                            fontSize: 12,
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
  
  Widget _buildRatingSection() {
    return _buildSection(
      'Tu Calificación',
      Icons.star,
      Colors.amber,
      [
        Row(
          children: [
            Row(
              children: List.generate(5, (index) {
                return Icon(
                  Icons.star,
                  size: 24,
                  color: index < _tripDetail!.rating!
                      ? Colors.amber
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                );
              }),
            ),
            SizedBox(width: 12),
            Text(
              '${_tripDetail!.rating}/5',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        if (_tripDetail!.comment != null && _tripDetail!.comment!.isNotEmpty) ...[
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.format_quote, color: context.secondaryText),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _tripDetail!.comment!,
                    style: TextStyle(
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
  
  Widget _buildSection(String title, IconData icon, Color color, List<Widget> children) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getStatusColor() {
    switch (_tripDetail!.status) {
      case TripStatus.completed:
        return ModernTheme.success;
      case TripStatus.cancelled:
        return ModernTheme.error;
      case TripStatus.inProgress:
        return ModernTheme.warning;
      default:
        return context.secondaryText;
    }
  }
  
  List<Color> _getStatusGradient() {
    final color = _getStatusColor();
    return [color, color.withValues(alpha: 0.8)];
  }
  
  IconData _getStatusIcon() {
    switch (_tripDetail!.status) {
      case TripStatus.completed:
        return Icons.check_circle;
      case TripStatus.cancelled:
        return Icons.cancel;
      case TripStatus.inProgress:
        return Icons.directions_car;
      default:
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
      default:
        return 'Estado Desconocido';
    }
  }
  
  Color _getEventColor(TripEventType type) {
    switch (type) {
      case TripEventType.requested:
        return Colors.blue;
      case TripEventType.driverAssigned:
        return Colors.orange;
      case TripEventType.driverArrived:
        return Colors.purple;
      case TripEventType.tripStarted:
        return ModernTheme.success;
      case TripEventType.tripCompleted:
        return ModernTheme.rappiOrange;
      case TripEventType.paymentProcessed:
        return Colors.indigo;
      default:
        return Theme.of(context).colorScheme.onSurface.withOpacity(0.6);
    }
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
  
  /// ✅ COMPARTIR VIAJE CON SHARE_PLUS
  Future<void> _shareTrip() async {
    final trip = _tripDetail;
    if (trip == null) {
      AppLogger.warning('⚠️ No hay detalles del viaje para compartir');
      return;
    }

    try {
      final text = '''
🚕 Viaje Rappi Team

📍 Desde: ${trip.pickupLocation.address}
📍 Hasta: ${trip.destinationLocation.address}

💰 Costo: ${trip.pricing.total.toCurrencyWithSign()}
🕐 Duración: ${trip.duration} min
📏 Distancia: ${trip.distance.toStringAsFixed(1)} km

⭐ Calificación: ${trip.rating != null ? '${trip.rating}/5' : 'Sin calificar'}

🚗 Conductor: ${trip.driver.name}
🔢 Placa: ${trip.driver.vehicle.plate}

📅 Fecha: ${_formatDate(trip.date)} ${_formatTime(trip.date)}

ID de viaje: ${trip.id}
''';

      await Share.share(
        text,
        subject: 'Detalles de mi viaje en Rappi Team',
      );

      AppLogger.info('✅ Viaje compartido exitosamente');
    } catch (e) {
      AppLogger.error('❌ Error al compartir viaje: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al compartir: ${e.toString()}'),
            backgroundColor: ModernTheme.error,
          ),
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
  
  /// ✅ GENERAR Y MOSTRAR RECIBO PDF
  Future<void> _showReceipt() async {
    final trip = _tripDetail;
    if (trip == null) {
      AppLogger.warning('⚠️ No hay detalles del viaje para generar recibo');
      return;
    }

    try {
      // Mostrar loading
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
            backgroundColor: ModernTheme.info,
            duration: Duration(seconds: 2),
          ),
        );
      }

      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
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
              pw.Center(
                child: pw.Text(
                  'Rappi Team',
                  style: pw.TextStyle(fontSize: 16),
                ),
              ),
              pw.SizedBox(height: 20),

              // Número de recibo y fecha
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Recibo N°: ${trip.receipt.receiptNumber}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text('Fecha: ${_formatDate(trip.date)}'),
                ],
              ),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 20),

              // Información del viaje
              pw.Text(
                'DETALLES DEL VIAJE',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              _buildPdfRow('Origen', trip.pickupLocation.address),
              _buildPdfRow('Destino', trip.destinationLocation.address),
              _buildPdfRow('Distancia', '${trip.distance.toStringAsFixed(1)} km'),
              _buildPdfRow('Duración', '${trip.duration} min'),
              pw.SizedBox(height: 20),

              // Información del conductor
              pw.Text(
                'CONDUCTOR',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              _buildPdfRow('Nombre', trip.driver.name),
              _buildPdfRow(
                'Vehículo',
                '${trip.driver.vehicle.color} ${trip.driver.vehicle.make} ${trip.driver.vehicle.model}',
              ),
              _buildPdfRow('Placa', trip.driver.vehicle.plate),
              pw.SizedBox(height: 20),

              // Desglose de costos
              pw.Text(
                'DESGLOSE DE COSTOS',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              _buildPdfRow(
                'Tarifa base',
                trip.pricing.baseFare.toCurrencyWithSign(),
              ),
              _buildPdfRow(
                'Por distancia',
                trip.pricing.distanceFare.toCurrencyWithSign(),
              ),
              _buildPdfRow(
                'Por tiempo',
                trip.pricing.timeFare.toCurrencyWithSign(),
              ),
              if (trip.pricing.tip > 0)
                _buildPdfRow(
                  'Propina',
                  trip.pricing.tip.toCurrencyWithSign(),
                ),
              if (trip.pricing.discount > 0)
                _buildPdfRow(
                  'Descuento',
                  '- ${trip.pricing.discount.toCurrencyWithSign()}',
                ),

              pw.Divider(thickness: 2),

              _buildPdfRow(
                'TOTAL',
                trip.pricing.total.toCurrencyWithSign(),
                isTotal: true,
              ),

              pw.SizedBox(height: 10),
              _buildPdfRow('Método de pago', trip.pricing.paymentMethod),

              pw.Spacer(),

              // Footer
              pw.Center(
                child: pw.Text(
                  'Gracias por viajar con Rappi Team',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      // Mostrar preview y permitir compartir/imprimir
      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'Recibo_RappiTeam_${trip.id}.pdf',
      );

      AppLogger.info('✅ Recibo PDF generado exitosamente');
    } catch (e) {
      AppLogger.error('❌ Error al generar recibo PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar recibo: ${e.toString()}'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }

  /// ✅ Helper para construir filas en el PDF
  pw.Widget _buildPdfRow(String label, String value, {bool isTotal = false}) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 4),
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
  
  /// ✅ REPETIR VIAJE (copiar origen/destino a nueva solicitud)
  Future<void> _repeatTrip() async {
    final trip = _tripDetail;
    if (trip == null) {
      AppLogger.warning('⚠️ No hay detalles del viaje para repetir');
      return;
    }

    try {
      // Confirmar acción
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text('¿Repetir viaje?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Se creará una nueva solicitud con:'),
              SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.my_location, size: 16, color: ModernTheme.success),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      trip.pickupLocation.address,
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: ModernTheme.error),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      trip.destinationLocation.address,
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.rappiOrange,
              ),
              child: Text('Repetir viaje'),
            ),
          ],
        ),
      );

      if (confirm != true || !mounted) return;

      // Navegar a home con datos pre-cargados
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

      AppLogger.info('✅ Navegando a home para repetir viaje');
    } catch (e) {
      AppLogger.error('❌ Error al repetir viaje: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al repetir viaje: ${e.toString()}'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }
  
  /// ✅ REPORTAR PROBLEMA (crear ticket de soporte en Firestore)
  Future<void> _reportProblem() async {
    final trip = _tripDetail;
    if (trip == null) {
      AppLogger.warning('⚠️ No hay detalles del viaje para reportar');
      return;
    }

    try {
      final issue = await showDialog<String>(
        context: context,
        builder: (context) => _ReportDialog(tripId: trip.id),
      );

      if (issue == null || issue.isEmpty || !mounted) return;

      // Mostrar loading
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
              Text('Enviando reporte...'),
            ],
          ),
          backgroundColor: ModernTheme.info,
        ),
      );

      // Crear ticket de soporte en Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

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

      AppLogger.info('✅ Reporte de problema enviado exitosamente');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Theme.of(context).colorScheme.onPrimary),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Reporte enviado. Te contactaremos pronto.'),
                ),
              ],
            ),
            backgroundColor: ModernTheme.success,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('❌ Error al reportar problema: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar reporte: ${e.toString()}'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }
  
  void _callDriver() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Llamando a ${_tripDetail!.driver.name}...'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
  
  void _messageDriver() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Abriendo chat con ${_tripDetail!.driver.name}...'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
}

// ✅ WIDGET DE DIÁLOGO PARA REPORTAR PROBLEMAS
class _ReportDialog extends StatefulWidget {
  final String tripId;
  const _ReportDialog({required this.tripId});

  @override
  _ReportDialogState createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _controller = TextEditingController();
  String? _selectedIssue;

  final List<String> _issues = [
    'Conductor no llegó',
    'Cobro incorrecto',
    'Mala conducción',
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Icon(Icons.report_problem, color: ModernTheme.warning),
          SizedBox(width: 12),
          Text('Reportar problema'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tipo de problema',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonFormField<String>(
                value: _selectedIssue,
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  border: InputBorder.none,
                  hintText: 'Selecciona un tipo',
                ),
                items: _issues.map((issue) {
                  return DropdownMenuItem(
                    value: issue,
                    child: Text(issue),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedIssue = value),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Descripción (opcional)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Cuéntanos más sobre el problema...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: EdgeInsets.all(12),
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
          child: Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _selectedIssue == null
              ? null
              : () {
                  final fullIssue = _selectedIssue! +
                      (_controller.text.isNotEmpty
                          ? ': ${_controller.text}'
                          : '');
                  Navigator.pop(context, fullIssue);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: ModernTheme.warning,
            disabledBackgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          child: Text('Enviar reporte'),
        ),
      ],
    );
  }
}

// Models
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

class LatLng {
  final double latitude;
  final double longitude;
  
  LatLng(this.latitude, this.longitude);
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

enum TripStatus { requested, driverAssigned, inProgress, completed, cancelled }

enum TripEventType {
  requested,
  driverAssigned,
  driverArrived,
  tripStarted,
  tripCompleted,
  paymentProcessed,
}