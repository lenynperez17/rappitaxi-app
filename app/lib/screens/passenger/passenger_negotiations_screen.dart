import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/price_negotiation_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/price_negotiation_model.dart';

/// Pantalla de negociaciones para pasajeros
/// Muestra las negociaciones activas y las ofertas de conductores
class PassengerNegotiationsScreen extends StatefulWidget {
  const PassengerNegotiationsScreen({super.key});

  @override
  State<PassengerNegotiationsScreen> createState() => _PassengerNegotiationsScreenState();
}

class _PassengerNegotiationsScreenState extends State<PassengerNegotiationsScreen>
    with SingleTickerProviderStateMixin {
  // Timer para actualizar el cronómetro cada segundo
  Timer? _countdownTimer;

  // Animation controller for staggered card entries
  late AnimationController _listAnimController;

  // ✅ CORREGIDO: Guardar referencia al provider para usar en dispose()
  // No se puede usar Provider.of(context) en dispose() porque el context ya no es válido
  PriceNegotiationProvider? _negotiationProvider;
  bool _isNavigatingToTracking = false;

  @override
  void initState() {
    super.initState();

    // Animation controller for staggered list entries
    _listAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    // ✅ NUEVO: Iniciar listener en tiempo real para recibir ofertas y cambios de status
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // ✅ CORREGIDO: Guardar referencia al provider para usar en dispose()
      _negotiationProvider = Provider.of<PriceNegotiationProvider>(context, listen: false);

      // ✅ IMPORTANTE: Limpiar negociaciones cuyo viaje fue cancelado ANTES de escuchar
      await _negotiationProvider!.cleanupCancelledNegotiations();

      // ✅ NUEVO: Expirar negociaciones vencidas automáticamente
      await _negotiationProvider!.expireOldNegotiations();

      _negotiationProvider!.startListeningToMyNegotiations();
    });

    // Iniciar timer para actualizar el cronómetro cada segundo
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          // Forzar rebuild para actualizar el cronómetro
        });

        // ✅ NUEVO: Verificar y expirar negociaciones automáticamente cada segundo
        _checkAndExpireNegotiations();
      }
    });
  }

  // ✅ NUEVO: Verificar negociaciones expiradas en cada tick del timer
  void _checkAndExpireNegotiations() {
    final provider = Provider.of<PriceNegotiationProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id ?? '';
    final now = DateTime.now();

    // Obtener las negociaciones activas del usuario
    final myActiveNegotiations = provider.activeNegotiations
        .where((n) => n.passengerId == currentUserId)
        .where((n) =>
            n.status == NegotiationStatus.waiting ||
            n.status == NegotiationStatus.negotiating)
        .toList();

    // Verificar si hay negociaciones que acaban de expirar
    bool anyExpired = false;
    for (final negotiation in myActiveNegotiations) {
      if (negotiation.expiresAt.isBefore(now)) {
        // Expirar esta negociación
        debugPrint('⏰ Auto-expirando negociación: ${negotiation.id}');
        provider.expireOldNegotiations();
        anyExpired = true;
        break; // Solo procesar una a la vez
      }
    }

    // ✅ NUEVO: Si TODAS las negociaciones expiraron, navegar al home automáticamente
    if (anyExpired) {
      // Verificar si quedan negociaciones válidas después de expirar
      final remainingValid = provider.activeNegotiations
          .where((n) => n.passengerId == currentUserId)
          .where((n) =>
              n.status == NegotiationStatus.waiting ||
              n.status == NegotiationStatus.negotiating)
          .where((n) => n.expiresAt.isAfter(now))
          .toList();

      if (remainingValid.isEmpty && mounted) {
        debugPrint('🏠 Todas las negociaciones expiraron, volviendo al home');

        // Mostrar mensaje y navegar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tu solicitud ha expirado. Puedes crear una nueva.'),
            backgroundColor: AppColors.warning,
            duration: Duration(seconds: 3),
          ),
        );

        // Navegar al home después de un breve delay para que se vea el mensaje
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _listAnimController.dispose();

    // ✅ CORREGIDO: Usar la referencia guardada en lugar de Provider.of(context)
    // Provider.of(context) no funciona en dispose() porque el context ya no es válido
    _negotiationProvider?.stopListeningToNegotiations();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id ?? '';

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          // Cleanup listeners before popping to prevent black screen
          _countdownTimer?.cancel();
          _negotiationProvider?.stopListeningToNegotiations();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mis Negociaciones'),
          backgroundColor: AppColors.rappiOrange,
        ),
        body: Consumer<PriceNegotiationProvider>(
        builder: (context, provider, _) {
          // ✅ NUEVO: Detectar si alguna negociación fue aceptada (por conductor)
          final acceptedNegotiations = provider.activeNegotiations
              .where((n) => n.passengerId == currentUserId)
              .where((n) => n.status == NegotiationStatus.accepted)
              .toList();

          // Si hay una negociación aceptada, verificar estado del viaje antes de navegar
          if (acceptedNegotiations.isNotEmpty && !_isNavigatingToTracking) {
            _isNavigatingToTracking = true;
            final acceptedNeg = acceptedNegotiations.first;
            debugPrint('🎉 Negociación aceptada detectada: ${acceptedNeg.id}');

            // Guardar referencias locales antes del async para evitar use_build_context_synchronously
            final scaffoldMessenger = ScaffoldMessenger.of(context);
            final navigator = Navigator.of(context);

            // Usar addPostFrameCallback para navegar después del build
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!mounted) return;

              // ✅ IMPORTANTE: Verificar si el viaje está cancelado ANTES de navegar
              final wasCancelled = await provider.checkAndHandleCancelledRide(acceptedNeg.id);
              if (wasCancelled) {
                debugPrint('⚠️ Viaje cancelado detectado, no se navega al tracking');
                // El método ya actualizó la negociación a cancelled, el UI se actualizará solo
                return;
              }

              // Obtener el rideId desde Firestore
              final rideId = await provider.getRideIdForNegotiation(acceptedNeg.id);
              debugPrint('🚗 RideId obtenido: $rideId');

              if (rideId != null && mounted) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('¡Un conductor aceptó tu viaje! Iniciando tracking...'),
                    backgroundColor: AppColors.success,
                    duration: Duration(seconds: 2),
                  ),
                );

                // Navegar a la pantalla de tracking
                navigator.pushReplacementNamed(
                  '/trip-tracking',
                  arguments: {'rideId': rideId},
                );
              } else if (mounted) {
                // rideId was null - retry up to 3 times with delay
                debugPrint('⚠️ rideId null, intentando retry...');
                for (int retry = 0; retry < 3; retry++) {
                  await Future.delayed(const Duration(seconds: 2));
                  if (!mounted) return;
                  final retryRideId = await provider.getRideIdForNegotiation(acceptedNeg.id);
                  if (retryRideId != null && mounted) {
                    navigator.pushReplacementNamed(
                      '/trip-tracking',
                      arguments: {'rideId': retryRideId},
                    );
                    return;
                  }
                }
                // All retries failed
                if (mounted) {
                  _isNavigatingToTracking = false;
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Error al conectar con el conductor. Espera un momento...'),
                      backgroundColor: AppColors.warning,
                    ),
                  );
                }
              }
            });
          }

          // ✅ CORREGIDO: Filtrar también por tiempo de expiración
          final now = DateTime.now();
          final myNegotiations = provider.activeNegotiations
              .where((n) => n.passengerId == currentUserId)
              .where((n) =>
                  n.status == NegotiationStatus.waiting ||
                  n.status == NegotiationStatus.negotiating)
              .where((n) => n.expiresAt.isAfter(now)) // ✅ Solo las no expiradas
              .toList();

          if (myNegotiations.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: myNegotiations.length,
            itemBuilder: (context, index) {
              final delay = (index * 0.12).clamp(0.0, 0.6);
              final end = (delay + 0.5).clamp(0.0, 1.0);
              final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(
                  parent: _listAnimController,
                  curve: Interval(delay, end, curve: Curves.easeOutBack),
                ),
              );
              return AnimatedBuilder(
                animation: animation,
                builder: (context, child) => Transform.translate(
                  offset: Offset(40 * (1 - animation.value), 0),
                  child: Opacity(opacity: animation.value, child: child),
                ),
                child: _buildNegotiationCard(myNegotiations[index]),
              );
            },
          );
        },
      ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.hourglass_empty,
            size: 80,
            color: AppColors.getTextSecondary(context),
          ),
          const SizedBox(height: 16),
          Text(
            'No tienes negociaciones activas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextSecondary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Solicita un viaje para comenzar',
            style: TextStyle(color: AppColors.getTextSecondary(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildNegotiationCard(PriceNegotiation negotiation) {
    final hasOffers = negotiation.driverOffers.isNotEmpty;
    final bestOffer = negotiation.bestOffer;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          // Header con estado y timer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getStatusColor(negotiation.status).withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _getStatusIcon(negotiation.status),
                      color: _getStatusColor(negotiation.status),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getStatusText(negotiation.status),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(negotiation.status),
                      ),
                    ),
                  ],
                ),
                _buildTimer(negotiation),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Route section with dotted line between origin and destination
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dots and line column
                    Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        // Dotted line
                        ...List.generate(3, (_) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Container(
                            width: 2,
                            height: 6,
                            color: AppColors.getTextSecondary(context),
                          ),
                        )),
                        Icon(
                          Icons.location_on_rounded,
                          size: 18,
                          color: AppColors.error,
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    // Addresses column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Origen',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.getTextSecondary(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            negotiation.pickup.address,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Destino',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.getTextSecondary(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            negotiation.destination.address,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Price section with semi-transparent background
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.rappiOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tu precio ofrecido:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'S/. ${negotiation.offeredPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.priceBlack,
                        ),
                      ),
                    ],
                  ),
                ),

                if (hasOffers) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Ofertas recibidas',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Green badge with offer count
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.inDriveGreen,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${negotiation.driverOffers.length}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (bestOffer != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.trending_down,
                                size: 16,
                                color: AppColors.success,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Mejor: S/. ${bestOffer.acceptedPrice.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Lista de ofertas
                  ...negotiation.driverOffers.map((offer) =>
                    _buildOfferCard(offer, negotiation.id),
                  ),
                ],

                if (!hasOffers) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.getInputFill(context),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.hourglass_empty, color: AppColors.getTextSecondary(context)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Esperando ofertas de conductores...',
                            style: TextStyle(color: AppColors.getTextSecondary(context)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ✅ Botón de cancelar siempre visible
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _cancelNegotiation(negotiation.id),
                    icon: const Icon(Icons.close, color: AppColors.error),
                    label: const Text(
                      'Cancelar solicitud',
                      style: TextStyle(color: AppColors.error),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NUEVO: Método para cancelar negociación
  Future<void> _cancelNegotiation(String negotiationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar solicitud'),
        content: const Text(
          '¿Estás seguro de que quieres cancelar esta solicitud de viaje?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = Provider.of<PriceNegotiationProvider>(context, listen: false);

      try {
        await provider.cancelNegotiation(negotiationId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Solicitud cancelada'),
              backgroundColor: AppColors.warning,
            ),
          );

          // Volver al home si no quedan negociaciones
          if (provider.activeNegotiations.isEmpty) {
            Navigator.pop(context);
          }
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
  }

  Widget _buildOfferCard(DriverOffer offer, String negotiationId) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: offer.driverPhoto.isNotEmpty
                  ? NetworkImage(offer.driverPhoto)
                  : null,
              child: offer.driverPhoto.isEmpty ? const Icon(Icons.person_rounded) : null,
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
                      fontSize: 15,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.star_rounded, size: 14, color: Colors.amber[700]),
                      const SizedBox(width: 4),
                      Text(
                        offer.driverRating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${offer.completedTrips} viajes',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${offer.vehicleModel} • ${offer.vehicleColor}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'S/. ${offer.acceptedPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.priceBlack,
                  ),
                ),
                const SizedBox(height: 4),
                ElevatedButton(
                  onPressed: () => _acceptOffer(negotiationId, offer.driverId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.ctaGreen,
                    foregroundColor: AppColors.priceBlack,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Aceptar',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimer(PriceNegotiation negotiation) {
    final remaining = negotiation.timeRemaining;

    // ✅ CORREGIDO: Si el tiempo es negativo o cero, mostrar "Expirado"
    if (remaining.isNegative || remaining.inSeconds <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_off, size: 16, color: AppColors.white),
            SizedBox(width: 4),
            Text(
              'Expirado',
              style: TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;

    // Color-coded: green when plenty of time, yellow mid, orange low, red critical
    Color timerColor;
    if (minutes >= 5) {
      timerColor = AppColors.success;
    } else if (minutes >= 3) {
      timerColor = AppColors.warning;
    } else if (minutes >= 1) {
      timerColor = AppColors.rappiOrange;
    } else {
      timerColor = AppColors.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: timerColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer, size: 16, color: AppColors.white),
          const SizedBox(width: 4),
          Text(
            '$minutes:${seconds.toString().padLeft(2, '0')}',
            style: const TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(NegotiationStatus status) {
    switch (status) {
      case NegotiationStatus.waiting:
        return AppColors.warning;
      case NegotiationStatus.negotiating:
        return AppColors.rappiOrange;
      case NegotiationStatus.accepted:
        return AppColors.success;
      case NegotiationStatus.expired:
      case NegotiationStatus.cancelled:
        return AppColors.error;
      default:
        return AppColors.getTextSecondary(context);
    }
  }

  IconData _getStatusIcon(NegotiationStatus status) {
    switch (status) {
      case NegotiationStatus.waiting:
        return Icons.hourglass_empty;
      case NegotiationStatus.negotiating:
        return Icons.sync;
      case NegotiationStatus.accepted:
        return Icons.check_circle;
      case NegotiationStatus.expired:
        return Icons.timer_off;
      case NegotiationStatus.cancelled:
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  String _getStatusText(NegotiationStatus status) {
    switch (status) {
      case NegotiationStatus.waiting:
        return 'Esperando ofertas';
      case NegotiationStatus.negotiating:
        return 'Recibiendo ofertas';
      case NegotiationStatus.accepted:
        return 'Oferta aceptada';
      case NegotiationStatus.expired:
        return 'Expirada';
      case NegotiationStatus.cancelled:
        return 'Cancelada';
      default:
        return 'Desconocido';
    }
  }

  Future<void> _acceptOffer(String negotiationId, String driverId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aceptar oferta'),
        content: const Text(
          '¿Estás seguro de que quieres aceptar esta oferta? '
          'El conductor será notificado y el viaje comenzará.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.ctaGreen,
              foregroundColor: AppColors.priceBlack,
            ),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = Provider.of<PriceNegotiationProvider>(
        context,
        listen: false,
      );

      try {
        // Mostrar loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(color: AppColors.rappiOrange),
          ),
        );

        // Aceptar oferta y obtener el ID del viaje creado
        final rideId = await provider.acceptDriverOffer(negotiationId, driverId);

        // Cerrar loading
        if (mounted) Navigator.pop(context);

        if (rideId != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Oferta aceptada! Tu conductor está en camino.'),
              backgroundColor: AppColors.success,
            ),
          );

          // Navegar a la pantalla de tracking del viaje
          Navigator.pushReplacementNamed(
            context,
            '/trip-tracking',
            arguments: {'rideId': rideId},
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al crear el viaje. Inténtalo de nuevo.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } catch (e) {
        // Cerrar loading si está abierto
        if (mounted) Navigator.pop(context);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al aceptar oferta: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}
