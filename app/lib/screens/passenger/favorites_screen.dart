import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/design/rt_colors.dart';
import '../../core/design/rt_tokens.dart';
import '../../core/design/rt_typography.dart';
import '../../core/widgets/custom_place_text_field.dart';
import '../../core/widgets/rt_animated_list_item.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_badge.dart';
import '../../core/widgets/rt_card.dart';
import '../../core/widgets/rt_empty_state.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../core/widgets/rt_text_field.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../utils/logger.dart';

final String _googleMapsApiKey = AppConfig.googleMapsApiKey;

// ============================================================
// Modelos
// ============================================================

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

// ============================================================
// Pantalla principal de favoritos
// ============================================================

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchTextController = TextEditingController();

  bool _isLoading = true;
  bool _isSearching = false;
  String _searchQuery = '';
  String? _userId;

  List<FavoritePlace> _favorites = [];
  List<RecentPlace> _recentPlaces = [];

  List<FavoritePlace> get _filteredFavorites {
    if (_searchQuery.isEmpty) return _favorites;
    final query = _searchQuery.toLowerCase();
    return _favorites.where((p) {
      return p.name.toLowerCase().contains(query) ||
          p.address.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadFavoritesFromFirebase();
  }

  @override
  void dispose() {
    _searchTextController.dispose();
    super.dispose();
  }

  // ============================================================
  // Firebase CRUD
  // ============================================================

  Future<void> _loadFavoritesFromFirebase() async {
    try {
      setState(() => _isLoading = true);

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        AppLogger.debug('Usuario no autenticado, no se pueden cargar favoritos');
        setState(() => _isLoading = false);
        return;
      }
      _userId = currentUser.uid;

      final favoritesSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('favorites')
          .orderBy('visitCount', descending: true)
          .get();

      final loadedFavorites = favoritesSnapshot.docs.map((doc) {
        final data = doc.data();
        return FavoritePlace(
          id: doc.id,
          name: data['name'] ?? 'Sin nombre',
          address: data['address'] ?? 'Sin dirección',
          icon: _getIconFromString(data['icon'] ?? 'place'),
          color: Color(data['color'] ?? RtColors.info.toARGB32()),
          location: LatLng(
            data['latitude'] ?? -12.0464,
            data['longitude'] ?? -77.0428,
          ),
          isDefault: data['isDefault'] ?? false,
          visitCount: data['visitCount'] ?? 0,
          lastVisit: data['lastVisit'] != null
              ? (data['lastVisit'] as Timestamp).toDate()
              : DateTime.now(),
        );
      }).toList();

      // Cargar lugares recientes desde el historial de viajes
      final ridesSnapshot = await _firestore
          .collection('rides')
          .where('passengerId', isEqualTo: _userId)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      final List<RecentPlace> loadedRecent = [];
      final Set<String> uniqueAddresses = {};

      for (final doc in ridesSnapshot.docs) {
        final data = doc.data();
        final destinationAddress = data['destinationAddress'] ?? '';

        if (destinationAddress.isNotEmpty &&
            !uniqueAddresses.contains(destinationAddress)) {
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
      if (!mounted) return;

      final errorStr = e.toString();
      String message;
      RtSnackbarType type;

      if (errorStr.contains('index') || errorStr.contains('FAILED_PRECONDITION')) {
        message = 'Los datos se están preparando. Intenta de nuevo en un momento';
        type = RtSnackbarType.info;
      } else if (errorStr.contains('permission') || errorStr.contains('PERMISSION_DENIED')) {
        message = 'No tienes permisos para ver los favoritos';
        type = RtSnackbarType.warning;
      } else if (errorStr.contains('network') || errorStr.contains('unavailable')) {
        message = 'Sin conexión a internet. Verifica tu red';
        type = RtSnackbarType.warning;
      } else {
        message = AppLocalizations.of(context)!.errorLoadingFavorites;
        type = RtSnackbarType.error;
      }

      RtSnackbar.show(context, message: message, type: type);
    }
  }

  Future<void> _addToFavorites(
    String name,
    String address,
    IconData icon,
    Color color,
    LatLng location,
  ) async {
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
        'color': color.toARGB32(),
        'latitude': location.latitude,
        'longitude': location.longitude,
        'isDefault': false,
        'visitCount': 0,
        'lastVisit': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _loadFavoritesFromFirebase();
      if (mounted) {
        RtSnackbar.show(
          context,
          message: AppLocalizations.of(context)!.placeAddedToFavorites,
          type: RtSnackbarType.success,
        );
      }
    } catch (e) {
      AppLogger.error('Error agregando favorito: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        RtSnackbar.show(
          context,
          message: AppLocalizations.of(context)!.errorAddingFavorite,
          type: RtSnackbarType.error,
        );
      }
    }
  }

  Future<void> _removeFavorite(FavoritePlace place) async {
    try {
      setState(() => _favorites.remove(place));

      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('favorites')
          .doc(place.id)
          .delete();

      if (mounted) {
        RtSnackbar.show(context, message: AppLocalizations.of(context)!.placeRemovedMessage(place.name), type: RtSnackbarType.success);
      }
    } catch (e) {
      AppLogger.error('Error eliminando favorito: $e');
      setState(() => _favorites.add(place));
      if (mounted) {
        RtSnackbar.show(
          context,
          message: AppLocalizations.of(context)!.errorRemovingFavorite,
          type: RtSnackbarType.error,
        );
      }
    }
  }

  Future<void> _editFavorite(
    FavoritePlace place,
    String name,
    String address,
    IconData icon,
    Color color,
    LatLng location,
  ) async {
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
        'color': color.toARGB32(),
        'latitude': location.latitude,
        'longitude': location.longitude,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _loadFavoritesFromFirebase();
      if (mounted) {
        RtSnackbar.show(
          context,
          message: AppLocalizations.of(context)!.placeUpdated,
          type: RtSnackbarType.success,
        );
      }
    } catch (e) {
      AppLogger.error('Error actualizando favorito: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        RtSnackbar.show(
          context,
          message: AppLocalizations.of(context)!.errorUpdatingFavorite,
          type: RtSnackbarType.error,
        );
      }
    }
  }

  // ============================================================
  // Helpers de iconos
  // ============================================================

  IconData _getIconFromString(String iconName) {
    switch (iconName) {
      case 'home':
        return Icons.home;
      case 'work':
        return Icons.work;
      case 'school':
        return Icons.school;
      case 'fitness':
        return Icons.fitness_center;
      case 'shopping':
        return Icons.shopping_cart;
      case 'restaurant':
        return Icons.restaurant;
      case 'hospital':
        return Icons.local_hospital;
      default:
        return Icons.place;
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

  // ============================================================
  // Formato de fechas
  // ============================================================

  String _formatLastVisit(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inHours < 1) {
      return AppLocalizations.of(context)!.minutesAgo(difference.inMinutes);
    } else if (difference.inDays < 1) {
      return AppLocalizations.of(context)!.hoursAgo(difference.inHours);
    } else if (difference.inDays == 1) {
      return AppLocalizations.of(context)!.yesterday;
    }
    return AppLocalizations.of(context)!.daysAgoFavorites(difference.inDays);
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  // ============================================================
  // Acciones de navegación
  // ============================================================

  void _selectPlace(FavoritePlace place) => Navigator.pop(context, place);

  void _selectRecentPlace(RecentPlace place) {
    Navigator.pop(context, {'address': place.address, 'isRecent': true});
  }

  void _navigateToPlace(FavoritePlace place) {
    RtSnackbar.show(
      context,
      message: '${AppLocalizations.of(context)!.navigatingTo} ${place.name}',
      type: RtSnackbarType.info,
    );
    Navigator.pop(context, place);
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchTextController.clear();
        _searchQuery = '';
      }
    });
  }

  // ============================================================
  // Dialogos
  // ============================================================

  void _showEditDialog(FavoritePlace place, {bool isNew = false}) {
    final nameController = TextEditingController(text: place.name);
    final addressController = TextEditingController(text: place.address);
    IconData selectedIcon = place.icon;
    Color selectedColor = place.color;
    LatLng? selectedLocation = isNew ? null : place.location;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: RtRadius.borderLg),
            title: Text(
              isNew
                  ? AppLocalizations.of(context)!.addFavorite
                  : AppLocalizations.of(context)!.editPlace,
              style: RtTypo.headingSmall,
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RtTextField(
                    controller: nameController,
                    label: AppLocalizations.of(context)!.placeNameLabel,
                    prefixIcon: Icons.label_outlined,
                  ),
                  const SizedBox(height: RtSpacing.base),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: RtColors.neutral300),
                      borderRadius: RtRadius.borderMd,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: RtSpacing.md,
                      vertical: RtSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.addressLabel,
                          style: RtTypo.labelSmall.copyWith(color: RtColors.neutral500),
                        ),
                        const SizedBox(height: RtSpacing.xs),
                        CustomPlaceTextField(
                          controller: addressController,
                          hintText: AppLocalizations.of(context)!.searchAddressHint,
                          googleApiKey: _googleMapsApiKey,
                          onPlaceSelected: (PlacePrediction prediction) {
                            if (prediction.lat != null && prediction.lng != null) {
                              setDialogState(() {
                                selectedLocation =
                                    LatLng(prediction.lat!, prediction.lng!);
                              });
                            }
                          },
                        ),
                        if (selectedLocation != null)
                          Padding(
                            padding: const EdgeInsets.only(top: RtSpacing.xs),
                            child: Text(
                              '${selectedLocation!.latitude.toStringAsFixed(4)}, ${selectedLocation!.longitude.toStringAsFixed(4)}',
                              style: RtTypo.labelSmall.copyWith(color: RtColors.success),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: RtSpacing.base),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(AppLocalizations.of(context)!.iconLabel, style: RtTypo.labelMedium),
                  ),
                  const SizedBox(height: RtSpacing.sm),
                  Wrap(
                    spacing: RtSpacing.sm,
                    children: [
                      Icons.home, Icons.work, Icons.school,
                      Icons.fitness_center, Icons.shopping_cart,
                      Icons.restaurant, Icons.local_hospital, Icons.place,
                    ].map((icon) {
                      final isSelected = selectedIcon == icon;
                      return InkWell(
                        onTap: () => setDialogState(() => selectedIcon = icon),
                        borderRadius: RtRadius.borderSm,
                        child: Container(
                          padding: const EdgeInsets.all(RtSpacing.sm),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? RtColors.brand.withValues(alpha: 0.15)
                                : RtColors.neutral100,
                            borderRadius: RtRadius.borderSm,
                            border: Border.all(
                              color: isSelected ? RtColors.brand : RtColors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Icon(icon, size: 24),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: RtSpacing.base),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(AppLocalizations.of(context)!.colorLabel, style: RtTypo.labelMedium),
                  ),
                  const SizedBox(height: RtSpacing.sm),
                  Wrap(
                    spacing: RtSpacing.sm,
                    children: [
                      RtColors.info, RtColors.warning, RtColors.success,
                      RtColors.accentPurple, Colors.orange, Colors.pink,
                      Colors.teal, Colors.indigo,
                    ].map((color) {
                      return InkWell(
                        onTap: () => setDialogState(() => selectedColor = color),
                        borderRadius: RtRadius.borderFull,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selectedColor == color
                                  ? RtColors.neutral900
                                  : RtColors.transparent,
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
                  if (selectedLocation == null) {
                    RtSnackbar.show(
                      context,
                      message: AppLocalizations.of(context)!.selectAddressFromAutocomplete,
                      type: RtSnackbarType.warning,
                    );
                    return;
                  }
                  final navigator = Navigator.of(context);
                  if (isNew) {
                    await _addToFavorites(
                      nameController.text,
                      addressController.text,
                      selectedIcon,
                      selectedColor,
                      selectedLocation!,
                    );
                  } else {
                    await _editFavorite(
                      place,
                      nameController.text,
                      addressController.text,
                      selectedIcon,
                      selectedColor,
                      selectedLocation!,
                    );
                  }
                  if (!mounted) return;
                  navigator.pop();
                },
                style: ElevatedButton.styleFrom(backgroundColor: RtColors.brand),
                child: Text(
                  isNew
                      ? AppLocalizations.of(context)!.add
                      : AppLocalizations.of(context)!.save,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<bool> _confirmDelete(FavoritePlace place) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: RtRadius.borderLg),
            title: Text(AppLocalizations.of(context)!.deletePlace(place.name)),
            content: Text(AppLocalizations.of(context)!.confirmDeletePlace),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: RtColors.error),
                child: Text(AppLocalizations.of(context)!.delete),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showMapView() {
    if (_favorites.isEmpty) {
      RtSnackbar.show(
        context,
        message: AppLocalizations.of(context)!.addFavoritesToViewMap,
        type: RtSnackbarType.warning,
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FavoritesMapScreen(favorites: _favorites),
      ),
    );
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: RtColors.neutral50,
      appBar: RtAppBar(
        title: _isSearching ? null : l10n.favoritePlacesTitle,
        titleWidget: _isSearching ? _buildSearchField() : null,
        variant: RtAppBarVariant.gradient,
        showBackButton: !_isSearching,
        leading: _isSearching
            ? IconButton(
                icon: const Icon(Icons.close, color: RtColors.white),
                onPressed: _toggleSearch,
              )
            : null,
        actions: [
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.search, color: RtColors.white),
              onPressed: _toggleSearch,
            ),
          IconButton(
            icon: const Icon(Icons.map, color: RtColors.white),
            onPressed: _showMapView,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: RtColors.brand))
          : _buildBody(l10n),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditDialog(
          FavoritePlace(
            id: '',
            name: '',
            address: '',
            icon: Icons.place,
            color: RtColors.info,
            location: const LatLng(0, 0),
            visitCount: 0,
            lastVisit: DateTime.now(),
          ),
          isNew: true,
        ),
        backgroundColor: RtColors.brand,
        icon: const Icon(Icons.add_location, color: RtColors.white),
        label: Text(l10n.addPlace, style: RtTypo.labelLarge.copyWith(color: RtColors.white)),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: RtSpacing.md, vertical: RtSpacing.xs),
      decoration: BoxDecoration(
        color: RtColors.white,
        borderRadius: RtRadius.borderSm,
      ),
      child: TextField(
        controller: _searchTextController,
        autofocus: true,
        style: RtTypo.bodyMedium.copyWith(color: RtColors.neutral900),
        cursorColor: RtColors.brand,
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context)!.searchPlaceHint,
          hintStyle: RtTypo.bodyMedium.copyWith(color: RtColors.neutral400),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_filteredFavorites.isEmpty && _recentPlaces.isEmpty) {
      return Center(
        child: RtEmptyState(
          icon: Icons.favorite_border_rounded,
          title: l10n.favoritePlacesTitle,
          description: l10n.addFavoritesToViewMap,
          actionLabel: l10n.addPlace,
          onAction: () => _showEditDialog(
            FavoritePlace(
              id: '',
              name: '',
              address: '',
              icon: Icons.place,
              color: RtColors.info,
              location: const LatLng(0, 0),
              visitCount: 0,
              lastVisit: DateTime.now(),
            ),
            isNew: true,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        if (_filteredFavorites.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(RtSpacing.base, RtSpacing.lg, RtSpacing.base, RtSpacing.sm),
            child: Text(l10n.yourPlaces, style: RtTypo.headingSmall),
          ),
          ...List.generate(_filteredFavorites.length, (index) {
            return RtAnimatedListItem(
              index: index,
              child: _buildFavoriteCard(_filteredFavorites[index]),
            );
          }),
        ],
        if (!_isSearching && _searchQuery.isEmpty && _recentPlaces.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(RtSpacing.base, RtSpacing.xl, RtSpacing.base, RtSpacing.sm),
            child: Text(l10n.recentlyVisited, style: RtTypo.headingSmall),
          ),
          ..._recentPlaces.map(_buildRecentPlaceCard),
        ],
      ],
    );
  }

  Widget _buildFavoriteCard(FavoritePlace place) {
    return Dismissible(
      key: Key(place.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: RtSpacing.base,
          vertical: RtSpacing.xs,
        ),
        padding: const EdgeInsets.symmetric(horizontal: RtSpacing.lg),
        decoration: BoxDecoration(
          color: RtColors.error,
          borderRadius: RtRadius.borderMd,
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete, color: RtColors.white),
      ),
      confirmDismiss: (_) => _confirmDelete(place),
      onDismissed: (_) => _removeFavorite(place),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: RtSpacing.base, vertical: RtSpacing.xs),
        child: RtCard(
          onTap: () => _selectPlace(place),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: place.color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(place.icon, color: place.color, size: RtIconSize.md),
              ),
              const SizedBox(width: RtSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            place.name,
                            style: RtTypo.titleLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (place.isDefault) ...[
                          const SizedBox(width: RtSpacing.sm),
                          RtBadge(
                            label: AppLocalizations.of(context)!.mainLabel,
                            color: RtColors.brand,
                            variant: RtBadgeVariant.subtle,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      place.address,
                      style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: RtSpacing.xs),
                    Text(
                      '${AppLocalizations.of(context)!.visitsCount(place.visitCount)}  -  ${_formatLastVisit(place.lastVisit)}',
                      style: RtTypo.labelSmall.copyWith(color: RtColors.neutral400),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.directions, color: RtColors.brand),
                onPressed: () => _navigateToPlace(place),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentPlaceCard(RecentPlace place) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: RtSpacing.base, vertical: RtSpacing.xs),
      child: RtCard(
        onTap: () => _selectRecentPlace(place),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(RtSpacing.sm),
              decoration: BoxDecoration(
                color: RtColors.neutral100,
                shape: BoxShape.circle,
              ),
              child: Icon(place.icon, color: RtColors.neutral500, size: RtIconSize.sm),
            ),
            const SizedBox(width: RtSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.address,
                    style: RtTypo.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _formatDate(place.date),
                    style: RtTypo.bodySmall.copyWith(color: RtColors.neutral400),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: RtColors.brand),
              onPressed: () => _showEditDialog(
                FavoritePlace(
                  id: '',
                  name: 'Nuevo Favorito',
                  address: place.address,
                  icon: place.icon,
                  color: RtColors.info,
                  location: const LatLng(0, 0),
                  visitCount: 0,
                  lastVisit: DateTime.now(),
                ),
                isNew: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Pantalla de mapa con favoritos
// ============================================================

class FavoritesMapScreen extends StatefulWidget {
  final List<FavoritePlace> favorites;

  const FavoritesMapScreen({super.key, required this.favorites});

  @override
  State<FavoritesMapScreen> createState() => _FavoritesMapScreenState();
}

class _FavoritesMapScreenState extends State<FavoritesMapScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _createMarkers();
  }

  void _createMarkers() {
    for (final place in widget.favorites) {
      _markers.add(
        Marker(
          markerId: MarkerId(place.id),
          position: place.location,
          infoWindow: InfoWindow(title: place.name, snippet: place.address),
          icon: BitmapDescriptor.defaultMarkerWithHue(_getMarkerHue(place.color)),
        ),
      );
    }
  }

  double _getMarkerHue(Color color) {
    if (color == RtColors.info) return BitmapDescriptor.hueBlue;
    if (color == RtColors.warning) return BitmapDescriptor.hueOrange;
    if (color == RtColors.success) return BitmapDescriptor.hueGreen;
    if (color == RtColors.accentPurple) return BitmapDescriptor.hueViolet;
    return BitmapDescriptor.hueRed;
  }

  void _fitAllMarkers() {
    if (_markers.isEmpty) return;

    double minLat = _markers.first.position.latitude;
    double maxLat = _markers.first.position.latitude;
    double minLng = _markers.first.position.longitude;
    double maxLng = _markers.first.position.longitude;

    for (final marker in _markers) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: RtAppBar(
        title: AppLocalizations.of(context)!.favoritesMapTitle,
        variant: RtAppBarVariant.gradient,
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: widget.favorites.isNotEmpty
              ? widget.favorites.first.location
              : const LatLng(-12.0464, -77.0428),
          zoom: 13,
        ),
        onMapCreated: (controller) {
          _mapController = controller;
          if (_markers.isNotEmpty) _fitAllMarkers();
        },
        markers: _markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      ),
    );
  }
}
