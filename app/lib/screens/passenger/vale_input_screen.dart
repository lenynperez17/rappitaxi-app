import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../providers/vale_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/snackbar_helper.dart';


/// Pantalla para escanear o ingresar código de vale
class ValeInputScreen extends StatefulWidget {
  const ValeInputScreen({super.key});

  @override
  State<ValeInputScreen> createState() => _ValeInputScreenState();
}

class _ValeInputScreenState extends State<ValeInputScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _codeController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isScanning = false;
  bool _isManualEntry = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(_fadeAnimation);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _codeController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _validateCode(String code) async {
    final valeProvider = context.read<ValeProvider>();

    final success = await valeProvider.validateAndLoadVale(code);

    if (!mounted) return;

    if (success) {
      SnackBarHelper.showSuccess(
        context,
        'Vale aplicado correctamente',
      );
      Navigator.pop(context, true);
    } else {
      SnackBarHelper.showError(
        context,
        valeProvider.validationError ?? 'Código de vale inválido',
      );
    }
  }

  void _onQRCodeDetected(BarcodeCapture capture) {
    if (_isScanning) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null) return;

    setState(() => _isScanning = true);
    _validateCode(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ingresa tu Vale Corporativo'),
        actions: [
          IconButton(
            icon: Icon(_isManualEntry ? Icons.qr_code_scanner : Icons.keyboard),
            onPressed: () {
              setState(() {
                _isManualEntry = !_isManualEntry;
                if (!_isManualEntry) {
                  _scannerController.start();
                } else {
                  _scannerController.stop();
                }
              });
            },
            tooltip: _isManualEntry ? 'Escanear QR' : 'Ingresar manualmente',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Consumer<ValeProvider>(
            builder: (context, valeProvider, _) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Instrucciones
                    _buildInstructions(),

                    const SizedBox(height: 32),

                    // Modo: Scanner QR o Ingreso Manual
                    if (_isManualEntry)
                      _buildManualEntry(valeProvider)
                    else
                      _buildQRScanner(),

                    const SizedBox(height: 24),

                    // Información del vale (si está validando o hay error)
                    if (valeProvider.isValidating) _buildLoadingState(),
                    if (valeProvider.validationError != null)
                      _buildErrorState(valeProvider.validationError!),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 12),
                Text(
                  '¿Cómo usar tu vale?',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Ingresa el código de tu vale corporativo o escanea el código QR proporcionado por tu empresa.',
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualEntry(ValeProvider valeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _codeController,
          decoration: InputDecoration(
            labelText: 'Código de Vale',
            hintText: 'Ej: CORP-2024-XXXX',
            prefixIcon: const Icon(Icons.confirmation_number),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
          ),
          textCapitalization: TextCapitalization.characters,
          onChanged: (value) {
            // Auto-formatear mientras escribe
            if (value.length > 3 && !value.contains('-')) {
              // Auto-agregar guiones
              _codeController.text = value.toUpperCase();
            }
          },
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: valeProvider.isValidating
              ? null
              : () {
                  final code = _codeController.text.trim();
                  if (code.isEmpty) {
                    SnackBarHelper.showError(
                      context,
                      'Por favor ingresa el código del vale',
                    );
                    return;
                  }
                  _validateCode(code);
                },
          icon: valeProvider.isValidating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_circle),
          label: Text(
            valeProvider.isValidating ? 'Validando...' : 'Validar Vale',
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQRScanner() {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.35,
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.primaryColor, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            MobileScanner(
              controller: _scannerController,
              onDetect: _onQRCodeDetected,
            ),
            if (_isScanning)
              Container(
                color: AppColors.getTextPrimary(context).withValues(alpha: 0.54),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            // Overlay con marco
            Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.white,
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text('Validando código de vale...'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Card(
      color: AppColors.error.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                error,
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
