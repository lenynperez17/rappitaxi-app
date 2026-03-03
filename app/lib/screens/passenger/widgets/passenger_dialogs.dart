import 'package:flutter/material.dart';

import '../../../core/design/rt_colors.dart';
import '../../../core/design/rt_tokens.dart';
import '../../../core/design/rt_typography.dart';
import '../../../core/widgets/rt_avatar.dart';
import '../../../models/price_negotiation_model.dart' as models;
import '../../../core/widgets/rt_animated_widgets.dart';

/// Dialogos reutilizables para el flujo del pasajero.
/// Confirmar viaje, aceptar oferta, conductor confirmado, logout.
class PassengerDialogs {
  PassengerDialogs._();

  /// Dialogo para confirmar aceptación de una oferta de conductor
  static Future<bool?> showAcceptOffer(BuildContext context, models.DriverOffer offer) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderXl),
        title: Row(
          children: [
            Icon(Icons.check_circle_outline, color: RtColors.success, size: RtIconSize.lg),
            const SizedBox(width: RtSpacing.md),
            const Text('Confirmar viaje'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info del conductor
            Row(
              children: [
                RtAvatar(
                  imageUrl: offer.driverPhoto.isNotEmpty ? offer.driverPhoto : null,
                  name: offer.driverName,
                  size: RtAvatarSize.medium,
                ),
                const SizedBox(width: RtSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(offer.driverName, style: RtTypo.titleLarge.copyWith(fontWeight: FontWeight.w600)),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 14, color: RtColors.warning),
                          const SizedBox(width: 4),
                          Text(offer.driverRating.toStringAsFixed(1), style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: RtSpacing.base),

            // Vehículo
            Text(offer.vehicleModel, style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500)),
            Text('${offer.vehiclePlate}  •  ${offer.vehicleColor}', style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500)),
            const SizedBox(height: RtSpacing.base),

            // Precio acordado
            Container(
              padding: const EdgeInsets.all(RtSpacing.md),
              decoration: BoxDecoration(
                color: RtColors.success.withValues(alpha: 0.1),
                borderRadius: RtRadius.borderMd,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Precio acordado:', style: RtTypo.bodyLarge),
                  Text(
                    'S/. ${offer.acceptedPrice.toStringAsFixed(2)}',
                    style: RtTypo.headingMedium.copyWith(color: RtColors.success),
                  ),
                ],
              ),
            ),
            const SizedBox(height: RtSpacing.sm),

            // Tiempo de llegada
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: RtColors.info),
                const SizedBox(width: 4),
                Text('Llega en ~${offer.estimatedArrival} min', style: RtTypo.bodySmall.copyWith(color: RtColors.info)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: RtColors.success,
              foregroundColor: RtColors.white,
              shape: RoundedRectangleBorder(borderRadius: RtRadius.borderMd),
            ),
            child: const Text('Aceptar viaje'),
          ),
        ],
      ),
    );
  }

  /// Dialogo de loading mientras se acepta una oferta
  static void showAcceptingLoading(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderXl),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ModernLoadingIndicator(color: RtColors.brand),
            const SizedBox(height: RtSpacing.lg),
            Text('Aceptando oferta...', style: RtTypo.bodyLarge),
          ],
        ),
      ),
    );
  }

  /// Dialogo de confirmación de conductor asignado
  static void showDriverAccepted(
    BuildContext context,
    models.DriverOffer offer,
    String rideId,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderXl),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: RtColors.success, size: 64),
            const SizedBox(height: RtSpacing.lg),
            Text('Conductor confirmado!', style: RtTypo.headingMedium),
            const SizedBox(height: RtSpacing.sm),
            Text(
              '${offer.driverName} esta en camino',
              style: RtTypo.bodyMedium.copyWith(color: RtColors.neutral500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: RtSpacing.xs),
            Text(
              'Llegara en aproximadamente ${offer.estimatedArrival} minutos',
              style: RtTypo.bodySmall.copyWith(color: RtColors.info),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: RtSpacing.lg),
            AnimatedPulseButton(
              text: 'Ver seguimiento',
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.pushNamed(
                  dialogContext,
                  '/trip-tracking',
                  arguments: {'rideId': rideId},
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Dialogo de confirmación de logout
  static void showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: RtColors.error),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }
}
