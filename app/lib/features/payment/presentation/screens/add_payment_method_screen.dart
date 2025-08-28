import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/oasis_button.dart';
import '../../../../core/widgets/oasis_text_field.dart';
import '../providers/payment_provider.dart';

class AddPaymentMethodScreen extends ConsumerStatefulWidget {
  const AddPaymentMethodScreen({super.key});
  
  @override
  ConsumerState<AddPaymentMethodScreen> createState() => _AddPaymentMethodScreenState();
}

class _AddPaymentMethodScreenState extends ConsumerState<AddPaymentMethodScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  String _selectedMethod = 'card';
  bool _isLoading = false;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Agregar método de pago'),
        // backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Selector de método
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selecciona un método',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _MethodOption(
                          icon: Icons.credit_card,
                          title: 'Tarjeta',
                          subtitle: 'Débito o crédito',
                          isSelected: _selectedMethod == 'card',
                          onTap: () => setState(() => _selectedMethod = 'card'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MethodOption(
                          icon: Icons.account_balance_wallet,
                          title: 'Mercado Pago',
                          subtitle: 'Cuenta vinculada',
                          isSelected: _selectedMethod == 'mercadopago',
                          onTap: () => setState(() => _selectedMethod = 'mercadopago'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Formulario según método seleccionado
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: FormBuilder(
                key: _formKey,
                child: _selectedMethod == 'card'
                    ? _buildCardForm()
                    : _buildMercadoPagoForm(),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Botón de guardar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OasisButton(
                text: 'Agregar método de pago',
                onPressed: _isLoading ? () {} : () => _handleSubmit(),
                isLoading: _isLoading,
              ),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCardForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Información de la tarjeta',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        
        // Número de tarjeta
        OasisTextField(
          name: 'cardNumber',
          label: 'Número de tarjeta',
          hintText: '1234 5678 9012 3456',
          keyboardType: TextInputType.number,
          prefixIcon: Icons.credit_card,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            _CardNumberFormatter(),
          ],
          validators: [
            FormBuilderValidators.required(
              errorText: 'El número de tarjeta es requerido',
            ),
            FormBuilderValidators.creditCard(
              errorText: 'Número de tarjeta inválido',
            ),
          ],
        ).animate().fadeIn(delay: 100.ms).slideX(begin: 0.1, end: 0),
        
        const SizedBox(height: 16),
        
        // Nombre del titular
        OasisTextField(
          name: 'cardholderName',
          label: 'Nombre del titular',
          hintText: 'Como aparece en la tarjeta',
          keyboardType: TextInputType.name,
          textCapitalization: TextCapitalization.characters,
          prefixIcon: Icons.person_outline,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
          ],
          validators: [
            FormBuilderValidators.required(
              errorText: 'El nombre es requerido',
            ),
            FormBuilderValidators.minLength(
              3,
              errorText: 'Nombre muy corto',
            ),
          ],
        ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.1, end: 0),
        
        const SizedBox(height: 16),
        
        // Fecha de vencimiento y CVV
        Row(
          children: [
            Expanded(
              flex: 2,
              child: OasisTextField(
                name: 'expiryDate',
                label: 'Vencimiento',
                hintText: 'MM/YY',
                keyboardType: TextInputType.number,
                prefixIcon: Icons.calendar_today,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _CardExpiryFormatter(),
                ],
                validators: [
                  FormBuilderValidators.required(
                    errorText: 'Requerido',
                  ),
                  (value) {
                    if (value == null || value.length != 5) {
                      return 'Formato MM/YY';
                    }
                    final parts = value.split('/');
                    final month = int.tryParse(parts[0]) ?? 0;
                    final year = int.tryParse(parts[1]) ?? 0;
                    
                    if (month < 1 || month > 12) {
                      return 'Mes inválido';
                    }
                    
                    final now = DateTime.now();
                    final expiry = DateTime(2000 + year, month);
                    
                    if (expiry.isBefore(now)) {
                      return 'Tarjeta vencida';
                    }
                    
                    return null;
                  },
                ],
              ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.1, end: 0),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OasisTextField(
                name: 'cvv',
                label: 'CVV',
                hintText: '123',
                keyboardType: TextInputType.number,
                obscureText: true,
                prefixIcon: Icons.lock_outline,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                validators: [
                  FormBuilderValidators.required(
                    errorText: 'Requerido',
                  ),
                  FormBuilderValidators.minLength(
                    3,
                    errorText: 'Mínimo 3',
                  ),
                ],
              ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1, end: 0),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Información de seguridad
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lock,
                size: 20,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tu información está protegida con encriptación de extremo a extremo',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 500.ms),
      ],
    );
  }
  
  Widget _buildMercadoPagoForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vincular cuenta de Mercado Pago',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        
        // Email de Mercado Pago
        OasisTextField(
          name: 'mercadopagoEmail',
          label: 'Correo de Mercado Pago',
          hintText: 'correo@ejemplo.com',
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.email_outlined,
          validators: [
            FormBuilderValidators.required(
              errorText: 'El correo es requerido',
            ),
            FormBuilderValidators.email(
              errorText: 'Ingresa un correo válido',
            ),
          ],
        ).animate().fadeIn(delay: 100.ms).slideX(begin: 0.1, end: 0),
        
        const SizedBox(height: 24),
        
        // Información
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.lightBlue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.lightBlue.withOpacity(0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: Colors.lightBlue[700],
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Cómo funciona',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.lightBlue[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '1. Ingresa el correo de tu cuenta de Mercado Pago\n'
                '2. Te redirigiremos para autorizar el pago\n'
                '3. Los pagos se cargarán automáticamente a tu cuenta',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ).animate().fadeIn(delay: 200.ms),
      ],
    );
  }
  
  Future<void> _handleSubmit() async {
    if (_formKey.currentState?.saveAndValidate() ?? false) {
      setState(() => _isLoading = true);
      
      try {
        final values = _formKey.currentState!.value;
        
        if (_selectedMethod == 'card') {
          final expiryParts = values['expiryDate'].split('/');
          
          await ref.read(addCreditCardProvider(
            AddCardParams(
              cardNumber: values['cardNumber'],
              cardholderName: values['cardholderName'],
              expiryMonth: expiryParts[0],
              expiryYear: expiryParts[1],
              cvv: values['cvv'],
            ),
          ).future);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tarjeta agregada exitosamente'),
                // backgroundColor: AppTheme.successColor,
              ),
            );
            context.pop();
          }
        } else {
          // TODO: Implementar Mercado Pago OAuth
          await ref.read(paymentRepositoryProvider).addMercadoPagoAccount(
            email: values['mercadopagoEmail'],
          );
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cuenta de Mercado Pago vinculada'),
                // backgroundColor: AppTheme.successColor,
              ),
            );
            context.pop();
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              // backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }
}

class _MethodOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  
  const _MethodOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.primaryColor.withOpacity(0.05)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected
                  ? AppTheme.primaryColor
                  : Colors.grey[600],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: isSelected
                    ? AppTheme.primaryColor
                    : Colors.grey[800],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Formateador para número de tarjeta
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(text[i]);
    }
    
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// Formateador para fecha de vencimiento
class _CardExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll('/', '');
    final buffer = StringBuffer();
    
    for (int i = 0; i < text.length && i < 4; i++) {
      if (i == 2) {
        buffer.write('/');
      }
      buffer.write(text[i]);
    }
    
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}