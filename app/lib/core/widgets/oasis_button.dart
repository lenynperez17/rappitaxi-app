import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class OasisButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final Widget? icon;
  final bool isLoading;
  final bool isOutlined;
  final double? width;
  final double? height;
  final EdgeInsets? padding;
  final double borderRadius;

  const OasisButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.icon,
    this.isLoading = false,
    this.isOutlined = false,
    this.width,
    this.height,
    this.padding,
    this.borderRadius = 8.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? 
        (isOutlined ? Colors.transparent : AppTheme.primaryColor);
    final txtColor = textColor ?? 
        (isOutlined ? AppTheme.primaryColor : Colors.white);
    final bColor = borderColor ?? 
        (isOutlined ? AppTheme.primaryColor : Colors.transparent);

    return SizedBox(
      width: width,
      height: height ?? 48,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: txtColor,
          side: BorderSide(color: bColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    icon!,
                    const SizedBox(width: 8),
                  ],
                  Text(text),
                ],
              ),
      ),
    );
  }
}
