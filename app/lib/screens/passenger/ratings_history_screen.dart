// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../core/theme/modern_theme.dart';
import '../../core/extensions/theme_extensions.dart'; // ✅ Extensión para colores que se adaptan al tema

import '../../utils/logger.dart';
class RatingsHistoryScreen extends StatefulWidget {
  const RatingsHistoryScreen({super.key});

  @override
  _RatingsHistoryScreenState createState() => _RatingsHistoryScreenState();
}

class _RatingsHistoryScreenState extends State<RatingsHistoryScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userId; // Se obtendrá del usuario actual
  bool _isLoading = true;
  
  late AnimationController _headerController;
  late AnimationController _listController;
  
  String _selectedFilter = 'all';
  
  // Lista de calificaciones desde Firebase
  List<RatingData> _ratings = [];
  
  List<RatingData> get _filteredRatings {
    if (_selectedFilter == 'all') return _ratings;
    
    final filterValue = int.parse(_selectedFilter);
    return _ratings.where((r) => r.rating == filterValue).toList();
  }
  
  Map<String, dynamic> get _statistics {
    final totalRatings = _ratings.length;
    // ✅ Prevenir división por cero - retornar 0.0 cuando no hay calificaciones
    final avgRating = totalRatings > 0
        ? _ratings.fold<double>(0, (total, r) => total + r.rating) / totalRatings
        : 0.0;

    final ratingCounts = <int, int>{};
    for (var rating in _ratings) {
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
    
    _headerController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    )..forward();
    
    _listController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    )..forward();
    
    _loadRatingsFromFirebase();
  }
  
  Future<void> _loadRatingsFromFirebase() async {
    try {
      setState(() => _isLoading = true);

      // ✅ Obtener el ID del usuario autenticado desde Firebase Auth
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.userNotAuthenticated),
              backgroundColor: ModernTheme.error,
            ),
          );
        }
        return;
      }
      _userId = currentUser.uid;
      
      // Cargar calificaciones del usuario desde Firebase
      final ridesSnapshot = await _firestore
          .collection('rides')
          .where('passengerId', isEqualTo: _userId)
          .where('rating', isNotEqualTo: null)
          .orderBy('rating')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      
      List<RatingData> loadedRatings = [];
      
      for (var doc in ridesSnapshot.docs) {
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
        
        // Generar tags basados en la calificación
        // NOTA: Los tags se guardan como claves de traducción, se traducirán al mostrarlos
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
          route: '${data['pickupAddress'] ?? 'Origen'} → ${data['destinationAddress'] ?? 'Destino'}',
          tripAmount: (data['fare'] ?? 0.0).toDouble(),
        ));
      }
      
      // Si no hay calificaciones, mostrar lista vacía (sin crear datos de ejemplo)
      
      setState(() {
        _ratings = loadedRatings;
        _isLoading = false;
      });
      
    } catch (e) {
      AppLogger.error('Error cargando calificaciones: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorLoadingRatings),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }
  
  
  @override
  void dispose() {
    _headerController.dispose();
    _listController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surfaceColor,
      appBar: AppBar(
        backgroundColor: ModernTheme.rappiOrange,
        title: Text(
          AppLocalizations.of(context)!.myRatingsTitle,
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Estadísticas
          AnimatedBuilder(
            animation: _headerController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, -50 * (1 - _headerController.value)),
                child: Opacity(
                  opacity: _headerController.value,
                  child: _buildStatistics(),
                ),
              );
            },
          ),
          
          // Filtros
          _buildFilters(),
          
          // Lista de calificaciones
          Expanded(
            child: _filteredRatings.isEmpty
                ? _buildEmptyState()
                : AnimatedBuilder(
                    animation: _listController,
                    builder: (context, child) {
                      return ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: _filteredRatings.length,
                        itemBuilder: (context, index) {
                          final rating = _filteredRatings[index];
                          final delay = index * 0.1;
                          final animation = Tween<double>(
                            begin: 0,
                            end: 1,
                          ).animate(
                            CurvedAnimation(
                              parent: _listController,
                              curve: Interval(
                                delay,
                                delay + 0.5,
                                curve: Curves.easeOutBack,
                              ),
                            ),
                          );
                          
                          return AnimatedBuilder(
                            animation: animation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(50 * (1 - animation.value), 0),
                                child: Opacity(
                                  opacity: animation.value.clamp(0.0, 1.0),
                                  child: _buildRatingCard(rating),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatistics() {
    final stats = _statistics;
    final ratingCounts = stats['counts'] as Map<int, int>;

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: ModernTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: ModernTheme.rappiOrange.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Rating promedio grande y centrado
          Text(
            stats['average'].toStringAsFixed(1),
            style: TextStyle(
              color: Theme.of(context).colorScheme.surface,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
          // Estrellas debajo del promedio
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final avg = (stats['average'] as double);
              return Icon(
                index < avg.floor()
                    ? Icons.star
                    : (index < avg ? Icons.star_half : Icons.star_border),
                color: Colors.amber,
                size: 28,
              );
            }),
          ),
          SizedBox(height: 4),
          Text(
            '${stats['total']} ${AppLocalizations.of(context)!.totalLabel}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
          SizedBox(height: 16),
          // Separador
          Divider(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.3), height: 1),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Placeholder para mantener el Row con la distribución
            ],
          ),
          
          SizedBox(height: 20),
          
          // Distribución de calificaciones
          Column(
            children: [5, 4, 3, 2, 1].map((rating) {
              final count = ratingCounts[rating] ?? 0;
              // ✅ Prevenir división por cero - retornar 0 cuando no hay calificaciones
              final percentage = stats['total'] > 0
                  ? (count / stats['total'] * 100).toInt()
                  : 0;
              
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(
                      '$rating',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.surface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(
                      Icons.star,
                      size: 16,
                      color: Colors.amber,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 20,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          AnimatedContainer(
                            duration: Duration(milliseconds: 800),
                            height: 20,
                            width: MediaQuery.of(context).size.width * 
                                   percentage / 100 * 0.5,
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    SizedBox(
                      width: 30,
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.surface,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilters() {
    return Container(
      height: 50,
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip(AppLocalizations.of(context)!.allRatings, 'all'),
          SizedBox(width: 8),
          _buildFilterChip(AppLocalizations.of(context)!.fiveStarRating, '5'),
          SizedBox(width: 8),
          _buildFilterChip(AppLocalizations.of(context)!.fourStarRating, '4'),
          SizedBox(width: 8),
          _buildFilterChip(AppLocalizations.of(context)!.threeStarRating, '3'),
          SizedBox(width: 8),
          _buildFilterChip(AppLocalizations.of(context)!.twoStarRating, '2'),
          SizedBox(width: 8),
          _buildFilterChip(AppLocalizations.of(context)!.oneStarRating, '1'),
        ],
      ),
    );
  }
  
  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      selectedColor: ModernTheme.rappiOrange,
      backgroundColor: Theme.of(context).colorScheme.surface,
      labelStyle: TextStyle(
        color: isSelected ? Theme.of(context).colorScheme.onPrimary : context.primaryText,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? ModernTheme.rappiOrange : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
        ),
      ),
    );
  }
  
  Widget _buildRatingCard(RatingData rating) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.getCardShadow(context),
      ),
      child: InkWell(
        onTap: () => _showRatingDetails(rating),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con conductor y fecha
              Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundImage: (rating.driverPhoto.isNotEmpty && rating.driverPhoto.startsWith('http'))
                        ? NetworkImage(rating.driverPhoto)
                        : null,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rating.driverName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _formatDate(rating.date),
                          style: TextStyle(
                            color: context.secondaryText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Estrellas
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        index < rating.rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 20,
                      );
                    }),
                  ),
                ],
              ),
              
              SizedBox(height: 12),
              
              // Ruta
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.route,
                      size: 16,
                      color: context.secondaryText,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rating.route,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.secondaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      'S/. ${rating.tripAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ModernTheme.rappiOrange,
                      ),
                    ),
                  ],
                ),
              ),
              
              if (rating.comment != null) ...[
                SizedBox(height: 12),
                Text(
                  rating.comment!,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.primaryText,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              
              if (rating.tags.isNotEmpty) ...[
                SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: rating.tags.map((tag) {
                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getLocalizedTag(tag),
                        style: TextStyle(
                          fontSize: 11,
                          color: ModernTheme.rappiOrange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
  
  Widget _buildEmptyState() {
    // ✅ MEJORADO: Mostrar loading spinner mientras se cargan las calificaciones
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: ModernTheme.rappiOrange),
            SizedBox(height: 16),
            Text(
              'Cargando calificaciones...',
              style: TextStyle(
                color: context.secondaryText,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    // Mostrar estado vacío cuando no hay calificaciones
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.star_border,
            size: 80,
            color: context.secondaryText.withValues(alpha: 0.3),
          ),
          SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.noRatings,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: context.secondaryText,
            ),
          ),
          SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.ratingsWillAppearHere,
            style: TextStyle(
              color: context.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
  
  void _showRatingDetails(RatingData rating) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RatingDetailsModal(rating: rating),
    );
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) return AppLocalizations.of(context)!.today;
    if (difference == 1) return AppLocalizations.of(context)!.yesterday;
    if (difference < 7) return AppLocalizations.of(context)!.daysAgo(difference);

    return '${date.day}/${date.month}/${date.year}';
  }

  String _getLocalizedTag(String tagKey) {
    final localizations = AppLocalizations.of(context)!;
    switch (tagKey) {
      case 'excellentService':
        return localizations.excellentService;
      case 'verySatisfied':
        return localizations.verySatisfied;
      case 'goodService':
        return localizations.goodService;
      case 'satisfied':
        return localizations.satisfied;
      case 'regularService':
        return localizations.regularService;
      case 'acceptable':
        return localizations.acceptable;
      case 'needsImprovement':
        return localizations.needsImprovement;
      case 'dissatisfied':
        return localizations.dissatisfied;
      default:
        return tagKey; // Fallback si no hay traducción
    }
  }
}

// Modal de detalles
class RatingDetailsModal extends StatelessWidget {
  final RatingData rating;
  
  const RatingDetailsModal({super.key, required this.rating});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.ratingDetailsTitle,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Conductor
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundImage: (rating.driverPhoto.isNotEmpty && rating.driverPhoto.startsWith('http'))
                            ? NetworkImage(rating.driverPhoto)
                            : null,
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rating.driverName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
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
                  
                  SizedBox(height: 24),

                  // Información del viaje
                  _buildDetailSection(
                    AppLocalizations.of(context)!.tripInfoLabel,
                    [
                      _buildDetailRow(Icons.calendar_today, AppLocalizations.of(context)!.dateLabel,
                        '${rating.date.day}/${rating.date.month}/${rating.date.year}', context),
                      _buildDetailRow(Icons.access_time, AppLocalizations.of(context)!.timeLabel,
                        '${rating.date.hour.toString().padLeft(2, '0')}:${rating.date.minute.toString().padLeft(2, '0')}', context),
                      _buildDetailRow(Icons.route, AppLocalizations.of(context)!.routeLabel, rating.route, context),
                      _buildDetailRow(Icons.account_balance_wallet, // ✅ Cambiado de attach_money ($) a wallet
                        AppLocalizations.of(context)!.amountLabel,
                        'S/. ${rating.tripAmount.toStringAsFixed(2)}', context),
                      _buildDetailRow(Icons.tag, AppLocalizations.of(context)!.tripIdLabel, rating.tripId, context),
                    ],
                    context,
                  ),

                  if (rating.comment != null) ...[
                    SizedBox(height: 20),
                    _buildDetailSection(
                      AppLocalizations.of(context)!.yourCommentLabel,
                      [
                        Text(
                          rating.comment!,
                          style: TextStyle(
                            fontSize: 14,
                            color: context.primaryText,
                          ),
                        ),
                      ],
                      context,
                    ),
                  ],
                  
                  if (rating.tags.isNotEmpty) ...[
                    SizedBox(height: 20),
                    Text(
                      AppLocalizations.of(context)!.tagsLabel,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.primaryText,
                      ),
                    ),
                    SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: rating.tags.map((tag) {
                        return Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: ModernTheme.rappiOrange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: ModernTheme.rappiOrange,
                            ),
                          ),
                          child: Text(
                            _getLocalizedTagStatic(context, tag),
                            style: TextStyle(
                              fontSize: 13,
                              color: ModernTheme.rappiOrange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  
                  SizedBox(height: 24),
                  
                  // Botón de editar (deshabilitado)
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: Icon(Icons.edit),
                    label: Text(AppLocalizations.of(context)!.cannotEdit),
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
  
  Widget _buildDetailSection(String title, List<Widget> children, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: context.primaryText,
          ),
        ),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
  
  Widget _buildDetailRow(IconData icon, String label, String value, BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.secondaryText),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: context.secondaryText,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
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

  static String _getLocalizedTagStatic(BuildContext context, String tagKey) {
    final localizations = AppLocalizations.of(context)!;
    switch (tagKey) {
      case 'excellentService':
        return localizations.excellentService;
      case 'verySatisfied':
        return localizations.verySatisfied;
      case 'goodService':
        return localizations.goodService;
      case 'satisfied':
        return localizations.satisfied;
      case 'regularService':
        return localizations.regularService;
      case 'acceptable':
        return localizations.acceptable;
      case 'needsImprovement':
        return localizations.needsImprovement;
      case 'dissatisfied':
        return localizations.dissatisfied;
      default:
        return tagKey; // Fallback si no hay traducción
    }
  }
}

// Modelo de datos
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