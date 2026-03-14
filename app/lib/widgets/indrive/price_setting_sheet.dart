import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import 'offer_price_screen.dart';

/// Service definition with display data and price multiplier.
class _ServiceDef {
  final String type;
  final String title;
  final String subtitle;
  final int passengers;
  final String assetPath;
  final IconData? icon;
  final double multiplier;

  const _ServiceDef({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.passengers,
    required this.assetPath,
    this.icon,
    required this.multiplier,
  });
}

const _services = [
  _ServiceDef(
    type: 'viaje',
    title: 'Viaje',
    subtitle: 'Viaja a tu precio',
    passengers: 4,
    assetPath: 'assets/images/vehicles/sedan.png',
    multiplier: 1.0,
  ),
  _ServiceDef(
    type: 'mototaxi',
    title: 'Mototaxi',
    subtitle: 'Viajes simples y justos',
    passengers: 2,
    assetPath: 'assets/images/vehicles/mototaxi.png',
    multiplier: 0.75,
  ),
  _ServiceDef(
    type: 'entregas',
    title: 'Entregas',
    subtitle: 'Envios rapidos y seguros',
    passengers: 1,
    assetPath: 'assets/images/vehicles/mototaxi.png',
    icon: Icons.inventory_2_outlined,
    multiplier: 0.85,
  ),
];

/// Bottom sheet for setting ride price -- pixel-perfect inDrive clone.
/// Layout: promo banner -> dynamic service cards with price adjuster -> toggle -> CTA.
class PriceSettingSheet extends StatefulWidget {
  final double? calculatedDistance;
  final int? estimatedTime;
  final double? suggestedPrice;
  final double offeredPrice;
  final String selectedPaymentMethod;
  final bool isSearchingDriver;
  final String selectedServiceType;
  final String pickupAddress;
  final String destinationAddress;
  final VoidCallback onBack;
  final VoidCallback onSearchDriver;
  final ValueChanged<double> onPriceChanged;
  final ValueChanged<String> onPaymentMethodChanged;
  final ValueChanged<String> onServiceTypeChanged;

  const PriceSettingSheet({
    super.key,
    this.calculatedDistance,
    this.estimatedTime,
    this.suggestedPrice,
    required this.offeredPrice,
    required this.selectedPaymentMethod,
    required this.isSearchingDriver,
    required this.selectedServiceType,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.onBack,
    required this.onSearchDriver,
    required this.onPriceChanged,
    required this.onPaymentMethodChanged,
    required this.onServiceTypeChanged,
  });

  @override
  State<PriceSettingSheet> createState() => _PriceSettingSheetState();
}

class _PriceSettingSheetState extends State<PriceSettingSheet> {
  bool _autoAccept = false;

  // Ride options state
  bool _moreThan4Passengers = false;
  bool _babySeat = false;
  bool _hasPet = false;
  String _rideComment = '';

  double _multiplierFor(String type) {
    return _services.firstWhere((s) => s.type == type).multiplier;
  }

