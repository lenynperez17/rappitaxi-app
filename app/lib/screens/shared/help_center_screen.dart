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

  // Ronda 269: las guías eran cuatro títulos con `onTap: () {}` — flecha de
  // "entrar" incluida y nada detrás. La ronda 249 arregló las tarjetas de
  // contacto de arriba por este mismo motivo, pero esta lista se quedó fuera.
  //
  // Ahora cada guía tiene su texto y se abre en una hoja inferior. El contenido
  // describe la app tal y como funciona hoy: la guía de "compartir ubicación"
  // se sustituyó por el cambio de modo pasajero/conductor, porque compartir el
  // viaje en vivo todavía no está implementado y no tiene sentido documentar
  // algo que el usuario no va a encontrar.
  static const List<Map<String, Object>> _guides = [
    {
      'title': 'Cómo solicitar tu primer viaje',
      'icon': Icons.play_circle,
      'body': '1. En la pantalla principal, tu ubicación ya aparece como punto '
          'de recogida.\n\n'
          '2. Elige el servicio: Express, Ejecutivo o VIP.\n\n'
          '3. Pulsa "¿A dónde y por cuánto?" y escribe tu destino. '
          'Toca siempre una sugerencia de la lista: si solo escribes el texto, '
          'el destino no queda marcado en el mapa.\n\n'
          '4. Propón cuánto quieres pagar. La app sugiere una tarifa y te '
          'muestra el mínimo y el máximo.\n\n'
          '5. Pulsa "Encontrar ofertas" y espera. Los conductores cercanos '
          'pueden aceptar tu precio o proponerte otro.',
    },
    {
      'title': 'Configurar métodos de pago',
      'icon': Icons.payment,
      'body': 'Puedes pagar de dos formas distintas:\n\n'
          'Directo al conductor — efectivo, Yape o Plin. Le pagas a él al '
          'terminar el viaje, igual que en un taxi de calle.\n\n'
          'Con tu saldo — el importe se descuenta automáticamente de tu '
          'billetera al finalizar. Necesitas saldo suficiente antes de pedir el '
          'viaje; puedes recargar con tarjeta desde Métodos de pago.\n\n'
          'El método se elige en la misma pantalla donde propones tu tarifa, '
          'antes de buscar conductor.',
    },
    {
      'title': 'Usar promociones y descuentos',
      'icon': Icons.local_offer,
      'body': 'Si tienes un código promocional, introdúcelo en la pantalla '
          'donde propones tu tarifa: verás la línea "¿Tienes un código '
          'promocional? Úsalo aquí".\n\n'
          'El descuento se aplica sobre el importe final del viaje. Cada código '
          'tiene un número máximo de usos y una fecha de caducidad.',
    },
    {
      'title': 'Cambiar entre pasajero y conductor',
      'icon': Icons.swap_horiz,
      'body': 'Si tu cuenta está habilitada como conductor, abre el menú '
          'lateral (las tres líneas de arriba a la izquierda) y pulsa '
          '"Modo Conductor".\n\n'
          'Para volver a pasajero, en el menú del modo conductor pulsa '
          '"Modo pasajero".\n\n'
          'Si todavía no eres conductor, ese mismo botón te lleva al alta: '
          'tendrás que subir tu DNI, licencia, SOAT y la tarjeta de propiedad '
          'del vehículo. Hasta que los aprueben no podrás recibir viajes.',
    },
  ];

  void _openGuide(Map<String, Object> guide) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.getSurface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.getTextSecondary(sheetContext).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(guide['icon'] as IconData, color: AppColors.rappiOrange),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      guide['title'] as String,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getTextPrimary(sheetContext),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                guide['body'] as String,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: AppColors.getTextPrimary(sheetContext),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuides() {
    return ListView.builder(
      padding: const EdgeInsets.all(16), itemCount: _guides.length,
      itemBuilder: (context, index) {
        final guide = _guides[index];
        return Card(
          color: AppColors.getSurface(context), margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(guide['icon'] as IconData, color: AppColors.rappiOrange),
            title: Text(guide['title'] as String, style: TextStyle(color: AppColors.getTextPrimary(context))),
            trailing: Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.getTextSecondary(context)),
            onTap: () => _openGuide(guide),
          ),
        );
      },
    );
  }
}
