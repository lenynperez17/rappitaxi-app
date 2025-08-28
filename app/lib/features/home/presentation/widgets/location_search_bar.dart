import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class LocationSearchBar extends StatelessWidget {
  final String? hintText;
  final String? value;
  final VoidCallback? onTap;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;
  
  const LocationSearchBar({
    super.key,
    this.hintText,
    this.value,
    this.onTap,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            if (prefixIcon != null) ...[
              prefixIcon!,
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                value ?? hintText ?? '',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: value != null
                      ? AppTheme.textColor
                      : AppTheme.textSecondaryColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (suffixIcon != null) ...[
              const SizedBox(width: 12),
              suffixIcon!,
            ],
          ],
        ),
      ),
    );
  }
}