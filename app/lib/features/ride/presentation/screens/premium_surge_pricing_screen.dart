import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/models/location_model.dart';
import '../../domain/entities/surge_pricing.dart';
import '../../../../core/theme/app_theme.dart';

class PremiumSurgePricingScreen extends ConsumerStatefulWidget {
  final LocationModel pickup;
  final LocationModel destination;
  final double baseFare;
  final String vehicleType;

  const PremiumSurgePricingScreen({
    super.key,
    required this.pickup,
    required this.destination,
    required this.baseFare,
    required this.vehicleType,
  });

  @override
  ConsumerState<PremiumSurgePricingScreen> createState() =>
      _PremiumSurgePricingScreenState();
}

class _PremiumSurgePricingScreenState
    extends ConsumerState<PremiumSurgePricingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late AnimationController _countdownController;
  
  double _currentMultiplier = 1.8;
  bool _isPriceUpdating = false;
  Timer? _priceUpdateTimer;
  Timer? _countdownTimer;
  int _estimatedWaitTime = 45; // seconds
  
  late SurgePricing _surgePricing;
  List<String> _surgeReasons = [];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _generateSurgePricing();
    _startPriceMonitoring();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _countdownController = AnimationController(
      duration: const Duration(seconds: 60),
      vsync: this,
    );

    _countdownController.forward();
  }

  void _generateSurgePricing() {
    final random = Random();
    final reasons = [
      'Alta demanda en la zona',
      'Pocos conductores disponibles',
      'Hora pico de tráfico',
      'Evento especial cercano',
      'Condiciones climáticas',
    ];

    _surgeReasons = reasons.take(2 + random.nextInt(2)).toList();
    
    _surgePricing = SurgePricing(
      id: 'surge_${DateTime.now().millisecondsSinceEpoch}',
      zoneId: 'zone_${widget.pickup.latitude.toString().substring(0, 6)}',
      latitude: widget.pickup.latitude,
      longitude: widget.pickup.longitude,
      radiusKm: 5.0,
      surgeMultiplier: _currentMultiplier,
      startTime: DateTime.now().subtract(const Duration(minutes: 15)),
      endTime: DateTime.now().add(const Duration(minutes: 45)),
      reason: SurgeReason.highDemand,
      activeDrivers: 12 + random.nextInt(8),
      pendingRequests: 35 + random.nextInt(20),
    );
  }

  void _startPriceMonitoring() {
    _priceUpdateTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        _updateSurgePrice();
      }
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _estimatedWaitTime > 0) {
        setState(() {
          _estimatedWaitTime--;
        });
      }
    });
  }

  void _updateSurgePrice() {
    setState(() {
      _isPriceUpdating = true;
    });

    final random = Random();
    final change = (random.nextDouble() - 0.5) * 0.2; // ±0.1 change
    final newMultiplier = (_currentMultiplier + change).clamp(1.2, 3.0);
    
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _currentMultiplier = newMultiplier;
          _isPriceUpdating = false;
        });
        HapticFeedback.lightImpact();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _countdownController.dispose();
    _priceUpdateTimer?.cancel();
    _countdownTimer?.cancel();
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
              const Color(0xFFFF6B6B),
              const Color(0xFFFF8E53),
              const Color(0xFFFF6B9D),
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
                  'Precios Dinámicos',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Alta demanda en tu zona',
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
                scale: 1.0 + (_pulseController.value * 0.15),
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
                    Icons.trending_up,
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
          _buildSurgeIndicator(),
          const SizedBox(height: 24),
          _buildPriceComparison(),
          const SizedBox(height: 24),
          _buildDemandInfo(),
          const SizedBox(height: 24),
          _buildWaitTimeEstimate(),
          const SizedBox(height: 24),
          _buildSurgeReasons(),
          const SizedBox(height: 32),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildSurgeIndicator() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.withOpacity(0.1),
            Colors.red.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  for (int i = 0; i < 3; i++)
                    Transform.scale(
                      scale: 1.0 + (sin((_waveController.value * 2 * pi) - (i * pi / 2)) * 0.2),
                      child: Container(
                        width: 80 + (i * 20),
                        height: 80 + (i * 20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3 - (i * 0.1)),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        child: Text(
                          '${_currentMultiplier.toStringAsFixed(1)}x',
                          key: ValueKey(_currentMultiplier),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Multiplicador de Demanda',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Los precios están ${_currentMultiplier.toStringAsFixed(1)}x más altos de lo normal',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 200.ms, duration: 600.ms)
        .scale(delay: 200.ms, duration: 600.ms);
  }

  Widget _buildPriceComparison() {
    final surgePrice = widget.baseFare * _currentMultiplier;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comparación de Precios',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Precio normal',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'S/. ${widget.baseFare.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        decoration: TextDecoration.lineThrough,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 2,
                height: 40,
                color: Colors.grey.shade300,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Precio actual',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        'S/. ${surgePrice.toStringAsFixed(2)}',
                        key: ValueKey(surgePrice),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.orange,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Precio actualizado hace ${_isPriceUpdating ? "0" : "15"} segundos',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                    ),
                  ),
                ),
                if (_isPriceUpdating)
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 400.ms, duration: 600.ms)
        .slideX(begin: -0.3, delay: 400.ms, duration: 600.ms);
  }

  Widget _buildDemandInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.1),
            AppTheme.primaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Información de Demanda',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDemandStat(
                  Icons.directions_car,
                  'Conductores',
                  '${_surgePricing.activeDrivers}',
                  'disponibles',
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.grey.shade300,
              ),
              Expanded(
                child: _buildDemandStat(
                  Icons.people,
                  'Pasajeros',
                  '${_surgePricing.pendingRequests}',
                  'solicitando',
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 600.ms, duration: 600.ms)
        .slideX(begin: 0.3, delay: 600.ms, duration: 600.ms);
  }

  Widget _buildDemandStat(IconData icon, String title, String value, String subtitle) {
    return Column(
      children: [
        Icon(
          icon,
          color: AppTheme.primaryColor,
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildWaitTimeEstimate() {
    final minutes = _estimatedWaitTime ~/ 60;
    final seconds = _estimatedWaitTime % 60;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blue.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.access_time,
              color: Colors.blue,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tiempo de Espera Estimado',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  minutes > 0 
                      ? '$minutes:${seconds.toString().padLeft(2, '0')} min'
                      : '$seconds segundos',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 800.ms, duration: 600.ms)
        .slideY(begin: 0.3, delay: 800.ms, duration: 600.ms);
  }

  Widget _buildSurgeReasons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '¿Por qué los precios están altos?',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Column(
          children: _surgeReasons.asMap().entries.map((entry) {
            final index = entry.key;
            final reason = entry.value;
            
            return Container(
              margin: EdgeInsets.only(bottom: index < _surgeReasons.length - 1 ? 12 : 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      reason,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(delay: (1000 + index * 100).ms, duration: 600.ms)
                .slideX(begin: 0.3, delay: (1000 + index * 100).ms, duration: 600.ms);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final surgePrice = widget.baseFare * _currentMultiplier;

    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _acceptSurgePrice,
            icon: const Icon(Icons.local_taxi, size: 20),
            label: Text(
              'Aceptar Precio • S/. ${surgePrice.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: _waitForPriceReduction,
            icon: const Icon(Icons.schedule, size: 20),
            label: const Text(
              'Esperar a que Bajen los Precios',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              side: const BorderSide(color: AppTheme.primaryColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(delay: 1200.ms, duration: 600.ms)
        .scale(delay: 1200.ms, duration: 600.ms);
  }

  void _acceptSurgePrice() {
    final surgePrice = widget.baseFare * _currentMultiplier;
    
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
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_taxi,
                color: Colors.orange,
                size: 50,
              ),
            )
                .animate()
                .scale(delay: 200.ms, duration: 600.ms)
                .fadeIn(duration: 400.ms),
            const SizedBox(height: 16),
            Text(
              '¡Precio Aceptado!',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Buscando conductor disponible en tu zona',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Precio: S/. ${surgePrice.toStringAsFixed(2)} (${_currentMultiplier.toStringAsFixed(1)}x)',
                style: const TextStyle(
                  color: Colors.orange,
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
                  'vehicleType': widget.vehicleType,
                  'paymentMethod': 'surge',
                  'estimatedFare': surgePrice,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Buscar Conductor'),
            ),
          ],
        ),
      ),
    );
  }

  void _waitForPriceReduction() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Esperar Precios Más Bajos'),
        content: const Text(
          'Te notificaremos cuando los precios bajen. Esto puede tomar algunos minutos dependiendo de la demanda.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.pop(); // Regresar a la pantalla anterior
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Notificarme'),
          ),
        ],
      ),
    );
  }
}