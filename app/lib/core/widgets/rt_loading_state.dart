import 'package:flutter/material.dart';

import '../design/rt_colors.dart';
import '../design/rt_tokens.dart';

/// Widget de estado de carga con efecto shimmer real (gradiente deslizante).
///
/// Modos de uso:
///   - Constructor por defecto: CircularProgressIndicator centrado.
///   - [RtLoadingState.shimmer]: aplica efecto shimmer a un [child] personalizado.
///   - [RtLoadingState.list]: skeleton de lista (3-5 items con lineas de texto).
///   - [RtLoadingState.card]: skeleton de una card con titulo y lineas.
///   - [RtLoadingState.profile]: skeleton de perfil (circulo + lineas).
///   - [RtLoadingState.stats]: skeleton de grid de stats cards.
///
/// El shimmer se implementa con [AnimationController] + [LinearGradient],
/// sin dependencias externas. Los colores se adaptan al tema (light/dark)
/// usando tokens de [RtColors].
class RtLoadingState extends StatefulWidget {
  /// Tipo de preset de shimmer a mostrar
  final _ShimmerPreset _preset;

  /// Widget hijo personalizado (solo para [_ShimmerPreset.custom])
  final Widget? child;

  /// Cantidad de items en el preset de lista
  final int itemCount;

  /// Cantidad de columnas en el preset de stats
  final int statsColumns;

  /// Constructor por defecto: muestra un CircularProgressIndicator centrado
  const RtLoadingState({
    super.key,
  })  : _preset = _ShimmerPreset.none,
        child = null,
        itemCount = 3,
        statsColumns = 2;

  /// Constructor shimmer generico: aplica efecto shimmer al [child]
  const RtLoadingState.shimmer({
    super.key,
    required this.child,
  })  : _preset = _ShimmerPreset.custom,
        itemCount = 3,
        statsColumns = 2;

  /// Skeleton de lista con [itemCount] items simulando texto
  const RtLoadingState.list({
    super.key,
    this.itemCount = 4,
  })  : _preset = _ShimmerPreset.list,
        child = null,
        statsColumns = 2;

  /// Skeleton de una card con rectangulo superior y lineas de texto
  const RtLoadingState.card({
    super.key,
  })  : _preset = _ShimmerPreset.card,
        child = null,
        itemCount = 3,
        statsColumns = 2;

  /// Skeleton de perfil: circulo (avatar) + lineas de texto
  const RtLoadingState.profile({
    super.key,
  })  : _preset = _ShimmerPreset.profile,
        child = null,
        itemCount = 3,
        statsColumns = 2;

  /// Skeleton de stats: grid de [statsColumns] columnas con cards rectangulares
  const RtLoadingState.stats({
    super.key,
    this.statsColumns = 2,
  })  : _preset = _ShimmerPreset.stats,
        child = null,
        itemCount = 3;

  @override
  State<RtLoadingState> createState() => _RtLoadingStateState();
}

/// Tipos internos de preset
enum _ShimmerPreset { none, custom, list, card, profile, stats }

