import 'package:flutter/material.dart';
import '../../core/design/design_system.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_card.dart';

/// Pantalla del Centro de Ayuda con tabs para FAQ, Contacto y Guias
class HelpCenterScreen extends StatefulWidget {
  final String? userType;

  const HelpCenterScreen({super.key, this.userType});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, String>> _faqs = [
    {
      'question': 'Cómo solicitar un viaje?',
      'answer':
          'Ingresa tu destino, selecciona el tipo de vehículo y confirma tu solicitud.',
    },
    {
      'question': 'Cómo cancelar un viaje?',
      'answer':
          'Puedes cancelar desde la pantalla de seguimiento antes de que llegue el conductor.',
    },
    {
      'question': 'Qué métodos de pago acepta?',
      'answer':
          'Aceptamos efectivo, tarjetas de débito/crédito y billeteras digitales.',
    },
    {
      'question': 'Cómo calificar a un conductor?',
      'answer':
          'Al finalizar el viaje aparecerá automáticamente la pantalla de calificación.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: RtAppBar(
        title: 'Centro de Ayuda',
        showBackButton: true,
        variant: RtAppBarVariant.solid,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'FAQ'),
            Tab(text: 'Contacto'),
            Tab(text: 'Guias'),
          ],
          labelColor: RtColors.brand,
          unselectedLabelColor:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          indicatorColor: RtColors.brand,
          labelStyle: RtTypo.labelLarge,
          unselectedLabelStyle: RtTypo.labelMedium,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFAQTab(),
          _buildContactOptions(),
          _buildGuides(),
        ],
      ),
    );
  }

  /// Tab de preguntas frecuentes con buscador
  Widget _buildFAQTab() {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(child: _buildFAQList()),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: RtSpacing.paddingBase,
      color: Theme.of(context).colorScheme.surface,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar en preguntas frecuentes...',
          hintStyle: RtTypo.bodyMedium.copyWith(color: RtColors.neutral400),
          prefixIcon: const Icon(Icons.search, color: RtColors.neutral400),
          border: OutlineInputBorder(
            borderRadius: RtRadius.borderMd,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: RtRadius.borderMd,
            borderSide: const BorderSide(color: RtColors.brand),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: RtRadius.borderMd,
            borderSide: const BorderSide(color: RtColors.neutral200),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: RtSpacing.base,
            vertical: RtSpacing.md,
          ),
        ),
        onChanged: (value) => setState(() {}),
      ),
    );
  }

  Widget _buildFAQList() {
    final filteredFAQs = _faqs.where((faq) {
      final searchTerm = _searchController.text.toLowerCase();
      return faq['question']!.toLowerCase().contains(searchTerm) ||
          faq['answer']!.toLowerCase().contains(searchTerm);
    }).toList();

    if (filteredFAQs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: RtColors.neutral400),
            const SizedBox(height: RtSpacing.base),
            Text(
              'No se encontraron resultados',
              style: RtTypo.bodyLarge.copyWith(color: RtColors.neutral500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: RtSpacing.paddingBase,
      itemCount: filteredFAQs.length,
      itemBuilder: (context, index) {
        final faq = filteredFAQs[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: RtSpacing.sm),
          child: RtCard(
            variant: RtCardVariant.outlined,
            padding: EdgeInsets.zero,
            child: ExpansionTile(
              title: Text(
                faq['question']!,
                style: RtTypo.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              iconColor: RtColors.brand,
              collapsedIconColor: RtColors.neutral400,
              shape: const Border(),
              collapsedShape: const Border(),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    RtSpacing.base,
                    0,
                    RtSpacing.base,
                    RtSpacing.base,
                  ),
                  child: Text(
                    faq['answer']!,
                    style: RtTypo.bodyMedium.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContactOptions() {
    return ListView(
      padding: RtSpacing.paddingBase,
      children: [
        _buildContactCard(
          'Chat en Vivo',
          'Respuesta inmediata',
          Icons.chat,
          RtColors.brand,
          () {},
        ),
        _buildContactCard(
          'Email',
          'soporte@rapiteam.app',
          Icons.email,
          RtColors.info,
          () {},
        ),
        _buildContactCard(
          'Teléfono',
          '+51 1 234-5678',
          Icons.phone,
          RtColors.warning,
          () {},
        ),
        _buildContactCard(
          'WhatsApp',
          'Mensaje directo',
          Icons.message,
          RtColors.success,
          () {},
        ),
      ],
    );
  }

  Widget _buildContactCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: RtSpacing.md),
      child: RtCard(
        variant: RtCardVariant.elevated,
        onTap: onTap,
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color, size: RtIconSize.sm),
            ),
            const SizedBox(width: RtSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: RtTypo.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: RtTypo.bodySmall.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: RtIconSize.xs,
              color: RtColors.neutral400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuides() {
    final guides = [
      {'title': 'Cómo solicitar tu primer viaje', 'icon': Icons.play_circle},
      {'title': 'Configurar métodos de pago', 'icon': Icons.payment},
      {'title': 'Usar promociones y descuentos', 'icon': Icons.local_offer},
      {'title': 'Compartir tu ubicación', 'icon': Icons.location_on},
    ];

    return ListView.builder(
      padding: RtSpacing.paddingBase,
      itemCount: guides.length,
      itemBuilder: (context, index) {
        final guide = guides[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: RtSpacing.sm),
          child: RtCard(
            variant: RtCardVariant.elevated,
            onTap: () {
              // Abrir guia
            },
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: RtColors.brand.withValues(alpha: 0.1),
                    borderRadius: RtRadius.borderSm,
                  ),
                  child: Icon(
                    guide['icon'] as IconData,
                    color: RtColors.brand,
                    size: RtIconSize.sm,
                  ),
                ),
                const SizedBox(width: RtSpacing.md),
                Expanded(
                  child: Text(
                    guide['title'] as String,
                    style: RtTypo.titleMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: RtIconSize.xs,
                  color: RtColors.neutral400,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
