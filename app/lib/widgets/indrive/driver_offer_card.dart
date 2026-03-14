import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';

/// Individual driver offer card (inDrive style).
/// Layout: Price+ETA top -> strikethrough original -> driver info -> buttons.
class DriverOfferCard extends StatelessWidget {
  final Map<String, dynamic> offer;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onCounterOffer;
  final int index;
  final double? passengerOfferedPrice;

  const DriverOfferCard({
    super.key,
    required this.offer,
    required this.onAccept,
    required this.onReject,
    required this.onCounterOffer,
    this.index = 0,
    this.passengerOfferedPrice,
  });

  @override
  Widget build(BuildContext context) {
    final driverName = offer['driverName'] ?? 'Conductor';
    final driverPhoto = offer['driverPhoto'] as String?;
    final offeredPrice = (offer['offeredPrice'] as num?)?.toDouble() ?? 0.0;
    final driverRating = (offer['driverRating'] as num?)?.toDouble();
    final totalTrips = offer['totalTrips'] as int?;
    final estimatedArrival = offer['estimatedArrival'] as int?;
    final vehicleModel = offer['vehicleModel'] as String? ?? '';
    final vehicleBrand = offer['vehicleBrand'] as String? ?? '';
    final driverCategory = offer['driverCategory'] as String?;
    final vehicleDisplay = '$vehicleBrand $vehicleModel'.trim();

    final bool isMatchingPrice = passengerOfferedPrice != null &&
        offeredPrice <= passengerOfferedPrice!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.getBorder(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Price + ETA
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                offeredPrice.toCurrency(decimals: 2),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.priceBlack,
                  height: 1,
                ),
              ),
              if (estimatedArrival != null) ...[
                const SizedBox(width: 10),
                Text(
                  '$estimatedArrival min',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ],
            ],
          ),

          // Row 2: Original price strikethrough (if different)
          if (passengerOfferedPrice != null && offeredPrice != passengerOfferedPrice) ...[
            const SizedBox(height: 2),
            Text(
              passengerOfferedPrice!.toCurrency(decimals: 2),
              style: TextStyle(
                fontSize: 14,
                color: AppColors.getTextSecondary(context),
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ],

          // "Tu tarifa" badge
          if (isMatchingPrice) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4C3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.thumb_up, size: 14, color: Color(0xFF827717)),
                  const SizedBox(width: 4),
                  Text(
                    'Tu tarifa',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF827717),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Row 3: Driver photo + info
          Row(
            children: [
              // Driver photo with violet border
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF7C3AED), width: 2),
                ),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                  backgroundImage: driverPhoto != null && driverPhoto.isNotEmpty
                      ? NetworkImage(driverPhoto)
                      : null,
                  child: driverPhoto == null || driverPhoto.isEmpty
                      ? const Icon(Icons.person, color: Color(0xFF7C3AED), size: 22)
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + rating + trips in one row
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            driverName,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (driverRating != null) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(
                            driverRating.toStringAsFixed(2),
                            style: TextStyle(fontSize: 13, color: AppColors.getTextSecondary(context)),
                          ),
                        ],
                        if (totalTrips != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            '$totalTrips viajes',
                            style: TextStyle(fontSize: 13, color: AppColors.getTextSecondary(context)),
                          ),
                        ],
                      ],
                    ),
                    // Vehicle model
                    if (vehicleDisplay.isNotEmpty)
                      Text(
                        vehicleDisplay,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.getTextSecondary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    // Driver category badge
                    if (driverCategory != null && driverCategory.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          driverCategory,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Action buttons row
          Row(
            children: [
              // Reject button (filled grey)
              Expanded(
                child: ElevatedButton(
                  onPressed: onReject,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.getInputFill(context),
                    foregroundColor: AppColors.getTextPrimary(context),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Rechazar', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              // Accept button (gradient yellow -> green)
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.acceptGradient,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onAccept,
                      borderRadius: BorderRadius.circular(28),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Text(
                            'Aceptar',
                            style: TextStyle(
                              color: AppColors.priceBlack,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate()
      .fadeIn(delay: Duration(milliseconds: 100 * index))
      .slideX(begin: 0.15, delay: Duration(milliseconds: 100 * index));
  }
}

/// Card shown when a driver has already accepted the ride directly.
class AcceptedDriverCard extends StatelessWidget {
  final dynamic trip;
  final VoidCallback onGoToTracking;

  const AcceptedDriverCard({super.key, required this.trip, required this.onGoToTracking});

  @override
  Widget build(BuildContext context) {
    final vehicleInfo = trip.vehicleInfo as Map<String, dynamic>?;
    final driverName = vehicleInfo?['driverName'] ?? 'Conductor';
    final driverPhoto = vehicleInfo?['driverPhoto'] as String?;
    final plate = vehicleInfo?['plate'] ?? '';
    final model = vehicleInfo?['model'] ?? '';
    final brand = vehicleInfo?['brand'] ?? '';
    final acceptedPrice = trip.acceptedFare ?? trip.finalFare ?? trip.offeredFare ?? 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 48),
        const SizedBox(height: 12),
        Text(
          '¡Conductor acepto!',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.getTextPrimary(context),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.getInputFill(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.green, width: 2),
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.rappiOrange.withValues(alpha: 0.1),
                  backgroundImage: driverPhoto != null && driverPhoto.isNotEmpty
                      ? NetworkImage(driverPhoto)
                      : null,
                  child: driverPhoto == null || driverPhoto.isEmpty
                      ? const Icon(Icons.person, size: 28, color: AppColors.rappiOrange)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driverName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    if (model.isNotEmpty || brand.isNotEmpty)
                      Text('$brand $model'.trim(),
                        style: TextStyle(fontSize: 13, color: AppColors.getTextSecondary(context))),
                    if (plate.isNotEmpty)
                      Text(plate,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.getTextSecondary(context))),
                  ],
                ),
              ),
              if (acceptedPrice > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'S/ ${acceptedPrice.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: Container(
            decoration: BoxDecoration(
              gradient: AppColors.acceptGradient,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onGoToTracking,
                borderRadius: BorderRadius.circular(28),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.navigation, color: AppColors.priceBlack),
                      const SizedBox(width: 8),
                      Text('Ir a Tracking',
                        style: TextStyle(color: AppColors.priceBlack, fontWeight: FontWeight.w700, fontSize: 16)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }
}
