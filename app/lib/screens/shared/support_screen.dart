// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/extensions/theme_extensions.dart'; // ✅ Extensión para colores que se adaptan al tema

import '../../utils/logger.dart';
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  _SupportScreenState createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  // Support data
  List<SupportTicket> _tickets = [];
  List<FAQ> _faqs = [];
  bool _isLoading = true;

  // ✅ Información de contacto desde Firebase
  String _supportPhone = '';
  String _supportWhatsApp = '';
  String _supportEmail = 'soporte@rapiteam.app';
  
  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedCategory = 'general';
  String _selectedPriority = 'medium';
  
  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    
    _slideAnimation = CurvedAnimation(
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
        AppLogger.warning('⚠️ No hay usuario autenticado');
        setState(() => _isLoading = false);
        return;
      }

      // ✅ Cargar información de contacto desde Firebase config
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

      // ✅ Cargar tickets reales del usuario desde Firestore
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
            responses: [], // Se cargarán bajo demanda al abrir el ticket
          ));
        } catch (e) {
          AppLogger.error('Error parseando ticket ${doc.id}: $e');
        }
      }

      // ✅ Cargar FAQs desde Firebase
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
      AppLogger.error('❌ Error cargando datos de soporte: $e');
      if (!mounted) return;

      setState(() {
        _tickets = [];
        _faqs = _getDefaultFAQs();
        _isLoading = false;
      });
    }
  }

  // ✅ FAQs por defecto si no hay en Firebase
  List<FAQ> _getDefaultFAQs() {
    return [
        FAQ(
          id: '1',
          question: '¿Cómo puedo cambiar mi método de pago?',
          answer: 'Puedes cambiar tu método de pago desde el menú "Métodos de Pago" en tu perfil. Toca el método que deseas usar como predeterminado.',
          category: 'Pagos',
          isHelpful: null,
        ),
        FAQ(
          id: '2',
          question: '¿Qué hago si el conductor no llega?',
          answer: 'Si el conductor no llega en 10 minutos, puedes cancelar el viaje sin costo. Si ya pasó mucho tiempo, contacta a soporte.',
          category: 'Viajes',
          isHelpful: null,
        ),
        FAQ(
          id: '3',
          question: '¿Cómo puedo reportar un problema?',
          answer: 'Puedes reportar problemas desde esta pantalla de soporte, o directamente desde los detalles de tu viaje.',
          category: 'General',
          isHelpful: null,
        ),
        FAQ(
          id: '4',
          question: '¿Puedo programar un viaje con anticipación?',
          answer: 'Sí, puedes programar viajes hasta con 7 días de anticipación desde la pantalla principal.',
          category: 'Viajes',
          isHelpful: null,
        ),
        FAQ(
          id: '5',
          question: '¿Cómo funciona el sistema de calificaciones?',
          answer: 'Después de cada viaje puedes calificar tu experiencia del 1 al 5. Esto nos ayuda a mantener la calidad del servicio.',
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
        backgroundColor: context.surfaceColor,
        appBar: AppBar(
          backgroundColor: ModernTheme.rappiOrange,
          elevation: 0,
          title: Text(
            'Centro de Soporte',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          bottom: TabBar(
            indicatorColor: Theme.of(context).colorScheme.onPrimary,
            labelColor: Theme.of(context).colorScheme.onPrimary,
            unselectedLabelColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.70),
            tabs: [
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
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(ModernTheme.rappiOrange),
          ),
          SizedBox(height: 16),
          Text(
            'Cargando información de soporte...',
            style: TextStyle(
              color: context.secondaryText,
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
          // Search bar
          Container(
            margin: EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar en preguntas frecuentes...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: ModernTheme.rappiOrange),
                ),
              ),
            ),
          ),
          
          // Categories
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildCategoryChip('Todas', true);
                }
                return _buildCategoryChip(categories[index - 1], false);
              },
            ),
          ),
          
          // FAQs list
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.all(16),
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
      margin: EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(category),
        selected: isSelected,
        onSelected: (selected) {
          // Implement category filtering
        },
        backgroundColor: Theme.of(context).colorScheme.surface,
        selectedColor: ModernTheme.rappiOrange.withValues(alpha: 0.2),
        checkmarkColor: ModernTheme.rappiOrange,
        labelStyle: TextStyle(
          color: isSelected ? ModernTheme.rappiOrange : context.secondaryText,
        ),
      ),
    );
  }
  
  Widget _buildFAQCard(FAQ faq) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        title: Text(
          faq.question,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: context.primaryText,
          ),
        ),
        subtitle: Container(
          margin: EdgeInsets.only(top: 4),
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            faq.category,
            style: TextStyle(
              fontSize: 10,
              color: ModernTheme.rappiOrange,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  faq.answer,
                  style: TextStyle(
                    color: context.secondaryText,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      '¿Te fue útil esta respuesta?',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.secondaryText,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.thumb_up_outlined),
                      color: faq.isHelpful == true ? ModernTheme.success : context.secondaryText,
                      onPressed: () => _markFAQHelpful(faq, true),
                    ),
                    IconButton(
                      icon: Icon(Icons.thumb_down_outlined),
                      color: faq.isHelpful == false ? ModernTheme.error : context.secondaryText,
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
              color: context.secondaryText,
            ),
            SizedBox(height: 16),
            Text(
              'No tienes tickets de soporte',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.secondaryText,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Crea un nuevo ticket si necesitas ayuda',
              style: TextStyle(
                color: context.secondaryText,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _tickets.length,
      itemBuilder: (context, index) {
        final ticket = _tickets[index];
        return _buildTicketCard(ticket);
      },
    );
  }
  
  Widget _buildTicketCard(SupportTicket ticket) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _viewTicketDetails(ticket),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  Spacer(),
                  Text(
                    ticket.id,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.secondaryText,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                ticket.subject,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.primaryText,
                ),
              ),
              SizedBox(height: 4),
              Text(
                ticket.description,
                style: TextStyle(
                  color: context.secondaryText,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    _getCategoryIcon(ticket.category),
                    size: 16,
                    color: context.secondaryText,
                  ),
                  SizedBox(width: 4),
                  Text(
                    _getCategoryText(ticket.category),
                    style: TextStyle(
                      fontSize: 12,
                      color: context.secondaryText,
                    ),
                  ),
                  SizedBox(width: 16),
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: context.secondaryText,
                  ),
                  SizedBox(width: 4),
                  Text(
                    _formatDateTime(ticket.updatedAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: context.secondaryText,
                    ),
                  ),
                  Spacer(),
                  if (ticket.responses.isNotEmpty)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${ticket.responses.length} respuesta${ticket.responses.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 10,
                          color: ModernTheme.rappiOrange,
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
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
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
                color: context.primaryText,
              ),
            ),
            SizedBox(height: 24),
            
            // Category selection
            Text(
              'Categoría',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: context.primaryText,
              ),
            ),
            SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: ModernTheme.rappiOrange),
                ),
              ),
              items: [
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
            SizedBox(height: 16),
            
            // Priority selection
            Text(
              'Prioridad',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: context.primaryText,
              ),
            ),
            SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedPriority,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: ModernTheme.rappiOrange),
                ),
              ),
              items: [
                DropdownMenuItem(value: 'low', child: Text('Baja')),
                DropdownMenuItem(value: 'medium', child: Text('Media')),
                DropdownMenuItem(value: 'high', child: Text('Alta')),
                DropdownMenuItem(value: 'urgent', child: Text('Urgente')),
              ],
              onChanged: (value) {
                setState(() => _selectedPriority = value!);
              },
            ),
            SizedBox(height: 16),
            
            // Subject
            Text(
              'Asunto',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: context.primaryText,
              ),
            ),
            SizedBox(height: 8),
            TextFormField(
              controller: _subjectController,
              decoration: InputDecoration(
                hintText: 'Describe brevemente el problema',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: ModernTheme.rappiOrange),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor ingresa un asunto';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            
            // Description
            Text(
              'Descripción',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: context.primaryText,
              ),
            ),
            SizedBox(height: 8),
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
                  borderSide: BorderSide(color: ModernTheme.rappiOrange),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor describe el problema';
                }
                return null;
              },
            ),
            SizedBox(height: 24),
            
            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitTicket,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ModernTheme.rappiOrange,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Enviar Ticket',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildContactTab() {
    final contactOptions = [
      {
        'title': 'Llamar',
        'subtitle': 'Soporte directo',
        'icon': Icons.phone,
        'color': ModernTheme.primaryBlue,
        'info': _supportPhone.isNotEmpty ? _supportPhone : 'Configurar número',
        'onTap': _callSupport,
      },
      {
        'title': 'Chat en Vivo',
        'subtitle': 'Disponible 24/7',
        'icon': Icons.chat_bubble_rounded,
        'color': ModernTheme.rappiOrange,
        'info': 'Respuesta inmediata',
        'onTap': _openLiveChat,
      },
      {
        'title': 'Email',
        'subtitle': 'Escríbenos',
        'icon': Icons.email_rounded,
        'color': ModernTheme.warning,
        'info': _supportEmail,
        'onTap': _sendEmail,
      },
      {
        'title': 'WhatsApp',
        'subtitle': 'Mensaje directo',
        'icon': Icons.message_rounded,
        'color': ModernTheme.success,
        'info': _supportWhatsApp.isNotEmpty ? _supportWhatsApp : 'WhatsApp Business',
        'onTap': _openWhatsApp,
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grid 2 columnas con tarjetas de icono grande
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.88,
            children: contactOptions.map((option) {
              return _buildContactCard(
                option['title'] as String,
                option['subtitle'] as String,
                option['icon'] as IconData,
                option['color'] as Color,
                option['info'] as String,
                option['onTap'] as VoidCallback,
              );
            }).toList(),
          ),
          
          SizedBox(height: 24),
          
          // Office hours
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Horarios de Atención',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.primaryText,
                  ),
                ),
                SizedBox(height: 12),
                _buildHourRow('Lunes - Viernes', '8:00 AM - 10:00 PM'),
                _buildHourRow('Sábados', '9:00 AM - 8:00 PM'),
                _buildHourRow('Domingos', '10:00 AM - 6:00 PM'),
                SizedBox(height: 8),
                Text(
                  '* Chat en vivo disponible 24/7',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 24),
          
          // Social media
          Text(
            'Síguenos en redes sociales',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.primaryText,
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSocialButton('Facebook', Icons.facebook, ModernTheme.primaryBlue),
              _buildSocialButton('Twitter', Icons.alternate_email, ModernTheme.info),
              _buildSocialButton('Instagram', Icons.camera_alt, ModernTheme.error),
              _buildSocialButton('LinkedIn', Icons.work, ModernTheme.primaryBlue),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildContactCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    String info,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: color.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icono grande 80x80
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 36),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: context.primaryText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: context.secondaryText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                info,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHourRow(String day, String hours) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            day,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: context.primaryText,
            ),
          ),
          Text(
            hours,
            style: TextStyle(
              color: context.secondaryText,
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
        return ModernTheme.warning;
      case TicketStatus.inProgress:
        return ModernTheme.primaryBlue;
      case TicketStatus.resolved:
        return ModernTheme.success;
      case TicketStatus.closed:
        return context.secondaryText;
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
        return 'Técnico';
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
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Gracias por tu feedback'),
        backgroundColor: ModernTheme.success,
      ),
    );
  }
  
  void _viewTicketDetails(SupportTicket ticket) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TicketDetailsScreen(ticket: ticket),
      ),
    );
  }
  
  // ✅ Implementación completa de creación de ticket con Firebase
  void _submitTicket() async {
    if (_formKey.currentState!.validate()) {
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Debes estar autenticado para crear un ticket'),
              backgroundColor: ModernTheme.error,
            ),
          );
          return;
        }

        // ✅ Guardar en Firestore
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ticket creado exitosamente - ${newTicket.id}'),
            backgroundColor: ModernTheme.success,
          ),
        );

        // Cambiar al tab de tickets
        DefaultTabController.of(context).animateTo(1);
      } catch (e) {
        AppLogger.error('❌ Error creando ticket: $e');
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear ticket: $e'),
            backgroundColor: ModernTheme.error,
          ),
        );
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
  
  // ✅ Implementación completa de llamadas con url_launcher
  void _callSupport() async {
    if (_supportPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Número de soporte no configurado'),
          backgroundColor: ModernTheme.warning,
        ),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al intentar llamar: $e'),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }

  void _openLiveChat() {
    // ✅ Redirigir al tab de nuevo ticket para crear uno
    DefaultTabController.of(context).animateTo(2);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Crea un ticket y te responderemos pronto'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }

  // ✅ Implementación completa de email con url_launcher
  void _sendEmail() async {
    try {
      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: _supportEmail,
        query: 'subject=Soporte Rappi Team',
      );

      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        throw 'No se puede abrir el cliente de correo';
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al abrir correo: $e'),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }

  // ✅ Implementación completa de WhatsApp con url_launcher
  void _openWhatsApp() async {
    if (_supportWhatsApp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('WhatsApp de soporte no configurado'),
          backgroundColor: ModernTheme.warning,
        ),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al abrir WhatsApp: $e'),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }
  
  void _openSocialMedia(String platform) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Abriendo $platform...'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
} // Fin de la clase _SupportScreenState

// Ticket Details Screen
class TicketDetailsScreen extends StatelessWidget {
  final SupportTicket ticket;
  
  const TicketDetailsScreen({super.key, required this.ticket});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surfaceColor,
      appBar: AppBar(
        backgroundColor: ModernTheme.rappiOrange,
        title: Text(
          'Ticket ${ticket.id}',
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ticket header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: ModernTheme.getCardShadow(context),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      Spacer(),
                      Text(
                        'Creado: ${_formatDate(ticket.createdAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.secondaryText,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    ticket.subject,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.primaryText,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    ticket.description,
                    style: TextStyle(
                      color: context.secondaryText,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 16),
            
            // Responses
            if (ticket.responses.isNotEmpty) ...[
              Text(
                'Conversación',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.primaryText,
                ),
              ),
              SizedBox(height: 12),
              ...ticket.responses.map((response) => _buildResponseCard(context, response)),
            ],

            SizedBox(height: 16),
            
            // Add response button
            if (ticket.status != TicketStatus.closed)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _addResponse(context),
                  icon: Icon(Icons.reply),
                  label: Text('Responder'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ModernTheme.rappiOrange,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildResponseCard(BuildContext context, TicketResponse response) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: response.isFromSupport
                  ? ModernTheme.rappiOrange.withValues(alpha: 0.1)
                  : ModernTheme.primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              response.isFromSupport ? Icons.support_agent : Icons.person,
              color: response.isFromSupport
                  ? ModernTheme.rappiOrange
                  : ModernTheme.primaryBlue,
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: response.isFromSupport
                    ? ModernTheme.rappiOrange.withValues(alpha: 0.05)
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: response.isFromSupport
                      ? ModernTheme.rappiOrange.withValues(alpha: 0.2)
                      : Theme.of(context).dividerColor,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        response.isFromSupport ? 'Soporte Rappi Team' : 'Tú',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: response.isFromSupport
                              ? ModernTheme.rappiOrange
                              : ModernTheme.primaryBlue,
                        ),
                      ),
                      Spacer(),
                      Text(
                        _formatDateTime(response.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: context.secondaryText,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    response.message,
                    style: TextStyle(
                      color: context.primaryText,
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
        return ModernTheme.warning;
      case TicketStatus.inProgress:
        return ModernTheme.primaryBlue;
      case TicketStatus.resolved:
        return ModernTheme.success;
      case TicketStatus.closed:
        return context.secondaryText;
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
        title: Text('Agregar Respuesta'),
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Respuesta enviada'),
                    backgroundColor: ModernTheme.success,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.rappiOrange,
            ),
            child: Text('Enviar'),
          ),
        ],
      ),
    );
  }
}

// Models
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