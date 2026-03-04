import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/modern_theme.dart';
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

class _PassengerNegotiationsScreenState extends State<PassengerNegotiationsScreen> {
  // Timer para actualizar el cronómetro cada segundo
  Timer? _countdownTimer;

  // ✅ CORREGIDO: Guardar referencia al provider para usar en dispose()
  // No se puede usar Provider.of(context) en dispose() porque el context ya no es válido
  PriceNegotiationProvider? _negotiationProvider;
  bool _isNavigatingToTracking = false;

  @override
  void initState() {
    super.initState();

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
            backgroundColor: ModernTheme.warning,
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

    // ✅ CORREGIDO: Usar la referencia guardada en lugar de Provider.of(context)
    // Provider.of(context) no funciona en dispose() porque el context ya no es válido
    _negotiationProvider?.stopListeningToNegotiations();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Negociaciones'),
        backgroundColor: ModernTheme.rappiOrange,
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
                    backgroundColor: ModernTheme.success,
                    duration: Duration(seconds: 2),
                  ),
                );

                // Navegar a la pantalla de tracking
                navigator.pushReplacementNamed(
                  '/trip-tracking',
                  arguments: {'rideId': rideId},
                );
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
              return _buildNegotiationCard(myNegotiations[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No tienes negociaciones activas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Solicita un viaje para comenzar',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          // Header con estado
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getStatusColor(negotiation.status).withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
                // Rutas
                _buildLocationRow(
                  icon: Icons.radio_button_checked,
                  color: ModernTheme.success,
                  label: 'Origen',
                  address: negotiation.pickup.address,
                ),
                const SizedBox(height: 12),
                _buildLocationRow(
                  icon: Icons.location_on,
                  color: ModernTheme.error,
                  label: 'Destino',
                  address: negotiation.destination.address,
                ),
                const SizedBox(height: 16),

                // Tu precio
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tu precio ofrecido:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'S/. ${negotiation.offeredPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: ModernTheme.rappiOrange,
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
                      Text(
                        'Ofertas recibidas (${negotiation.driverOffers.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (bestOffer != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: ModernTheme.success.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.trending_down,
                                size: 16,
                                color: ModernTheme.success,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Mejor: S/. ${bestOffer.acceptedPrice.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: ModernTheme.success,
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
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.hourglass_empty, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Esperando ofertas de conductores...',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ✅ NUEVO: Botón de cancelar siempre visible
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _cancelNegotiation(negotiation.id),
                    icon: const Icon(Icons.close, color: ModernTheme.error),
                    label: const Text(
                      'Cancelar solicitud',
                      style: TextStyle(color: ModernTheme.error),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: ModernTheme.error),
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
              backgroundColor: ModernTheme.error,
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
              backgroundColor: ModernTheme.warning,
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
              backgroundColor: ModernTheme.error,
            ),
          );
        }
      }
    }
  }

  Widget _buildOfferCard(DriverOffer offer, String negotiationId) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: offer.driverPhoto.isNotEmpty
                  ? NetworkImage(offer.driverPhoto)
                  : null,
              child: offer.driverPhoto.isEmpty ? const Icon(Icons.person) : null,
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
                      Icon(Icons.star, size: 14, color: Colors.amber[700]),
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
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${offer.vehicleModel} • ${offer.vehicleColor}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Precio más grande y prominente (fontSize 32, bold)
                Text(
                  'S/.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: ModernTheme.rappiOrange,
                  ),
                ),
                Text(
                  offer.acceptedPrice.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: ModernTheme.rappiOrange,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                ElevatedButton(
                  onPressed: () => _acceptOffer(negotiationId, offer.driverId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ModernTheme.success,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                  ),
                  child: const Text(
                    'Aceptar',
                    style: TextStyle(fontSize: 13),
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
          color: ModernTheme.error,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_off, size: 16, color: Colors.white),
            const SizedBox(width: 4),
            const Text(
              'Expirado',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: minutes < 2 ? ModernTheme.error : ModernTheme.warning,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '$minutes:${seconds.toString().padLeft(2, '0')}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color color,
    required String label,
    required String address,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(NegotiationStatus status) {
    switch (status) {
      case NegotiationStatus.waiting:
        return ModernTheme.warning;
      case NegotiationStatus.negotiating:
        return ModernTheme.rappiOrange;
      case NegotiationStatus.accepted:
        return ModernTheme.success;
      case NegotiationStatus.expired:
      case NegotiationStatus.cancelled:
        return ModernTheme.error;
      default:
        return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
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
              backgroundColor: ModernTheme.success,
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
            child: CircularProgressIndicator(color: ModernTheme.rappiOrange),
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
              backgroundColor: ModernTheme.success,
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
              backgroundColor: ModernTheme.error,
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
              backgroundColor: ModernTheme.error,
            ),
          );
        }
      }
    }
  }
}
