import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/price_negotiation_provider.dart';
import '../theme/modern_theme.dart';
import '../../utils/error_messages.dart';

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

  /// Ronda 236: modo actual del contexto donde se pinta el botón (driver
  /// home o passenger home). Se usa como source of truth cuando
  /// `user.currentMode` es null y `userType='dual'` — sin este hint el
  /// filtro no sabe cuál es el rol actual y termina viendo 2 destinos
  /// (passenger+driver) → dispara popup en vez de cambio directo.
  final String? fromMode;

  const ModeSwitchButton({
    super.key,
    this.compact = false,
    this.backgroundColor,
    this.fromMode,
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

        // Ronda 235: cuando el user solo tiene 2 roles (passenger + driver
        // real), tocar el botón cambia directo al otro modo sin popup. El
        // popup solo aparece si hay 3+ roles (ej. admin).
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: authProvider.isLoading
                ? null
                : () => _handleTap(context, authProvider, user),
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
    // Ronda 233 fix: backend no envía documentVerified — antes esto forzaba
    // "Pasajero" siempre aunque el user fuera dual+verified. Ahora chequea
    // isVerified+userType (mismo criterio de Ronda 231).
    final userType = (user.userType as String?) ?? 'passenger';
    final isDriverApproved = (user.isVerified as bool? ?? false) &&
        (userType == 'driver' || userType == 'dual');
    if (activeMode == 'driver' && !isDriverApproved) {
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

  /// Ronda 235: decidir si abrir popup o cambiar directo.
  /// Ronda 236: usar `fromMode` prop cuando currentMode del user es null y
  /// userType='dual' — sin esto el filtro no encontraba el modo actual y
  /// dejaba ambos destinos en effectiveRoles → popup innecesario.
  void _handleTap(BuildContext context, AuthProvider authProvider, dynamic user) {
    final userType = (user.userType as String?) ?? 'passenger';
    final isDriverApproved = (user.isVerified as bool? ?? false) &&
        (userType == 'driver' || userType == 'dual');
    final availableRoles = (user.availableRoles as List<dynamic>?)?.cast<String>() ?? const <String>[];

    // Preferencia: fromMode del widget > currentMode del user > effective
    // computado (que puede ser 'dual', irresoluble para filtrar).
    String currentMode = fromMode ??
        (user.currentMode as String?) ??
        _getEffectiveMode(user);
    // Si terminó siendo 'dual' aún (raro), asumimos passenger — el driver
    // home siempre pasa fromMode='driver' explícito.
    if (currentMode == 'dual') currentMode = 'passenger';

    // Filtrar roles a los que realmente puede cambiar.
    final effectiveRoles = availableRoles
        .where((r) => r != currentMode)
        .where((r) => r != 'dual') // 'dual' es meta-rol, no destino de switch
        .where((r) => r != 'driver' || isDriverApproved)
        .toList();

    // Si solo hay UN destino, cambiar directo sin popup.
    if (effectiveRoles.length == 1) {
      final target = effectiveRoles.first;
      _switchDirectly(context, authProvider, target);
      return;
    }
    // 0 o 2+ → mostrar diálogo (para admin u otros casos raros).
    _showSwitchDialog(context, authProvider, user);
  }

  Future<void> _switchDirectly(BuildContext context, AuthProvider authProvider, String mode) async {
    final rootNav = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    // Limpiar listeners del rol previo (mismo cleanup que hace _switchToMode
    // desde el dialog).
    final currentMode = authProvider.currentUser?.currentMode;
    try {
      final priceNegProvider = Provider.of<PriceNegotiationProvider>(context, listen: false);
      if (currentMode == 'passenger') {
        priceNegProvider.stopPassengerListeners();
      } else if (currentMode == 'driver') {
        priceNegProvider.stopDriverListeners();
      }
    } catch (_) { /* provider puede no estar disponible */ }

    final ok = await authProvider.switchMode(mode);
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(content: Text(authProvider.errorMessage ?? 'Error al cambiar de modo'), backgroundColor: Colors.red),
      );
      return;
    }
    final target = mode == 'driver' ? '/driver/home' : '/passenger/home';
    rootNav.pushNamedAndRemoveUntil(target, (_) => false);
  }

  /// Mostrar diálogo para seleccionar nuevo modo (solo 3+ roles).
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
                child: Text(userFriendlyError(e, fallback: 'Error')),
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
