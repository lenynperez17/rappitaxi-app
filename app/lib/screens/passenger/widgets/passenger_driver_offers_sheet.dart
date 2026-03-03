import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design/rt_colors.dart';
import '../../../core/design/rt_tokens.dart';
import '../../../core/design/rt_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/rt_avatar.dart';
import '../../../core/widgets/rt_card.dart';
import '../../../models/price_negotiation_model.dart' as models;

/// Bottom sheet que muestra las ofertas de conductores en tiempo real.
/// Incluye timer countdown con pulso, lista animada de cards con foto,
/// rating, precio, boton de aceptar, badge "Mejor oferta" y animaciones
/// de entrada slide-in con feedback haptico.
class PassengerDriverOffersSheet extends StatefulWidget {
  final models.PriceNegotiation? negotiation;
  final VoidCallback onClose;
  final Future<void> Function(models.DriverOffer offer) onAcceptOffer;

  const PassengerDriverOffersSheet({
    super.key,
    required this.negotiation,
    required this.onClose,
    required this.onAcceptOffer,
  });

  @override
  State<PassengerDriverOffersSheet> createState() =>
      _PassengerDriverOffersSheetState();
}

class _PassengerDriverOffersSheetState
    extends State<PassengerDriverOffersSheet>
    with TickerProviderStateMixin {
  /// Controlador para la animacion de pulso del timer
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  /// Controlador para la animacion de rotacion del icono de busqueda
  late AnimationController _searchRotationController;
  late Animation<double> _searchRotation;

  /// Cantidad previa de ofertas para detectar nuevas
  int _previousOffersCount = 0;

  /// Controladores de animacion para cada oferta (slide-in)
  final List<AnimationController> _offerSlideControllers = [];
  final List<Animation<Offset>> _offerSlideAnimations = [];

  @override
  void initState() {
    super.initState();

    // Animacion de pulso para timer
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Animacion de rotacion para icono de busqueda en estado vacio
    _searchRotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _searchRotation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(
        parent: _searchRotationController,
        curve: Curves.easeInOut,
      ),
    );

    _previousOffersCount = widget.negotiation?.driverOffers.length ?? 0;
    _initializeOfferAnimations();
  }

  @override
  void didUpdateWidget(covariant PassengerDriverOffersSheet oldWidget) {
    super.didUpdateWidget(oldWidget);

    final currentCount = widget.negotiation?.driverOffers.length ?? 0;

    // Detectar nuevas ofertas y animar su entrada
    if (currentCount > _previousOffersCount) {
      final newOffersCount = currentCount - _previousOffersCount;
      for (int i = 0; i < newOffersCount; i++) {
        _addOfferSlideAnimation();
      }
      HapticFeedback.selectionClick();
    }

    _previousOffersCount = currentCount;

    // Activar pulso del timer cuando queda poco tiempo (< 30s)
    final remaining = widget.negotiation?.timeRemaining;
    if (remaining != null &&
        !remaining.isNegative &&
        remaining.inSeconds <= 30 &&
        remaining.inSeconds > 0) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  /// Inicializa animaciones de slide para ofertas existentes
  void _initializeOfferAnimations() {
    final count = widget.negotiation?.driverOffers.length ?? 0;
    for (int i = 0; i < count; i++) {
      _addOfferSlideAnimation(animate: false);
    }
  }

  /// Agrega una animacion de slide-in para una nueva oferta
  void _addOfferSlideAnimation({bool animate = true}) {
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    final slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOut),
    );

    _offerSlideControllers.add(controller);
    _offerSlideAnimations.add(slideAnimation);

    if (animate) {
      controller.forward();
    } else {
      controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _searchRotationController.dispose();
    for (final controller in _offerSlideControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Determina cual es la mejor oferta (mejor rating O mejor precio)
  String? _getBestOfferId() {
    final offers = widget.negotiation?.driverOffers ?? [];
    if (offers.length < 2) return null;

    // Buscar la oferta con mejor combinacion de precio bajo y rating alto
    models.DriverOffer? best;
    double bestScore = -1;

    for (final offer in offers) {
      // Score compuesto: rating normalizado + precio inverso normalizado
      final maxPrice = offers
          .map((o) => o.acceptedPrice)
          .reduce((a, b) => a > b ? a : b);
      final priceScore =
          maxPrice > 0 ? (1 - (offer.acceptedPrice / maxPrice)) : 0;
      final ratingScore = offer.driverRating / 5.0;
      final score = (ratingScore * 0.4) + (priceScore * 0.6);

      if (score > bestScore) {
        bestScore = score;
        best = offer;
      }
    }

    return best?.driverId;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? RtColors.neutral900 : RtColors.white,
        borderRadius: RtRadius.sheetTop,
        boxShadow: RtShadow.strong(isDark: isDark),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context, isDark),
          _buildTitleRow(context, isDark),
          _buildOffersList(context, isDark),
          const SizedBox(height: RtSpacing.base),
        ],
      ),
    );
  }

  /// Handle con boton de cerrar
  Widget _buildHeader(BuildContext context, bool isDark) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Drag handle
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: isDark ? RtColors.neutral600 : RtColors.neutral300,
            borderRadius: RtRadius.borderFull,
          ),
        ),
        // Boton cerrar
        Positioned(
          right: RtSpacing.base,
          top: RtSpacing.sm,
          child: GestureDetector(
            onTap: widget.onClose,
            child: Container(
              padding: const EdgeInsets.all(RtSpacing.xs),
              decoration: BoxDecoration(
                color: isDark ? RtColors.neutral800 : RtColors.neutral100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close_rounded,
                size: RtIconSize.sm,
                color: RtColors.neutral500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Titulo con badge de conteo y timer con animacion de pulso
  Widget _buildTitleRow(BuildContext context, bool isDark) {
    final int offersCount = widget.negotiation?.driverOffers.length ?? 0;

    return Padding(
      padding: const EdgeInsets.all(RtSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Titulo con badge de conteo
          Expanded(
            child: Row(
              children: [
                Text(
                  'Ofertas de conductores',
                  style: RtTypo.headingMedium.copyWith(
                    color: isDark ? RtColors.white : RtColors.neutral900,
                  ),
                ),
                const SizedBox(width: RtSpacing.sm),
                // Badge con conteo (pill rojo brand con número blanco)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: RtSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: RtColors.brand,
                    borderRadius: RtRadius.borderFull,
                  ),
                  child: Text(
                    '$offersCount',
                    style: RtTypo.labelSmall.copyWith(
                      color: RtColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Timer countdown con pulso
          _buildCountdownBadge(isDark),
        ],
      ),
    );
  }

  /// Badge con tiempo restante y animacion de pulso cuando queda poco
  /// Helper que construye el pill visual del timer
  Widget _buildTimerPill(
    String text,
    Color color,
    bool isDark,
    bool isActive,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RtSpacing.md,
        vertical: RtSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: RtRadius.borderXl,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.timer_rounded : Icons.timer_off_rounded,
            size: RtIconSize.xs,
            color: color,
          ),
          const SizedBox(width: RtSpacing.xs),
          Text(
            text,
            style: RtTypo.labelLarge.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Badge con tiempo restante y animacion de pulso cuando queda poco
  Widget _buildCountdownBadge(bool isDark) {
    final Duration? remaining = widget.negotiation?.timeRemaining;

    // Si no hay tiempo restante o ya expiro, mostrar "Expirado"
    if (remaining == null || remaining.isNegative || remaining.inSeconds <= 0) {
      return _buildTimerPill('Expirado', RtColors.error, isDark, false);
    }

    final bool isLowTime = remaining.inSeconds <= 30;
    final String timerText =
        '${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}';
    final Color timerColor = isLowTime ? RtColors.error : RtColors.warning;

    final Widget badge = _buildTimerPill(timerText, timerColor, isDark, true);

    // Envolver con animacion de pulso si queda poco tiempo
    if (isLowTime) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: child,
          );
        },
        child: badge,
      );
    }

    return badge;
  }

  /// Lista scrollable de ofertas de conductores con animaciones
  Widget _buildOffersList(BuildContext context, bool isDark) {
    final offers = widget.negotiation?.driverOffers ?? [];

    if (offers.isEmpty) {
      return _buildEmptyState(isDark);
    }

    final bestOfferId = _getBestOfferId();

    return SizedBox(
      height: 300,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: RtSpacing.lg),
        itemCount: offers.length,
        itemBuilder: (context, index) {
          final offer = offers[index];
          final isBestOffer = bestOfferId == offer.driverId;

          // Aplicar animacion slide-in si existe
          Widget card = _buildOfferCard(context, isDark, offer, isBestOffer);

          if (index < _offerSlideAnimations.length) {
            card = SlideTransition(
              position: _offerSlideAnimations[index],
              child: card,
            );
          }

          return card;
        },
      ),
    );
  }

  /// Estado vacio animado cuando no hay ofertas
  Widget _buildEmptyState(bool isDark) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icono de busqueda con animacion de rotacion
            AnimatedBuilder(
              animation: _searchRotation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _searchRotation.value,
                  child: child,
                );
              },
              child: Icon(
                Icons.search_rounded,
                size: RtIconSize.xxl,
                color: RtColors.brand.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: RtSpacing.md),
            Text(
              'Buscando conductores cercanos...',
              style: RtTypo.bodyMedium.copyWith(
                color: isDark ? RtColors.neutral400 : RtColors.neutral500,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: RtSpacing.sm),
            Text(
              'Recibirás ofertas en segundos',
              style: RtTypo.bodySmall.copyWith(
                color: RtColors.neutral400,
              ),
            ),
            const SizedBox(height: RtSpacing.lg),
            // Barra de progreso lineal indeterminada roja brand
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: RtSpacing.xxxl),
              child: ClipRRect(
                borderRadius: RtRadius.borderFull,
                child: LinearProgressIndicator(
                  backgroundColor: isDark
                      ? RtColors.neutral800
                      : RtColors.brand.withValues(alpha: 0.1),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(RtColors.brand),
                  minHeight: 3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Card de oferta de conductor individual con badge "Mejor oferta"
  Widget _buildOfferCard(
    BuildContext context,
    bool isDark,
    models.DriverOffer offer,
    bool isBestOffer,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: RtSpacing.md),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          RtCard(
            variant: RtCardVariant.elevated,
            borderRadius: BorderRadius.circular(16),
            padding: const EdgeInsets.all(RtSpacing.base),
            child: Row(
              children: [
                // Zona izquierda: Avatar con badge online
                RtAvatar(
                  imageUrl: offer.driverPhoto.isNotEmpty
                      ? offer.driverPhoto
                      : null,
                  name: offer.driverName,
                  size: RtAvatarSize.large,
                  badgeColor: RtColors.success,
                ),
                const SizedBox(width: RtSpacing.md),

                // Zona centro: Información del conductor
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nombre del conductor
                      Text(
                        offer.driverName,
                        style: RtTypo.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? RtColors.white : RtColors.neutral900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),

                      // Rating con estrellas amarillas
                      Row(
                        children: [
                          ...List.generate(5, (i) {
                            final starValue = i + 1;
                            if (offer.driverRating >= starValue) {
                              return Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: RtColors.warning,
                              );
                            } else if (offer.driverRating >= starValue - 0.5) {
                              return Icon(
                                Icons.star_half_rounded,
                                size: 14,
                                color: RtColors.warning,
                              );
                            } else {
                              return Icon(
                                Icons.star_outline_rounded,
                                size: 14,
                                color: RtColors.neutral300,
                              );
                            }
                          }),
                          const SizedBox(width: RtSpacing.xs),
                          Text(
                            offer.driverRating.toStringAsFixed(1),
                            style: RtTypo.labelMedium.copyWith(
                              color: RtColors.neutral500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: RtSpacing.xs),

                      // Vehículo: modelo y color
                      Text(
                        '${offer.vehicleModel} - ${offer.vehicleColor}',
                        style: RtTypo.bodySmall.copyWith(
                          color: RtColors.neutral500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: RtSpacing.xs),

                      // Tiempo estimado de llegada
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 13,
                            color: RtColors.info,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${offer.estimatedArrival} min',
                            style: RtTypo.labelSmall.copyWith(
                              color: RtColors.info,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: RtSpacing.sm),

                // Zona derecha: Precio y boton Aceptar
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Precio
                    Text(
                      offer.acceptedPrice.toCurrency(),
                      style: RtTypo.headingSmall.copyWith(
                        color: RtColors.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: RtSpacing.sm),

                    // Boton "Aceptar"
                    SizedBox(
                      width: 90,
                      height: 36,
                      child: ElevatedButton(
                        onPressed: () => widget.onAcceptOffer(offer),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RtColors.success,
                          foregroundColor: RtColors.white,
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Aceptar',
                          style: RtTypo.labelMedium.copyWith(
                            color: RtColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Badge "Mejor oferta" posicionado en esquina superior derecha
          if (isBestOffer)
            Positioned(
              top: -6,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: RtSpacing.sm,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: RtColors.warning,
                  borderRadius: RtRadius.borderFull,
                  boxShadow: [
                    BoxShadow(
                      color: RtColors.warning.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  'Mejor oferta',
                  style: RtTypo.labelSmall.copyWith(
                    color: RtColors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
