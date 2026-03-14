import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';

/// Fullscreen "Ofrece tu tarifa" screen -- inDrive style.
///
/// Opened when user taps the big price in PriceSettingSheet.
/// Allows editing price via text field, shows payment method,
/// auto-accept toggle, route summary, and "Buscar conductor" CTA.
class OfferPriceScreen extends StatefulWidget {
  final double currentPrice;
  final double suggestedPrice;
  final double minPrice;
  final double maxPrice;
  final String paymentMethod;
  final String pickupAddress;
  final String destinationAddress;
  final bool isSearchingDriver;
  final ValueChanged<double> onPriceChanged;
  final VoidCallback onSearchDriver;
  final ValueChanged<String> onPaymentMethodChanged;

  const OfferPriceScreen({
    super.key,
    required this.currentPrice,
    required this.suggestedPrice,
    required this.minPrice,
    required this.maxPrice,
    required this.paymentMethod,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.isSearchingDriver,
    required this.onPriceChanged,
    required this.onSearchDriver,
    required this.onPaymentMethodChanged,
  });

  @override
  State<OfferPriceScreen> createState() => _OfferPriceScreenState();
}

class _OfferPriceScreenState extends State<OfferPriceScreen> {
  late TextEditingController _priceController;
  late FocusNode _priceFocusNode;
  bool _autoAccept = false;
  late double _editedPrice;

  @override
  void initState() {
    super.initState();
    _editedPrice = widget.currentPrice;
    _priceController = TextEditingController(
      text: widget.currentPrice.toStringAsFixed(2),
    );
    _priceFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _priceController.dispose();
    _priceFocusNode.dispose();
    super.dispose();
  }

  void _onPriceSubmitted(String value) {
    final parsed = double.tryParse(value);
    if (parsed == null) {
      // Reset to current price if invalid
      _priceController.text = _editedPrice.toStringAsFixed(2);
      return;
    }
    final clamped = parsed.clamp(widget.minPrice, widget.maxPrice);
    setState(() => _editedPrice = clamped);
    _priceController.text = clamped.toStringAsFixed(2);
    widget.onPriceChanged(clamped);
  }

  IconData _paymentIcon(String method) {
    switch (method.toLowerCase()) {
      case 'yape':
        return Icons.phone_android;
      case 'plin':
        return Icons.phone_iphone;
      case 'tarjeta':
        return Icons.credit_card;
      default:
        return Icons.payments;
    }
  }

  String _paymentLabel(String method) {
    switch (method.toLowerCase()) {
      case 'yape':
        return 'Yape';
      case 'plin':
        return 'Plin';
      case 'tarjeta':
        return 'Tarjeta';
      default:
        return 'Efectivo';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: AppColors.getSurface(context),
      appBar: AppBar(
        backgroundColor: AppColors.getSurface(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.getTextPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Ofrece tu tarifa',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.getTextPrimary(context),
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: bottomInset > 0 ? 16 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Subtitle
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Text(
                      'Puedes modificar la tarifa recomendada',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ),

                  // Large editable price
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: IntrinsicWidth(
                        child: TextField(
                          controller: _priceController,
                          focusNode: _priceFocusNode,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                          ],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: AppColors.priceBlack,
                            letterSpacing: -1,
                          ),
                          decoration: InputDecoration(
                            prefixText: 'S/ ',
                            prefixStyle: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              color: AppColors.priceBlack,
                              letterSpacing: -1,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onSubmitted: _onPriceSubmitted,
                          onTapOutside: (_) {
                            _onPriceSubmitted(_priceController.text);
                            _priceFocusNode.unfocus();
                          },
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // Recommended price
                  Center(
                    child: Text(
                      'Tarifa recomendada: ${widget.suggestedPrice.toCurrency()}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Payment method row
                  _buildSectionRow(
                    icon: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.rappiOrange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _paymentIcon(widget.paymentMethod),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    title: _paymentLabel(widget.paymentMethod),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: AppColors.getTextSecondary(context),
                    ),
                    onTap: () {
                      // TODO: Open payment method selector
                    },
                  ),

                  const Divider(height: 1, indent: 16, endIndent: 16),

                  // Auto-accept toggle
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.send, size: 20, color: AppColors.getTextSecondary(context)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Aceptar automaticamente al conductor mas cercano por ${_editedPrice.toCurrency()}',
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

                  const Divider(height: 1, indent: 16, endIndent: 16),

                  // Route summary: origin
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4285F4),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.pickupAddress.isNotEmpty
                                ? widget.pickupAddress
                                : 'Punto de recogida',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.getTextPrimary(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Dotted line connector
                  Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: Column(
                      children: List.generate(
                        3,
                        (_) => Container(
                          width: 2,
                          height: 4,
                          margin: const EdgeInsets.symmetric(vertical: 1),
                          color: AppColors.getBorder(context),
                        ),
                      ),
                    ),
                  ),

                  // Route summary: destination
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE53935),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.destinationAddress.isNotEmpty
                                ? widget.destinationAddress
                                : 'Destino',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.getTextPrimary(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.add,
                          size: 20,
                          color: AppColors.getTextSecondary(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom CTA bar
          Container(
            padding: EdgeInsets.fromLTRB(
              16, 12, 16,
              MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: AppColors.getSurface(context),
              border: Border(
                top: BorderSide(color: AppColors.getBorder(context), width: 0.5),
              ),
            ),
            child: Row(
              children: [
                // CTA button
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: Material(
                      color: widget.isSearchingDriver
                          ? AppColors.grey400
                          : AppColors.rappiOrange,
                      borderRadius: BorderRadius.circular(26),
                      child: InkWell(
                        onTap: widget.isSearchingDriver
                            ? null
                            : () {
                                _onPriceSubmitted(_priceController.text);
                                widget.onSearchDriver();
                                Navigator.pop(context);
                              },
                        borderRadius: BorderRadius.circular(26),
                        child: Center(
                          child: widget.isSearchingDriver
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'Buscar conductor',
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
                const SizedBox(width: 12),
                // Filter icon
                GestureDetector(
                  onTap: () {
                    // TODO: Open filter/settings
                  },
                  child: Icon(
                    Icons.tune,
                    size: 24,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionRow({
    required Widget icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }
}
