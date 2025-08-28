import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/oasis_button.dart';
import '../../domain/entities/ride_request.dart';

class RideRequestCard extends StatefulWidget {
  final RideRequest request;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const RideRequestCard({
    super.key,
    required this.request,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<RideRequestCard> createState() => _RideRequestCardState();
}

class _RideRequestCardState extends State<RideRequestCard> {
  late Timer _timer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.request.timeoutSeconds;
    _startTimer();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _remainingSeconds--;
          if (_remainingSeconds <= 0) {
            timer.cancel();
            widget.onReject();
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = _remainingSeconds / widget.request.timeoutSeconds;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con timer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Info del pasajero
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      // backgroundColor: Colors.grey[200],
                      backgroundImage: widget.request.passengerPhoto != null
                          ? NetworkImage(widget.request.passengerPhoto!)
                          : null,
                      child: widget.request.passengerPhoto == null
                          ? const Icon(Icons.person, color: Colors.grey)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.request.passengerName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              size: 16,
                              color: Colors.amber[700],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.request.passengerRating.toStringAsFixed(1),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                // Timer circular
                CircularPercentIndicator(
                  radius: 30.0,
                  lineWidth: 4.0,
                  percent: progress,
                  center: Text(
                    '$_remainingSeconds',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _remainingSeconds <= 10
                              ? AppTheme.errorColor
                              : AppTheme.primaryColor,
                        ),
                  ),
                  progressColor: _remainingSeconds <= 10
                      ? AppTheme.errorColor
                      : AppTheme.primaryColor,
                  // backgroundColor: Colors.grey[300]!,
                  animation: true,
                  animateFromLastPercent: true,
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Información del viaje
            Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: Colors.grey[300],
                    ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.request.pickup.address,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        widget.request.destination.address,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Detalles del viaje
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildDetail(
                    context,
                    icon: Icons.route,
                    value: '${widget.request.estimatedDistance.toStringAsFixed(1)} km',
                    label: 'Distancia',
                  ),
                  Container(
                    height: 30,
                    width: 1,
                    color: Colors.grey[300],
                  ),
                  _buildDetail(
                    context,
                    icon: Icons.schedule,
                    value: '${widget.request.estimatedDuration} min',
                    label: 'Duración',
                  ),
                  Container(
                    height: 30,
                    width: 1,
                    color: Colors.grey[300],
                  ),
                  _buildDetail(
                    context,
                    icon: Icons.attach_money,
                    value: 'S/ ${widget.request.estimatedFare.toStringAsFixed(2)}',
                    label: 'Tarifa',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Tipo de vehículo y método de pago
            Row(
              children: [
                Chip(
                  label: Text(_getVehicleTypeName(widget.request.vehicleType)),
                  avatar: Icon(
                    Icons.directions_car,
                    size: 16,
                    color: AppTheme.primaryColor,
                  ),
                  // backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(_getPaymentMethodName(widget.request.paymentMethod)),
                  avatar: Icon(
                    _getPaymentMethodIcon(widget.request.paymentMethod),
                    size: 16,
                    color: AppTheme.secondaryColor,
                  ),
                  // backgroundColor: AppTheme.secondaryColor.withOpacity(0.1),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Botones de acción
            Row(
              children: [
                Expanded(
                  child: OasisButton(
                    text: 'Rechazar',
                    onPressed: widget.onReject,
                    isOutlined: true,
                    // textColor: AppTheme.errorColor,
                    // borderColor: AppTheme.errorColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OasisButton(
                    text: 'Aceptar',
                    onPressed: widget.onAccept,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate()
        .fadeIn()
        .scale(begin: const Offset(0.95, 0.95))
        .shake(
          delay: Duration(seconds: widget.request.timeoutSeconds - 10),
          duration: const Duration(milliseconds: 500),
        );
  }

  Widget _buildDetail(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: AppTheme.primaryColor,
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
              ),
        ),
      ],
    );
  }

  String _getVehicleTypeName(String type) {
    switch (type) {
      case 'economy':
        return 'Económico';
      case 'standard':
        return 'Estándar';
      case 'premium':
        return 'Premium';
      default:
        return type;
    }
  }

  String _getPaymentMethodName(String method) {
    switch (method) {
      case 'cash':
        return 'Efectivo';
      case 'card':
        return 'Tarjeta';
      case 'mercadopago':
        return 'Mercado Pago';
      case 'yape':
        return 'Yape';
      default:
        return method;
    }
  }

  IconData _getPaymentMethodIcon(String method) {
    switch (method) {
      case 'cash':
        return Icons.money;
      case 'card':
        return Icons.credit_card;
      case 'mercadopago':
        return Icons.account_balance_wallet;
      case 'yape':
        return Icons.phone_android;
      default:
        return Icons.payment;
    }
  }
}