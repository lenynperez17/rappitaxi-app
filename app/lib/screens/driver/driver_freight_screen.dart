import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive_bottom_sheet.dart';
import '../../core/l10n/driver_strings.dart';
import '../../services/rapi_api_client.dart';
import 'driver_wallet_simple_screen.dart';
import '../../utils/error_messages.dart';

class DriverFreightScreen extends StatefulWidget {
  const DriverFreightScreen({super.key});

  @override
  State<DriverFreightScreen> createState() => _DriverFreightScreenState();
}

class _DriverFreightScreenState extends State<DriverFreightScreen> {
  int _bottomNavIndex = 0;
  bool _isAvailable = false;

  // Muro de solicitudes
  List<Map<String, dynamic>> _freightRequests = [];
  bool _isLoadingRequests = true;

  // Mis solicitudes
  int _myRequestsFilter = 0; // 0=Esperando, 1=Activas

  // Calificación
  double _rating = 4.85;
  int _totalTrips = 0;
  final int _totalReviews = 0;
  double _walletBalance = 0.0;
  final double _cancellationRate = 0.0;

  @override
  void initState() {
    super.initState();
    _loadFreightRequests();
    _loadDriverStats();
  }

  Future<void> _loadFreightRequests() async {
    setState(() => _isLoadingRequests = true);
    // TODO(node-migration): reemplazar con endpoint /api/freight/requests?status=active
    // cuando exista. Por ahora devolvemos lista vacía.
    if (mounted) {
      setState(() {
        _freightRequests = const [];
        _isLoadingRequests = false;
      });
    }
  }

