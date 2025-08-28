import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/oasis_button.dart';
import '../../../../shared/models/location_model.dart';

class SearchingDriverScreen extends ConsumerStatefulWidget {
  final LocationModel pickup;
  final LocationModel destination;
  final String vehicleType;
  final String paymentMethod;
  final double estimatedFare;
  
  const SearchingDriverScreen({
    super.key,
    required this.pickup,
    required this.destination,
    required this.vehicleType,
    required this.paymentMethod,
    required this.estimatedFare,
  });
  
  @override
  ConsumerState<SearchingDriverScreen> createState() => _SearchingDriverScreenState();
}

class _SearchingDriverScreenState extends ConsumerState<SearchingDriverScreen> {
  Timer? _searchTimer;
  int _searchSeconds = 0;
  bool _driverFound = false;
  
  @override
  void initState() {
    super.initState();
    _startSearching();
  }
  
  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }
  
  void _startSearching() {
    _searchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _searchSeconds++;
      });
      
      // Simular encontrar conductor después de 5 segundos
      if (_searchSeconds >= 5 && !_driverFound) {
        setState(() {
          _driverFound = true;
        });
        
        // Navegar a pantalla de viaje en progreso después de 2 segundos
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _searchTimer?.cancel();
            context.pushReplacement('/ride/in-progress', extra: {
              'pickup': widget.pickup,
              'destination': widget.destination,
              'vehicleType': widget.vehicleType,
              'paymentMethod': widget.paymentMethod,
              'fare': widget.estimatedFare,
              'driver': {
                'name': 'Carlos Rodriguez',
                'rating': 4.8,
                'vehicle': 'Toyota Corolla Blanco',
                'plate': 'ABC-123',
                'photo': null,
                'trips': 1250,
              },
            });
          }
        });
      }
      
      // Timeout después de 60 segundos
      if (_searchSeconds >= 60) {
        _searchTimer?.cancel();
        _showNoDriversDialog();
      }
    });
  }
  
  void _cancelSearch() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cancelar búsqueda?'),
        content: const Text('¿Estás seguro de que deseas cancelar la búsqueda de conductor?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No, continuar'),
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
  
  void _showNoDriversDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('No hay conductores disponibles'),
        content: const Text(
          'Lo sentimos, no hay conductores disponibles en este momento. Por favor, intenta nuevamente en unos minutos.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/home');
            },
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animación de búsqueda
              Container(
                width: 200,
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Círculos animados
                    ...List.generate(3, (index) {
                      return Container(
                        width: 150 + (index * 30).toDouble(),
                        height: 150 + (index * 30).toDouble(),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.primaryColor.withOpacity(0.3 - (index * 0.1)),
                            width: 2,
                          ),
                        ),
                      )
                          .animate(onPlay: (controller) => controller.repeat())
                          .scale(
                            begin: const Offset(0.8, 0.8),
                            end: const Offset(1.2, 1.2),
                            duration: Duration(seconds: 2 + index),
                            curve: Curves.easeInOut,
                          )
                          .fade(
                            begin: 1,
                            end: 0,
                            duration: Duration(seconds: 2 + index),
                          );
                    }),
                    
                    // Icono del carro
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: _driverFound ? AppTheme.successColor : AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _driverFound ? Icons.check : Icons.directions_car,
                        color: Colors.white,
                        size: 40,
                      ),
                    ).animate().scale(delay: 200.ms),
                  ],
                ),
              ),
              
              const SizedBox(height: 48),
              
              // Título
              Text(
                _driverFound ? '¡Conductor encontrado!' : 'Buscando conductor...',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(),
              
              const SizedBox(height: 16),
              
              // Subtítulo
              Text(
                _driverFound
                    ? 'Tu conductor está en camino'
                    : 'Estamos buscando el mejor conductor para ti',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 200.ms),
              
              const SizedBox(height: 32),
              
              // Información del conductor (si se encontró)
              if (_driverFound) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        // backgroundColor: AppTheme.primaryColor,
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Carlos Rodriguez',
                              style: TextStyle(
                                fontSize: 16,
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
                                const Text('4.8'),
                                const SizedBox(width: 8),
                                Text(
                                  '• Toyota Corolla',
                                  style: TextStyle(
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn()
                    .slideY(begin: 0.2, end: 0),
              ] else ...[
                // Detalles del viaje mientras busca
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildLocationRow(
                        icon: Icons.circle,
                        iconColor: AppTheme.primaryColor,
                        location: widget.pickup.address,
                      ),
                      Container(
                        margin: const EdgeInsets.only(left: 12),
                        height: 20,
                        width: 1,
                        color: Colors.grey.shade300,
                      ),
                      _buildLocationRow(
                        icon: Icons.location_on,
                        iconColor: AppTheme.accentColor,
                        location: widget.destination.address,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Tiempo de búsqueda
                Text(
                  'Tiempo de búsqueda: ${_searchSeconds}s',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
              
              const Spacer(),
              
              // Botón de cancelar
              if (!_driverFound)
                OasisButton(
                  text: 'Cancelar búsqueda',
                  onPressed: _cancelSearch,
                  isOutlined: true,
                ).animate().fadeIn(delay: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String location,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: iconColor,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            location,
            style: const TextStyle(fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}