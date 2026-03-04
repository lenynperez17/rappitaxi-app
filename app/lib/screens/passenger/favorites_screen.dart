// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ✅ NUEVO: Importar FirebaseAuth
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;
import '../../core/theme/modern_theme.dart';
import '../../core/extensions/theme_extensions.dart'; // ✅ Extensión para colores que se adaptan al tema
import '../../core/widgets/custom_place_text_field.dart';
import '../../generated/l10n/app_localizations.dart';

import '../../utils/logger.dart';
import '../../utils/map_marker_utils.dart';
import '../../core/config/app_config.dart';

// 🔐 GOOGLE MAPS API KEY - Usar AppConfig.googleMapsApiKey directamente

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  _FavoritesScreenState createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  late AnimationController _listController;
  late AnimationController _fabController;
  late AnimationController _searchController;
  
  final TextEditingController _searchTextController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;
  String? _userId; // Se obtendrá del usuario actual
  
  // Lugares favoritos desde Firebase
  List<FavoritePlace> _favorites = [];
  List<RecentPlace> _recentPlaces = [];
  
  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fabController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );
    _searchController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    
    _listController.forward();
    _fabController.forward();
    
    // Cargar favoritos desde Firebase
    _loadFavoritesFromFirebase();
  }
  
  Future<void> _loadFavoritesFromFirebase() async {
    try {
      setState(() => _isLoading = true);

      // ✅ CORREGIDO: Obtener el userId del usuario autenticado real
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        AppLogger.debug('Usuario no autenticado, no se pueden cargar favoritos');
        setState(() => _isLoading = false);
        return;
      }
      _userId = currentUser.uid;

      // Cargar lugares favoritos
      final favoritesSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('favorites')
          .orderBy('visitCount', descending: true)
          .get();
      
      List<FavoritePlace> loadedFavorites = [];
      
      for (var doc in favoritesSnapshot.docs) {
        final data = doc.data();
        loadedFavorites.add(FavoritePlace(
          id: doc.id,
          name: data['name'] ?? 'Sin nombre',
          address: data['address'] ?? 'Sin dirección',
          icon: _getIconFromString(data['icon'] ?? 'place'),
          color: Color(data['color'] ?? ModernTheme.primaryBlue.value),
          location: LatLng(
            data['latitude'] ?? -12.0464,
            data['longitude'] ?? -77.0428,
          ),
          isDefault: data['isDefault'] ?? false,
          visitCount: data['visitCount'] ?? 0,
          lastVisit: data['lastVisit'] != null 
              ? (data['lastVisit'] as Timestamp).toDate()
              : DateTime.now(),
        ));
      }
      
      // Si no hay favoritos, mostrar lista vacía (sin crear datos de ejemplo)
      
      // Cargar lugares recientes desde el historial de viajes
      final ridesSnapshot = await _firestore
          .collection('rides')
          .where('passengerId', isEqualTo: _userId)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();
      
      List<RecentPlace> loadedRecent = [];
      Set<String> uniqueAddresses = {};
      
      for (var doc in ridesSnapshot.docs) {
        final data = doc.data();
        final destinationAddress = data['destinationAddress'] ?? '';
        
        if (destinationAddress.isNotEmpty && !uniqueAddresses.contains(destinationAddress)) {
          uniqueAddresses.add(destinationAddress);
          loadedRecent.add(RecentPlace(
            address: destinationAddress,
            date: data['createdAt'] != null 
                ? (data['createdAt'] as Timestamp).toDate()
                : DateTime.now(),
            icon: Icons.location_on,
          ));
        }
        
        if (loadedRecent.length >= 3) break;
      }
      
      setState(() {
        _favorites = loadedFavorites;
        _recentPlaces = loadedRecent;
        _isLoading = false;
      });
      
    } catch (e) {
      AppLogger.error('Error cargando favoritos: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorLoadingFavorites),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }
  
  
  IconData _getIconFromString(String iconName) {
    switch (iconName) {
      case 'home': return Icons.home;
      case 'work': return Icons.work;
      case 'school': return Icons.school;
      case 'fitness': return Icons.fitness_center;
      case 'shopping': return Icons.shopping_cart;
      case 'restaurant': return Icons.restaurant;
      case 'hospital': return Icons.local_hospital;
      default: return Icons.place;
    }
  }
  
  String _getIconString(IconData icon) {
    if (icon == Icons.home) return 'home';
    if (icon == Icons.work) return 'work';
    if (icon == Icons.school) return 'school';
    if (icon == Icons.fitness_center) return 'fitness';
    if (icon == Icons.shopping_cart) return 'shopping';
    if (icon == Icons.restaurant) return 'restaurant';
    if (icon == Icons.local_hospital) return 'hospital';
    return 'place';
  }
  
  /// ✅ CORREGIDO: Aceptar LatLng location como parámetro
  Future<void> _addToFavorites(String name, String address, IconData icon, Color color, LatLng location) async {
    try {
      setState(() => _isLoading = true);

      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('favorites')
          .add({
        'name': name,
        'address': address,
        'icon': _getIconString(icon),
        'color': color.value,
        /// ✅ CORREGIDO: Usar coordenadas reales del autocomplete
        'latitude': location.latitude,
        'longitude': location.longitude,
        'isDefault': false,
        'visitCount': 0,
        'lastVisit': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Recargar favoritos
      await _loadFavoritesFromFirebase();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.placeAddedToFavorites),
            backgroundColor: ModernTheme.success,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error agregando favorito: $e');
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorAddingFavorite),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }
  
  Future<void> _removeFavorite(FavoritePlace place) async {
    try {
      // Primero eliminar de la lista local para feedback inmediato
      setState(() {
        _favorites.remove(place);
      });
      
      // Luego eliminar de Firebase
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('favorites')
          .doc(place.id)
          .delete();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.placeRemovedMessage(place.name)),
            backgroundColor: ModernTheme.success,
            action: SnackBarAction(
              label: AppLocalizations.of(context)!.undo,
              onPressed: () async {
                // Restaurar en Firebase
                await _firestore
                    .collection('users')
                    .doc(_userId)
                    .collection('favorites')
                    .doc(place.id)
                    .set({
                  'name': place.name,
                  'address': place.address,
                  'icon': _getIconString(place.icon),
                  'color': place.color.value,
                  'latitude': place.location.latitude,
                  'longitude': place.location.longitude,
                  'isDefault': place.isDefault,
                  'visitCount': place.visitCount,
                  'lastVisit': Timestamp.fromDate(place.lastVisit),
                  'createdAt': FieldValue.serverTimestamp(),
                });
                
                // Recargar favoritos
                await _loadFavoritesFromFirebase();
              },
            ),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error eliminando favorito: $e');
      // Restaurar en caso de error
      setState(() {
        _favorites.add(place);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorRemovingFavorite),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }
  
  /// ✅ CORREGIDO: Aceptar LatLng location como parámetro
  Future<void> _editFavorite(FavoritePlace place, String name, String address, IconData icon, Color color, LatLng location) async {
    try {
      setState(() => _isLoading = true);

      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('favorites')
          .doc(place.id)
          .update({
        'name': name,
        'address': address,
        'icon': _getIconString(icon),
        'color': color.value,
        /// ✅ CORREGIDO: Actualizar también las coordenadas
        'latitude': location.latitude,
        'longitude': location.longitude,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Recargar favoritos
      await _loadFavoritesFromFirebase();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.placeUpdated),
            backgroundColor: ModernTheme.success,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error actualizando favorito: $e');
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorUpdatingFavorite),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }
  
  
  List<FavoritePlace> get _filteredFavorites {
    if (_searchQuery.isEmpty) return _favorites;
    
    return _favorites.where((place) {
      return place.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             place.address.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }
  
  @override
  void dispose() {
    _listController.dispose();
    _fabController.dispose();
    _searchController.dispose();
    _searchTextController.dispose();
    super.dispose();
  }
  
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (_isSearching) {
        _searchController.forward();
      } else {
        _searchController.reverse();
        _searchTextController.clear();
        _searchQuery = '';
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surfaceColor,
      appBar: AppBar(
        backgroundColor: ModernTheme.rappiOrange,
        title: AnimatedSwitcher(
          duration: Duration(milliseconds: 300),
          child: _isSearching
              /// ✅ COLORES INVERTIDOS: Fondo blanco con texto oscuro para contraste
              ? Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _searchTextController,
                    autofocus: true,
                    style: TextStyle(
                      color: ModernTheme.rappiOrange,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    cursorColor: ModernTheme.rappiOrange,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.searchPlaceHint,
                      hintStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                )
              : Text(
                  AppLocalizations.of(context)!.favoritePlacesTitle,
                  style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                ),
        ),
        leading: IconButton(
          icon: Icon(
            _isSearching ? Icons.close : Icons.arrow_back,
            color: Theme.of(context).colorScheme.surface,
          ),
          onPressed: () {
            if (_isSearching) {
              _toggleSearch();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          if (!_isSearching)
            IconButton(
              icon: Icon(Icons.search, color: Theme.of(context).colorScheme.onPrimary),
              onPressed: _toggleSearch,
            ),
          IconButton(
            icon: Icon(Icons.map, color: Theme.of(context).colorScheme.onPrimary),
            onPressed: _showMapView,
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Mini mapa en la parte superior (height: 200) mostrando favoritos como pins
          SliverToBoxAdapter(
            child: _buildMiniMap(),
          ),

          // Estadísticas
          SliverToBoxAdapter(
            child: _buildStatistics(),
          ),
          
          // Lugares favoritos principales
          if (_filteredFavorites.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text(
                  AppLocalizations.of(context)!.yourPlaces,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.primaryText,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final place = _filteredFavorites[index];
                    final delay = index * 0.1;
                    final animation = Tween<double>(
                      begin: 0,
                      end: 1,
                    ).animate(
                      CurvedAnimation(
                        parent: _listController,
                        curve: Interval(
                          delay,
                          // ✅ CORREGIDO: Limitar end a 1.0 para prevenir assertion 'end <= 1.0'
                          math.min(delay + 0.5, 1.0),
                          // ✅ CORREGIDO: Usar Curves.easeOut en vez de easeOutBack (que sobrepasa 1.0)
                          curve: Curves.easeOut,
                        ),
                      ),
                    );
                    
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(50 * (1 - animation.value), 0),
                          child: Opacity(
                            // ✅ Clamp para prevenir valores fuera del rango [0.0, 1.0] por Curves.easeOutBack
                            opacity: animation.value.clamp(0.0, 1.0),
                            child: _buildFavoriteCard(place),
                          ),
                        );
                      },
                    );
                  },
                  childCount: _filteredFavorites.length,
                ),
              ),
            ),
          ],
          
          // Lugares recientes
          if (!_isSearching && _searchQuery.isEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Text(
                  AppLocalizations.of(context)!.recentlyVisited,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.primaryText,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final place = _recentPlaces[index];
                    return _buildRecentPlaceCard(place);
                  },
                  childCount: _recentPlaces.length,
                ),
              ),
            ),
          ],
          
          // Espacio al final
          SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _fabController,
        builder: (context, child) {
          return Transform.scale(
            scale: _fabController.value,
            child: FloatingActionButton.extended(
              onPressed: _addNewFavorite,
              backgroundColor: ModernTheme.rappiOrange,
              icon: Icon(Icons.add_location, color: Theme.of(context).colorScheme.onPrimary),
              label: Text(
                AppLocalizations.of(context)!.addPlace,
                style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
              ),
            ),
          );
        },
      ),
    );
  }
  
  /// Mini mapa en la parte superior (height: 200) mostrando los favoritos como pins
  Widget _buildMiniMap() {
    // Crear marcadores para los favoritos
    final Set<Marker> miniMarkers = {};
    for (int i = 0; i < _favorites.length; i++) {
      final place = _favorites[i];
      miniMarkers.add(
        Marker(
          markerId: MarkerId('mini_${place.id}'),
          position: place.location,
          infoWindow: InfoWindow(title: place.name),
        ),
      );
    }

    // Centro del mapa: primer favorito o Lima por defecto
    final center = _favorites.isNotEmpty
        ? _favorites.first.location
        : LatLng(-12.0464, -77.0428);

    return Container(
      height: 200,
      margin: EdgeInsets.all(0),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: center,
              zoom: _favorites.length > 1 ? 12 : 15,
            ),
            markers: miniMarkers,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            scrollGesturesEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            zoomGesturesEnabled: false,
          ),
          // Overlay con etiqueta
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: ModernTheme.rappiOrange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on, size: 14, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    '${_favorites.length} lugares guardados',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics() {
    final totalVisits = _favorites.fold<int>(
      0, (total, place) => total + place.visitCount);

    // ✅ CORREGIDO: Verificar que la lista no esté vacía antes de usar reduce()
    final mostVisitedName = _favorites.isNotEmpty
        ? _favorites.reduce((a, b) => a.visitCount > b.visitCount ? a : b).name
        : '-';

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: ModernTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: ModernTheme.rappiOrange.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: Icons.favorite,
                value: '${_favorites.length}',
                label: AppLocalizations.of(context)!.favoritesLabel,
              ),
              Container(
                height: 40,
                width: 1,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.24),
              ),
              _buildStatItem(
                icon: Icons.location_on,
                value: '$totalVisits',
                label: AppLocalizations.of(context)!.visitsLabel,
              ),
              Container(
                height: 40,
                width: 1,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.24),
              ),
              _buildStatItem(
                icon: Icons.star,
                value: mostVisitedName,
                label: AppLocalizations.of(context)!.mostVisited,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.onPrimary, size: 20),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: Theme.of(context).colorScheme.surface,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  Widget _buildFavoriteCard(FavoritePlace place) {
    return Dismissible(
      key: Key(place.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: ModernTheme.error,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onPrimary),
      ),
      confirmDismiss: (direction) async {
        return await _confirmDelete(place);
      },
      onDismissed: (direction) async {
        // Eliminar de Firebase
        await _removeFavorite(place);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: ModernTheme.getCardShadow(context),
        ),
        child: InkWell(
          onTap: () => _selectPlace(place),
          onLongPress: () => _editPlace(place),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Icono
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: place.color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    place.icon,
                    color: place.color,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                
                // Información
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              place.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: context.primaryText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (place.isDefault) ...[
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.mainLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: ModernTheme.rappiOrange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        place.address,
                        style: TextStyle(
                          fontSize: 14,
                          color: context.secondaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: context.secondaryText,
                          ),
                          Flexible(
                            child: Text(
                              AppLocalizations.of(context)!.visitsCount(place.visitCount),
                              style: TextStyle(
                                fontSize: 12,
                                color: context.secondaryText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 12),
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: context.secondaryText,
                          ),
                          Flexible(
                            child: Text(
                              ' ${_formatLastVisit(place.lastVisit)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.secondaryText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Botones de acción
                Column(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.directions,
                        color: ModernTheme.rappiOrange,
                      ),
                      onPressed: () => _navigateToPlace(place),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildRecentPlaceCard(RecentPlace place) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.getCardShadow(context),
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            place.icon,
            color: context.secondaryText,
            size: 20,
          ),
        ),
        title: Text(
          place.address,
          style: TextStyle(fontSize: 14),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _formatDate(place.date),
          style: TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.add_circle_outline,
            color: ModernTheme.rappiOrange,
          ),
          onPressed: () => _addRecentToFavorites(place),
        ),
        onTap: () => _selectRecentPlace(place),
      ),
    );
  }
  
  String _formatLastVisit(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inHours < 1) {
      return AppLocalizations.of(context)!.minutesAgo(difference.inMinutes);
    } else if (difference.inDays < 1) {
      return AppLocalizations.of(context)!.hoursAgo(difference.inHours);
    } else if (difference.inDays == 1) {
      return AppLocalizations.of(context)!.yesterday;
    } else {
      return AppLocalizations.of(context)!.daysAgoFavorites(difference.inDays);
    }
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  void _selectPlace(FavoritePlace place) {
    Navigator.pop(context, place);
  }
  
  void _selectRecentPlace(RecentPlace place) {
    Navigator.pop(context, {
      'address': place.address,
      'isRecent': true,
    });
  }
  
  void _navigateToPlace(FavoritePlace place) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${AppLocalizations.of(context)!.navigatingTo} ${place.name}'),
        backgroundColor: ModernTheme.rappiOrange,
      ),
    );
    Navigator.pop(context, place);
  }
  
  void _editPlace(FavoritePlace place) {
    _showEditDialog(place);
  }
  
  void _addNewFavorite() {
    _showAddFavoriteDialog();
  }
  
  void _addRecentToFavorites(RecentPlace recentPlace) {
    // ✅ CORREGIDO: Al agregar un reciente a favoritos, abrir el diálogo de edición
    // para que el usuario seleccione la dirección con el autocomplete y obtener coordenadas reales
    _showEditDialog(
      FavoritePlace(
        id: '',
        name: 'Nuevo Favorito',
        address: recentPlace.address,
        icon: recentPlace.icon,
        color: ModernTheme.primaryBlue,
        location: LatLng(0, 0), // Se actualizará con coordenadas reales del autocomplete
        visitCount: 0,
        lastVisit: DateTime.now(),
      ),
      isNew: true,
    );
  }
  
  void _showEditDialog(FavoritePlace place, {bool isNew = false}) {
    final nameController = TextEditingController(text: place.name);
    final addressController = TextEditingController(text: place.address);
    IconData selectedIcon = place.icon;
    Color selectedColor = place.color;
    /// ✅ NUEVO: Variable para almacenar las coordenadas seleccionadas del autocomplete
    LatLng? selectedLocation = isNew ? null : place.location;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(isNew ? AppLocalizations.of(context)!.addFavorite : AppLocalizations.of(context)!.editPlace),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nombre
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.placeNameLabel,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),

                  /// ✅ CORREGIDO: Usar CustomPlaceTextField con autocomplete de Google Places
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.addressLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        SizedBox(height: 4),
                        CustomPlaceTextField(
                          controller: addressController,
                          hintText: AppLocalizations.of(context)!.searchAddressHint,
                          googleApiKey: AppConfig.googleMapsApiKey,
                          onPlaceSelected: (PlacePrediction prediction) {
                            /// ✅ Guardar las coordenadas cuando se selecciona un lugar
                            if (prediction.lat != null && prediction.lng != null) {
                              setDialogState(() {
                                selectedLocation = LatLng(prediction.lat!, prediction.lng!);
                              });
                            }
                          },
                        ),
                        if (selectedLocation != null)
                          Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              '📍 ${selectedLocation!.latitude.toStringAsFixed(4)}, ${selectedLocation!.longitude.toStringAsFixed(4)}',
                              style: TextStyle(
                                fontSize: 10,
                                color: ModernTheme.success,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),

                  // Selección de icono
                  Text(AppLocalizations.of(context)!.iconLabel),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      Icons.home,
                      Icons.work,
                      Icons.school,
                      Icons.fitness_center,
                      Icons.shopping_cart,
                      Icons.restaurant,
                      Icons.local_hospital,
                      Icons.place,
                    ].map((icon) {
                      return InkWell(
                        onTap: () {
                          setDialogState(() {
                            selectedIcon = icon;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: selectedIcon == icon
                              ? ModernTheme.rappiOrange.withValues(alpha: 0.2)
                              : Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selectedIcon == icon
                                ? ModernTheme.rappiOrange
                                : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Icon(icon, size: 24),
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 16),

                  // Selección de color
                  Text(AppLocalizations.of(context)!.colorLabel),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ModernTheme.primaryBlue,
                      ModernTheme.warning,
                      ModernTheme.success,
                      Colors.purple,
                      Colors.orange,
                      Colors.pink,
                      Colors.teal,
                      Colors.indigo,
                    ].map((color) {
                      return InkWell(
                        onTap: () {
                          setDialogState(() {
                            selectedColor = color;
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selectedColor == color
                                ? Theme.of(context).colorScheme.onSurface
                                : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              ElevatedButton(
                onPressed: () async {
                  /// ✅ VALIDACIÓN: Verificar que se haya seleccionado una dirección con coordenadas
                  if (selectedLocation == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.of(context)!.selectAddressFromAutocomplete),
                        backgroundColor: ModernTheme.warning,
                      ),
                    );
                    return;
                  }

                  final navigator = Navigator.of(context);

                  if (isNew) {
                    /// ✅ CORREGIDO: Agregar a Firebase con coordenadas reales
                    await _addToFavorites(
                      nameController.text,
                      addressController.text,
                      selectedIcon,
                      selectedColor,
                      selectedLocation!, // ✅ Pasar coordenadas reales
                    );
                  } else {
                    /// ✅ CORREGIDO: Actualizar en Firebase con coordenadas reales
                    await _editFavorite(
                      place,
                      nameController.text,
                      addressController.text,
                      selectedIcon,
                      selectedColor,
                      selectedLocation!, // ✅ Pasar coordenadas reales
                    );
                  }
                  if (!mounted) return;
                  navigator.pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ModernTheme.rappiOrange,
                ),
                child: Text(isNew ? AppLocalizations.of(context)!.add : AppLocalizations.of(context)!.save),
              ),
            ],
          );
        },
      ),
    );
  }
  
  void _showAddFavoriteDialog() {
    _showEditDialog(
      FavoritePlace(
        id: '',
        name: '',
        address: '',
        icon: Icons.place,
        color: ModernTheme.primaryBlue,
        location: LatLng(0, 0),
        visitCount: 0,
        lastVisit: DateTime.now(),
      ),
      isNew: true,
    );
  }
  
  Future<bool> _confirmDelete(FavoritePlace place) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(AppLocalizations.of(context)!.deletePlace(place.name)),
        content: Text(
          AppLocalizations.of(context)!.confirmDeletePlace,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.error,
            ),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    ) ?? false;
  }
  
  void _showMapView() {
    // ✅ CORREGIDO: Verificar que haya favoritos antes de mostrar el mapa
    if (_favorites.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.addFavoritesToViewMap),
          backgroundColor: ModernTheme.warning,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FavoritesMapScreen(favorites: _favorites),
      ),
    );
  }
}

