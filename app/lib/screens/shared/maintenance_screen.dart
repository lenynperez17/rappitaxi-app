import 'package:flutter/material.dart';
import '../../core/theme/modern_theme.dart';

/// Pantalla de mantenimiento del sistema
///
/// Se muestra cuando el admin activa maintenanceMode en la configuración.
/// Los usuarios no-admin no pueden acceder a la app mientras esté activo.
class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  bool _isChecking = false;

  /// Verificar si el modo mantenimiento sigue activo
  Future<void> _checkMaintenanceStatus() async {
    setState(() => _isChecking = true);

    // TODO(node-migration): reemplazar con endpoint /api/config/app cuando exista.
    // Por ahora simplemente reintentamos volviendo al splash — este decidira si
    // hay que volver a mostrar la pantalla de mantenimiento o continuar al app.
    await Future<void>.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;
    setState(() => _isChecking = false);
    Navigator.pushReplacementNamed(context, '/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ModernTheme.rappiOrange.withValues(alpha: 0.12),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icono grande naranja centrado
                  Icon(
                    Icons.build_circle,
                    size: 120,
                    color: ModernTheme.rappiOrange,
                  ),

                  const SizedBox(height: 32),

                  // Card central con borderRadius 24 y padding 32
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Título
                        Text(
                          'Sistema en Mantenimiento',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: ModernTheme.rappiOrange,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 16),

                        // Descripción
                        Text(
                          'Estamos realizando mejoras para brindarte una mejor experiencia.\n\nPor favor, intenta de nuevo más tarde.',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[600],
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 32),

                        // Botón reintentar
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                _isChecking ? null : _checkMaintenanceStatus,
                            icon: _isChecking
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.refresh),
                            label: Text(
                                _isChecking ? 'Verificando...' : 'Reintentar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ModernTheme.rappiOrange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Logo y nombre de la app
                  Image.asset(
                    'assets/images/logo_rappi_taxi.png',
                    width: 60,
                    height: 60,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.local_taxi,
                        size: 48,
                        color: ModernTheme.rappiOrange.withValues(alpha: 0.5),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Rappi Team',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
