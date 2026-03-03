// Pantalla principal del Libro de Reclamaciones
// Cumple con Ley N 29571 - Código de Proteccion y Defensa del Consumidor (Peru)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/design/design_system.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_button.dart';
import '../../models/complaint_model.dart';
import '../../providers/complaints_provider.dart';
import '../../generated/l10n/app_localizations.dart';
import 'new_complaint_screen.dart';
import 'complaint_detail_screen.dart';

class ComplaintsBookScreen extends StatefulWidget {
  const ComplaintsBookScreen({super.key});

  @override
  State<ComplaintsBookScreen> createState() => _ComplaintsBookScreenState();
}

class _ComplaintsBookScreenState extends State<ComplaintsBookScreen> {
  @override
  void initState() {
    super.initState();
    // Cargar reclamos del usuario al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ComplaintsProvider>().loadUserComplaints();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: RtAppBar(
        title: l10n.complaintsBook,
        variant: RtAppBarVariant.gradient,
      ),
      body: Consumer<ComplaintsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            color: RtColors.brand,
            backgroundColor: Theme.of(context).colorScheme.surface,
            onRefresh: () => provider.loadUserComplaints(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Banner informativo legal
                  _buildLegalInfoBanner(theme, l10n),
                  const SizedBox(height: 20),

                  // Botones para nuevo reclamo/queja
                  _buildActionButtons(context, l10n),
                  const SizedBox(height: 24),

                  // Error si existe
                  if (provider.error != null)
                    _buildErrorBanner(provider.error!, theme),

                  // Lista de reclamos
                  _buildComplaintsList(provider, theme, l10n),
                  const SizedBox(height: 24),

                  // Información del proveedor
                  _buildProviderInfo(theme, l10n),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLegalInfoBanner(ThemeData theme, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RtColors.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RtColors.info.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: RtColors.info, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.legalInformation,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: RtColors.info,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.complaintsLegalInfo,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.complaintsLaw,
            style: theme.textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: RtButton(
            label: l10n.newClaim,
            icon: Icons.report_problem_outlined,
            onPressed: () => _navigateToNewComplaint(ComplaintType.reclamo),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: RtButton(
            label: l10n.newComplaint,
            icon: Icons.feedback_outlined,
            variant: RtButtonVariant.outlined,
            onPressed: () => _navigateToNewComplaint(ComplaintType.queja),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String error, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RtColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: RtColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: RtColors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: RtColors.error,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () {
              context.read<ComplaintsProvider>().clearError();
            },
            color: RtColors.error,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildComplaintsList(
    ComplaintsProvider provider,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.myComplaints,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (provider.complaints.isNotEmpty)
              Text(
                '${provider.complaints.length} ${l10n.records}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (provider.complaints.isEmpty)
          _buildEmptyState(theme, l10n)
        else
          ...provider.complaints.map((complaint) => _buildComplaintCard(
                complaint,
                theme,
                l10n,
              )),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noComplaints,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.noComplaintsDescription,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildComplaintCard(
    ComplaintRecord complaint,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: InkWell(
        onTap: () => _navigateToDetail(complaint),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado con número y estado
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    complaint.complaintNumber,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  _buildStatusChip(complaint, theme, l10n),
                ],
              ),
              const SizedBox(height: 8),

              // Tipo y fecha
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: complaint.type == ComplaintType.reclamo
                          ? RtColors.warning.withValues(alpha: 0.1)
                          : RtColors.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      complaint.typeDisplayName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: complaint.type == ComplaintType.reclamo
                            ? RtColors.warning
                            : RtColors.info,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    dateFormat.format(complaint.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Descripción truncada
              Text(
                complaint.complaintDetail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),

              // Indicador de vencimiento si aplica
              if (complaint.requiresResponse &&
                  complaint.status != ComplaintStatus.resolved &&
                  complaint.status != ComplaintStatus.closed)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        complaint.isOverdue
                            ? Icons.warning_amber_rounded
                            : Icons.schedule,
                        size: 16,
                        color: complaint.isOverdue
                            ? RtColors.error
                            : RtColors.warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        complaint.isOverdue
                            ? l10n.overdueResponse
                            : '${complaint.daysToRespond} ${l10n.daysToRespond}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: complaint.isOverdue
                              ? RtColors.error
                              : RtColors.warning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(
    ComplaintRecord complaint,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    Color backgroundColor;
    Color textColor;

    switch (complaint.status) {
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            complaint.statusEmoji,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 4),
          Text(
            complaint.statusDisplayName,
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderInfo(ThemeData theme, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.providerData,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          _buildProviderRow(
            Icons.business,
            ProviderInfo.name,
            theme,
          ),
          const SizedBox(height: 8),
          _buildProviderRow(
            Icons.badge_outlined,
            'RUC: ${ProviderInfo.ruc}',
            theme,
          ),
          const SizedBox(height: 8),
          _buildProviderRow(
            Icons.location_on_outlined,
            ProviderInfo.address,
            theme,
          ),
        ],
      ),
    );
  }

  Widget _buildProviderRow(IconData icon, String text, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }

  void _navigateToNewComplaint(ComplaintType type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewComplaintScreen(initialType: type),
      ),
    );
  }

  void _navigateToDetail(ComplaintRecord complaint) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ComplaintDetailScreen(complaint: complaint),
      ),
    );
  }
}
