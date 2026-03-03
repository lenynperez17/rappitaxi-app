import 'package:flutter/material.dart';
import '../../core/design/design_system.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_snackbar.dart';

/// Pantalla "Acerca de RapiTeam" con información de la app, empresa,
/// legal, contacto, técnica y redes sociales
class AboutScreen extends StatefulWidget {
  final String? userType; // 'passenger', 'driver', 'admin'

  const AboutScreen({super.key, this.userType});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
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
      duration: RtDuration.emphasis,
      vsync: this,
    );

    _slideController = AnimationController(
      duration: RtDuration.slow,
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: RtCurve.enter,
    );

    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: RtCurve.enter,
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: RtAppBar(
        title: 'Acerca de RapiTeam',
        variant: RtAppBarVariant.gradient,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: RtColors.white),
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
                  // App Header Section
                  _buildHeaderSection(),

                  // App Information
                  _buildAppInfoSection(),

                  // Company Information
                  _buildCompanySection(),

                  // Legal Information
                  _buildLegalSection(),

                  // Contact Information
                  _buildContactSection(),

                  // Technical Information
                  _buildTechnicalSection(),

                  // Social Media
                  _buildSocialMediaSection(),

                  const SizedBox(height: RtSpacing.xxl),
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
            padding: const EdgeInsets.all(RtSpacing.xxl),
            child: Column(
              children: [
                // App Logo/Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: RtGradients.brand,
                    shape: BoxShape.circle,
                    boxShadow: RtShadow.brand(),
                  ),
                  child: const Icon(
                    Icons.local_taxi,
                    size: 60,
                    color: RtColors.white,
                  ),
                ),
                const SizedBox(height: RtSpacing.xl),

                // App Name
                Text(
                  'RapiTeam',
                  style: RtTypo.displayLarge.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: RtSpacing.sm),

                // Tagline
                Text(
                  'Tu viaje, rápido y seguro',
                  style: RtTypo.bodyLarge.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: RtSpacing.base),

                // Version
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: RtSpacing.base,
                    vertical: RtSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: RtColors.brand.withValues(alpha: 0.1),
                    borderRadius: RtRadius.borderFull,
                  ),
                  child: Text(
                    'Versión 1.3.0 (Build 56)',
                    style: RtTypo.labelMedium.copyWith(
                      color: RtColors.brand,
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
      RtColors.info,
      [
        _buildInfoTile(
          'Descripción',
          'RapiTeam es una plataforma moderna de transporte que conecta pasajeros con conductores profesionales, ofreciendo un servicio seguro, confiable y eficiente.',
          Icons.description,
        ),
        _buildInfoTile(
          'Desarrollado por',
          'RAPI SOLUCIONES GENERALES S.A.C.',
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
      RtColors.brand,
      [
        _buildInfoTile(
          'Mision',
          'Revolucionar el transporte urbano mediante tecnologia innovadora que conecta comunidades y facilita la movilidad.',
          Icons.flag,
        ),
        _buildInfoTile(
          'Vision',
          'Ser la plataforma de transporte lider en America Latina, reconocida por nuestra excelencia en servicio y sostenibilidad.',
          Icons.visibility,
        ),
        _buildInfoTile(
          'Valores',
          'Seguridad, Confianza, Innovacion, Responsabilidad Social',
          Icons.favorite,
        ),
        _buildInfoTile(
          'Fundada en',
          '2024 - Lima, Peru',
          Icons.location_city,
        ),
      ],
    );
  }

  Widget _buildLegalSection() {
    return _buildSection(
      'Información Legal',
      Icons.gavel,
      RtColors.warning,
      [
        _buildActionTile(
          'Términos y Condiciones',
          'Lee los términos de uso del servicio',
          Icons.article,
          _showTermsAndConditions,
        ),
        _buildActionTile(
          'Política de Privacidad',
          'Conoce como protegemos tus datos',
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
      RtColors.warning,
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
          'Horario de Atencion',
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
      RtColors.info,
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
      'Siguenos',
      Icons.share,
      RtColors.error,
      [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: RtSpacing.base),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSocialButton(
                'Facebook',
                Icons.facebook,
                RtColors.info,
                _openFacebook,
              ),
              _buildSocialButton(
                'Twitter',
                Icons.connect_without_contact,
                RtColors.info,
                _openTwitter,
              ),
              _buildSocialButton(
                'Instagram',
                Icons.camera_alt,
                RtColors.warning,
                _openInstagram,
              ),
              _buildSocialButton(
                'LinkedIn',
                Icons.work,
                RtColors.info,
                _openLinkedIn,
              ),
            ],
          ),
        ),
        const SizedBox(height: RtSpacing.sm),
        Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: RtSpacing.base),
            child: Text(
              '@RapiTeamPE',
              style: RtTypo.titleMedium.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(
      String title, IconData icon, Color color, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            RtSpacing.base,
            RtSpacing.xl,
            RtSpacing.base,
            RtSpacing.md,
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: RtIconSize.sm),
              const SizedBox(width: RtSpacing.sm),
              Text(
                title,
                style: RtTypo.headingSmall.copyWith(color: color),
              ),
            ],
          ),
        ),
        Container(
          margin: RtSpacing.screenH,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: RtRadius.borderLg,
            boxShadow: RtShadow.soft(),
          ),
          child: ClipRRect(
            borderRadius: RtRadius.borderLg,
            child: Column(children: children),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile(String title, String subtitle, IconData icon) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(RtSpacing.sm),
        decoration: BoxDecoration(
          color: RtColors.brand.withValues(alpha: 0.1),
          borderRadius: RtRadius.borderSm,
        ),
        child: Icon(icon, color: RtColors.brand, size: RtIconSize.sm),
      ),
      title: Text(title, style: RtTypo.titleMedium.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(
        subtitle,
        style: RtTypo.bodySmall.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildActionTile(
      String title, String subtitle, IconData icon, VoidCallback? onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(RtSpacing.sm),
        decoration: BoxDecoration(
          color: RtColors.info.withValues(alpha: 0.1),
          borderRadius: RtRadius.borderSm,
        ),
        child: Icon(icon, color: RtColors.info, size: RtIconSize.sm),
      ),
      title: Text(title, style: RtTypo.titleMedium.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(
        subtitle,
        style: RtTypo.bodySmall.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
      trailing: onTap != null
          ? Icon(Icons.arrow_forward_ios, size: RtIconSize.xs, color: RtColors.neutral400)
          : null,
      onTap: onTap,
    );
  }

  Widget _buildSocialButton(
      String name, IconData icon, Color color, VoidCallback onTap) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(RtSpacing.base),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: RtIconSize.md),
          ),
        ),
        const SizedBox(height: RtSpacing.sm),
        Text(
          name,
          style: RtTypo.labelSmall.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  void _shareApp() {
    RtSnackbar.show(
      context,
      message: 'Compartiendo RapiTeam...',
      type: RtSnackbarType.info,
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
      applicationName: 'RapiTeam',
      applicationVersion: '1.3.0',
      applicationIcon: Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(
          gradient: RtGradients.brand,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.local_taxi, size: 32, color: RtColors.white),
      ),
    );
  }

  void _contactSupport() {
    RtSnackbar.show(
      context,
      message: 'Abriendo cliente de email...',
      type: RtSnackbarType.info,
    );
  }

  void _contactSales() {
    RtSnackbar.show(
      context,
      message: 'Contactando equipo de ventas...',
      type: RtSnackbarType.info,
    );
  }

  void _callEmergency() {
    RtSnackbar.show(
      context,
      message: 'Iniciando llamada de emergencia...',
      type: RtSnackbarType.warning,
    );
  }

  void _showOfficeLocation() {
    RtSnackbar.show(
      context,
      message: 'Abriendo ubicación en mapas...',
      type: RtSnackbarType.info,
    );
  }

  void _showChangelog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderLg),
        title: Text('Historial de Versiones', style: RtTypo.headingSmall),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildChangelogEntry('1.0.0', 'Enero 2025', [
                'Lanzamiento inicial de la aplicación',
                'Sistema completo de solicitud de viajes',
                'Panel de conductor y administrador',
                'Integracion con mapas y pagos',
                'Chat en tiempo real',
                'Sistema de calificaciones',
              ]),
              _buildChangelogEntry('0.9.0', 'Diciembre 2024', [
                'Version beta cerrada',
                'Pruebas con conductores seleccionados',
                'Optimizaciones de rendimiento',
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildChangelogEntry(
      String version, String date, List<String> changes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Version $version ($date)',
          style: RtTypo.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: RtColors.brand,
          ),
        ),
        const SizedBox(height: RtSpacing.sm),
        ...changes.map((change) => Padding(
              padding: const EdgeInsets.only(left: RtSpacing.base, bottom: RtSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '- ',
                    style: RtTypo.bodySmall.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                  Expanded(
                    child: Text(change, style: RtTypo.bodySmall),
                  ),
                ],
              ),
            )),
        const SizedBox(height: RtSpacing.base),
      ],
    );
  }

  void _openFacebook() {
    RtSnackbar.show(
      context,
      message: 'Abriendo Facebook...',
      type: RtSnackbarType.info,
    );
  }

  void _openTwitter() {
    RtSnackbar.show(
      context,
      message: 'Abriendo Twitter...',
      type: RtSnackbarType.info,
    );
  }

  void _openInstagram() {
    RtSnackbar.show(
      context,
      message: 'Abriendo Instagram...',
      type: RtSnackbarType.info,
    );
  }

  void _openLinkedIn() {
    RtSnackbar.show(
      context,
      message: 'Abriendo LinkedIn...',
      type: RtSnackbarType.info,
    );
  }

  Widget _buildLegalDocumentScreen(String title, String content) {
    return Scaffold(
      appBar: RtAppBar(
        title: title,
        variant: RtAppBarVariant.gradient,
      ),
      body: SingleChildScrollView(
        padding: RtSpacing.paddingBase,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: RtSpacing.base),
            Text(
              title,
              style: RtTypo.displaySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: RtSpacing.base),
            Text(
              'Última actualizacion: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
              style: RtTypo.bodySmall.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: RtSpacing.xl),
            Text(
              content,
              style: RtTypo.bodyMedium.copyWith(
                height: 1.6,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTermsAndConditionsContent() {
    return '''1. ACEPTACION DE LOS TERMINOS

Al utilizar la aplicación RapiTeam, usted acepta estar legalmente obligado por estos términos y condiciones.

2. DESCRIPCION DEL SERVICIO

RapiTeam es una plataforma tecnologica que conecta usuarios que necesitan transporte con conductores independientes.

3. REGISTRO Y CUENTA DE USUARIO

- Debe proporcionar información precisa y completa
- Es responsable de mantener la confidencialidad de su cuenta
- Debe notificar inmediatamente cualquier uso no autorizado

4. USO DEL SERVICIO

- El servicio esta disponible para usuarios mayores de 18 anos
- Prohibido el uso para actividades ilegales
- Se reserva el derecho de suspender cuentas por mal uso

5. TARIFAS Y PAGOS

- Las tarifas se calculan según distancia, tiempo y demanda
- Los pagos se procesan de forma segura
- Las disputas de pago deben reportarse dentro de 24 horas

6. RESPONSABILIDADES

- Los conductores son contratistas independientes
- RapiTeam no es responsable por danos durante el viaje
- Los usuarios deben seguir las normas de comportamiento

7. PRIVACIDAD

Su privacidad es importante. Consulte nuestra Política de Privacidad para más información.

8. MODIFICACIONES

Nos reservamos el derecho de modificar estos términos en cualquier momento.

9. JURISDICCION

Estos términos se rigen por las leyes de la Republica del Peru.''';
  }

  String _getPrivacyPolicyContent() {
    return '''POLITICA DE PRIVACIDAD DE RAPITEAM

1. INFORMACION QUE RECOPILAMOS

- Datos personales: nombre, email, teléfono
- Información de ubicación para brindar el servicio
- Datos de pago para procesar transacciones
- Información del dispositivo para mejorar la experiencia

2. COMO USAMOS SU INFORMACION

- Conectar pasajeros con conductores
- Procesar pagos de forma segura
- Mejorar nuestros servicios
- Comunicar promociones (con su consentimiento)

3. COMPARTIR INFORMACION

- Con conductores para completar viajes
- Con procesadores de pago para transacciones
- Con autoridades cuando sea requerido por ley
- Nunca vendemos datos personales a terceros

4. SEGURIDAD DE DATOS

- Encriptacion de datos sensibles
- Servidores seguros con certificaciones
- Acceso limitado solo a personal autorizado
- Monitoreo continuo de seguridad

5. SUS DERECHOS

- Acceder a sus datos personales
- Corregir información incorrecta
- Eliminar su cuenta y datos
- Exportar sus datos

6. RETENCION DE DATOS

Mantenemos sus datos solo mientras sea necesario para brindar el servicio.

7. CONTACTO

Para preguntas sobre privacidad: privacy@rapiteam.app''';
  }

  String _getCookiePolicyContent() {
    return '''POLITICA DE COOKIES

1. QUE SON LAS COOKIES

Las cookies son pequenos archivos de texto que se almacenan en su dispositivo para mejorar la experiencia de usuario.

2. TIPOS DE COOKIES QUE USAMOS

- Cookies esenciales: necesarias para el funcionamiento
- Cookies de rendimiento: para analizar el uso de la app
- Cookies de personalizacion: para recordar preferencias

3. COMO CONTROLAR LAS COOKIES

Puede gestionar las cookies desde la configuración de la aplicación.

4. COOKIES DE TERCEROS

Utilizamos servicios de terceros como Google Analytics que pueden colocar cookies.

5. ACTUALIZACIONES

Esta politica puede actualizarse periodicamente.''';
  }
}
