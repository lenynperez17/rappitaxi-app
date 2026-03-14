import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';
import '../../screens/passenger/modern_passenger_home.dart';
import 'service_type_selector.dart';

/// Main home bottom section widget (inDrive style).
/// Contains address fields, service selector, favorites, and recent places.
class HomeBottomSection extends StatelessWidget {
  final Widget addressFieldsWidget;
  final ServiceType selectedServiceType;
  final ValueChanged<ServiceType> onServiceTypeChanged;
  final bool isSelectingLocation;
  final bool showContinueButton;
  final bool isKeyboardOpen;
  final Widget findDriverButton;
  final Map<String, Map<String, dynamic>?> userFavorites;
  final List<Map<String, dynamic>> recentPlaces;
  final bool loadingPlaces;
  final void Function(String favoriteKey) onFavoriteTap;
  final void Function(String address, String subtitle, {double? lat, double? lng}) onRecentPlaceTap;
  final VoidCallback onAddFavoriteTap;

  const HomeBottomSection({
    super.key,
    required this.addressFieldsWidget,
    required this.selectedServiceType,
    required this.onServiceTypeChanged,
    required this.isSelectingLocation,
    required this.showContinueButton,
    required this.isKeyboardOpen,
    required this.findDriverButton,
    required this.userFavorites,
    required this.recentPlaces,
    required this.loadingPlaces,
    required this.onFavoriteTap,
    required this.onRecentPlaceTap,
    required this.onAddFavoriteTap,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: isSelectingLocation ? 0.40 : 0.55,
      minChildSize: 0.30,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const [0.30, 0.55, 0.85],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.getSurface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              // Drag handle
              SliverToBoxAdapter(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.getBorder(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              // Address fields
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: addressFieldsWidget,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              // Service type selector
              if (!isSelectingLocation)
                SliverToBoxAdapter(
                  child: ServiceTypeSelector(
                    selectedType: selectedServiceType,
                    onTypeSelected: onServiceTypeChanged,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              // Find driver button
              if (showContinueButton && !isKeyboardOpen)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: findDriverButton,
                  ),
                ),
              // Favorites + recents
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isSelectingLocation) ...[
                      _FavoritePlaces(
                        favorites: userFavorites,
                        onFavoriteTap: onFavoriteTap,
                        onAddTap: onAddFavoriteTap,
                      ),
                      const Divider(height: 1),
                      _RecentPlaces(
                        places: recentPlaces,
                        loading: loadingPlaces,
                        onPlaceTap: onRecentPlaceTap,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FavoritePlaces extends StatelessWidget {
  final Map<String, Map<String, dynamic>?> favorites;
  final void Function(String key) onFavoriteTap;
  final VoidCallback onAddTap;

  const _FavoritePlaces({required this.favorites, required this.onFavoriteTap, required this.onAddTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lugares favoritos',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _FavoriteIcon(
                icon: Icons.home,
                label: 'Casa',
                data: favorites['home'],
                onTap: () => onFavoriteTap('home'),
              ),
              _FavoriteIcon(
                icon: Icons.work,
                label: 'Trabajo',
                data: favorites['work'],
                onTap: () => onFavoriteTap('work'),
              ),
              _FavoriteIcon(
                icon: Icons.school,
                label: 'Universidad',
                data: favorites['university'],
                onTap: () => onFavoriteTap('university'),
              ),
              _FavoriteIcon(
                icon: Icons.add,
                label: 'Agregar',
                onTap: onAddTap,
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1);
  }
}

class _FavoriteIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final Map<String, dynamic>? data;
  final VoidCallback onTap;

  const _FavoriteIcon({required this.icon, required this.label, this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasFavorite = data != null && data!['address'] != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasFavorite
                    ? AppColors.rappiOrange.withValues(alpha: 0.1)
                    : AppColors.getInputFill(context),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: hasFavorite ? AppColors.rappiOrange : AppColors.getTextSecondary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFavorite ? _truncate(data!['address'] as String) : label,
              style: TextStyle(
                fontSize: 12,
                color: hasFavorite ? AppColors.getTextPrimary(context) : AppColors.getTextSecondary(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String _truncate(String text) => text.length <= 10 ? text : '${text.substring(0, 8)}...';
}

class _RecentPlaces extends StatelessWidget {
  final List<Map<String, dynamic>> places;
  final bool loading;
  final void Function(String address, String subtitle, {double? lat, double? lng}) onPlaceTap;

  const _RecentPlaces({required this.places, required this.loading, required this.onPlaceTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recientes',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: 12),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          else if (places.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Aun no tienes viajes recientes',
                style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 14),
              ),
            )
          else
            ...places.map((place) => _RecentPlaceItem(
                  address: place['address'] as String,
                  subtitle: place['subtitle'] as String,
                  lat: place['lat'] as double?,
                  lng: place['lng'] as double?,
                  onTap: onPlaceTap,
                )),
        ],
      ),
    );
  }
}

class _RecentPlaceItem extends StatelessWidget {
  final String address;
  final String subtitle;
  final double? lat;
  final double? lng;
  final void Function(String address, String subtitle, {double? lat, double? lng}) onTap;

  const _RecentPlaceItem({
    required this.address,
    required this.subtitle,
    this.lat,
    this.lng,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(address, subtitle, lat: lat, lng: lng),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.rappiOrange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.history_rounded, color: AppColors.rappiOrange, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    address,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.getTextPrimary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context)),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.getTextSecondary(context)),
          ],
        ),
      ),
    );
  }
}
