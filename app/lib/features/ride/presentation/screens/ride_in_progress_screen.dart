import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/oasis_button.dart';
import '../../../../shared/models/location_model.dart';

class RideInProgressScreen extends ConsumerStatefulWidget {
  final LocationModel pickup;
  final LocationModel destination;
  final String vehicleType;
  final String paymentMethod;
  final double fare;
  final Map<String, dynamic> driver;
  
  const RideInProgressScreen({
    super.key,
    required this.pickup,
    required this.destination,
    required this.vehicleType,
    required this.paymentMethod,
    required this.fare,
    required this.driver,
  });
  
  @override
  ConsumerState<RideInProgressScreen> createState() => _RideInProgressScreenState();
}

class _RideInProgressScreenState extends ConsumerState<RideInProgressScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  
  RideStatus _rideStatus = RideStatus.driverOnTheWay;
  Timer? _statusTimer;
  int _eta = 5; // Minutos estimados
  
  @override
  void initState() {
    super.initState();
    _setupMapElements();
    _simulateRideProgress();
  }
  
  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }
  
  void _setupMapElements() {
    _markers = {
      Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(widget.pickup.latitude, widget.pickup.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: 'Recogida', snippet: widget.pickup.address),
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(widget.destination.latitude, widget.destination.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: 'Destino', snippet: widget.destination.address),
      ),
      // Marcador del conductor
      Marker(
        markerId: const MarkerId('driver'),
        position: LatLng(
          widget.pickup.latitude - 0.01,
          widget.pickup.longitude - 0.01,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'Tu conductor'),
      ),
    };
    
    _polylines = {
      Polyline(
        polylineId: const PolylineId('route'),
        points: [
          LatLng(widget.pickup.latitude, widget.pickup.longitude),
          LatLng(widget.destination.latitude, widget.destination.longitude),
        ],
        color: AppTheme.primaryColor,
        width: 4,
      ),
    };
  }
  
  void _simulateRideProgress() {
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        if (_eta > 0) _eta--;
        
        switch (_rideStatus) {
          case RideStatus.driverOnTheWay:
            if (_eta <= 2) {
              _rideStatus = RideStatus.driverArrived;
              _eta = 0;
            }
            break;
          case RideStatus.driverArrived:
            // Simular que el pasajero sube después de 10 segundos
            Future.delayed(const Duration(seconds: 10), () {
              if (mounted) {
                setState(() {
                  _rideStatus = RideStatus.inTrip;
                  _eta = 12; // Tiempo estimado del viaje
                });
              }
            });
            break;
          case RideStatus.inTrip:
            if (_eta <= 0) {
              _rideStatus = RideStatus.arrived;
              timer.cancel();
              _showRideCompleted();
            }
            break;
          case RideStatus.arrived:
            timer.cancel();
            break;
        }
      });
    });
  }
  
  void _showRideCompleted() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        context.pushReplacement('/ride/completed', extra: {
          'fare': widget.fare,
          'driver': widget.driver,
          'pickup': widget.pickup,
          'destination': widget.destination,
        });
      }
    });
  }
  
  void _callDriver() async {
    final phoneNumber = 'tel:+51999999999'; // Número simulado
    if (await canLaunchUrl(Uri.parse(phoneNumber))) {
      await launchUrl(Uri.parse(phoneNumber));
    }
  }
  
  void _shareTrip() {
    // TODO: Implementar compartir viaje
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Compartiendo información del viaje...'),
        // backgroundColor: AppTheme.primaryColor,
      ),
    );
  }
  
  void _cancelRide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cancelar viaje?'),
        content: const Text(
          'Si cancelas el viaje después de que el conductor haya aceptado, '
          'se te podría cobrar una tarifa de cancelación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/home');
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
            ),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Mapa
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(widget.pickup.latitude, widget.pickup.longitude),
              zoom: 15,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
            },
          ),
          
          // Botón de centrar mapa
          Positioned(
            right: 16,
            bottom: 320,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.my_location),
                onPressed: () {
                  // TODO: Centrar en ubicación actual
                },
              ),
            ),
          ),
          
          // Panel superior con información del estado
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getStatusColor(),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    _getStatusIcon(),
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getStatusTitle(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_eta > 0)
                          Text(
                            'Llegada en $_eta min',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_rideStatus == RideStatus.driverArrived)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Esperando',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: -0.2, end: 0),
          ),
          
          // Panel inferior con información del conductor
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Indicador de arrastre
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Información del conductor
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              // backgroundColor: AppTheme.primaryColor,
                              child: Text(
                                widget.driver['name'].split(' ')[0][0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.driver['name'],
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        color: Colors.amber,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text('${widget.driver['rating']}'),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${widget.driver['trips']} viajes',
                                        style: TextStyle(
                                          color: AppTheme.textSecondaryColor,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Botones de acción
                            Row(
                              children: [
                                IconButton(
                                  onPressed: _callDriver,
                                  icon: const Icon(
                                    Icons.phone,
                                    color: AppTheme.primaryColor,
                                  ),
                                  style: IconButton.styleFrom(
                                    // backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: () {
                                    // TODO: Abrir chat
                                  },
                                  icon: const Icon(
                                    Icons.message,
                                    color: AppTheme.primaryColor,
                                  ),
                                  style: IconButton.styleFrom(
                                    // backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Información del vehículo
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                widget.driver['vehicle'],
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  widget.driver['plate'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Botones de acción
                        Row(
                          children: [
                            Expanded(
                              child: OasisButton(
                                text: 'Compartir viaje',
                                onPressed: _shareTrip,
                                isOutlined: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OasisButton(
                                text: 'Cancelar',
                                onPressed: _rideStatus == RideStatus.inTrip ? () {} : _cancelRide,
                                isOutlined: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().slideY(begin: 1, end: 0, duration: 400.ms),
          ),
        ],
      ),
    );
  }
  
  Color _getStatusColor() {
    switch (_rideStatus) {
      case RideStatus.driverOnTheWay:
        return AppTheme.primaryColor;
      case RideStatus.driverArrived:
        return AppTheme.successColor;
      case RideStatus.inTrip:
        return AppTheme.accentColor;
      case RideStatus.arrived:
        return AppTheme.successColor;
    }
  }
  
  IconData _getStatusIcon() {
    switch (_rideStatus) {
      case RideStatus.driverOnTheWay:
        return Icons.directions_car;
      case RideStatus.driverArrived:
        return Icons.location_on;
      case RideStatus.inTrip:
        return Icons.navigation;
      case RideStatus.arrived:
        return Icons.flag;
    }
  }
  
  String _getStatusTitle() {
    switch (_rideStatus) {
      case RideStatus.driverOnTheWay:
        return 'Tu conductor está en camino';
      case RideStatus.driverArrived:
        return 'Tu conductor ha llegado';
      case RideStatus.inTrip:
        return 'En viaje a tu destino';
      case RideStatus.arrived:
        return '¡Has llegado!';
    }
  }
}

enum RideStatus {
  driverOnTheWay,
  driverArrived,
  inTrip,
  arrived,
}