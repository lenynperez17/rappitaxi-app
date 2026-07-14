// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/animated/modern_animated_widgets.dart';

class RatingDialog extends StatefulWidget {
  final String driverName;
  final String driverPhoto;
  final String tripId;
  final bool isDriverRating;
  final Function(int rating, String? comment, List<String> tags)? onSubmit;

  const RatingDialog({super.key, required this.driverName, required this.driverPhoto, required this.tripId, this.isDriverRating = false, this.onSubmit});

  static Future<void> show({required BuildContext context, required String driverName, required String driverPhoto, required String tripId, bool isDriverRating = false, Function(int rating, String? comment, List<String> tags)? onSubmit}) {
    return showDialog(context: context, barrierDismissible: false, builder: (context) => RatingDialog(driverName: driverName, driverPhoto: driverPhoto, tripId: tripId, isDriverRating: isDriverRating, onSubmit: onSubmit));
  }

  @override
  _RatingDialogState createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> with TickerProviderStateMixin {
  int _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  late AnimationController _dialogController;
  late AnimationController _starsController;
  late AnimationController _submitController;
  late List<AnimationController> _starControllers;

  Map<int, List<String>> get _ratingTags => widget.isDriverRating ? {
    5: ['Pasajero amable', 'Puntual', 'Respetuoso', 'Buena ubicacion', 'Excelente trato'],
    4: ['Buen pasajero', 'Educado', 'Pago correcto', 'Sin problemas'],
    3: ['Regular', 'Podria mejorar', 'Aceptable'],
    2: ['Impuntual', 'Ubicacion incorrecta', 'Grosero', 'Problematico'],
    1: ['Pesimo pasajero', 'Agresivo', 'No se presento', 'Experiencia terrible'],
  } : {
    5: ['Excelente servicio', 'Conductor amable', 'Vehiculo limpio', 'Ruta eficiente', 'Muy puntual'],
    4: ['Buen servicio', 'Conductor profesional', 'Viaje comodo', 'Precio justo'],
    3: ['Servicio regular', 'Podria mejorar', 'Aceptable'],
    2: ['Mal servicio', 'Conductor imprudente', 'Vehiculo sucio', 'Ruta incorrecta'],
    1: ['Pesimo servicio', 'Conductor grosero', 'Vehiculo en mal estado', 'Experiencia terrible'],
  };

  final List<String> _selectedTags = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _dialogController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _starsController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _submitController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _starControllers = List.generate(5, (index) => AnimationController(duration: const Duration(milliseconds: 200), vsync: this));
    _dialogController.forward();
    // Guard mounted — sin esto, si el user cierra el diálogo antes de 300ms,
    // el controller queda disposed y forward() lanza excepción.
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _starsController.forward();
    });
  }

  @override
  void dispose() {
    _dialogController.dispose(); _starsController.dispose(); _submitController.dispose();
    for (var controller in _starControllers) { controller.dispose(); }
    _commentController.dispose(); super.dispose();
  }

  void _setRating(int rating) {
    setState(() { _rating = rating; _selectedTags.clear(); });
    for (int i = 0; i < rating; i++) { _starControllers[i].forward().then((_) { _starControllers[i].reverse(); }); }
    _starsController.forward().then((_) { _starsController.reverse(); });
  }

  void _toggleTag(String tag) { setState(() { if (_selectedTags.contains(tag)) { _selectedTags.remove(tag); } else { _selectedTags.add(tag); } }); }

  Future<void> _submitRating() async {
    if (_rating == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Por favor selecciona una calificacion'), backgroundColor: AppColors.error));
      return;
    }
    setState(() => _isSubmitting = true);
    _submitController.forward();
    await Future.delayed(const Duration(seconds: 2));
    if (widget.onSubmit != null) { widget.onSubmit!(_rating, _commentController.text.trim().isEmpty ? null : _commentController.text.trim(), _selectedTags); }
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 12), Text('Gracias por tu calificacion!')]),
        backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              elevation: 24, insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 380),
                child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
                    Container(height: 80, decoration: const BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.vertical(top: Radius.circular(28)))),
                    Positioned(top: 8, right: 8, child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 18)),
                    )),
                    Positioned(top: 30, child: Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))]),
                      child: CircleAvatar(radius: 40, backgroundColor: AppColors.rappiOrange.withValues(alpha: 0.1),
                        backgroundImage: widget.driverPhoto.isNotEmpty ? NetworkImage(widget.driverPhoto) : null,
                        child: widget.driverPhoto.isEmpty ? const Icon(Icons.person, size: 40, color: AppColors.rappiOrange) : null),
                    )),
                  ]),
                  const SizedBox(height: 50),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(widget.driverName, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context)))),
                  const SizedBox(height: 4),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Column(children: [
                    Text(widget.isDriverRating ? 'Como fue tu pasajero?' : 'Como fue tu conductor?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.getTextPrimary(context))),
                    const SizedBox(height: 4),
                    Text(widget.isDriverRating ? 'Califica a tu pasajero' : 'Califica a tu conductor', style: TextStyle(fontSize: 13, color: AppColors.getTextSecondary(context))),
                    const SizedBox(height: 20),
                    _buildAnimatedStars(),
                    if (_rating > 0) ...[
                      const SizedBox(height: 16),
                      AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: Text(_getRatingMessage(), key: ValueKey(_rating), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _getRatingColor()))),
                      const SizedBox(height: 16),
                      _buildTagsSection(),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _commentController, maxLines: 2, style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(hintText: 'Cuentanos mas...', hintStyle: TextStyle(fontSize: 13, color: AppColors.getTextSecondary(context)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.getBorder(context))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.rappiOrange, width: 2)),
                          filled: true, fillColor: AppColors.getInputFill(context)),
                      ),
                      const SizedBox(height: 20),
                      AnimatedBuilder(animation: _submitController, builder: (context, child) {
                        return Transform.scale(scale: 1 - (0.1 * _submitController.value), child: AnimatedPulseButton(text: _isSubmitting ? 'Enviando...' : 'Enviar Calificacion', icon: _isSubmitting ? null : Icons.send, onPressed: _isSubmitting ? () {} : _submitRating));
                      }),
                    ],
                    if (_rating == 0) ...[
                      const SizedBox(height: 16),
                      TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Calificar despues', style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 14))),
                    ],
                    const SizedBox(height: 8),
                  ])),
                ])),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedStars() {
    return AnimatedBuilder(animation: _starsController, builder: (context, child) {
      return Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (index) {
        final delay = index * 0.1;
        final animation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _starsController, curve: Interval(delay, delay + 0.5, curve: Curves.elasticOut)));
        return AnimatedBuilder(animation: animation, builder: (context, child) {
          return Transform.scale(scale: animation.value, child: AnimatedBuilder(animation: _starControllers[index], builder: (context, child) {
            return Transform.scale(scale: 1 + (0.3 * _starControllers[index].value), child: GestureDetector(
              onTap: () => _setRating(index + 1),
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Icon(index < _rating ? Icons.star_rounded : Icons.star_outline_rounded, size: 44, color: index < _rating ? Colors.amber : AppColors.getBorder(context))),
            ));
          }));
        });
      }));
    });
  }

  Widget _buildTagsSection() {
    final tags = _ratingTags[_rating] ?? [];
    return AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: Column(key: ValueKey(_rating), crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_rating >= 4 ? 'Que te gusto?' : 'Que podria mejorar?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
      const SizedBox(height: 10),
      Wrap(spacing: 6, runSpacing: 6, children: tags.map((tag) {
        final isSelected = _selectedTags.contains(tag);
        return GestureDetector(onTap: () => _toggleTag(tag), child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.rappiOrange.withValues(alpha: 0.1) : AppColors.getInputFill(context),
            border: Border.all(color: isSelected ? AppColors.rappiOrange : AppColors.getBorder(context), width: isSelected ? 1.5 : 1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (isSelected) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.check, size: 14, color: AppColors.rappiOrange)),
            Text(tag, style: TextStyle(fontSize: 12, color: isSelected ? AppColors.rappiOrange : AppColors.getTextSecondary(context), fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
          ]),
        ));
      }).toList()),
    ]));
  }

  String _getRatingMessage() {
    switch (_rating) { case 5: return 'Excelente! 🌟'; case 4: return 'Muy bueno! 👍'; case 3: return 'Regular 😐'; case 2: return 'Malo 👎'; case 1: return 'Muy malo 😞'; default: return ''; }
  }

  Color _getRatingColor() {
    switch (_rating) { case 5: return AppColors.success; case 4: return AppColors.rappiOrange; case 3: return AppColors.warning; case 2: return Colors.orange; case 1: return AppColors.error; default: return AppColors.getTextPrimary(context); }
  }
}

class PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.1)..style = PaintingStyle.stroke..strokeWidth = 1;
    for (double i = -size.height; i < size.width + size.height; i += 20) { canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), paint); }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
