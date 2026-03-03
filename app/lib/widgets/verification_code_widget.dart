import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ride_provider.dart';
import '../utils/firestore_error_handler.dart';

/// Widget para mostrar y verificar códigos de verificación mutua
/// Sirve tanto para pasajero como para conductor
class VerificationCodeWidget extends StatefulWidget {
  final String rideId;
  final bool isDriver; // true si es conductor, false si es pasajero

  const VerificationCodeWidget({
    super.key,
    required this.rideId,
    required this.isDriver,
  });

  @override
  State<VerificationCodeWidget> createState() => _VerificationCodeWidgetState();
}

class _VerificationCodeWidgetState extends State<VerificationCodeWidget> {
  final TextEditingController _codeController = TextEditingController();
  bool _isVerifying = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();

    if (code.isEmpty || code.length != 4) {
      setState(() {
        _errorMessage = 'Ingresa un código de 4 dígitos';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final rideProvider = Provider.of<RideProvider>(context, listen: false);
    bool success;

    try {
      if (widget.isDriver) {
        // Conductor verifica código del pasajero
        success = await rideProvider.driverVerifiesPassengerCode(widget.rideId, code);
      } else {
        // Pasajero verifica código del conductor
        success = await rideProvider.passengerVerifiesDriverCode(widget.rideId, code);
      }

      setState(() {
        _isVerifying = false;
        if (success) {
          _successMessage = widget.isDriver
              ? '✅ Pasajero verificado correctamente'
              : '✅ Conductor verificado correctamente';
          _errorMessage = null;
          _codeController.clear();
        } else {
          _errorMessage = rideProvider.errorMessage ?? 'Código incorrecto';
          _successMessage = null;
        }
      });

      // Si ambos están verificados, mostrar mensaje de inicio de viaje
      if (success && rideProvider.isMutualVerificationComplete) {
        _showRideStartedDialog();
      }
    } catch (e) {
      setState(() {
        _isVerifying = false;
        _errorMessage = FirestoreErrorHandler.getSpanishMessage(e);
        _successMessage = null;
      });
    }
  }

  void _showRideStartedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 32),
            const SizedBox(width: 12),
            const Text('¡Viaje Iniciado!'),
          ],
        ),
        content: const Text(
          'Ambos códigos han sido verificados correctamente.\n\n'
          '✅ Verificación mutua completada\n'
          '🚗 El viaje ha comenzado',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RideProvider>(
      builder: (context, rideProvider, _) {
        // Obtener el código propio para mostrar
        final myCode = widget.isDriver
            ? rideProvider.driverVerificationCode
            : rideProvider.passengerVerificationCode;

        // Verificar si ya se completó la verificación propia
        final isMyVerificationComplete = widget.isDriver
            ? rideProvider.isPassengerVerified
            : rideProvider.isDriverVerified;

        // Verificar si la verificación mutua está completa
        final isMutualComplete = rideProvider.isMutualVerificationComplete;

        return Card(
          elevation: 4,
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Título
                Text(
                  'Verificación Mutua',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Ambos deben verificarse para iniciar el viaje',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                  textAlign: TextAlign.center,
                ),
                const Divider(height: 32),

                // Mostrar código propio
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        widget.isDriver
                            ? 'Tu código (mostrar al pasajero):'
                            : 'Tu código (mostrar al conductor):',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        myCode ?? '----',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Icon(Icons.visibility, color: Theme.of(context).colorScheme.primary, size: 20),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Estado de verificación propia
                if (isMyVerificationComplete)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.isDriver
                                ? '✅ Has verificado al pasajero'
                                : '✅ Has verificado al conductor',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  // Input para verificar código del otro
                  Text(
                    widget.isDriver
                        ? 'Ingresa el código del pasajero:'
                        : 'Ingresa el código del conductor:',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: '----',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                      ),
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                    onSubmitted: (_) => _verifyCode(),
                  ),
                  const SizedBox(height: 16),

                  // Botón de verificar
                  ElevatedButton.icon(
                    onPressed: _isVerifying ? null : _verifyCode,
                    icon: _isVerifying
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.onPrimary),
                            ),
                          )
                        : const Icon(Icons.verified_user),
                    label: Text(
                      _isVerifying ? 'Verificando...' : 'Verificar Código',
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],

                // Mensajes de error/éxito
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (_successMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _successMessage!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Estado de verificación mutua
                if (isMutualComplete) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.done_all, color: Theme.of(context).colorScheme.onPrimary, size: 40),
                        const SizedBox(height: 8),
                        Text(
                          '¡VERIFICACIÓN COMPLETA!',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'El viaje está en progreso',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],

                // Instrucciones
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info, color: Theme.of(context).colorScheme.tertiary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.isDriver
                              ? '💡 Solicita al pasajero que te muestre su código de 4 dígitos'
                              : '💡 Solicita al conductor que te muestre su código de 4 dígitos',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
