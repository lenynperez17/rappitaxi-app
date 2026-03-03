import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/design/rt_colors.dart';
import '../../../core/design/rt_tokens.dart';
import '../../../core/design/rt_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../generated/l10n/app_localizations.dart';

/// Bottom sheet principal que maneja dos estados:
/// 1. Seleccion de destino (favoritos + recientes + boton continuar)
/// 2. Negociación de precio (info ruta + precios sugeridos + método de pago)
class PassengerTripSheet extends StatelessWidget {
  // Estado: destino
  final bool isSelectingLocation;
  final bool showContinueButton;
  final VoidCallback onContinue;

  // Estado: negociación de precio
  final bool showPriceNegotiation;
  final double? calculatedDistance;
  final int? estimatedTime;
  final double? suggestedPrice;
  final double offeredPrice;
  final String selectedPaymentMethod;
  final bool isManualPriceEntry;
  final bool isCreatingNegotiation;
  final TextEditingController priceController;
  final FocusNode priceFocusNode;

  // Callbacks de precio
  final ValueChanged<double> onPriceSelected;
  final ValueChanged<String> onPaymentMethodChanged;
  final ValueChanged<bool> onManualPriceEntryChanged;
  final VoidCallback onStartNegotiation;
  final VoidCallback onCancelNegotiation;
  final VoidCallback onHideKeyboard;

  // Callbacks de favoritos/recientes
  final ValueChanged<String> onFavoriteTapped;
  final ValueChanged<String> onRecentTapped;

  // Widget del selector de servicios (inyectado desde el padre)
  final Widget? serviceSelector;

  const PassengerTripSheet({
    super.key,
    this.serviceSelector,
    required this.isSelectingLocation,
    required this.showContinueButton,
    required this.onContinue,
    required this.showPriceNegotiation,
    this.calculatedDistance,
    this.estimatedTime,
    this.suggestedPrice,
    required this.offeredPrice,
    required this.selectedPaymentMethod,
    required this.isManualPriceEntry,
    required this.isCreatingNegotiation,
    required this.priceController,
    required this.priceFocusNode,
    required this.onPriceSelected,
    required this.onPaymentMethodChanged,
    required this.onManualPriceEntryChanged,
    required this.onStartNegotiation,
    required this.onCancelNegotiation,
    required this.onHideKeyboard,
    required this.onFavoriteTapped,
    required this.onRecentTapped,
  });

  @override
  Widget build(BuildContext context) {
    if (showPriceNegotiation) {
      return _buildPriceNegotiationSheet(context);
    }
    return _buildDestinationSheet(context);
  }

  // ================================================================
  // SHEET DE DESTINO (favoritos + recientes)
  // ================================================================

  Widget _buildDestinationSheet(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: isSelectingLocation
          ? 0.08
          : (showContinueButton ? 0.50 : 0.35),
      minChildSize: isSelectingLocation ? 0.08 : 0.2,
      maxChildSize: 0.65,
      builder: (BuildContext context, ScrollController scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? RtColors.neutral900.withValues(alpha: 0.95)
                    : RtColors.white.withValues(alpha: 0.92),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDragHandle(isDark),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isSelectingLocation) ...[
                            // Selector de servicios dentro del sheet
                            if (serviceSelector != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: RtSpacing.sm,
                                  bottom: RtSpacing.sm,
                                ),
                                child: serviceSelector!,
                              ),
                            _DestinationFavorites(
                              isDark: isDark,
                              onFavoriteTapped: onFavoriteTapped,
                            ),
                            Divider(
                              height: 1,
                              color: isDark
                                  ? RtColors.neutral700
                                  : RtColors.neutral200,
                            ),
                            _DestinationRecents(
                              isDark: isDark,
                              onRecentTapped: onRecentTapped,
                            ),
                          ],
                          if (showContinueButton)
                            _buildContinueButton(context),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ================================================================
  // SHEET DE NEGOCIACION DE PRECIO
  // ================================================================

