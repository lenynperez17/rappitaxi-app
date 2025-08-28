import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lottie/lottie.dart';

import '../../domain/entities/price_negotiation.dart';
import '../../domain/entities/negotiation_offer.dart';
import '../../data/services/price_negotiation_service.dart';
import '../providers/negotiation_provider.dart';
import '../widgets/offer_card.dart';
import '../widgets/driver_offer_card.dart';
import '../widgets/negotiation_timer_widget.dart';
import '../widgets/price_comparison_chart.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/loading_overlay.dart';
import '../../../../shared/widgets/animated_counter_widget.dart';

class PriceNegotiationScreen extends ConsumerStatefulWidget {
  final String negotiationId;
  final double suggestedPrice;
  final String rideRequestId;

  const PriceNegotiationScreen({
    super.key,
    required this.negotiationId,
    required this.suggestedPrice,
    required this.rideRequestId,
  });

  @override
  ConsumerState<PriceNegotiationScreen> createState() => _PriceNegotiationScreenState();
}

class _PriceNegotiationScreenState extends ConsumerState<PriceNegotiationScreen> with TickerProviderStateMixin {
  final TextEditingController _counterOfferController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  late AnimationController _pulseController;
  late AnimationController _slideController;
  Timer? _refreshTimer;
  bool _isAccepting = false;
  bool _showPriceChart = false;
  bool _isExtendingTime = false;
  String? _selectedOfferId;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _initializeNegotiation();
    _startRefreshTimer();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _refreshTimer?.cancel();
    _counterOfferController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeNegotiation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(negotiationProvider(widget.rideRequestId).notifier)
        .startNegotiation();
    });
  }
  
  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) {
        if (mounted) {
          ref.read(negotiationProvider(widget.rideRequestId).notifier)
            .refreshOffers();
          setState(() {});
        }
      },
    );
  }

  Future<void> _acceptOffer(DriverOffer offer) async {
    if (_isAccepting) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar oferta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Aceptar la oferta de ${offer.driverName}?',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.rappiOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Precio:'),
                  Text(
                    '\$${offer.offeredPrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;

    setState(() {
      _isAccepting = true;
      _selectedOfferId = offer.id;
    });

    try {
      final service = ref.read(PriceNegotiationService.provider);
      
      await service.acceptOffer(
        negotiationId: widget.negotiationId,
        offerId: offer.id,
        passengerId: 'current_user_id', // TODO: Obtener del auth provider
      );

      if (mounted) {
        LoadingOverlay.hide(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '¡Oferta aceptada! ${offer.driverName} está en camino',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        // Navegar a pantalla de viaje en progreso
        context.go('/ride-tracking/${widget.rideRequestId}');
      }
    } catch (e) {
      if (mounted) {
        LoadingOverlay.hide(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al aceptar oferta: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAccepting = false;
          _selectedOfferId = null;
        });
      }
    }
  }
  
  Future<void> _makeCounterOffer(DriverOffer offer, double counterPrice) async {
    LoadingOverlay.show(context);
    try {
      final service = ref.read(PriceNegotiationService.provider);
      await service.makeCounterOffer(
        negotiationId: widget.negotiationId,
        offerId: offer.id,
        counterPrice: counterPrice,
      );
      
      if (mounted) {
        LoadingOverlay.hide(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contraoferta enviada'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        LoadingOverlay.hide(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar contraoferta: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
  
  void _showCounterOfferDialog(DriverOffer offer) {
    _counterOfferController.text = offer.offeredPrice.toStringAsFixed(0);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Contraoferta a ${offer.driverName}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Información del conductor
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: offer.driverPhoto != null
                      ? CachedNetworkImageProvider(offer.driverPhoto!)
                      : null,
                    child: offer.driverPhoto == null
                      ? const Icon(Icons.person, size: 30)
                      : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          offer.driverName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.star, size: 16, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(offer.driverRating.toStringAsFixed(1)),
                            const SizedBox(width: 8),
                            Text(
                              '${offer.vehicleMake} ${offer.vehicleModel}',
                              style: TextStyle(color: AppColors.textLight),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Precio actual
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Oferta actual:'),
                    Text(
                      '\$${offer.offeredPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Input de contraoferta
              TextField(
                controller: _counterOfferController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Tu contraoferta',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                autofocus: true,
              ),
              
              const SizedBox(height: 20),
              
              // Botones de acción
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _sendCounterOffer(offer),
                      icon: const Icon(Icons.send),
                      label: const Text('Enviar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.rappiOrange,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
  
  void _sendCounterOffer(DriverOffer offer) async {
    final counterPrice = double.tryParse(_counterOfferController.text);
    
    if (counterPrice == null || counterPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingresa un precio válido'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    
    Navigator.pop(context);
    await _makeCounterOffer(offer, counterPrice);
  }

  Future<void> _extendNegotiation() async {
    if (_isExtendingTime) return;
    
    setState(() {
      _isExtendingTime = true;
    });
    
    try {
      final service = ref.read(PriceNegotiationService.provider);
      await service.extendNegotiation(
        negotiationId: widget.negotiationId,
        additionalSeconds: 180, // 3 minutos adicionales
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Negociación extendida por 3 minutos más'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo extender: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExtendingTime = false;
        });
      }
    }
  }

  Future<void> _cancelNegotiation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cancelar negociación?'),
        content: const Text(
          'Si cancelas, tendrás que solicitar un nuevo viaje.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continuar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final service = ref.read(PriceNegotiationService.provider);
      await service.cancelNegotiation(
        negotiationId: widget.negotiationId,
        reason: 'Cancelado por usuario',
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cancelar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildHeader(PriceNegotiation negotiation) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.rappiOrange, AppColors.rappiOrange.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Negociación de Precio',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    negotiation.status.name.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPriceCard(
                  'Precio Sugerido',
                  '\$${widget.suggestedPrice.toStringAsFixed(0)}',
                  Icons.local_taxi,
                  Colors.white.withOpacity(0.9),
                ),
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.0 + (_pulseController.value * 0.05),
                      child: _buildPriceCard(
                        'Tu Oferta',
                        '\$${negotiation.passengerOffer?.toStringAsFixed(0) ?? "N/A"}',
                        Icons.monetization_on,
                        Colors.amber[300]!,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceCard(String label, String price, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            price,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerSection(PriceNegotiation negotiation) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          NegotiationTimerWidget(
            expiresAt: negotiation.expiresAt,
            onExpired: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('La negociación ha expirado'),
                  backgroundColor: AppColors.error,
                ),
              );
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: _extendNegotiation,
                icon: const Icon(Icons.access_time),
                label: const Text('Extender'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _cancelNegotiation,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancelar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOffersSection() {
    final service = ref.read(PriceNegotiationService.provider);
    
    return StreamBuilder<List<DriverOffer>>(
      stream: service.getOffersStream(widget.negotiationId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar ofertas: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }

        final offers = snapshot.data ?? [];

        if (offers.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Lottie.asset(
                  'assets/animations/searching.json',
                  width: 120,
                  height: 120,
                  fit: BoxFit.contain,
                ).animate(onPlay: (controller) => controller.repeat()),
                const SizedBox(height: 24),
                const Text(
                  'Esperando ofertas de conductores...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Los conductores están revisando tu solicitud',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ofertas Recibidas (${offers.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showPriceChart = !_showPriceChart;
                      });
                    },
                    icon: Icon(
                      _showPriceChart 
                          ? Icons.list_rounded 
                          : Icons.bar_chart_rounded,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            
            if (_showPriceChart) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                height: 200,
                child: PriceComparisonChart(
                  offers: offers,
                  suggestedPrice: widget.suggestedPrice,
                ),
              ),
              const SizedBox(height: 16),
            ],

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: offers.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final offer = offers[index];
                final isSelected = _selectedOfferId == offer.id;
                
                return DriverOfferCard(
                  offer: offer,
                  suggestedPrice: widget.suggestedPrice,
                  onAccept: () => _acceptOffer(offer),
                  isAccepting: _isAccepting && isSelected,
                  rank: index + 1,
                ).animate().fadeIn(
                  delay: Duration(milliseconds: index * 100),
                  duration: const Duration(milliseconds: 400),
                ).slideX(
                  begin: 0.2,
                  duration: const Duration(milliseconds: 400),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.read(PriceNegotiationService.provider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: StreamBuilder<PriceNegotiation>(
        stream: service.getNegotiationStream(widget.negotiationId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Error al cargar la negociación',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text('${snapshot.error}'),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Volver'),
                  ),
                ],
              ),
            );
          }

          final negotiation = snapshot.data!;

          if (negotiation.status == NegotiationStatus.accepted) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Lottie.asset(
                      'assets/animations/success.json',
                      width: 120,
                      height: 120,
                      repeat: false,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '¡Oferta Aceptada!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Tu conductor está en camino'),
                  ],
                ),
              ),
            );
          }

          if (negotiation.status == NegotiationStatus.expired ||
              negotiation.status == NegotiationStatus.cancelled) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.timer_off_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      negotiation.status == NegotiationStatus.expired
                          ? 'Negociación Expirada'
                          : 'Negociación Cancelada',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Puedes solicitar un nuevo viaje'),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Nueva Solicitud'),
                    ),
                  ],
                ),
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(negotiation)),
              SliverToBoxAdapter(child: _buildTimerSection(negotiation)),
              SliverToBoxAdapter(child: _buildOffersSection()),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }
}