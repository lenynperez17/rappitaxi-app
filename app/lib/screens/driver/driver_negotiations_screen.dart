import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/price_negotiation_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/price_negotiation_model.dart';

/// Pantalla de negociaciones para conductores
/// Muestra las solicitudes activas donde pueden hacer ofertas
class DriverNegotiationsScreen extends StatefulWidget {
  const DriverNegotiationsScreen({super.key});

  @override
  State<DriverNegotiationsScreen> createState() => _DriverNegotiationsScreenState();
}

class _DriverNegotiationsScreenState extends State<DriverNegotiationsScreen> {
  // Timer para actualizar el cronómetro cada segundo
  Timer? _countdownTimer;

  // Stream de negociaciones en tiempo real
  StreamSubscription<QuerySnapshot>? _negotiationsSubscription;
  List<PriceNegotiation> _negotiations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _startCountdownTimer();
    _listenToNegotiations();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _negotiationsSubscription?.cancel();
    super.dispose();
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          // Forzar rebuild para actualizar el cronómetro
        });
      }
    });
  }

  void _listenToNegotiations() {
    // Escuchar negociaciones en tiempo real desde Firestore
    _negotiationsSubscription = FirebaseFirestore.instance
        .collection('negotiations')
        .where('status', whereIn: ['waiting', 'negotiating'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      final now = DateTime.now();
      final negotiations = snapshot.docs
          .map((doc) {
            try {
              final data = doc.data();

              // Parsear expiresAt que puede ser String o Timestamp
              DateTime expiresAt;
              final expiresAtRaw = data['expiresAt'];
              if (expiresAtRaw is Timestamp) {
                expiresAt = expiresAtRaw.toDate();
              } else if (expiresAtRaw is String) {
                expiresAt = DateTime.parse(expiresAtRaw);
              } else {
                expiresAt = now; // Default a ahora si no es válido
              }

              // Filtrar expiradas
              if (now.isAfter(expiresAt)) return null;

              return PriceNegotiation(
                id: doc.id,
                passengerId: data['passengerId'] ?? '',
                passengerName: data['passengerName'] ?? 'Usuario',
                passengerPhoto: data['passengerPhoto'] ?? '',
                passengerRating: (data['passengerRating'] ?? 5.0).toDouble(),
                pickup: LocationPoint(
                  latitude: (data['pickup']?['latitude'] ?? 0.0).toDouble(),
                  longitude: (data['pickup']?['longitude'] ?? 0.0).toDouble(),
                  address: data['pickup']?['address'] ?? '',
                  reference: data['pickup']?['reference'],
                ),
                destination: LocationPoint(
                  latitude: (data['destination']?['latitude'] ?? 0.0).toDouble(),
                  longitude: (data['destination']?['longitude'] ?? 0.0).toDouble(),
                  address: data['destination']?['address'] ?? '',
                  reference: data['destination']?['reference'],
                ),
                suggestedPrice: (data['suggestedPrice'] ?? 0.0).toDouble(),
                offeredPrice: (data['offeredPrice'] ?? 0.0).toDouble(),
                distance: (data['distance'] ?? 0.0).toDouble(),
                estimatedTime: data['estimatedTime'] ?? 0,
                createdAt: _parseDateTime(data['createdAt'], now),
                expiresAt: expiresAt,
                status: _parseStatus(data['status']),
                driverOffers: [],
                paymentMethod: _parsePaymentMethod(data['paymentMethod']),
                notes: data['notes'],
              );
            } catch (e) {
              debugPrint('Error parsing negotiation: $e');
              return null;
            }
          })
          .whereType<PriceNegotiation>()
          .toList();

      setState(() {
        _negotiations = negotiations;
        _isLoading = false;
      });
    }, onError: (e) {
      debugPrint('Error listening to negotiations: $e');
      setState(() => _isLoading = false);
    });
  }

  // Helper para parsear DateTime que puede ser String o Timestamp
  DateTime _parseDateTime(dynamic value, DateTime defaultValue) {
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is String) {
      return DateTime.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  NegotiationStatus _parseStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'waiting': return NegotiationStatus.waiting;
      case 'negotiating': return NegotiationStatus.negotiating;
      case 'accepted': return NegotiationStatus.accepted;
      case 'completed': return NegotiationStatus.completed;
      case 'cancelled': return NegotiationStatus.cancelled;
      case 'expired': return NegotiationStatus.expired;
      default: return NegotiationStatus.waiting;
    }
  }

  PaymentMethod _parsePaymentMethod(String? method) {
    switch (method?.toLowerCase()) {
      case 'card': return PaymentMethod.card;
      case 'wallet': return PaymentMethod.wallet;
      default: return PaymentMethod.cash;
    }
  }

  Future<void> _refreshNegotiations() async {
    // El stream se actualiza automáticamente, pero podemos forzar un refresh
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          // Cleanup listeners before popping to prevent black screen
          _countdownTimer?.cancel();
          _negotiationsSubscription?.cancel();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Solicitudes de Viaje'),
          backgroundColor: ModernTheme.rappiOrange,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshNegotiations,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _negotiations.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _refreshNegotiations,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _negotiations.length,
                      itemBuilder: (context, index) {
                        return _buildNegotiationCard(_negotiations[index]);
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay solicitudes activas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Las nuevas solicitudes aparecerán aquí',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildNegotiationCard(PriceNegotiation negotiation) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentDriverId = authProvider.currentUser?.id ?? '';

    // Verificar si el conductor ya hizo una oferta
    final hasOffer = negotiation.driverOffers.any((offer) =>
      offer.driverId == currentDriverId
    );

    // UI: Al tap abre bottom sheet con detalle completo
    return GestureDetector(
      onTap: () => _showNegotiationDetailSheet(negotiation),
      child: Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          // Header con info del pasajero
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: negotiation.passengerPhoto.isNotEmpty
                      ? NetworkImage(negotiation.passengerPhoto)
                      : null,
                  child: negotiation.passengerPhoto.isEmpty
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        negotiation.passengerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Icon(Icons.star, size: 16, color: Colors.amber[700]),
                          const SizedBox(width: 4),
                          Text(
                            negotiation.passengerRating.toStringAsFixed(1),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildTimer(negotiation),
              ],
            ),
          ),

          // Detalles del viaje
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Origen
                _buildLocationRow(
                  icon: Icons.radio_button_checked,
                  color: ModernTheme.success,
                  label: 'Origen',
                  address: negotiation.pickup.address,
                ),
                const SizedBox(height: 12),

                // Destino
                _buildLocationRow(
                  icon: Icons.location_on,
                  color: ModernTheme.error,
                  label: 'Destino',
                  address: negotiation.destination.address,
                ),
                const SizedBox(height: 16),

                // Info del viaje
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoChip(
                        icon: Icons.route,
                        label: '${negotiation.distance.toStringAsFixed(1)} km',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInfoChip(
                        icon: Icons.schedule,
                        label: '${negotiation.estimatedTime} min',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInfoChip(
                        icon: Icons.payments,
                        label: _getPaymentMethodText(negotiation.paymentMethod),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Precio ofrecido por el pasajero
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Precio ofrecido:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        negotiation.offeredPrice.toCurrency(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: ModernTheme.rappiOrange,
                        ),
                      ),
                    ],
                  ),
                ),

                if (negotiation.notes != null && negotiation.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.notes, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            negotiation.notes!,
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Botón de acción
                if (!hasOffer)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _showOfferDialog(negotiation),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ModernTheme.rappiOrange,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Hacer una oferta',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ModernTheme.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: ModernTheme.success),
                        const SizedBox(width: 8),
                        const Text(
                          'Ya realizaste una oferta',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  // UI: Bottom sheet con detalle de la negociacion
  void _showNegotiationDetailSheet(PriceNegotiation negotiation) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          top: 20,
          left: 24,
          right: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: negotiation.passengerPhoto.isNotEmpty
                      ? NetworkImage(negotiation.passengerPhoto)
                      : null,
                  child: negotiation.passengerPhoto.isEmpty
                      ? const Icon(Icons.person, size: 28)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(negotiation.passengerName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Solicitud de viaje',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'S/. ${negotiation.offeredPrice.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ModernTheme.rappiOrange),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildLocationRow(
              icon: Icons.radio_button_checked,
              color: ModernTheme.success,
              label: 'Recogida',
              address: negotiation.pickup.address,
            ),
            const SizedBox(height: 8),
            _buildLocationRow(
              icon: Icons.location_on,
              color: ModernTheme.rappiOrange,
              label: 'Destino',
              address: negotiation.destination.address,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _buildInfoChip(icon: Icons.route, label: '${negotiation.distance.toStringAsFixed(1)} km')),
                const SizedBox(width: 8),
                Expanded(child: _buildInfoChip(icon: Icons.access_time, label: '${negotiation.estimatedTime} min')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimer(PriceNegotiation negotiation) {
    final remaining = negotiation.timeRemaining;

    // Validar tiempo negativo o expirado
    if (remaining.isNegative || remaining.inSeconds <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: ModernTheme.error,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_off, size: 16, color: Colors.white),
            const SizedBox(width: 4),
            const Text(
              'Expirado',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: minutes < 2 ? ModernTheme.error : ModernTheme.warning,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, size: 16, color: Theme.of(context).colorScheme.onPrimary),
          const SizedBox(width: 4),
          Text(
            '$minutes:${seconds.toString().padLeft(2, '0')}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color color,
    required String label,
    required String address,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _getPaymentMethodText(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Efectivo';
      case PaymentMethod.card:
        return 'Tarjeta';
      case PaymentMethod.wallet:
        return 'Wallet';
    }
  }

  void _showOfferDialog(PriceNegotiation negotiation) {
    final priceController = TextEditingController(
      text: negotiation.offeredPrice.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hacer una oferta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Precio sugerido: ${negotiation.suggestedPrice.toCurrency()}',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
            Text(
              'Precio del pasajero: ${negotiation.offeredPrice.toCurrency()}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Tu precio',
                prefixText: '${AppConstants.currencySymbol} ',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ingresa el precio al que estás dispuesto a aceptar este viaje',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final price = double.tryParse(priceController.text);
              if (price == null || price <= 0) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Ingresa un precio válido')),
                  );
                }
                return;
              }

              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }

              if (!context.mounted) return;

              final provider = Provider.of<PriceNegotiationProvider>(
                context,
                listen: false,
              );
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              try {
                // ✅ MODIFICADO: makeDriverOffer ahora retorna String? con mensaje de error
                final error = await provider.makeDriverOffer(
                  negotiation.id,
                  price,
                );

                if (mounted) {
                  if (error != null) {
                    // ✅ Mostrar error (ej: saldo insuficiente)
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text(error),
                        backgroundColor: ModernTheme.error,
                        duration: const Duration(seconds: 5),
                        action: error.contains('Saldo') ? SnackBarAction(
                          label: 'Recargar',
                          textColor: Colors.white,
                          onPressed: () {
                            // Navegar a pantalla de billetera
                            Navigator.pushNamed(context, '/driver-wallet');
                          },
                        ) : null,
                      ),
                    );
                  } else {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Oferta enviada exitosamente'),
                        backgroundColor: ModernTheme.success,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Error al enviar oferta: $e'),
                      backgroundColor: ModernTheme.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.rappiOrange,
            ),
            child: const Text('Enviar oferta'),
          ),
        ],
      ),
    );
  }
}
