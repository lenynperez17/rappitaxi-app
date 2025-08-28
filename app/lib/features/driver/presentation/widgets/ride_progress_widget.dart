import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/oasis_button.dart';
import '../../../../shared/models/ride_model.dart';

class RideProgressWidget extends StatelessWidget {
  final RideModel ride;
  final bool hasArrivedAtPickup;
  final bool isNavigatingToDestination;
  final VoidCallback onCancelRide;
  final VoidCallback onCallPassenger;
  final VoidCallback onMessagePassenger;

  const RideProgressWidget({
    super.key,
    required this.ride,
    required this.hasArrivedAtPickup,
    required this.isNavigatingToDestination,
    required this.onCancelRide,
    required this.onCallPassenger,
    required this.onMessagePassenger,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle visual
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Información del pasajero
              _buildPassengerInfo(context),
              
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              
              // Información del viaje
              _buildTripInfo(context),
              
              const SizedBox(height: 20),
              
              // Botones de acción
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2);
  }

  Widget _buildPassengerInfo(BuildContext context) {
    return Row(
      children: [
        // Avatar del pasajero
        CircleAvatar(
          radius: 24,
          // backgroundColor: Colors.grey[200],
          backgroundImage: ride.passengerInfo?.photoUrl != null
              ? NetworkImage(ride.passengerInfo!.photoUrl!)
              : null,
          child: ride.passengerInfo?.photoUrl == null
              ? Icon(
                  Icons.person,
                  color: Colors.grey[400],
                )
              : null,
        ),
        
        const SizedBox(width: 12),
        
        // Información del pasajero
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ride.passengerInfo?.name ?? 'Pasajero',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.star,
                    size: 16,
                    color: Colors.amber[700],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${ride.passengerInfo?.rating ?? 5.0}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _getRideStatusColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _getRideStatusText(),
                      style: TextStyle(
                        color: _getRideStatusColor(),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Botones de contacto
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onCallPassenger,
              icon: const Icon(Icons.call),
              style: IconButton.styleFrom(
                // backgroundColor: AppTheme.successColor.withOpacity(0.1),
                foregroundColor: AppTheme.successColor,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onMessagePassenger,
              icon: const Icon(Icons.message),
              style: IconButton.styleFrom(
                // backgroundColor: AppTheme.infoColor.withOpacity(0.1),
                foregroundColor: AppTheme.infoColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTripInfo(BuildContext context) {
    return Column(
      children: [
        // Origen
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.radio_button_checked,
                color: AppTheme.successColor,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasArrivedAtPickup ? 'Recogida completada' : 'Punto de recogida',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  Text(
                    ride.pickup?.address ?? 'Dirección no disponible',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
            if (hasArrivedAtPickup)
              Icon(
                Icons.check_circle,
                color: AppTheme.successColor,
                size: 20,
              ),
          ],
        ),
        
        // Línea conectora
        Container(
          margin: const EdgeInsets.only(left: 15, top: 8, bottom: 8),
          child: Row(
            children: List.generate(
              3,
              (index) => Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
        
        // Destino
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.location_on,
                color: AppTheme.errorColor,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Destino',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  Text(
                    ride.destination?.address ?? 'Dirección no disponible',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Información adicional
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoItem(
                context,
                'Tarifa',
                'S/ ${ride.fare?.toStringAsFixed(2) ?? '0.00'}',
                Icons.payments,
                AppTheme.primaryColor,
              ),
              Container(
                height: 30,
                width: 1,
                color: Colors.grey[300],
              ),
              _buildInfoItem(
                context,
                'Distancia',
                '${(ride.distance ?? 0).toStringAsFixed(1)} km',
                Icons.straighten,
                AppTheme.infoColor,
              ),
              Container(
                height: 30,
                width: 1,
                color: Colors.grey[300],
              ),
              _buildInfoItem(
                context,
                'Tipo',
                ride.paymentMethod ?? 'Efectivo',
                Icons.credit_card,
                AppTheme.warningColor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 16,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontSize: 10,
              ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        // Botón cancelar
        Expanded(
          flex: 2,
          child: OutlinedButton.icon(
            onPressed: onCancelRide,
            icon: const Icon(
              Icons.cancel,
              size: 18,
            ),
            label: const Text('Cancelar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
              side: BorderSide(color: AppTheme.errorColor),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        
        const SizedBox(width: 12),
        
        // Botón principal (varía según el estado)
        Expanded(
          flex: 3,
          child: OasisButton(
            text: _getMainButtonText(),
            onPressed: _getMainButtonAction(context) ?? () {},
            // backgroundColor: _getMainButtonColor(),
            icon: Icon(_getMainButtonIcon()),
          ),
        ),
      ],
    );
  }

  String _getMainButtonText() {
    if (!hasArrivedAtPickup) {
      return 'Navegando...';
    } else if (isNavigatingToDestination) {
      return 'Navegando al destino';
    } else {
      return 'Comenzar viaje';
    }
  }

  IconData _getMainButtonIcon() {
    if (!hasArrivedAtPickup) {
      return Icons.navigation;
    } else if (isNavigatingToDestination) {
      return Icons.location_on;
    } else {
      return Icons.play_arrow;
    }
  }

  Color _getMainButtonColor() {
    if (!hasArrivedAtPickup) {
      return AppTheme.warningColor;
    } else {
      return AppTheme.primaryColor;
    }
  }

  VoidCallback? _getMainButtonAction(BuildContext context) {
    // El botón está deshabilitado durante la navegación
    // La acción principal se maneja en el dialog de llegada
    return null;
  }

  Color _getRideStatusColor() {
    switch (ride.status) {
      case 'pending':
        return AppTheme.warningColor;
      case 'accepted':
        return AppTheme.infoColor;
      case 'in_progress':
        return AppTheme.primaryColor;
      case 'completed':
        return AppTheme.successColor;
      case 'cancelled':
        return AppTheme.errorColor;
      default:
        return Colors.grey;
    }
  }

  String _getRideStatusText() {
    if (!hasArrivedAtPickup) {
      return 'Yendo a recoger';
    } else if (isNavigatingToDestination) {
      return 'En viaje';
    } else {
      return 'En punto de recogida';
    }
  }
}