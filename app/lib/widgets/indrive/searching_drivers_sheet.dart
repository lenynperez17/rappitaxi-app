import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/ride_provider.dart';
import '../../providers/price_negotiation_provider.dart';
import '../../models/price_negotiation_model.dart';
import 'driver_offer_card.dart';
import '../../services/sound_service.dart';

/// Bottom sheet shown while searching for drivers and viewing offers.
/// Supports collapsed/expanded states via drag gesture on the handle.
class SearchingDriversSheet extends StatefulWidget {
  final String pickupAddress;
  final String destinationAddress;
  final VoidCallback onCancel;
  final void Function(Map<String, dynamic> offer) onAcceptOffer;
  final void Function(Map<String, dynamic> offer) onRejectOffer;
  final void Function(Map<String, dynamic> offer) onCounterOffer;
  final void Function(dynamic trip) onGoToTracking;
  final double offeredPrice;
  final double suggestedPrice;
  final double minPrice;
  final double maxPrice;
  final ValueChanged<double> onPriceChanged;
  final String selectedPaymentMethod;
  final Future<void> Function(double? newPrice) onRenewSearch;

  const SearchingDriversSheet({
    super.key,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.onCancel,
    required this.onAcceptOffer,
    required this.onRejectOffer,
    required this.onCounterOffer,
    required this.onGoToTracking,
    required this.offeredPrice,
    required this.suggestedPrice,
    required this.minPrice,
    required this.maxPrice,
    required this.onPriceChanged,
    required this.onRenewSearch,
    this.selectedPaymentMethod = 'Efectivo',
  });

  @override
  State<SearchingDriversSheet> createState() => _SearchingDriversSheetState();
}

