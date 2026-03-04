import 'package:flutter/material.dart';

/// Widget seguro para mostrar imágenes de red
/// Si la URL está vacía o hay error, muestra un ícono placeholder
class SafeNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  
  const SafeNetworkImage({
    super.key,
    required this.imageUrl,
    this.width = 50,
    this.height = 50,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    // Si no hay URL o está vacía, mostrar placeholder
    if (imageUrl == null || imageUrl!.isEmpty || !imageUrl!.startsWith('http')) {
      return _buildPlaceholder(context);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(width / 2),
      child: Image.network(
        imageUrl!,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorWidget(context);
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoadingWidget(context);
        },
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return placeholder ?? Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person,
        size: width * 0.6,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context) {
    return errorWidget ?? Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person,
        size: width * 0.6,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      ),
    );
  }

  Widget _buildLoadingWidget(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).primaryColor,
          ),
        ),
      ),
    );
  }
}

/// Versión circular para avatares
class SafeCircleAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Widget? child;
  final Color? backgroundColor;
  
  const SafeCircleAvatar({
    super.key,
    this.imageUrl,
    this.radius = 20,
    this.child,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    // Si no hay URL o está vacía, mostrar ícono por defecto
    if (imageUrl == null || imageUrl!.isEmpty || !imageUrl!.startsWith('http')) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.surfaceContainerHighest,
        child: child ?? Icon(
          Icons.person,
          size: radius * 1.2,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      );
    }

    // Intentar cargar la imagen
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.surfaceContainerHighest,
      backgroundImage: NetworkImage(imageUrl!),
      onBackgroundImageError: (exception, stackTrace) {
        // El error se maneja mostrando el child o ícono por defecto
      },
      child: child,
    );
  }
}