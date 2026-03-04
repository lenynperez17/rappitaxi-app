import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/price_negotiation_provider.dart';
import '../theme/modern_theme.dart';

/// Botón para cambiar entre modos (pasajero, conductor, admin)
///
/// Se muestra si el usuario tiene múltiples roles disponibles.
/// Permite cambiar entre passenger ↔ driver ↔ admin con confirmación.
class ModeSwitchButton extends StatelessWidget {
  /// Si es true, muestra el botón completo con texto
  /// Si es false, solo muestra el ícono (para espacios reducidos)
  final bool compact;

  /// Color del botón (opcional, usa color dinámico según modo)
  final Color? backgroundColor;

  const ModeSwitchButton({
    super.key,
    this.compact = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.currentUser;

        // No mostrar para admins - ellos SOLO pueden ser admins
        if (user == null || user.isAdmin) {
          return SizedBox.shrink();
        }

        // Solo mostrar si tiene múltiples roles disponibles
        if (user.availableRoles == null || user.availableRoles!.length <= 1) {
          return SizedBox.shrink();
        }

        // ✅ FIX: Usar modo EFECTIVO considerando documentVerified
        // Si está en modo driver pero no tiene documentos verificados,
        // mostrar como pasajero para consistencia visual
        final currentMode = _getEffectiveMode(user);
        final buttonColor = backgroundColor ?? _getModeColor(currentMode);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: authProvider.isLoading
                ? null
                : () => _showSwitchDialog(context, authProvider, user),
            borderRadius: BorderRadius.circular(compact ? 30 : 12),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 12 : 16,
                vertical: compact ? 12 : 12,
              ),
              decoration: BoxDecoration(
                color: buttonColor,
                borderRadius: BorderRadius.circular(compact ? 30 : 12),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: authProvider.isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.swap_horiz_rounded,
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: compact ? 20 : 22,
                        ),
                        if (!compact) ...[
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _getModeDisplayName(currentMode),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_drop_down,
                            color: Theme.of(context).colorScheme.onPrimary,
                            size: 18,
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  /// ✅ NUEVO: Obtener modo efectivo considerando el estado de documentos
  /// Si está en modo driver pero no tiene documentos verificados,
  /// retorna 'passenger' para consistencia con la navegación
  String _getEffectiveMode(dynamic user) {
    final activeMode = (user.activeMode as String?) ?? 'passenger';
    // Si es driver pero no tiene documentos verificados, mostrar como pasajero
    if (activeMode == 'driver' && user.documentVerified != true) {
      return 'passenger';
    }
    return activeMode;
  }

  /// Obtener color según el modo
  Color _getModeColor(String mode) {
    switch (mode) {
      case 'passenger':
        return ModernTheme.primaryOrange;
      case 'driver':
        return Color(0xFF10B981); // Verde
      case 'admin':
        return Color(0xFFEF4444); // Rojo
      default:
        return ModernTheme.primaryOrange;
    }
  }

  /// Obtener nombre para mostrar según el modo
  String _getModeDisplayName(String mode) {
    switch (mode) {
      case 'passenger':
        return 'Pasajero';
      case 'driver':
        return 'Conductor';
      case 'admin':
        return 'Admin';
      default:
        return mode;
    }
  }

  /// Obtener ícono según el modo
  IconData _getModeIcon(String mode) {
    switch (mode) {
      case 'passenger':
        return Icons.person_rounded;
      case 'driver':
        return Icons.local_taxi_rounded;
      case 'admin':
        return Icons.admin_panel_settings_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  /// Mostrar diálogo para seleccionar nuevo modo
  void _showSwitchDialog(
      BuildContext context, AuthProvider authProvider, dynamic user) {
    final currentMode = (user.activeMode as String?) ?? 'passenger';
    final availableRoles = (user.availableRoles as List<dynamic>?) ?? [];

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.swap_horiz_rounded,
              color: _getModeColor(currentMode),
              size: 24,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Cambiar Modo',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selecciona el modo al que deseas cambiar:',
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            SizedBox(height: 20),
            // Lista de opciones de modo
            ...availableRoles.map((role) {
              final roleStr = role.toString();
              final isCurrentMode = roleStr == currentMode;
              final modeColor = _getModeColor(roleStr);

              return Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: isCurrentMode
                        ? null
                        : () => _switchToMode(
                            dialogContext, context, authProvider, roleStr),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isCurrentMode
                            ? modeColor.withValues(alpha: 0.1)
                            : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCurrentMode
                              ? modeColor
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                          width: isCurrentMode ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isCurrentMode
                                  ? modeColor
                                  : modeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _getModeIcon(roleStr),
                              color: isCurrentMode
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : modeColor,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getModeDisplayName(roleStr),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: isCurrentMode
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: isCurrentMode
                                        ? modeColor
                                        : Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                if (isCurrentMode)
                                  Text(
                                    'Modo actual',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: modeColor,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (isCurrentMode)
                            Icon(
                              Icons.check_circle,
                              color: modeColor,
                              size: 24,
                            )
                          else
                            Icon(
                              Icons.arrow_forward_ios,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                              size: 16,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'La app navegará a la pantalla correspondiente',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cerrar',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Cambiar a un modo específico
  Future<void> _switchToMode(
    BuildContext dialogContext,
    BuildContext parentContext,
    AuthProvider authProvider,
    String targetMode,
  ) async {
    Navigator.pop(dialogContext);

    try {
      // ✅ CLEANUP CRÍTICO: Detener listeners del rol anterior ANTES de cambiar
      final currentMode = authProvider.currentUser?.currentMode;
      final priceNegProvider = Provider.of<PriceNegotiationProvider>(parentContext, listen: false);

      if (currentMode == 'passenger') {
        priceNegProvider.stopPassengerListeners();
        debugPrint('🧹 Limpiados listeners de pasajero antes de cambiar a $targetMode');
      } else if (currentMode == 'driver') {
        priceNegProvider.stopDriverListeners();
        debugPrint('🧹 Limpiados listeners de conductor antes de cambiar a $targetMode');
      }

      // Cambiar modo
      final success = await authProvider.switchMode(targetMode);

      if (!parentContext.mounted) return;

      if (success) {
        // Obtener ruta según modo
        String route;
        switch (targetMode) {
          case 'driver':
            route = '/driver/home';
            break;
          case 'admin':
            route = '/admin/dashboard';
            break;
          case 'passenger':
          default:
            route = '/passenger/home';
            break;
        }

        // Navegar a la pantalla correspondiente
        Navigator.pushNamedAndRemoveUntil(
          parentContext,
          route,
          (route) => false, // Limpiar stack de navegación
        );

        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Theme.of(parentContext).colorScheme.onPrimary,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Cambiado a modo ${_getModeDisplayName(targetMode)}',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: _getModeColor(targetMode),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        // Mostrar error
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.error,
                  color: Theme.of(parentContext).colorScheme.onError,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    authProvider.errorMessage ?? 'Error al cambiar modo',
                  ),
                ),
              ],
            ),
            backgroundColor: ModernTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (!parentContext.mounted) return;

      ScaffoldMessenger.of(parentContext).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.error,
                color: Theme.of(parentContext).colorScheme.onError,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text('Error: ${e.toString()}'),
              ),
            ],
          ),
          backgroundColor: ModernTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
}
