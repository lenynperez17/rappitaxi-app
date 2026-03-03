import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/design/rt_colors.dart';
import '../../../core/design/rt_tokens.dart';
import '../../../core/design/rt_typography.dart';
import '../../../core/widgets/custom_place_text_field.dart';
import '../../../generated/l10n/app_localizations.dart';

/// Barra de busqueda con patron "Single Input" que se expande.
/// Estado colapsado: campo único "A donde vas?" con icono de busqueda rojo.
/// Estado expandido: 2 campos conectados con timeline vertical y boton swap.
class PassengerSearchBar extends StatefulWidget {
  final TextEditingController pickupController;
  final TextEditingController destinationController;
  final LatLng? pickupCoordinates;
  final LatLng? destinationCoordinates;

  /// Callback cuando se selecciona un lugar (isPickup, coords)
  final void Function(bool isPickup, LatLng coords) onPlaceSelected;

  /// Callback cuando el usuario toca un campo de texto
  final void Function(bool isPickup) onFieldTapped;

  /// Callback para usar ubicación GPS actual
  final VoidCallback onUseCurrentLocation;

  /// Callback para abrir el mapa tipo Uber/InDrive
  final void Function(bool isOrigin) onOpenMapPicker;

  /// Callback para limpiar todos los campos
  final VoidCallback onClearAll;

  /// Indica si se activo el modo de selección de ubicación
  final void Function(bool isSearching) onSearchingChanged;

  /// Controla externamente si la barra esta expandida
  final bool isExpanded;

  /// Callback cuando se toca el campo colapsado
  final VoidCallback? onTap;

  const PassengerSearchBar({
    super.key,
    required this.pickupController,
    required this.destinationController,
    required this.pickupCoordinates,
    required this.destinationCoordinates,
    required this.onPlaceSelected,
    required this.onFieldTapped,
    required this.onUseCurrentLocation,
    required this.onOpenMapPicker,
    required this.onClearAll,
    required this.onSearchingChanged,
    this.isExpanded = false,
    this.onTap,
  });

  @override
  State<PassengerSearchBar> createState() => _PassengerSearchBarState();
}

