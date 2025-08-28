import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/models/location_model.dart';
import '../../domain/entities/shared_ride.dart';
import '../../../../core/theme/app_theme.dart';

class PremiumSharedRideScreen extends ConsumerStatefulWidget {
  final LocationModel pickup;
  final LocationModel destination;
  final double originalFare;

  const PremiumSharedRideScreen({
    super.key,
    required this.pickup,
    required this.destination,
    required this.originalFare,
  });

  @override
  ConsumerState<PremiumSharedRideScreen> createState() =>
      _PremiumSharedRideScreenState();
}

class _PremiumSharedRideScreenState
    extends ConsumerState<PremiumSharedRideScreen>
    with TickerProviderStateMixin {
  late AnimationController _searchController;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  
  bool _isSearching = false;
  bool _hasFoundMatches = false;
  List<SharedRideMatch> _matches = [];
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _searchController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF667EEA),
              const Color(0xFF764BA2),
              const Color(0xFFF093FB),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: _buildContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Viaje Compartido',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Comparte el viaje y ahorra dinero',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_pulseController.value * 0.1),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.people,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 600.ms)
        .slideY(begin: -0.3, duration: 600.ms);
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSavingsCard(),
          const SizedBox(height: 24),
          _buildRouteInfo(),
          const SizedBox(height: 24),
          _buildHowItWorks(),
          const SizedBox(height: 24),
          if (!_isSearching && !_hasFoundMatches)
            _buildSearchButton()
          else if (_isSearching)
            _buildSearchingState()
          else
            _buildMatchesSection(),
        ],
      ),
    );
  }

  Widget _buildSavingsCard() {
    final savings = widget.originalFare * 0.3; // 30% descuento
    final sharedFare = widget.originalFare - savings;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.withOpacity(0.1),
            Colors.green.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.green.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.savings,
                  color: Colors.green,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ahorra hasta 30%',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    Text(
                      'Compartiendo el viaje con otros pasajeros',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Precio individual',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'S/. ${widget.originalFare.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        decoration: TextDecoration.lineThrough,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 2,
                height: 30,
                color: Colors.grey.shade300,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Precio compartido',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'S/. ${sharedFare.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 200.ms, duration: 600.ms)
        .scale(delay: 200.ms, duration: 600.ms);
  }

  Widget _buildRouteInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.pickup.address,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(left: 6),
            height: 20,
            width: 2,
            color: Colors.grey.shade300,
          ),
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.destination.address,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 400.ms, duration: 600.ms)
        .slideX(begin: -0.3, delay: 400.ms, duration: 600.ms);
  }

  Widget _buildHowItWorks() {
    final steps = [
      {
        'icon': Icons.search,
        'title': 'Buscar compañeros',
        'description': 'Encontramos pasajeros con rutas similares',
      },
      {
        'icon': Icons.route,
        'title': 'Optimizar ruta',
        'description': 'Creamos la mejor ruta para todos',
      },
      {
        'icon': Icons.share,
        'title': 'Compartir costos',
        'description': 'Dividen el precio del viaje equitativamente',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '¿Cómo funciona?',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Column(
          children: steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            
            return Container(
              margin: EdgeInsets.only(bottom: index < steps.length - 1 ? 16 : 0),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      step['icon'] as IconData,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step['title'] as String,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          step['description'] as String,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(delay: (600 + index * 100).ms, duration: 600.ms)
                .slideX(begin: 0.3, delay: (600 + index * 100).ms, duration: 600.ms);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSearchButton() {
    return Container(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _startSearching,
        icon: const Icon(Icons.search, size: 20),
        label: Text(
          'Buscar Compañeros de Viaje',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 1000.ms, duration: 600.ms)
        .scale(delay: 1000.ms, duration: 600.ms);
  }

  Widget _buildSearchingState() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _searchController,
          builder: (context, child) {
            return Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withOpacity(0.1),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                ),
              ),
              child: Transform.rotate(
                angle: _searchController.value * 2 * pi,
                child: const Icon(
                  Icons.search,
                  color: AppTheme.primaryColor,
                  size: 40,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        Text(
          'Buscando compañeros de viaje...',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Encontrando pasajeros con rutas similares',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        LinearProgressIndicator(
          backgroundColor: Colors.grey.shade300,
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: _cancelSearch,
          child: const Text('Cancelar búsqueda'),
        ),
      ],
    );
  }

  Widget _buildMatchesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: Colors.green,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '¡Compañeros encontrados!',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Hemos encontrado ${_matches.length} pasajeros con rutas compatibles:',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 16),
        Column(
          children: _matches.asMap().entries.map((entry) {
            final index = entry.key;
            final match = entry.value;
            return _buildMatchCard(match, index);
          }).toList(),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _confirmSharedRide,
            icon: const Icon(Icons.people, size: 20),
            label: Text(
              'Confirmar Viaje Compartido • S/. ${(widget.originalFare * 0.7).toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMatchCard(SharedRideMatch match, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              color: AppTheme.primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  match.passengerName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.star,
                      color: Colors.amber,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      match.rating.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.location_on,
                      color: Colors.grey.shade500,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${match.distanceFromRoute.toStringAsFixed(1)} km',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${match.compatibilityScore}% match',
              style: const TextStyle(
                color: Colors.green,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: (index * 100).ms, duration: 600.ms)
        .slideX(begin: 0.3, delay: (index * 100).ms, duration: 600.ms);
  }

  void _startSearching() {
    setState(() {
      _isSearching = true;
    });

    _searchController.repeat();
    
    // Simular búsqueda de compañeros
    _searchTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _generateMatches();
        setState(() {
          _isSearching = false;
          _hasFoundMatches = true;
        });
        _searchController.stop();
      }
    });

    HapticFeedback.mediumImpact();
  }

  void _generateMatches() {
    final random = Random();
    final names = ['Ana García', 'Carlos López', 'María Rodríguez'];
    
    _matches = List.generate(3, (index) {
      return SharedRideMatch(
        id: 'match_$index',
        passengerId: 'passenger_$index',
        passengerName: names[index],
        rating: 4.2 + random.nextDouble() * 0.8,
        pickupLocation: LocationModel(
          latitude: widget.pickup.latitude + (random.nextDouble() - 0.5) * 0.01,
          longitude: widget.pickup.longitude + (random.nextDouble() - 0.5) * 0.01,
          address: 'Cerca de ${widget.pickup.address}',
        ),
        dropoffLocation: LocationModel(
          latitude: widget.destination.latitude + (random.nextDouble() - 0.5) * 0.01,
          longitude: widget.destination.longitude + (random.nextDouble() - 0.5) * 0.01,
          address: 'Cerca de ${widget.destination.address}',
        ),
        compatibilityScore: 85 + random.nextInt(15),
        distanceFromRoute: 0.2 + random.nextDouble() * 0.8,
        estimatedDetourTime: Duration(minutes: 2 + random.nextInt(8)),
        status: MatchStatus.pending,
      );
    });
  }

  void _cancelSearch() {
    _searchTimer?.cancel();
    _searchController.stop();
    setState(() {
      _isSearching = false;
    });
  }

  void _confirmSharedRide() {
    HapticFeedback.mediumImpact();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people,
                color: Colors.green,
                size: 50,
              ),
            )
                .animate()
                .scale(delay: 200.ms, duration: 600.ms)
                .fadeIn(duration: 400.ms),
            const SizedBox(height: 16),
            Text(
              '¡Viaje Compartido Confirmado!',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tu conductor está en camino para recoger a todos los pasajeros',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Ahorro: S/. ${(widget.originalFare * 0.3).toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.pushReplacement('/ride/searching-driver', extra: {
                  'pickup': widget.pickup,
                  'destination': widget.destination,
                  'vehicleType': 'shared',
                  'paymentMethod': 'shared',
                  'estimatedFare': widget.originalFare * 0.7,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Ver Estado del Viaje'),
            ),
          ],
        ),
      ),
    );
  }
}

// Mock class for SharedRideMatch
class SharedRideMatch {
  final String id;
  final String passengerId;
  final String passengerName;
  final double rating;
  final LocationModel pickupLocation;
  final LocationModel dropoffLocation;
  final int compatibilityScore;
  final double distanceFromRoute;
  final Duration estimatedDetourTime;
  final MatchStatus status;

  SharedRideMatch({
    required this.id,
    required this.passengerId,
    required this.passengerName,
    required this.rating,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.compatibilityScore,
    required this.distanceFromRoute,
    required this.estimatedDetourTime,
    required this.status,
  });
}

enum MatchStatus { pending, confirmed, cancelled }