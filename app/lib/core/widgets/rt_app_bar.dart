import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/rt_colors.dart';
import '../design/rt_gradients.dart';
import '../design/rt_typography.dart';

/// Variantes visuales del AppBar
enum RtAppBarVariant {
  /// Sin fondo, texto adaptivo según el tema
  transparent,

  /// Fondo surface del tema con texto normal
  solid,

  /// Gradiente brand con texto e iconos blancos
  gradient,
}

/// AppBar reutilizable del design system RapiTeam.
/// Implementa PreferredSizeWidget para uso directo en Scaffold.appBar.
class RtAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final Widget? leading;
  final List<Widget>? actions;
  final RtAppBarVariant variant;
  final bool showBackButton;
  final bool centerTitle;
  final PreferredSizeWidget? bottom;

  const RtAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.actions,
    this.variant = RtAppBarVariant.solid,
    this.showBackButton = true,
    this.centerTitle = true,
    this.bottom,
  });

  @override
  Size get preferredSize {
    final double bottomHeight = bottom?.preferredSize.height ?? 0;
    return Size.fromHeight(kToolbarHeight + bottomHeight);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool canPop = Navigator.of(context).canPop();
    final bool shouldShowBack = showBackButton && canPop && leading == null;

    switch (variant) {
      case RtAppBarVariant.gradient:
        return _buildGradientAppBar(context, shouldShowBack);

      case RtAppBarVariant.solid:
        return _buildSolidAppBar(context, isDark, shouldShowBack);

      case RtAppBarVariant.transparent:
        return _buildTransparentAppBar(context, isDark, shouldShowBack);
    }
  }

  /// AppBar con gradiente brand, texto e iconos blancos
  Widget _buildGradientAppBar(BuildContext context, bool shouldShowBack) {
    return Container(
      decoration: const BoxDecoration(gradient: RtGradients.brand),
      child: AppBar(
        title: _buildTitle(RtColors.white),
        leading: _buildLeading(context, shouldShowBack, RtColors.white),
        actions: actions,
        centerTitle: centerTitle,
        bottom: bottom,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: RtColors.white,
        iconTheme: const IconThemeData(color: RtColors.white),
        actionsIconTheme: const IconThemeData(color: RtColors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
    );
  }

  /// AppBar solido con fondo surface del tema
  Widget _buildSolidAppBar(
    BuildContext context,
    bool isDark,
    bool shouldShowBack,
  ) {
    final Color foreground = isDark ? RtColors.white : RtColors.neutral900;

    return AppBar(
      title: _buildTitle(foreground),
      leading: _buildLeading(context, shouldShowBack, foreground),
      actions: actions,
      centerTitle: centerTitle,
      bottom: bottom,
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 0,
      scrolledUnderElevation: 1,
      foregroundColor: foreground,
      iconTheme: IconThemeData(color: foreground),
      actionsIconTheme: IconThemeData(color: foreground),
      systemOverlayStyle:
          isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );
  }

  /// AppBar transparente con texto adaptivo
  Widget _buildTransparentAppBar(
    BuildContext context,
    bool isDark,
    bool shouldShowBack,
  ) {
    final Color foreground = isDark ? RtColors.white : RtColors.neutral900;

    return AppBar(
      title: _buildTitle(foreground),
      leading: _buildLeading(context, shouldShowBack, foreground),
      actions: actions,
      centerTitle: centerTitle,
      bottom: bottom,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: foreground,
      iconTheme: IconThemeData(color: foreground),
      actionsIconTheme: IconThemeData(color: foreground),
      systemOverlayStyle:
          isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );
  }

  /// Construye el widget de titulo (prioriza titleWidget sobre title)
  Widget? _buildTitle(Color color) {
    if (titleWidget != null) return titleWidget;
    if (title == null) return null;

    return Text(
      title!,
      style: RtTypo.headingSmall.copyWith(color: color),
    );
  }

  /// Construye el leading (boton de retroceso o widget personalizado)
  Widget? _buildLeading(
    BuildContext context,
    bool shouldShowBack,
    Color color,
  ) {
    if (leading != null) return leading;
    if (!shouldShowBack) return null;

    return IconButton(
      icon: Icon(Icons.arrow_back_ios_new_rounded, color: color, size: 20),
      onPressed: () => Navigator.of(context).pop(),
    );
  }
}
