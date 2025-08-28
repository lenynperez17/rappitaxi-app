import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/oasis_button.dart';
import '../../../../shared/models/location_model.dart';
import '../../../../shared/models/user_model.dart' hide PaymentMethod;
import '../../../home/presentation/providers/location_provider.dart';
import '../../../payment/presentation/providers/payment_provider.dart';
import '../../../payment/domain/entities/payment_method.dart' as pm;
import 'premium_price_negotiation_screen.dart';
import 'premium_scheduled_ride_screen.dart';
import 'premium_shared_ride_screen.dart';
import 'premium_surge_pricing_screen.dart';

class ConfirmRideScreen extends ConsumerStatefulWidget {
  final LocationModel pickup;
  final LocationModel destination;
  
  const ConfirmRideScreen({
    super.key,
    required this.pickup,
    required this.destination,
  });
  
  @override
  ConsumerState<ConfirmRideScreen> createState() => _ConfirmRideScreenState();
}

class _ConfirmRideScreenState extends ConsumerState<ConfirmRideScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  
  String _selectedVehicleType = 'standard';
  pm.PaymentMethod? _selectedPaymentMethod;
  bool _enablePriceNegotiation = false; // InDrive-style price negotiation
  bool _enableScheduledRide = false;    // Didi-style scheduled rides
  bool _enableSharedRide = false;       // Yango-style shared rides
  bool _showSurgePrice = false;         // Uber-style surge pricing
  
  // Precios estimados por tipo de vehículo
  final Map<String, double> _vehiclePrices = {
    'economy': 12.50,
    'standard': 18.00,
    'premium': 25.00,
  };
  
  @override
  void initState() {
    super.initState();
    _setupMapElements();
  }
  
  void _setupMapElements() {
    // Marcadores
    _markers = {
      Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(widget.pickup.latitude, widget.pickup.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: 'Recogida', snippet: widget.pickup.address),
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(widget.destination.latitude, widget.destination.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: 'Destino', snippet: widget.destination.address),
      ),
    };
    
    // Ruta simulada
    _polylines = {
      Polyline(
        polylineId: const PolylineId('route'),
        points: [
          LatLng(widget.pickup.latitude, widget.pickup.longitude),
          LatLng(widget.destination.latitude, widget.destination.longitude),
        ],
        color: AppTheme.primaryColor,
        width: 4,
      ),
    };
  }
  
  void _confirmRide() {
    final baseFare = _vehiclePrices[_selectedVehicleType]!;
    
    // 1. InDrive-style Price Negotiation
    if (_enablePriceNegotiation) {
      final rideRequestId = DateTime.now().millisecondsSinceEpoch.toString();
      context.push('/ride/negotiate-price', extra: {
        'rideRequestId': rideRequestId,
        'pickup': widget.pickup,
        'destination': widget.destination,
        'suggestedPrice': baseFare,
      });
    }
    // 2. Didi-style Scheduled Rides
    else if (_enableScheduledRide) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PremiumScheduledRideScreen(
            pickup: widget.pickup,
            destination: widget.destination,
            estimatedFare: baseFare,
          ),
        ),
      );
    }
    // 3. Yango-style Shared Rides
    else if (_enableSharedRide) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PremiumSharedRideScreen(
            pickup: widget.pickup,
            destination: widget.destination,
            originalFare: baseFare,
          ),
        ),
      );
    }
    // 4. Uber-style Surge Pricing
    else if (_showSurgePrice) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PremiumSurgePricingScreen(
            pickup: widget.pickup,
            destination: widget.destination,
            baseFare: baseFare,
            vehicleType: _selectedVehicleType,
          ),
        ),
      );
    }
    // 5. Normal ride flow
    else {
      context.push('/ride/searching-driver', extra: {
        'pickup': widget.pickup,
        'destination': widget.destination,
        'vehicleType': _selectedVehicleType,
        'paymentMethod': _selectedPaymentMethod?.id ?? 'cash',
        'estimatedFare': baseFare,
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Comentado temporalmente - necesita implementar el provider
    // final locationService = ref.read(locationServiceProvider);
    final distance = 5.0; // Valor temporal hardcodeado
    // locationService.calculateDistance(
    //   widget.pickup.latitude,
    //   widget.pickup.longitude,
    //   widget.destination.latitude,
    //   widget.destination.longitude,
    // );
    
    return Scaffold(
      // backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Mapa
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(
                (widget.pickup.latitude + widget.destination.latitude) / 2,
                (widget.pickup.longitude + widget.destination.longitude) / 2,
              ),
              zoom: 13,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
              // Ajustar cámara para mostrar ambos puntos
              _fitBounds();
            },
          ),
          
          // Botón de retroceso
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
            ).animate().scale(delay: 200.ms),
          ),
          
          // Panel inferior
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Indicador de arrastre
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  // Información del viaje
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Resumen del viaje
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: AppTheme.primaryColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          widget.pickup.address,
                                          style: Theme.of(context).textTheme.bodyMedium,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    margin: const EdgeInsets.only(left: 4),
                                    height: 20,
                                    width: 1,
                                    color: Colors.grey.shade300,
                                  ),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on,
                                        color: AppTheme.accentColor,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          widget.destination.address,
                                          style: Theme.of(context).textTheme.bodyMedium,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${distance.toStringAsFixed(1)} km',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '~${(distance * 3).toInt()} min',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 20),
                        
                        // Selección de tipo de vehículo
                        Text(
                          'Tipo de vehículo',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildVehicleOption(
                              type: 'economy',
                              name: 'Económico',
                              icon: Icons.directions_car,
                              price: _vehiclePrices['economy']!,
                            ),
                            const SizedBox(width: 12),
                            _buildVehicleOption(
                              type: 'standard',
                              name: 'Estándar',
                              icon: Icons.local_taxi,
                              price: _vehiclePrices['standard']!,
                            ),
                            const SizedBox(width: 12),
                            _buildVehicleOption(
                              type: 'premium',
                              name: 'Premium',
                              icon: Icons.star,
                              price: _vehiclePrices['premium']!,
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Método de pago
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Método de pago',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            _buildPaymentMethodSelector(),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Características Premium - Todas las funcionalidades avanzadas
                        Text(
                          'Características Premium',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Grid de características premium
                        Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildPremiumFeatureCard(
                                    Icons.handshake,
                                    'Negociar',
                                    'Precio InDrive',
                                    'Múltiples ofertas',
                                    _enablePriceNegotiation,
                                    (value) {
                                      setState(() {
                                        _enablePriceNegotiation = value;
                                        if (value) {
                                          _enableScheduledRide = false;
                                          _enableSharedRide = false;
                                          _showSurgePrice = false;
                                        }
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildPremiumFeatureCard(
                                    Icons.schedule,
                                    'Programar',
                                    'Viaje Didi',
                                    'Hasta 7 días antes',
                                    _enableScheduledRide,
                                    (value) {
                                      setState(() {
                                        _enableScheduledRide = value;
                                        if (value) {
                                          _enablePriceNegotiation = false;
                                          _enableSharedRide = false;
                                          _showSurgePrice = false;
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildPremiumFeatureCard(
                                    Icons.people,
                                    'Compartir',
                                    'Viaje Yango',
                                    'Ahorra hasta 30%',
                                    _enableSharedRide,
                                    (value) {
                                      setState(() {
                                        _enableSharedRide = value;
                                        if (value) {
                                          _enablePriceNegotiation = false;
                                          _enableScheduledRide = false;
                                          _showSurgePrice = false;
                                        }
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildPremiumFeatureCard(
                                    Icons.trending_up,
                                    'Demanda',
                                    'Pricing Uber',
                                    'Precios dinámicos',
                                    _showSurgePrice,
                                    (value) {
                                      setState(() {
                                        _showSurgePrice = value;
                                        if (value) {
                                          _enablePriceNegotiation = false;
                                          _enableScheduledRide = false;
                                          _enableSharedRide = false;
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Botón de confirmar
                        OasisButton(
                          text: _getConfirmButtonText(),
                          onPressed: _confirmRide,
                        ).animate().fadeIn().scale(delay: 300.ms),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().slideY(begin: 1, end: 0, duration: 400.ms),
          ),
        ],
      ),
    );
  }
  
  Widget _buildVehicleOption({
    required String type,
    required String name,
    required IconData icon,
    required double price,
  }) {
    final isSelected = _selectedVehicleType == type;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedVehicleType = type),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'S/ ${price.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _fitBounds() {
    if (_mapController == null) return;
    
    final bounds = LatLngBounds(
      southwest: LatLng(
        widget.pickup.latitude < widget.destination.latitude
            ? widget.pickup.latitude
            : widget.destination.latitude,
        widget.pickup.longitude < widget.destination.longitude
            ? widget.pickup.longitude
            : widget.destination.longitude,
      ),
      northeast: LatLng(
        widget.pickup.latitude > widget.destination.latitude
            ? widget.pickup.latitude
            : widget.destination.latitude,
        widget.pickup.longitude > widget.destination.longitude
            ? widget.pickup.longitude
            : widget.destination.longitude,
      ),
    );
    
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }
  
  Widget _buildPaymentMethodSelector() {
    final selectedMethod = ref.watch(selectedPaymentMethodProvider);
    
    if (selectedMethod != null) {
      _selectedPaymentMethod = selectedMethod;
    }
    
    return Consumer(
      builder: (context, ref, child) {
        final paymentMethodsAsync = ref.watch(paymentMethodsProvider);
        
        return paymentMethodsAsync.when(
          data: (methods) {
            if (_selectedPaymentMethod == null && methods.isNotEmpty) {
              _selectedPaymentMethod = methods.firstWhere(
                (m) => m.isDefault,
                orElse: () => methods.first,
              );
            }
            
            return InkWell(
              onTap: () async {
                final result = await showModalBottomSheet<pm.PaymentMethod>(
                  context: context,
                  // backgroundColor: Colors.transparent,
                  builder: (context) => _PaymentMethodBottomSheet(
                    methods: methods,
                    selectedMethod: _selectedPaymentMethod,
                  ),
                );
                
                if (result != null) {
                  setState(() {
                    _selectedPaymentMethod = result;
                  });
                  ref.read(selectedPaymentMethodProvider.notifier).state = result;
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getPaymentIcon(_selectedPaymentMethod?.type ?? 'cash'),
                      size: 20,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getPaymentName(_selectedPaymentMethod),
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => const SizedBox(
            height: 40,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => TextButton.icon(
            onPressed: () => ref.invalidate(paymentMethodsProvider),
            icon: const Icon(Icons.refresh, size: 20),
            label: const Text('Reintentar'),
          ),
        );
      },
    );
  }
  
  IconData _getPaymentIcon(String type) {
    switch (type) {
      case 'cash':
        return Icons.money;
      case 'card':
        return Icons.credit_card;
      case 'mercadopago':
        return Icons.account_balance_wallet;
      default:
        return Icons.payment;
    }
  }
  
  String _getPaymentName(pm.PaymentMethod? method) {
    if (method == null) return 'Efectivo';
    
    switch (method.type) {
      case 'cash':
        return 'Efectivo';
      case 'card':
        return '${method.cardBrand ?? 'Tarjeta'} ****${method.cardLast4}';
      case 'mercadopago':
        return 'Mercado Pago';
      default:
        return method.type;
    }
  }

  Widget _buildPremiumFeatureCard(
    IconData icon,
    String title,
    String subtitle,
    String description,
    bool isSelected,
    ValueChanged<bool> onChanged,
  ) {
    return GestureDetector(
      onTap: () => onChanged(!isSelected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.1)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryColor : Colors.grey.shade600,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppTheme.primaryColor : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppTheme.primaryColor : Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 400.ms, duration: 600.ms)
        .scale(delay: 400.ms, duration: 600.ms);
  }

  String _getConfirmButtonText() {
    final baseFare = _vehiclePrices[_selectedVehicleType]!;
    
    if (_enablePriceNegotiation) {
      return '🤝 Negociar Precio - InDrive Style';
    } else if (_enableScheduledRide) {
      return '📅 Programar Viaje - Didi Style';
    } else if (_enableSharedRide) {
      return '👥 Buscar Compañeros - Yango Style';
    } else if (_showSurgePrice) {
      return '📈 Ver Precios Dinámicos - Uber Style';
    } else {
      return 'Confirmar viaje - S/ ${baseFare.toStringAsFixed(2)}';
    }
  }
}

class _PaymentMethodBottomSheet extends StatelessWidget {
  final List<pm.PaymentMethod> methods;
  final pm.PaymentMethod? selectedMethod;
  
  const _PaymentMethodBottomSheet({
    required this.methods,
    this.selectedMethod,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Título
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Selecciona un método de pago',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          
          // Lista de métodos
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: methods.length,
            itemBuilder: (context, index) {
              final method = methods[index];
              final isSelected = method.id == selectedMethod?.id;
              
              return ListTile(
                leading: Icon(
                  _getIcon(method.type),
                  color: isSelected ? AppTheme.primaryColor : null,
                ),
                title: Text(
                  _getTitle(method),
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Text(_getSubtitle(method)),
                trailing: isSelected
                    ? const Icon(
                        Icons.check_circle,
                        color: AppTheme.primaryColor,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(method),
              );
            },
          ),
          
          // Botón de agregar método
          Padding(
            padding: const EdgeInsets.all(20),
            child: OasisButton(
              isOutlined: true,
              text: 'Agregar método de pago',
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/profile/payment-methods/add');
              },
              icon: const Icon(Icons.add),
            ),
          ),
          
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
  
  IconData _getIcon(String type) {
    switch (type) {
      case 'cash':
        return Icons.money;
      case 'card':
        return Icons.credit_card;
      case 'mercadopago':
        return Icons.account_balance_wallet;
      default:
        return Icons.payment;
    }
  }
  
  String _getTitle(pm.PaymentMethod method) {
    switch (method.type) {
      case 'cash':
        return 'Efectivo';
      case 'card':
        return method.cardBrand ?? 'Tarjeta';
      case 'mercadopago':
        return 'Mercado Pago';
      default:
        return method.type;
    }
  }
  
  String _getSubtitle(pm.PaymentMethod method) {
    switch (method.type) {
      case 'cash':
        return 'Paga al finalizar el viaje';
      case 'card':
        return '•••• ${method.cardLast4}';
      case 'mercadopago':
        return 'Cuenta vinculada';
      default:
        return '';
    }
  }
}