import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/shift.dart';
import '../providers/shift_provider.dart';
import '../../../../shared/providers/user_provider.dart';

/// Pantalla para crear o editar un turno
class CreateShiftScreen extends StatefulWidget {
  final Shift? shift;

  const CreateShiftScreen({super.key, this.shift});

  @override
  State<CreateShiftScreen> createState() => _CreateShiftScreenState();
}

class _CreateShiftScreenState extends State<CreateShiftScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 16, minute: 0);
  final List<String> _selectedDays = [];
  
  bool _isLoading = false;

  final List<Map<String, String>> _weekDays = [
    {'key': 'monday', 'label': 'Lunes'},
    {'key': 'tuesday', 'label': 'Martes'},
    {'key': 'wednesday', 'label': 'Miércoles'},
    {'key': 'thursday', 'label': 'Jueves'},
    {'key': 'friday', 'label': 'Viernes'},
    {'key': 'saturday', 'label': 'Sábado'},
    {'key': 'sunday', 'label': 'Domingo'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.shift != null) {
      _initializeFromShift();
    } else {
      _selectedDays.add(_getCurrentDayKey());
    }
  }

  void _initializeFromShift() {
    final shift = widget.shift!;
    _selectedDate = shift.startTime;
    _startTime = TimeOfDay.fromDateTime(shift.startTime);
    _endTime = TimeOfDay.fromDateTime(shift.endTime);
    _selectedDays.addAll(shift.workDays);
    _notesController.text = shift.notes ?? '';
  }

  String _getCurrentDayKey() {
    final weekday = DateTime.now().weekday;
    return _weekDays[weekday - 1]['key']!;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.shift != null ? 'Editar Turno' : 'Crear Turno'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveShift,
            child: Text(
              'GUARDAR',
              style: TextStyle(
                color: _isLoading ? Colors.grey : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDateSection(),
                    const SizedBox(height: 24),
                    _buildTimeSection(),
                    const SizedBox(height: 24),
                    _buildDaysSection(),
                    const SizedBox(height: 24),
                    _buildNotesSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDateSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fecha del Turno',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.grey[600]),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('EEEE, dd MMM yyyy', 'es').format(_selectedDate),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Horario',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTimeField(
                    'Hora de Inicio',
                    _startTime,
                    Icons.schedule,
                    (time) => setState(() => _startTime = time),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTimeField(
                    'Hora de Fin',
                    _endTime,
                    Icons.schedule_send,
                    (time) => setState(() => _endTime = time),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeField(
    String label,
    TimeOfDay time,
    IconData icon,
    Function(TimeOfDay) onTimeSelected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _selectTime(time, onTimeSelected),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.grey[600], size: 20),
                const SizedBox(width: 8),
                Text(
                  time.format(context),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDaysSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Días de la Semana',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: _weekDays.map((day) {
                final isSelected = _selectedDays.contains(day['key']);
                return FilterChip(
                  label: Text(day['label']!),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedDays.add(day['key']!);
                      } else {
                        _selectedDays.remove(day['key']!);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notas (Opcional)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Agrega cualquier nota adicional sobre este turno...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  Future<void> _selectTime(
    TimeOfDay initialTime,
    Function(TimeOfDay) onTimeSelected,
  ) async {
    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (time != null) {
      onTimeSelected(time);
    }
  }

  Future<void> _saveShift() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona al menos un día de la semana'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userProvider = context.read<UserProvider>();
      final shiftProvider = context.read<ShiftProvider>();

      if (userProvider.user?.uid == null) {
        throw Exception('Usuario no autenticado');
      }

      final startDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _startTime.hour,
        _startTime.minute,
      );

      var endDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _endTime.hour,
        _endTime.minute,
      );

      // Si la hora de fin es menor a la de inicio, es al día siguiente
      if (endDateTime.isBefore(startDateTime)) {
        endDateTime = endDateTime.add(const Duration(days: 1));
      }

      final shift = Shift(
        id: widget.shift?.id ?? '',
        driverId: userProvider.user!.uid,
        startTime: startDateTime,
        endTime: endDateTime,
        status: widget.shift?.status ?? ShiftStatus.scheduled,
        workDays: _selectedDays,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        actualStartTime: widget.shift?.actualStartTime,
        actualEndTime: widget.shift?.actualEndTime,
        actualEarnings: widget.shift?.actualEarnings ?? 0.0,
        completedRides: widget.shift?.completedRides ?? 0,
        createdAt: widget.shift?.createdAt,
        updatedAt: DateTime.now(),
      );

      bool success;
      if (widget.shift != null) {
        success = await shiftProvider.updateShift(shift);
      } else {
        success = await shiftProvider.createShift(shift);
      }

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.shift != null 
                  ? 'Turno actualizado correctamente' 
                  : 'Turno creado correctamente',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
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