  Future<void> _loadDriverStats() async {
    try {
      final api = RapiApiClient.instance;

      // Rating del usuario.
      try {
        final resp = await api.me();
        final u = resp?['user'] as Map<String, dynamic>?;
        final r = u?['rating'] ?? u?['ratingAvg'];
        if (r is num && mounted) _rating = r.toDouble();
      } catch (_) {}

      // Balance de wallet.
      try {
        final w = await api.walletBalance();
        final b = w['balance'] ?? w['serviceCredits'];
        if (b is num && mounted) _walletBalance = b.toDouble();
      } catch (_) {}

      // Total de viajes de tipo freight del driver.
      try {
        final resp = await api.listRides(role: 'driver', pageSize: 200);
        final rawList = (resp['rides'] as List?) ?? const [];
        int freightTrips = 0;
        for (final r in rawList) {
          if (r is! Map) continue;
          if ((r['type'] ?? '') == 'freight') freightTrips++;
        }
        if (mounted) _totalTrips = freightTrips;
      } catch (_) {}

      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final ds = DriverStrings(Localizations.localeOf(context).languageCode);
    return Scaffold(
      backgroundColor: AppColors.getSurface(context),
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
                    child: Icon(Icons.menu, size: 28, color: AppColors.getTextPrimary(context)),
                  ),
                  const SizedBox(width: 16),
                  if (_bottomNavIndex == 0)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isAvailable = !_isAvailable),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: _isAvailable ? AppColors.rappiRed : AppColors.error,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _isAvailable ? AppColors.rappiRed : AppColors.error,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _isAvailable ? ds.available : ds.busy,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: Center(
                        child: Text(
                          _bottomNavIndex == 1 ? ds.myRequests : ds.ratingTab,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  if (_bottomNavIndex == 0) ...[
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: _showFilterOptions,
                      child: Icon(Icons.tune, size: 28, color: AppColors.getTextPrimary(context)),
                    ),
                  ] else
                    const SizedBox(width: 28),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _bottomNavIndex == 0
                  ? _buildMuroTab()
                  : _bottomNavIndex == 1
                      ? _buildMisSolicitudesTab()
                      : _buildCalificacionTab(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _bottomNavIndex,
        onTap: (i) => setState(() => _bottomNavIndex = i),
        selectedItemColor: AppColors.getTextPrimary(context),
        unselectedItemColor: AppColors.getTextSecondary(context),
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.list_alt), label: ds.requestWall),
          BottomNavigationBarItem(icon: const Icon(Icons.checklist), label: ds.myRequests),
          BottomNavigationBarItem(icon: const Icon(Icons.star_border), label: ds.ratingTab),
        ],
      ),
    );
  }

  // ─────────── TAB 1: MURO DE SOLICITUDES ───────────

  Widget _buildMuroTab() {
    return Column(
      children: [
        // Info banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppColors.getBackground(context),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.rappiRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.info, size: 18, color: AppColors.rappiRed),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Realiza ofertas que se ajusten a tus necesidades. Te recomendamos ofertar a entre 5 y 10 pedidos para aumentar tus posibilidades.',
                  style: TextStyle(fontSize: 14, height: 1.4, color: AppColors.getTextPrimary(context)),
                ),
              ),
            ],
          ),
        ),

        // Requests list
        Expanded(
          child: _isLoadingRequests
              ? const Center(child: CircularProgressIndicator())
              : _freightRequests.isEmpty
                  ? _buildEmptyMuro()
                  : _buildRequestsList(),
        ),
      ],
    );
  }

  Widget _buildEmptyMuro() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_shipping, size: 64, color: AppColors.getTextSecondary(context).withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('No hay solicitudes de flete', style: TextStyle(fontSize: 16, color: AppColors.getTextSecondary(context))),
          Text('disponibles en tu zona', style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context).withValues(alpha: 0.7))),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _loadFreightRequests,
            icon: const Icon(Icons.refresh),
            label: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList() {
    return RefreshIndicator(
      onRefresh: _loadFreightRequests,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _freightRequests.length,
        itemBuilder: (context, index) => _FreightRequestCard(
          request: _freightRequests[index],
          onTap: () => _showRequestDetail(_freightRequests[index]),
          onMenu: () => _showRequestMenu(_freightRequests[index]),
        ),
      ),
    );
  }

  void _showRequestDetail(Map<String, dynamic> request) {
    final ds = DriverStrings(Localizations.localeOf(context).languageCode);
    final price = (request['price'] ?? 0).toDouble();
    final description = request['description'] ?? '';
    final pickup = request['pickupAddress'] ?? '';
    final destination = request['destinationAddress'] ?? '';
    final vehicleType = request['vehicleType'] ?? 'Camión';

    showResponsiveBottomSheet(
      context: context,
      showDragHandle: false,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Price
              Text('S/ ${price.toStringAsFixed(0)}', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.getTextPrimary(context))),
              const SizedBox(height: 12),

              // Vehicle type
              Row(
                children: [
                  Icon(Icons.local_shipping, size: 20, color: AppColors.getTextSecondary(context)),
                  const SizedBox(width: 8),
                  Text(vehicleType, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
                ],
              ),
              const SizedBox(height: 16),

              // Route
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.circle, size: 14, color: Colors.blue),
                  const SizedBox(width: 10),
                  Expanded(child: Text(pickup.isNotEmpty ? pickup : 'Origen no especificado', style: TextStyle(fontSize: 15, color: AppColors.getTextPrimary(context)))),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.circle, size: 14, color: Colors.green),
                  const SizedBox(width: 10),
                  Expanded(child: Text(destination.isNotEmpty ? destination : 'Destino no especificado', style: TextStyle(fontSize: 15, color: AppColors.getTextPrimary(context)))),
                ],
              ),

              if (description.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 18, color: AppColors.getTextSecondary(context)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(description, style: TextStyle(fontSize: 15, color: AppColors.getTextPrimary(context), height: 1.4))),
                  ],
                ),
              ],
              const SizedBox(height: 24),

              // Offer button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showMakeOfferSheet(request);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.rappiRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(ds.makeOffer, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMakeOfferSheet(Map<String, dynamic> request) {
    final ds = DriverStrings(Localizations.localeOf(context).languageCode);
    final price = (request['price'] ?? 0).toDouble();
    final controller = TextEditingController(text: price.toStringAsFixed(0));

    // Ronda 214: enableDrag=false porque el sheet contiene un TextField con
    // autofocus (contra-oferta del driver). Ver comentario en price_setting_sheet.
    showResponsiveBottomSheet(
      context: context,
      enableDrag: false,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ds.yourOffer, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
            const SizedBox(height: 8),
            Text('Precio sugerido: S/ ${price.toStringAsFixed(0)}', style: TextStyle(color: AppColors.getTextSecondary(context))),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.getTextPrimary(context)),
              decoration: InputDecoration(
                prefixText: 'S/ ',
                prefixStyle: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.getTextPrimary(context)),
                filled: true,
                fillColor: AppColors.getBackground(context),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Oferta de S/ ${controller.text} enviada')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.rappiRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(ds.sendOffer, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRequestMenu(Map<String, dynamic> request) {
    final ds = DriverStrings(Localizations.localeOf(context).languageCode);
    showResponsiveBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
            child: Row(
              children: [
                Text('Solicitud en la lista', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: AppColors.getBorder(context).withValues(alpha: 0.3), shape: BoxShape.circle),
                    child: Icon(Icons.close, size: 20, color: AppColors.getTextPrimary(context)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            title: Text(ds.sendComplaint, style: TextStyle(fontSize: 16, color: AppColors.getTextPrimary(context))),
            trailing: Icon(Icons.chevron_right, color: AppColors.getTextSecondary(context)),
            onTap: () {
              Navigator.pop(ctx);
              _showComplaintSheet();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showComplaintSheet() {
    final ds = DriverStrings(Localizations.localeOf(context).languageCode);
    showResponsiveBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ds.sendComplaint, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
            const SizedBox(height: 16),
            ...['Precio muy bajo', 'Información incorrecta', 'Solicitud duplicada', 'Otro motivo'].map((reason) =>
              ListTile(
                title: Text(reason),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(userFriendlyError(reason, fallback: 'Queja enviada'))),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterOptions() {
    showResponsiveBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filtrar solicitudes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
            const SizedBox(height: 16),
            ...['Todos los vehículos', 'Camión Grande', 'Camión Mediano', 'Camioneta', 'Moto de carga'].map((type) =>
              ListTile(
                leading: Icon(Icons.local_shipping, color: AppColors.getTextSecondary(context)),
                title: Text(type),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(userFriendlyError(type, fallback: 'Filtro'))),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────── TAB 2: MIS SOLICITUDES ───────────

  Widget _buildMisSolicitudesTab() {
    final ds = DriverStrings(Localizations.localeOf(context).languageCode);
    return Column(
      children: [
        // Filter chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildMyFilterChip(ds.waitingResponse, 0, 0),
                const SizedBox(width: 8),
                _buildMyFilterChip(ds.activeRequests, 1, 0),
              ],
            ),
          ),
        ),

        // Empty state
        Expanded(
          child: Center(
            child: Text(
              ds.noRequestsYet,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.getTextPrimary(context)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMyFilterChip(String label, int index, int count) {
    final isSelected = _myRequestsFilter == index;
    return GestureDetector(
      onTap: () => setState(() => _myRequestsFilter = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.getSurface(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isSelected ? AppColors.getBorder(context) : Colors.transparent),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.blue : AppColors.getTextPrimary(context),
              ),
            ),
            const SizedBox(width: 6),
            Text('$count', style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context))),
          ],
        ),
      ),
    );
  }

  // ─────────── TAB 3: CALIFICACIÓN ───────────

  Widget _buildCalificacionTab() {
    final ds = DriverStrings(Localizations.localeOf(context).languageCode);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 8),

          // Status
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(ds.normal, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.getTextPrimary(context))),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showRatingHelp(),
                child: Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.getTextSecondary(context), width: 2),
                  ),
                  child: Icon(Icons.question_mark, size: 14, color: AppColors.getTextSecondary(context)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Rating bar
          _buildRatingBar('${ds.averageRating}:', _rating.toStringAsFixed(2), _rating / 5.0, [Colors.orange, Colors.yellow, Colors.green]),
          const SizedBox(height: 16),

          // Frequency bar
          _buildRatingBar('${ds.frequency}:', 'Principiante', _totalTrips > 0 ? (_totalTrips / 100).clamp(0.0, 1.0) : 0.15, [Colors.red, Colors.orange]),
          const SizedBox(height: 16),

          // Cancellation bar
          _buildRatingBar('${ds.cancellationRate}:', 'Rara vez', 1.0 - _cancellationRate, [Colors.green, Colors.green]),
          const SizedBox(height: 24),

          // Stats card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: AppColors.getSurface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.getBorder(context).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                _buildStatItem('$_totalTrips', ds.tripsCount.toLowerCase()),
                Container(width: 1, height: 40, color: AppColors.getBorder(context)),
                _buildStatItem('$_totalReviews', ds.reviews.toLowerCase()),
                Container(width: 1, height: 40, color: AppColors.getBorder(context)),
                _buildStatItem('${_walletBalance.toStringAsFixed(2)} S/', ds.balance.toLowerCase(), isHighlighted: true),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Reviews section
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
                Text('$_totalReviews ${ds.reviews.toLowerCase()}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.getTextPrimary(context))),
                if (_totalReviews == 0) ...[
                  const SizedBox(height: 12),
                  Text(ds.noReviewsYet, style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context))),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Wallet button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverWalletSimpleScreen())),
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: const Text('Ver cartera'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBar(String label, String value, double progress, List<Color> colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.getBorder(context).withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation<Color>(colors.length > 1
                ? Color.lerp(colors.first, colors.last, progress) ?? colors.first
                : colors.first),
            minHeight: 10,
          ),
        ),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 15, color: AppColors.getTextPrimary(context)),
            children: [
              TextSpan(text: '$label ', style: const TextStyle(fontWeight: FontWeight.bold)),
              TextSpan(text: value),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String value, String label, {bool isHighlighted = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: isHighlighted ? AppColors.rappiRed : AppColors.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context))),
        ],
      ),
    );
  }

  void _showRatingHelp() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tu calificación'),
        content: const Text('Tu calificación se basa en:\n\n• Calificación promedio de los clientes\n• Frecuencia de viajes completados\n• Tasa de cancelación de solicitudes\n\nMantén una buena calificación para recibir más solicitudes.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido'))],
      ),
    );
  }
}

