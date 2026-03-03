import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/design/rt_colors.dart';
import '../../core/design/rt_tokens.dart';
import '../../core/design/rt_typography.dart';
import '../../core/widgets/rt_animated_list_item.dart';
import '../../core/widgets/rt_app_bar.dart';
import '../../core/widgets/rt_avatar.dart';
import '../../core/widgets/rt_badge.dart';
import '../../core/widgets/rt_card.dart';
import '../../core/widgets/rt_empty_state.dart';
import '../../core/widgets/rt_snackbar.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../utils/logger.dart';

// ============================================================
// Modelo de datos
// ============================================================

class RatingData {
  final String id;
  final String tripId;
  final String driverName;
  final String driverPhoto;
  final DateTime date;
  final int rating;
  final String? comment;
  final List<String> tags;
  final String route;
  final double tripAmount;

  RatingData({
    required this.id,
    required this.tripId,
    required this.driverName,
    required this.driverPhoto,
    required this.date,
    required this.rating,
    this.comment,
    required this.tags,
    required this.route,
    required this.tripAmount,
  });
}

// ============================================================
// Pantalla principal
// ============================================================

class RatingsHistoryScreen extends StatefulWidget {
  const RatingsHistoryScreen({super.key});

  @override
  State<RatingsHistoryScreen> createState() => _RatingsHistoryScreenState();
}

