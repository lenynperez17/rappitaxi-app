import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/extensions/theme_extensions.dart';
import '../../providers/wallet_provider.dart';
import '../../utils/logger.dart';

class RechargeCreditsScreen extends StatefulWidget {
  const RechargeCreditsScreen({super.key});

  @override
  State<RechargeCreditsScreen> createState() => _RechargeCreditsScreenState();
}

class _RechargeCreditsScreenState extends State<RechargeCreditsScreen> {
  bool _isLoading = false;
  bool _isProcessing = false;
  double _currentCredits = 0;
  // ✅ INICIALIZAR CON VALORES POR DEFECTO para evitar RangeError
  List<Map<String, dynamic>> _packages = [
    {'amount': 10.0, 'bonus': 0.0, 'label': 'Básico'},
    {'amount': 20.0, 'bonus': 2.0, 'label': 'Popular'},
    {'amount': 50.0, 'bonus': 10.0, 'label': 'Pro'},
    {'amount': 100.0, 'bonus': 25.0, 'label': 'Premium'},
  ];
  Map<String, dynamic>? _selectedPackage;

  @override
  void initState() {
    super.initState();
    _loadCreditInfo();
  }

  Future<void> _loadCreditInfo() async {
    // Obtener provider ANTES de cualquier await
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);

    // Usar valor local como fallback inicial
    _currentCredits = walletProvider.serviceCredits;

    // Intentar cargar datos de Firestore con timeout de 5 segundos
    try {
      final creditStatus = await walletProvider.checkCreditStatus()
          .timeout(const Duration(seconds: 5), onTimeout: () {
        AppLogger.warning('Timeout obteniendo créditos, usando valor local');
        return {'currentCredits': _currentCredits};
      });
      _currentCredits = (creditStatus['currentCredits'] as num?)?.toDouble() ?? _currentCredits;
    } catch (e) {
      AppLogger.warning('Error obteniendo créditos: $e');
    }

    try {
      final config = await walletProvider.getCreditConfig()
          .timeout(const Duration(seconds: 5), onTimeout: () {
        AppLogger.warning('Timeout obteniendo config, usando paquetes default');
        return {'creditPackages': []};
      });
      final configPackages = List<Map<String, dynamic>>.from(config['creditPackages'] ?? []);
      if (configPackages.isNotEmpty) {
        _packages = configPackages;
      }
    } catch (e) {
      AppLogger.warning('Error obteniendo config: $e');
    }