// ─────────── FREIGHT REQUEST CARD ───────────

class _FreightRequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onTap;
  final VoidCallback onMenu;

  const _FreightRequestCard({
    required this.request,
    required this.onTap,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final price = (request['price'] ?? 0).toDouble();
    final pickup = request['pickupAddress'] ?? '';
    final destination = request['destinationAddress'] ?? '';
    final description = request['description'] ?? '';
    final vehicleType = request['vehicleType'] ?? 'Camión';
    final tags = List<String>.from(request['tags'] ?? []);
    // createdAt viene del backend Node como ISO-8601 string.
    final createdAtRaw = request['createdAt'] ?? request['created_at'];
    final createdAt = createdAtRaw is String
        ? DateTime.tryParse(createdAtRaw)
        : (createdAtRaw is DateTime ? createdAtRaw : null);
    final userName = request['userName'] ?? '';
    final userPhoto = request['userPhoto'] ?? '';
    final pickupTime = request['pickupTime'] ?? '';
    final distance = request['distance'] ?? '';
    final duration = request['duration'] ?? '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.getSurface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.getBorder(context).withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Price + menu
            Row(
              children: [
                Text('PEN ${price.toStringAsFixed(0)}', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.getTextPrimary(context))),
                const Spacer(),
                GestureDetector(
                  onTap: onMenu,
                  child: Icon(Icons.more_horiz, size: 24, color: AppColors.getTextSecondary(context)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Tags
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (pickupTime.isNotEmpty)
                  _buildTag(context, '⏱ Tiempo de recogida: $pickupTime', AppColors.rappiRed.withValues(alpha: 0.1)),
                ...tags.map((tag) => _buildTag(context, tag, AppColors.getBackground(context))),
              ],
            ),
            const SizedBox(height: 12),

            // Vehicle type
            Row(
              children: [
                Icon(Icons.local_shipping, size: 20, color: AppColors.getTextPrimary(context)),
                const SizedBox(width: 8),
                Text(vehicleType, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
              ],
            ),
            const SizedBox(height: 12),

            // Route
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Icon(Icons.circle, size: 12, color: Colors.blue),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(pickup.isNotEmpty ? pickup : 'Origen', style: TextStyle(fontSize: 15, color: AppColors.getTextPrimary(context)))),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Icon(Icons.circle, size: 12, color: Colors.green),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (distance.isNotEmpty)
                        Text('$distance${duration.isNotEmpty ? ', $duration' : ''}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
                      Text(destination.isNotEmpty ? destination : 'Destino', style: TextStyle(fontSize: 15, color: AppColors.getTextPrimary(context))),
                    ],
                  ),
                ),
              ],
            ),

            if (description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 18, color: AppColors.getTextSecondary(context)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, color: AppColors.getTextPrimary(context)),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 10),
            Text(
              _formatTimeAgo(createdAt),
              style: TextStyle(fontSize: 13, color: AppColors.getTextSecondary(context)),
            ),

            if (userName.isNotEmpty) ...[
              Divider(height: 24, color: AppColors.getBorder(context)),
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: userPhoto.isNotEmpty ? NetworkImage(userPhoto) : null,
                    child: userPhoto.isEmpty ? const Icon(Icons.person, size: 20) : null,
                  ),
                  const SizedBox(width: 12),
                  Text(userName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTag(BuildContext context, String text, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.getTextPrimary(context))),
    );
  }

  String _formatTimeAgo(DateTime? date) {
    if (date == null) return 'Solicitud reciente';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Solicitud creada ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    return 'Hace ${diff.inDays} días';
  }
}
