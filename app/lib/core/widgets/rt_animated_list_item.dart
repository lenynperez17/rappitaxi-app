import 'package:flutter/material.dart';

import '../design/rt_tokens.dart';

/// Widget que anima su hijo con fade-in y slide-up al aparecer.
/// El delay es progresivo según el indice para crear efecto cascada (staggered).
///
/// Parametros:
/// - [index]: posicion del item en la lista (determina el delay)
/// - [child]: widget hijo que será animado
/// - [duration]: duracion de la animacion (por defecto [RtDuration.normal])
///
/// Ejemplo de uso en un ListView.builder:
/// ```dart
/// RtAnimatedListItem(
///   index: index,
///   child: MyListTile(...),
/// )
/// ```
class RtAnimatedListItem extends StatefulWidget {
  /// Posicion del item en la lista. Determina el delay de entrada.
  final int index;

  /// Widget hijo que será animado con fade + slide-up.
  final Widget child;

  /// Duracion de la animacion. Por defecto [RtDuration.normal] (300ms).
  final Duration duration;

  const RtAnimatedListItem({
    super.key,
    required this.index,
    required this.child,
    this.duration = RtDuration.normal,
  });

  @override
  State<RtAnimatedListItem> createState() => _RtAnimatedListItemState();
}

class _RtAnimatedListItemState extends State<RtAnimatedListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  /// Delay progresivo: 50ms por cada indice en la lista
  static const int _delayPerIndex = 50;

  /// Desplazamiento vertical inicial en pixeles
  static const double _slideOffset = 20.0;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: RtCurve.enter,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, _slideOffset),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: RtCurve.enter,
    ));

    _startWithDelay();
  }

  /// Inicia la animacion tras el delay calculado por indice
  Future<void> _startWithDelay() async {
    final int delay = widget.index * _delayPerIndex;
    await Future<void>.delayed(Duration(milliseconds: delay));
    if (mounted) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: _slideAnimation.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
