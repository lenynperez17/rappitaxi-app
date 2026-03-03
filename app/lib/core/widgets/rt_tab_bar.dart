import 'package:flutter/material.dart';

import '../design/rt_colors.dart';
import '../design/rt_typography.dart';

/// TabBar estilizado del design system RapiTeam.
/// Envuelve el TabBar nativo de Flutter con los estilos de marca:
/// indicador brand, tipografia Inter y borde inferior sutil.
class RtTabBar extends StatelessWidget {
  final List<String> tabs;
  final TabController? controller;
  final bool isScrollable;
  final ValueChanged<int>? onTap;

  const RtTabBar({
    super.key,
    required this.tabs,
    this.controller,
    this.isScrollable = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? RtColors.neutral700 : RtColors.neutral200,
          ),
        ),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: isScrollable,
        onTap: onTap,
        tabs: tabs.map((label) => Tab(text: label)).toList(),
        labelStyle: RtTypo.labelLarge.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: RtTypo.labelLarge,
        labelColor: RtColors.brand,
        unselectedLabelColor: RtColors.neutral500,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: UnderlineTabIndicator(
          borderSide: const BorderSide(color: RtColors.brand, width: 3),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
        ),
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(RtColors.transparent),
        dividerColor: RtColors.transparent,
        tabAlignment: isScrollable ? TabAlignment.start : null,
      ),
    );
  }
}
