import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/oasis_button.dart';
import '../../../../shared/models/user_model.dart';
import '../../domain/entities/payment_method.dart' as pm;
import '../providers/payment_provider.dart';

class PaymentMethodsScreen extends ConsumerWidget {
  const PaymentMethodsScreen({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentMethodsAsync = ref.watch(paymentMethodsProvider);
    
    return Scaffold(
      // backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Métodos de pago'),
        // backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: paymentMethodsAsync.when(
        data: (methods) => _buildContent(context, ref, methods),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Error al cargar métodos de pago',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OasisButton(
                text: 'Reintentar',
                onPressed: () => ref.invalidate(paymentMethodsProvider),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, -2),
              blurRadius: 10,
            ),
          ],
        ),
        child: SafeArea(
          child: OasisButton(
            text: 'Agregar método de pago',
            onPressed: () => context.push('/profile/payment-methods/add'),
            icon: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ),
    );
  }
  
  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<pm.PaymentMethod> methods,
  ) {
    if (methods.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.payment_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No tienes métodos de pago',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega un método de pago para realizar viajes',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: methods.length,
      itemBuilder: (context, index) {
        final method = methods[index];
        return _PaymentMethodCard(
          method: method,
          onTap: () => _handleMethodTap(context, ref, method),
          onSetDefault: method.type != 'cash' && !method.isDefault
              ? () => _handleSetDefault(context, ref, method)
              : null,
          onRemove: method.type != 'cash'
              ? () => _handleRemove(context, ref, method)
              : null,
        ).animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.1, end: 0);
      },
    );
  }
  
  Future<void> _handleMethodTap(
    BuildContext context,
    WidgetRef ref,
    pm.PaymentMethod method,
  ) async {
    // Por ahora solo seleccionar
    ref.read(selectedPaymentMethodProvider.notifier).state = method;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_getMethodName(method)} seleccionado'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  Future<void> _handleSetDefault(
    BuildContext context,
    WidgetRef ref,
    pm.PaymentMethod method,
  ) async {
    try {
      await ref.read(setDefaultPaymentMethodProvider(method.id).future);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Método de pago predeterminado actualizado'),
            // backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            // backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
  
  Future<void> _handleRemove(
    BuildContext context,
    WidgetRef ref,
    pm.PaymentMethod method,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar método de pago'),
        content: Text(
          '¿Estás seguro de eliminar ${_getMethodName(method)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    
    if (confirm == true && context.mounted) {
      try {
        await ref.read(removePaymentMethodProvider(method.id).future);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Método de pago eliminado'),
              // backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              // backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }
  
  String _getMethodName(pm.PaymentMethod method) {
    switch (method.type) {
      case 'cash':
        return 'Efectivo';
      case 'card':
        return '${method.cardBrand ?? 'Tarjeta'} ****${method.cardLast4}';
      case 'mercadopago':
        return 'Mercado Pago';
      case 'yape':
        return 'Yape';
      default:
        return method.type;
    }
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final pm.PaymentMethod method;
  final VoidCallback onTap;
  final VoidCallback? onSetDefault;
  final VoidCallback? onRemove;
  
  const _PaymentMethodCard({
    required this.method,
    required this.onTap,
    this.onSetDefault,
    this.onRemove,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: method.isDefault ? AppTheme.primaryColor : Colors.grey[300]!,
          width: method.isDefault ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icono
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getIconColor(method.type).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getIcon(method.type),
                  color: _getIconColor(method.type),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              
              // Información
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _getTitle(method),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (method.isDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Predeterminado',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getSubtitle(method),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Acciones
              if (onSetDefault != null || onRemove != null)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'default' && onSetDefault != null) {
                      onSetDefault!();
                    } else if (value == 'remove' && onRemove != null) {
                      onRemove!();
                    }
                  },
                  itemBuilder: (context) => [
                    if (onSetDefault != null)
                      const PopupMenuItem(
                        value: 'default',
                        child: Row(
                          children: [
                            Icon(Icons.star_outline, size: 20),
                            SizedBox(width: 12),
                            Text('Establecer como predeterminado'),
                          ],
                        ),
                      ),
                    if (onRemove != null)
                      const PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 20, color: Colors.red),
                            SizedBox(width: 12),
                            Text('Eliminar', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  IconData _getIcon(String type) {
    switch (type) {
      case 'cash':
        return Icons.money;
      case 'card':
        return Icons.credit_card;
      case 'mercadopago':
        return Icons.account_balance_wallet;
      case 'yape':
        return Icons.phone_android;
      default:
        return Icons.payment;
    }
  }
  
  Color _getIconColor(String type) {
    switch (type) {
      case 'cash':
        return Colors.green;
      case 'card':
        return Colors.blue;
      case 'mercadopago':
        return Colors.lightBlue;
      case 'yape':
        return Colors.purple;
      default:
        return AppTheme.primaryColor;
    }
  }
  
  String _getTitle(pm.PaymentMethod method) {
    switch (method.type) {
      case 'cash':
        return 'Efectivo';
      case 'card':
        return method.cardBrand ?? 'Tarjeta';
      case 'mercadopago':
        return 'Mercado Pago';
      case 'yape':
        return 'Yape';
      default:
        return method.type;
    }
  }
  
  String _getSubtitle(pm.PaymentMethod method) {
    switch (method.type) {
      case 'cash':
        return 'Paga al finalizar el viaje';
      case 'card':
        return '•••• ${method.cardLast4}';
      case 'mercadopago':
        return method.metadata?['email'] ?? 'Cuenta vinculada';
      case 'yape':
        return method.metadata?['phone'] ?? 'Número vinculado';
      default:
        return '';
    }
  }
}