class _RatingsHistoryScreenState extends State<RatingsHistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _userId;
  bool _isLoading = true;
  String _selectedFilter = 'all';
  List<RatingData> _ratings = [];

  List<RatingData> get _filteredRatings {
    if (_selectedFilter == 'all') return _ratings;
    final filterValue = int.parse(_selectedFilter);
    return _ratings.where((r) => r.rating == filterValue).toList();
  }

  Map<String, dynamic> get _statistics {
    final totalRatings = _ratings.length;
    final avgRating = totalRatings > 0
        ? _ratings.fold<double>(0, (total, r) => total + r.rating) / totalRatings
        : 0.0;

    final ratingCounts = <int, int>{};
    for (final rating in _ratings) {
      ratingCounts[rating.rating] = (ratingCounts[rating.rating] ?? 0) + 1;
    }

    return {
      'total': totalRatings,
      'average': avgRating,
      'counts': ratingCounts,
    };
  }

  @override
  void initState() {
    super.initState();
    _loadRatingsFromFirebase();
  }

  Future<void> _loadRatingsFromFirebase() async {
    try {
      setState(() => _isLoading = true);

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          RtSnackbar.show(
            context,
            message: AppLocalizations.of(context)!.userNotAuthenticated,
            type: RtSnackbarType.error,
          );
        }
        return;
      }
      _userId = currentUser.uid;

      final ridesSnapshot = await _firestore
          .collection('rides')
          .where('passengerId', isEqualTo: _userId)
          .where('rating', isNotEqualTo: null)
          .orderBy('rating')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final List<RatingData> loadedRatings = [];

      for (final doc in ridesSnapshot.docs) {
        final data = doc.data();

        // Obtener información del conductor
        String driverName = 'Conductor';
        String driverPhoto = '';

        if (data['driverId'] != null) {
          try {
            final driverDoc = await _firestore
                .collection('users')
                .doc(data['driverId'])
                .get();

            if (driverDoc.exists) {
              final driverData = driverDoc.data()!;
              driverName = '${driverData['firstName'] ?? ''} ${driverData['lastName'] ?? ''}'.trim();
              if (driverName.isEmpty) driverName = 'Conductor';
              driverPhoto = driverData['profileImage'] ?? '';
            }
          } catch (e) {
            AppLogger.error('Error obteniendo datos del conductor: $e');
          }
        }

        // Tags basados en la calificación
        List<String> tags = [];
        final rating = data['rating'] ?? 0;
        if (rating >= 5) {
          tags = ['excellentService', 'verySatisfied'];
        } else if (rating >= 4) {
          tags = ['goodService', 'satisfied'];
        } else if (rating >= 3) {
          tags = ['regularService', 'acceptable'];
        } else {
          tags = ['needsImprovement', 'dissatisfied'];
        }

        loadedRatings.add(RatingData(
          id: doc.id,
          tripId: doc.id,
          driverName: driverName,
          driverPhoto: driverPhoto,
          date: data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
          rating: data['rating'] ?? 0,
          comment: data['ratingComment'] ?? '',
          tags: tags,
          route: '${data['pickupAddress'] ?? 'Origen'} -> ${data['destinationAddress'] ?? 'Destino'}',
          tripAmount: (data['fare'] ?? 0.0).toDouble(),
        ));
      }

      setState(() {
        _ratings = loadedRatings;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('Error cargando calificaciones: $e');
      setState(() => _isLoading = false);
      if (!mounted) return;

      final errorStr = e.toString();
      String message;
      RtSnackbarType type;

      if (errorStr.contains('index') || errorStr.contains('FAILED_PRECONDITION')) {
        message = 'Los datos se están preparando. Intenta de nuevo en un momento';
        type = RtSnackbarType.info;
      } else if (errorStr.contains('permission') || errorStr.contains('PERMISSION_DENIED')) {
        message = 'No tienes permisos para ver las calificaciones';
        type = RtSnackbarType.warning;
      } else if (errorStr.contains('network') || errorStr.contains('unavailable')) {
        message = 'Sin conexión a internet. Verifica tu red';
        type = RtSnackbarType.warning;
      } else {
        message = AppLocalizations.of(context)!.errorLoadingRatings;
        type = RtSnackbarType.error;
      }

      RtSnackbar.show(context, message: message, type: type);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: RtColors.neutral50,
      appBar: RtAppBar(
        title: l10n.myRatingsTitle,
        variant: RtAppBarVariant.gradient,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: RtColors.brand),
            )
          : Column(
              children: [
                _buildStatistics(),
                _buildFilters(l10n),
                Expanded(
                  child: _filteredRatings.isEmpty
                      ? _buildEmptyState(l10n)
                      : ListView.builder(
                          padding: const EdgeInsets.all(RtSpacing.base),
                          itemCount: _filteredRatings.length,
                          itemBuilder: (context, index) {
                            return RtAnimatedListItem(
                              index: index,
                              child: _buildRatingCard(_filteredRatings[index]),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  // ============================================================
  // Estadísticas
  // ============================================================

  Widget _buildStatistics() {
    final stats = _statistics;
    final ratingCounts = stats['counts'] as Map<int, int>;

    return Container(
      margin: const EdgeInsets.all(RtSpacing.base),
      padding: const EdgeInsets.all(RtSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [RtColors.brand, RtColors.brandDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: RtRadius.borderLg,
        boxShadow: RtShadow.brand(),
      ),
      child: Column(
        children: [
          // Total y promedio
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    '${stats['total']}',
                    style: RtTypo.displaySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context)!.totalLabel,
                    style: RtTypo.bodySmall.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              Container(height: 40, width: 1, color: Colors.white24),
              Column(
                children: [
                  Row(
                    children: [
                      Text(
                        (stats['average'] as double).toStringAsFixed(1),
                        style: RtTypo.displaySmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: RtSpacing.xs),
                      const Icon(Icons.star, color: Colors.amber, size: 24),
                    ],
                  ),
                  Text(
                    AppLocalizations.of(context)!.averageLabel,
                    style: RtTypo.bodySmall.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: RtSpacing.lg),

          // Barras de distribución
          ...List.generate(5, (i) {
            final star = 5 - i;
            final count = ratingCounts[star] ?? 0;
            final percentage = stats['total'] > 0
                ? (count / stats['total'] * 100).toInt()
                : 0;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Text(
                    '$star',
                    style: RtTypo.labelMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Icon(Icons.star, size: 14, color: Colors.amber),
                  const SizedBox(width: RtSpacing.sm),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: RtRadius.borderSm,
                          ),
                        ),
                        AnimatedContainer(
                          duration: RtDuration.normal,
                          height: 18,
                          width: MediaQuery.of(context).size.width *
                              percentage / 100 * 0.45,
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: RtRadius.borderSm,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: RtSpacing.sm),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '$count',
                      style: RtTypo.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ============================================================
  // Filtros
  // ============================================================

  Widget _buildFilters(AppLocalizations l10n) {
    final filters = [
      {'label': l10n.allRatings, 'value': 'all'},
      {'label': l10n.fiveStarRating, 'value': '5'},
      {'label': l10n.fourStarRating, 'value': '4'},
      {'label': l10n.threeStarRating, 'value': '3'},
      {'label': l10n.twoStarRating, 'value': '2'},
      {'label': l10n.oneStarRating, 'value': '1'},
    ];

    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: RtSpacing.base),
        separatorBuilder: (_, __) => const SizedBox(width: RtSpacing.sm),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter['value'];

          return ChoiceChip(
            label: Text(filter['label']!),
            selected: isSelected,
            onSelected: (_) {
              setState(() => _selectedFilter = filter['value']!);
            },
            selectedColor: RtColors.brand,
            backgroundColor: Colors.white,
            labelStyle: RtTypo.labelMedium.copyWith(
              color: isSelected ? Colors.white : RtColors.neutral700,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected ? RtColors.brand : RtColors.neutral300,
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // Tarjeta de calificación
  // ============================================================

  Widget _buildRatingCard(RatingData rating) {
    return Padding(
      padding: const EdgeInsets.only(bottom: RtSpacing.base),
      child: RtCard(
        onTap: () => _showRatingDetails(rating),
        child: Padding(
          padding: const EdgeInsets.all(RtSpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: conductor + estrellas
              Row(
                children: [
                  RtAvatar(
                    imageUrl: rating.driverPhoto,
                    name: rating.driverName,
                    size: RtAvatarSize.medium,
                  ),
                  const SizedBox(width: RtSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rating.driverName,
                          style: RtTypo.titleMedium.copyWith(
                            color: RtColors.neutral900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(rating.date),
                          style: RtTypo.bodySmall.copyWith(
                            color: RtColors.neutral500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStars(rating.rating, size: 18),
                ],
              ),

              const SizedBox(height: RtSpacing.md),

              // Ruta y monto
              Container(
                padding: const EdgeInsets.all(RtSpacing.sm),
                decoration: BoxDecoration(
                  color: RtColors.neutral100,
                  borderRadius: RtRadius.borderSm,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.route, size: 16, color: RtColors.neutral500),
                    const SizedBox(width: RtSpacing.sm),
                    Expanded(
                      child: Text(
                        rating.route,
                        style: RtTypo.bodySmall.copyWith(
                          color: RtColors.neutral600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      'S/. ${rating.tripAmount.toStringAsFixed(2)}',
                      style: RtTypo.labelMedium.copyWith(
                        color: RtColors.brand,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Comentario
              if (rating.comment != null && rating.comment!.isNotEmpty) ...[
                const SizedBox(height: RtSpacing.md),
                Text(
                  rating.comment!,
                  style: RtTypo.bodyMedium.copyWith(color: RtColors.neutral800),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Tags
              if (rating.tags.isNotEmpty) ...[
                const SizedBox(height: RtSpacing.md),
                Wrap(
                  spacing: RtSpacing.xs + 2,
                  runSpacing: RtSpacing.xs + 2,
                  children: rating.tags.map((tag) {
                    return RtBadge(
                      label: _getLocalizedTag(tag),
                      variant: RtBadgeVariant.subtle,
                      color: RtColors.brand,
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Estado vacio
  // ============================================================

  Widget _buildEmptyState(AppLocalizations l10n) {
    return RtEmptyState(
      icon: Icons.star_border_rounded,
      title: l10n.noRatings,
      description: l10n.ratingsWillAppearHere,
    );
  }

  // ============================================================
  // Modal de detalles
  // ============================================================

  void _showRatingDetails(RatingData rating) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RatingDetailsModal(
        rating: rating,
        formatDate: _formatDate,
        getLocalizedTag: _getLocalizedTag,
      ),
    );
  }

  // ============================================================
  // Helpers
  // ============================================================

  Widget _buildStars(int count, {double size = 20}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < count ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: size,
        );
      }),
    );
  }

  String _formatDate(DateTime date) {
    final l10n = AppLocalizations.of(context)!;
    final difference = DateTime.now().difference(date).inDays;

    if (difference == 0) return l10n.today;
    if (difference == 1) return l10n.yesterday;
    if (difference < 7) return l10n.daysAgo(difference);
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getLocalizedTag(String tagKey) {
    final l10n = AppLocalizations.of(context)!;
    switch (tagKey) {
      case 'excellentService':
        return l10n.excellentService;
      case 'verySatisfied':
        return l10n.verySatisfied;
      case 'goodService':
        return l10n.goodService;
      case 'satisfied':
        return l10n.satisfied;
      case 'regularService':
        return l10n.regularService;
      case 'acceptable':
        return l10n.acceptable;
      case 'needsImprovement':
        return l10n.needsImprovement;
      case 'dissatisfied':
        return l10n.dissatisfied;
      default:
        return tagKey;
    }
  }
}

// ============================================================
// Modal de detalles de calificación
// ============================================================

class _RatingDetailsModal extends StatelessWidget {
  final RatingData rating;
  final String Function(DateTime) formatDate;
  final String Function(String) getLocalizedTag;

  const _RatingDetailsModal({
    required this.rating,
    required this.formatDate,
    required this.getLocalizedTag,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: RtSpacing.md),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: RtColors.neutral300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(RtSpacing.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.ratingDetailsTitle,
                  style: RtTypo.headingSmall.copyWith(
                    color: RtColors.neutral900,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Contenido
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(RtSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Conductor
                  Row(
                    children: [
                      RtAvatar(
                        imageUrl: rating.driverPhoto,
                        name: rating.driverName,
                        size: RtAvatarSize.large,
                      ),
                      const SizedBox(width: RtSpacing.base),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rating.driverName,
                              style: RtTypo.headingSmall.copyWith(
                                color: RtColors.neutral900,
                              ),
                            ),
                            const SizedBox(height: RtSpacing.xs),
                            Row(
                              children: List.generate(5, (index) {
                                return Icon(
                                  index < rating.rating
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: Colors.amber,
                                  size: 24,
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: RtSpacing.xl),

                  // Información del viaje
                  _buildDetailSection(
                    l10n.tripInfoLabel,
                    [
                      _buildDetailRow(Icons.calendar_today, l10n.dateLabel,
                          '${rating.date.day}/${rating.date.month}/${rating.date.year}'),
                      _buildDetailRow(Icons.access_time, l10n.timeLabel,
                          '${rating.date.hour.toString().padLeft(2, '0')}:${rating.date.minute.toString().padLeft(2, '0')}'),
                      _buildDetailRow(Icons.route, l10n.routeLabel, rating.route),
                      _buildDetailRow(Icons.account_balance_wallet,
                          l10n.amountLabel,
                          'S/. ${rating.tripAmount.toStringAsFixed(2)}'),
                      _buildDetailRow(Icons.tag, l10n.tripIdLabel, rating.tripId),
                    ],
                  ),

                  if (rating.comment != null && rating.comment!.isNotEmpty) ...[
                    const SizedBox(height: RtSpacing.lg),
                    _buildDetailSection(
                      l10n.yourCommentLabel,
                      [
                        Text(
                          rating.comment!,
                          style: RtTypo.bodyMedium.copyWith(
                            color: RtColors.neutral800,
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (rating.tags.isNotEmpty) ...[
                    const SizedBox(height: RtSpacing.lg),
                    Text(
                      l10n.tagsLabel,
                      style: RtTypo.titleMedium.copyWith(
                        color: RtColors.neutral900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: RtSpacing.md),
                    Wrap(
                      spacing: RtSpacing.sm,
                      runSpacing: RtSpacing.sm,
                      children: rating.tags.map((tag) {
                        return RtBadge(
                          label: getLocalizedTag(tag),
                          variant: RtBadgeVariant.outlined,
                          color: RtColors.brand,
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: RtSpacing.xl),

                  // Boton de editar (deshabilitado)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.edit),
                      label: Text(l10n.cannotEdit),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: RtRadius.borderMd,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: RtTypo.titleMedium.copyWith(
            color: RtColors.neutral900,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: RtSpacing.md),
        Container(
          padding: const EdgeInsets.all(RtSpacing.base),
          decoration: BoxDecoration(
            color: RtColors.neutral50,
            borderRadius: RtRadius.borderMd,
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: RtColors.neutral500),
          const SizedBox(width: RtSpacing.md),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: RtTypo.bodySmall.copyWith(color: RtColors.neutral500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: RtSpacing.sm),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: RtTypo.labelMedium.copyWith(
                color: RtColors.neutral800,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
