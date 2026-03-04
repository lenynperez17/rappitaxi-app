// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/extensions/theme_extensions.dart'; // ✅ Extensión para colores que se adaptan al tema

class AboutScreen extends StatefulWidget {
  final String? userType; // 'passenger', 'driver', 'admin'
  
  const AboutScreen({super.key, this.userType});
  
  @override
  _AboutScreenState createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> 
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: Duration(milliseconds: 600),
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
    
    _fadeController.forward();
    _slideController.forward();
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surfaceColor,
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: CustomScrollView(
              slivers: [
                // SliverAppBar con efecto parallax
                SliverAppBar(
                  expandedHeight: 250,
                  pinned: true,
                  backgroundColor: ModernTheme.rappiOrange,
                  iconTheme: IconThemeData(color: context.onPrimaryText),
                  actions: [
                    IconButton(
                      icon: Icon(Icons.share, color: context.onPrimaryText),
                      onPressed: _shareApp,
                    ),
                  ],
                  title: Text(
                    'Acerca de Rappi Team',
                    style: TextStyle(
                      color: context.onPrimaryText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.parallax,
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            ModernTheme.rappiOrange,
                            ModernTheme.rappiOrange.withValues(alpha: 0.85),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(height: 40),
                            // Logo circular centrado en el header expandido
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 16,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.local_taxi,
                                size: 52,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Rappi Team',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'v1.0.0',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Contenido en lista
                SliverList(
                  delegate: SliverChildListDelegate([
                    SizedBox(height: 16),
                    // Cards escalonadas (margin-left incremental: 0, 8, 16, 8, 0...)
                    _buildStaggeredCard(_buildAppInfoSection(), 0),
                    _buildStaggeredCard(_buildCompanySection(), 1),
                    _buildStaggeredCard(_buildLegalSection(), 2),
                    _buildStaggeredCard(_buildContactSection(), 3),
                    _buildStaggeredCard(_buildTechnicalSection(), 4),
                    _buildStaggeredCard(_buildSocialMediaSection(), 5),
                    SizedBox(height: 32),
                  ]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Wrapper para dar margen incremental escalonado a cada sección
  Widget _buildStaggeredCard(Widget child, int index) {
    // Patron: 0, 8, 16, 8, 0, 8, 16...
    const margins = [0.0, 8.0, 16.0, 8.0, 0.0, 8.0];
    final leftMargin = margins[index % margins.length];
    return Padding(
      padding: EdgeInsets.only(left: leftMargin),
      child: child,
    );
  }
  
  Widget _buildHeaderSection() {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - _slideAnimation.value)),
          child: Container(
            padding: EdgeInsets.all(32),
            child: Column(
              children: [
                // App Logo/Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [ModernTheme.rappiOrange, ModernTheme.rappiOrange.withValues(alpha: 0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: ModernTheme.rappiOrange.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.local_taxi,
                    size: 60,
                    color: context.onPrimaryText,
                  ),
                ),
                SizedBox(height: 24),
                
                // App Name
                Text(
                  'Rappi Team',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: context.primaryText,
                  ),
                ),
                SizedBox(height: 8),
                
                // Tagline
                Text(
                  'Tu solución de movilidad urbana',
                  style: TextStyle(
                    fontSize: 16,
                    color: context.secondaryText,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                SizedBox(height: 16),
                
                // Version
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Versión 1.0.0 (Build 100)',
                    style: TextStyle(
                      color: ModernTheme.rappiOrange,
                      fontWeight: FontWeight.w600,
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
  
  Widget _buildAppInfoSection() {
    return _buildSection(
      'Información de la App',
      Icons.info,
      ModernTheme.primaryBlue,
      [
        _buildInfoTile(
          'Descripción',
          'Rappi Team es una plataforma moderna de transporte que conecta pasajeros con conductores profesionales, ofreciendo un servicio seguro, confiable y eficiente.',
          Icons.description,
        ),
        _buildInfoTile(
          'Desarrollado por',
          'NYNEL MKT - Soluciones Tecnológicas',
          Icons.business,
        ),
        _buildInfoTile(
          'Fecha de lanzamiento',
          'Enero 2025',
          Icons.calendar_today,
        ),
        _buildInfoTile(
          'Categoría',
          'Transporte y Viajes',
          Icons.category,
        ),
        _buildInfoTile(
          'Tamaño de la app',
          '45.2 MB',
          Icons.storage,
        ),
        _buildInfoTile(
          'Compatibilidad',
          'Android 6.0+ / iOS 12.0+',
          Icons.phone_android,
        ),
      ],
    );
  }
  
  Widget _buildCompanySection() {
    return _buildSection(
      'Nuestra Empresa',
      Icons.business_center,
      ModernTheme.rappiOrange,
      [
        _buildInfoTile(
          'Misión',
          'Revolucionar el transporte urbano mediante tecnología innovadora que conecta comunidades y facilita la movilidad.',
          Icons.flag,
        ),
        _buildInfoTile(
          'Visión',
          'Ser la plataforma de transporte líder en América Latina, reconocida por nuestra excelencia en servicio y sostenibilidad.',
          Icons.visibility,
        ),
        _buildInfoTile(
          'Valores',
          'Seguridad, Confianza, Innovación, Responsabilidad Social',
          Icons.favorite,
        ),
        _buildInfoTile(
          'Fundada en',
          '2024 - Lima, Perú',
          Icons.location_city,
        ),
      ],
    );
  }
  
  Widget _buildLegalSection() {
    return _buildSection(
      'Información Legal',
      Icons.gavel,
      ModernTheme.warning,
      [
        _buildActionTile(
          'Términos y Condiciones',
          'Lee los términos de uso del servicio',
          Icons.article,
          _showTermsAndConditions,
        ),
        _buildActionTile(
          'Política de Privacidad',
          'Conoce cómo protegemos tus datos',
          Icons.privacy_tip,
          _showPrivacyPolicy,
        ),
        _buildActionTile(
          'Política de Cookies',
          'Información sobre el uso de cookies',
          Icons.cookie,
          _showCookiePolicy,
        ),
        _buildActionTile(
          'Licencias de Software',
          'Licencias de componentes de terceros',
          Icons.code,
          _showLicenses,
        ),
        _buildInfoTile(
          'Registro Empresarial',
          'RUC: 20123456789',
          Icons.business,
        ),
      ],
    );
  }
  
  Widget _buildContactSection() {
    return _buildSection(
      'Contacto y Soporte',
      Icons.contact_support,
      ModernTheme.warning,
      [
        _buildActionTile(
          'Soporte al Cliente',
          'support@rapiteam.app',
          Icons.email,
          _contactSupport,
        ),
        _buildActionTile(
          'Ventas Corporativas',
          'ventas@rapiteam.app',
          Icons.business_center,
          _contactSales,
        ),
        _buildActionTile(
          'Teléfono de Emergencia',
          '+51 1 123-4567',
          Icons.phone,
          _callEmergency,
        ),
        _buildActionTile(
          'Oficinas Centrales',
          'Av. Javier Prado 123, San Isidro, Lima',
          Icons.location_on,
          _showOfficeLocation,
        ),
        _buildActionTile(
          'Horario de Atención',
          'Lunes a Domingo: 24/7',
          Icons.schedule,
          null,
        ),
      ],
    );
  }
  
  Widget _buildTechnicalSection() {
    return _buildSection(
      'Información Técnica',
      Icons.settings,
      ModernTheme.primaryBlue,
      [
        _buildInfoTile(
          'Framework',
          'Flutter 3.19.0',
          Icons.code,
        ),
        _buildInfoTile(
          'Backend',
          'Firebase / Node.js',
          Icons.cloud,
        ),
        _buildInfoTile(
          'Base de Datos',
          'Firestore / PostgreSQL',
          Icons.storage,
        ),
        _buildInfoTile(
          'Mapas',
          'Google Maps Platform',
          Icons.map,
        ),
        _buildInfoTile(
          'Pagos',
          'MercadoPago',
          Icons.payment,
        ),
        _buildActionTile(
          'Changelog',
          'Ver historial de versiones',
          Icons.history,
          _showChangelog,
        ),
      ],
    );
  }
  
  Widget _buildSocialMediaSection() {
    return _buildSection(
      'Síguenos',
      Icons.share,
      ModernTheme.error,
      [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildSocialButton(
              'Facebook',
              Icons.facebook,
              ModernTheme.primaryBlue,
              _openFacebook,
            ),
            _buildSocialButton(
              'Twitter',
              Icons.connect_without_contact,
              ModernTheme.info,
              _openTwitter,
            ),
            _buildSocialButton(
              'Instagram',
              Icons.camera_alt,
              ModernTheme.warning,
              _openInstagram,
            ),
            _buildSocialButton(
              'LinkedIn',
              Icons.work,
              ModernTheme.primaryBlue,
              _openLinkedIn,
            ),
          ],
        ),
        SizedBox(height: 16),
        Center(
          child: Text(
            '@RappiTeamPE',
            style: TextStyle(
              color: context.secondaryText,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildSection(String title, IconData icon, Color color, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
  
  Widget _buildInfoTile(String title, String subtitle, IconData icon) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: ModernTheme.rappiOrange, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: context.secondaryText,
          height: 1.4,
        ),
      ),
    );
  }
  
  Widget _buildActionTile(String title, String subtitle, IconData icon, VoidCallback? onTap) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: ModernTheme.primaryBlue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: ModernTheme.primaryBlue, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: context.secondaryText,
        ),
      ),
      trailing: onTap != null ? Icon(Icons.arrow_forward_ios, size: 16) : null,
      onTap: onTap,
    );
  }
  
  Widget _buildSocialButton(String name, IconData icon, Color color, VoidCallback onTap) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          name,
          style: TextStyle(
            fontSize: 12,
            color: context.secondaryText,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
  
  void _shareApp() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Compartiendo Rappi Team...'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
  
  void _showTermsAndConditions() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _buildLegalDocumentScreen(
          'Términos y Condiciones',
          _getTermsAndConditionsContent(),
        ),
      ),
    );
  }
  
  void _showPrivacyPolicy() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _buildLegalDocumentScreen(
          'Política de Privacidad',
          _getPrivacyPolicyContent(),
        ),
      ),
    );
  }
  
  void _showCookiePolicy() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _buildLegalDocumentScreen(
          'Política de Cookies',
          _getCookiePolicyContent(),
        ),
      ),
    );
  }
  
  void _showLicenses() {
    showLicensePage(
      context: context,
      applicationName: 'Rappi Team',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [ModernTheme.rappiOrange, ModernTheme.rappiOrange.withValues(alpha: 0.8)],
          ),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.local_taxi, size: 32, color: context.onPrimaryText),
      ),
    );
  }
  
  void _contactSupport() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Abriendo cliente de email...'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
  
  void _contactSales() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Contactando equipo de ventas...'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
  
  void _callEmergency() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Iniciando llamada de emergencia...'),
        backgroundColor: ModernTheme.warning,
      ),
    );
  }
  
  void _showOfficeLocation() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Abriendo ubicación en mapas...'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
  
  void _showChangelog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Historial de Versiones'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildChangelogEntry('1.0.0', 'Enero 2025', [
                'Lanzamiento inicial de la aplicación',
                'Sistema completo de solicitud de viajes',
                'Panel de conductor y administrador',
                'Integración con mapas y pagos',
                'Chat en tiempo real',
                'Sistema de calificaciones',
              ]),
              _buildChangelogEntry('0.9.0', 'Diciembre 2024', [
                'Versión beta cerrada',
                'Pruebas con conductores seleccionados',
                'Optimizaciones de rendimiento',
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildChangelogEntry(String version, String date, List<String> changes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Versión $version ($date)',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: ModernTheme.rappiOrange,
          ),
        ),
        SizedBox(height: 8),
        ...changes.map((change) => Padding(
          padding: EdgeInsets.only(left: 16, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• ', style: TextStyle(color: context.secondaryText)),
              Expanded(
                child: Text(
                  change,
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        )),
        SizedBox(height: 16),
      ],
    );
  }
  
  void _openFacebook() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Abriendo Facebook...'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
  
  void _openTwitter() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Abriendo Twitter...'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
  
  void _openInstagram() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Abriendo Instagram...'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
  
  void _openLinkedIn() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Abriendo LinkedIn...'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
  
  Widget _buildLegalDocumentScreen(String title, String content) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ModernTheme.rappiOrange,
        title: Text(
          title,
          style: TextStyle(color: context.onPrimaryText),
        ),
        iconTheme: IconThemeData(color: context.onPrimaryText),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: context.primaryText,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Última actualización: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
              style: TextStyle(
                color: context.secondaryText,
                fontStyle: FontStyle.italic,
              ),
            ),
            SizedBox(height: 24),
            Text(
              content,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: context.primaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _getTermsAndConditionsContent() {
    return '''1. ACEPTACIÓN DE LOS TÉRMINOS

Al utilizar la aplicación Rappi Team, usted acepta estar legalmente obligado por estos términos y condiciones.

2. DESCRIPCIÓN DEL SERVICIO

Rappi Team es una plataforma tecnológica que conecta usuarios que necesitan transporte con conductores independientes.

3. REGISTRO Y CUENTA DE USUARIO

- Debe proporcionar información precisa y completa
- Es responsable de mantener la confidencialidad de su cuenta
- Debe notificar inmediatamente cualquier uso no autorizado

4. USO DEL SERVICIO

- El servicio está disponible para usuarios mayores de 18 años
- Prohibido el uso para actividades ilegales
- Se reserva el derecho de suspender cuentas por mal uso

5. TARIFAS Y PAGOS

- Las tarifas se calculan según distancia, tiempo y demanda
- Los pagos se procesan de forma segura
- Las disputas de pago deben reportarse dentro de 24 horas

6. RESPONSABILIDADES

- Los conductores son contratistas independientes
- Rappi Team no es responsable por daños durante el viaje
- Los usuarios deben seguir las normas de comportamiento

7. PRIVACIDAD

Su privacidad es importante. Consulte nuestra Política de Privacidad para más información.

8. MODIFICACIONES

Nos reservamos el derecho de modificar estos términos en cualquier momento.

9. JURISDICCIÓN

Estos términos se rigen por las leyes de la República del Perú.''';
  }
  
  String _getPrivacyPolicyContent() {
    return '''POLÍTICA DE PRIVACIDAD DE RAPPI TEAM

1. INFORMACIÓN QUE RECOPILAMOS

- Datos personales: nombre, email, teléfono
- Información de ubicación para brindar el servicio
- Datos de pago para procesar transacciones
- Información del dispositivo para mejorar la experiencia

2. CÓMO USAMOS SU INFORMACIÓN

- Conectar pasajeros con conductores
- Procesar pagos de forma segura
- Mejorar nuestros servicios
- Comunicar promociones (con su consentimiento)

3. COMPARTIR INFORMACIÓN

- Con conductores para completar viajes
- Con procesadores de pago para transacciones
- Con autoridades cuando sea requerido por ley
- Nunca vendemos datos personales a terceros

4. SEGURIDAD DE DATOS

- Encriptación de datos sensibles
- Servidores seguros con certificaciones
- Acceso limitado solo a personal autorizado
- Monitoreo continuo de seguridad

5. SUS DERECHOS

- Acceder a sus datos personales
- Corregir información incorrecta
- Eliminar su cuenta y datos
- Exportar sus datos

6. RETENCIÓN DE DATOS

Mantenemos sus datos solo mientras sea necesario para brindar el servicio.

7. CONTACTO

Para preguntas sobre privacidad: privacy@rapiteam.app''';
  }
  
  String _getCookiePolicyContent() {
    return '''POLÍTICA DE COOKIES

1. QUÉ SON LAS COOKIES

Las cookies son pequeños archivos de texto que se almacenan en su dispositivo para mejorar la experiencia de usuario.

2. TIPOS DE COOKIES QUE USAMOS

- Cookies esenciales: necesarias para el funcionamiento
- Cookies de rendimiento: para analizar el uso de la app
- Cookies de personalización: para recordar preferencias

3. CÓMO CONTROLAR LAS COOKIES

Puede gestionar las cookies desde la configuración de la aplicación.

4. COOKIES DE TERCEROS

Utilizamos servicios de terceros como Google Analytics que pueden colocar cookies.

5. ACTUALIZACIONES

Esta política puede actualizarse periódicamente.''';
  }
}