import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../../shared/providers/riverpod_compat.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/oasis_button.dart';
import '../../../../shared/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../home/presentation/providers/location_provider.dart';
import '../providers/driver_status_provider.dart';
import '../widgets/driver_status_card.dart';
import '../widgets/ride_request_card.dart';

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  GoogleMapController? _mapController;
  
  @override
  void initState() {
    super.initState();
    // Iniciar actualización de ubicación cuando el conductor esté online
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startLocationUpdates();
    });
  }
  
  void _startLocationUpdates() {
    ref.listen(driverStatusProvider, (previous, next) {
      next.whenData((status) {
        if (status == 'online' || status == 'busy' || status == 'in_ride') {
          // Actualizar ubicación cada 10 segundos cuando esté activo
          _updateLocation();
        }
      });
    });
  }
  
  Future<void> _updateLocation() async {
    final position = await ref.read(currentLocationProvider.future);
    if (position != null) {
      final repository = ref.read(driverRepositoryProvider);
      await repository.updateDriverLocation(
        position.latitude,
        position.longitude,
      );
    }
  }
  
  Future<void> _centerOnCurrentLocation() async {
    final position = await ref.read(currentLocationProvider.future);
    if (position != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          15,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final driverStatusAsync = ref.watch(driverStatusProvider);
    final rideRequestsAsync = ref.watch(rideRequestsProvider);
    final todayEarningsAsync = ref.watch(todayEarningsProvider);
    final driverRatingAsync = ref.watch(driverRatingProvider);
    final statusNotifier = ref.watch(driverStatusNotifierProvider);
    final requestActions = ref.watch(rideRequestActionsProvider);
    
    return Scaffold(
      body: Stack(
        children: [
          // Mapa
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(-12.0464, -77.0428), // Lima
              zoom: 15,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapType: MapType.normal,
          ),
          
          // Overlay superior
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Header con estado del conductor
                      driverStatusAsync.when(
                        data: (status) {
                          final earnings = todayEarningsAsync.value ?? 0.0;
                          final rating = driverRatingAsync.value ?? 5.0;
                          
                          return DriverStatusCard(
                            status: status,
                            earnings: earnings,
                            rating: rating,
                            onStatusChanged: (newStatus) {
                              ref.read(driverStatusNotifierProvider.notifier)
                                  .updateStatus(newStatus);
                            },
                          );
                        },
                        loading: () => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Lista de solicitudes de viaje
          DraggableScrollableSheet(
            initialChildSize: 0.3,
            minChildSize: 0.15,
            maxChildSize: 0.7,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Handle
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    
                    // Título
                    driverStatusAsync.when(
                      data: (status) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              status == 'online' 
                                  ? 'Solicitudes de viaje'
                                  : status == 'busy' || status == 'in_ride'
                                      ? 'En viaje'
                                      : 'Sin conexión',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (status == 'online')
                              rideRequestsAsync.when(
                                data: (requests) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${requests.length} activas',
                                    style: TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                loading: () => const SizedBox.shrink(),
                                error: (_, __) => const SizedBox.shrink(),
                              ),
                          ],
                        ),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    
                    // Lista de solicitudes
                    Expanded(
                      child: driverStatusAsync.when(
                        data: (status) {
                          if (status == 'online') {
                            return rideRequestsAsync.when(
                              data: (requests) {
                                if (requests.isEmpty) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.hourglass_empty,
                                          size: 64,
                                          color: Colors.grey[300],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Esperando solicitudes...',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                color: Colors.grey[600],
                                              ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Te notificaremos cuando haya\nnuevos viajes disponibles',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: Colors.grey[500],
                                              ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                
                                return ListView.separated(
                                  controller: scrollController,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  itemCount: requests.length,
                                  separatorBuilder: (_, __) => 
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final request = requests[index];
                                    return RideRequestCard(
                                      request: request,
                                      onAccept: () async {
                                        try {
                                          await requestActions.acceptRequest(request.id);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Solicitud aceptada'),
                                                // backgroundColor: Colors.green,
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Error: $e'),
                                                // backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      onReject: () async {
                                        try {
                                          await requestActions.rejectRequest(request.id);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Solicitud rechazada'),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Error: $e'),
                                                // backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                    ).animate()
                                        .fadeIn(delay: Duration(
                                          milliseconds: index * 100,
                                        ))
                                        .slideY(begin: 0.2, end: 0);
                                  },
                                );
                              },
                              loading: () => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              error: (error, _) => Center(
                                child: Text('Error: $error'),
                              ),
                            );
                          } else if (status == 'busy' || status == 'in_ride') {
                            // Mostrar información del viaje actual
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.directions_car,
                                    size: 64,
                                    color: AppTheme.primaryColor,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Viaje en progreso',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: AppTheme.primaryColor,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Completa tu viaje actual para\nrecibir nuevas solicitudes',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Colors.grey[500],
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            );
                          } else {
                            // Offline
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.wifi_off,
                                    size: 64,
                                    color: Colors.grey[300],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Estás desconectado',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: Colors.grey[600],
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Activa tu estado para recibir\nsolicitudes de viaje',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Colors.grey[500],
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),
                                  OasisButton(
                                    text: 'Conectarme',
                                    onPressed: statusNotifier.isLoading
                                        ? () {}
                                        : () {
                                            ref.read(driverStatusNotifierProvider.notifier)
                                                .updateStatus('online');
                                          },
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                        loading: () => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        error: (error, _) => Center(
                          child: Text('Error: $error'),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          
          // Botón de ubicación
          Positioned(
            right: 16,
            bottom: 350,
            child: FloatingActionButton(
              mini: true,
              // backgroundColor: Colors.white,
              foregroundColor: AppTheme.primaryColor,
              onPressed: _centerOnCurrentLocation,
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}