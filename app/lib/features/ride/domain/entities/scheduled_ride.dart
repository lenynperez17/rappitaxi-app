import 'package:freezed_annotation/freezed_annotation.dart';

part 'scheduled_ride.freezed.dart';
part 'scheduled_ride.g.dart';

/// Entidad para viajes programados estilo Didi
@freezed
class ScheduledRide with _$ScheduledRide {
  const factory ScheduledRide({
    required String id,
    required String passengerId,
    String? driverId,
    required Map<String, dynamic> pickupLocation,
    required Map<String, dynamic> dropoffLocation,
    required DateTime scheduledTime,
    required String vehicleType,
    required double estimatedFare,
    required ScheduledRideStatus status,
    String? paymentMethod,
    String? notes,
    String? cancelReason,
    DateTime? confirmedAt,
    DateTime? assignedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    required DateTime createdAt,
    @Default(false) bool isRecurring,
    RecurrencePattern? recurrencePattern,
    @Default(30) int reminderMinutesBefore,
    @Default(false) bool allowAutoAssign,
    @Default(60) int searchRadiusMinutes, // Buscar conductor X minutos antes
  }) = _ScheduledRide;

  factory ScheduledRide.fromJson(Map<String, dynamic> json) =>
      _$ScheduledRideFromJson(json);
}

enum ScheduledRideStatus {
  pending,
  confirmed,
  driverAssigned,
  inProgress,
  completed,
  cancelled,
  expired,
  failed
}

/// Patrón de recurrencia para viajes programados
@freezed
class RecurrencePattern with _$RecurrencePattern {
  const factory RecurrencePattern({
    required RecurrenceType type,
    required List<int> daysOfWeek, // 1=Lunes, 7=Domingo
    @Default(1) int interval, // Cada N días/semanas/meses
    DateTime? endDate,
    @Default(0) int maxOccurrences,
    @Default([]) List<DateTime> exceptions, // Fechas excluidas
  }) = _RecurrencePattern;

  factory RecurrencePattern.fromJson(Map<String, dynamic> json) =>
      _$RecurrencePatternFromJson(json);
      
  /// Factory constructors para facilitar el uso
  static RecurrencePattern get none => const RecurrencePattern(
    type: RecurrenceType.none, 
    daysOfWeek: []
  );
  
  static RecurrencePattern get daily => const RecurrencePattern(
    type: RecurrenceType.daily, 
    daysOfWeek: []
  );
  
  static RecurrencePattern get weekly => const RecurrencePattern(
    type: RecurrenceType.weekly, 
    daysOfWeek: []
  );
  
  static RecurrencePattern get monthly => const RecurrencePattern(
    type: RecurrenceType.monthly, 
    daysOfWeek: []
  );
  
  static RecurrencePattern get weekdays => const RecurrencePattern(
    type: RecurrenceType.weekdays, 
    daysOfWeek: [1, 2, 3, 4, 5] // Lunes a Viernes
  );
  
  static RecurrencePattern get custom => const RecurrencePattern(
    type: RecurrenceType.custom, 
    daysOfWeek: []
  );
  
  /// Lista de todos los patrones disponibles
  static List<RecurrencePattern> get values => [
    none, daily, weekly, monthly, weekdays, custom
  ];
}

enum RecurrenceType {
  none,
  daily,
  weekly,
  monthly,
  weekdays,
  custom
}

/// Configuración de viajes programados
@freezed
class ScheduledRideConfig with _$ScheduledRideConfig {
  const factory ScheduledRideConfig({
    @Default(true) bool enableScheduledRides,
    @Default(30) int minMinutesInAdvance, // Mínimo 30 minutos antes
    @Default(10080) int maxMinutesInAdvance, // Máximo 7 días antes (7*24*60)
    @Default(true) bool allowRecurring,
    @Default(5) int maxRecurringRides,
    @Default(true) bool sendReminders,
    @Default([30, 60]) List<int> reminderIntervals, // Minutos antes
    @Default(true) bool allowModification,
    @Default(60) int modificationDeadlineMinutes, // No modificar 1 hora antes
    @Default(true) bool allowCancellation,
    @Default(30) int cancellationDeadlineMinutes,
    @Default(0.1) double cancellationFeePercent, // 10% de penalización
    @Default(true) bool priorityMatching, // Prioridad para encontrar conductor
  }) = _ScheduledRideConfig;

  factory ScheduledRideConfig.fromJson(Map<String, dynamic> json) =>
      _$ScheduledRideConfigFromJson(json);
}