import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';

class NegotiationTimerWidget extends StatefulWidget {
  final DateTime expiresAt;
  final VoidCallback? onExpired;
  final VoidCallback? onWarning;
  final int warningSeconds;

  const NegotiationTimerWidget({
    super.key,
    required this.expiresAt,
    this.onExpired,
    this.onWarning,
    this.warningSeconds = 30,
  });

  @override
  State<NegotiationTimerWidget> createState() => _NegotiationTimerWidgetState();
}

class _NegotiationTimerWidgetState extends State<NegotiationTimerWidget>
    with TickerProviderStateMixin {
  Timer? _timer;
  Duration _remainingTime = Duration.zero;
  bool _hasWarned = false;
  
  late AnimationController _pulseController;
  late AnimationController _progressController;
  
  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _startTimer();
    _calculateProgress();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _updateRemainingTime();
    
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemainingTime();
      _calculateProgress();
      
      if (_remainingTime.inSeconds <= 0) {
        _timer?.cancel();
        widget.onExpired?.call();
      } else if (_remainingTime.inSeconds <= widget.warningSeconds && !_hasWarned) {
        _hasWarned = true;
        widget.onWarning?.call();
        _pulseController.repeat(reverse: true);
      }
    });
  }

  void _updateRemainingTime() {
    final now = DateTime.now();
    final difference = widget.expiresAt.difference(now);
    
    setState(() {
      _remainingTime = difference.isNegative ? Duration.zero : difference;
    });
  }

  void _calculateProgress() {
    // Asumimos que la duración inicial de la negociación es de 5 minutos (300 segundos)
    const totalDuration = 300;
    final elapsed = totalDuration - _remainingTime.inSeconds;
    final progress = elapsed / totalDuration;
    
    _progressController.animateTo(progress.clamp(0.0, 1.0));
  }

  String _formatTime(Duration duration) {
    if (duration.inSeconds <= 0) return '00:00';
    
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Color _getTimerColor() {
    if (_remainingTime.inSeconds <= 10) {
      return AppColors.error;
    } else if (_remainingTime.inSeconds <= widget.warningSeconds) {
      return Colors.orange;
    } else {
      return AppColors.rappiOrange;
    }
  }

  IconData _getTimerIcon() {
    if (_remainingTime.inSeconds <= 10) {
      return Icons.timer_off;
    } else if (_remainingTime.inSeconds <= widget.warningSeconds) {
      return Icons.warning;
    } else {
      return Icons.access_time;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timerColor = _getTimerColor();
    final isWarning = _remainingTime.inSeconds <= widget.warningSeconds;
    final isCritical = _remainingTime.inSeconds <= 10;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: timerColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: timerColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Título
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: isWarning 
                        ? 1.0 + (_pulseController.value * 0.1)
                        : 1.0,
                    child: Icon(
                      _getTimerIcon(),
                      color: timerColor,
                      size: 24,
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              Text(
                isCritical
                    ? '¡TIEMPO AGOTÁNDOSE!'
                    : isWarning
                        ? 'Tiempo restante limitado'
                        : 'Tiempo restante',
                style: TextStyle(
                  fontSize: isCritical ? 16 : 14,
                  fontWeight: isCritical ? FontWeight.bold : FontWeight.w600,
                  color: timerColor,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Timer principal
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: timerColor.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: isCritical 
                      ? 1.0 + (_pulseController.value * 0.05)
                      : 1.0,
                  child: Text(
                    _formatTime(_remainingTime),
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: timerColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Barra de progreso
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: AnimatedBuilder(
              animation: _progressController,
              builder: (context, child) {
                return FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _progressController.value,
                  child: Container(
                    decoration: BoxDecoration(
                      color: timerColor,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: timerColor.withOpacity(0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Mensaje de estado
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildStatusMessage(isCritical, isWarning),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusMessage(bool isCritical, bool isWarning) {
    if (isCritical) {
      return Text(
        '⚡ ¡Acepta una oferta antes de que expire!',
        key: const ValueKey('critical'),
        style: TextStyle(
          fontSize: 12,
          color: AppColors.error,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ).animate(onPlay: (controller) => controller.repeat()).shimmer(
        duration: const Duration(milliseconds: 1000),
        color: Colors.white.withOpacity(0.5),
      );
    } else if (isWarning) {
      return Text(
        'Considera extender el tiempo si necesitas más ofertas',
        key: const ValueKey('warning'),
        style: TextStyle(
          fontSize: 12,
          color: Colors.orange[700],
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      );
    } else {
      return Text(
        'Los conductores están enviando sus ofertas',
        key: const ValueKey('normal'),
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
        textAlign: TextAlign.center,
      );
    }
  }
}