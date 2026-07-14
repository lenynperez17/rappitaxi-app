import 'package:flutter/material.dart';

/// Responsive context extension for quick access to device metrics.
/// Uses optimized MediaQuery static methods (Flutter 3.x) to avoid
/// unnecessary rebuilds — sizeOf/viewInsetsOf/paddingOf only trigger
/// rebuilds when their specific property changes.
extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;
  double get keyboardHeight => MediaQuery.viewInsetsOf(this).bottom;
  bool get isKeyboardOpen => keyboardHeight > 0;
  double get bottomSafeArea => MediaQuery.paddingOf(this).bottom;
  double get topSafeArea => MediaQuery.paddingOf(this).top;

  /// Bottom padding accounting for navigation bar with minimum fallback.
  /// On devices with gesture nav (~34dp), 3-button nav (~48dp), or
  /// home indicator (iOS ~34dp), returns the actual safe area.
  /// On devices with no bottom inset, returns 16dp minimum.
  double get bottomPadding => bottomSafeArea > 0 ? bottomSafeArea : 16.0;
}