class _RtLoadingStateState extends State<RtLoadingState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Solo animar si se muestra shimmer
    if (widget._preset != _ShimmerPreset.none) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Modo simple: indicador circular centrado
    if (widget._preset == _ShimmerPreset.none) {
      return const Center(
        child: CircularProgressIndicator(color: RtColors.brand),
      );
    }

    // Construir el contenido según el preset
    final Widget content = switch (widget._preset) {
      _ShimmerPreset.custom => widget.child ?? const SizedBox.shrink(),
      _ShimmerPreset.list => _buildListPreset(context),
      _ShimmerPreset.card => _buildCardPreset(context),
      _ShimmerPreset.profile => _buildProfilePreset(context),
      _ShimmerPreset.stats => _buildStatsPreset(context),
      _ShimmerPreset.none => const SizedBox.shrink(),
    };

    return _ShimmerEffect(
      controller: _controller,
      child: content,
    );
  }

  /// Preset lista: items con lineas simulando texto
  Widget _buildListPreset(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.itemCount, (index) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: index < widget.itemCount - 1 ? RtSpacing.md : 0,
          ),
          child: _ShimmerListItem(),
        );
      }),
    );
  }

  /// Preset card: rectangulo superior + lineas de texto
  Widget _buildCardPreset(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: RtRadius.borderMd,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rectangulo superior simulando imagen
          const _ShimmerBox(height: 160, width: double.infinity),
          Padding(
            padding: const EdgeInsets.all(RtSpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titulo
                const _ShimmerBox(height: 18, width: 200),
                const SizedBox(height: RtSpacing.sm),
                // Subtitulo
                const _ShimmerBox(height: 14, width: 260),
                const SizedBox(height: RtSpacing.xs),
                // Linea corta
                const _ShimmerBox(height: 14, width: 140),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Preset perfil: circulo (avatar) + lineas de texto
  Widget _buildProfilePreset(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar circular
        const _ShimmerBox(
          height: 64,
          width: 64,
          shape: BoxShape.circle,
        ),
        const SizedBox(width: RtSpacing.md),
        // Información del perfil
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: RtSpacing.xs),
              // Nombre
              const _ShimmerBox(height: 18, width: 160),
              const SizedBox(height: RtSpacing.sm),
              // Email o subtitulo
              const _ShimmerBox(height: 14, width: 200),
              const SizedBox(height: RtSpacing.xs),
              // Detalle adicional
              const _ShimmerBox(height: 14, width: 120),
            ],
          ),
        ),
      ],
    );
  }

  /// Preset stats: grid de cards rectangulares
  Widget _buildStatsPreset(BuildContext context) {
    return Wrap(
      spacing: RtSpacing.md,
      runSpacing: RtSpacing.md,
      children: List.generate(4, (index) {
        return SizedBox(
          width: (MediaQuery.sizeOf(context).width -
                  RtSpacing.xl * 2 -
                  RtSpacing.md * (widget.statsColumns - 1)) /
              widget.statsColumns,
          child: Container(
            padding: const EdgeInsets.all(RtSpacing.base),
            decoration: BoxDecoration(
              borderRadius: RtRadius.borderMd,
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icono o indicador
                _ShimmerBox(height: 32, width: 32),
                SizedBox(height: RtSpacing.sm),
                // Valor numerico
                _ShimmerBox(height: 22, width: 80),
                SizedBox(height: RtSpacing.xs),
                // Etiqueta
                _ShimmerBox(height: 12, width: 60),
              ],
            ),
          ),
        );
      }),
    );
  }
}

/// Caja individual del skeleton con forma y dimensiones configurables
class _ShimmerBox extends StatelessWidget {
  final double height;
  final double? width;
  final BoxShape shape;

  const _ShimmerBox({
    required this.height,
    this.width,
    this.shape = BoxShape.rectangle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? RtColors.neutral800 : RtColors.neutral200;

    return Container(
      height: height,
      width: shape == BoxShape.circle ? height : width,
      decoration: BoxDecoration(
        color: baseColor,
        shape: shape,
        borderRadius: shape == BoxShape.rectangle ? RtRadius.borderSm : null,
      ),
    );
  }
}

/// Item individual del preset de lista: rectangulo + lineas de texto
class _ShimmerListItem extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Icono/thumbnail cuadrado
        const _ShimmerBox(height: 48, width: 48),
        const SizedBox(width: RtSpacing.md),
        // Lineas de texto
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _ShimmerBox(height: 14, width: 180),
              SizedBox(height: RtSpacing.sm),
              _ShimmerBox(height: 12, width: 120),
            ],
          ),
        ),
      ],
    );
  }
}

/// Widget que aplica el efecto shimmer real (gradiente deslizante) a su hijo.
/// Usa [ShaderMask] con un [LinearGradient] que se desplaza horizontalmente
/// mediante el [AnimationController].
class _ShimmerEffect extends StatelessWidget {
  final AnimationController controller;
  final Widget child;

  const _ShimmerEffect({
    required this.controller,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Colores del shimmer adaptados al tema
    // Light: gris claro (neutral200) a blanco (neutral50)
    // Dark: gris oscuro (neutral800) a gris medio (neutral600)
    final baseColor = isDark ? RtColors.neutral800 : RtColors.neutral200;
    final highlightColor = isDark ? RtColors.neutral600 : RtColors.neutral50;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final double slide = controller.value * 2 - 0.5;
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: [
                (slide - 0.3).clamp(0.0, 1.0),
                slide.clamp(0.0, 1.0),
                (slide + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: child!,
        );
      },
      child: child,
    );
  }
}
