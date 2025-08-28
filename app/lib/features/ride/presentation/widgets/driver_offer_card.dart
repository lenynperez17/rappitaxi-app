import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../domain/entities/price_negotiation.dart';
import '../../../../core/constants/app_colors.dart';

class DriverOfferCard extends StatelessWidget {
  final DriverOffer offer;
  final double suggestedPrice;
  final VoidCallback onAccept;
  final bool isAccepting;
  final int rank;

  const DriverOfferCard({
    super.key,
    required this.offer,
    required this.suggestedPrice,
    required this.onAccept,
    this.isAccepting = false,
    required this.rank,
  });

  Color _getRankColor() {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.grey[400]!;
      case 3:
        return Colors.brown[300]!;
      default:
        return AppColors.rappiOrange;
    }
  }

  IconData _getRankIcon() {
    switch (rank) {
      case 1:
        return Icons.emoji_events;
      case 2:
        return Icons.military_tech;
      case 3:
        return Icons.workspace_premium;
      default:
        return Icons.local_taxi;
    }
  }

  double _getPriceDifference() {
    return ((offer.offeredPrice - suggestedPrice) / suggestedPrice * 100);
  }

  String _getPriceDifferenceText() {
    final diff = _getPriceDifference();
    if (diff < 0) {
      return '${diff.abs().toStringAsFixed(1)}% menos';
    } else if (diff > 0) {
      return '${diff.toStringAsFixed(1)}% más';
    } else {
      return 'Precio exacto';
    }
  }

  Color _getPriceDifferenceColor() {
    final diff = _getPriceDifference();
    if (diff < 0) {
      return AppColors.success;
    } else if (diff > 0) {
      return AppColors.error;
    } else {
      return AppColors.rappiOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGoodOffer = offer.offeredPrice <= suggestedPrice;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: rank == 1 
            ? Border.all(color: Colors.amber, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          if (rank == 1)
            BoxShadow(
              color: Colors.amber.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        children: [
          // Encabezado con ranking
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: rank == 1 
                  ? Colors.amber.withOpacity(0.1)
                  : Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                // Ranking badge
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getRankColor(),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getRankIcon(),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                
                // Info del conductor
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.driverName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            color: Colors.amber[600],
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${offer.driverRating.toStringAsFixed(1)} (${offer.totalTrips} viajes)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Avatar del conductor
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: offer.driverPhoto != null
                      ? NetworkImage(offer.driverPhoto!)
                      : null,
                  child: offer.driverPhoto == null
                      ? const Icon(Icons.person, color: Colors.grey)
                      : null,
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Información del vehículo
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.directions_car,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${offer.vehicleModel} • ${offer.vehiclePlate}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Métricas del viaje
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildMetric(
                      Icons.access_time,
                      '${offer.estimatedArrivalMinutes} min',
                      'Llegada',
                    ),
                    _buildMetric(
                      Icons.route,
                      '${offer.estimatedDistance.toStringAsFixed(1)} km',
                      'Distancia',
                    ),
                    _buildMetric(
                      Icons.speed,
                      '${(offer.estimatedDistance / (offer.estimatedArrivalMinutes / 60)).toStringAsFixed(0)} km/h',
                      'Velocidad',
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Precio y diferencia
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isGoodOffer 
                        ? AppColors.success.withOpacity(0.1)
                        : AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isGoodOffer 
                          ? AppColors.success.withOpacity(0.3)
                          : AppColors.error.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Precio Ofrecido',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '\$${offer.offeredPrice.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _getPriceDifferenceColor(),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getPriceDifferenceColor(),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _getPriceDifferenceText(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isGoodOffer 
                                    ? Icons.trending_down 
                                    : Icons.trending_up,
                                color: _getPriceDifferenceColor(),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'vs \$${suggestedPrice.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Mensaje del conductor (si existe)
                if (offer.message != null && offer.message!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 16,
                              color: Colors.blue[600],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Mensaje del conductor:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          offer.message!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // Botón de aceptar
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isAccepting ? null : onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isGoodOffer 
                          ? AppColors.success 
                          : AppColors.rappiOrange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: isGoodOffer ? 4 : 2,
                    ),
                    child: isAccepting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                rank == 1 ? '¡ACEPTAR MEJOR OFERTA!' : 'Aceptar Oferta',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.grey[600],
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}