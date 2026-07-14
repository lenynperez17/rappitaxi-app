import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive_bottom_sheet.dart';
import '../../providers/preferences_provider.dart';
import '../../services/rapi_api_client.dart';
import '../../services/sound_service.dart';
import '../../core/l10n/driver_strings.dart';
import 'driver_comfort_rules_screen.dart';

class DriverRideConfigScreen extends StatefulWidget {
  const DriverRideConfigScreen({super.key});

  @override
  State<DriverRideConfigScreen> createState() => _DriverRideConfigScreenState();
}

class _DriverRideConfigScreenState extends State<DriverRideConfigScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Tarifas tab state
  String _vehicleName = '';
  String _vehiclePlate = '';
  bool _tripEnabled = true;
  bool _comfortEnabled = false;
  bool _xlEnabled = false;
  bool _packageDelivery = true;
  bool _thermalBag = false;

  // Solicitudes tab state
  bool _rideSounds = false;
  bool _requestChain = false;
  String _selectedNavigator = 'Google Maps';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      // 1) Nombre/placa del vehículo desde el backend Node (perfil de driver).
      try {
        final profile = await RapiApiClient.instance.myDriverProfile();
        final vehicle = (profile['vehicle'] as Map?)?.cast<String, dynamic>();
        String vehicleName = '';
        String plate = '';
        if (vehicle != null) {
          final make = (vehicle['make'] ?? vehicle['brand'] ?? '') as String;
          final model = (vehicle['model'] ?? '') as String;
          vehicleName = [make, model].where((s) => s.isNotEmpty).join(' ');
          plate = (vehicle['plate'] ?? vehicle['licensePlate'] ?? '') as String;
        }
        if (mounted) {
          setState(() {
            _vehicleName = vehicleName;
            _vehiclePlate = plate;
          });
        }
      } catch (_) {}

      // 2) Preferencias de servicio — TODO(node-migration): reemplazar con
      // endpoint /api/drivers/me/service-preferences cuando exista. Mientras
      // tanto persistimos localmente en SharedPreferences.
      final sp = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _tripEnabled = sp.getBool('driver.pref.trip') ?? true;
          _comfortEnabled = sp.getBool('driver.pref.comfort') ?? false;
          _xlEnabled = sp.getBool('driver.pref.xl') ?? false;
          _packageDelivery = sp.getBool('driver.pref.packageDelivery') ?? true;
          _thermalBag = sp.getBool('driver.pref.thermalBag') ?? false;
          _rideSounds = sp.getBool('driver.pref.rideSounds') ?? false;
          _requestChain = sp.getBool('driver.pref.requestChain') ?? false;
          _selectedNavigator =
              sp.getString('driver.pref.navigator') ?? 'Google Maps';

          // Sync SoundService with saved preference
          SoundService().setEnabled(_rideSounds);
        });
      }
    } catch (_) {}
  }

  Future<void> _savePreference(String key, bool value) async {
    // TODO(node-migration): reemplazar con endpoint
    // /api/drivers/me/service-preferences cuando exista.
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool('driver.pref.$key', value);
    } catch (_) {}
  }

  Future<void> _saveStringPreference(String key, String value) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString('driver.pref.$key', value);
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ds = DriverStrings(Localizations.localeOf(context).languageCode);
    return Scaffold(
      backgroundColor: AppColors.getSurface(context),
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back, size: 28, color: AppColors.getTextPrimary(context)),
                  ),
                  Expanded(
                    child: Center(child: Text(ds.configuration, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
                  ),
                  const SizedBox(width: 28),
                ],
              ),
            ),

            // Tab bar
            TabBar(
              controller: _tabController,
              labelColor: AppColors.getTextPrimary(context),
              unselectedLabelColor: AppColors.getTextSecondary(context),
              labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              indicatorColor: AppColors.getTextPrimary(context),
              indicatorWeight: 3,
              tabs: [
                Tab(text: ds.rates),
                Tab(text: ds.requests),
              ],
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTarifasTab(),
                  _buildSolicitudesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTarifasTab() {
    final ds = DriverStrings(Localizations.localeOf(context).languageCode);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vehicle info
          if (_vehicleName.isNotEmpty || _vehiclePlate.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.getBorder(context))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _vehicleName.isNotEmpty ? _vehicleName : 'Vehículo',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context)),
                        ),
                        if (_vehiclePlate.isNotEmpty)
                          Text(_vehiclePlate, style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context))),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(ds.contactSupportToChange)),
                      );
                    },
                    child: Text(ds.change),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // Viajes section
          Text(ds.trips2, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
          const SizedBox(height: 8),
          _buildToggleItem(ds.trip, null, _tripEnabled, (v) {
            setState(() => _tripEnabled = v);
            _savePreference('trip', v);
          }),
          _buildToggleItem(ds.comfort, null, _comfortEnabled, (v) {
            setState(() => _comfortEnabled = v);
            _savePreference('comfort', v);
          }),
          _buildToggleItem(ds.xl, ds.xlNotAvailable, _xlEnabled, (v) {
            setState(() => _xlEnabled = v);
            _savePreference('xl', v);
          }, enabled: false),
          const SizedBox(height: 24),

          // Entregas section
          Text(ds.deliveries, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
          const SizedBox(height: 8),
          _buildToggleItem(ds.packageDelivery, null, _packageDelivery, (v) {
            setState(() => _packageDelivery = v);
            _savePreference('packageDelivery', v);
          }),
          _buildToggleItem(ds.thermalBag, null, _thermalBag, (v) {
            setState(() => _thermalBag = v);
            _savePreference('thermalBag', v);
          }),
          const SizedBox(height: 16),

          // Service type descriptions
          _buildServiceCard(
            icon: Icons.directions_car,
            title: ds.trip,
            description: ds.basicTrip,
            highlighted: true,
          ),
          const SizedBox(height: 8),
          _buildServiceCard(
            icon: Icons.directions_car,
            title: ds.comfort,
            description: ds.comfortDesc,
            highlighted: false,
            buttons: [ds.comfortRules, ds.comfortRequirements],
          ),
          const SizedBox(height: 8),
          _buildServiceCard(
            icon: Icons.airport_shuttle,
            title: ds.vehicle6Passengers,
            description: ds.vehicle6Desc,
            highlighted: false,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSolicitudesTab() {
    final ds = DriverStrings(Localizations.localeOf(context).languageCode);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dark mode
          Row(
            children: [
              Icon(Icons.dark_mode_outlined, size: 24, color: AppColors.getTextPrimary(context)),
              const SizedBox(width: 12),
              Text(ds.darkMode, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
            ],
          ),
          const SizedBox(height: 12),
          Consumer<PreferencesProvider>(
            builder: (context, prefs, _) {
              final darkMode = prefs.darkMode;
              return Row(
                children: [
                  _buildModeButton(ds.disable, 'off', !darkMode ? 'off' : 'other', () {
                    prefs.setDarkMode(false);
                  }),
                  const SizedBox(width: 8),
                  _buildModeButton(ds.enable, 'on', darkMode ? 'on' : 'other', () {
                    prefs.setDarkMode(true);
                  }),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Ride sounds
          Row(
            children: [
              Icon(Icons.notifications_outlined, size: 24, color: AppColors.getTextPrimary(context)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ds.rideSounds, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
                    const SizedBox(height: 4),
                    Text(ds.rideSoundsDesc, style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context))),
                  ],
                ),
              ),
              Switch(
                value: _rideSounds,
                onChanged: (v) {
                  setState(() => _rideSounds = v);
                  SoundService().setEnabled(v);
                  _savePreference('rideSounds', v);
                },
                activeTrackColor: AppColors.getTextPrimary(context),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Request chain
          Row(
            children: [
              Icon(Icons.double_arrow, size: 24, color: AppColors.getTextPrimary(context)),
              const SizedBox(width: 12),
              Text(ds.requestChain, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(ds.requestChain),
                      content: Text(ds.requestChainDesc),
                      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ds.understood))],
                    ),
                  );
                },
                child: Icon(Icons.help_outline, size: 18, color: AppColors.getTextSecondary(context)),
              ),
              const Spacer(),
              Switch(
                value: _requestChain,
                onChanged: (v) {
                  setState(() => _requestChain = v);
                  _savePreference('requestChain', v);
                },
                activeTrackColor: AppColors.getTextPrimary(context),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Navigator
          GestureDetector(
            onTap: () {
              showResponsiveBottomSheet(
                context: context,
                builder: (ctx) {
                  final navOptions = [
                    {'name': 'Google Maps', 'icon': Icons.map},
                    {'name': 'Waze', 'icon': Icons.navigation},
                    {'name': 'Apple Maps', 'icon': Icons.explore},
                  ];
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(padding: const EdgeInsets.all(16), child: Text(ds.navigator, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                      ...navOptions.map((opt) {
                        final name = opt['name'] as String;
                        final icon = opt['icon'] as IconData;
                        final isActive = _selectedNavigator == name;
                        return ListTile(
                          title: Text(name, style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
                          leading: Icon(icon, color: isActive ? AppColors.rappiRed : null),
                          trailing: isActive ? const Icon(Icons.check, color: AppColors.rappiRed) : null,
                          onTap: () {
                            setState(() => _selectedNavigator = name);
                            _saveStringPreference('navigator', name);
                            Navigator.pop(ctx);
                          },
                        );
                      }),
                      const SizedBox(height: 8),
                    ],
                  );
                },
              );
            },
            child: Row(
              children: [
                Icon(Icons.navigation, size: 24, color: AppColors.getTextPrimary(context)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ds.navigator, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(context))),
                      Text(_selectedNavigator, style: TextStyle(fontSize: 13, color: AppColors.getTextSecondary(context))),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.getTextSecondary(context)),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildToggleItem(String title, String? subtitle, bool value, ValueChanged<bool> onChanged, {bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600,
                  color: enabled ? AppColors.getTextPrimary(context) : AppColors.getTextSecondary(context),
                )),
                if (subtitle != null)
                  Text(subtitle, style: TextStyle(fontSize: 13, color: AppColors.getTextSecondary(context))),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeTrackColor: AppColors.getTextPrimary(context),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard({
    required IconData icon,
    required String title,
    required String description,
    required bool highlighted,
    List<String>? buttons,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.rappiRed.withValues(alpha: 0.08) : AppColors.getBackground(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 24, color: highlighted ? AppColors.rappiRed : AppColors.getTextSecondary(context)),
              const SizedBox(width: 10),
              Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context))),
            ],
          ),
          const SizedBox(height: 8),
          Text(description, style: TextStyle(fontSize: 14, color: AppColors.getTextSecondary(context), height: 1.4)),
          if (buttons != null) ...[
            const SizedBox(height: 12),
            ...buttons.asMap().entries.map((entry) {
              final index = entry.key;
              final label = entry.value;
              return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => DriverComfortRulesScreen(initialPage: index),
                    ));
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildModeButton(String label, String value, String currentValue, VoidCallback onTap) {
    final isSelected = currentValue == value;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.getTextPrimary(context) : AppColors.getBackground(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isSelected ? Colors.transparent : AppColors.getBorder(context)),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.getSurface(context) : AppColors.getTextPrimary(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