  Widget _buildPriceNegotiationSheet(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final String distanceTimeText = _getDistanceTimeText();
    final String suggestedPriceText = _getSuggestedPriceText();

    return NotificationListener<ScrollStartNotification>(
      onNotification: (notification) {
        onHideKeyboard();
        onManualPriceEntryChanged(false);
        return false;
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (BuildContext context, ScrollController scrollController) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? RtColors.neutral900.withValues(alpha: 0.95)
                      : RtColors.white.withValues(alpha: 0.92),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDragHandle(isDark),
                    _buildNegotiationHeader(context, isDark),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          onHideKeyboard();
                          onManualPriceEntryChanged(false);
                        },
                        child: SingleChildScrollView(
                          controller: scrollController,
                          child: Padding(
                            padding: const EdgeInsets.all(RtSpacing.sm),
                            child: Column(
                              children: [
                                // Subtitulo
                                Text(
                                  'Los conductores cercanos veran tu oferta',
                                  style: RtTypo.bodySmall.copyWith(
                                    color: RtColors.neutral500,
                                  ),
                                ),
                                const SizedBox(height: RtSpacing.md),

                                // Info de ruta con accent line verde
                                _buildRouteInfo(
                                  context,
                                  isDark,
                                  distanceTimeText,
                                  suggestedPriceText,
                                ),
                                const SizedBox(height: RtSpacing.md),

                                // Titulo de precios
                                Text(
                                  'Selecciona tu precio:',
                                  style: RtTypo.titleLarge.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? RtColors.white
                                        : RtColors.neutral900,
                                  ),
                                ),
                                const SizedBox(height: RtSpacing.sm),

                                // Chips de precio sugerido
                                _buildPriceSuggestions(context, isDark),
                                const SizedBox(height: RtSpacing.sm),

                                // Campo de precio manual
                                _buildManualPriceField(context, isDark),
                                const SizedBox(height: RtSpacing.md),

                                // Métodos de pago
                                _buildPaymentMethods(context, isDark),
                                const SizedBox(height: RtSpacing.md),

                                // Boton buscar conductor con gradiente
                                _buildGradientButton(
                                  label: 'Buscar conductor',
                                  icon: Icons.search_rounded,
                                  isLoading: isCreatingNegotiation,
                                  onPressed: isCreatingNegotiation
                                      ? null
                                      : onStartNegotiation,
                                ),

                                const SizedBox(height: RtSpacing.base),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ================================================================
  // COMPONENTES COMPARTIDOS
  // ================================================================

  /// Handle visual para arrastrar el sheet (pill 40x5, más redondeado)
  Widget _buildDragHandle(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      width: 40,
      height: 5,
      decoration: BoxDecoration(
        color: RtColors.neutral300,
        borderRadius: RtRadius.borderFull,
      ),
    );
  }

  /// Header con boton cancelar y titulo
  Widget _buildNegotiationHeader(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: RtSpacing.base,
        vertical: RtSpacing.sm,
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: isDark ? RtColors.white : RtColors.neutral900,
            ),
            onPressed: onCancelNegotiation,
            tooltip: 'Volver',
          ),
          Expanded(
            child: Center(
              child: Text(
                'Ofrece tu precio',
                style: RtTypo.headingMedium.copyWith(
                  color: isDark ? RtColors.white : RtColors.neutral900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  /// Info de ruta con accent line verde a la izquierda
  Widget _buildRouteInfo(
    BuildContext context,
    bool isDark,
    String distanceTimeText,
    String suggestedPriceText,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? RtColors.neutral800 : RtColors.neutral50,
        borderRadius: RtRadius.borderMd,
        border: Border(
          left: BorderSide(
            color: RtColors.success,
            width: 3,
          ),
        ),
      ),
      padding: const EdgeInsets.all(RtSpacing.md),
      child: Row(
        children: [
          Icon(Icons.route, color: RtColors.info, size: RtIconSize.md),
          const SizedBox(width: RtSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  distanceTimeText,
                  style: RtTypo.headingSmall.copyWith(
                    color: isDark ? RtColors.white : RtColors.neutral900,
                  ),
                ),
                const SizedBox(height: RtSpacing.xs),
                Text(
                  suggestedPriceText,
                  style: RtTypo.bodySmall.copyWith(color: RtColors.success),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Chips de precio sugerido mejorados con más padding y escala bounce
  Widget _buildPriceSuggestions(BuildContext context, bool isDark) {
    final double basePrice = suggestedPrice ?? 15.0;
    final List<double> prices = [
      basePrice * 0.9,
      basePrice,
      basePrice * 1.1,
      basePrice * 1.2,
    ];

    return Wrap(
      spacing: RtSpacing.sm,
      runSpacing: RtSpacing.sm,
      alignment: WrapAlignment.center,
      children: prices
          .map((price) => _buildPriceChip(context, isDark, price))
          .toList(),
    );
  }

  /// Chip individual de precio con escala 1.05 al seleccionar
  Widget _buildPriceChip(BuildContext context, bool isDark, double price) {
    final bool isSelected = (offeredPrice - price).abs() < 0.01;

    return GestureDetector(
      onTap: () => onPriceSelected(price),
      child: AnimatedScale(
        scale: isSelected ? 1.05 : 1.0,
        duration: RtDuration.fast,
        curve: RtCurve.bounce,
        child: AnimatedContainer(
          duration: RtDuration.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: RtSpacing.xl,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? RtColors.brand
                : (isDark ? RtColors.neutral800 : RtColors.white),
            borderRadius: RtRadius.borderMd,
            border: Border.all(
              color: isSelected
                  ? RtColors.brand
                  : (isDark ? RtColors.neutral600 : RtColors.neutral300),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected ? RtShadow.brand() : null,
          ),
          child: Text(
            price.toCurrency(),
            style: RtTypo.titleLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? RtColors.white
                  : (isDark ? RtColors.neutral100 : RtColors.neutral900),
            ),
          ),
        ),
      ),
    );
  }

  /// Campo de precio manual con estilo underline (borde inferior)
  Widget _buildManualPriceField(BuildContext context, bool isDark) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: RtSpacing.base),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Prefijo S/ grande
          Text(
            'S/',
            style: RtTypo.headingMedium.copyWith(
              color: isDark ? RtColors.white : RtColors.neutral900,
            ),
          ),
          const SizedBox(width: RtSpacing.sm),
          Expanded(
            child: TextField(
              controller: priceController,
              focusNode: priceFocusNode,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: RtTypo.headingMedium.copyWith(color: RtColors.brand),
              decoration: InputDecoration(
                hintText: l10n.enterPrice,
                hintStyle:
                    RtTypo.bodyMedium.copyWith(color: RtColors.neutral400),
                border: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color:
                        isDark ? RtColors.neutral600 : RtColors.neutral300,
                  ),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color:
                        isDark ? RtColors.neutral600 : RtColors.neutral300,
                  ),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: RtColors.brand,
                    width: 2,
                  ),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.only(bottom: RtSpacing.xs),
              ),
              onTap: () => onManualPriceEntryChanged(true),
              onChanged: (value) {
                final price = double.tryParse(value);
                if (price != null) {
                  onPriceSelected(price);
                }
              },
              onSubmitted: (_) {
                onHideKeyboard();
                onManualPriceEntryChanged(false);
              },
            ),
          ),
          if (priceController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, size: RtIconSize.sm),
              onPressed: () {
                priceController.clear();
                onHideKeyboard();
                onManualPriceEntryChanged(false);
                onPriceSelected(suggestedPrice ?? 15.0);
              },
            ),
        ],
      ),
    );
  }

