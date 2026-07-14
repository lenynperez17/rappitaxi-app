import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive_bottom_sheet.dart';
import '../../core/l10n/driver_strings.dart';
import '../../services/rapi_api_client.dart';
import 'driver_recharge_screen.dart';

class DriverWalletSimpleScreen extends StatefulWidget {
  const DriverWalletSimpleScreen({super.key});

  @override
  State<DriverWalletSimpleScreen> createState() => _DriverWalletSimpleScreenState();
}

class _DriverWalletSimpleScreenState extends State<DriverWalletSimpleScreen> {
  double _balance = 0.0;
  double _commissionRate = 10.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  Future<void> _loadWalletData() async {
    try {
      // Balance de la billetera desde el backend Node.
      double balance = 0;
      try {
        final w = await RapiApiClient.instance.walletBalance();
        final b = w['balance'] ?? w['serviceCredits'];
        if (b is num) balance = b.toDouble();
      } catch (_) {}

      // TODO(node-migration): reemplazar con endpoint /api/config/rates cuando
      // exista. Por ahora usamos el default (10%).
      const commissionRate = 10.0;

      if (mounted) {
        setState(() {
          _balance = balance;
          _commissionRate = commissionRate;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showInfoSheet(String title, String body, String understoodLabel) {
    showResponsiveBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
            const SizedBox(height: 12),
            Text(body, style: TextStyle(fontSize: 15, color: AppColors.getTextSecondary(context), height: 1.5)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.rappiRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(understoodLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ds = DriverStrings(Localizations.localeOf(context).languageCode);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back, size: 28, color: AppColors.getTextPrimary(context)),
                  ),
                ],
              ),
            ),

            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),

                      // Commission info card
                      GestureDetector(
                        onTap: () => _showInfoSheet(
                          ds.serviceCommission,
                          ds.serviceCommissionDesc(_commissionRate.toStringAsFixed(2)),
                          ds.understood,
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          decoration: BoxDecoration(
                            color: AppColors.getSurface(context),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.getBorder(context).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.credit_card, size: 24, color: AppColors.getTextSecondary(context)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  ds.serviceRateFair(_commissionRate.toStringAsFixed(2)),
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.getTextPrimary(context)),
                                ),
                              ),
                              Icon(Icons.chevron_right, color: AppColors.getTextSecondary(context)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Balance card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.getSurface(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.getBorder(context).withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Saldo header
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.rappiRed.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.monetization_on, color: AppColors.rappiRed, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Text(ds.balance, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.getTextPrimary(context))),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () => _showInfoSheet(
                                    ds.walletBalanceTitle,
                                    ds.walletBalanceDesc(''),
                                    ds.understood,
                                  ),
                                  child: Icon(Icons.help_outline, color: AppColors.getTextSecondary(context), size: 22),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Balance amount
                            Row(
                              children: [
                                Text(
                                  'S/ ${_balance.toStringAsFixed(2)}',
                                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: AppColors.getTextPrimary(context)),
                                ),
                                const Spacer(),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Recargar button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () async {
                                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverRechargeScreen()));
                                  _loadWalletData(); // Refresh balance after returning
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.rappiRed,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: Text(ds.recharge, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Métodos de pago
                      GestureDetector(
                        onTap: () => _showInfoSheet(
                          ds.paymentMethods,
                          ds.paymentMethodsDesc,
                          ds.understood,
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          decoration: BoxDecoration(
                            color: AppColors.getSurface(context),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.getBorder(context).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.payment, size: 24, color: AppColors.getTextSecondary(context)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(ds.paymentMethods, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
                              ),
                              Icon(Icons.chevron_right, color: AppColors.getTextSecondary(context)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Historial de transacciones
                      GestureDetector(
                        onTap: () => _showInfoSheet(
                          ds.transactionHistory,
                          ds.transactionHistoryDesc,
                          ds.understood,
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          decoration: BoxDecoration(
                            color: AppColors.getSurface(context),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.getBorder(context).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 24, color: AppColors.getTextSecondary(context)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(ds.transactionHistory, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
                              ),
                              Icon(Icons.chevron_right, color: AppColors.getTextSecondary(context)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
