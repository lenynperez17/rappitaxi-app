import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/location_model.dart';
import '../../../../core/services/location_service.dart';
import '../../../home/presentation/providers/location_provider.dart';
import '../../../home/presentation/widgets/location_search_bar.dart';

// Provider temporal para location service
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

class SearchDestinationScreen extends ConsumerStatefulWidget {
  final LocationModel? pickupLocation;
  
  const SearchDestinationScreen({
    super.key,
    this.pickupLocation,
  });
  
  @override
  ConsumerState<SearchDestinationScreen> createState() => _SearchDestinationScreenState();
}

class _SearchDestinationScreenState extends ConsumerState<SearchDestinationScreen> {
  final _pickupController = TextEditingController();
  final _destinationController = TextEditingController();
  final _pickupFocusNode = FocusNode();
  final _destinationFocusNode = FocusNode();
  
  LocationModel? _pickupLocation;
  LocationModel? _destinationLocation;
  List<LocationModel> _searchResults = [];
  bool _isSearchingPickup = true;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _pickupLocation = widget.pickupLocation;
    if (_pickupLocation != null) {
      _pickupController.text = _pickupLocation!.address;
      // Enfocar en destino si ya tenemos pickup
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _destinationFocusNode.requestFocus();
        _isSearchingPickup = false;
      });
    }
  }
  
  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    _pickupFocusNode.dispose();
    _destinationFocusNode.dispose();
    super.dispose();
  }
  
  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final locationService = ref.read(locationServiceProvider);
      final results = await locationService.searchPlaces(query);
      
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _selectLocation(LocationModel location) {
    setState(() {
      if (_isSearchingPickup) {
        _pickupLocation = location;
        _pickupController.text = location.address;
        _destinationFocusNode.requestFocus();
        _isSearchingPickup = false;
      } else {
        _destinationLocation = location;
        _destinationController.text = location.address;
      }
      _searchResults = [];
    });
    
    // Si tenemos ambas ubicaciones, continuar
    if (_pickupLocation != null && _destinationLocation != null) {
      _continueToConfirmRide();
    }
  }
  
  void _continueToConfirmRide() {
    context.push('/ride/confirm', extra: {
      'pickup': _pickupLocation,
      'destination': _destinationLocation,
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('¿A dónde vamos?'),
      ),
      body: Column(
        children: [
          // Formulario de búsqueda
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Campo de pickup
                TextFormField(
                  controller: _pickupController,
                  focusNode: _pickupFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Punto de recogida',
                    prefixIcon: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    suffixIcon: _pickupController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _pickupController.clear();
                                _pickupLocation = null;
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primaryColor),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  onChanged: (value) {
                    setState(() => _isSearchingPickup = true);
                    _searchLocation(value);
                  },
                  onTap: () {
                    setState(() => _isSearchingPickup = true);
                  },
                ).animate().fadeIn(duration: 300.ms),
                
                const SizedBox(height: 12),
                
                // Línea conectora
                Container(
                  margin: const EdgeInsets.only(left: 20),
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 1,
                    height: 20,
                    color: Colors.grey.shade300,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Campo de destino
                TextFormField(
                  controller: _destinationController,
                  focusNode: _destinationFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Destino',
                    prefixIcon: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.location_on,
                        color: AppTheme.accentColor,
                        size: 24,
                      ),
                    ),
                    suffixIcon: _destinationController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _destinationController.clear();
                                _destinationLocation = null;
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primaryColor),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  onChanged: (value) {
                    setState(() => _isSearchingPickup = false);
                    _searchLocation(value);
                  },
                  onTap: () {
                    setState(() => _isSearchingPickup = false);
                  },
                ).animate().fadeIn(duration: 300.ms, delay: 100.ms),
              ],
            ),
          ),
          
          // Resultados de búsqueda
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),
                  )
                : _searchResults.isEmpty
                    ? _buildSuggestions()
                    : _buildSearchResults(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSuggestions() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Lugares favoritos',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildSuggestionTile(
          icon: Icons.home,
          title: 'Casa',
          subtitle: 'Añadir dirección de casa',
          onTap: () {
            // TODO: Navegar a añadir dirección
          },
        ),
        _buildSuggestionTile(
          icon: Icons.work,
          title: 'Trabajo',
          subtitle: 'Añadir dirección de trabajo',
          onTap: () {
            // TODO: Navegar a añadir dirección
          },
        ),
        const SizedBox(height: 24),
        Text(
          'Recientes',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildRecentLocationTile(
          title: 'Aeropuerto Jorge Chávez',
          subtitle: 'Av. Elmer Faucett s/n, Callao',
          onTap: () {
            _selectLocation(
              const LocationModel(
                latitude: -12.0219,
                longitude: -77.1143,
                address: 'Av. Elmer Faucett s/n, Callao',
                name: 'Aeropuerto Jorge Chávez',
                city: 'Callao',
                state: 'Callao',
                country: 'Perú',
              ),
            );
          },
        ),
      ],
    );
  }
  
  Widget _buildSearchResults() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final location = _searchResults[index];
        return ListTile(
          leading: const Icon(
            Icons.location_on_outlined,
            color: AppTheme.textSecondaryColor,
          ),
          title: Text(location.name ?? location.address),
          subtitle: location.name != null ? Text(location.address) : null,
          onTap: () => _selectLocation(location),
        ).animate().fadeIn(delay: Duration(milliseconds: index * 50));
      },
    );
  }
  
  Widget _buildSuggestionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: AppTheme.primaryColor,
          size: 20,
        ),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppTheme.textSecondaryColor,
      ),
      onTap: onTap,
    );
  }
  
  Widget _buildRecentLocationTile({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: const Icon(
        Icons.history,
        color: AppTheme.textSecondaryColor,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}