  void _openOfferPriceScreen() {
    final suggested = widget.suggestedPrice ?? 15.0;
    final mult = _multiplierFor(widget.selectedServiceType);
    final serviceSuggested = suggested * mult;
    final minPrice = (serviceSuggested * 0.5).ceilToDouble().clamp(3.0, serviceSuggested);
    final maxPrice = (serviceSuggested * 3.0).floorToDouble();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OfferPriceScreen(
          currentPrice: widget.offeredPrice,
          suggestedPrice: serviceSuggested,
          minPrice: minPrice,
          maxPrice: maxPrice,
          paymentMethod: widget.selectedPaymentMethod,
          pickupAddress: widget.pickupAddress,
          destinationAddress: widget.destinationAddress,
          isSearchingDriver: widget.isSearchingDriver,
          onPriceChanged: widget.onPriceChanged,
          onSearchDriver: widget.onSearchDriver,
          onPaymentMethodChanged: widget.onPaymentMethodChanged,
        ),
      ),
    );
  }

  void _showPaymentMethodSheet() {
    final methods = [
      ('Efectivo', Icons.payments, const Color(0xFF8BC34A)),
      ('Yape', Icons.phone_android, const Color(0xFF6B2D8B)),
      ('Plin', Icons.phone_iphone, const Color(0xFF00BCD4)),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.getSurface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header: title + close
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Spacer(),
                      Text(
                        'Metodo de pago',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextPrimary(ctx),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.getInputFill(ctx),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close, size: 18, color: AppColors.getTextPrimary(ctx)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Payment options
                for (final (name, icon, color) in methods)
                  _PaymentMethodTile(
                    name: name,
                    icon: icon,
                    iconColor: color,
                    isSelected: widget.selectedPaymentMethod == name,
                    onTap: () {
                      widget.onPaymentMethodChanged(name);
                      Navigator.pop(ctx);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showOptionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.getSurface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Spacer(),
                        Text(
                          'Opciones',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.getTextPrimary(ctx),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.getInputFill(ctx),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close, size: 18, color: AppColors.getTextPrimary(ctx)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Toggle options
                    _OptionToggleRow(
                      label: 'Mas de 4 pasajeros',
                      value: _moreThan4Passengers,
                      onChanged: (v) {
                        setModalState(() {});
                        setState(() => _moreThan4Passengers = v);
                      },
                    ),
                    const SizedBox(height: 16),
                    _OptionToggleRow(
                      label: 'Silla de bebe',
                      value: _babySeat,
                      onChanged: (v) {
                        setModalState(() {});
                        setState(() => _babySeat = v);
                      },
                    ),
                    const SizedBox(height: 16),
                    _OptionToggleRow(
                      label: 'Llevo una mascota',
                      value: _hasPet,
                      onChanged: (v) {
                        setModalState(() {});
                        setState(() => _hasPet = v);
                      },
                    ),
                    const SizedBox(height: 20),
                    // Comments row
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _showCommentDialog();
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.getInputFill(ctx),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Text(
                              _rideComment.isEmpty ? 'Comentarios' : _rideComment,
                              style: TextStyle(
                                fontSize: 15,
                                color: _rideComment.isEmpty
                                    ? AppColors.getTextSecondary(ctx)
                                    : AppColors.getTextPrimary(ctx),
                              ),
                            ),
                            const Spacer(),
                            Icon(Icons.chevron_right, size: 20, color: AppColors.getTextSecondary(ctx)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Close button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: Material(
                        color: AppColors.rappiOrange,
                        borderRadius: BorderRadius.circular(26),
                        child: InkWell(
                          onTap: () => Navigator.pop(ctx),
                          borderRadius: BorderRadius.circular(26),
                          child: const Center(
                            child: Text(
                              'Cerrar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCommentDialog() {
    final controller = TextEditingController(text: _rideComment);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.getSurface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16, 16, 16,
            MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Spacer(),
                  Text(
                    'Comentarios',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.getTextPrimary(ctx),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.getInputFill(ctx),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close, size: 18, color: AppColors.getTextPrimary(ctx)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 3,
                maxLength: 150,
                decoration: InputDecoration(
                  hintText: 'Ej: Llevo equipaje, esperame en la puerta...',
                  hintStyle: TextStyle(color: AppColors.getTextSecondary(ctx)),
                  filled: true,
                  fillColor: AppColors.getInputFill(ctx),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: Material(
                  color: AppColors.rappiOrange,
                  borderRadius: BorderRadius.circular(26),
                  child: InkWell(
                    onTap: () {
                      setState(() => _rideComment = controller.text.trim());
                      Navigator.pop(ctx);
                    },
                    borderRadius: BorderRadius.circular(26),
                    child: const Center(
                      child: Text(
                        'Guardar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final suggested = widget.suggestedPrice ?? 15.0;
    final mult = _multiplierFor(widget.selectedServiceType);
    final serviceSuggested = suggested * mult;
    final minPrice = (serviceSuggested * 0.5).ceilToDouble().clamp(3.0, serviceSuggested);
    final maxPrice = (serviceSuggested * 3.0).floorToDouble();

    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.30,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.getSurface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: AppColors.getCardShadow(),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.getBorder(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Scrollable service list
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    children: [
                      _PromoBanner(),
                      const Divider(height: 1),
                      ..._buildServiceList(
                        suggested: suggested,
                        serviceSuggested: serviceSuggested,
                        minPrice: minPrice,
                        maxPrice: maxPrice,
                      ),
                    ],
                  ),
                ),
              ),

              // Fixed bottom: auto-accept toggle + CTA
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.send, size: 20, color: AppColors.getTextSecondary(context)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Aceptar automaticamente la oferta de ${widget.offeredPrice.toCurrency()}',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                    ),
                    Switch(
                      value: _autoAccept,
                      onChanged: (v) => setState(() => _autoAccept = v),
                      activeTrackColor: AppColors.rappiOrange,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _showPaymentMethodSheet,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.rappiOrange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.payments, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: Material(
                          color: widget.isSearchingDriver ? AppColors.grey400 : AppColors.rappiOrange,
                          borderRadius: BorderRadius.circular(26),
                          child: InkWell(
                            onTap: widget.isSearchingDriver ? null : widget.onSearchDriver,
                            borderRadius: BorderRadius.circular(26),
                            child: Center(
                              child: widget.isSearchingDriver
                                  ? const SizedBox(
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : Text(
                                      'Encontrar ofertas',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _showOptionsSheet,
                      child: Icon(Icons.tune, size: 24, color: AppColors.getTextSecondary(context)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Builds service cards dynamically. The price adjuster appears
  /// below whichever service is currently selected.
  List<Widget> _buildServiceList({
    required double suggested,
    required double serviceSuggested,
    required double minPrice,
    required double maxPrice,
  }) {
    final widgets = <Widget>[];

    for (final service in _services) {
      final isSelected = service.type == widget.selectedServiceType;

      widgets.add(
        _ServiceCard(
          title: service.title,
          subtitle: service.subtitle,
          passengers: service.passengers,
          assetPath: service.assetPath,
          icon: service.icon,
          isSelected: isSelected,
          trailingPrice: !isSelected
              ? '~${(suggested * service.multiplier).toCurrency()}'
              : null,
          onTap: () => widget.onServiceTypeChanged(service.type),
        ),
      );
      widgets.add(const Divider(height: 1));

      // Price adjuster under the selected service
      if (isSelected) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                _PriceAdjuster(
                  price: widget.offeredPrice,
                  isAtMin: widget.offeredPrice <= minPrice,
                  isAtMax: widget.offeredPrice >= maxPrice,
                  onDecrease: () {
                    if (widget.offeredPrice <= minPrice) return;
                    final newPrice = (widget.offeredPrice - 1.0).clamp(minPrice, maxPrice);
                    widget.onPriceChanged(newPrice);
                  },
                  onIncrease: () {
                    if (widget.offeredPrice >= maxPrice) return;
                    final newPrice = (widget.offeredPrice + 1.0).clamp(minPrice, maxPrice);
                    widget.onPriceChanged(newPrice);
                  },
                  onPriceTap: _openOfferPriceScreen,
                ),
                const SizedBox(height: 4),
                Text(
                  'Tarifa recomendada: ${serviceSuggested.toCurrency()}',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Min: ${minPrice.toCurrency()} -- Max: ${maxPrice.toCurrency()}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.getTextSecondary(context).withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        );
        widgets.add(const Divider(height: 1));
      }
    }

    return widgets;
  }
}

/// Promo code banner at top of sheet
class _PromoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.sell_outlined, size: 22, color: AppColors.getTextSecondary(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '¿Tienes un codigo promocional? Usalo aqui',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.getTextPrimary(context),
              ),
            ),
          ),
          Icon(Icons.chevron_right, size: 22, color: AppColors.getTextSecondary(context)),
        ],
      ),
    );
  }
}

/// Service type card (selected or alternative) matching inDrive layout
class _ServiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int passengers;
  final String assetPath;
  final bool isSelected;
  final String? trailingPrice;
  final VoidCallback? onTap;
  final IconData? icon;

  const _ServiceCard({
    required this.title,
    required this.subtitle,
    required this.passengers,
    required this.assetPath,
    required this.isSelected,
    this.trailingPrice,
    this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isSelected ? AppColors.getInputFill(context) : null,
        child: Row(
          children: [
            // Vehicle image or icon
            SizedBox(
              width: 56,
              height: 40,
              child: icon != null
                  ? Icon(icon, size: 32, color: AppColors.getTextSecondary(context))
                  : Image.asset(
                      assetPath,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.local_taxi,
                        size: 32,
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.info_outline, size: 16, color: AppColors.getTextSecondary(context)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.person, size: 14, color: AppColors.getTextSecondary(context)),
                      Text(
                        '$passengers',
                        style: TextStyle(fontSize: 13, color: AppColors.getTextSecondary(context)),
                      ),
                    ],
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: AppColors.getTextSecondary(context)),
                  ),
                ],
              ),
            ),
            // Trailing: edit icon (selected) or price (not selected)
            if (isSelected)
              Icon(Icons.edit, size: 20, color: AppColors.getTextSecondary(context))
            else if (trailingPrice != null)
              Text(
                trailingPrice!,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Price +/- adjuster widget (inDrive style: big price in center).
/// Tapping the price opens the fullscreen offer price screen.
class _PriceAdjuster extends StatelessWidget {
  final double price;
  final bool isAtMin;
  final bool isAtMax;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback? onPriceTap;

  const _PriceAdjuster({
    required this.price,
    this.isAtMin = false,
    this.isAtMax = false,
    required this.onDecrease,
    required this.onIncrease,
    this.onPriceTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RoundButton(icon: Icons.remove, onTap: onDecrease, disabled: isAtMin),
        const SizedBox(width: 24),
        GestureDetector(
          onTap: onPriceTap,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Text(
              price.toCurrency(),
              key: ValueKey(price.toStringAsFixed(2)),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: AppColors.priceBlack,
                letterSpacing: -1,
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        _RoundButton(icon: Icons.add, onTap: onIncrease, disabled: isAtMax),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool disabled;

  const _RoundButton({required this.icon, required this.onTap, this.disabled = false});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.3 : 1.0,
      child: Material(
        color: AppColors.getInputFill(context),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: disabled ? null : onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon, size: 24, color: AppColors.getTextPrimary(context)),
          ),
        ),
      ),
    );
  }
}

/// Row tile for payment method selection in the modal sheet.
class _PaymentMethodTile extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color iconColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentMethodTile({
    required this.name,
    required this.icon,
    required this.iconColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFF4285F4), size: 22),
          ],
        ),
      ),
    );
  }
}

/// Toggle row for ride options in the modal sheet.
class _OptionToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _OptionToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.getTextPrimary(context),
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: AppColors.rappiOrange,
        ),
      ],
    );
  }
}
