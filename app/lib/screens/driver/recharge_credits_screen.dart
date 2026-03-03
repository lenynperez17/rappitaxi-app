import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design/design_system.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_button.dart';
import '../../providers/wallet_provider.dart';
import '../../utils/logger.dart';
import '../../utils/firestore_error_handler.dart';

class RechargeCreditsScreen extends StatefulWidget {
  const RechargeCreditsScreen({super.key});

  @override
  State<RechargeCreditsScreen> createState() => _RechargeCreditsScreenState();
}

class _RechargeCreditsScreenState extends State<RechargeCreditsScreen> {
  bool _isLoading = false;
  double _currentCredits = 0;
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
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    _currentCredits = walletProvider.serviceCredits;

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

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const RtAppBar(
        title: 'Recargar Créditos',
        variant: RtAppBarVariant.gradient,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: RtColors.brand,
              ),
            )
          : SingleChildScrollView(
              padding: RtSpacing.screenAll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Saldo actual
                  _buildCurrentBalanceCard(),
                  const SizedBox(height: RtSpacing.xl),

                  // Seleccionar paquete
                  Text(
                    'Selecciona un paquete',
                    style: RtTypo.headingSmall.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: RtSpacing.md),
                  _buildPackagesGrid(),
                  const SizedBox(height: RtSpacing.xl),

                  // Método de pago
                  Text(
                    'Método de pago',
                    style: RtTypo.headingSmall.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: RtSpacing.md),
                  _buildPaymentMethods(),
                  const SizedBox(height: RtSpacing.xl),

                  // Resumen
                  if (_selectedPackage != null) ...[
                    _buildSummaryCard(),
                    const SizedBox(height: RtSpacing.base),
                  ],

                  // Boton de pago
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: RtButton(
                      label: _selectedPackage != null
                          ? 'Pagar S/. ${(_selectedPackage!['amount'] as double).toStringAsFixed(2)}'
                          : 'Selecciona un paquete',
                      icon: Icons.payment,
                      onPressed: _selectedPackage != null ? _processPayment : null,
                    ),
                  ),
                  const SizedBox(height: RtSpacing.xl),

                  // Info adicional
                  _buildInfoSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentBalanceCard() {
    final walletProvider = Provider.of<WalletProvider>(context);
    final isFirstRecharge = walletProvider.isFirstRecharge;

    return Container(
      padding: const EdgeInsets.all(RtSpacing.lg),
      decoration: BoxDecoration(
        gradient: RtGradients.brand,
        borderRadius: RtRadius.borderLg,
        boxShadow: RtShadow.brand(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Saldo de Créditos',
                style: RtTypo.bodyMedium.copyWith(
                  color: RtColors.white.withValues(alpha: 0.7),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: RtColors.white.withValues(alpha: 0.2),
                  borderRadius: RtRadius.borderSm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_balance_wallet, color: RtColors.white, size: 16),
                    const SizedBox(width: RtSpacing.xs),
                    Text(
                      'PEN',
                      style: RtTypo.labelSmall.copyWith(color: RtColors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: RtSpacing.sm),
          Text(
            'S/. ${_currentCredits.toStringAsFixed(2)}',
            style: RtTypo.displayLarge.copyWith(color: RtColors.white),
          ),
          if (isFirstRecharge) ...[
            const SizedBox(height: RtSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: RtColors.white.withValues(alpha: 0.2),
                borderRadius: RtRadius.borderSm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.card_giftcard, color: RtColors.warning, size: 18),
                  const SizedBox(width: RtSpacing.sm),
                  Text(
                    'Primera recarga con BONIFICACION!',
                    style: RtTypo.labelSmall.copyWith(
                      color: RtColors.white,
                      fontWeight: FontWeight.w600,
                    ),
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
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: RtSpacing.md,
        mainAxisSpacing: RtSpacing.md,
        childAspectRatio: 1.3,
      ),
      itemCount: _packages.length,
      itemBuilder: (context, index) {
        final package = _packages[index];
        final isSelected = _selectedPackage == package;
        final amount = (package['amount'] as num).toDouble();
        final bonus = (package['bonus'] as num).toDouble();
        final label = package['label'] as String? ?? '';
        final isPopular = label.toLowerCase() == 'popular';

        return GestureDetector(
          onTap: () => setState(() => _selectedPackage = package),
          child: AnimatedContainer(
            duration: RtDuration.normal,
            padding: RtSpacing.paddingBase,
            decoration: BoxDecoration(
              color: isSelected
                  ? RtColors.brandSurface
                  : Theme.of(context).cardColor,
              borderRadius: RtRadius.borderLg,
              border: Border.all(
                color: isSelected ? RtColors.brand : RtColors.neutral300,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected ? RtShadow.soft() : null,
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: RtTypo.labelSmall.copyWith(
                        color: isPopular
                            ? RtColors.brand
                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: isPopular ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: RtSpacing.xs),
                    Text(
                      'S/. ${amount.toStringAsFixed(0)}',
                      style: RtTypo.displaySmall.copyWith(
                        color: isSelected ? RtColors.brand : null,
                      ),
                    ),
                    if (bonus > 0) ...[
                      const SizedBox(height: RtSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: RtColors.warningLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '+S/. ${bonus.toStringAsFixed(0)} gratis',
                          style: RtTypo.labelSmall.copyWith(
                            color: RtColors.warningDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (isPopular)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: RtColors.brand,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Popular',
                        style: RtTypo.labelSmall.copyWith(
                          color: RtColors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                if (isSelected)
                  const Positioned(
                    top: 0,
                    right: 0,
                    child: Icon(Icons.check_circle, color: RtColors.brand, size: 20),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentMethods() {
    return Container(
      padding: RtSpacing.paddingBase,
      decoration: BoxDecoration(
        color: RtColors.infoLight,
        borderRadius: RtRadius.borderMd,
        border: Border.all(color: RtColors.info, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.credit_card,
            color: RtColors.info,
            size: 32,
          ),
          const SizedBox(width: RtSpacing.md),
          Text(
            'Tarjeta de crédito/débito',
            style: RtTypo.headingSmall.copyWith(color: RtColors.info),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: RtColors.successLight,
              borderRadius: RtRadius.borderFull,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified, color: RtColors.success, size: 16),
                const SizedBox(width: RtSpacing.xs),
                Text(
                  'Seguro',
                  style: RtTypo.labelSmall.copyWith(color: RtColors.success),
                ),
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
      padding: RtSpacing.paddingBase,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: RtRadius.borderLg,
        border: Border.all(color: RtColors.neutral200),
        boxShadow: RtShadow.soft(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen',
            style: RtTypo.titleLarge.copyWith(fontWeight: FontWeight.bold),
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
            style: RtTypo.bodyMedium.copyWith(
              color: isBonus
                  ? RtColors.brand
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: RtTypo.bodyMedium.copyWith(
              color: isBonus ? RtColors.brand : null,
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
      padding: RtSpacing.paddingBase,
      decoration: BoxDecoration(
        color: RtColors.infoLight.withValues(alpha: 0.5),
        borderRadius: RtRadius.borderMd,
        border: Border.all(color: RtColors.info.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: RtColors.infoDark, size: 20),
              const SizedBox(width: RtSpacing.sm),
              Text(
                'Información',
                style: RtTypo.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: RtColors.infoDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: RtSpacing.sm),
          _buildInfoItem('Cada servicio aceptado consume créditos'),
          _buildInfoItem('Manten saldo suficiente para no perder viajes'),
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
          Text(
            '\u2022 ',
            style: RtTypo.bodySmall,
          ),
          Expanded(
            child: Text(
              text,
              style: RtTypo.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processPayment() async {
    if (_selectedPackage == null) return;

    final amount = (_selectedPackage!['amount'] as num).toDouble();
    final bonus = (_selectedPackage!['bonus'] as num).toDouble();

    final walletProvider = Provider.of<WalletProvider>(context, listen: false);

    // Capturar el valor ANTES de procesar el pago (Firestore lo marca false después)
    final wasFirstRecharge = walletProvider.isFirstRecharge;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: RtColors.brand),
      ),
    );

    try {
      final result = await walletProvider.processRechargeWithIzypay(
        amount: amount,
        bonus: bonus,
        context: context,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (result['success'] == true) {
        final creditStatus = await walletProvider.checkCreditStatus();
        setState(() {
          _currentCredits = (creditStatus['currentCredits'] as num?)?.toDouble() ?? 0.0;
        });

        _showSuccessDialog(amount, bonus, wasFirstRecharge: wasFirstRecharge);
      } else {
        _showErrorDialog(result['message'] ?? 'Error al procesar el pago. Intenta nuevamente.');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showErrorDialog(FirestoreErrorHandler.getSpanishMessage(e));
    }
  }

  void _showSuccessDialog(double amount, double bonus, {bool wasFirstRecharge = false}) {
    final firstRechargeBonus = wasFirstRecharge ? 5.0 : 0.0;
    final totalCredits = amount + bonus + firstRechargeBonus;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderLg),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: RtSpacing.paddingBase,
              decoration: BoxDecoration(
                color: RtColors.successLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: RtColors.success, size: 64),
            ),
            const SizedBox(height: RtSpacing.base),
            Text(
              'Recarga exitosa!',
              style: RtTypo.headingMedium,
            ),
            const SizedBox(height: RtSpacing.sm),
            Text(
              'Se han agregado S/. ${totalCredits.toStringAsFixed(2)} a tu cuenta',
              textAlign: TextAlign.center,
              style: RtTypo.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: RtSpacing.base),
            Container(
              padding: RtSpacing.paddingMd,
              decoration: BoxDecoration(
                color: RtColors.brandSurface,
                borderRadius: RtRadius.borderMd,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.account_balance_wallet, color: RtColors.brand),
                  const SizedBox(width: RtSpacing.sm),
                  Text(
                    'Nuevo saldo: S/. ${_currentCredits.toStringAsFixed(2)}',
                    style: RtTypo.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: RtColors.brand,
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
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: RtColors.brand,
                shape: RoundedRectangleBorder(borderRadius: RtRadius.borderMd),
              ),
              child: Text(
                'Aceptar',
                style: RtTypo.labelLarge.copyWith(color: RtColors.white),
              ),
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
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderLg),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: RtColors.error),
            const SizedBox(width: RtSpacing.sm),
            Text('Error', style: RtTypo.headingSmall),
          ],
        ),
        content: Text(message, style: RtTypo.bodyMedium),
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
