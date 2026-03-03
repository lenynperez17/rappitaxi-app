import 'package:flutter/material.dart';

import '../../../core/design/design_system.dart';
import '../../../core/widgets/rt_avatar.dart';
import '../../../core/widgets/rt_badge.dart';
import '../../../core/widgets/rt_button.dart';
import '../../../core/widgets/rt_card.dart';
import '../../../models/price_negotiation_model.dart';
import '../../../core/widgets/rt_animated_widgets.dart';

/// Card compacta de solicitud de viaje para la lista horizontal
class DriverTripRequestCard extends StatelessWidget {
  final PriceNegotiation request;
  final VoidCallback onTap;

  const DriverTripRequestCard({
    super.key,
    required this.request,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final timeRemaining = request.timeRemaining;
    final isExpired = timeRemaining.isNegative || timeRemaining.inSeconds <= 0;
    final isUrgent = !isExpired && timeRemaining.inMinutes < 2;

    return AnimatedElevatedCard(
      onTap: onTap,
      borderRadius: RtRadius.lg,
      child: Container(
        width: 280,
        padding: RtSpacing.paddingBase,
        margin: const EdgeInsets.only(right: RtSpacing.md),
        decoration: isUrgent
            ? BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    RtColors.warning.withValues(alpha: 0.1),
                    RtColors.white,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: RtSpacing.md),
            _buildRouteInfo(),
            const Spacer(),
            _buildFooter(isExpired, isUrgent),
          ],
        ),
      ),
    );
  }

  /// Fila superior: avatar, nombre, rating y precio
  Widget _buildHeader() {
    return Row(
      children: [
        RtAvatar(
          imageUrl: request.passengerPhoto,
          name: request.passengerName,
          size: RtAvatarSize.small,
        ),
        const SizedBox(width: RtSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                request.passengerName,
                style: RtTypo.titleLarge.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                children: [
                  const Icon(
                    Icons.star,
                    size: RtIconSize.xs,
                    color: RtColors.warning,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    request.passengerRating.toStringAsFixed(1),
                    style: RtTypo.bodySmall.copyWith(
                      color: RtColors.neutral500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        RtBadge(
          label: 'S/. ${request.offeredPrice.toStringAsFixed(2)}',
          color: RtColors.success,
          variant: RtBadgeVariant.subtle,
        ),
      ],
    );
  }

  /// Direcciones de recogida y destino
  Widget _buildRouteInfo() {
    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.location_on, size: RtIconSize.xs, color: RtColors.success),
            const SizedBox(width: RtSpacing.xs),
            Expanded(
              child: Text(
                request.pickup.address,
                style: RtTypo.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: RtSpacing.xs),
        Row(
          children: [
            const Icon(Icons.flag, size: RtIconSize.xs, color: RtColors.error),
            const SizedBox(width: RtSpacing.xs),
            Expanded(
              child: Text(
                request.destination.address,
                style: RtTypo.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Distancia, tiempo estimado y temporizador
  Widget _buildFooter(bool isExpired, bool isUrgent) {
    Color timerColor;
    if (isExpired) {
      timerColor = RtColors.error;
    } else if (isUrgent) {
      timerColor = RtColors.warning;
    } else {
      timerColor = RtColors.info;
    }

    final timeRemaining = request.timeRemaining;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.route, size: 14, color: RtColors.neutral500),
            const SizedBox(width: RtSpacing.xs),
            Text(
              '${request.distance.toStringAsFixed(1)} km',
              style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500),
            ),
            const SizedBox(width: RtSpacing.sm),
            Icon(Icons.access_time, size: 14, color: RtColors.neutral500),
            const SizedBox(width: RtSpacing.xs),
            Text(
              '${request.estimatedTime} min',
              style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: timerColor,
            borderRadius: RtRadius.borderMd,
          ),
          child: Text(
            isExpired
                ? 'Expirado'
                : '${timeRemaining.inMinutes}:${(timeRemaining.inSeconds % 60).toString().padLeft(2, '0')}',
            style: RtTypo.labelSmall.copyWith(
              color: RtColors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// Sheet de detalle expandido para una solicitud seleccionada
class DriverTripDetailSheet extends StatelessWidget {
  final PriceNegotiation request;
  final VoidCallback onClose;
  final VoidCallback onReject;
  final VoidCallback onNegotiate;
  final VoidCallback onAccept;

  const DriverTripDetailSheet({
    super.key,
    required this.request,
    required this.onClose,
    required this.onReject,
    required this.onNegotiate,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: RtRadius.sheetTop,
        boxShadow: RtShadow.strong(),
      ),
      padding: const EdgeInsets.all(RtSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSheetHandle(context),
          const SizedBox(height: RtSpacing.base),
          _buildPassengerInfo(context),
          const SizedBox(height: RtSpacing.xl),
          _buildRouteDetail(context),
          const SizedBox(height: RtSpacing.base),
          _buildInfoChips(context),
          if (request.notes != null && request.notes!.isNotEmpty) ...[
            const SizedBox(height: RtSpacing.base),
            _buildNotes(),
          ],
          const SizedBox(height: RtSpacing.xl),
          _buildActionButtons(),
        ],
      ),
    );
  }

  /// Handle del sheet con boton de cerrar
  Widget _buildSheetHandle(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: RtColors.neutral300,
            borderRadius: RtRadius.borderFull,
          ),
        ),
        Positioned(
          right: 0,
          child: GestureDetector(
            onTap: onClose,
            child: Container(
              padding: RtSpacing.paddingXs,
              decoration: const BoxDecoration(
                color: RtColors.neutral200,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 18,
                color: RtColors.neutral500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Info del pasajero: foto, nombre, rating, pago, precio
  Widget _buildPassengerInfo(BuildContext context) {
    return Row(
      children: [
        RtAvatar(
          imageUrl: request.passengerPhoto,
          name: request.passengerName,
          size: RtAvatarSize.large,
        ),
        const SizedBox(width: RtSpacing.base),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                request.passengerName,
                style: RtTypo.headingSmall,
              ),
              Row(
                children: [
                  const Icon(Icons.star, size: RtIconSize.xs, color: RtColors.warning),
                  const SizedBox(width: RtSpacing.xs),
                  Text(
                    request.passengerRating.toStringAsFixed(1),
                    style: RtTypo.bodyMedium.copyWith(color: RtColors.neutral500),
                  ),
                  const SizedBox(width: RtSpacing.md),
                  Icon(
                    request.paymentMethod == PaymentMethod.cash
                        ? Icons.money
                        : Icons.credit_card,
                    size: RtIconSize.xs,
                    color: RtColors.neutral500,
                  ),
                  const SizedBox(width: RtSpacing.xs),
                  Text(
                    request.paymentMethod == PaymentMethod.cash
                        ? 'Efectivo'
                        : 'Tarjeta',
                    style: RtTypo.bodyMedium.copyWith(color: RtColors.neutral500),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: RtSpacing.lg,
            vertical: RtSpacing.sm,
          ),
          decoration: BoxDecoration(
            gradient: RtGradients.success,
            borderRadius: RtRadius.borderFull,
          ),
          child: Text(
            'S/. ${request.offeredPrice.toStringAsFixed(2)}',
            style: RtTypo.headingMedium.copyWith(color: RtColors.white),
          ),
        ),
      ],
    );
  }

  /// Detalle de ruta: recogida y destino con linea conectora
  Widget _buildRouteDetail(BuildContext context) {
    return RtCard(
      variant: RtCardVariant.filled,
      padding: RtSpacing.paddingBase,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: RtColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: RtSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recogida',
                      style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500),
                    ),
                    Text(
                      request.pickup.address,
                      style: RtTypo.titleMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 5),
            child: Container(
              height: 30,
              width: 1,
              color: RtColors.neutral300,
            ),
          ),
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: RtColors.error,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: RtSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Destino',
                      style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500),
                    ),
                    Text(
                      request.destination.address,
                      style: RtTypo.titleMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Chips de información: distancia, tiempo, temporizador
  Widget _buildInfoChips(BuildContext context) {
    final timeRemaining = request.timeRemaining;
    final isExpired = timeRemaining.isNegative || timeRemaining.inSeconds <= 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildInfoChip(Icons.route, '${request.distance.toStringAsFixed(1)} km'),
        _buildInfoChip(Icons.access_time, '${request.estimatedTime} min'),
        _buildInfoChip(
          Icons.timer,
          isExpired
              ? 'Expirado'
              : '${timeRemaining.inMinutes}:${(timeRemaining.inSeconds % 60).toString().padLeft(2, '0')}',
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RtSpacing.md,
        vertical: RtSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: RtColors.neutral100,
        borderRadius: RtRadius.borderMd,
      ),
      child: Row(
        children: [
          Icon(icon, size: RtIconSize.xs, color: RtColors.neutral500),
          const SizedBox(width: RtSpacing.xs),
          Text(
            text,
            style: RtTypo.titleMedium.copyWith(color: RtColors.neutral500),
          ),
        ],
      ),
    );
  }

  /// Notas del pasajero
  Widget _buildNotes() {
    return Container(
      padding: RtSpacing.paddingMd,
      decoration: BoxDecoration(
        color: RtColors.infoLight,
        borderRadius: RtRadius.borderMd,
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: RtColors.info, size: RtIconSize.sm),
          const SizedBox(width: RtSpacing.sm),
          Expanded(
            child: Text(
              request.notes!,
              style: RtTypo.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  /// Botones de accion: rechazar, negociar, aceptar
  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: RtButton(
                label: 'Rechazar',
                onPressed: onReject,
                variant: RtButtonVariant.outlined,
                icon: Icons.close,
                size: RtButtonSize.medium,
              ),
            ),
            const SizedBox(width: RtSpacing.md),
            Expanded(
              child: RtButton(
                label: 'Negociar',
                onPressed: onNegotiate,
                variant: RtButtonVariant.outlined,
                icon: Icons.price_change,
                size: RtButtonSize.medium,
              ),
            ),
          ],
        ),
        const SizedBox(height: RtSpacing.md),
        SizedBox(
          width: double.infinity,
          child: AnimatedPulseButton(
            text: 'Aceptar viaje',
            icon: Icons.check,
            color: RtColors.success,
            onPressed: onAccept,
          ),
        ),
      ],
    );
  }
}
