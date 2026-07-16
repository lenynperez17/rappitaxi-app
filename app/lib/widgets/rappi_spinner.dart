import 'package:flutter/material.dart';
import '../core/theme/modern_theme.dart';

/// Loading spinner unificado — usar en lugar de CircularProgressIndicator crudo.
///
/// Antes había 99+ CircularProgressIndicator con 7 fuentes de color y 4
/// sizes distintos (16/20/22/24) sin criterio, mezclando `color:` y
/// `valueColor:` viejos.
///
/// Uso:
///   RappiSpinner()               // 20px, naranja Rappi
///   RappiSpinner(size: 16)       // small
///   RappiSpinner(onDark: true)   // blanco sobre fondos oscuros/botones
///   RappiSpinner.centeredWithLabel('Cargando...')  // helper full-page
class RappiSpinner extends StatelessWidget {
  final double size;
  final bool onDark;
  final double strokeWidth;

  const RappiSpinner({
    super.key,
    this.size = 20,
    this.onDark = false,
    this.strokeWidth = 2.5,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: onDark ? Colors.white : ModernTheme.rappiOrange,
      ),
    );
  }

  /// Loading centrado con label — usar como full-page loading
  static Widget centeredWithLabel(String label) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const RappiSpinner(size: 28),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// Loading row para uso inline dentro de un widget (ej. dentro de un
  /// botón que está deshabilitado durante submit).
  /// Ronda 106: strokeWidth propagable + default proporcional al size=16.
  /// Antes: stroke 2.5 (default de tamaño 20) en spinner de 16px se veía
  /// desproporcionadamente grueso (~31% del radio) e inconsistente con
  /// otros usos manuales de RappiSpinner(size:16, strokeWidth:2.0).
  static Widget row(String label, {bool onDark = false, double strokeWidth = 2.0}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RappiSpinner(size: 16, onDark: onDark, strokeWidth: strokeWidth),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: onDark ? Colors.white : null,
          ),
        ),
      ],
    );
  }
}
