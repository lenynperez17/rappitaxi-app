import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/models/location_model.dart';
import '../../domain/entities/price_negotiation.dart';
import '../../data/services/price_negotiation_service.dart';
import '../../../../core/theme/app_theme.dart';

class PremiumPriceNegotiationScreen extends ConsumerStatefulWidget {
  final LocationModel pickup;
  final LocationModel destination;
  final double suggestedPrice;
  final String rideRequestId;

  const PremiumPriceNegotiationScreen({
    super.key,
    required this.pickup,
    required this.destination,
    required this.suggestedPrice,
    required this.rideRequestId,
  });

  @override
  ConsumerState<PremiumPriceNegotiationScreen> createState() =>
      _PremiumPriceNegotiationScreenState();
}

class _PremiumPriceNegotiationScreenState
    extends ConsumerState<PremiumPriceNegotiationScreen>
    with TickerProviderStateMixin {
  late AnimationController _timerController;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  
  late Animation<double> _timerAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  Timer? _countdownTimer;
  int _remainingSeconds = 300; // 5 minutos
  bool _isExtended = false;
  
  List<DriverOffer> _offers = [];
  DriverOffer? _selectedOffer;
  double _counterOfferAmount = 0;
  final TextEditingController _counterOfferController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startTimer();
    _simulateOffers();
  }

  void _initializeAnimations() {
    _timerController = AnimationController(
      duration: const Duration(seconds: 300),
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

    _timerAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _timerController,
      curve: Curves.linear,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    _timerController.forward();
    _slideController.forward();
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            _countdownTimer?.cancel();
            _onTimeUp();
          }
        });
      }
    });
  }

  void _simulateOffers() {
    // Simular ofertas que llegan de forma gradual
    final random = Random();
    final driverNames = [
      'Carlos Mendoza', 'Ana López', 'Miguel Torres', 
      'Sofia Vargas', 'Diego Ramírez', 'Isabella Cruz'
    ];
    
    for (int i = 0; i < 6; i++) {
      Timer(Duration(seconds: 5 + i * 15), () {
        if (mounted) {
          final offer = DriverOffer(
            id: 'offer_$i',
            negotiationId: widget.rideRequestId,
            driverId: 'driver_$i',
            driverName: driverNames[i],
            driverRating: 4.2 + random.nextDouble() * 0.8,
            driverPhoto: 'https://api.dicebear.com/7.x/personas/png?seed=${driverNames[i]}',
            totalTrips: 150 + random.nextInt(300),
            vehicleModel: i % 2 == 0 ? 'Toyota Corolla' : 'Chevrolet Spark',
            vehiclePlate: 'ABC-${100 + i}${20 + i}${30 + i}',
            offeredPrice: widget.suggestedPrice * (0.8 + random.nextDouble() * 0.4),
            estimatedDistance: 0.5 + random.nextDouble() * 2.5,
            estimatedArrivalMinutes: 5 + random.nextInt(10),
            status: OfferStatus.pending,
            createdAt: DateTime.now(),
          );
          
          setState(() {
            _offers.add(offer);
            _offers.sort((a, b) => a.offeredPrice.compareTo(b.offeredPrice));
          });

          // Animación de entrada para la nueva oferta
          HapticFeedback.lightImpact();
        }
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _timerController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    _counterOfferController.dispose();
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
              _buildTimerSection(),
              _buildRouteInfo(),
              Expanded(
                child: _buildOffersSection(),
              ),
              _buildBottomSection(),
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
            onTap: () => Navigator.pop(context),
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
                  'Negociación de Precio',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Esperando ofertas de conductores',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 600.ms)
        .slideY(begin: -0.3, duration: 600.ms);
  }

  Widget _buildTimerSection() {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Tiempo restante',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _remainingSeconds < 60 ? _pulseAnimation.value : 1.0,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _remainingSeconds < 60 
                            ? Colors.red.withOpacity(0.2)
                            : Colors.white.withOpacity(0.2),
                        border: Border.all(
                          color: _remainingSeconds < 60 
                              ? Colors.red
                              : Colors.white,
                          width: 3,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color: _remainingSeconds < 60 
                                ? Colors.red
                                : Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _timerAnimation,
            builder: (context, child) {
              return Container(
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: Colors.white.withOpacity(0.3),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _timerAnimation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(
                        colors: _remainingSeconds < 60
                            ? [Colors.red, Colors.orange]
                            : [Colors.green, Colors.blue],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (!_isExtended && _remainingSeconds < 120) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _extendTime,
              icon: const Icon(Icons.add_alarm),
              label: const Text('Extender 2 min'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 200.ms, duration: 600.ms)
        .slideY(begin: -0.3, delay: 200.ms, duration: 600.ms);
  }

  Widget _buildRouteInfo() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.route,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📍 ${widget.pickup.address}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '🏁 ${widget.destination.address}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'S/. ${widget.suggestedPrice.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 400.ms, duration: 600.ms)
        .slideX(begin: -0.3, delay: 400.ms, duration: 600.ms);
  }

  Widget _buildOffersSection() {
    if (_offers.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.15),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
              child: const Icon(
                Icons.hourglass_empty,
                color: Colors.white,
                size: 40,
              ),
            )
                .animate(onPlay: (controller) => controller.repeat())
                .rotate(duration: 2000.ms),
            const SizedBox(height: 20),
            Text(
              'Esperando ofertas...',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Los conductores cercanos están enviando sus ofertas',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Ofertas recibidas (${_offers.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_offers.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Text(
                    'Menor: S/. ${_offers.first.offeredPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _offers.length,
              itemBuilder: (context, index) {
                return _buildOfferCard(_offers[index], index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferCard(DriverOffer offer, int index) {
    final isSelected = _selectedOffer?.id == offer.id;
    final isLowest = _offers.isNotEmpty && offer.id == _offers.first.id;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedOffer = offer;
          });
          HapticFeedback.lightImpact();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected 
                ? Colors.white.withOpacity(0.25)
                : Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected 
                  ? Colors.white
                  : Colors.white.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isSelected ? 0.2 : 0.1),
                blurRadius: isSelected ? 15 : 10,
                offset: Offset(0, isSelected ? 8 : 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Avatar del conductor
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                    child: ClipOval(
                      child: Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Información del conductor
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              offer.driverName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isLowest) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'MEJOR PRECIO',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
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
                              offer.driverRating.toStringAsFixed(1),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Icon(
                              Icons.location_on,
                              color: Colors.white.withOpacity(0.7),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${offer.estimatedDistance.toStringAsFixed(1)} km',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${offer.vehicleModel} • ${offer.vehiclePlate}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Precio y tiempo
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'S/. ${offer.offeredPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${offer.estimatedArrivalMinutes} min',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              if (isSelected) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showCounterOfferDialog(offer),
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text('Contraoferta'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => _acceptOffer(offer),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Aceptar Oferta'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (index * 100).ms, duration: 600.ms)
        .slideX(begin: 0.3, delay: (index * 100).ms, duration: 600.ms);
  }

  Widget _buildBottomSection() {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          border: Border(
            top: BorderSide(
              color: Colors.white.withOpacity(0.3),
            ),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _makeCounterOffer,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Hacer Contraoferta'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _cancelNegotiation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Icon(Icons.close),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _extendTime() {
    setState(() {
      _remainingSeconds += 120; // Agregar 2 minutos
      _isExtended = true;
    });
    HapticFeedback.mediumImpact();
  }

  void _onTimeUp() {
    if (_offers.isNotEmpty) {
      // Auto-seleccionar la mejor oferta
      _acceptOffer(_offers.first);
    } else {
      // Mostrar diálogo de búsqueda alternativa
      _showAlternativeDialog();
    }
  }

  void _acceptOffer(DriverOffer offer) {
    HapticFeedback.mediumImpact();
    
    // Mostrar diálogo de confirmación con animación premium
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
                Icons.check_circle,
                color: Colors.green,
                size: 50,
              ),
            )
                .animate()
                .scale(delay: 200.ms, duration: 600.ms)
                .fadeIn(duration: 400.ms),
            const SizedBox(height: 16),
            Text(
              '¡Oferta Aceptada!',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${offer.driverName} está en camino',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.pushReplacement('/ride/in-progress', extra: {
                  'pickup': widget.pickup,
                  'destination': widget.destination,
                  'vehicleType': offer.vehicleModel,
                  'paymentMethod': 'negotiated',
                  'fare': offer.offeredPrice,
                  'driver': {
                    'id': offer.driverId,
                    'name': offer.driverName,
                    'rating': offer.driverRating,
                    'vehicle': '${offer.vehicleModel} • ${offer.vehiclePlate}',
                  },
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCounterOfferDialog(DriverOffer offer) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Hacer Contraoferta a ${offer.driverName}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Su oferta: S/. ${offer.offeredPrice.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _counterOfferController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Tu contraoferta',
                prefixText: 'S/. ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Enviar contraoferta
                      Navigator.pop(context);
                      HapticFeedback.lightImpact();
                    },
                    child: const Text('Enviar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _makeCounterOffer() {
    _showCounterOfferDialog(_offers.first);
  }

  void _showAlternativeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Tiempo Agotado'),
        content: const Text(
          'No se recibieron ofertas en el tiempo establecido. ¿Deseas buscar con tarifa normal?'
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Continuar con tarifa normal
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  void _cancelNegotiation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('¿Cancelar negociación?'),
        content: const Text(
          'Si cancelas ahora, perderás todas las ofertas recibidas y tendrás que solicitar un nuevo viaje.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continuar negociando'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.pop(); // Regresar a la pantalla anterior
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}