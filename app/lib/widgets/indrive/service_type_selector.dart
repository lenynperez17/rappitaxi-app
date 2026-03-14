import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';
import '../../screens/passenger/modern_passenger_home.dart';

/// Horizontal scroll selector for service types (inDrive style).
/// Shows vehicle images prominently with labels below.
class ServiceTypeSelector extends StatelessWidget {
  final ServiceType selectedType;
  final ValueChanged<ServiceType> onTypeSelected;

  const ServiceTypeSelector({
    super.key,
    required this.selectedType,
    required this.onTypeSelected,
  });

  static const _services = [
    _ServiceDef(ServiceType.viaje, Icons.local_taxi, 'Viaje', 'assets/images/vehicles/sedan.png'),
    _ServiceDef(ServiceType.mototaxi, Icons.two_wheeler, 'Mototaxi', 'assets/images/vehicles/mototaxi.png'),
    _ServiceDef(ServiceType.entregas, Icons.inventory_2, 'Entregas', 'assets/images/vehicles/van_entregas.png'),
    _ServiceDef(ServiceType.ciudadACiudad, Icons.route, 'Ciudad a Ciudad', 'assets/images/vehicles/suv_interurbano.png'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _services.length,
        itemBuilder: (context, index) {
          final svc = _services[index];
          return _ServiceChip(
            type: svc.type,
            icon: svc.icon,
            label: svc.label,
            assetPath: svc.assetPath,
            isSelected: selectedType == svc.type,
            onTap: () => onTypeSelected(svc.type),
          ).animate().fadeIn(delay: Duration(milliseconds: 60 * index)).slideX(begin: 0.08);
        },
      ),
    );
  }
}

class _ServiceDef {
  final ServiceType type;
  final IconData icon;
  final String label;
  final String assetPath;

  const _ServiceDef(this.type, this.icon, this.label, this.assetPath);
}

class _ServiceChip extends StatelessWidget {
  final ServiceType type;
  final IconData icon;
  final String label;
  final String assetPath;
  final bool isSelected;
  final VoidCallback onTap;

  const _ServiceChip({
    required this.type,
    required this.icon,
    required this.label,
    required this.assetPath,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 88,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.ctaGreen.withValues(alpha: 0.12)
              : AppColors.getInputFill(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.ctaGreen : AppColors.getBorder(context),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Vehicle image - larger and more prominent
            SizedBox(
              width: 52,
              height: 52,
              child: Image.asset(
                assetPath,
                errorBuilder: (_, __, ___) => Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.ctaGreen.withValues(alpha: 0.15)
                        : AppColors.getInputFill(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: isSelected ? AppColors.rappiOrange : AppColors.getTextSecondary(context),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.priceBlack : AppColors.getTextPrimary(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
