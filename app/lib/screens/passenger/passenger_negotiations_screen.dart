import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design/rt_colors.dart';
import '../../core/design/rt_tokens.dart';
import '../../core/design/rt_typography.dart';
import '../../core/widgets/rt_animated_list_item.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_avatar.dart';
import '../../core/widgets/rt_badge.dart';
import '../../core/widgets/rt_button.dart';
import '../../core/widgets/rt_card.dart';
import '../../core/widgets/rt_empty_state.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../models/price_negotiation_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/price_negotiation_provider.dart';
import '../../utils/firestore_error_handler.dart';

// ============================================================
// Pantalla de negociaciones del pasajero
// ============================================================

class PassengerNegotiationsScreen extends StatefulWidget {
  const PassengerNegotiationsScreen({super.key});

  @override
  State<PassengerNegotiationsScreen> createState() =>
      _PassengerNegotiationsScreenState();
}

class _PassengerNegotiationsScreenState
    extends State<PassengerNegotiationsScreen> {
  Timer? _countdownTimer;
  PriceNegotiationProvider? _negotiationProvider;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _negotiationProvider =
          Provider.of<PriceNegotiationProvider>(context, listen: false);

      // Limpiar negociaciones cuyo viaje fue cancelado
      await _negotiationProvider!.cleanupCancelledNegotiations();

      // Expirar negociaciones vencidas
      await _negotiationProvider!.expireOldNegotiations();

      _negotiationProvider!.startListeningToMyNegotiations();
    });

    // Timer para actualizar el cronometro cada segundo
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
        _checkAndExpireNegotiations();
      }
    });
  }

  void _checkAndExpireNegotiations() {
    final provider =
        Provider.of<PriceNegotiationProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id ?? '';
    final now = DateTime.now();

    final myActiveNegotiations = provider.activeNegotiations
        .where((n) => n.passengerId == currentUserId)
        .where((n) =>
            n.status == NegotiationStatus.waiting ||
            n.status == NegotiationStatus.negotiating)
        .toList();

    bool anyExpired = false;
    for (final negotiation in myActiveNegotiations) {
      if (negotiation.expiresAt.isBefore(now)) {
        debugPrint('Auto-expirando negociación: ${negotiation.id}');
        provider.expireOldNegotiations();
        anyExpired = true;
        break;
      }
    }

    if (anyExpired) {
      final remainingValid = provider.activeNegotiations
          .where((n) => n.passengerId == currentUserId)
          .where((n) =>
              n.status == NegotiationStatus.waiting ||
              n.status == NegotiationStatus.negotiating)
          .where((n) => n.expiresAt.isAfter(now))
          .toList();

      if (remainingValid.isEmpty && mounted) {
        RtSnackbar.show(
          context,
          message: 'Tu solicitud ha expirado. Puedes crear una nueva.',
          type: RtSnackbarType.warning,
        );

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) Navigator.of(context).pop();
        });
      }
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _negotiationProvider?.stopListeningToNegotiations();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id ?? '';

    return Scaffold(
      backgroundColor: RtColors.neutral50,
      appBar: const RtAppBar(
        title: 'Mis Negociaciones',
        variant: RtAppBarVariant.gradient,
      ),
      body: Consumer<PriceNegotiationProvider>(
        builder: (context, provider, _) {
          // Detectar negociación aceptada
          final acceptedNegotiations = provider.activeNegotiations
              .where((n) => n.passengerId == currentUserId)
              .where((n) => n.status == NegotiationStatus.accepted)
              .toList();

          if (acceptedNegotiations.isNotEmpty) {
            _handleAcceptedNegotiation(
                acceptedNegotiations.first, provider);
          }

          // Filtrar negociaciones activas no expiradas
          final now = DateTime.now();
          final myNegotiations = provider.activeNegotiations
              .where((n) => n.passengerId == currentUserId)
              .where((n) =>
                  n.status == NegotiationStatus.waiting ||
                  n.status == NegotiationStatus.negotiating)
              .where((n) => n.expiresAt.isAfter(now))
              .toList();

          if (myNegotiations.isEmpty) {
            return const RtEmptyState(
              icon: Icons.inbox_outlined,
              title: 'No tienes negociaciones activas',
              description: 'Solicita un viaje para comenzar',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(RtSpacing.base),
            itemCount: myNegotiations.length,
            itemBuilder: (context, index) {
              return RtAnimatedListItem(
                index: index,
                child: _buildNegotiationCard(myNegotiations[index]),
              );
            },
          );
        },
      ),
    );
  }

  // ============================================================
  // Navegacion automatica al aceptar
  // ============================================================

  void _handleAcceptedNegotiation(
    PriceNegotiation negotiation,
    PriceNegotiationProvider provider,
  ) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final wasCancelled =
          await provider.checkAndHandleCancelledRide(negotiation.id);
      if (wasCancelled) return;

      final rideId = await provider.getRideIdForNegotiation(negotiation.id);

      if (rideId != null && mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content:
                Text('Un conductor acepto tu viaje! Iniciando tracking...'),
            backgroundColor: RtColors.success,
            duration: Duration(seconds: 2),
          ),
        );

        navigator.pushReplacementNamed(
          '/trip-tracking',
          arguments: {'rideId': rideId},
        );
      }
    });
  }

  // ============================================================
  // Tarjeta de negociación
  // ============================================================

  Widget _buildNegotiationCard(PriceNegotiation negotiation) {
    final hasOffers = negotiation.driverOffers.isNotEmpty;
    final bestOffer = negotiation.bestOffer;

    return Padding(
      padding: const EdgeInsets.only(bottom: RtSpacing.base),
      child: RtCard(
        child: Column(
          children: [
            // Header con estado y timer
            Container(
              padding: const EdgeInsets.all(RtSpacing.base),
              decoration: BoxDecoration(
                color: _getStatusColor(negotiation.status).withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        _getStatusIcon(negotiation.status),
                        color: _getStatusColor(negotiation.status),
                        size: RtIconSize.sm,
                      ),
                      const SizedBox(width: RtSpacing.sm),
                      Text(
                        _getStatusText(negotiation.status),
                        style: RtTypo.labelMedium.copyWith(
                          color: _getStatusColor(negotiation.status),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  _buildTimer(negotiation),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(RtSpacing.base),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Origen
                  _buildLocationRow(
                    icon: Icons.radio_button_checked,
                    color: RtColors.success,
                    label: 'Origen',
                    address: negotiation.pickup.address,
                  ),
                  const SizedBox(height: RtSpacing.md),
                  // Destino
                  _buildLocationRow(
                    icon: Icons.location_on,
                    color: RtColors.error,
                    label: 'Destino',
                    address: negotiation.destination.address,
                  ),

                  const SizedBox(height: RtSpacing.base),

                  // Precio ofrecido
                  Container(
                    padding: const EdgeInsets.all(RtSpacing.md),
                    decoration: BoxDecoration(
                      color: RtColors.brand.withValues(alpha: 0.08),
                      borderRadius: RtRadius.borderMd,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tu precio ofrecido:',
                          style: RtTypo.bodyMedium.copyWith(
                            color: RtColors.neutral700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'S/. ${negotiation.offeredPrice.toStringAsFixed(2)}',
                          style: RtTypo.headingSmall.copyWith(
                            color: RtColors.brand,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Ofertas de conductores
                  if (hasOffers) ...[
                    const SizedBox(height: RtSpacing.base),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Ofertas recibidas (${negotiation.driverOffers.length})',
                          style: RtTypo.titleMedium.copyWith(
                            color: RtColors.neutral900,
                          ),
                        ),
                        if (bestOffer != null)
                          RtBadge(
                            label: 'Mejor: S/. ${bestOffer.acceptedPrice.toStringAsFixed(2)}',
                            icon: Icons.trending_down,
                            color: RtColors.success,
                            variant: RtBadgeVariant.subtle,
                          ),
                      ],
                    ),
                    const SizedBox(height: RtSpacing.md),
                    ...negotiation.driverOffers.map(
                      (offer) =>
                          _buildOfferCard(offer, negotiation.id),
                    ),
                  ],

                  // Esperando ofertas
                  if (!hasOffers) ...[
                    const SizedBox(height: RtSpacing.base),
                    Container(
                      padding: const EdgeInsets.all(RtSpacing.base),
                      decoration: BoxDecoration(
                        color: RtColors.neutral100,
                        borderRadius: RtRadius.borderMd,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.hourglass_empty,
                            color: RtColors.neutral500,
                          ),
                          const SizedBox(width: RtSpacing.md),
                          Expanded(
                            child: Text(
                              'Esperando ofertas de conductores...',
                              style: RtTypo.bodyMedium.copyWith(
                                color: RtColors.neutral600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Boton cancelar
                  const SizedBox(height: RtSpacing.base),
                  RtButton(
                    label: 'Cancelar solicitud',
                    icon: Icons.close,
                    variant: RtButtonVariant.outlined,
                    onPressed: () => _cancelNegotiation(negotiation.id),
                    isFullWidth: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Tarjeta de oferta individual
  // ============================================================

  Widget _buildOfferCard(DriverOffer offer, String negotiationId) {
    return Padding(
      padding: const EdgeInsets.only(bottom: RtSpacing.sm),
      child: RtCard(
        variant: RtCardVariant.outlined,
        child: Padding(
          padding: const EdgeInsets.all(RtSpacing.md),
          child: Row(
            children: [
              RtAvatar(
                imageUrl: offer.driverPhoto,
                name: offer.driverName,
                size: RtAvatarSize.medium,
              ),
              const SizedBox(width: RtSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.driverName,
                      style: RtTypo.titleSmall.copyWith(
                        color: RtColors.neutral900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.star, size: 14, color: Colors.amber[700]),
                        const SizedBox(width: RtSpacing.xs),
                        Text(
                          offer.driverRating.toStringAsFixed(1),
                          style: RtTypo.bodySmall.copyWith(
                            color: RtColors.neutral700,
                          ),
                        ),
                        const SizedBox(width: RtSpacing.sm),
                        Text(
                          '${offer.completedTrips} viajes',
                          style: RtTypo.bodySmall.copyWith(
                            color: RtColors.neutral500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${offer.vehicleModel} - ${offer.vehicleColor}',
                      style: RtTypo.labelSmall.copyWith(
                        color: RtColors.neutral500,
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
                    style: RtTypo.headingSmall.copyWith(
                      color: RtColors.brand,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: RtSpacing.xs),
                  RtButton(
                    label: 'Aceptar',
                    size: RtButtonSize.small,
                    onPressed: () =>
                        _acceptOffer(negotiationId, offer.driverId),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Timer de expiracion
  // ============================================================

  Widget _buildTimer(PriceNegotiation negotiation) {
    final remaining = negotiation.timeRemaining;

    if (remaining.isNegative || remaining.inSeconds <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: RtSpacing.md,
          vertical: RtSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: RtColors.error,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_off, size: 16, color: Colors.white),
            SizedBox(width: RtSpacing.xs),
            Text(
              'Expirado',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    final isUrgent = minutes < 2;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RtSpacing.md,
        vertical: RtSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: isUrgent ? RtColors.error : RtColors.warning,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer, size: 16, color: Colors.white),
          const SizedBox(width: RtSpacing.xs),
          Text(
            '$minutes:${seconds.toString().padLeft(2, '0')}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Fila de ubicación
  // ============================================================

  Widget _buildLocationRow({
    required IconData icon,
    required Color color,
    required String label,
    required String address,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: RtIconSize.sm),
        const SizedBox(width: RtSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: RtTypo.labelSmall.copyWith(
                  color: RtColors.neutral500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: RtTypo.bodyMedium.copyWith(
                  color: RtColors.neutral800,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // Helpers de estado
  // ============================================================

  Color _getStatusColor(NegotiationStatus status) {
    switch (status) {
      case NegotiationStatus.waiting:
        return RtColors.warning;
      case NegotiationStatus.negotiating:
        return RtColors.brand;
      case NegotiationStatus.accepted:
        return RtColors.success;
      case NegotiationStatus.expired:
      case NegotiationStatus.cancelled:
        return RtColors.error;
      default:
        return RtColors.neutral500;
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

  // ============================================================
  // Acciones
  // ============================================================

  Future<void> _cancelNegotiation(String negotiationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderLg),
        title: const Text('Cancelar solicitud'),
        content: const Text(
          'Estás seguro de que quieres cancelar esta solicitud de viaje?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          RtButton(
            label: 'Sí, cancelar',
            variant: RtButtonVariant.danger,
            size: RtButtonSize.small,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider =
          Provider.of<PriceNegotiationProvider>(context, listen: false);

      try {
        await provider.cancelNegotiation(negotiationId);

        if (mounted) {
          RtSnackbar.show(
            context,
            message: 'Solicitud cancelada',
            type: RtSnackbarType.warning,
          );

          if (provider.activeNegotiations.isEmpty) {
            Navigator.pop(context);
          }
        }
      } catch (e) {
        if (mounted) {
          RtSnackbar.show(
            context,
            message: FirestoreErrorHandler.getSpanishMessage(e),
            type: RtSnackbarType.error,
          );
        }
      }
    }
  }

  Future<void> _acceptOffer(String negotiationId, String driverId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderLg),
        title: const Text('Aceptar oferta'),
        content: const Text(
          'Estás seguro de que quieres aceptar esta oferta? '
          'El conductor será notificado y el viaje comenzará.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          RtButton(
            label: 'Aceptar',
            size: RtButtonSize.small,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider =
          Provider.of<PriceNegotiationProvider>(context, listen: false);

      try {
        // Mostrar loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(
            child: CircularProgressIndicator(color: RtColors.brand),
          ),
        );

        final rideId =
            await provider.acceptDriverOffer(negotiationId, driverId);

        if (mounted) Navigator.pop(context); // Cerrar loading

        if (rideId != null && mounted) {
          RtSnackbar.show(
            context,
            message: 'Oferta aceptada! Tu conductor esta en camino.',
            type: RtSnackbarType.success,
          );

          Navigator.pushReplacementNamed(
            context,
            '/trip-tracking',
            arguments: {'rideId': rideId},
          );
        } else if (mounted) {
          RtSnackbar.show(
            context,
            message: 'Error al crear el viaje. Intentalo de nuevo.',
            type: RtSnackbarType.error,
          );
        }
      } catch (e) {
        if (mounted) Navigator.pop(context); // Cerrar loading

        if (mounted) {
          RtSnackbar.show(
            context,
            message: FirestoreErrorHandler.getSpanishMessage(e),
            type: RtSnackbarType.error,
          );
        }
      }
    }
  }
}
