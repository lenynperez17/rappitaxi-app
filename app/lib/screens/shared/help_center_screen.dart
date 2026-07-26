// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/common/rappi_app_bar.dart';
import 'support_screen.dart';

class HelpCenterScreen extends StatefulWidget {
  final String? userType;
  const HelpCenterScreen({super.key, this.userType});
  @override
  _HelpCenterScreenState createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> with SingleTickerProviderStateMixin {
  int _selectedTab = 0;
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  final List<Map<String, String>> _faqs = [
    {'question': 'Como solicitar un viaje?', 'answer': 'Ingresa tu destino, selecciona el tipo de vehiculo y confirma tu solicitud.'},
    {'question': 'Como cancelar un viaje?', 'answer': 'Puedes cancelar desde la pantalla de seguimiento antes de que llegue el conductor.'},
    {'question': 'Que metodos de pago acepta?', 'answer': 'Aceptamos efectivo, tarjetas de debito/credito y billeteras digitales.'},
    {'question': 'Como calificar a un conductor?', 'answer': 'Al finalizar el viaje aparecera automaticamente la pantalla de calificacion.'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() { setState(() { _selectedTab = _tabController.index; }); });
  }

  @override
  void dispose() { _searchController.dispose(); _tabController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getInputFill(context),
      appBar: RappiAppBar(title: 'Centro de Ayuda', showBackButton: true),
      body: Column(children: [
        Container(
          color: AppColors.getSurface(context),
          child: TabBar(
            controller: _tabController,
            tabs: const [Tab(text: 'FAQ'), Tab(text: 'Contacto'), Tab(text: 'Guias')],
            labelColor: AppColors.rappiOrange, unselectedLabelColor: AppColors.getTextSecondary(context), indicatorColor: AppColors.rappiOrange,
          ),
        ),
        if (_selectedTab == 0) _buildSearchBar(),
        Expanded(child: _buildTabContent()),
      ]),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16), color: AppColors.getSurface(context),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: AppColors.getTextPrimary(context)),
        decoration: InputDecoration(
          hintText: 'Buscar en preguntas frecuentes...',
          hintStyle: TextStyle(color: AppColors.getTextSecondary(context)),
          prefixIcon: Icon(Icons.search, color: AppColors.getTextSecondary(context)),
          filled: true, fillColor: AppColors.getInputFill(context),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.getBorder(context))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.getBorder(context))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.rappiOrange)),
        ),
        onChanged: (value) => setState(() {}),
      ),
    );
  }

  Widget _buildTabContent() { switch (_selectedTab) { case 0: return _buildFAQList(); case 1: return _buildContactOptions(); case 2: return _buildGuides(); default: return _buildFAQList(); } }

  Widget _buildFAQList() {
    final filteredFAQs = _faqs.where((faq) { final searchTerm = _searchController.text.toLowerCase(); return faq['question']!.toLowerCase().contains(searchTerm) || faq['answer']!.toLowerCase().contains(searchTerm); }).toList();
    return ListView.builder(
      padding: const EdgeInsets.all(16), itemCount: filteredFAQs.length,
      itemBuilder: (context, index) {
        final faq = filteredFAQs[index];
        return Card(
          color: AppColors.getSurface(context), margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            title: Text(faq['question']!, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
            children: [Padding(padding: const EdgeInsets.all(16), child: Text(faq['answer']!, style: TextStyle(color: AppColors.getTextPrimary(context))))],
          ),
        );
      },
    );
  }

  Widget _buildContactOptions() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      // Ronda 249: las 4 tarjetas tenían `onTap: () {}` — el usuario tocaba y
      // NO PASABA NADA. Además el teléfono '+51 1 234-5678' era inventado y
      // WhatsApp no tiene número configurado, así que se eliminaron en vez de
      // dejar contactos falsos. Queda el email real y el centro de soporte.
      _buildContactCard('Enviar un mensaje', 'Abre el centro de soporte',
          Icons.support_agent, AppColors.rappiOrange, _openSupport),
      _buildContactCard('Correo', _kSupportEmail, Icons.email,
          AppColors.rappiOrange, _sendSupportEmail),
    ]);
  }

  /// Email de soporte oficial (mismo que usa SupportScreen).
  static const String _kSupportEmail = 'facturacion.rapiteam@gmail.com';

  void _openSupport() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const SupportScreen()));
  }

  Future<void> _sendSupportEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: _kSupportEmail,
      query: 'subject=${Uri.encodeComponent('Soporte Rapi Team')}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No se pudo abrir tu app de correo. '
              'Escríbenos a $_kSupportEmail'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildContactCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      color: AppColors.getSurface(context), margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.1), child: Icon(icon, color: color)),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
        subtitle: Text(subtitle, style: TextStyle(color: AppColors.getTextSecondary(context))),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.getTextSecondary(context)),
        onTap: onTap,
      ),
    );
  }

  Widget _buildGuides() {
    final guides = [
      {'title': 'Como solicitar tu primer viaje', 'icon': Icons.play_circle},
      {'title': 'Configurar metodos de pago', 'icon': Icons.payment},
      {'title': 'Usar promociones y descuentos', 'icon': Icons.local_offer},
      {'title': 'Compartir tu ubicacion', 'icon': Icons.location_on},
    ];
    return ListView.builder(
      padding: const EdgeInsets.all(16), itemCount: guides.length,
      itemBuilder: (context, index) {
        final guide = guides[index];
        return Card(
          color: AppColors.getSurface(context), margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(guide['icon'] as IconData, color: AppColors.rappiOrange),
            title: Text(guide['title'] as String, style: TextStyle(color: AppColors.getTextPrimary(context))),
            trailing: Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.getTextSecondary(context)),
            onTap: () {},
          ),
        );
      },
    );
  }
}
