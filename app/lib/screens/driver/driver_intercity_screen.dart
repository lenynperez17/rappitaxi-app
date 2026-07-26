import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive_bottom_sheet.dart';
import '../../core/l10n/driver_strings.dart';
import '../../services/rapi_api_client.dart';
import 'driver_recharge_screen.dart';

class DriverIntercityScreen extends StatefulWidget {
  const DriverIntercityScreen({super.key});

  @override
  State<DriverIntercityScreen> createState() => _DriverIntercityScreenState();
}

class _DriverIntercityScreenState extends State<DriverIntercityScreen> {
  int _bottomNavIndex = 0;
  bool _notifyNewRequests = false;
  bool _unlimitedActive = false;
  double _walletBalance = 0.0;
  final double _unlimitedPrice = 7.0;
  String _originCity = 'Lima';
  String _destinationCity = '';
  String _selectedDateLabel = '';

  // Mis viajes tab
  int _myTripsFilter = 0; // 0=Aceptadas, 1=Pendientes, 2=Archivadas

  static const List<String> _allCities = [
    'Amazonas', 'Áncash', 'Apurímac', 'Arequipa', 'Ayacucho',
    'Cajamarca', 'Callao', 'Chachapoyas', 'Chiclayo', 'Chimbote',
    'Chincha', 'Cusco', 'Huancavelica', 'Huancayo', 'Huánuco',
    'Huaraz', 'Ica', 'Ilo', 'Iquitos', 'Jaén',
    'Juliaca', 'La Merced', 'Lambayeque', 'Lima', 'Madre de Dios',
    'Moquegua', 'Moyobamba', 'Nasca', 'Oxapampa', 'Paita',
    'Pasco', 'Piura', 'Pucallpa', 'Puerto Maldonado', 'Puno',
    'Satipo', 'Sullana', 'Tacna', 'Talara', 'Tarapoto',
    'Tarma', 'Tingo María', 'Trujillo', 'Tumbes', 'Yurimaguas',
  ];

  @override
  void initState() {
    super.initState();
    _loadWalletBalance();
  }

  Future<void> _loadWalletBalance() async {
    try {
      final w = await RapiApiClient.instance.walletBalance();
      final b = w['balance'] ?? w['serviceCredits'];
      if (mounted && b is num) {
        setState(() {
          _walletBalance = b.toDouble();
        });
      }
    } catch (_) {}
  }