    // SIEMPRE terminar loading
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recargar Créditos'),
        backgroundColor: ModernTheme.rappiOrange,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCurrentBalanceCard(),
                  const SizedBox(height: 24),
                  const Text(
                    'Selecciona un paquete',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildPackagesGrid(),
                  const SizedBox(height: 24),
                  const Text(
                    'Método de pago',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildPaymentMethods(),
                  const SizedBox(height: 24),
                  if (_selectedPackage != null) ...[
                    _buildSummaryCard(),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.payment),
                      label: Text(
                        _selectedPackage != null
                            ? 'Recargar S/ ${(_selectedPackage!['amount'] as num).toDouble().toStringAsFixed(0)}'
                            : 'Selecciona un paquete',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedPackage != null && !_isProcessing
                            ? ModernTheme.rappiOrange
                            : Colors.grey,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _selectedPackage != null && !_isProcessing ? _processPayment : null,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildInfoSection(),
                ],
              ),
            ),
          // Overlay de loading al procesar pago
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Conectando con MercadoPago...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrentBalanceCard() {
    final walletProvider = Provider.of<WalletProvider>(context);
    final isFirstRecharge = walletProvider.isFirstRecharge;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [ModernTheme.rappiOrange, ModernTheme.rappiOrange.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: ModernTheme.rappiOrange.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Saldo de Créditos',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_balance_wallet, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text('PEN', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'S/. ${_currentCredits.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (isFirstRecharge) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.card_giftcard, color: Colors.amber, size: 18),
                  SizedBox(width: 8),
                  Text(
                    '¡Primera recarga con BONIFICACIÓN!',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPackagesGrid() {
    // UI: 3 columnas con diseño circular para los montos predefinidos
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: _packages.length,
      itemBuilder: (context, index) {
        final package = _packages[index];
        final isSelected = _selectedPackage == package;
        final amount = (package['amount'] as num).toDouble();
        final bonus = (package['bonus'] as num).toDouble();
        final label = package['label'] as String? ?? '';
        final isPopular = label.toLowerCase() == 'popular';

        // UI: Items circulares para los montos predefinidos
        return GestureDetector(
          onTap: () => setState(() => _selectedPackage = package),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Circulo principal con monto
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? ModernTheme.rappiOrange
                            : Theme.of(context).colorScheme.surface,
                        border: Border.all(
                          color: isSelected
                              ? ModernTheme.rappiOrange
                              : isPopular
                                  ? ModernTheme.rappiOrange.withValues(alpha: 0.4)
                                  : Colors.grey.shade300,
                          width: isSelected ? 0 : 2,
                        ),
                        boxShadow: isSelected
                            ? [BoxShadow(color: ModernTheme.rappiOrange.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))]
                            : [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'S/.',
                            style: TextStyle(
                              fontSize: 10,
                              color: isSelected ? Colors.white70 : context.secondaryText,
                            ),
                          ),
                          Text(
                            amount.toStringAsFixed(0),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : context.primaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isPopular)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.star, color: Colors.white, size: 10),
                      ),
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle, color: ModernTheme.rappiOrange, size: 16),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                // Etiqueta
                Text(
                  label.isNotEmpty ? label : 'S/. ${amount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isPopular ? FontWeight.bold : FontWeight.normal,
                    color: isPopular ? ModernTheme.rappiOrange : context.secondaryText,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (bonus > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '+${bonus.toStringAsFixed(0)} gratis',
                    style: const TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentMethods() {
    // Solo MercadoPago como método de pago
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/mercadopago_logo.png',
            height: 32,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.credit_card,
              color: Colors.blue,
              size: 32,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'MercadoPago',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, color: Colors.green, size: 16),
                SizedBox(width: 4),
                Text('Seguro', style: TextStyle(color: Colors.green, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final walletProvider = Provider.of<WalletProvider>(context);
    final amount = (_selectedPackage!['amount'] as num).toDouble();
    final bonus = (_selectedPackage!['bonus'] as num).toDouble();
    final firstRechargeBonus = walletProvider.isFirstRecharge ? 5.0 : 0.0;
    final totalBonus = bonus + firstRechargeBonus;
    final totalCredits = amount + totalBonus;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          _buildSummaryRow('Monto a pagar', 'S/. ${amount.toStringAsFixed(2)}'),
          if (bonus > 0) _buildSummaryRow('Bonificación del paquete', '+S/. ${bonus.toStringAsFixed(2)}', isBonus: true),
          if (firstRechargeBonus > 0)
            _buildSummaryRow('Bonificación primera recarga', '+S/. ${firstRechargeBonus.toStringAsFixed(2)}', isBonus: true),
          const Divider(),
          _buildSummaryRow(
            'Total de créditos',
            'S/. ${totalCredits.toStringAsFixed(2)}',
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBonus = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isBonus ? ModernTheme.rappiOrange : context.secondaryText,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isBonus ? ModernTheme.rappiOrange : null,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              fontSize: isBold ? 18 : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Información',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildInfoItem('Cada servicio aceptado consume créditos'),
          _buildInfoItem('Mantén saldo suficiente para no perder viajes'),
          _buildInfoItem('Los créditos no expiran'),
          _buildInfoItem('Primera recarga incluye bonificación extra'),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 12)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: context.secondaryText),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processPayment() async {
    if (_selectedPackage == null || _isProcessing) return;

    setState(() => _isProcessing = true);

    final amount = (_selectedPackage!['amount'] as num).toDouble();
    final bonus = (_selectedPackage!['bonus'] as num).toDouble();
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);

    try {
      final result = await walletProvider.processRechargeWithMercadoPago(
        amount: amount,
        bonus: bonus,
        context: context,
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (result['success'] == true) {
        final creditStatus = await walletProvider.checkCreditStatus();
        setState(() {
          _currentCredits = (creditStatus['currentCredits'] as num?)?.toDouble() ?? 0.0;
        });
        _showSuccessDialog(amount, bonus);
      } else {
        _showErrorDialog(result['message'] ?? 'Error al procesar el pago.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showErrorDialog('Error: $e');
    }
  }

  void _showSuccessDialog(double amount, double bonus) {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final firstRechargeBonus = walletProvider.isFirstRecharge ? 5.0 : 0.0;
    final totalCredits = amount + bonus + firstRechargeBonus;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ModernTheme.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: ModernTheme.success, size: 64),
            ),
            const SizedBox(height: 16),
            const Text(
              '¡Recarga exitosa!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Se han agregado S/. ${totalCredits.toStringAsFixed(2)} a tu cuenta',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.secondaryText),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.account_balance_wallet, color: ModernTheme.rappiOrange),
                  const SizedBox(width: 8),
                  Text(
                    'Nuevo saldo: S/. ${_currentCredits.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: ModernTheme.rappiOrange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context); // Volver a la pantalla anterior
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.rappiOrange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Aceptar', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: ModernTheme.error),
            SizedBox(width: 8),
            Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
