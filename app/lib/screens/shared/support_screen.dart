// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../utils/error_messages.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});
  @override
  _SupportScreenState createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  List<SupportTicket> _tickets = [];
  List<FAQ> _faqs = [];
  bool _isLoading = true;
  String _supportPhone = '';
  String _supportWhatsApp = '';
  String _supportEmail = 'facturacion.rapiteam@gmail.com';
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedCategory = 'general';
  String _selectedPriority = 'medium';

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(duration: Duration(milliseconds: 600), vsync: this);
    _slideController = AnimationController(duration: Duration(milliseconds: 800), vsync: this);
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _slideAnimation = CurvedAnimation(parent: _slideController, curve: Curves.easeOut);
    _loadSupportData();
  }

  @override
  void dispose() { _fadeController.dispose(); _slideController.dispose(); _subjectController.dispose(); _descriptionController.dispose(); super.dispose(); }

  void _loadSupportData() async {
    // TODO(node-migration): reemplazar con endpoints /api/config/support,
    // /api/support/tickets y /api/support/faqs cuando existan.
    // Por ahora usamos defaults y una lista vacia de tickets.
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.currentUser == null) { setState(() => _isLoading = false); return; }
      _supportPhone = '';
      _supportWhatsApp = '';
      _supportEmail = 'facturacion.rapiteam@gmail.com';
      if (!mounted) return;
      setState(() {
        _tickets = <SupportTicket>[];
        _faqs = _getDefaultFAQs();
        _isLoading = false;
      });
      _fadeController.forward(); _slideController.forward();
    } catch (e) {
      print(userFriendlyError(e, fallback: 'Error cargando datos de soporte'));
      if (!mounted) return;
      setState(() { _tickets = []; _faqs = _getDefaultFAQs(); _isLoading = false; });
    }
  }

  List<FAQ> _getDefaultFAQs() { return [
    FAQ(id: '1', question: 'Como cambio mi metodo de pago?', answer: 'Ve a tu perfil, selecciona "Metodos de pago" y agrega o modifica tu metodo preferido.', category: 'Pagos', isHelpful: null),
    FAQ(id: '2', question: 'Que hago si mi conductor no llega?', answer: 'Si tu conductor no ha llegado despues de 10 minutos, puedes cancelar el viaje sin cargo y solicitar uno nuevo.', category: 'Viajes', isHelpful: null),
    FAQ(id: '3', question: 'Como reporto un problema?', answer: 'Puedes reportar un problema desde el historial de viajes o contactandonos directamente por chat o email.', category: 'General', isHelpful: null),
    FAQ(id: '4', question: 'Puedo programar un viaje?', answer: 'Si, puedes programar viajes con anticipacion seleccionando la opcion "Programar" al solicitar un viaje.', category: 'Viajes', isHelpful: null),
    FAQ(id: '5', question: 'Como funciona el sistema de calificacion?', answer: 'Despues de cada viaje, puedes calificar a tu conductor del 1 al 5. Las calificaciones ayudan a mantener la calidad del servicio.', category: 'General', isHelpful: null),
  ]; }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(length: 4, child: Scaffold(
      backgroundColor: AppColors.getInputFill(context),
      appBar: AppBar(
        backgroundColor: AppColors.rappiOrange, elevation: 0,
        title: Text('Centro de Soporte', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: TabBar(indicatorColor: Colors.white, labelColor: Colors.white, unselectedLabelColor: Colors.white70, tabs: [
          Tab(icon: Icon(Icons.help_outline), text: 'FAQ'),
          Tab(icon: Icon(Icons.support_agent), text: 'Mis Tickets'),
          Tab(icon: Icon(Icons.add_circle_outline), text: 'Nuevo'),
          Tab(icon: Icon(Icons.contact_support), text: 'Contacto'),
        ]),
      ),
      body: _isLoading ? _buildLoadingState() : _buildTabViews(),
    ));
  }

  Widget _buildLoadingState() { return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.rappiOrange)), SizedBox(height: 16), Text('Cargando información de soporte...', style: TextStyle(color: AppColors.getTextSecondary(context)))])); }

  Widget _buildTabViews() { return AnimatedBuilder(animation: _fadeAnimation, builder: (context, child) { return Opacity(opacity: _fadeAnimation.value, child: TabBarView(children: [_buildFAQsTab(), _buildTicketsTab(), _buildNewTicketTab(), _buildContactTab()])); }); }

  Widget _buildFAQsTab() {
    final categories = _faqs.map((faq) => faq.category).toSet().toList();
    return SingleChildScrollView(child: Column(children: [
      Container(margin: EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.getSurface(context), borderRadius: BorderRadius.circular(12)),
        child: TextField(style: TextStyle(color: AppColors.getTextPrimary(context)), decoration: InputDecoration(hintText: 'Buscar preguntas frecuentes...', hintStyle: TextStyle(color: AppColors.getTextSecondary(context)), prefixIcon: Icon(Icons.search, color: AppColors.getTextSecondary(context)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.getBorder(context))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.getBorder(context))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.rappiOrange))))),
      SizedBox(height: 50, child: ListView.builder(scrollDirection: Axis.horizontal, padding: EdgeInsets.symmetric(horizontal: 16), itemCount: categories.length + 1, itemBuilder: (context, index) { if (index == 0) return _buildCategoryChip('Todas', true); return _buildCategoryChip(categories[index - 1], false); })),
      ListView.builder(shrinkWrap: true, physics: NeverScrollableScrollPhysics(), padding: EdgeInsets.all(16), itemCount: _faqs.length, itemBuilder: (context, index) => _buildFAQCard(_faqs[index])),
    ]));
  }

  Widget _buildCategoryChip(String category, bool isSelected) { return Container(margin: EdgeInsets.only(right: 8), child: FilterChip(label: Text(category), selected: isSelected, onSelected: (selected) {}, backgroundColor: AppColors.getSurface(context), selectedColor: AppColors.rappiOrange.withValues(alpha: 0.2), checkmarkColor: AppColors.rappiOrange, labelStyle: TextStyle(color: isSelected ? AppColors.rappiOrange : AppColors.getTextSecondary(context)))); }

  Widget _buildFAQCard(FAQ faq) {
    return Card(margin: EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(faq.question, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
        subtitle: Container(margin: EdgeInsets.only(top: 4), padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppColors.rappiOrange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text(faq.category, style: TextStyle(fontSize: 10, color: AppColors.rappiOrange))),
        children: [Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(faq.answer, style: TextStyle(color: AppColors.getTextSecondary(context), height: 1.5)), SizedBox(height: 16),
          Row(children: [Text('Te fue util esta respuesta?', style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(context))), Spacer(), IconButton(icon: Icon(Icons.thumb_up_outlined), color: faq.isHelpful == true ? Colors.green : AppColors.getTextSecondary(context), onPressed: () => _markFAQHelpful(faq, true)), IconButton(icon: Icon(Icons.thumb_down_outlined), color: faq.isHelpful == false ? Colors.red : AppColors.getTextSecondary(context), onPressed: () => _markFAQHelpful(faq, false))]),
        ]))],
      ));
  }

  Widget _buildTicketsTab() {
    if (_tickets.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.support_agent, size: 64, color: AppColors.getTextSecondary(context)),
        SizedBox(height: 16),
        Text('No tienes tickets de soporte', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextSecondary(context))),
        SizedBox(height: 8),
        Text('Crea un ticket si necesitas ayuda', style: TextStyle(color: AppColors.getTextSecondary(context))),
        SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () => DefaultTabController.of(context).animateTo(2),
          icon: Icon(Icons.add),
          label: Text('Crear ticket'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.rappiOrange,
            foregroundColor: Colors.white,
          ),
        ),
      ]));
    }
    return ListView.builder(padding: EdgeInsets.all(16), itemCount: _tickets.length, itemBuilder: (context, index) => _buildTicketCard(_tickets[index]));
  }

  Widget _buildTicketCard(SupportTicket ticket) {
    return Card(margin: EdgeInsets.only(bottom: 16), child: InkWell(onTap: () => _viewTicketDetails(ticket), child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _getStatusColor(ticket.status).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text(_getStatusText(ticket.status), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getStatusColor(ticket.status)))), Spacer(), Text(ticket.id, style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(context)))]),
      SizedBox(height: 8), Text(ticket.subject, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
      SizedBox(height: 4), Text(ticket.description, style: TextStyle(color: AppColors.getTextSecondary(context)), maxLines: 2, overflow: TextOverflow.ellipsis),
      SizedBox(height: 12),
      Row(children: [Icon(_getCategoryIcon(ticket.category), size: 16, color: AppColors.getTextSecondary(context)), SizedBox(width: 4), Text(_getCategoryText(ticket.category), style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(context))), SizedBox(width: 16), Icon(Icons.schedule, size: 16, color: AppColors.getTextSecondary(context)), SizedBox(width: 4), Text(_formatDateTime(ticket.updatedAt), style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(context))),
        if (ticket.responses.isNotEmpty) Container(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: AppColors.rappiOrange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text('${ticket.responses.length} respuestas', style: TextStyle(fontSize: 10, color: AppColors.rappiOrange, fontWeight: FontWeight.bold)))]),
    ]))));
  }

  Widget _buildNewTicketTab() {
    return SingleChildScrollView(padding: EdgeInsets.all(16), child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Crear Nuevo Ticket de Soporte', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))), SizedBox(height: 24),
      Text('Categoria', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))), SizedBox(height: 8),
      DropdownButtonFormField<String>(initialValue: _selectedCategory, items: [DropdownMenuItem(value: 'general', child: Text('General')), DropdownMenuItem(value: 'trip', child: Text('Problemas con viajes')), DropdownMenuItem(value: 'payment', child: Text('Problemas de pago')), DropdownMenuItem(value: 'account', child: Text('Cuenta/Perfil')), DropdownMenuItem(value: 'technical', child: Text('Problemas tecnicos')), DropdownMenuItem(value: 'other', child: Text('Otro'))], onChanged: (value) { setState(() => _selectedCategory = value!); }),
      SizedBox(height: 16), Text('Prioridad', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))), SizedBox(height: 8),
      DropdownButtonFormField<String>(initialValue: _selectedPriority, items: [DropdownMenuItem(value: 'low', child: Text('Baja')), DropdownMenuItem(value: 'medium', child: Text('Media')), DropdownMenuItem(value: 'high', child: Text('Alta')), DropdownMenuItem(value: 'urgent', child: Text('Urgente'))], onChanged: (value) { setState(() => _selectedPriority = value!); }),
      SizedBox(height: 16), Text('Asunto', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))), SizedBox(height: 8),
      TextFormField(controller: _subjectController, style: TextStyle(color: AppColors.getTextPrimary(context)), decoration: InputDecoration(hintText: 'Describe brevemente tu problema', hintStyle: TextStyle(color: AppColors.getTextSecondary(context)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.getBorder(context))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.getBorder(context))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.rappiOrange))), validator: (value) { if (value == null || value.isEmpty) return 'Por favor ingresa un asunto'; return null; }),
      SizedBox(height: 16), Text('Descripcion', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))), SizedBox(height: 8),
      TextFormField(controller: _descriptionController, maxLines: 5, style: TextStyle(color: AppColors.getTextPrimary(context)), decoration: InputDecoration(hintText: 'Proporciona todos los detalles posibles', hintStyle: TextStyle(color: AppColors.getTextSecondary(context)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.getBorder(context))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.getBorder(context))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.rappiOrange))), validator: (value) { if (value == null || value.isEmpty) return 'Por favor describe el problema'; return null; }),
      SizedBox(height: 24),
      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _submitTicket, style: ElevatedButton.styleFrom(backgroundColor: AppColors.rappiOrange, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Enviar Ticket', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
    ])));
  }

  Widget _buildContactTab() {
    return SingleChildScrollView(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildContactOption('Llamar a Soporte', 'Habla directamente', Icons.phone, AppColors.priceBlack, _supportPhone.isNotEmpty ? _supportPhone : 'Configurar numero', _callSupport),
      _buildContactOption('Chat en Vivo', 'Chatea con un agente', Icons.chat, AppColors.rappiOrange, 'Disponible 24/7', _openLiveChat),
      _buildContactOption('Email de Soporte', 'Envia un correo al equipo', Icons.email, Colors.orange, _supportEmail, _sendEmail),
      _buildContactOption('WhatsApp', 'Contacta por WhatsApp', Icons.message, Colors.green, _supportWhatsApp.isNotEmpty ? _supportWhatsApp : 'Configurar WhatsApp', _openWhatsApp),
      SizedBox(height: 24),
      Container(padding: EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.getSurface(context), borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Horario de Atencion', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.getTextPrimary(context))), SizedBox(height: 12),
        _buildHourRow('Lunes a Viernes', '8:00 AM - 10:00 PM'), _buildHourRow('Sabados', '9:00 AM - 8:00 PM'), _buildHourRow('Domingos', '10:00 AM - 6:00 PM'),
        SizedBox(height: 8), Text('El chat en vivo esta disponible 24/7', style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(context))),
      ])),
      SizedBox(height: 24),
      Text('Siguenos en redes sociales', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.getTextPrimary(context))), SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_buildSocialButton('Facebook', Icons.facebook, Colors.blue), _buildSocialButton('Twitter', Icons.alternate_email, Colors.lightBlue), _buildSocialButton('Instagram', Icons.camera_alt, Colors.purple), _buildSocialButton('LinkedIn', Icons.work, Colors.indigo)]),
    ]));
  }

  Widget _buildContactOption(String title, String subtitle, IconData icon, Color color, String info, VoidCallback onTap) {
    return Card(margin: EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: InkWell(onTap: onTap, child: Padding(padding: EdgeInsets.all(16), child: Row(children: [
      Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)), SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))), Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(context))), SizedBox(height: 4), Text(info, style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w600))])),
      Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.getTextSecondary(context)),
    ]))));
  }

  Widget _buildHourRow(String day, String hours) { return Padding(padding: EdgeInsets.symmetric(vertical: 2), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(day, style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.getTextPrimary(context))), Text(hours, style: TextStyle(color: AppColors.getTextSecondary(context)))])); }
  Widget _buildSocialButton(String platform, IconData icon, Color color) { return GestureDetector(onTap: () => _openSocialMedia(platform), child: Container(width: 60, height: 60, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 28))); }

  Color _getStatusColor(TicketStatus status) { switch (status) { case TicketStatus.open: return Colors.orange; case TicketStatus.inProgress: return AppColors.info; case TicketStatus.resolved: return AppColors.success; case TicketStatus.closed: return AppColors.grey500; } }
  String _getStatusText(TicketStatus status) { switch (status) { case TicketStatus.open: return 'Abierto'; case TicketStatus.inProgress: return 'En Progreso'; case TicketStatus.resolved: return 'Resuelto'; case TicketStatus.closed: return 'Cerrado'; } }
  IconData _getCategoryIcon(SupportCategory category) { switch (category) { case SupportCategory.general: return Icons.help_outline; case SupportCategory.trip: return Icons.directions_car; case SupportCategory.payment: return Icons.payment; case SupportCategory.account: return Icons.person; case SupportCategory.technical: return Icons.build; case SupportCategory.other: return Icons.more_horiz; } }
  String _getCategoryText(SupportCategory category) { switch (category) { case SupportCategory.general: return 'General'; case SupportCategory.trip: return 'Viajes'; case SupportCategory.payment: return 'Pagos'; case SupportCategory.account: return 'Cuenta'; case SupportCategory.technical: return 'Tecnico'; case SupportCategory.other: return 'Otro'; } }

  String _formatDateTime(DateTime dateTime) { final difference = DateTime.now().difference(dateTime); if (difference.inMinutes < 60) return 'Hace ${difference.inMinutes} min'; if (difference.inHours < 24) return 'Hace ${difference.inHours}h'; return '${dateTime.day}/${dateTime.month}/${dateTime.year}'; }

  void _markFAQHelpful(FAQ faq, bool helpful) {
    setState(() { final index = _faqs.indexWhere((f) => f.id == faq.id); if (index != -1) { _faqs[index] = FAQ(id: faq.id, question: faq.question, answer: faq.answer, category: faq.category, isHelpful: helpful); } });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gracias por tu opinion!'), backgroundColor: Colors.green));
  }

  void _viewTicketDetails(SupportTicket ticket) { Navigator.push(context, MaterialPageRoute(builder: (context) => TicketDetailsScreen(ticket: ticket))); }

  void _submitTicket() async {
    if (_formKey.currentState!.validate()) {
      // TODO(node-migration): reemplazar con endpoint POST /api/support/tickets
      // cuando exista. Por ahora creamos el ticket solo en memoria local.
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Debes estar autenticado'), backgroundColor: Colors.red));
        return;
      }
      final localId = 'local-${DateTime.now().millisecondsSinceEpoch}';
      final newTicket = SupportTicket(
        id: localId,
        subject: _subjectController.text,
        description: _descriptionController.text,
        category: _parseCategoryFromString(_selectedCategory),
        priority: _parsePriorityFromString(_selectedPriority),
        status: TicketStatus.open,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        responses: [],
      );
      if (!mounted) return;
      setState(() {
        _tickets.insert(0, newTicket);
        _subjectController.clear();
        _descriptionController.clear();
        _selectedCategory = 'general';
        _selectedPriority = 'medium';
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ticket registrado localmente'), backgroundColor: Colors.green));
      DefaultTabController.of(context).animateTo(1);
    }
  }

  SupportCategory _parseCategoryFromString(String category) { switch (category.toLowerCase()) { case 'trip': return SupportCategory.trip; case 'payment': return SupportCategory.payment; case 'account': return SupportCategory.account; case 'technical': return SupportCategory.technical; case 'other': return SupportCategory.other; default: return SupportCategory.general; } }
  TicketPriority _parsePriorityFromString(String priority) { switch (priority.toLowerCase()) { case 'low': return TicketPriority.low; case 'high': return TicketPriority.high; case 'urgent': return TicketPriority.urgent; default: return TicketPriority.medium; } }
  TicketStatus _parseStatusFromString(String status) { switch (status.toLowerCase()) { case 'open': return TicketStatus.open; case 'in_progress': case 'inprogress': return TicketStatus.inProgress; case 'resolved': return TicketStatus.resolved; case 'closed': return TicketStatus.closed; default: return TicketStatus.open; } }

  void _callSupport() async {
    if (_supportPhone.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Numero de soporte no configurado'), backgroundColor: Colors.orange)); return; }
    try { final Uri phoneUri = Uri(scheme: 'tel', path: _supportPhone); if (await canLaunchUrl(phoneUri)) { await launchUrl(phoneUri); } else { throw 'No se puede abrir la app de telefono'; } }
    catch (e) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userFriendlyError(e, fallback: 'Error al llamar')), backgroundColor: Colors.red)); }
  }

  void _openLiveChat() { DefaultTabController.of(context).animateTo(2); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Crea un ticket y te responderemos pronto'), backgroundColor: AppColors.rappiOrange)); }

  void _sendEmail() async {
    try { final Uri emailUri = Uri(scheme: 'mailto', path: _supportEmail, query: 'subject=Soporte Rappi Team'); if (await canLaunchUrl(emailUri)) { await launchUrl(emailUri); } else { throw 'No se puede abrir el cliente de correo'; } }
    catch (e) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userFriendlyError(e, fallback: 'Error al abrir email')), backgroundColor: Colors.red)); }
  }

  void _openWhatsApp() async {
    if (_supportWhatsApp.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('WhatsApp no configurado'), backgroundColor: Colors.orange)); return; }
    try { final cleanNumber = _supportWhatsApp.replaceAll(RegExp(r'[^\d+]'), ''); final Uri whatsappUri = Uri.parse('https://wa.me/$cleanNumber'); if (await canLaunchUrl(whatsappUri)) { await launchUrl(whatsappUri, mode: LaunchMode.externalApplication); } else { throw 'No se puede abrir WhatsApp'; } }
    catch (e) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userFriendlyError(e, fallback: 'Error al abrir WhatsApp')), backgroundColor: Colors.red)); }
  }

  void _openSocialMedia(String platform) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Abriendo $platform...'), backgroundColor: AppColors.rappiOrange)); }
}

