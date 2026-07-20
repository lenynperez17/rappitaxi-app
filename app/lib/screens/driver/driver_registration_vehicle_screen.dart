// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive_bottom_sheet.dart';
import '../../utils/safe_navigation.dart';

/// Pantalla 3: Datos del vehículo
class DriverRegistrationVehicleScreen extends StatefulWidget {
  final Map<String, dynamic> registrationData;

  const DriverRegistrationVehicleScreen({
    super.key,
    required this.registrationData,
  });

  @override
  State<DriverRegistrationVehicleScreen> createState() => _DriverRegistrationVehicleScreenState();
}

class _DriverRegistrationVehicleScreenState extends State<DriverRegistrationVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _plateController = TextEditingController();

  String? _selectedBrand;
  String? _selectedModel;
  int? _selectedYear;
  String? _selectedColor;
  File? _vehicleImage;
  final _picker = ImagePicker();

  // Listas de opciones - Marcas ordenadas alfabéticamente
  final List<String> _brands = [
    'BAIC', 'BYD', 'Changan', 'Chery', 'Chevrolet', 'Citroën',
    'Daewoo', 'Daihatsu', 'DFSK', 'Dodge', 'FAW', 'Fiat',
    'Ford', 'Foton', 'Geely', 'Great Wall', 'Haval', 'Honda',
    'Hyundai', 'JAC', 'Jeep', 'Kia', 'Lifan', 'Mazda',
    'Mercedes-Benz', 'MG', 'Mitsubishi', 'Nissan', 'Peugeot',
    'Renault', 'Ssangyong', 'Subaru', 'Suzuki', 'Toyota',
    'Volkswagen', 'Volvo', 'Wuling', 'Zotye', 'Otro'
  ];

  final Map<String, List<String>> _modelsByBrand = {
    'BAIC': ['X25', 'X35', 'X55', 'D20', 'M50', 'Senova X25', 'Otro'],
    'BYD': ['F3', 'Song Plus', 'Yuan Plus', 'Dolphin', 'Seal', 'Han', 'Tang', 'Atto 3', 'E1', 'E2', 'Otro'],
    'Changan': ['Alsvin', 'CS15', 'CS35 Plus', 'CS55 Plus', 'CS75 Plus', 'Eado', 'V7', 'Honor', 'Star', 'Otro'],
    'Chery': ['Tiggo 2', 'Tiggo 3', 'Tiggo 4', 'Tiggo 5X', 'Tiggo 7', 'Tiggo 8', 'Arrizo 5', 'QQ', 'Fulwin', 'Otro'],
    'Chevrolet': ['Sail', 'Spark', 'Aveo', 'Cruze', 'Beat', 'Onix', 'Tracker', 'Captiva', 'N300', 'N400', 'Groove', 'Cobalt', 'Otro'],
    'Citroën': ['C3', 'C4', 'C-Elysée', 'Berlingo', 'C4 Cactus', 'Otro'],
    'Daewoo': ['Matiz', 'Lanos', 'Cielo', 'Tico', 'Racer', 'Otro'],
    'Daihatsu': ['Terios', 'Sirion', 'Rocky', 'Charade', 'Otro'],
    'DFSK': ['Glory 330', 'Glory 560', 'K01', 'K05', 'C35', 'C37', 'V21', 'V22', 'Otro'],
    'Dodge': ['Journey', 'Attitude', 'Neon', 'Ram', 'Durango', 'Otro'],
    'FAW': ['N5', 'R7', 'D60', 'T77', 'Besturn B30', 'Otro'],
    'Fiat': ['Uno', 'Palio', 'Mobi', 'Argo', 'Cronos', 'Strada', 'Toro', '500', 'Punto', 'Otro'],
    'Ford': ['Focus', 'Fiesta', 'Escape', 'Ranger', 'EcoSport', 'Explorer', 'Ka', 'Fusion', 'Territory', 'Mustang', 'F-150', 'Edge', 'Otro'],
    'Foton': ['Tunland', 'Sauvana', 'Gratour', 'View', 'Toano', 'Otro'],
    'Geely': ['Coolray', 'Azkarra', 'Emgrand', 'GC6', 'CK', 'Monjaro', 'Otro'],
    'Great Wall': ['Wingle 5', 'Wingle 6', 'Wingle 7', 'H3', 'H5', 'H6', 'Poer', 'Otro'],
    'Haval': ['H1', 'H2', 'H6', 'Jolion', 'Dargo', 'H9', 'Otro'],
    'Honda': ['Civic', 'City', 'CR-V', 'HR-V', 'Fit', 'Accord', 'Jazz', 'WR-V', 'BR-V', 'Pilot', 'Otro'],
    'Hyundai': ['Accent', 'Elantra', 'Tucson', 'i10', 'i20', 'Grand i10', 'Creta', 'Santa Fe', 'Kona', 'Venue', 'Verna', 'Ioniq', 'Starex', 'H1', 'Otro'],
    'JAC': ['S1', 'S2', 'S3', 'S4', 'S5', 'S7', 'J2', 'J3', 'J4', 'iEV', 'Refine', 'X200', 'Otro'],
    'Jeep': ['Renegade', 'Compass', 'Cherokee', 'Grand Cherokee', 'Wrangler', 'Otro'],
    'Kia': ['Rio', 'Cerato', 'Sportage', 'Picanto', 'Soul', 'Seltos', 'Sorento', 'Stonic', 'Carnival', 'K3', 'Niro', 'Forte', 'Otro'],
    'Lifan': ['X50', 'X60', 'X70', '520', '530', '620', 'Otro'],
    'Mazda': ['2', '3', '6', 'CX-3', 'CX-5', 'CX-30', 'CX-50', 'CX-9', 'BT-50', 'Otro'],
    'Mercedes-Benz': ['Clase A', 'Clase C', 'Clase E', 'GLA', 'GLC', 'Sprinter', 'Vito', 'Otro'],
    'MG': ['3', '5', 'ZS', 'HS', 'RX5', 'GT', 'ZS EV', 'Marvel R', 'MG One', 'Otro'],
    'Mitsubishi': ['Lancer', 'ASX', 'Outlander', 'L200', 'Eclipse Cross', 'Mirage', 'Xpander', 'Montero', 'Pajero', 'Otro'],
    'Nissan': ['Sentra', 'Versa', 'March', 'Frontier', 'Kicks', 'Note', 'Tiida', 'Almera', 'Qashqai', 'X-Trail', 'Navara', 'NP300', 'Juke', 'V16', 'Otro'],
    'Peugeot': ['208', '301', '308', '2008', '3008', '5008', 'Partner', 'Rifter', 'Otro'],
    'Renault': ['Logan', 'Sandero', 'Duster', 'Kwid', 'Stepway', 'Captur', 'Koleos', 'Kangoo', 'Symbol', 'Clio', 'Otro'],
    'Ssangyong': ['Tivoli', 'Korando', 'Rexton', 'Musso', 'Actyon', 'Otro'],
    'Subaru': ['Impreza', 'XV', 'Forester', 'Outback', 'Legacy', 'WRX', 'Otro'],
    'Suzuki': ['Swift', 'Alto', 'Dzire', 'Vitara', 'Ignis', 'S-Cross', 'Ciaz', 'Celerio', 'Jimny', 'Ertiga', 'APV', 'Carry', 'Otro'],
    'Toyota': ['Corolla', 'Yaris', 'RAV4', 'Hilux', 'Avanza', 'Etios', 'Probox', 'Vitz', 'Rush', 'Fortuner', 'Land Cruiser', 'Camry', 'Prius', 'Agya', 'Urban Cruiser', 'Prado', 'Starlet', 'Innova', '4Runner', 'Tacoma', 'Otro'],
    'Volkswagen': ['Gol', 'Polo', 'Jetta', 'Tiguan', 'Virtus', 'T-Cross', 'Taos', 'Amarok', 'Saveiro', 'Up!', 'Golf', 'Nivus', 'Otro'],
    'Volvo': ['XC40', 'XC60', 'XC90', 'S60', 'S90', 'V40', 'Otro'],
    'Wuling': ['Hongguang', 'Almaz', 'Cortez', 'Confero', 'Air EV', 'Otro'],
    'Zotye': ['T300', 'T500', 'T600', 'T700', 'Z100', 'Z300', 'Otro'],
    'Otro': ['Otro'],
  };

  final List<String> _colors = [
    'Blanco', 'Negro', 'Plata', 'Plateado', 'Gris', 'Gris Oscuro',
    'Rojo', 'Azul', 'Azul Oscuro', 'Celeste', 'Verde', 'Verde Oscuro',
    'Amarillo', 'Naranja', 'Marrón', 'Beige', 'Crema', 'Champagne',
    'Dorado', 'Bronce', 'Vino', 'Guinda', 'Turquesa', 'Otro'
  ];

  List<int> get _years {
    final currentYear = DateTime.now().year;
    return List.generate(30, (index) => currentYear - index);
  }

  @override
  void dispose() {
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _pickVehicleImage() async {
    final source = await showResponsiveBottomSheet<ImageSource>(
      context: context,
      builder: (context) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Tomar foto'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Elegir de galería'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    );

    if (source == null || !mounted) return;

    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 80,
    );

    if (pickedFile != null && mounted) {
      setState(() => _vehicleImage = File(pickedFile.path));
    }
  }

  bool get _isFormValid {
    return _selectedBrand != null &&
        _selectedModel != null &&
        _selectedYear != null &&
        _selectedColor != null &&
        _plateController.text.length >= 6 &&
        _vehicleImage != null;
  }

  @override
  Widget build(BuildContext context) {
    final workType = widget.registrationData['workType'] as String? ?? 'driver';
    final isCourier = workType == 'courier';

    return Scaffold(
      backgroundColor: AppColors.getSurface(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.getTextPrimary(context)),
          onPressed: () => safePopOrHome(context),
        ),
        title: Text(
          'Paso 2 de 4',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.getTextSecondary(context),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCourier ? 'Tu vehículo de reparto' : 'Información del vehículo',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Datos de tu ${workType == 'moto' ? 'moto' : 'vehículo'}',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
                const SizedBox(height: 32),

                // Marca
                _buildDropdown(
                  label: 'Marca',
                  value: _selectedBrand,
                  items: _brands,
                  onChanged: (value) {
                    setState(() {
                      _selectedBrand = value;
                      _selectedModel = null;
                    });
                  },
                ),

                const SizedBox(height: 20),

                // Modelo
                _buildDropdown(
                  label: 'Modelo',
                  value: _selectedModel,
                  items: _selectedBrand != null
                      ? _modelsByBrand[_selectedBrand] ?? ['Otro']
                      : [],
                  onChanged: (value) => setState(() => _selectedModel = value),
                  enabled: _selectedBrand != null,
                ),

                const SizedBox(height: 20),

                // Año y Color en fila
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown(
                        label: 'Año',
                        value: _selectedYear?.toString(),
                        items: _years.map((y) => y.toString()).toList(),
                        onChanged: (value) => setState(() => _selectedYear = int.tryParse(value ?? '')),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDropdown(
                        label: 'Color',
                        value: _selectedColor,
                        items: _colors,
                        onChanged: (value) => setState(() => _selectedColor = value),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Placa
                Text(
                  'Placa',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _plateController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    UpperCaseTextFormatter(),
                    LengthLimitingTextInputFormatter(7),
                  ],
                  decoration: InputDecoration(
                    hintText: 'ABC-123',
                    prefixIcon: const Icon(Icons.pin_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: AppColors.getInputFill(context),
                  ),
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: 24),

                // Foto del vehículo
                Text(
                  'Foto del vehículo',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickVehicleImage,
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.getInputFill(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _vehicleImage != null
                            ? AppColors.success
                            : AppColors.getBorder(context),
                        width: 2,
                      ),
                      image: _vehicleImage != null
                          ? DecorationImage(
                              image: FileImage(_vehicleImage!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _vehicleImage == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo_rounded,
                                size: 48,
                                color: AppColors.rappiRed,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Tomar foto del vehículo',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.rappiRed,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Muestra el frente y la placa',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.getTextSecondary(context),
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),

                const SizedBox(height: 40),

                // Botón Continuar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isFormValid
                        ? () {
                            final data = Map<String, dynamic>.from(widget.registrationData);
                            data.addAll({
                              'vehicleBrand': _selectedBrand,
                              'vehicleModel': _selectedModel,
                              'vehicleYear': _selectedYear,
                              'vehicleColor': _selectedColor,
                              'vehiclePlate': _plateController.text,
                              'vehiclePhotoLocalPath': _vehicleImage!.path,
                            });

                            Navigator.pushNamed(
                              context,
                              '/driver/register/documents',
                              arguments: data,
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.rappiRed,
                      disabledBackgroundColor: Colors.grey[300],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Continuar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _isFormValid ? Colors.white : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.getTextPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.getInputFill(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.getBorder(context)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              hint: Text(
                'Seleccionar',
                style: TextStyle(color: AppColors.getTextSecondary(context)),
              ),
              isExpanded: true,
              items: items.map((item) {
                return DropdownMenuItem(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// Formateador para convertir texto a mayúsculas
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
