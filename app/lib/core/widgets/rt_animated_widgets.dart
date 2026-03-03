import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../design/design_system.dart';

// Boton animado con efecto de pulsacion
class AnimatedPulseButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final bool isLoading;

  const AnimatedPulseButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.color,
    this.isLoading = false,
  });

  @override
  State<AnimatedPulseButton> createState() => _AnimatedPulseButtonState();
}

class _AnimatedPulseButtonState extends State<AnimatedPulseButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Solo animar si el boton esta habilitado
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AnimatedPulseButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Actualizar animacion cuando cambie el estado del boton
    if (widget.onPressed != null && !widget.isLoading) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determinar si el boton esta habilitado
    final isEnabled = widget.onPressed != null && !widget.isLoading;

    return GestureDetector(
      onTap: widget.isLoading ? null : () {
        if (widget.onPressed != null) {
          widget.onPressed!();
        }
      },
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.color ?? RtColors.brand,
                (widget.color ?? RtColors.brand)
                    .withValues(alpha: 0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: (widget.color ?? RtColors.brand)
                    .withValues(alpha: 0.3),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: widget.isLoading
              ? Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.onPrimary,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(
                        widget.icon,
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        widget.text,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// Tarjeta animada con efecto de elevacion
class AnimatedElevatedCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final double borderRadius;

  const AnimatedElevatedCard({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.borderRadius = 20,
  });

  @override
  State<AnimatedElevatedCard> createState() => _AnimatedElevatedCardState();
}

class _AnimatedElevatedCardState extends State<AnimatedElevatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _elevationAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _elevationAnimation = Tween<double>(
      begin: 0,
      end: 10,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
        if (widget.onTap != null) widget.onTap!();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _elevationAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _isPressed ? 0.98 : 1.0,
            child: Container(
              decoration: BoxDecoration(
                color: widget.color ?? Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                    blurRadius: 10 + _elevationAnimation.value,
                    offset: Offset(0, 5 + _elevationAnimation.value / 2),
                    spreadRadius: _elevationAnimation.value / 5,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                child: widget.child,
              ),
            ),
          );
        },
      ),
    );
  }
}

// Indicador de carga animado
class ModernLoadingIndicator extends StatefulWidget {
  final double size;
  final Color? color;

  const ModernLoadingIndicator({
    super.key,
    this.size = 50,
    this.color,
  });

  @override
  State<ModernLoadingIndicator> createState() => _ModernLoadingIndicatorState();
}

class _ModernLoadingIndicatorState extends State<ModernLoadingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));

    _scaleController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_rotationController, _scaleAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotationController.value * 2 * math.pi,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    widget.color ?? RtColors.brand,
                    (widget.color ?? RtColors.brand).withValues(alpha: 0.3),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(widget.size * 0.15),
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.onPrimary,
                  strokeWidth: 3,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Boton flotante animado con opciones expandibles
class AnimatedFloatingActionMenu extends StatefulWidget {
  final List<FloatingMenuItem> items;
  final IconData mainIcon;
  final Color? color;

  const AnimatedFloatingActionMenu({
    super.key,
    required this.items,
    this.mainIcon = Icons.add,
    this.color,
  });

  @override
  State<AnimatedFloatingActionMenu> createState() =>
      _AnimatedFloatingActionMenuState();
}

class _AnimatedFloatingActionMenuState
    extends State<AnimatedFloatingActionMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        ...widget.items.asMap().entries.map((entry) {
          int index = entry.key;
          FloatingMenuItem item = entry.value;

          return AnimatedBuilder(
            animation: _expandAnimation,
            builder: (context, child) {
              double offset = (index + 1) * 70.0 * _expandAnimation.value;
              return Transform.translate(
                offset: Offset(0, -offset),
                child: Opacity(
                  opacity: _expandAnimation.value,
                  child: Transform.scale(
                    scale: _expandAnimation.value,
                    child: FloatingActionButton(
                      mini: true,
                      backgroundColor: item.color ?? RtColors.info,
                      onPressed: _isExpanded ? item.onPressed : null,
                      child: Icon(item.icon, color: Theme.of(context).colorScheme.onPrimary),
                    ),
                  ),
                ),
              );
            },
          );
        }),
        FloatingActionButton(
          backgroundColor: widget.color ?? RtColors.brand,
          onPressed: _toggle,
          child: AnimatedBuilder(
            animation: _expandAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _expandAnimation.value * math.pi / 4,
                child: Icon(
                  widget.mainIcon,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class FloatingMenuItem {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;

  FloatingMenuItem({
    required this.icon,
    required this.onPressed,
    this.color,
  });
}

// Slider animado para selección de precio
class PriceNegotiationSlider extends StatefulWidget {
  final double minPrice;
  final double maxPrice;
  final double suggestedPrice;
  final Function(double) onPriceChanged;

  const PriceNegotiationSlider({
    super.key,
    required this.minPrice,
    required this.maxPrice,
    required this.suggestedPrice,
    required this.onPriceChanged,
  });

  @override
  State<PriceNegotiationSlider> createState() =>
      _PriceNegotiationSliderState();
}

class _PriceNegotiationSliderState extends State<PriceNegotiationSlider>
    with SingleTickerProviderStateMixin {
  late double _currentPrice;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _currentPrice = widget.suggestedPrice;

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: RtGradients.brand,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: RtShadow.soft(),
                ),
                child: Text(
                  'S/. ${_currentPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: RtColors.brand,
            inactiveTrackColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            trackHeight: 6,
            thumbColor: RtColors.brand,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            overlayColor: RtColors.brand.withValues(alpha: 0.2),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
          ),
          child: Slider(
            value: _currentPrice,
            min: widget.minPrice,
            max: widget.maxPrice,
            onChanged: (value) {
              setState(() {
                _currentPrice = value;
              });
              widget.onPriceChanged(value);
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'S/. ${widget.minPrice.toStringAsFixed(2)}',
              style: const TextStyle(
                color: RtColors.neutral500,
                fontSize: 12,
              ),
            ),
            Text(
              'Precio sugerido: S/. ${widget.suggestedPrice.toStringAsFixed(2)}',
              style: const TextStyle(
                color: RtColors.success,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'S/. ${widget.maxPrice.toStringAsFixed(2)}',
              style: const TextStyle(
                color: RtColors.neutral500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
