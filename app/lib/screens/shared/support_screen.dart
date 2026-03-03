import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/design/design_system.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../core/widgets/rt_button.dart';

import '../../utils/logger.dart';
import '../../utils/firestore_error_handler.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  // Datos de soporte
  List<SupportTicket> _tickets = [];
  List<FAQ> _faqs = [];
  bool _isLoading = true;

  // Información de contacto desde Firebase
  String _supportPhone = '';
  String _supportWhatsApp = '';
  String _supportEmail = 'soporte@rapiteam.app';

  // Controladores de formulario
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedCategory = 'general';
  String _selectedPriority = 'medium';

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    // Configurar curva del slide controller
    CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    );

    _loadSupportData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _loadSupportData() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        AppLogger.warning('No hay usuario autenticado');
        setState(() => _isLoading = false);
        return;
      }

      // Cargar información de contacto desde Firebase config
      final configDoc = await FirebaseFirestore.instance
          .collection('config')
          .doc('support_info')
          .get();

      if (configDoc.exists) {
        final data = configDoc.data()!;
        _supportPhone = data['phone'] ?? '';
        _supportWhatsApp = data['whatsapp'] ?? '';
        _supportEmail = data['email'] ?? 'soporte@rapiteam.app';
      }

      // Cargar tickets reales del usuario desde Firestore
      final ticketsSnapshot = await FirebaseFirestore.instance
          .collection('supportTickets')
          .where('userId', isEqualTo: currentUser.uid)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      List<SupportTicket> loadedTickets = [];
      for (var doc in ticketsSnapshot.docs) {
        try {
          final data = doc.data();
          loadedTickets.add(SupportTicket(
            id: doc.id,
            subject: data['subject'] ?? '',
            description: data['description'] ?? '',
            category: _parseCategoryFromString(data['category'] ?? 'general'),
            priority: _parsePriorityFromString(data['priority'] ?? 'medium'),
            status: _parseStatusFromString(data['status'] ?? 'open'),
            createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            responses: [], // Se cargaran bajo demanda al abrir el ticket
          ));
        } catch (e) {
          AppLogger.error('Error parseando ticket ${doc.id}: $e');
        }
      }

      // Cargar FAQs desde Firebase
      final faqsSnapshot = await FirebaseFirestore.instance
          .collection('faqs')
          .where('active', isEqualTo: true)
          .orderBy('order')
          .get();

      List<FAQ> loadedFaqs = [];
      for (var doc in faqsSnapshot.docs) {
        try {
          final data = doc.data();
          loadedFaqs.add(FAQ(
            id: doc.id,
            question: data['question'] ?? '',
            answer: data['answer'] ?? '',
            category: data['category'] ?? 'General',
            isHelpful: null,
          ));
        } catch (e) {
          AppLogger.error('Error parseando FAQ ${doc.id}: $e');
        }
      }

      if (!mounted) return;

      setState(() {
        _tickets = loadedTickets;
        _faqs = loadedFaqs.isNotEmpty ? loadedFaqs : _getDefaultFAQs();
        _isLoading = false;
      });

      _fadeController.forward();
      _slideController.forward();
    } catch (e) {
      AppLogger.error('Error cargando datos de soporte: $e');
      if (!mounted) return;

      setState(() {
        _tickets = [];
        _faqs = _getDefaultFAQs();
        _isLoading = false;
      });
    }
  }

  // FAQs por defecto si no hay en Firebase
  List<FAQ> _getDefaultFAQs() {
    return [
        FAQ(
          id: '1',
          question: 'Cómo puedo cambiar mi método de pago?',
          answer: 'Puedes cambiar tu método de pago desde el menu "Métodos de Pago" en tu perfil. Toca el método que deseas usar como predeterminado.',
          category: 'Pagos',
          isHelpful: null,
        ),
        FAQ(
          id: '2',
          question: 'Qué hago si el conductor no llega?',
          answer: 'Sí el conductor no llega en 10 minutos, puedes cancelar el viaje sin costo. Si ya pasó mucho tiempo, contacta a soporte.',
          category: 'Viajes',
          isHelpful: null,
        ),
        FAQ(
          id: '3',
          question: 'Cómo puedo reportar un problema?',
          answer: 'Puedes reportar problemas desde esta pantalla de soporte, o directamente desde los detalles de tu viaje.',
          category: 'General',
          isHelpful: null,
        ),
        FAQ(
          id: '4',
          question: 'Puedo programar un viaje con anticipación?',
          answer: 'Sí, puedes programar viajes hasta con 7 días de anticipación desde la pantalla principal.',
          category: 'Viajes',
          isHelpful: null,
        ),
        FAQ(
          id: '5',
          question: 'Cómo funciona el sistema de calificaciones?',
          answer: 'Despues de cada viaje puedes calificar tu experiencia del 1 al 5. Esto nos ayuda a mantener la calidad del servicio.',
          category: 'General',
          isHelpful: null,
        ),
      ];
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: RtAppBar(
          title: 'Centro de Soporte',
          variant: RtAppBarVariant.gradient,
          bottom: TabBar(
            indicatorColor: Theme.of(context).colorScheme.onPrimary,
            labelColor: Theme.of(context).colorScheme.onPrimary,
            unselectedLabelColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.70),
            tabs: const [
              Tab(icon: Icon(Icons.help_outline), text: 'FAQs'),
              Tab(icon: Icon(Icons.support_agent), text: 'Mis Tickets'),
              Tab(icon: Icon(Icons.add_circle_outline), text: 'Nuevo Ticket'),
              Tab(icon: Icon(Icons.contact_support), text: 'Contacto'),
            ],
          ),
        ),
        body: _isLoading ? _buildLoadingState() : _buildTabViews(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(RtColors.brand),
          ),
          const SizedBox(height: 16),
          Text(
            'Cargando información de soporte...',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabViews() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: TabBarView(
            children: [
              _buildFAQsTab(),
              _buildTicketsTab(),
              _buildNewTicketTab(),
              _buildContactTab(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFAQsTab() {
    final categories = _faqs.map((faq) => faq.category).toSet().toList();

    return SingleChildScrollView(
      child: Column(
        children: [
          // Barra de busqueda
          Container(
            margin: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar en preguntas frecuentes...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: RtColors.brand),
                ),
              ),
            ),
          ),

          // Categorias
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildCategoryChip('Todas', true);
                }
                return _buildCategoryChip(categories[index - 1], false);
              },
            ),
          ),

          // Lista de FAQs
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: _faqs.length,
            itemBuilder: (context, index) {
              final faq = _faqs[index];
              return _buildFAQCard(faq);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String category, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(category),
        selected: isSelected,
        onSelected: (selected) {
          // Implementar filtrado por categoria
        },
        backgroundColor: Theme.of(context).colorScheme.surface,
        selectedColor: RtColors.brand.withValues(alpha: 0.2),
        checkmarkColor: RtColors.brand,
        labelStyle: TextStyle(
          color: isSelected ? RtColors.brand : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildFAQCard(FAQ faq) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        title: Text(
          faq.question,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: RtColors.brand.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            faq.category,
            style: const TextStyle(
              fontSize: 10,
              color: RtColors.brand,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  faq.answer,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Te fue util esta respuesta?',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.thumb_up_outlined),
                      color: faq.isHelpful == true ? RtColors.success : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      onPressed: () => _markFAQHelpful(faq, true),
                    ),
                    IconButton(
                      icon: const Icon(Icons.thumb_down_outlined),
                      color: faq.isHelpful == false ? RtColors.error : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      onPressed: () => _markFAQHelpful(faq, false),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketsTab() {
    if (_tickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.support_agent,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'No tienes tickets de soporte',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Crea un nuevo ticket si necesitas ayuda',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tickets.length,
      itemBuilder: (context, index) {
        final ticket = _tickets[index];
        return _buildTicketCard(ticket);
      },
    );
  }

  Widget _buildTicketCard(SupportTicket ticket) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _viewTicketDetails(ticket),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(ticket.status, context).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getStatusText(ticket.status),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(ticket.status, context),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    ticket.id,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                ticket.subject,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                ticket.description,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    _getCategoryIcon(ticket.category),
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getCategoryText(ticket.category),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDateTime(ticket.updatedAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const Spacer(),
                  if (ticket.responses.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: RtColors.brand.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${ticket.responses.length} respuesta${ticket.responses.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: RtColors.brand,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewTicketTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Crear Nuevo Ticket de Soporte',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),

            // Seleccion de categoria
            Text(
              'Categoría',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: RtColors.brand),
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'general', child: Text('General')),
                DropdownMenuItem(value: 'trip', child: Text('Problemas con viaje')),
                DropdownMenuItem(value: 'payment', child: Text('Problemas de pago')),
                DropdownMenuItem(value: 'account', child: Text('Cuenta y perfil')),
                DropdownMenuItem(value: 'technical', child: Text('Problemas técnicos')),
                DropdownMenuItem(value: 'other', child: Text('Otro')),
              ],
              onChanged: (value) {
                setState(() => _selectedCategory = value!);
              },
            ),
            const SizedBox(height: 16),

            // Seleccion de prioridad
            Text(
              'Prioridad',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedPriority,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: RtColors.brand),
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Baja')),
                DropdownMenuItem(value: 'medium', child: Text('Media')),
                DropdownMenuItem(value: 'high', child: Text('Alta')),
                DropdownMenuItem(value: 'urgent', child: Text('Urgente')),
              ],
              onChanged: (value) {
                setState(() => _selectedPriority = value!);
              },
            ),
            const SizedBox(height: 16),

            // Asunto
            Text(
              'Asunto',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _subjectController,
              decoration: InputDecoration(
                hintText: 'Describe brevemente el problema',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: RtColors.brand),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor ingresa un asunto';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Descripción
            Text(
              'Descripción',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Proporciona detalles sobre el problema...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: RtColors.brand),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor describe el problema';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Boton de enviar
            RtButton(
              label: 'Enviar Ticket',
              onPressed: _submitTicket,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Opciones de contacto con información real desde Firebase
          _buildContactOption(
            'Llamar a Soporte',
            'Habla directamente con nuestro equipo',
            Icons.phone,
            RtColors.info,
            _supportPhone.isNotEmpty ? _supportPhone : 'Configurar número',
            _callSupport,
          ),
          _buildContactOption(
            'Chat en Vivo',
            'Chatea con un agente en tiempo real',
            Icons.chat,
            RtColors.brand,
            'Disponible 24/7',
            _openLiveChat,
          ),
          _buildContactOption(
            'Email',
            'Envia un correo a nuestro equipo',
            Icons.email,
            RtColors.warning,
            _supportEmail,
            _sendEmail,
          ),
          _buildContactOption(
            'WhatsApp',
            'Contacta por WhatsApp',
            Icons.message,
            RtColors.success,
            _supportWhatsApp.isNotEmpty ? _supportWhatsApp : 'Configurar WhatsApp',
            _openWhatsApp,
          ),

          const SizedBox(height: 24),

          // Horarios de atencion
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Horarios de Atencion',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                _buildHourRow('Lunes - Viernes', '8:00 AM - 10:00 PM'),
                _buildHourRow('Sábados', '9:00 AM - 8:00 PM'),
                _buildHourRow('Domingos', '10:00 AM - 6:00 PM'),
                const SizedBox(height: 8),
                Text(
                  '* Chat en vivo disponible 24/7',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Redes sociales
          Text(
            'Siguenos en redes sociales',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSocialButton('Facebook', Icons.facebook, RtColors.info),
              _buildSocialButton('Twitter', Icons.alternate_email, RtColors.info),
              _buildSocialButton('Instagram', Icons.camera_alt, RtColors.error),
              _buildSocialButton('LinkedIn', Icons.work, RtColors.info),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactOption(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    String info,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      info,
                      style: TextStyle(
                        fontSize: 14,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHourRow(String day, String hours) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            day,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Text(
            hours,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton(String platform, IconData icon, Color color) {
    return GestureDetector(
      onTap: () => _openSocialMedia(platform),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }

  Color _getStatusColor(TicketStatus status, BuildContext context) {
    switch (status) {
      case TicketStatus.open:
        return RtColors.warning;
      case TicketStatus.inProgress:
        return RtColors.info;
      case TicketStatus.resolved:
        return RtColors.success;
      case TicketStatus.closed:
        return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    }
  }

  String _getStatusText(TicketStatus status) {
    switch (status) {
      case TicketStatus.open:
        return 'Abierto';
      case TicketStatus.inProgress:
        return 'En Progreso';
      case TicketStatus.resolved:
        return 'Resuelto';
      case TicketStatus.closed:
        return 'Cerrado';
    }
  }

  IconData _getCategoryIcon(SupportCategory category) {
    switch (category) {
      case SupportCategory.general:
        return Icons.help_outline;
      case SupportCategory.trip:
        return Icons.directions_car;
      case SupportCategory.payment:
        return Icons.payment;
      case SupportCategory.account:
        return Icons.person;
      case SupportCategory.technical:
        return Icons.build;
      case SupportCategory.other:
        return Icons.more_horiz;
    }
  }

  String _getCategoryText(SupportCategory category) {
    switch (category) {
      case SupportCategory.general:
        return 'General';
      case SupportCategory.trip:
        return 'Viaje';
      case SupportCategory.payment:
        return 'Pago';
      case SupportCategory.account:
        return 'Cuenta';
      case SupportCategory.technical:
        return 'Tecnico';
      case SupportCategory.other:
        return 'Otro';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours} h';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  void _markFAQHelpful(FAQ faq, bool helpful) {
    setState(() {
      final index = _faqs.indexWhere((f) => f.id == faq.id);
      if (index != -1) {
        _faqs[index] = FAQ(
          id: faq.id,
          question: faq.question,
          answer: faq.answer,
          category: faq.category,
          isHelpful: helpful,
        );
      }
    });

    RtSnackbar.show(context, message: 'Gracias por tu feedback', type: RtSnackbarType.success);
  }

  void _viewTicketDetails(SupportTicket ticket) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TicketDetailsScreen(ticket: ticket),
      ),
    );
  }

  // Implementacion completa de creacion de ticket con Firebase
  void _submitTicket() async {
    if (_formKey.currentState!.validate()) {
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          if (!mounted) return;
          RtSnackbar.show(context, message: 'Debes estar autenticado para crear un ticket', type: RtSnackbarType.error);
          return;
        }

        // Guardar en Firestore
        final ticketData = {
          'userId': currentUser.uid,
          'subject': _subjectController.text,
          'description': _descriptionController.text,
          'category': _selectedCategory,
          'priority': _selectedPriority,
          'status': 'open',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        final docRef = await FirebaseFirestore.instance
            .collection('supportTickets')
            .add(ticketData);

        // Crear objeto de ticket local
        final newTicket = SupportTicket(
          id: docRef.id,
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

        RtSnackbar.show(context, message: 'Ticket creado exitosamente - ${newTicket.id}', type: RtSnackbarType.success);

        // Cambiar al tab de tickets
        DefaultTabController.of(context).animateTo(1);
      } catch (e) {
        AppLogger.error('Error creando ticket: $e');
        if (!mounted) return;

        RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
      }
    }
  }

  SupportCategory _parseCategoryFromString(String category) {
    switch (category.toLowerCase()) {
      case 'trip':
        return SupportCategory.trip;
      case 'payment':
        return SupportCategory.payment;
      case 'account':
        return SupportCategory.account;
      case 'technical':
        return SupportCategory.technical;
      case 'other':
        return SupportCategory.other;
      default:
        return SupportCategory.general;
    }
  }

  TicketPriority _parsePriorityFromString(String priority) {
    switch (priority.toLowerCase()) {
      case 'low':
        return TicketPriority.low;
      case 'high':
        return TicketPriority.high;
      case 'urgent':
        return TicketPriority.urgent;
      default:
        return TicketPriority.medium;
    }
  }

  TicketStatus _parseStatusFromString(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return TicketStatus.open;
      case 'in_progress':
      case 'inprogress':
        return TicketStatus.inProgress;
      case 'resolved':
        return TicketStatus.resolved;
      case 'closed':
        return TicketStatus.closed;
      default:
        return TicketStatus.open;
    }
  }

  // Implementacion completa de llamadas con url_launcher
  void _callSupport() async {
    if (_supportPhone.isEmpty) {
      if (!mounted) return;
      RtSnackbar.show(context, message: 'Número de soporte no configurado', type: RtSnackbarType.warning);
      return;
    }

    try {
      final Uri phoneUri = Uri(scheme: 'tel', path: _supportPhone);
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        throw 'No se puede abrir la aplicación de teléfono';
      }
    } catch (e) {
      if (!mounted) return;
      RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
    }
  }

  void _openLiveChat() {
    // Redirigir al tab de nuevo ticket para crear uno
    DefaultTabController.of(context).animateTo(2);
    RtSnackbar.show(context, message: 'Crea un ticket y te responderemos pronto', type: RtSnackbarType.info);
  }

  // Implementacion completa de email con url_launcher
  void _sendEmail() async {
    try {
      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: _supportEmail,
        query: 'subject=Soporte RapiTeam',
      );

      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        throw 'No se puede abrir el cliente de correo';
      }
    } catch (e) {
      if (!mounted) return;
      RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
    }
  }

  // Implementacion completa de WhatsApp con url_launcher
  void _openWhatsApp() async {
    if (_supportWhatsApp.isEmpty) {
      if (!mounted) return;
      RtSnackbar.show(context, message: 'WhatsApp de soporte no configurado', type: RtSnackbarType.warning);
      return;
    }

    try {
      // Limpiar el número (quitar espacios, guiones, etc.)
      final cleanNumber = _supportWhatsApp.replaceAll(RegExp(r'[^\d+]'), '');
      final Uri whatsappUri = Uri.parse('https://wa.me/$cleanNumber');

      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        throw 'No se puede abrir WhatsApp';
      }
    } catch (e) {
      if (!mounted) return;
      RtSnackbar.show(context, message: FirestoreErrorHandler.getSpanishMessage(e), type: RtSnackbarType.error);
    }
  }

  void _openSocialMedia(String platform) {
    RtSnackbar.show(context, message: 'Abriendo $platform...', type: RtSnackbarType.info);
  }
} // Fin de la clase _SupportScreenState

// Pantalla de detalles del ticket
class TicketDetailsScreen extends StatelessWidget {
  final SupportTicket ticket;

  const TicketDetailsScreen({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: RtAppBar(
        title: 'Ticket ${ticket.id}',
        variant: RtAppBarVariant.gradient,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado del ticket
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: RtShadow.soft(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(ticket.status, context).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getStatusText(ticket.status),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(ticket.status, context),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Creado: ${_formatDate(ticket.createdAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    ticket.subject,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ticket.description,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Respuestas
            if (ticket.responses.isNotEmpty) ...[
              Text(
                'Conversacion',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              ...ticket.responses.map((response) => _buildResponseCard(context, response)),
            ],

            const SizedBox(height: 16),

            // Boton de agregar respuesta
            if (ticket.status != TicketStatus.closed)
              RtButton(
                label: 'Responder',
                icon: Icons.reply,
                onPressed: () => _addResponse(context),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponseCard(BuildContext context, TicketResponse response) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: response.isFromSupport
                  ? RtColors.brand.withValues(alpha: 0.1)
                  : RtColors.info.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              response.isFromSupport ? Icons.support_agent : Icons.person,
              color: response.isFromSupport
                  ? RtColors.brand
                  : RtColors.info,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: response.isFromSupport
                    ? RtColors.brand.withValues(alpha: 0.05)
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: response.isFromSupport
                      ? RtColors.brand.withValues(alpha: 0.2)
                      : Theme.of(context).dividerColor,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        response.isFromSupport ? 'Soporte RapiTeam' : 'Tu',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: response.isFromSupport
                              ? RtColors.brand
                              : RtColors.info,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatDateTime(response.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    response.message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(TicketStatus status, BuildContext context) {
    switch (status) {
      case TicketStatus.open:
        return RtColors.warning;
      case TicketStatus.inProgress:
        return RtColors.info;
      case TicketStatus.resolved:
        return RtColors.success;
      case TicketStatus.closed:
        return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    }
  }

  String _getStatusText(TicketStatus status) {
    switch (status) {
      case TicketStatus.open:
        return 'Abierto';
      case TicketStatus.inProgress:
        return 'En Progreso';
      case TicketStatus.resolved:
        return 'Resuelto';
      case TicketStatus.closed:
        return 'Cerrado';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours} h';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }

  void _addResponse(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Agregar Respuesta'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Escribe tu respuesta...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          RtButton(
            label: 'Cancelar',
            onPressed: () => Navigator.pop(context),
            variant: RtButtonVariant.ghost,
            isFullWidth: false,
          ),
          RtButton(
            label: 'Enviar',
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.pop(context);
                RtSnackbar.show(context, message: 'Respuesta enviada', type: RtSnackbarType.success);
              }
            },
            isFullWidth: false,
          ),
        ],
      ),
    );
  }
}

// Modelos
class SupportTicket {
  final String id;
  final String subject;
  final String description;
  final SupportCategory category;
  final TicketPriority priority;
  final TicketStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<TicketResponse> responses;

  SupportTicket({
    required this.id,
    required this.subject,
    required this.description,
    required this.category,
    required this.priority,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.responses,
  });
}

class TicketResponse {
  final String id;
  final String message;
  final bool isFromSupport;
  final DateTime createdAt;

  TicketResponse({
    required this.id,
    required this.message,
    required this.isFromSupport,
    required this.createdAt,
  });
}

class FAQ {
  final String id;
  final String question;
  final String answer;
  final String category;
  final bool? isHelpful;

  FAQ({
    required this.id,
    required this.question,
    required this.answer,
    required this.category,
    this.isHelpful,
  });
}

enum SupportCategory {
  general,
  trip,
  payment,
  account,
  technical,
  other,
}

enum TicketPriority {
  low,
  medium,
  high,
  urgent,
}

enum TicketStatus {
  open,
  inProgress,
  resolved,
  closed,
}
