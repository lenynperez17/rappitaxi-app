// Formulario para crear nuevo reclamo o queja
// Cumple con Ley N 29571 - Código de Proteccion y Defensa del Consumidor (Peru)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/design/design_system.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_button.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../models/complaint_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/complaints_provider.dart';
import '../../generated/l10n/app_localizations.dart';

class NewComplaintScreen extends StatefulWidget {
  final ComplaintType initialType;

  const NewComplaintScreen({
    super.key,
    this.initialType = ComplaintType.reclamo,
  });

  @override
  State<NewComplaintScreen> createState() => _NewComplaintScreenState();
}

class _NewComplaintScreenState extends State<NewComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  late ComplaintType _selectedType;
  bool _acceptTerms = false;
  bool _isSubmitting = false;

  // Controladores de texto
  final _nameController = TextEditingController();
  final _dniController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _amountController = TextEditingController();
  final _serviceController = TextEditingController();
  final _detailController = TextEditingController();
  final _requestController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _loadUserData();
  }

  void _loadUserData() {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;

    if (user != null) {
      _nameController.text = user.fullName;
      _phoneController.text = user.phone;
      _emailController.text = user.email;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dniController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _amountController.dispose();
    _serviceController.dispose();
    _detailController.dispose();
    _requestController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: RtAppBar(
        title: _selectedType == ComplaintType.reclamo
            ? l10n.newClaim
            : l10n.newComplaint,
        variant: RtAppBarVariant.gradient,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tipo de registro
              _buildTypeSelector(theme, l10n),
              const SizedBox(height: 24),

              // Seccion: Datos del consumidor
              _buildSectionTitle(l10n.consumerData, theme),
              const SizedBox(height: 12),
              _buildConsumerFields(theme, l10n),
              const SizedBox(height: 24),

              // Seccion: Detalle del reclamo
              _buildSectionTitle(l10n.complaintDetails, theme),
              const SizedBox(height: 12),
              _buildComplaintFields(theme, l10n),
              const SizedBox(height: 24),

              // Términos y condiciones
              _buildTermsCheckbox(theme, l10n),
              const SizedBox(height: 24),

              // Boton de envio
              _buildSubmitButton(theme, l10n),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector(ThemeData theme, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.recordType,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTypeOption(
                type: ComplaintType.reclamo,
                title: l10n.claim,
                description: l10n.claimDescription,
                theme: theme,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTypeOption(
                type: ComplaintType.queja,
                title: l10n.complaint,
                description: l10n.complaintDescription,
                theme: theme,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeOption({
    required ComplaintType type,
    required String title,
    required String description,
    required ThemeData theme,
  }) {
    final isSelected = _selectedType == type;
    final color =
        type == ComplaintType.reclamo ? RtColors.warning : RtColors.info;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedType = type;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : theme.colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            // Indicador visual de seleccion
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? color : theme.colorScheme.outline.withValues(alpha: 0.5),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isSelected ? color : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: RtColors.brand.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: RtColors.brand,
        ),
      ),
    );
  }

  Widget _buildConsumerFields(ThemeData theme, AppLocalizations l10n) {
    return Column(
      children: [
        // Nombre completo
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: l10n.fullName,
            prefixIcon: const Icon(Icons.person_outline),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return l10n.requiredField;
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // DNI
        TextFormField(
          controller: _dniController,
          decoration: InputDecoration(
            labelText: l10n.dniDocument,
            prefixIcon: const Icon(Icons.badge_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(8),
          ],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return l10n.requiredField;
            }
            if (value.length < 8) {
              return l10n.invalidDni;
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Dirección
        TextFormField(
          controller: _addressController,
          decoration: InputDecoration(
            labelText: l10n.address,
            prefixIcon: const Icon(Icons.location_on_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          maxLines: 2,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return l10n.requiredField;
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Teléfono y Email en row
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: l10n.phone,
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.requiredField;
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: l10n.email,
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.requiredField;
                  }
                  if (!value.contains('@')) {
                    return l10n.invalidEmail;
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildComplaintFields(ThemeData theme, AppLocalizations l10n) {
    return Column(
      children: [
        // Monto reclamado (opcional)
        TextFormField(
          controller: _amountController,
          decoration: InputDecoration(
            labelText: l10n.claimedAmount,
            prefixIcon: const Icon(Icons.attach_money),
            hintText: l10n.optional,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
        ),
        const SizedBox(height: 16),

        // Descripción del servicio
        TextFormField(
          controller: _serviceController,
          decoration: InputDecoration(
            labelText: l10n.serviceDescription,
            prefixIcon: const Icon(Icons.description_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          maxLines: 2,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return l10n.requiredField;
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Detalle del reclamo
        TextFormField(
          controller: _detailController,
          decoration: InputDecoration(
            labelText: l10n.complaintDetail,
            prefixIcon: const Icon(Icons.edit_note),
            helperText: l10n.minCharacters(50),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          maxLines: 4,
          maxLength: 1000,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return l10n.requiredField;
            }
            if (value.length < 50) {
              return l10n.minCharactersError(50);
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Pedido del consumidor
        TextFormField(
          controller: _requestController,
          decoration: InputDecoration(
            labelText: l10n.consumerRequest,
            prefixIcon: const Icon(Icons.request_quote_outlined),
            hintText: l10n.consumerRequestHint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          maxLines: 3,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return l10n.requiredField;
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildTermsCheckbox(ThemeData theme, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _acceptTerms,
            onChanged: (value) {
              setState(() {
                _acceptTerms = value ?? false;
              });
            },
            activeColor: RtColors.brand,
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _acceptTerms = !_acceptTerms;
                });
              },
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  l10n.complaintTermsAcceptance,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(ThemeData theme, AppLocalizations l10n) {
    return RtButton(
      label: _selectedType == ComplaintType.reclamo
          ? l10n.submitClaim
          : l10n.submitComplaint,
      onPressed: _isSubmitting || !_acceptTerms ? null : _submitComplaint,
      isLoading: _isSubmitting,
    );
  }

  Future<void> _submitComplaint() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_acceptTerms) {
      RtSnackbar.show(context, message: AppLocalizations.of(context)!.mustAcceptTerms, type: RtSnackbarType.error);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final provider = context.read<ComplaintsProvider>();
    final l10n = AppLocalizations.of(context)!;

    final complaint = await provider.createComplaint(
      type: _selectedType,
      consumerName: _nameController.text.trim(),
      consumerDni: _dniController.text.trim(),
      consumerAddress: _addressController.text.trim(),
      consumerPhone: _phoneController.text.trim(),
      consumerEmail: _emailController.text.trim(),
      claimedAmount: _amountController.text.isNotEmpty
          ? double.tryParse(_amountController.text)
          : null,
      serviceDescription: _serviceController.text.trim(),
      complaintDetail: _detailController.text.trim(),
      consumerRequest: _requestController.text.trim(),
    );

    setState(() {
      _isSubmitting = false;
    });

    if (!mounted) return;

    if (complaint != null) {
      // Mostrar éxito y regresar
      RtSnackbar.show(context, message: '${l10n.complaintCreated} ${complaint.complaintNumber}', type: RtSnackbarType.success);
      Navigator.pop(context);
    } else if (provider.error != null) {
      RtSnackbar.show(context, message: provider.error!, type: RtSnackbarType.error);
    }
  }
}
