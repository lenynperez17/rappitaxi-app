import 'package:flutter/material.dart';

import '../../../core/design/rt_colors.dart';
import '../../../core/design/rt_tokens.dart';
import '../../../core/design/rt_typography.dart';

/// Tipos de servicio disponibles en la app
enum ServiceType {
  standard,
  xl,
  premium,
  delivery,
  moto,
}

/// Datos de configuración para cada tipo de servicio
class _ServiceConfig {
  final String emoji;
  final String name;
  final String description;
  final double priceMultiplier;

  const _ServiceConfig({
    required this.emoji,
    required this.name,
    required this.description,
    required this.priceMultiplier,
  });
}

/// Selector horizontal de tipo de servicio.
/// Muestra cards scrollables con emoji de vehículo, nombre, descripción y precio estimado.
class PassengerServiceSelector extends StatefulWidget {
  final ServiceType selectedType;
  final ValueChanged<ServiceType> onServiceSelected;

  /// Precio base estimado para mostrar rango de precio.
  /// Si es null, se muestra el multiplicador como fallback.
  final double? basePrice;

  const PassengerServiceSelector({
    super.key,
    required this.selectedType,
    required this.onServiceSelected,
    this.basePrice,
  });

  @override
  State<PassengerServiceSelector> createState() =>
      _PassengerServiceSelectorState();
}

class _PassengerServiceSelectorState extends State<PassengerServiceSelector>
    with SingleTickerProviderStateMixin {
  /// Configuración visual de cada tipo de servicio
  static const Map<ServiceType, _ServiceConfig> _configs = {
    ServiceType.standard: _ServiceConfig(
      emoji: '\u{1F697}',
      name: 'Standard',
      description: '1-4 pasajeros',
      priceMultiplier: 1.0,
    ),
    ServiceType.xl: _ServiceConfig(
      emoji: '\u{1F690}',
      name: 'XL',
      description: '5-6 pasajeros',
      priceMultiplier: 1.5,
    ),
    ServiceType.premium: _ServiceConfig(
      emoji: '\u{1F698}',
      name: 'Premium',
      description: '1-4 pasajeros',
      priceMultiplier: 2.0,
    ),
    ServiceType.delivery: _ServiceConfig(
      emoji: '\u{1F4E6}',
      name: 'Delivery',
      description: 'Solo paquetes',
      priceMultiplier: 0.8,
    ),
    ServiceType.moto: _ServiceConfig(
      emoji: '\u{1F3CD}\u{FE0F}',
      name: 'MotoTaxi',
      description: '1 pasajero',
      priceMultiplier: 0.7,
    ),
  };

  late final AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: RtDuration.normal,
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PassengerServiceSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedType != widget.selectedType) {
      _scaleController.forward(from: 0.0);
    }
  }

  /// Texto de precio: rango si hay basePrice, o multiplicador como fallback
  String _priceText(double multiplier) {
    final base = widget.basePrice;
    if (base != null) {
      final low = (base * multiplier * 0.8).toInt();
      final high = (base * multiplier * 1.2).toInt();
      return 'S/$low - $high';
    }
    return 'x${multiplier.toStringAsFixed(1)}';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: RtSpacing.base),
        itemCount: ServiceType.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: RtSpacing.md),
        itemBuilder: (context, index) {
          final type = ServiceType.values[index];
          return _ServiceCard(
            config: _configs[type]!,
            isSelected: widget.selectedType == type,
            scaleAnimation: _scaleController,
            priceText: _priceText(_configs[type]!.priceMultiplier),
            onTap: () => widget.onServiceSelected(type),
          );
        },
      ),
    );
  }
}

/// Card individual para un tipo de servicio con animacion de escala
class _ServiceCard extends StatelessWidget {
  final _ServiceConfig config;
  final bool isSelected;
  final AnimationController scaleAnimation;
  final String priceText;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.config,
    required this.isSelected,
    required this.scaleAnimation,
    required this.priceText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Colores según estado de seleccion
    final Color bgColor = isSelected
        ? RtColors.brand.withValues(alpha: 0.08)
        : (isDark ? RtColors.neutral800 : RtColors.white);
    final Color fgColor =
        isDark ? RtColors.neutral100 : RtColors.neutral900;
    final Color descColor = RtColors.neutral500;

    final card = AnimatedContainer(
      duration: RtDuration.fast,
      width: 105,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: RtRadius.borderLg,
        border: Border.all(
          color: isSelected
              ? RtColors.brand
              : (isDark ? RtColors.neutral700 : RtColors.neutral200),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? RtShadow.brand()
            : RtShadow.soft(isDark: isDark),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: RtSpacing.xs,
        vertical: RtSpacing.sm,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Emoji del vehículo
          Text(
            config.emoji,
            style: const TextStyle(fontSize: 22),
          ),
          const SizedBox(height: 2),

          // Nombre del servicio
          Text(
            config.name,
            textAlign: TextAlign.center,
            style: RtTypo.labelMedium.copyWith(
              color: fgColor,
              fontWeight: FontWeight.bold,
            ),
          ),

          // Descripción compacta
          Text(
            config.description,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              color: descColor,
            ),
          ),

          // Precio estimado
          Text(
            priceText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: RtColors.success,
            ),
          ),
        ],
      ),
    );

    // Animacion de escala con spring solo para el seleccionado
    Widget animatedCard;
    if (isSelected) {
      animatedCard = AnimatedBuilder(
        animation: scaleAnimation,
        builder: (context, child) {
          final curveValue = RtCurve.spring.transform(
            scaleAnimation.value.clamp(0.0, 1.0),
          );
          final scale = 1.0 + (0.05 * curveValue);
          return Transform.scale(scale: scale, child: child);
        },
        child: card,
      );
    } else {
      animatedCard = card;
    }

    return GestureDetector(
      onTap: onTap,
      child: animatedCard,
    );
  }
}
