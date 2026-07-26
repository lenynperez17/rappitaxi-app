import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            // Ronda 249: el velo era `onSurface@0.5`, que en modo oscuro es
            // BLANCO — velo blanco luminoso, y el mensaje (onPrimary, también
            // blanco) quedaba invisible encima. Un overlay debe ser oscuro
            // siempre, independiente del tema.
            color: AppColors.overlay,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  if (message != null) ...[
                    SizedBox(height: 16),
                    Text(
                      message!,
                      style: const TextStyle(
                        // Blanco fijo: el velo siempre es oscuro.
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}