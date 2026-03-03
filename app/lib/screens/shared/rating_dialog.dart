import 'package:flutter/material.dart';
import '../../core/design/design_system.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../core/widgets/rt_animated_widgets.dart';

class RatingDialog extends StatefulWidget {
  final String driverName;
  final String driverPhoto;
  final String tripId;
  final Function(int rating, String? comment, List<String> tags)? onSubmit;

  const RatingDialog({
    super.key,
    required this.driverName,
    required this.driverPhoto,
    required this.tripId,
    this.onSubmit,
  });

  static Future<void> show({
    required BuildContext context,
    required String driverName,
    required String driverPhoto,
    required String tripId,
    Function(int rating, String? comment, List<String> tags)? onSubmit,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RatingDialog(
        driverName: driverName,
        driverPhoto: driverPhoto,
        tripId: tripId,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog>
    with TickerProviderStateMixin {
  int _rating = 0;
  final TextEditingController _commentController = TextEditingController();

  // Animaciones
  late AnimationController _dialogController;
  late AnimationController _starsController;
  late AnimationController _submitController;
  late List<AnimationController> _starControllers;

  // Tags predefinidos según la calificación
  final Map<int, List<String>> _ratingTags = {
    5: ['Excelente servicio', 'Conductor amable', 'Vehículo limpio', 'Ruta eficiente', 'Muy puntual'],
    4: ['Buen servicio', 'Conductor profesional', 'Viaje comodo', 'Precio justo'],
    3: ['Servicio regular', 'Podria mejorar', 'Aceptable'],
    2: ['Servicio deficiente', 'Conductor imprudente', 'Vehículo sucio', 'Ruta incorrecta'],
    1: ['Muy mal servicio', 'Conductor grosero', 'Vehículo en mal estado', 'Experiencia terrible'],
  };

  final List<String> _selectedTags = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    _dialogController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _starsController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _submitController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Crear controladores individuales para cada estrella
    _starControllers = List.generate(
      5,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 200),
        vsync: this,
      ),
    );

    // Iniciar animaciones
    _dialogController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _starsController.forward();
    });
  }

  @override
  void dispose() {
    _dialogController.dispose();
    _starsController.dispose();
    _submitController.dispose();
    for (var controller in _starControllers) {
      controller.dispose();
    }
    _commentController.dispose();
    super.dispose();
  }

  void _setRating(int rating) {
    setState(() {
      _rating = rating;
      _selectedTags.clear();
    });

    // Animar las estrellas seleccionadas
    for (int i = 0; i < rating; i++) {
      _starControllers[i].forward().then((_) {
        _starControllers[i].reverse();
      });
    }

    // Vibracion haptica (simulada con animacion)
    _starsController.forward().then((_) {
      _starsController.reverse();
    });
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  void _submitRating() async {
    if (_rating == 0) {
      if (!mounted) return;
      RtSnackbar.show(context, message: 'Por favor, selecciona una calificación', type: RtSnackbarType.error);
      return;
    }

    setState(() => _isSubmitting = true);

    _submitController.forward();

    // Simular envio
    await Future.delayed(const Duration(seconds: 2));

    if (widget.onSubmit != null) {
      widget.onSubmit!(
        _rating,
        _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
        _selectedTags,
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop();

    // Mostrar mensaje de agradecimiento
    if (!mounted) return;
    RtSnackbar.show(context, message: 'Gracias por tu calificación!', type: RtSnackbarType.success);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _dialogController,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * _dialogController.value),
          child: Opacity(
            opacity: _dialogController.value,
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 24,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header con foto del conductor
                      Container(
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: RtGradients.brand,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Patron de fondo
                            Positioned.fill(
                              child: CustomPaint(
                                painter: PatternPainter(),
                              ),
                            ),
                            // Info del conductor
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 35,
                                  backgroundColor: Theme.of(context).colorScheme.surface,
                                  child: CircleAvatar(
                                    radius: 32,
                                    backgroundImage: NetworkImage(widget.driverPhoto),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.driverName,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                            // Boton de cerrar
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7)),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // Titulo
                            Text(
                              'Cómo fue tu viaje?',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tu opinion nos ayuda a mejorar',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Estrellas animadas
                            _buildAnimatedStars(),

                            if (_rating > 0) ...[
                              const SizedBox(height: 20),

                              // Mensaje según calificación
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: Text(
                                  _getRatingMessage(),
                                  key: ValueKey(_rating),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: _getRatingColor(),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Tags sugeridos
                              _buildTagsSection(),

                              const SizedBox(height: 20),

                              // Campo de comentario
                              TextField(
                                controller: _commentController,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  hintText: 'Cuéntanos más sobre tu experiencia (opcional)',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.18)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: RtColors.brand,
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: Theme.of(context).colorScheme.surface,
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Boton de enviar
                              AnimatedBuilder(
                                animation: _submitController,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: 1 - (0.1 * _submitController.value),
                                    child: AnimatedPulseButton(
                                      text: _isSubmitting ? 'Enviando...' : 'Enviar calificación',
                                      icon: _isSubmitting ? null : Icons.send,
                                      onPressed: _isSubmitting ? () {} : _submitRating,
                                      color: RtColors.brand,
                                    ),
                                  );
                                },
                              ),
                            ],

                            if (_rating == 0) ...[
                              const SizedBox(height: 24),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(
                                  'Calificar más tarde',
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedStars() {
    return AnimatedBuilder(
      animation: _starsController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final delay = index * 0.1;
            final animation = Tween<double>(
              begin: 0,
              end: 1,
            ).animate(
              CurvedAnimation(
                parent: _starsController,
                curve: Interval(
                  delay,
                  delay + 0.5,
                  curve: Curves.elasticOut,
                ),
              ),
            );

            return AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                return Transform.scale(
                  scale: animation.value,
                  child: AnimatedBuilder(
                    animation: _starControllers[index],
                    builder: (context, child) {
                      final starScale = 1 + (0.3 * _starControllers[index].value);

                      return Transform.scale(
                        scale: starScale,
                        child: IconButton(
                          onPressed: () => _setRating(index + 1),
                          icon: Icon(
                            index < _rating ? Icons.star : Icons.star_border,
                            size: 40,
                            color: index < _rating
                              ? RtColors.warning
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          }),
        );
      },
    );
  }

  Widget _buildTagsSection() {
    final tags = _ratingTags[_rating] ?? [];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Column(
        key: ValueKey(_rating),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _rating >= 4 ? 'Qué te gustó?' : 'Qué podría mejorar?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags.map((tag) {
              final isSelected = _selectedTags.contains(tag);

              return InkWell(
                onTap: () => _toggleTag(tag),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                      ? RtColors.brand.withValues(alpha: 0.1)
                      : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                        ? RtColors.brand
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.18),
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected)
                        const Icon(
                          Icons.check,
                          size: 16,
                          color: RtColors.brand,
                        ),
                      if (isSelected) const SizedBox(width: 4),
                      Text(
                        tag,
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected
                            ? RtColors.brand
                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _getRatingMessage() {
    switch (_rating) {
      case 5:
        return 'Excelente!';
      case 4:
        return 'Muy bien!';
      case 3:
        return 'Regular';
      case 2:
        return 'Malo';
      case 1:
        return 'Muy malo';
      default:
        return '';
    }
  }

  Color _getRatingColor() {
    switch (_rating) {
      case 5:
        return RtColors.success;
      case 4:
        return RtColors.brand;
      case 3:
        return RtColors.warning;
      case 2:
        return RtColors.warning;
      case 1:
        return RtColors.error;
      default:
        return Theme.of(context).colorScheme.onSurface;
    }
  }
}

// Painter para el patron de fondo
class PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = RtColors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Dibujar patron de lineas diagonales
    for (double i = -size.height; i < size.width + size.height; i += 20) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
