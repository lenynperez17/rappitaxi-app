import 'package:flutter/material.dart';
import '../../domain/entities/shift.dart';
import '../../domain/repositories/shift_repository.dart';
import '../../data/repositories/shift_repository_impl.dart';
import '../../../../shared/utils/logger.dart';

/// Provider para manejar el estado de los turnos del conductor
class ShiftProvider extends ChangeNotifier {
  final ShiftRepository _shiftRepository = ShiftRepositoryImpl();

  List<Shift> _shifts = [];
  List<ShiftTemplate> _templates = [];
  Shift? _activeShift;
  ShiftStats? _stats;
  
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Shift> get shifts => _shifts;
  List<ShiftTemplate> get templates => _templates;
  Shift? get activeShift => _activeShift;
  ShiftStats? get stats => _stats;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasActiveShift => _activeShift != null;

  /// Carga los turnos del conductor
  Future<void> loadShifts(String driverId) async {
    _setLoading(true);
    try {
      _shifts = await _shiftRepository.getShiftsByDriverId(driverId);
      _activeShift = await _shiftRepository.getActiveShift(driverId);
      _clearError();
    } catch (e) {
      _setError('Error cargando turnos: $e');
      Logger.error('Error en loadShifts: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Carga turnos por rango de fechas
  Future<void> loadShiftsByDateRange(
    String driverId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    _setLoading(true);
    try {
      _shifts = await _shiftRepository.getShiftsByDateRange(
        driverId,
        startDate,
        endDate,
      );
      _clearError();
    } catch (e) {
      _setError('Error cargando turnos por fecha: $e');
      Logger.error('Error en loadShiftsByDateRange: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Carga las plantillas de turno
  Future<void> loadTemplates(String driverId) async {
    try {
      _templates = await _shiftRepository.getShiftTemplates(driverId);
      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Error cargando plantillas: $e');
      Logger.error('Error en loadTemplates: $e');
    }
  }

  /// Crea un nuevo turno
  Future<bool> createShift(Shift shift) async {
    _setLoading(true);
    try {
      final newShift = await _shiftRepository.createShift(shift);
      _shifts.insert(0, newShift);
      _clearError();
      return true;
    } catch (e) {
      _setError('Error creando turno: $e');
      Logger.error('Error en createShift: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Actualiza un turno existente
  Future<bool> updateShift(Shift shift) async {
    try {
      await _shiftRepository.updateShift(shift);
      
      final index = _shifts.indexWhere((s) => s.id == shift.id);
      if (index != -1) {
        _shifts[index] = shift;
      }
      
      if (_activeShift?.id == shift.id) {
        _activeShift = shift;
      }
      
      _clearError();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Error actualizando turno: $e');
      Logger.error('Error en updateShift: $e');
      return false;
    }
  }

  /// Elimina un turno
  Future<bool> deleteShift(String shiftId) async {
    try {
      await _shiftRepository.deleteShift(shiftId);
      _shifts.removeWhere((shift) => shift.id == shiftId);
      
      if (_activeShift?.id == shiftId) {
        _activeShift = null;
      }
      
      _clearError();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Error eliminando turno: $e');
      Logger.error('Error en deleteShift: $e');
      return false;
    }
  }

  /// Inicia un turno
  Future<bool> startShift(String shiftId) async {
    try {
      await _shiftRepository.startShift(shiftId);
      
      final shiftIndex = _shifts.indexWhere((s) => s.id == shiftId);
      if (shiftIndex != -1) {
        final updatedShift = _shifts[shiftIndex].copyWith(
          status: ShiftStatus.active,
          actualStartTime: DateTime.now(),
        );
        _shifts[shiftIndex] = updatedShift;
        _activeShift = updatedShift;
      }
      
      _clearError();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Error iniciando turno: $e');
      Logger.error('Error en startShift: $e');
      return false;
    }
  }

  /// Finaliza un turno
  Future<bool> endShift(String shiftId, {double? earnings, int? completedRides}) async {
    try {
      await _shiftRepository.endShift(shiftId);
      
      final shiftIndex = _shifts.indexWhere((s) => s.id == shiftId);
      if (shiftIndex != -1) {
        final updatedShift = _shifts[shiftIndex].copyWith(
          status: ShiftStatus.completed,
          actualEndTime: DateTime.now(),
          actualEarnings: earnings ?? _shifts[shiftIndex].actualEarnings,
          completedRides: completedRides ?? _shifts[shiftIndex].completedRides,
        );
        
        _shifts[shiftIndex] = updatedShift;
        await _shiftRepository.updateShift(updatedShift);
      }
      
      _activeShift = null;
      _clearError();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Error finalizando turno: $e');
      Logger.error('Error en endShift: $e');
      return false;
    }
  }

  /// Crea una plantilla de turno
  Future<bool> createTemplate(ShiftTemplate template) async {
    try {
      final newTemplate = await _shiftRepository.createShiftTemplate(template);
      _templates.add(newTemplate);
      _clearError();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Error creando plantilla: $e');
      Logger.error('Error en createTemplate: $e');
      return false;
    }
  }

  /// Actualiza una plantilla de turno
  Future<bool> updateTemplate(ShiftTemplate template) async {
    try {
      await _shiftRepository.updateShiftTemplate(template);
      
      final index = _templates.indexWhere((t) => t.id == template.id);
      if (index != -1) {
        _templates[index] = template;
      }
      
      _clearError();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Error actualizando plantilla: $e');
      Logger.error('Error en updateTemplate: $e');
      return false;
    }
  }

  /// Elimina una plantilla de turno
  Future<bool> deleteTemplate(String templateId) async {
    try {
      await _shiftRepository.deleteShiftTemplate(templateId);
      _templates.removeWhere((template) => template.id == templateId);
      _clearError();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Error eliminando plantilla: $e');
      Logger.error('Error en deleteTemplate: $e');
      return false;
    }
  }

  /// Crea turnos desde una plantilla
  Future<bool> createShiftsFromTemplate(
    String templateId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    _setLoading(true);
    try {
      final newShifts = await _shiftRepository.createShiftsFromTemplate(
        templateId,
        startDate,
        endDate,
      );
      
      _shifts.addAll(newShifts);
      _shifts.sort((a, b) => b.startTime.compareTo(a.startTime));
      
      _clearError();
      return true;
    } catch (e) {
      _setError('Error creando turnos desde plantilla: $e');
      Logger.error('Error en createShiftsFromTemplate: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Carga estadísticas del mes
  Future<void> loadStats(String driverId, DateTime month) async {
    try {
      _stats = await _shiftRepository.getShiftStats(driverId, month);
      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Error cargando estadísticas: $e');
      Logger.error('Error en loadStats: $e');
    }
  }

  /// Obtiene turnos del día actual
  List<Shift> getTodayShifts() {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _shifts.where((shift) {
      return shift.startTime.isAfter(startOfDay) && 
             shift.startTime.isBefore(endOfDay);
    }).toList();
  }

  /// Obtiene turnos de la semana actual
  List<Shift> getWeekShifts() {
    final today = DateTime.now();
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final startOfWeekDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    final endOfWeek = startOfWeekDay.add(const Duration(days: 7));

    return _shifts.where((shift) {
      return shift.startTime.isAfter(startOfWeekDay) && 
             shift.startTime.isBefore(endOfWeek);
    }).toList();
  }

  /// Verifica si el conductor puede iniciar un turno
  bool canStartShift(Shift shift) {
    if (_activeShift != null) return false;
    if (shift.status != ShiftStatus.scheduled) return false;
    
    final now = DateTime.now();
    final allowedStartTime = shift.startTime.subtract(const Duration(minutes: 15));
    final latestStartTime = shift.startTime.add(const Duration(minutes: 30));
    
    return now.isAfter(allowedStartTime) && now.isBefore(latestStartTime);
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}