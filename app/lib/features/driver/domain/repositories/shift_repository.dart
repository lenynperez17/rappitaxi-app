import '../entities/shift.dart';

/// Repositorio abstracto para manejar turnos de conductores
abstract class ShiftRepository {
  /// Obtiene todos los turnos de un conductor
  Future<List<Shift>> getShiftsByDriverId(String driverId);
  
  /// Obtiene turnos de un conductor en un rango de fechas
  Future<List<Shift>> getShiftsByDateRange(
    String driverId, 
    DateTime startDate, 
    DateTime endDate,
  );
  
  /// Crea un nuevo turno
  Future<Shift> createShift(Shift shift);
  
  /// Actualiza un turno existente
  Future<void> updateShift(Shift shift);
  
  /// Elimina un turno
  Future<void> deleteShift(String shiftId);
  
  /// Inicia un turno (marca como activo)
  Future<void> startShift(String shiftId);
  
  /// Finaliza un turno (marca como completado)
  Future<void> endShift(String shiftId);
  
  /// Obtiene el turno activo actual del conductor
  Future<Shift?> getActiveShift(String driverId);
  
  /// Obtiene las plantillas de turno del conductor
  Future<List<ShiftTemplate>> getShiftTemplates(String driverId);
  
  /// Crea una plantilla de turno
  Future<ShiftTemplate> createShiftTemplate(ShiftTemplate template);
  
  /// Actualiza una plantilla de turno
  Future<void> updateShiftTemplate(ShiftTemplate template);
  
  /// Elimina una plantilla de turno
  Future<void> deleteShiftTemplate(String templateId);
  
  /// Crea turnos a partir de una plantilla para un período
  Future<List<Shift>> createShiftsFromTemplate(
    String templateId,
    DateTime startDate,
    DateTime endDate,
  );
  
  /// Obtiene estadísticas de turnos del conductor
  Future<ShiftStats> getShiftStats(String driverId, DateTime month);
}

/// Estadísticas de turnos
class ShiftStats {
  final int totalShifts;
  final int completedShifts;
  final int cancelledShifts;
  final int missedShifts;
  final double totalHours;
  final double totalEarnings;
  final double averageEarningsPerHour;
  final double attendanceRate;

  ShiftStats({
    required this.totalShifts,
    required this.completedShifts,
    required this.cancelledShifts,
    required this.missedShifts,
    required this.totalHours,
    required this.totalEarnings,
    required this.averageEarningsPerHour,
    required this.attendanceRate,
  });

  factory ShiftStats.fromJson(Map<String, dynamic> json) {
    return ShiftStats(
      totalShifts: json['totalShifts'] ?? 0,
      completedShifts: json['completedShifts'] ?? 0,
      cancelledShifts: json['cancelledShifts'] ?? 0,
      missedShifts: json['missedShifts'] ?? 0,
      totalHours: (json['totalHours'] ?? 0.0).toDouble(),
      totalEarnings: (json['totalEarnings'] ?? 0.0).toDouble(),
      averageEarningsPerHour: (json['averageEarningsPerHour'] ?? 0.0).toDouble(),
      attendanceRate: (json['attendanceRate'] ?? 0.0).toDouble(),
    );
  }
}