  void _showUnlimitedPaymentSheet() {
    showResponsiveBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.getTextPrimary(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Actualizar el pago del servicio', style: TextStyle(color: AppColors.getSurface(context), fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
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
              const SizedBox(height: 20),

              // Title
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: 'Pagar una vez al día\n', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.getTextPrimary(context), height: 1.2)),
                  TextSpan(text: 'sin cargos\nadicionales', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.rappiRed, height: 1.2)),
                ]),
              ),
              const SizedBox(height: 24),

              // Benefits
              _benefitRow('Solicitudes ilimitadas durante las próximas 24 h'),
              const SizedBox(height: 14),
              _benefitRow('Viajes de ida y vuelta cubiertos'),
              const SizedBox(height: 14),
              _benefitRow('No pagarás el servicio cuando un pasajero acepte tu oferta'),
              const SizedBox(height: 24),

              // Wallet balance
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverRechargeScreen()));
                },
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 24, color: AppColors.getTextSecondary(context)),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tu saldo', style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context))),
                        Text('S/${_walletBalance.toStringAsFixed(2)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.rappiRed)),
                      ],
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right, color: AppColors.getTextSecondary(context)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Recharge button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (_walletBalance >= _unlimitedPrice) {
                      _activateUnlimited();
                    } else {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverRechargeScreen())).then((_) => _loadWalletBalance());
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.rappiRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    _walletBalance >= _unlimitedPrice ? 'Activar por S/${_unlimitedPrice.toInt()}' : 'Recargar hasta S/${_unlimitedPrice.toInt()}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _benefitRow(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle_outline, size: 24, color: AppColors.getTextPrimary(context)),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: TextStyle(fontSize: 16, color: AppColors.getTextPrimary(context), height: 1.3))),
      ],
    );
  }

  void _activateUnlimited() {
    setState(() => _unlimitedActive = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Solicitudes ilimitadas activadas por 24 horas')),
    );
  }

  void _showUnlimitedInfoPage() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const _UnlimitedInfoPage()));
  }

  void _showNotificationHelp() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notificaciones de solicitudes'),
        content: const Text('Cuando se active, recibirás una notificación cada vez que un pasajero publique una solicitud de viaje entre ciudades que coincida con tu ruta.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido'))],
      ),
    );
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
                  Expanded(
                    child: Center(
                      child: Text(
                        _bottomNavIndex == 0 ? ds.intercity : ds.myRequests,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 28),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _bottomNavIndex == 0 ? _buildSolicitudesTab() : _buildMisViajesTab(),
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
          BottomNavigationBarItem(icon: const Icon(Icons.list_alt), label: ds.tripRequests),
          BottomNavigationBarItem(icon: const Icon(Icons.checklist), label: ds.myTrips),
        ],
      ),
    );
  }

  Widget _buildSolicitudesTab() {
    final ds = DriverStrings(Localizations.localeOf(context).languageCode);
    return Column(
      children: [
        // Info banner
        GestureDetector(
          onTap: _showUnlimitedInfoPage,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.rappiRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(border: Border.all(color: Colors.black54), borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.info_outline, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text("Info sobre '${ds.unlimitedRequests}'", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Filters
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _FilterRow(
                icon: Icons.circle,
                iconColor: AppColors.rappiRed,
                label: _originCity.isNotEmpty ? _originCity : ds.origin,
                onTap: () => _showCityPicker('origen'),
              ),
              const Divider(height: 1),
              _FilterRow(
                icon: Icons.circle,
                iconColor: _destinationCity.isNotEmpty ? AppColors.rappiRed : Colors.grey,
                label: _destinationCity.isNotEmpty ? _destinationCity : ds.destination,
                onTap: () => _showCityPicker('destino'),
              ),
              const Divider(height: 1),
              _FilterRow(
                icon: Icons.calendar_today,
                iconColor: _selectedDateLabel.isNotEmpty ? AppColors.rappiRed : Colors.grey,
                label: _selectedDateLabel.isNotEmpty ? _selectedDateLabel : ds.date,
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                    locale: const Locale('es', 'PE'),
                  );
                  if (date != null && mounted) {
                    final months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
                    final days = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
                    setState(() {
                      _selectedDateLabel = '${days[date.weekday - 1]} ${date.day} ${months[date.month - 1]}';
                    });
                  }
                },
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(child: Text(ds.notifyNewRequests, style: const TextStyle(fontSize: 15))),
                    GestureDetector(
                      onTap: _showNotificationHelp,
                      child: Icon(Icons.help_outline, color: AppColors.rappiRed, size: 20),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: _notifyNewRequests,
                      onChanged: (v) => setState(() => _notifyNewRequests = v),
                      activeTrackColor: AppColors.rappiRed,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              GestureDetector(
                onTap: _showUnlimitedPaymentSheet,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.all_inclusive, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(ds.unlimitedRequests, style: const TextStyle(fontSize: 15))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: _unlimitedActive ? AppColors.rappiRed : AppColors.error,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _unlimitedActive ? ds.active : 'Inactivo',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Empty state
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions_car, size: 64, color: AppColors.getTextSecondary(context).withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                Text('No hay solicitudes de viaje', style: TextStyle(fontSize: 16, color: AppColors.getTextSecondary(context))),
                Text('entre ciudades disponibles', style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context).withValues(alpha: 0.7))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMisViajesTab() {
    final ds = DriverStrings(Localizations.localeOf(context).languageCode);
    return Column(
      children: [
        // Filter chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTripFilterChip(ds.accepted, 0, 0),
                const SizedBox(width: 8),
                _buildTripFilterChip(ds.pending, 1, 0),
                const SizedBox(width: 8),
                _buildTripFilterChip(ds.archived, 2, 0),
              ],
            ),
          ),
        ),

        // Empty state
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _myTripsFilter == 0
                        ? 'Todavía no tienes solicitudes aceptadas'
                        : _myTripsFilter == 1
                            ? 'No tienes solicitudes pendientes'
                            : 'No tienes solicitudes archivadas',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.getTextPrimary(context)),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => setState(() => _bottomNavIndex = 0),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.rappiRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(ds.searchRequest, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTripFilterChip(String label, int index, int count) {
    final isSelected = _myTripsFilter == index;
    return GestureDetector(
      onTap: () => setState(() => _myTripsFilter = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.getTextPrimary(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isSelected ? Colors.transparent : AppColors.getBorder(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.getSurface(context) : AppColors.getTextPrimary(context),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.getSurface(context).withValues(alpha: 0.7) : AppColors.getTextSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCityPicker(String type) {
    final ds = DriverStrings(Localizations.localeOf(context).languageCode);
    final typeLabel = type == 'origen' ? ds.origin.toLowerCase() : ds.destination.toLowerCase();
    showResponsiveBottomSheet(
      context: context,
      showDragHandle: false,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => _CityPickerSheet(
          typeLabel: typeLabel,
          selectCityLabel: ds.selectCity,
          searchCityHint: ds.searchCity,
          cities: _allCities,
          onCitySelected: (city) {
            Navigator.pop(ctx);
            setState(() {
              if (type == 'origen') {
                _originCity = city;
              } else {
                _destinationCity = city;
              }
            });
          },
          scrollController: scrollController,
        ),
      ),
    );
  }
}

class _CityPickerSheet extends StatefulWidget {
  final String typeLabel;
  final String selectCityLabel;
  final String searchCityHint;
  final List<String> cities;
  final ValueChanged<String> onCitySelected;
  final ScrollController scrollController;

  const _CityPickerSheet({
    required this.typeLabel,
    required this.selectCityLabel,
    required this.searchCityHint,
    required this.cities,
    required this.onCitySelected,
    required this.scrollController,
  });

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  String _search = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _search.isEmpty
        ? widget.cities
        : widget.cities.where((c) => c.toLowerCase().contains(_search.toLowerCase())).toList();

    return Column(
      children: [
        // Handle
        const SizedBox(height: 8),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 12),

        // Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '${widget.selectCityLabel} - ${widget.typeLabel}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),

        // Search field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: widget.searchCityHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _search = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.getBackground(context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // City list
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text('No se encontraron ciudades', style: TextStyle(color: AppColors.getTextSecondary(context))))
              : ListView.builder(
                  controller: widget.scrollController,
                  itemCount: filtered.length,
                  itemBuilder: (_, index) {
                    final city = filtered[index];
                    return ListTile(
                      leading: Icon(Icons.location_city, color: AppColors.getTextSecondary(context), size: 20),
                      title: Text(city, style: const TextStyle(fontSize: 16)),
                      onTap: () => widget.onCitySelected(city),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FilterRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  const _FilterRow({required this.icon, required this.iconColor, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(fontSize: 16, color: AppColors.getTextPrimary(context)))),
          ],
        ),
      ),
    );
  }
}

// Info page about unlimited requests
class _UnlimitedInfoPage extends StatelessWidget {
  const _UnlimitedInfoPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      body: SafeArea(
        child: Column(
          children: [
            // Close button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text('Cerrar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
                ),
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Hero section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      color: const Color(0xFFFFF8E1),
                      child: Column(
                        children: [
                          // Illustration
                          Container(
                            width: 220,
                            height: 180,
                            decoration: BoxDecoration(
                              color: AppColors.rappiRed.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Positioned(
                                  left: 15, top: 15,
                                  child: Transform.rotate(
                                    angle: -0.2,
                                    child: Container(width: 50, height: 50, decoration: BoxDecoration(color: AppColors.rappiRed.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8))),
                                  ),
                                ),
                                Positioned(
                                  right: 20, bottom: 20,
                                  child: Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.rappiRed.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8))),
                                ),
                                Icon(Icons.all_inclusive, size: 80, color: AppColors.rappiRed.withValues(alpha: 0.6)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              'Solicitudes ilimitadas por 24 horas',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppColors.getTextPrimary(context), height: 1.1),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              'Paga una vez y disfruta de solicitudes ilimitadas, sin cobros extra',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 17, color: AppColors.getTextSecondary(context), height: 1.4),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Desliza hacia abajo y descubre más ↓',
                            style: TextStyle(fontSize: 15, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),

                    // How it works section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      color: AppColors.rappiRed.withValues(alpha: 0.1),
                      child: Column(
                        children: [
                          Text(
                            'Cómo funcionan las solicitudes',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.rappiRed),
                          ),
                          const SizedBox(height: 24),
                          _infoCard(context, Icons.payment, 'Pago único', 'Paga una sola vez al día y accede a todas las solicitudes de viaje entre ciudades sin cargos adicionales.'),
                          const SizedBox(height: 12),
                          _infoCard(context, Icons.access_time, '24 horas', 'Tu acceso dura 24 horas completas desde el momento de la activación.'),
                          const SizedBox(height: 12),
                          _infoCard(context, Icons.swap_horiz, 'Ida y vuelta', 'Incluye viajes de ida y vuelta. Publica tu ruta y recibe pasajeros en ambas direcciones.'),
                          const SizedBox(height: 12),
                          _infoCard(context, Icons.money_off, 'Sin comisión extra', 'No se cobra comisión adicional cuando un pasajero acepta tu oferta de viaje entre ciudades.'),
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

  Widget _infoCard(BuildContext context, IconData icon, String title, String description) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28, color: AppColors.rappiRed),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
                const SizedBox(height: 4),
                Text(description, style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context), height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