class _PassengerSearchBarState extends State<PassengerSearchBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;
  bool _internalExpanded = false;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: RtDuration.normal,
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: RtCurve.enter,
      reverseCurve: RtCurve.exit,
    );
    _internalExpanded = widget.isExpanded;
    if (_internalExpanded) {
      _expandController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(PassengerSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      _internalExpanded = widget.isExpanded;
      if (_internalExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  /// Expande la barra de busqueda
  void _expand() {
    setState(() => _internalExpanded = true);
    _expandController.forward();
    widget.onTap?.call();
  }

  /// Colapsa la barra de busqueda
  void _collapse() {
    setState(() => _internalExpanded = false);
    _expandController.reverse();
  }

  /// Intercambia origen y destino
  void _swapFields() {
    final tmpText = widget.pickupController.text;
    widget.pickupController.text = widget.destinationController.text;
    widget.destinationController.text = tmpText;

    // Si hay coordenadas, notificar el intercambio
    if (widget.pickupCoordinates != null && widget.destinationCoordinates != null) {
      final tmpCoords = widget.pickupCoordinates!;
      widget.onPlaceSelected(true, widget.destinationCoordinates!);
      widget.onPlaceSelected(false, tmpCoords);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, _) {
        // Transicion suave entre colapsado y expandido
        if (_expandAnimation.value < 0.01) {
          return _buildCollapsed(isDark);
        }
        if (_expandAnimation.value > 0.99) {
          return _buildExpanded(isDark);
        }
        // Durante la animacion, mezclar opacidad
        return Stack(
          children: [
            Opacity(
              opacity: (1.0 - _expandAnimation.value).clamp(0.0, 1.0),
              child: _buildCollapsed(isDark),
            ),
            Opacity(
              opacity: _expandAnimation.value.clamp(0.0, 1.0),
              child: _buildExpanded(isDark),
            ),
          ],
        );
      },
    );
  }

  // ════════════════════════════════════════════
  // ESTADO COLAPSADO - Campo único "A donde vas?"
  // ════════════════════════════════════════════

  Widget _buildCollapsed(bool isDark) {
    return GestureDetector(
      onTap: _expand,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: RtSpacing.base,
          vertical: RtSpacing.sm,
        ),
        height: 56,
        decoration: BoxDecoration(
          color: isDark ? RtColors.neutral900 : RtColors.white,
          borderRadius: RtRadius.borderLg,
          boxShadow: RtShadow.medium(isDark: isDark),
        ),
        child: Row(
          children: [
            const SizedBox(width: RtSpacing.base),
            // Icono de busqueda rojo (brand)
            Icon(
              Icons.search_rounded,
              color: RtColors.brand,
              size: RtIconSize.md,
            ),
            const SizedBox(width: RtSpacing.md),
            // Texto placeholder
            Expanded(
              child: Text(
                AppLocalizations.of(context)?.whereAreYouGoing ?? 'A donde vas?',
                style: RtTypo.bodyLarge.copyWith(
                  color: isDark ? RtColors.neutral400 : RtColors.neutral500,
                ),
              ),
            ),
            const SizedBox(width: RtSpacing.base),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════
  // ESTADO EXPANDIDO - 2 campos con timeline vertical
  // ════════════════════════════════════════════

  Widget _buildExpanded(bool isDark) {
    final bool hasContent = widget.pickupController.text.isNotEmpty ||
        widget.destinationController.text.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: RtSpacing.base,
        vertical: RtSpacing.sm,
      ),
      padding: const EdgeInsets.all(RtSpacing.base),
      decoration: BoxDecoration(
        color: isDark ? RtColors.neutral900 : RtColors.white,
        borderRadius: BorderRadius.circular(RtRadius.lg + 4),
        boxShadow: RtShadow.strong(isDark: isDark),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline vertical: punto verde -> linea punteada -> punto rojo
          _buildTimeline(isDark),
          const SizedBox(width: RtSpacing.md),
          // Campos de texto
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Campo origen
                _buildOriginField(isDark),
                // Separador con boton swap
                _buildSwapDivider(isDark),
                // Campo destino
                _buildDestinationField(isDark, hasContent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Timeline vertical con puntos de color y linea punteada
  Widget _buildTimeline(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: RtSpacing.base),
      child: SizedBox(
        width: 12,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Punto verde (origen)
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: RtColors.success,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: RtColors.success.withValues(alpha: 0.3),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            // Linea punteada vertical
            _buildDottedLine(isDark, height: 40),
            // Punto rojo (destino)
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: RtColors.brand,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: RtColors.brand.withValues(alpha: 0.3),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Linea punteada vertical gris
  Widget _buildDottedLine(bool isDark, {required double height}) {
    final Color lineColor = isDark ? RtColors.neutral600 : RtColors.neutral300;
    const int dotCount = 5;
    final double dotHeight = height / (dotCount * 2 - 1);

    return SizedBox(
      height: height,
      width: 2,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(dotCount, (index) {
          return Container(
            width: 2,
            height: dotHeight,
            decoration: BoxDecoration(
              color: lineColor,
              borderRadius: RtRadius.borderFull,
            ),
          );
        }),
      ),
    );
  }

  /// Campo de origen con botones GPS y mapa
  Widget _buildOriginField(bool isDark) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        Expanded(
          child: _buildAddressField(
            controller: widget.pickupController,
            hintText: l10n.whereAreYou,
            isPickup: true,
          ),
        ),
        // Boton GPS
        _buildIconAction(
          icon: Icons.my_location,
          color: RtColors.brand,
          tooltip: 'Usar mi ubicación actual',
          onPressed: widget.onUseCurrentLocation,
        ),
        // Boton seleccionar en mapa
        _buildIconAction(
          icon: Icons.map_outlined,
          color: RtColors.success,
          tooltip: 'Seleccionar en el mapa',
          onPressed: () => widget.onOpenMapPicker(true),
        ),
      ],
    );
  }

  /// Separador horizontal con boton swap circular
  Widget _buildSwapDivider(bool isDark) {
    return SizedBox(
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Linea divisora
          Divider(
            height: 1,
            color: isDark ? RtColors.neutral700 : RtColors.neutral200,
          ),
          // Boton swap
          Positioned(
            right: 0,
            child: GestureDetector(
              onTap: _swapFields,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDark ? RtColors.neutral800 : RtColors.neutral100,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? RtColors.neutral700 : RtColors.neutral200,
                  ),
                ),
                child: Icon(
                  Icons.swap_vert_rounded,
                  size: RtIconSize.sm,
                  color: isDark ? RtColors.neutral300 : RtColors.neutral600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Campo de destino con boton limpiar
  Widget _buildDestinationField(bool isDark, bool hasContent) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        Expanded(
          child: _buildAddressField(
            controller: widget.destinationController,
            hintText: l10n.whereAreYouGoing,
            isPickup: false,
          ),
        ),
        // Boton seleccionar en mapa
        _buildIconAction(
          icon: Icons.map_outlined,
          color: RtColors.brand,
          tooltip: 'Seleccionar en el mapa',
          onPressed: () => widget.onOpenMapPicker(false),
        ),
        // Boton limpiar (solo visible si hay contenido)
        if (hasContent)
          _buildIconAction(
            icon: Icons.close_rounded,
            color: RtColors.neutral400,
            tooltip: 'Limpiar todo',
            onPressed: () {
              widget.onClearAll();
              _collapse();
            },
          ),
      ],
    );
  }

  /// Campo de dirección con autocompletado de Google Places
  Widget _buildAddressField({
    required TextEditingController controller,
    required String hintText,
    required bool isPickup,
  }) {
    return CustomPlaceTextField(
      controller: controller,
      hintText: hintText,
      googleApiKey: AppConfig.googleMapsApiKey,
      onTap: () => widget.onFieldTapped(isPickup),
      onPlaceSelected: (PlacePrediction prediction) {
        if (prediction.lat != null && prediction.lng != null) {
          final coords = LatLng(prediction.lat!, prediction.lng!);
          widget.onPlaceSelected(isPickup, coords);
        }
      },
    );
  }

  /// Boton circular de accion compacto
  Widget _buildIconAction({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        icon: Icon(icon, size: RtIconSize.sm, color: color),
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );
  }
}
