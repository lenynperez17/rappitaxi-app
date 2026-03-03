import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/design_system.dart';
import '../../../core/widgets/rt_badge.dart';
import '../../../core/widgets/rt_card.dart';
import '../../../providers/document_provider.dart';

/// Panel superior del conductor con toggle online/offline,
/// banners de créditos, documentos y estadísticas del día
class DriverStatusBar extends StatelessWidget {
  final bool isOnline;
  final ValueChanged<bool> onOnlineChanged;
  final bool isCheckingCredits;
  final bool hasEnoughCredits;
  final double serviceCredits;
  final double minServiceCredits;
  final double todayEarnings;
  final int todayTrips;
  final double acceptanceRate;

  const DriverStatusBar({
    super.key,
    required this.isOnline,
    required this.onOnlineChanged,
    required this.isCheckingCredits,
    required this.hasEnoughCredits,
    required this.serviceCredits,
    required this.minServiceCredits,
    required this.todayEarnings,
    required this.todayTrips,
    required this.acceptanceRate,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RtCard(
        margin: RtSpacing.paddingBase,
        padding: RtSpacing.paddingBase,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildOnlineToggle(context),
            if (!isCheckingCredits && !hasEnoughCredits)
              _buildCreditsWarningBanner(context),
            if (!isCheckingCredits && hasEnoughCredits)
              _buildCreditsBalance(),
            _buildDocumentsBanner(context),
            if (isOnline) ...[
              const Divider(height: RtSpacing.xl),
              _buildDayStats(context),
            ],
          ],
        ),
      ),
    );
  }

  /// Switch online/offline con texto de estado
  Widget _buildOnlineToggle(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          isOnline ? 'En línea' : 'Fuera de línea',
          style: RtTypo.headingSmall.copyWith(
            color: isOnline ? RtColors.success : RtColors.neutral500,
          ),
        ),
        Switch(
          value: isOnline,
          onChanged: onOnlineChanged,
          activeTrackColor: RtColors.success.withValues(alpha: 0.4),
          thumbColor: WidgetStatePropertyAll(
            isOnline ? RtColors.success : RtColors.neutral400,
          ),
        ),
      ],
    );
  }

  /// Banner de créditos insuficientes
  Widget _buildCreditsWarningBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: RtSpacing.md),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/driver/recharge-credits'),
        borderRadius: RtRadius.borderMd,
        child: Container(
          padding: RtSpacing.paddingMd,
          decoration: BoxDecoration(
            color: RtColors.warningLight,
            borderRadius: RtRadius.borderMd,
            border: Border.all(
              color: RtColors.warning.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: RtSpacing.paddingSm,
                decoration: BoxDecoration(
                  color: RtColors.warning.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: RtColors.warning,
                  size: RtIconSize.sm,
                ),
              ),
              const SizedBox(width: RtSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Créditos de servicio insuficientes',
                      style: RtTypo.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Créditos: S/. ${serviceCredits.toStringAsFixed(2)} '
                      '(min: S/. ${minServiceCredits.toStringAsFixed(2)}) - Toca para recargar',
                      style: RtTypo.labelSmall.copyWith(
                        color: RtColors.neutral500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: RtColors.warning,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Saldo de créditos cuando tiene suficiente
  Widget _buildCreditsBalance() {
    return Container(
      margin: const EdgeInsets.only(top: RtSpacing.sm),
      child: RtBadge(
        label: 'Créditos: S/. ${serviceCredits.toStringAsFixed(2)}',
        color: RtColors.success,
        variant: RtBadgeVariant.subtle,
        icon: Icons.account_balance_wallet,
      ),
    );
  }

  /// Banner de documentos pendientes
  Widget _buildDocumentsBanner(BuildContext context) {
    return Consumer<DocumentProvider>(
      builder: (context, docProvider, _) {
        final status = docProvider.verificationStatus;
        if (status == null || status.isEmpty) return const SizedBox.shrink();

        final isVerified = status['isVerified'] == true;
        final verificationStatus =
            status['verificationStatus']?.toString() ?? 'pending';

        if (isVerified || verificationStatus == 'approved') {
          return const SizedBox.shrink();
        }

        Color bannerColor;
        String title;
        String subtitle;
        IconData icon;

        switch (verificationStatus) {
          case 'under_review':
            bannerColor = RtColors.info;
            title = 'Documentos en revisión';
            subtitle = 'Te notificaremos cuando sean aprobados';
            icon = Icons.hourglass_empty;
          case 'rejected':
            bannerColor = RtColors.error;
            title = 'Documentos rechazados';
            subtitle = 'Revisa y vuelve a subir los documentos';
            icon = Icons.error_outline;
          default:
            bannerColor = RtColors.warning;
            title = 'Documentos pendientes';
            subtitle = 'Completa tu documentacion para trabajar';
            icon = Icons.description_outlined;
        }

        return Container(
          margin: const EdgeInsets.only(top: RtSpacing.md),
          child: InkWell(
            onTap: () => Navigator.pushNamed(context, '/driver/documents'),
            borderRadius: RtRadius.borderMd,
            child: Container(
              padding: RtSpacing.paddingMd,
              decoration: BoxDecoration(
                color: bannerColor.withValues(alpha: 0.1),
                borderRadius: RtRadius.borderMd,
                border: Border.all(
                  color: bannerColor.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: RtSpacing.paddingSm,
                    decoration: BoxDecoration(
                      color: bannerColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: bannerColor, size: RtIconSize.sm),
                  ),
                  const SizedBox(width: RtSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: RtTypo.titleMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: RtTypo.labelSmall.copyWith(
                            color: RtColors.neutral500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: bannerColor),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Estadísticas del día: ganancias, viajes, aceptación
  Widget _buildDayStats(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatistic(
          'Ganancias',
          'S/. ${todayEarnings.toStringAsFixed(2)}',
          Icons.monetization_on,
        ),
        _buildStatistic(
          'Viajes',
          '$todayTrips',
          Icons.directions_car,
        ),
        _buildStatistic(
          'Aceptación',
          acceptanceRate > 0
              ? '${acceptanceRate.toStringAsFixed(1)}%'
              : 'N/A',
          Icons.star,
        ),
      ],
    );
  }

  Widget _buildStatistic(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: RtColors.brand, size: RtIconSize.md),
        const SizedBox(height: RtSpacing.xs),
        Text(
          value,
          style: RtTypo.titleLarge.copyWith(
            fontWeight: FontWeight.w700,
            color: RtColors.neutral900,
          ),
        ),
        Text(
          label,
          style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500),
        ),
      ],
    );
  }
}
