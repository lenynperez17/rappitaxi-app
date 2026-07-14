// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

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
      backgroundColor: AppColors.getInputFill(context),
      appBar: AppBar(
        backgroundColor: AppColors.rappiOrange,
        elevation: 0,
        title: Text(
          'Acerca de Rappi Team',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share, color: Colors.white),
            onPressed: _shareApp,
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeaderSection(),
                  _buildAppInfoSection(),
                  _buildCompanySection(),
                  _buildLegalSection(),
                  _buildContactSection(),
                  _buildTechnicalSection(),
                  _buildSocialMediaSection(),
                  SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
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
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.rappiOrange, AppColors.rappiOrange.withValues(alpha: 0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.rappiOrange.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.local_taxi,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'Rappi Team',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Tu viaje, tu precio, tu camino',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.getTextSecondary(context),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.rappiOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Version 1.0.0 (Build 100)',
                    style: TextStyle(
                      color: AppColors.rappiOrange,
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
      'Informacion de la App',
      Icons.info,
      AppColors.priceBlack,
      [
        _buildInfoTile('Descripcion', 'Rappi Team es una plataforma de transporte que conecta pasajeros con conductores, ofreciendo precios negociables, viajes programados y seguimiento en tiempo real.', Icons.description),
        _buildInfoTile('Desarrollado por', 'Rappi Team S.A.C.', Icons.business),
        _buildInfoTile('Fecha de lanzamiento', 'Enero 2025', Icons.calendar_today),
        _buildInfoTile('Categoria', 'Transporte y Viajes', Icons.category),
        _buildInfoTile('Tamano de la app', '45.2 MB', Icons.storage),
        _buildInfoTile('Compatibilidad', 'Android 6.0+ / iOS 12.0+', Icons.phone_android),
      ],
    );
  }

  Widget _buildCompanySection() {
    return _buildSection(
      'Nuestra Empresa',
      Icons.business_center,
      AppColors.rappiOrange,
      [
        _buildInfoTile('Mision', 'Democratizar el transporte urbano ofreciendo una plataforma segura, accesible y justa para pasajeros y conductores.', Icons.flag),
        _buildInfoTile('Vision', 'Ser la plataforma de transporte lider en Latinoamerica, reconocida por su innovacion y compromiso con la comunidad.', Icons.visibility),
        _buildInfoTile('Valores', 'Seguridad, Transparencia, Innovacion, Respeto y Compromiso Social.', Icons.favorite),
        _buildInfoTile('Fundada en', 'Lima, Peru - 2024', Icons.location_city),
      ],
    );
  }

  Widget _buildLegalSection() {
    return _buildSection(
      'Informacion Legal',
      Icons.gavel,
      Colors.purple,
      [
        _buildActionTile('Terminos y Condiciones', 'Leer los terminos del servicio', Icons.article, _showTermsAndConditions),
        _buildActionTile('Politica de Privacidad', 'Conoce como protegemos tus datos', Icons.privacy_tip, _showPrivacyPolicy),
        _buildActionTile('Politica de Cookies', 'Informacion sobre el uso de cookies', Icons.cookie, _showCookiePolicy),
        _buildActionTile('Licencias de Software', 'Licencias de terceros', Icons.code, _showLicenses),
        _buildInfoTile('Registro Comercial', 'RUC: 20XXXXXXXXX', Icons.business),
      ],
    );
  }

  Widget _buildContactSection() {
    return _buildSection(
      'Contacto y Soporte',
      Icons.contact_support,
      Colors.orange,
      [
        _buildActionTile('Soporte al Cliente', 'facturacion.rapiteam@gmail.com', Icons.email, _contactSupport),
        _buildActionTile('Ventas Corporativas', 'ventas@rapiteam.com', Icons.business_center, _contactSales),
        _buildActionTile('Telefono de Emergencia', '+51 1 123-4567', Icons.phone, _callEmergency),
        _buildActionTile('Oficina Central', 'Av. Principal 123, Lima, Peru', Icons.location_on, _showOfficeLocation),
        _buildInfoTile('Horario de Atencion', 'Lunes a Domingo: 24 horas', Icons.schedule),
      ],
    );
  }

  Widget _buildTechnicalSection() {
    return _buildSection(
      'Informacion Tecnica',
      Icons.settings,
      Colors.indigo,
      [
        _buildInfoTile('Framework', 'Flutter 3.19.0', Icons.code),
        _buildInfoTile('Backend', 'Firebase / Node.js', Icons.cloud),
        _buildInfoTile('Base de Datos', 'Firestore / PostgreSQL', Icons.storage),
        _buildInfoTile('Mapas', 'Google Maps Platform', Icons.map),
        _buildInfoTile('Pagos', 'MercadoPago', Icons.payment),
        _buildActionTile('Historial de Cambios', 'Ver historial de versiones', Icons.history, _showChangelog),
      ],
    );
  }

  Widget _buildSocialMediaSection() {
    return _buildSection(
      'Siguenos',
      Icons.share,
      Colors.pink,
      [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildSocialButton('Facebook', Icons.facebook, Colors.blue, _openFacebook),
            _buildSocialButton('Twitter', Icons.connect_without_contact, Colors.lightBlue, _openTwitter),
            _buildSocialButton('Instagram', Icons.camera_alt, Colors.purple, _openInstagram),
            _buildSocialButton('LinkedIn', Icons.work, Colors.blueAccent, _openLinkedIn),
          ],
        ),
        SizedBox(height: 16),
        Center(
          child: Text(
            '@RappiTeamPE',
            style: TextStyle(
              color: AppColors.getTextSecondary(context),
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
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.getSurface(context),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: AppColors.getBorder(context).withValues(alpha: 0.05), blurRadius: 10, offset: Offset(0, 2)),
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
        decoration: BoxDecoration(color: AppColors.rappiOrange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: AppColors.rappiOrange, size: 20),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 13, color: AppColors.getTextSecondary(context), height: 1.4)),
    );
  }

  Widget _buildActionTile(String title, String subtitle, IconData icon, VoidCallback? onTap) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.priceBlack.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: AppColors.priceBlack, size: 20),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 13, color: AppColors.getTextSecondary(context))),
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
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle, border: Border.all(color: color.withValues(alpha: 0.3))),
            child: Icon(icon, color: color, size: 24),
          ),
        ),
        SizedBox(height: 8),
        Text(name, style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(context), fontWeight: FontWeight.w500)),
      ],
    );
  }

  void _shareApp() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Compartiendo Rappi Team...'), backgroundColor: AppColors.info));
  }

  void _showTermsAndConditions() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => _buildLegalDocumentScreen('Terminos y Condiciones', 'Los presentes Terminos y Condiciones regulan el uso de la aplicacion Rappi Team. Al utilizar nuestros servicios, usted acepta estos terminos en su totalidad. Rappi Team se reserva el derecho de modificar estos terminos en cualquier momento.')));
  }

  void _showPrivacyPolicy() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => _buildLegalDocumentScreen('Politica de Privacidad', 'En Rappi Team, nos comprometemos a proteger su privacidad. Recopilamos informacion personal necesaria para brindar nuestros servicios de transporte, incluyendo nombre, telefono, ubicacion y datos de pago. Esta informacion se utiliza exclusivamente para facilitar los viajes y mejorar la experiencia del usuario.')));
  }

  void _showCookiePolicy() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => _buildLegalDocumentScreen('Politica de Cookies', 'Rappi Team utiliza cookies y tecnologias similares para mejorar la experiencia del usuario, analizar el trafico y personalizar el contenido.')));
  }

  void _showLicenses() {
    showLicensePage(
      context: context,
      applicationName: 'Rappi Team',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 64, height: 64,
        decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.rappiOrange, AppColors.rappiOrange.withValues(alpha: 0.8)]), shape: BoxShape.circle),
        child: Icon(Icons.local_taxi, size: 32, color: Colors.white),
      ),
    );
  }

  void _contactSupport() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Abriendo cliente de correo...'), backgroundColor: AppColors.info));
  }

  void _contactSales() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Contactando equipo de ventas...'), backgroundColor: AppColors.info));
  }

  void _callEmergency() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Iniciando llamada de emergencia...'), backgroundColor: AppColors.warning));
  }

  void _showOfficeLocation() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Abriendo ubicacion en mapas...'), backgroundColor: AppColors.info));
  }

  void _showChangelog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Historial de Versiones'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildChangelogEntry('1.0.0', 'Enero 2025', ['Lanzamiento inicial de la aplicacion', 'Sistema completo de solicitud de viajes', 'Panel de conductor y administrador', 'Integracion de mapas y pagos', 'Chat en tiempo real', 'Sistema de calificaciones']),
                _buildChangelogEntry('0.9.0', 'Diciembre 2024', ['Version beta cerrada', 'Pruebas con conductores seleccionados', 'Optimizaciones de rendimiento']),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('Cerrar'))],
        );
      },
    );
  }

  Widget _buildChangelogEntry(String version, String date, List<String> changes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('v$version - $date', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.rappiOrange)),
        SizedBox(height: 8),
        ...changes.map((change) => Padding(
          padding: EdgeInsets.only(left: 16, bottom: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('\u2022 ', style: TextStyle(color: AppColors.getTextSecondary(context))),
            Expanded(child: Text(change, style: TextStyle(fontSize: 13))),
          ]),
        )),
        SizedBox(height: 16),
      ],
    );
  }

  void _openFacebook() { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Abriendo Facebook...'), backgroundColor: AppColors.info)); }
  void _openTwitter() { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Abriendo Twitter...'), backgroundColor: AppColors.info)); }
  void _openInstagram() { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Abriendo Instagram...'), backgroundColor: AppColors.info)); }
  void _openLinkedIn() { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Abriendo LinkedIn...'), backgroundColor: AppColors.info)); }

  Widget _buildLegalDocumentScreen(String title, String content) {
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';
    return Scaffold(
      backgroundColor: AppColors.getInputFill(context),
      appBar: AppBar(backgroundColor: AppColors.rappiOrange, elevation: 0, title: Text(title, style: TextStyle(color: Colors.white)), iconTheme: IconThemeData(color: Colors.white)),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
          SizedBox(height: 16),
          Text('Ultima actualizacion: $dateStr', style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(context), fontStyle: FontStyle.italic)),
          SizedBox(height: 24),
          Text(content, style: TextStyle(fontSize: 14, height: 1.6, color: AppColors.getTextPrimary(context))),
        ]),
      ),
    );
  }
}
