import 'package:flutter/material.dart';

import '../../../core/design/design_system.dart';
import '../../../core/utils/currency_formatter.dart';
import '../driver_profile_screen.dart';

/// Header del perfil del conductor con avatar, nombre, rating y placa.
/// Incluye la seccion de estadísticas generales.
class DriverProfileHeader extends StatelessWidget {
  final DriverProfile profile;
  final Animation<double> slideAnimation;
  final VoidCallback onChangeImage;

  const DriverProfileHeader({
    super.key,
    required this.profile,
    required this.slideAnimation,
    required this.onChangeImage,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - slideAnimation.value)),
          child: Column(
            children: [
              _buildHeaderCard(context),
              const SizedBox(height: RtSpacing.xs),
              _buildStatsOverview(context),
            ],
          ),
        );
      },
    );
  }

  /// Card principal con gradiente, avatar y datos basicos
  Widget _buildHeaderCard(BuildContext context) {
    return Container(
      margin: RtSpacing.paddingBase,
      padding: const EdgeInsets.all(RtSpacing.xl),
      decoration: BoxDecoration(
        gradient: RtGradients.brand,
        borderRadius: RtRadius.borderXl,
        boxShadow: RtShadow.brand(),
      ),
      child: Column(
        children: [
          // Avatar con boton de cámara
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: profile.profileImageUrl.isEmpty
                      ? LinearGradient(
                          colors: [
                            RtColors.white.withValues(alpha: 0.3),
                            RtColors.white.withValues(alpha: 0.1),
                          ],
                        )
                      : null,
                  image: profile.profileImageUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(profile.profileImageUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                  border: Border.all(color: RtColors.white, width: 3),
                ),
                child: profile.profileImageUrl.isEmpty
                    ? const Icon(Icons.person, size: 50, color: RtColors.white)
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: onChangeImage,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: RtColors.brand, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: RtColors.brand,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: RtSpacing.base),

          // Nombre
          Text(
            profile.name,
            style: RtTypo.displaySmall.copyWith(color: RtColors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: RtSpacing.sm),

          // Rating con estrellas
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  return Icon(
                    Icons.star,
                    size: 16,
                    color: index < profile.rating.floor()
                        ? RtColors.warning
                        : RtColors.white.withValues(alpha: 0.3),
                  );
                }),
              ),
              const SizedBox(width: RtSpacing.sm),
              Flexible(
                child: Text(
                  '${profile.rating} (${profile.totalTrips} viajes)',
                  style: RtTypo.bodyMedium.copyWith(
                    color: RtColors.white.withValues(alpha: 0.7),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: RtSpacing.base),

          // Miembro desde
          Text(
            'Miembro desde ${_formatMemberSince(profile.memberSince)}',
            style: RtTypo.bodySmall.copyWith(
              color: RtColors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  /// Estadísticas: viajes, kilometros, ganancias
  Widget _buildStatsOverview(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: RtSpacing.base),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              context,
              'Viajes',
              '${profile.totalTrips}',
              Icons.directions_car,
              RtColors.info,
            ),
          ),
          const SizedBox(width: RtSpacing.md),
          Expanded(
            child: _buildStatCard(
              context,
              'Kilometros',
              '${(profile.totalDistance / 1000).toStringAsFixed(1)}K',
              Icons.straighten,
              RtColors.success,
            ),
          ),
          const SizedBox(width: RtSpacing.md),
          Expanded(
            child: _buildStatCard(
              context,
              'Ganancias',
              profile.totalEarnings.toCurrencyCompact(),
              Icons.account_balance_wallet,
              RtColors.warning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: RtSpacing.paddingBase,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: RtRadius.borderLg,
        boxShadow: RtShadow.soft(),
      ),
      child: Column(
        children: [
          Container(
            padding: RtSpacing.paddingSm,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: RtIconSize.sm),
          ),
          const SizedBox(height: RtSpacing.sm),
          Text(
            value,
            style: RtTypo.headingSmall.copyWith(color: color),
          ),
          Text(
            label,
            style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500),
          ),
        ],
      ),
    );
  }

  String _formatMemberSince(DateTime date) {
    const months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}
