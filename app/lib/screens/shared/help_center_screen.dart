// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/extensions/theme_extensions.dart';

class HelpCenterScreen extends StatefulWidget {
  final String? userType;

  const HelpCenterScreen({super.key, this.userType});

  @override
  _HelpCenterScreenState createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, String>> _faqs = [
    {
      'question': '¿Cómo solicitar un viaje?',
      'answer': 'Ingresa tu destino, selecciona el tipo de vehículo y confirma tu solicitud.',
    },
    {
      'question': '¿Cómo cancelar un viaje?',
      'answer': 'Puedes cancelar desde la pantalla de seguimiento antes de que llegue el conductor.',
    },
    {
      'question': '¿Qué métodos de pago acepta?',
      'answer': 'Aceptamos efectivo, tarjetas de débito/crédito y billeteras digitales.',
    },
    {
      'question': '¿Cómo calificar a un conductor?',
      'answer': 'Al finalizar el viaje aparecerá automáticamente la pantalla de calificación.',
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surfaceColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              pinned: true,
              backgroundColor: ModernTheme.rappiOrange,
              iconTheme: IconThemeData(color: Colors.white),
              title: const Text(
                'Centro de Ayuda',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(_tabController.index == 0 ? 116 : 48),
                child: Container(
                  color: Theme.of(context).colorScheme.surface,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_tabController.index == 0) _buildSearchBar(),
                      TabBar(
                        controller: _tabController,
                        tabs: const [
                          Tab(text: 'FAQ'),
                          Tab(text: 'Contacto'),
                          Tab(text: 'Guias'),
                        ],
                        labelColor: ModernTheme.rappiOrange,
                        unselectedLabelColor: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                        indicatorColor: ModernTheme.rappiOrange,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildFAQList(),
            _buildContactOptions(),
            _buildGuides(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      color: Theme.of(context).colorScheme.surface,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar en preguntas frecuentes...',
          prefixIcon: const Icon(Icons.search),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(
                color: Theme.of(context).dividerColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(
                color: Theme.of(context).dividerColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide:
                const BorderSide(color: ModernTheme.rappiOrange, width: 2),
          ),
          filled: true,
          fillColor: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.4),
        ),
        onChanged: (value) => setState(() {}),
      ),
    );
  }

  // Categorias de FAQs para agrupar preguntas
  final List<Map<String, dynamic>> _faqCategories = [
    {
      'category': 'Viajes',
      'icon': Icons.local_taxi,
      'faqs': [
        {
          'question': '¿Cómo solicitar un viaje?',
          'answer':
              'Ingresa tu destino, selecciona el tipo de vehículo y confirma tu solicitud.',
        },
        {
          'question': '¿Cómo cancelar un viaje?',
          'answer':
              'Puedes cancelar desde la pantalla de seguimiento antes de que llegue el conductor.',
        },
      ],
    },
    {
      'category': 'Pagos',
      'icon': Icons.payment,
      'faqs': [
        {
          'question': '¿Qué métodos de pago acepta?',
          'answer':
              'Aceptamos efectivo, tarjetas de débito/crédito y billeteras digitales.',
        },
      ],
    },
    {
      'category': 'Calificaciones',
      'icon': Icons.star,
      'faqs': [
        {
          'question': '¿Cómo calificar a un conductor?',
          'answer':
              'Al finalizar el viaje aparecerá automáticamente la pantalla de calificación.',
        },
      ],
    },
  ];

  Widget _buildFAQList() {
    final searchTerm = _searchController.text.toLowerCase();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: _faqCategories.map((categoryData) {
        final category = categoryData['category'] as String;
        final icon = categoryData['icon'] as IconData;
        final faqs = categoryData['faqs'] as List<Map<String, String>>;

        // Filtrar por busqueda
        final filteredFaqs = faqs.where((faq) {
          if (searchTerm.isEmpty) return true;
          return faq['question']!.toLowerCase().contains(searchTerm) ||
              faq['answer']!.toLowerCase().contains(searchTerm);
        }).toList();

        if (filteredFaqs.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header de categoría
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon,
                        color: ModernTheme.rappiOrange, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    category.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.secondaryText,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            // FAQs de esta categoria
            ...filteredFaqs.map((faq) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  child: ExpansionTile(
                    tilePadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    collapsedShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    iconColor: ModernTheme.rappiOrange,
                    collapsedIconColor: context.secondaryText,
                    title: Text(
                      faq['question']!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Text(
                          faq['answer']!,
                          style: TextStyle(
                            fontSize: 14,
                            color: context.secondaryText,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildContactOptions() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _buildContactCard(
          'Chat en Vivo',
          'Respuesta inmediata',
          Icons.chat,
          ModernTheme.rappiOrange,
          () {},
        ),
        _buildContactCard(
          'Email',
          'soporte@rapiteam.app',
          Icons.email,
          ModernTheme.info,
          () {},
        ),
        _buildContactCard(
          'Teléfono',
          '+51 1 234-5678',
          Icons.phone,
          ModernTheme.warning,
          () {},
        ),
        _buildContactCard(
          'WhatsApp',
          'Mensaje directo',
          Icons.message,
          ModernTheme.success,
          () {},
        ),
      ],
    );
  }

  Widget _buildContactCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
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
      padding: EdgeInsets.all(16),
      itemCount: guides.length,
      itemBuilder: (context, index) {
        final guide = guides[index];
        return Card(
          margin: EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(guide['icon'] as IconData, color: ModernTheme.rappiOrange),
            title: Text(guide['title'] as String),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Abrir guía
            },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