// Pantalla de mapa con favoritos
class FavoritesMapScreen extends StatefulWidget {
  final List<FavoritePlace> favorites;
  
  const FavoritesMapScreen({super.key, required this.favorites});
  
  @override
  _FavoritesMapScreenState createState() => _FavoritesMapScreenState();
}

class _FavoritesMapScreenState extends State<FavoritesMapScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final bool _isLoading = true;
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};

  // Iconos modernos por tipo de favorito
  final Map<String, BitmapDescriptor> _favoriteIcons = {};

  @override
  void initState() {
    super.initState();
    _loadIconsAndCreateMarkers();
  }

  /// Cargar iconos modernos y crear marcadores
  Future<void> _loadIconsAndCreateMarkers() async {
    // Pre-cargar iconos de favoritos por tipo
    for (var place in widget.favorites) {
      final type = _getPlaceType(place.color);
      if (!_favoriteIcons.containsKey(type)) {
        _favoriteIcons[type] = await MapMarkerUtils.getFavoriteIcon(type: type);
      }
    }

    // Crear marcadores con iconos modernos
    for (var place in widget.favorites) {
      final type = _getPlaceType(place.color);
      _markers.add(
        Marker(
          markerId: MarkerId(place.id),
          position: place.location,
          infoWindow: InfoWindow(
            title: place.name,
            snippet: place.address,
          ),
          icon: _favoriteIcons[type] ?? BitmapDescriptor.defaultMarker,
        ),
      );
    }

    if (mounted) setState(() {});
  }

  /// Obtener tipo de favorito según color
  String _getPlaceType(Color color) {
    if (color == ModernTheme.primaryBlue) return 'home';
    if (color == ModernTheme.warning) return 'work';
    if (color == ModernTheme.success) return 'gym';
    if (color == Colors.purple) return 'other';
    return 'default';
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ModernTheme.rappiOrange,
        title: Text(
          AppLocalizations.of(context)!.favoritesMapTitle,
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GoogleMap(
        // ✅ CORREGIDO: Usar ubicación por defecto si no hay favoritos
        initialCameraPosition: CameraPosition(
          target: widget.favorites.isNotEmpty
              ? widget.favorites.first.location
              : LatLng(-12.0464, -77.0428), // Lima centro por defecto
          zoom: 13,
        ),
        onMapCreated: (controller) {
          _mapController = controller;
          // Ajustar cámara para mostrar todos los marcadores
          if (_markers.isNotEmpty) {
            _fitAllMarkers();
          }
        },
        markers: _markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      ),
    );
  }
  
  void _fitAllMarkers() {
    if (_markers.isEmpty) return;
    
    double minLat = _markers.first.position.latitude;
    double maxLat = _markers.first.position.latitude;
    double minLng = _markers.first.position.longitude;
    double maxLng = _markers.first.position.longitude;
    
    for (var marker in _markers) {
      minLat = math.min(minLat, marker.position.latitude);
      maxLat = math.max(maxLat, marker.position.latitude);
      minLng = math.min(minLng, marker.position.longitude);
      maxLng = math.max(maxLng, marker.position.longitude);
    }
    
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        100,
      ),
    );
  }
}

// Modelos
class FavoritePlace {
  final String id;
  final String name;
  final String address;
  final IconData icon;
  final Color color;
  final LatLng location;
  final bool isDefault;
  final int visitCount;
  final DateTime lastVisit;
  
  FavoritePlace({
    required this.id,
    required this.name,
    required this.address,
    required this.icon,
    required this.color,
    required this.location,
    this.isDefault = false,
    required this.visitCount,
    required this.lastVisit,
  });
}

class RecentPlace {
  final String address;
  final DateTime date;
  final IconData icon;
  
  RecentPlace({
    required this.address,
    required this.date,
    required this.icon,
  });
}