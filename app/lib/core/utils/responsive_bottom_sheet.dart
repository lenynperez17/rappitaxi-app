import 'package:flutter/material.dart';

/// Shows a responsive modal bottom sheet that automatically handles:
/// - Keyboard avoidance (viewInsets.bottom padding)
/// - Navigation bar clearance (padding.bottom for gesture/button nav)
/// - Max height constraint (90% of screen by default)
/// - Consistent rounded corners and drag handle
/// - isScrollControlled: true (always, for proper keyboard behavior)
/// - useSafeArea: true (always)
Future<T?> showResponsiveBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
  Color? backgroundColor,
  double maxHeightFraction = 0.9,
  bool showDragHandle = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ResponsiveSheetWrapper(
      maxHeightFraction: maxHeightFraction,
      showDragHandle: showDragHandle,
      backgroundColor: backgroundColor,
      builder: builder,
    ),
  );
}

class _ResponsiveSheetWrapper extends StatelessWidget {
  final double maxHeightFraction;
  final bool showDragHandle;
  final Color? backgroundColor;
  final WidgetBuilder builder;

  const _ResponsiveSheetWrapper({
    required this.maxHeightFraction,
    required this.showDragHandle,
    required this.builder,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * maxHeightFraction;
    final surfaceColor =
        backgroundColor ?? Theme.of(context).colorScheme.surface;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showDragHandle)
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              Flexible(child: builder(context)),
              SizedBox(height: bottomPadding),
            ],
          ),
        ),
      ),
    );
  }
}
