import 'package:freezed_annotation/freezed_annotation.dart';

part 'shift.freezed.dart';
part 'shift.g.dart';

/// Entidad que representa un turno de conductor
@freezed
class Shift with _$Shift {
  const factory Shift({
    required String id,
    required String driverId,
    required DateTime startTime,
    required DateTime endTime,
    required ShiftStatus status,
    required List<String> workDays, // ['monday', 'tuesday', etc.]
    String? notes,
    DateTime? actualStartTime,
    DateTime? actualEndTime,
    @Default(0.0) double estimatedEarnings,
    @Default(0.0) double actualEarnings,
    @Default(0) int completedRides,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _Shift;

  factory Shift.fromJson(Map<String, dynamic> json) => _$ShiftFromJson(json);
}

/// Estados posibles de un turno
enum ShiftStatus {
  @JsonValue('scheduled')
  scheduled, // Programado
  
  @JsonValue('active')
  active, // Activo
  
  @JsonValue('completed')
  completed, // Completado
  
  @JsonValue('cancelled')
  cancelled, // Cancelado
  
  @JsonValue('missed')
  missed, // No se presentó
}

/// Extensión para obtener texto legible del estado
extension ShiftStatusExtension on ShiftStatus {
  String get displayName {
    switch (this) {
      case ShiftStatus.scheduled:
        return 'Programado';
      case ShiftStatus.active:
        return 'Activo';
      case ShiftStatus.completed:
        return 'Completado';
      case ShiftStatus.cancelled:
        return 'Cancelado';
      case ShiftStatus.missed:
        return 'No se presentó';
    }
  }

  /// Color asociado al estado
  int get colorValue {
    switch (this) {
      case ShiftStatus.scheduled:
        return 0xFF2196F3; // Azul
      case ShiftStatus.active:
        return 0xFF4CAF50; // Verde
      case ShiftStatus.completed:
        return 0xFF9E9E9E; // Gris
      case ShiftStatus.cancelled:
        return 0xFFF44336; // Rojo
      case ShiftStatus.missed:
        return 0xFFFF9800; // Naranja
    }
  }
}

/// Template de turno recurrente
@freezed
class ShiftTemplate with _$ShiftTemplate {
  const factory ShiftTemplate({
    required String id,
    required String driverId,
    required String name,
    required String startTime, // "08:00"
    required String endTime, // "16:00"
    required List<String> workDays,
    @Default(true) bool isActive,
    String? notes,
    DateTime? createdAt,
  }) = _ShiftTemplate;

  factory ShiftTemplate.fromJson(Map<String, dynamic> json) => 
      _$ShiftTemplateFromJson(json);
}