  /// Métodos de pago con iconos más grandes y check en el seleccionado
  Widget _buildPaymentMethods(BuildContext context, bool isDark) {
    return Wrap(
      spacing: RtSpacing.md,
      runSpacing: RtSpacing.md,
      alignment: WrapAlignment.center,
      children: [
        _buildPaymentChip(context, isDark, Icons.money, 'Efectivo'),
        _buildPaymentChip(context, isDark, Icons.credit_card, 'Tarjeta'),
        _buildPaymentChip(
            context, isDark, Icons.account_balance_wallet, 'Billetera'),
      ],
    );
  }

  /// Chip de método de pago con check si esta seleccionado
  Widget _buildPaymentChip(
    BuildContext context,
    bool isDark,
    IconData icon,
    String label,
  ) {
    final bool selected = selectedPaymentMethod == label;

    return GestureDetector(
      onTap: () => onPaymentMethodChanged(label),
      child: AnimatedContainer(
        duration: RtDuration.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: RtSpacing.base,
          vertical: RtSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected
              ? RtColors.brand.withValues(alpha: 0.1)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? RtColors.brand
                : (isDark ? RtColors.neutral600 : RtColors.neutral300),
            width: selected ? 2 : 1,
          ),
          borderRadius: RtRadius.borderMd,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: RtIconSize.md,
              color: selected ? RtColors.brand : RtColors.neutral500,
            ),
            const SizedBox(width: RtSpacing.sm),
            Text(
              label,
              style: RtTypo.labelLarge.copyWith(
                color: selected ? RtColors.brand : RtColors.neutral500,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            // Check al lado del icono si esta seleccionado
            if (selected) ...[
              const SizedBox(width: RtSpacing.xs),
              Icon(
                Icons.check_circle_rounded,
                size: RtIconSize.xs,
                color: RtColors.brand,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Boton "Continuar" con gradiente y flecha animada
  Widget _buildContinueButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        RtSpacing.lg,
        RtSpacing.base,
        RtSpacing.lg,
        RtSpacing.lg,
      ),
      child: _buildGradientButton(
        label: 'Continuar',
        icon: Icons.arrow_forward_rounded,
        onPressed: onContinue,
      ),
    );
  }

  /// Boton con gradiente reutilizable (56px de alto, borderRadius 16)
  Widget _buildGradientButton({
    required String label,
    required IconData icon,
    VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    final bool isDisabled = onPressed == null;

    return AnimatedOpacity(
      opacity: isDisabled ? 0.5 : 1.0,
      duration: RtDuration.fast,
      child: GestureDetector(
        onTap: isLoading ? null : onPressed,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [RtColors.brand, Color(0xFFB91C1C)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: RtRadius.borderLg,
            boxShadow: RtShadow.brand(),
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(RtColors.white),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: RtColors.white, size: RtIconSize.md),
                      const SizedBox(width: RtSpacing.sm),
                      Text(
                        label,
                        style: RtTypo.titleLarge.copyWith(
                          fontWeight: FontWeight.w600,
                          color: RtColors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ================================================================
  // HELPERS
  // ================================================================

  String _getDistanceTimeText() {
    if (calculatedDistance != null && estimatedTime != null) {
      return '${calculatedDistance!.toStringAsFixed(1)} km  \u2022  $estimatedTime min';
    }
    return 'Calculando ruta...';
  }

  String _getSuggestedPriceText() {
    if (suggestedPrice != null) {
      return 'Precio sugerido: ${suggestedPrice!.toCurrency()}';
    }
    return 'Calculando precio...';
  }
}

// ================================================================
// WIDGETS INTERNOS CON ANIMACIONES STAGGERED
// ================================================================

/// Lugares favoritos con animacion staggered (fade + slide up, delay 50ms)
class _DestinationFavorites extends StatefulWidget {
  final bool isDark;
  final ValueChanged<String> onFavoriteTapped;

  const _DestinationFavorites({
    required this.isDark,
    required this.onFavoriteTapped,
  });

  @override
  State<_DestinationFavorites> createState() => _DestinationFavoritesState();
}

class _DestinationFavoritesState extends State<_DestinationFavorites>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<Animation<double>> _fadeAnimations;
  late final List<Animation<Offset>> _slideAnimations;

  static const _items = [
    (Icons.home_rounded, 'Casa'),
    (Icons.work_rounded, 'Trabajo'),
    (Icons.school_rounded, 'Universidad'),
    (Icons.add_rounded, 'Agregar'),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Crear animaciones staggered con delay de 50ms por item
    _fadeAnimations = List.generate(_items.length, (i) {
      final start = (i * 0.125).clamp(0.0, 1.0);
      final end = (start + 0.5).clamp(0.0, 1.0);
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start, end, curve: RtCurve.enter),
        ),
      );
    });

    _slideAnimations = List.generate(_items.length, (i) {
      final start = (i * 0.125).clamp(0.0, 1.0);
      final end = (start + 0.5).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start, end, curve: RtCurve.enter),
        ),
      );
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        RtSpacing.lg,
        RtSpacing.md,
        RtSpacing.lg,
        RtSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lugares favoritos',
            style: RtTypo.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: widget.isDark ? RtColors.white : RtColors.neutral900,
            ),
          ),
          const SizedBox(height: RtSpacing.base),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (i) {
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimations[i],
                    child: SlideTransition(
                      position: _slideAnimations[i],
                      child: child,
                    ),
                  );
                },
                child: _buildFavoriteItem(
                  widget.isDark,
                  _items[i].$1,
                  _items[i].$2,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  /// Item de lugar favorito con fondo brand sutil e icono brand
  Widget _buildFavoriteItem(bool isDark, IconData icon, String label) {
    return GestureDetector(
      onTap: () {
        if (label != 'Agregar') {
          widget.onFavoriteTapped(label);
        }
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(RtSpacing.md),
            decoration: BoxDecoration(
              color: RtColors.brand.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: RtColors.brand, size: RtIconSize.md),
          ),
          const SizedBox(height: RtSpacing.sm),
          Text(
            label,
            style: RtTypo.labelSmall.copyWith(
              color: isDark ? RtColors.neutral300 : RtColors.neutral600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Destinos recientes con animacion staggered
class _DestinationRecents extends StatefulWidget {
  final bool isDark;
  final ValueChanged<String> onRecentTapped;

  const _DestinationRecents({
    required this.isDark,
    required this.onRecentTapped,
  });

  @override
  State<_DestinationRecents> createState() => _DestinationRecentsState();
}

class _DestinationRecentsState extends State<_DestinationRecents>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<Animation<double>> _fadeAnimations;
  late final List<Animation<Offset>> _slideAnimations;

  static const _recents = [
    ('Centro Comercial Plaza', 'Av. Principal 123'),
    ('Aeropuerto Internacional', 'Terminal 1'),
    ('Parque Central', 'Calle Principal s/n'),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _fadeAnimations = List.generate(_recents.length, (i) {
      final start = (i * 0.15).clamp(0.0, 1.0);
      final end = (start + 0.5).clamp(0.0, 1.0);
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start, end, curve: RtCurve.enter),
        ),
      );
    });

    _slideAnimations = List.generate(_recents.length, (i) {
      final start = (i * 0.15).clamp(0.0, 1.0);
      final end = (start + 0.5).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start, end, curve: RtCurve.enter),
        ),
      );
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        RtSpacing.lg,
        RtSpacing.md,
        RtSpacing.lg,
        RtSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recientes',
            style: RtTypo.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: widget.isDark ? RtColors.white : RtColors.neutral900,
            ),
          ),
          const SizedBox(height: RtSpacing.md),
          ...List.generate(_recents.length, (i) {
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimations[i],
                  child: SlideTransition(
                    position: _slideAnimations[i],
                    child: child,
                  ),
                );
              },
              child: _buildRecentItem(
                widget.isDark,
                _recents[i].$1,
                _recents[i].$2,
              ),
            );
          }),
          // Boton "Ver todos" si hay más de 3
          if (_recents.length >= 3)
            Padding(
              padding: const EdgeInsets.only(top: RtSpacing.sm),
              child: Center(
                child: TextButton(
                  onPressed: () {
                    // Futura navegación a lista completa
                  },
                  child: Text(
                    'Ver todos',
                    style: RtTypo.labelLarge.copyWith(
                      color: RtColors.brand,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Item de destino reciente con icono circular
  Widget _buildRecentItem(bool isDark, String title, String subtitle) {
    return GestureDetector(
      onTap: () => widget.onRecentTapped(title),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: RtSpacing.md),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(RtSpacing.sm),
              decoration: BoxDecoration(
                color: isDark
                    ? RtColors.neutral800
                    : RtColors.neutral100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history,
                color: RtColors.neutral500,
                size: RtIconSize.sm,
              ),
            ),
            const SizedBox(width: RtSpacing.base),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: RtTypo.titleLarge.copyWith(
                      color: isDark
                          ? RtColors.white
                          : RtColors.neutral900,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: RtTypo.bodySmall.copyWith(
                      color: RtColors.neutral500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: RtIconSize.xs,
              color: RtColors.neutral400,
            ),
          ],
        ),
      ),
    );
  }
}