class _SearchingDriversSheetState extends State<SearchingDriversSheet> {
  Timer? _countdownTimer;
  int _remainingSeconds = 120;
  bool _autoAccept = false;
  bool _showExpiredInline = false; // Show "increase fare" options inline (not as modal)
  bool _isExpanded = false; // Collapsed by default
  bool _timerExpiredShown = false; // Prevent showing dialog multiple times

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _timerExpiredShown = false;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _countdownTimer?.cancel();
        if (!_timerExpiredShown) {
          _timerExpiredShown = true;
          _showTimerExpiredSheet();
        }
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String get _timerDisplay {
    final min = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final sec = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  String get _priceMessage {
    if (widget.offeredPrice < widget.suggestedPrice) {
      return 'Tarifa menor al promedio. Espere recibir menos ofertas';
    } else if (widget.offeredPrice > widget.suggestedPrice) {
      return 'Mejor tarifa. Tu solicitud tiene prioridad';
    }
    return 'Tarifa promedio. Buscando conductores cercanos';
  }

  IconData get _paymentIcon {
    switch (widget.selectedPaymentMethod.toLowerCase()) {
      case 'yape':
        return Icons.phone_android;
      case 'plin':
        return Icons.phone_android;
      case 'tarjeta':
        return Icons.credit_card;
      case 'billetera':
      case 'wallet':
        return Icons.account_balance_wallet;
      default:
        return Icons.payments_outlined;
    }
  }

  Color _getPaymentColor() {
    switch (widget.selectedPaymentMethod.toLowerCase()) {
      case 'yape':
        return const Color(0xFF6B21A8);
      case 'plin':
        return const Color(0xFF00BFA5);
      case 'tarjeta':
        return const Color(0xFF1565C0);
      case 'billetera':
      case 'wallet':
        return AppColors.rappiOrange;
      default:
        return const Color(0xFF4CAF50);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<RideProvider, PriceNegotiationProvider>(
      builder: (context, rideProvider, negotiationProvider, _) {
        // Read offers from PriceNegotiationProvider (real-time Firestore listener)
        final driverOfferObjects = negotiationProvider.currentNegotiation?.driverOffers
            .where((o) => o.status == OfferStatus.pending)
            .toList() ?? [];
        // Convert DriverOffer objects to Map<String, dynamic> for widget compatibility
        final offers = driverOfferObjects.map((o) => <String, dynamic>{
          'driverId': o.driverId,
          'driverName': o.driverName,
          'driverPhone': o.driverPhone,
          'driverPhoto': o.driverPhoto,
          'driverRating': o.driverRating,
          'vehicleModel': o.vehicleModel,
          'vehiclePlate': o.vehiclePlate,
          'vehicleColor': o.vehicleColor,
          'offeredPrice': o.acceptedPrice,
          'acceptedPrice': o.acceptedPrice,
          'estimatedArrival': o.estimatedArrival,
          'completedTrips': o.completedTrips,
          'acceptanceRate': o.acceptanceRate,
          'status': o.status.name,
        }).toList();
        final hasOffers = offers.isNotEmpty;
        final currentTrip = rideProvider.currentTrip;
        final hasDirectAcceptance = currentTrip?.status == 'accepted' &&
            currentTrip?.driverId != null &&
            !hasOffers;

        if (hasOffers) {
          _countdownTimer?.cancel();
        }

        if (hasDirectAcceptance) {
          return _buildSheetContainer(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AcceptedDriverCard(
                trip: currentTrip!,
                onGoToTracking: () => widget.onGoToTracking(currentTrip),
              ),
            ),
          );
        }

        if (hasOffers) {
          return _buildOffersState(context, offers);
        }

        // Show inline "increase fare" options when timer expired
        if (_showExpiredInline) {
          return _buildExpiredOptionsInline();
        }

        // Searching state: draggable collapsed/expanded
        return _buildSearchingState(context);
      },
    );
  }

  Widget _buildSheetContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: AppColors.getCardShadow(),
      ),
      child: child,
    );
  }

  Widget _buildOffersState(BuildContext context, List<Map<String, dynamic>> offers) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "Cancelar solicitud" pill floating over map
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: GestureDetector(
            onTap: () => _showCancelConfirmation(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.cancelPill,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close, size: 16, color: Colors.white),
                  SizedBox(width: 6),
                  Text('Cancelar solicitud',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                ],
              ),
            ),
          ).animate().fadeIn().slideX(begin: -0.2),
        ),
        // "Elige a un conductor" title (white for contrast over dark overlay)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Text(
            'Elige a un conductor',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        // Scrollable list of offer cards (transparent bg, cards float over map)
        Flexible(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            shrinkWrap: true,
            itemCount: offers.length,
            itemBuilder: (context, index) {
              final offer = offers[index];
              return DriverOfferCard(
                offer: offer,
                index: index,
                passengerOfferedPrice: widget.offeredPrice,
                onAccept: () => widget.onAcceptOffer(offer),
                onReject: () => widget.onRejectOffer(offer),
                onCounterOffer: () => widget.onCounterOffer(offer),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Searching state with collapsed/expanded behavior
  Widget _buildSearchingState(BuildContext context) {
    final showStrikethrough = widget.offeredPrice != widget.suggestedPrice;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return GestureDetector(
      onVerticalDragUpdate: (details) {
        // Drag up (negative dy) = expand, drag down (positive dy) = collapse
        if (details.primaryDelta! < -8 && !_isExpanded) {
          setState(() => _isExpanded = true);
        } else if (details.primaryDelta! > 8 && _isExpanded) {
          setState(() => _isExpanded = false);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: AppColors.getSurface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: AppColors.getCardShadow(),
        ),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle (always visible, draggable)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _buildHandle(),
              ),

              // === ALWAYS VISIBLE: Price section ===
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  children: [
                    // Header: message + countdown
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _priceMessage,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.getTextPrimary(context),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _timerDisplay,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _remainingSeconds / 120.0,
                        backgroundColor: AppColors.getInputFill(context),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.searchingOrange),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Price with -0.50/+0.50 buttons
                    Row(
                      children: [
                        Expanded(
                          child: _PriceButton(
                            label: '- 0.50',
                            enabled: widget.offeredPrice > widget.minPrice,
                            onTap: () {
                              final newPrice = (widget.offeredPrice - 0.50).clamp(widget.minPrice, widget.maxPrice);
                              widget.onPriceChanged(newPrice);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                              child: Text(
                                widget.offeredPrice.toCurrency(decimals: 2),
                                key: ValueKey(widget.offeredPrice),
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.priceBlack,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            if (showStrikethrough)
                              Text(
                                widget.suggestedPrice.toCurrency(decimals: 2),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.getTextSecondary(context),
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PriceButton(
                            label: '+ 0.50',
                            enabled: widget.offeredPrice < widget.maxPrice,
                            onTap: () {
                              final newPrice = (widget.offeredPrice + 0.50).clamp(widget.minPrice, widget.maxPrice);
                              widget.onPriceChanged(newPrice);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // "Aumentar tarifa"
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: widget.offeredPrice < widget.maxPrice
                            ? () {
                                final newPrice = (widget.offeredPrice + 0.50).clamp(widget.minPrice, widget.maxPrice);
                                widget.onPriceChanged(newPrice);
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.getInputFill(context),
                          foregroundColor: AppColors.getTextSecondary(context),
                          disabledBackgroundColor: AppColors.getInputFill(context),
                          disabledForegroundColor: AppColors.getTextSecondary(context).withValues(alpha: 0.5),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Aumentar tarifa',
                          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),

              // === ALWAYS VISIBLE: Auto-accept ===
              _buildSectionCard(
                child: Row(
                  children: [
                    Icon(Icons.send, size: 20, color: AppColors.getTextSecondary(context)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Aceptar automaticamente ofertas entre ${widget.offeredPrice.toCurrency(decimals: 2)} y 5 minutos de distancia',
                        style: TextStyle(fontSize: 13, color: AppColors.getTextPrimary(context)),
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

              // === ALWAYS VISIBLE: Payment method ===
              _buildSectionCard(
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _getPaymentColor().withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_paymentIcon, size: 18, color: _getPaymentColor()),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(fontSize: 15, color: AppColors.getTextPrimary(context)),
                          children: [
                            TextSpan(
                              text: widget.offeredPrice.toCurrency(decimals: 2),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            if (widget.offeredPrice != widget.suggestedPrice) ...[
                              const TextSpan(text: ', '),
                              TextSpan(
                                text: widget.suggestedPrice.toCurrency(decimals: 2),
                                style: TextStyle(
                                  color: AppColors.getTextSecondary(context),
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                            TextSpan(text: ' ${widget.selectedPaymentMethod}'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // === EXPANDABLE: Route summary + Cancel (only when expanded) ===
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Route summary
                    _buildSectionCard(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10, height: 10,
                                decoration: const BoxDecoration(color: Color(0xFF4285F4), shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  widget.pickupAddress.isNotEmpty ? widget.pickupAddress : 'Mi ubicacion',
                                  style: const TextStyle(fontSize: 14),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Column(
                              children: List.generate(3, (_) => Container(
                                width: 2, height: 3,
                                margin: const EdgeInsets.symmetric(vertical: 1),
                                color: AppColors.getBorder(context),
                              )),
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 10, height: 10,
                                decoration: const BoxDecoration(color: Color(0xFF34A853), shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  widget.destinationAddress,
                                  style: const TextStyle(fontSize: 14),
                                  maxLines: 2, overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Cancel button
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding + 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _showCancelConfirmation(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.getInputFill(context),
                            foregroundColor: AppColors.getTextPrimary(context),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'Cancelar solicitud',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 300),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTimerExpiredSheet() {
    if (!mounted) return;
    SoundService().play(AppSound.timerExpired);
    // Show expired options inline (not as modal) so they disappear with the widget
    setState(() => _showExpiredInline = true);
  }

  /// Build the inline "increase fare" UI (replaces the old modal bottom sheet)
  Widget _buildExpiredOptionsInline() {
    final rawIncrease = widget.offeredPrice * 1.15;
    final increasedPrice = (rawIncrease * 2).round() / 2.0;
    final clampedPrice = increasedPrice.clamp(widget.minPrice, widget.maxPrice);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aumenta tu tarifa para llamar la atencion de los conductores',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.getTextPrimary(context),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 24),

          // Increase price button (green) -- updates Firestore + re-notifies drivers
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onPriceChanged(clampedPrice);
                widget.onRenewSearch(clampedPrice); // Update price + re-notify
                setState(() {
                  _showExpiredInline = false;
                  _remainingSeconds = 120;
                });
                _startCountdown();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC8E636),
                foregroundColor: AppColors.priceBlack,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                'Aumenta la tarifa a ${clampedPrice.toCurrency(decimals: 2)}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Keep current price button (grey) -- just restart local timer
          // No Firestore call needed: ride already has expiresAt=10min
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _showExpiredInline = false;
                  _remainingSeconds = 120;
                });
                _startCountdown();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.getInputFill(context),
                foregroundColor: AppColors.getTextPrimary(context),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                'Mantener ${widget.offeredPrice.toCurrency(decimals: 2)}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelConfirmation(BuildContext context) {
    final increasedPrice = (widget.offeredPrice + 1.0).clamp(widget.minPrice, widget.maxPrice);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).padding.bottom + 24),
        decoration: BoxDecoration(
          color: AppColors.getSurface(ctx),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + close button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '¿Todavia necesitas un viaje? Busca de nuevo con una tarifa mas alta',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.getTextPrimary(ctx),
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.getInputFill(ctx),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, size: 20, color: AppColors.getTextSecondary(ctx)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Aumenta las posibilidades de realizar tu viaje',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.getTextSecondary(ctx),
              ),
            ),
            const SizedBox(height: 24),

            // "Buscar por S/ X.XX" green button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  widget.onPriceChanged(increasedPrice);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC8E636),
                  foregroundColor: AppColors.priceBlack,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  'Buscar por ${increasedPrice.toCurrency(decimals: 2)}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'La mayoria de pasajeros obtiene quien los lleve con esta tarifa en rutas similares',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.getTextSecondary(ctx),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // "Quiero cancelar" button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  widget.onCancel();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.getInputFill(ctx),
                  foregroundColor: AppColors.getTextPrimary(ctx),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Quiero cancelar',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.getInputFill(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.getBorder(context),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// Rectangular price adjustment button (- 0.50 / + 0.50)
class _PriceButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _PriceButton({required this.label, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.3,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.getInputFill(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.getBorder(context)),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.getTextPrimary(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
