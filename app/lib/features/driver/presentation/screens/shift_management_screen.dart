import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/shift_provider.dart';
import '../../domain/entities/shift.dart';
import '../widgets/shift_card.dart';
import '../widgets/active_shift_widget.dart';
import '../widgets/shift_calendar_widget.dart';
import '../widgets/shift_stats_widget.dart';
import 'create_shift_screen.dart';
import 'shift_templates_screen.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/providers/user_provider.dart';

/// Pantalla principal para gestionar turnos del conductor
class ShiftManagementScreen extends StatefulWidget {
  const ShiftManagementScreen({super.key});

  @override
  State<ShiftManagementScreen> createState() => _ShiftManagementScreenState();
}

class _ShiftManagementScreenState extends State<ShiftManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadData() {
    final userProvider = context.read<UserProvider>();
    final shiftProvider = context.read<ShiftProvider>();
    
    if (userProvider.user?.uid != null) {
      shiftProvider.loadShifts(userProvider.user!.uid);
      shiftProvider.loadTemplates(userProvider.user!.uid);
      shiftProvider.loadStats(userProvider.user!.uid, _selectedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Turnos'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.today), text: 'Hoy'),
            Tab(icon: Icon(Icons.calendar_month), text: 'Calendario'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Estadísticas'),
            Tab(icon: Icon(Icons.template_outlined), text: 'Plantillas'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createNewShift,
          ),
        ],
      ),
      body: Consumer<ShiftProvider>(
        builder: (context, shiftProvider, child) {
          if (shiftProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (shiftProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    shiftProvider.error!,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.red[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadData,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildTodayTab(shiftProvider),
              _buildCalendarTab(shiftProvider),
              _buildStatsTab(shiftProvider),
              _buildTemplatesTab(shiftProvider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTodayTab(ShiftProvider shiftProvider) {
    final todayShifts = shiftProvider.getTodayShifts();
    final activeShift = shiftProvider.activeShift;

    return RefreshIndicator(
      onRefresh: () async => _loadData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Turno activo
            if (activeShift != null) ...[
              ActiveShiftWidget(
                shift: activeShift,
                onEndShift: _endShift,
              ),
              const SizedBox(height: 16),
            ],

            // Turnos de hoy
            Text(
              'Turnos de Hoy (${DateFormat('dd/MM/yyyy').format(DateTime.now())})',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            if (todayShifts.isEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.event_available,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No tienes turnos programados para hoy',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _createNewShift,
                        icon: const Icon(Icons.add),
                        label: const Text('Crear Turno'),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              ...todayShifts.map((shift) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ShiftCard(
                  shift: shift,
                  onStart: () => _startShift(shift),
                  onEdit: () => _editShift(shift),
                  onDelete: () => _deleteShift(shift),
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarTab(ShiftProvider shiftProvider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ShiftCalendarWidget(
        shifts: shiftProvider.shifts,
        selectedDate: _selectedDate,
        onDateSelected: (date) {
          setState(() {
            _selectedDate = date;
          });
        },
        onShiftTap: (shift) => _showShiftDetails(shift),
      ),
    );
  }

  Widget _buildStatsTab(ShiftProvider shiftProvider) {
    return RefreshIndicator(
      onRefresh: () async {
        final userProvider = context.read<UserProvider>();
        if (userProvider.user?.uid != null) {
          await shiftProvider.loadStats(userProvider.user!.uid, _selectedDate);
        }
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selector de mes
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.date_range, color: AppTheme.primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Estadísticas de ${DateFormat('MMMM yyyy', 'es').format(_selectedDate)}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => _changeStatsMonth(-1),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => _changeStatsMonth(1),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Widget de estadísticas
            ShiftStatsWidget(stats: shiftProvider.stats),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplatesTab(ShiftProvider shiftProvider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Plantillas de Turnos',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _createTemplate,
                icon: const Icon(Icons.add),
                label: const Text('Nueva Plantilla'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ShiftTemplatesScreen(
              templates: shiftProvider.templates,
              onEditTemplate: _editTemplate,
              onDeleteTemplate: _deleteTemplate,
              onCreateFromTemplate: _createFromTemplate,
            ),
          ),
        ],
      ),
    );
  }

  void _createNewShift() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CreateShiftScreen(),
      ),
    ).then((_) => _loadData());
  }

  void _editShift(Shift shift) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateShiftScreen(shift: shift),
      ),
    ).then((_) => _loadData());
  }

  void _startShift(Shift shift) async {
    final shiftProvider = context.read<ShiftProvider>();
    final success = await shiftProvider.startShift(shift.id);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Turno iniciado correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _endShift(Shift shift) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _EndShiftDialog(shift: shift),
    );

    if (result != null) {
      final shiftProvider = context.read<ShiftProvider>();
      final success = await shiftProvider.endShift(
        shift.id,
        earnings: result['earnings'],
        completedRides: result['rides'],
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Turno finalizado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _deleteShift(Shift shift) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: const Text('¿Estás seguro de que quieres eliminar este turno?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final shiftProvider = context.read<ShiftProvider>();
      final success = await shiftProvider.deleteShift(shift.id);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Turno eliminado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _showShiftDetails(Shift shift) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: ShiftCard(
                    shift: shift,
                    showDetails: true,
                    onStart: shiftProvider.canStartShift(shift)
                        ? () => _startShift(shift)
                        : null,
                    onEdit: () => _editShift(shift),
                    onDelete: () => _deleteShift(shift),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _changeStatsMonth(int months) {
    setState(() {
      _selectedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month + months,
        1,
      );
    });

    final userProvider = context.read<UserProvider>();
    final shiftProvider = context.read<ShiftProvider>();
    if (userProvider.user?.uid != null) {
      shiftProvider.loadStats(userProvider.user!.uid, _selectedDate);
    }
  }

  void _createTemplate() {
    // TODO: Implementar creación de plantilla
  }

  void _editTemplate(ShiftTemplate template) {
    // TODO: Implementar edición de plantilla
  }

  void _deleteTemplate(ShiftTemplate template) {
    // TODO: Implementar eliminación de plantilla
  }

  void _createFromTemplate(ShiftTemplate template) {
    // TODO: Implementar creación de turnos desde plantilla
  }
}

/// Diálogo para finalizar turno
class _EndShiftDialog extends StatefulWidget {
  final Shift shift;

  const _EndShiftDialog({required this.shift});

  @override
  State<_EndShiftDialog> createState() => _EndShiftDialogState();
}

class _EndShiftDialogState extends State<_EndShiftDialog> {
  final _earningsController = TextEditingController();
  final _ridesController = TextEditingController();

  @override
  void dispose() {
    _earningsController.dispose();
    _ridesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Finalizar Turno'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _earningsController,
            decoration: const InputDecoration(
              labelText: 'Ganancias (\$)',
              prefixIcon: Icon(Icons.attach_money),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ridesController,
            decoration: const InputDecoration(
              labelText: 'Viajes completados',
              prefixIcon: Icon(Icons.directions_car),
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            final earnings = double.tryParse(_earningsController.text) ?? 0.0;
            final rides = int.tryParse(_ridesController.text) ?? 0;
            
            Navigator.of(context).pop({
              'earnings': earnings,
              'rides': rides,
            });
          },
          child: const Text('Finalizar'),
        ),
      ],
    );
  }
}