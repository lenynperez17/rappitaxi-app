import 'package:flutter/material.dart';

class AnimatedCounterWidget extends StatelessWidget {
  final int value;
  final Duration duration;
  final TextStyle? textStyle;
  final String? prefix;
  final String? suffix;

  const AnimatedCounterWidget({
    super.key,
    required this.value,
    this.duration = const Duration(milliseconds: 800),
    this.textStyle,
    this.prefix,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return Text(
          '${prefix ?? ''}$animatedValue${suffix ?? ''}',
          style: textStyle ?? Theme.of(context).textTheme.displayMedium,
        );
      },
    );
  }
}