// Pantalla de detalle de un reclamo o queja
// Cumple con Ley N 29571 - Código de Proteccion y Defensa del Consumidor (Peru)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/design/design_system.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../models/complaint_model.dart';
import '../../providers/complaints_provider.dart';
import '../../generated/l10n/app_localizations.dart';

class ComplaintDetailScreen extends StatefulWidget {
  final ComplaintRecord complaint;

  const ComplaintDetailScreen({
    super.key,
    required this.complaint,
  });

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  late ComplaintRecord _complaint;

  @override
  void initState() {
    super.initState();
    _complaint = widget.complaint;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: RtAppBar(
        title: _complaint.complaintNumber,
        variant: RtAppBarVariant.gradient,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy, color: RtColors.white),
            tooltip: l10n.copyNumber,
            onPressed: () {
              Clipboard.setData(
                ClipboardData(text: _complaint.complaintNumber),
              );
              RtSnackbar.show(context, message: l10n.numberCopied, type: RtSnackbarType.success);
            },
          ),
        ],
      ),
      body: StreamBuilder<ComplaintRecord?>(
        stream: context
            .read<ComplaintsProvider>()
            .watchComplaint(_complaint.id),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            _complaint = snapshot.data!;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Estado y tipo
                _buildHeaderCard(theme, l10n, dateFormat),
                const SizedBox(height: 16),

                // Datos del consumidor
                _buildSection(
                  title: l10n.consumerData,
                  icon: Icons.person_outline,
                  theme: theme,
                  children: [
                    _buildInfoRow(l10n.fullName, _complaint.consumerName, theme),
                    _buildInfoRow(l10n.dniDocument, _complaint.consumerDni, theme),
                    _buildInfoRow(l10n.address, _complaint.consumerAddress, theme),
                    _buildInfoRow(l10n.phone, _complaint.consumerPhone, theme),
                    _buildInfoRow(l10n.email, _complaint.consumerEmail, theme),
                  ],
                ),
                const SizedBox(height: 16),

                // Detalle del reclamo
                _buildSection(
                  title: l10n.complaintDetails,
                  icon: Icons.description_outlined,
                  theme: theme,
                  children: [
                    if (_complaint.claimedAmount != null)
                      _buildInfoRow(
                        l10n.claimedAmount,
                        'S/ ${_complaint.claimedAmount!.toStringAsFixed(2)}',
                        theme,
                      ),
                    _buildInfoRow(
                      l10n.serviceDescription,
                      _complaint.serviceDescription,
                      theme,
                    ),
                    _buildDetailBox(
                      l10n.complaintDetail,
                      _complaint.complaintDetail,
                      theme,
                    ),
                    _buildDetailBox(
                      l10n.consumerRequest,
                      _complaint.consumerRequest,
                      theme,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Respuesta del proveedor (si existe)
                if (_complaint.adminResponse != null)
                  _buildSection(
                    title: l10n.providerResponse,
                    icon: Icons.reply_outlined,
                    theme: theme,
                    color: RtColors.success,
                    children: [
                      if (_complaint.responseDate != null)
                        _buildInfoRow(
                          l10n.responseDate,
                          dateFormat.format(_complaint.responseDate!),
                          theme,
                        ),
                      _buildDetailBox(
                        l10n.response,
                        _complaint.adminResponse!,
                        theme,
                        color: RtColors.success,
                      ),
                    ],
                  ),

                // Datos del proveedor
                if (_complaint.adminResponse == null)
                  const SizedBox(height: 16),
                _buildSection(
                  title: l10n.providerData,
                  icon: Icons.business_outlined,
                  theme: theme,
                  children: [
                    _buildInfoRow(l10n.businessName, _complaint.providerName, theme),
                    _buildInfoRow('RUC', _complaint.providerRuc, theme),
                    _buildInfoRow(l10n.address, _complaint.providerAddress, theme),
                  ],
                ),
                const SizedBox(height: 16),

                // Información legal
                _buildLegalInfo(theme, l10n),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(
    ThemeData theme,
    AppLocalizations l10n,
    DateFormat dateFormat,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Tipo y estado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Tipo de registro
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _complaint.type == ComplaintType.reclamo
                        ? RtColors.warning.withValues(alpha: 0.1)
                        : RtColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _complaint.type == ComplaintType.reclamo
                            ? Icons.report_problem_outlined
                            : Icons.feedback_outlined,
                        size: 18,
                        color: _complaint.type == ComplaintType.reclamo
                            ? RtColors.warning
                            : RtColors.info,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _complaint.typeDisplayName,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: _complaint.type == ComplaintType.reclamo
                              ? RtColors.warning
                              : RtColors.info,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Estado
                _buildStatusBadge(theme, l10n),
              ],
            ),
            const SizedBox(height: 16),

            // Fechas
            Row(
              children: [
                Expanded(
                  child: _buildDateInfo(
                    l10n.createdDate,
                    dateFormat.format(_complaint.createdAt),
                    Icons.calendar_today_outlined,
                    theme,
                  ),
                ),
                if (_complaint.resolvedDate != null)
                  Expanded(
                    child: _buildDateInfo(
                      l10n.resolvedDate,
                      dateFormat.format(_complaint.resolvedDate!),
                      Icons.check_circle_outline,
                      theme,
                    ),
                  ),
              ],
            ),

            // Indicador de tiempo si es reclamo pendiente
            if (_complaint.requiresResponse &&
                _complaint.status != ComplaintStatus.resolved &&
                _complaint.status != ComplaintStatus.closed)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _complaint.isOverdue
                        ? RtColors.error.withValues(alpha: 0.1)
                        : RtColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _complaint.isOverdue
                            ? Icons.warning_amber_rounded
                            : Icons.schedule,
                        color: _complaint.isOverdue
                            ? RtColors.error
                            : RtColors.warning,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _complaint.isOverdue
                                  ? l10n.responseOverdue
                                  : l10n.pendingResponse,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _complaint.isOverdue
                                    ? RtColors.error
                                    : RtColors.warning,
                              ),
                            ),
                            Text(
                              _complaint.isOverdue
                                  ? l10n.overdueDescription
                                  : '${_complaint.daysToRespond} ${l10n.daysRemaining}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
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

  Widget _buildStatusBadge(ThemeData theme, AppLocalizations l10n) {
    Color backgroundColor;
    Color textColor;

    switch (_complaint.status) {
      case ComplaintStatus.pending:
        backgroundColor = RtColors.warning.withValues(alpha: 0.1);
        textColor = RtColors.warning;
        break;
      case ComplaintStatus.inReview:
        backgroundColor = RtColors.info.withValues(alpha: 0.1);
        textColor = RtColors.info;
        break;
      case ComplaintStatus.resolved:
        backgroundColor = RtColors.success.withValues(alpha: 0.1);
        textColor = RtColors.success;
        break;
      case ComplaintStatus.closed:
        backgroundColor = theme.colorScheme.outline.withValues(alpha: 0.1);
        textColor = theme.colorScheme.outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _complaint.statusEmoji,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 6),
          Text(
            _complaint.statusDisplayName,
            style: theme.textTheme.labelLarge?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateInfo(
    String label,
    String value,
    IconData icon,
    ThemeData theme,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required ThemeData theme,
    required List<Widget> children,
    Color? color,
  }) {
    final sectionColor = color ?? RtColors.brand;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Encabezado de seccion
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: sectionColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: sectionColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: sectionColor,
                  ),
                ),
              ],
            ),
          ),
          // Contenido
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailBox(
    String label,
    String value,
    ThemeData theme, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color ?? theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: color != null
                  ? Border.all(color: color.withValues(alpha: 0.3))
                  : null,
            ),
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalInfo(ThemeData theme, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.gavel_outlined,
            size: 18,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.complaintLegalNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
