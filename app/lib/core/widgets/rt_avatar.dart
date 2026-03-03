import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../design/rt_colors.dart';
import '../design/rt_typography.dart';

/// Tamanos predefinidos para RtAvatar
enum RtAvatarSize {
  small(32),
  medium(44),
  large(64),
  xlarge(80);

  final double dimension;
  const RtAvatarSize(this.dimension);
}

/// Avatar reutilizable del design system RapiTeam.
/// Muestra imagen de red, iniciales del nombre o icono por defecto.
/// Soporta badge de estado posicionado abajo-derecha.
class RtAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final IconData? icon;
  final RtAvatarSize size;
  final Color? badgeColor;
  final VoidCallback? onTap;

  const RtAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.icon,
    this.size = RtAvatarSize.medium,
    this.badgeColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    Widget avatar = SizedBox(
      width: size.dimension,
      height: size.dimension,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _buildAvatarCircle(isDark),
          if (badgeColor != null) _buildBadge(isDark),
        ],
      ),
    );

    if (onTap == null) return avatar;

    return GestureDetector(
      onTap: onTap,
      child: avatar,
    );
  }

  /// Construye el circulo principal del avatar
  Widget _buildAvatarCircle(bool isDark) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return _buildImageAvatar();
    }

    if (name != null && name!.isNotEmpty) {
      return _buildInitialsAvatar(isDark);
    }

    return _buildIconAvatar(isDark);
  }

  /// Avatar con imagen de red usando CachedNetworkImage
  Widget _buildImageAvatar() {
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: size.dimension,
        height: size.dimension,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildPlaceholderCircle(),
        errorWidget: (context, url, error) => _buildIconAvatar(false),
      ),
    );
  }

  /// Placeholder mientras carga la imagen
  Widget _buildPlaceholderCircle() {
    return Container(
      width: size.dimension,
      height: size.dimension,
      decoration: const BoxDecoration(
        color: RtColors.neutral200,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: SizedBox(
          width: size.dimension * 0.4,
          height: size.dimension * 0.4,
          child: const CircularProgressIndicator(
            strokeWidth: 2,
            color: RtColors.neutral400,
          ),
        ),
      ),
    );
  }

  /// Avatar con iniciales del nombre sobre fondo brand suave
  Widget _buildInitialsAvatar(bool isDark) {
    final String initials = _extractInitials(name!);
    final double fontSize = _initialsFontSize;

    return Container(
      width: size.dimension,
      height: size.dimension,
      decoration: BoxDecoration(
        color: isDark
            ? RtColors.brand.withValues(alpha: 0.2)
            : RtColors.brandSurface,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: RtTypo.labelLarge.copyWith(
          fontSize: fontSize,
          color: isDark ? RtColors.brandLight : RtColors.brand,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Avatar con icono por defecto (persona)
  Widget _buildIconAvatar(bool isDark) {
    return Container(
      width: size.dimension,
      height: size.dimension,
      decoration: BoxDecoration(
        color: isDark ? RtColors.neutral700 : RtColors.neutral200,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        icon ?? Icons.person_rounded,
        size: size.dimension * 0.5,
        color: isDark ? RtColors.neutral400 : RtColors.neutral500,
      ),
    );
  }

  /// Badge de estado: circulo pequeno posicionado abajo-derecha
  Widget _buildBadge(bool isDark) {
    const double badgeSize = 12.0;
    const double borderWidth = 2.0;

    return Positioned(
      right: 0,
      bottom: 0,
      child: Container(
        width: badgeSize,
        height: badgeSize,
        decoration: BoxDecoration(
          color: badgeColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? RtColors.neutral900 : RtColors.white,
            width: borderWidth,
          ),
        ),
      ),
    );
  }

  /// Extrae las primeras 2 iniciales del nombre
  String _extractInitials(String fullName) {
    final List<String> parts =
        fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();

    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts[0][0].toUpperCase();

    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  /// Tamano de fuente de las iniciales según el tamano del avatar
  double get _initialsFontSize {
    switch (size) {
      case RtAvatarSize.small:
        return 11;
      case RtAvatarSize.medium:
        return 14;
      case RtAvatarSize.large:
        return 20;
      case RtAvatarSize.xlarge:
        return 26;
    }
  }
}
