// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../utils/error_messages.dart';
import '../../services/app_config_service.dart';

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
          'Acerca de Rapi Team',
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
                  // Ronda 279: se retira "Síguenos". Los cuatro botones no
                  // abrían ninguna red —solo mostraban "Abriendo Facebook..."—
                  // y el usuario que decía debajo era "@RappiTeamPE", con la
                  // marca equivocada. Cuando haya cuentas reales se vuelve a
                  // poner con sus enlaces; hasta entonces prometía algo que no
                  // existe.
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
                  'Rapi Team',
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
      'Información de la App',
      Icons.info,
      AppColors.getTextPrimary(context),
      [
        _buildInfoTile('Descripcion', 'Rapi Team es una plataforma de transporte que conecta pasajeros con conductores, ofreciendo precios negociables, viajes programados y seguimiento en tiempo real.', Icons.description),
        _buildInfoTile('Desarrollado por', 'Rapi Team S.A.C.', Icons.business),
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
      'Información Legal',
      Icons.gavel,
      Colors.purple,
      [
        _buildActionTile('Términos y Condiciones', 'Leer los terminos del servicio', Icons.article, _showTermsAndConditions),
        _buildActionTile('Política de Privacidad', 'Conoce como protegemos tus datos', Icons.privacy_tip, _showPrivacyPolicy),
        _buildActionTile('Politica de Cookies', 'Informacion sobre el uso de cookies', Icons.cookie, _showCookiePolicy),
        _buildActionTile('Licencias de Software', 'Licencias de terceros', Icons.code, _showLicenses),
        // Ronda 279: decía literalmente "RUC: 20XXXXXXXXX", con las equis a la
        // vista del usuario. El RUC real está en el panel desde siempre.
        if (AppConfigService.instance.config.companyRuc.isNotEmpty)
          _buildInfoTile(
            'Registro Comercial',
            'RUC: ${AppConfigService.instance.config.companyRuc}',
            Icons.business,
          ),
      ],
    );
  }

  /// Ronda 279: esta sección mostraba datos inventados y botones que mentían.
  ///
  /// Había un "Teléfono de Emergencia: +51 1 123-4567" —un número de relleno—
  /// cuyo botón solo enseñaba el mensaje "Iniciando llamada de emergencia..."
  /// y no llamaba a nadie. Igual "Ventas Corporativas" con un correo que no
  /// existe y "Oficina Central: Av. Principal 123" de marcador de posición.
  ///
  /// Se quedan solo los datos reales, y los que vienen del panel se leen del
  /// panel. Para la emergencia de verdad la app ya tiene su botón SOS, que sí
  /// avisa a los contactos y al administrador; enviar a la gente a un número
  /// falso en una urgencia es lo peor que podía hacer esta pantalla.
  Widget _buildContactSection() {
    final config = AppConfigService.instance.config;
    return _buildSection(
      'Contacto y Soporte',
      Icons.contact_support,
      Colors.orange,
      [
        _buildActionTile(
          'Soporte al Cliente',
          config.supportEmail,
          Icons.email,
          _contactSupport,
        ),
        if (config.companyAddress.isNotEmpty)
          _buildInfoTile('Dirección', config.companyAddress, Icons.location_on),
        _buildInfoTile('Horario de Atención', 'Lunes a Domingo: 24 horas', Icons.schedule),
      ],
    );
  }

  /// Ronda 279: esta sección le contaba al pasajero la versión del framework y
  /// que la base de datos era "Firestore / PostgreSQL". Ni le sirve de nada ni
  /// era ya cierto: de Firebase solo queda el envío de notificaciones. Se deja
  /// lo único que tiene sentido para quien usa la app —con quién se paga— y el
  /// historial de versiones.
  Widget _buildTechnicalSection() {
    return _buildSection(
      'Información Técnica',
      Icons.settings,
      Colors.indigo,
      [
        _buildInfoTile('Mapas', 'Google Maps Platform', Icons.map),
        _buildInfoTile('Pagos', 'MercadoPago', Icons.payment),
        _buildActionTile('Historial de Cambios', 'Ver historial de versiones', Icons.history, _showChangelog),
      ],
    );
  }

  // Ronda 279: aquí vivía la sección "Síguenos", con cuatro botones que no
  // abrían ninguna red —solo mostraban "Abriendo Facebook..."— bajo el usuario
  // "@RappiTeamPE", con la marca equivocada. Se retiró entera, código incluido:
  // dejarlo muerto invita a que alguien lo vuelva a enchufar sin enterarse de
  // que nunca funcionó. Cuando existan cuentas reales se rehace con sus
  // enlaces de verdad.

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
        decoration: BoxDecoration(color: AppColors.getTextPrimary(context).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: AppColors.getTextPrimary(context), size: 20),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 13, color: AppColors.getTextSecondary(context))),
      trailing: onTap != null ? Icon(Icons.arrow_forward_ios, size: 16) : null,
      onTap: onTap,
    );
  }

  /// Ronda 279: el botón de compartir de la barra superior solo enseñaba
  /// "Compartiendo Rapi Team..." y no compartía nada. `share_plus` ya está en
  /// el proyecto —lo usa el detalle del viaje para enviar el recibo—, así que
  /// ahora abre de verdad la hoja de compartir del sistema.
  Future<void> _shareApp() async {
    try {
      await Share.share(
        'Pide tu taxi con Rapi Team y propón tú el precio.\n'
        'Descárgala en tu tienda de aplicaciones.',
        subject: 'Rapi Team',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFriendlyError(e, fallback: 'No se pudo compartir.')),
          backgroundColor: AppColors.info,
        ),
      );
    }
  }

  void _showTermsAndConditions() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => _buildLegalDocumentScreen('Términos y Condiciones', 'Los presentes Terminos y Condiciones regulan el uso de la aplicacion Rapi Team. Al utilizar nuestros servicios, usted acepta estos terminos en su totalidad. Rapi Team se reserva el derecho de modificar estos terminos en cualquier momento.')));
  }

  void _showPrivacyPolicy() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => _buildLegalDocumentScreen('Política de Privacidad', 'En Rapi Team, nos comprometemos a proteger su privacidad. Recopilamos informacion personal necesaria para brindar nuestros servicios de transporte, incluyendo nombre, telefono, ubicacion y datos de pago. Esta informacion se utiliza exclusivamente para facilitar los viajes y mejorar la experiencia del usuario.')));
  }

  void _showCookiePolicy() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => _buildLegalDocumentScreen('Politica de Cookies', 'Rapi Team utiliza cookies y tecnologias similares para mejorar la experiencia del usuario, analizar el trafico y personalizar el contenido.')));
  }

  void _showLicenses() {
    showLicensePage(
      context: context,
      applicationName: 'Rapi Team',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 64, height: 64,
        decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.rappiOrange, AppColors.rappiOrange.withValues(alpha: 0.8)]), shape: BoxShape.circle),
        child: Icon(Icons.local_taxi, size: 32, color: Colors.white),
      ),
    );
  }

  /// Ronda 279: antes solo decía "Abriendo cliente de correo..." y no abría
  /// nada. Ahora abre el correo de verdad, con el asunto puesto, y si el
  /// teléfono no tiene aplicación de correo lo dice en vez de fingir.
  Future<void> _contactSupport() async {
    final email = AppConfigService.instance.config.supportEmail;
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {'subject': 'Soporte Rapi Team'},
    );
    final abierto = await launchUrl(uri, mode: LaunchMode.externalApplication)
        .catchError((_) => false);
    if (!abierto && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Escríbenos a $email'),
          backgroundColor: AppColors.info,
        ),
      );
    }
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

  // Ronda 279: los cuatro `_openRed()` que había aquí solo enseñaban
  // "Abriendo Facebook..." y no abrían nada. Eliminados con su sección.

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
          Text(userFriendlyError(dateStr, fallback: 'Ultima actualizacion'), style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(context), fontStyle: FontStyle.italic)),
          SizedBox(height: 24),
          Text(content, style: TextStyle(fontSize: 14, height: 1.6, color: AppColors.getTextPrimary(context))),
        ]),
      ),
    );
  }
}