class TicketDetailsScreen extends StatelessWidget {
  final SupportTicket ticket;
  const TicketDetailsScreen({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getInputFill(context),
      appBar: AppBar(backgroundColor: AppColors.rappiOrange, title: Text('Ticket #${ticket.id}', style: TextStyle(color: Colors.white)), leading: IconButton(icon: Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context))),
      body: SingleChildScrollView(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.getSurface(context), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: AppColors.getBorder(context).withValues(alpha: 0.1), blurRadius: 4, offset: Offset(0, 2))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _getStatusColor(ticket.status).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text(_getStatusText(context, ticket.status), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _getStatusColor(ticket.status)))), Spacer(), Text('Creado: ${_formatDate(ticket.createdAt)}', style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(context)))]),
            SizedBox(height: 12), Text(ticket.subject, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
            SizedBox(height: 8), Text(ticket.description, style: TextStyle(color: AppColors.getTextSecondary(context), height: 1.5)),
          ])),
        SizedBox(height: 16),
        if (ticket.responses.isNotEmpty) ...[Text('Conversacion', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.getTextPrimary(context))), SizedBox(height: 12), ...ticket.responses.map((response) => _buildResponseCard(context, response))],
        SizedBox(height: 16),
        if (ticket.status != TicketStatus.closed) SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => _addResponse(context), icon: Icon(Icons.reply), label: Text('Responder'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.rappiOrange, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
      ])),
    );
  }

  Widget _buildResponseCard(BuildContext context, TicketResponse response) {
    return Padding(padding: EdgeInsets.only(bottom: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 40, height: 40, decoration: BoxDecoration(color: response.isFromSupport ? AppColors.rappiOrange.withValues(alpha: 0.1) : AppColors.priceBlack.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(response.isFromSupport ? Icons.support_agent : Icons.person, color: response.isFromSupport ? AppColors.rappiOrange : AppColors.priceBlack, size: 20)),
      SizedBox(width: 12),
      Expanded(child: Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: response.isFromSupport ? AppColors.rappiOrange.withValues(alpha: 0.05) : AppColors.getSurface(context), borderRadius: BorderRadius.circular(8), border: Border.all(color: response.isFromSupport ? AppColors.rappiOrange.withValues(alpha: 0.2) : AppColors.getBorder(context))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Text(response.isFromSupport ? 'Soporte Rappi Team' : 'Tu', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: response.isFromSupport ? AppColors.rappiOrange : AppColors.priceBlack)), Spacer(), Text(_formatDateTimeStatic(context, response.createdAt), style: TextStyle(fontSize: 10, color: AppColors.getTextSecondary(context)))]),
          SizedBox(height: 4), Text(response.message, style: TextStyle(height: 1.4, color: AppColors.getTextPrimary(context))),
        ]))),
    ]));
  }

  String _formatDate(DateTime date) { return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}'; }
  String _formatDateTimeStatic(BuildContext context, DateTime dateTime) { final difference = DateTime.now().difference(dateTime); if (difference.inMinutes < 60) return 'Hace ${difference.inMinutes} min'; if (difference.inHours < 24) return 'Hace ${difference.inHours}h'; return '${dateTime.day}/${dateTime.month}'; }
  Color _getStatusColor(TicketStatus status) { switch (status) { case TicketStatus.open: return Colors.orange; case TicketStatus.inProgress: return AppColors.info; case TicketStatus.resolved: return AppColors.success; case TicketStatus.closed: return AppColors.grey500; } }
  String _getStatusText(BuildContext context, TicketStatus status) { switch (status) { case TicketStatus.open: return 'Abierto'; case TicketStatus.inProgress: return 'En Progreso'; case TicketStatus.resolved: return 'Resuelto'; case TicketStatus.closed: return 'Cerrado'; } }

  void _addResponse(BuildContext context) {
    final controller = TextEditingController();
    // Ronda 214: dispose garantizado con .then() — antes controller solo se
    // liberaba en el botón Enviar; cerrar con back o tap fuera leakeaba.
    showDialog(context: context, builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), backgroundColor: AppColors.getSurface(dialogContext),
      title: Text('Agregar Respuesta', style: TextStyle(color: AppColors.getTextPrimary(dialogContext))),
      content: SingleChildScrollView(child: TextField(controller: controller, maxLines: 3, style: TextStyle(color: AppColors.getTextPrimary(dialogContext)), decoration: InputDecoration(hintText: 'Escribe tu respuesta...', hintStyle: TextStyle(color: AppColors.getTextSecondary(dialogContext)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.getBorder(dialogContext))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.getBorder(dialogContext))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.rappiOrange))))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('Cancelar', style: TextStyle(color: AppColors.getTextSecondary(dialogContext)))),
        ElevatedButton(onPressed: () { if (controller.text.isNotEmpty) { Navigator.pop(dialogContext); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Respuesta enviada'), backgroundColor: Colors.green)); } }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.rappiOrange, foregroundColor: Colors.white), child: Text('Enviar')),
      ],
    )).then((_) => controller.dispose());
  }
}

// Models
class SupportTicket { final String id; final String subject; final String description; final SupportCategory category; final TicketPriority priority; final TicketStatus status; final DateTime createdAt; final DateTime updatedAt; final List<TicketResponse> responses; SupportTicket({required this.id, required this.subject, required this.description, required this.category, required this.priority, required this.status, required this.createdAt, required this.updatedAt, required this.responses}); }
class TicketResponse { final String message; final bool isFromSupport; final DateTime createdAt; TicketResponse({required this.message, required this.isFromSupport, required this.createdAt}); }
class FAQ { final String? id; final String question; final String answer; final String category; final bool? isHelpful; FAQ({this.id, required this.question, required this.answer, required this.category, this.isHelpful}); }
enum SupportCategory { general, trip, payment, account, technical, other }
enum TicketPriority { low, medium, high, urgent }
enum TicketStatus { open, inProgress, resolved, closed }
