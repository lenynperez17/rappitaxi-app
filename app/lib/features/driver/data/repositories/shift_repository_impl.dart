import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/shift.dart';
import '../../domain/repositories/shift_repository.dart';
import '../../../../shared/utils/logger.dart';

/// Implementación del repositorio de turnos usando Firestore
class ShiftRepositoryImpl implements ShiftRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _shiftsCollection = 'shifts';
  static const String _templatesCollection = 'shift_templates';

  @override
  Future<List<Shift>> getShiftsByDriverId(String driverId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_shiftsCollection)
          .where('driverId', isEqualTo: driverId)
          .orderBy('startTime', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Shift.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      Logger.error('Error obteniendo turnos del conductor: $e');
      rethrow;
    }
  }

  @override
  Future<List<Shift>> getShiftsByDateRange(
    String driverId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection(_shiftsCollection)
          .where('driverId', isEqualTo: driverId)
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('startTime')
          .get();

      return querySnapshot.docs
          .map((doc) => Shift.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      Logger.error('Error obteniendo turnos por rango de fechas: $e');
      rethrow;
    }
  }

  @override
  Future<Shift> createShift(Shift shift) async {
    try {
      final docRef = await _firestore.collection(_shiftsCollection).add({
        ...shift.toJson()..remove('id'),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return shift.copyWith(
        id: docRef.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      Logger.error('Error creando turno: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateShift(Shift shift) async {
    try {
      await _firestore.collection(_shiftsCollection).doc(shift.id).update({
        ...shift.toJson()..remove('id'),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      Logger.error('Error actualizando turno: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteShift(String shiftId) async {
    try {
      await _firestore.collection(_shiftsCollection).doc(shiftId).delete();
    } catch (e) {
      Logger.error('Error eliminando turno: $e');
      rethrow;
    }
  }

  @override
  Future<void> startShift(String shiftId) async {
    try {
      await _firestore.collection(_shiftsCollection).doc(shiftId).update({
        'status': ShiftStatus.active.name,
        'actualStartTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      Logger.error('Error iniciando turno: $e');
      rethrow;
    }
  }

  @override
  Future<void> endShift(String shiftId) async {
    try {
      await _firestore.collection(_shiftsCollection).doc(shiftId).update({
        'status': ShiftStatus.completed.name,
        'actualEndTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      Logger.error('Error finalizando turno: $e');
      rethrow;
    }
  }

  @override
  Future<Shift?> getActiveShift(String driverId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_shiftsCollection)
          .where('driverId', isEqualTo: driverId)
          .where('status', isEqualTo: ShiftStatus.active.name)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) return null;

      final doc = querySnapshot.docs.first;
      return Shift.fromJson({...doc.data(), 'id': doc.id});
    } catch (e) {
      Logger.error('Error obteniendo turno activo: $e');
      rethrow;
    }
  }

  @override
  Future<List<ShiftTemplate>> getShiftTemplates(String driverId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_templatesCollection)
          .where('driverId', isEqualTo: driverId)
          .where('isActive', isEqualTo: true)
          .get();

      return querySnapshot.docs
          .map((doc) => ShiftTemplate.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      Logger.error('Error obteniendo plantillas de turnos: $e');
      rethrow;
    }
  }

  @override
  Future<ShiftTemplate> createShiftTemplate(ShiftTemplate template) async {
    try {
      final docRef = await _firestore.collection(_templatesCollection).add({
        ...template.toJson()..remove('id'),
        'createdAt': FieldValue.serverTimestamp(),
      });

      return template.copyWith(id: docRef.id, createdAt: DateTime.now());
    } catch (e) {
      Logger.error('Error creando plantilla de turno: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateShiftTemplate(ShiftTemplate template) async {
    try {
      await _firestore.collection(_templatesCollection).doc(template.id).update({
        ...template.toJson()..remove('id'),
      });
    } catch (e) {
      Logger.error('Error actualizando plantilla de turno: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteShiftTemplate(String templateId) async {
    try {
      await _firestore
          .collection(_templatesCollection)
          .doc(templateId)
          .update({'isActive': false});
    } catch (e) {
      Logger.error('Error eliminando plantilla de turno: $e');
      rethrow;
    }
  }

  @override
  Future<List<Shift>> createShiftsFromTemplate(
    String templateId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      // Obtener la plantilla
      final templateDoc = await _firestore
          .collection(_templatesCollection)
          .doc(templateId)
          .get();

      if (!templateDoc.exists) {
        throw Exception('Plantilla de turno no encontrada');
      }

      final template = ShiftTemplate.fromJson({
        ...templateDoc.data()!,
        'id': templateDoc.id,
      });

      // Crear turnos para el período especificado
      final shifts = <Shift>[];
      final currentDate = DateTime(startDate.year, startDate.month, startDate.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day);

      while (currentDate.isBefore(end) || currentDate.isAtSameMomentAs(end)) {
        final weekday = _getWeekdayName(currentDate.weekday);
        
        if (template.workDays.contains(weekday)) {
          // Parsear horas de inicio y fin
          final startTimeParts = template.startTime.split(':');
          final endTimeParts = template.endTime.split(':');
          
          final shiftStart = DateTime(
            currentDate.year,
            currentDate.month,
            currentDate.day,
            int.parse(startTimeParts[0]),
            int.parse(startTimeParts[1]),
          );
          
          var shiftEnd = DateTime(
            currentDate.year,
            currentDate.month,
            currentDate.day,
            int.parse(endTimeParts[0]),
            int.parse(endTimeParts[1]),
          );
          
          // Si la hora de fin es menor a la de inicio, es al día siguiente
          if (shiftEnd.isBefore(shiftStart)) {
            shiftEnd = shiftEnd.add(const Duration(days: 1));
          }

          final shift = Shift(
            id: '', // Se asignará al crear
            driverId: template.driverId,
            startTime: shiftStart,
            endTime: shiftEnd,
            status: ShiftStatus.scheduled,
            workDays: [weekday],
            notes: template.notes,
          );

          final createdShift = await createShift(shift);
          shifts.add(createdShift);
        }

        currentDate.add(const Duration(days: 1));
      }

      return shifts;
    } catch (e) {
      Logger.error('Error creando turnos desde plantilla: $e');
      rethrow;
    }
  }

  @override
  Future<ShiftStats> getShiftStats(String driverId, DateTime month) async {
    try {
      final startOfMonth = DateTime(month.year, month.month, 1);
      final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      final shifts = await getShiftsByDateRange(driverId, startOfMonth, endOfMonth);

      var totalShifts = shifts.length;
      var completedShifts = 0;
      var cancelledShifts = 0;
      var missedShifts = 0;
      var totalHours = 0.0;
      var totalEarnings = 0.0;

      for (final shift in shifts) {
        switch (shift.status) {
          case ShiftStatus.completed:
            completedShifts++;
            totalEarnings += shift.actualEarnings;
            if (shift.actualStartTime != null && shift.actualEndTime != null) {
              final duration = shift.actualEndTime!.difference(shift.actualStartTime!);
              totalHours += duration.inMinutes / 60.0;
            }
            break;
          case ShiftStatus.cancelled:
            cancelledShifts++;
            break;
          case ShiftStatus.missed:
            missedShifts++;
            break;
          default:
            break;
        }
      }

      final attendanceRate = totalShifts > 0 
          ? (completedShifts / totalShifts) * 100 
          : 0.0;
      final averageEarningsPerHour = totalHours > 0 
          ? totalEarnings / totalHours 
          : 0.0;

      return ShiftStats(
        totalShifts: totalShifts,
        completedShifts: completedShifts,
        cancelledShifts: cancelledShifts,
        missedShifts: missedShifts,
        totalHours: totalHours,
        totalEarnings: totalEarnings,
        averageEarningsPerHour: averageEarningsPerHour,
        attendanceRate: attendanceRate,
      );
    } catch (e) {
      Logger.error('Error obteniendo estadísticas de turnos: $e');
      rethrow;
    }
  }

  /// Convierte el número de día de la semana a nombre
  String _getWeekdayName(int weekday) {
    switch (weekday) {
      case 1: return 'monday';
      case 2: return 'tuesday';
      case 3: return 'wednesday';
      case 4: return 'thursday';
      case 5: return 'friday';
      case 6: return 'saturday';
      case 7: return 'sunday';
      default: return 'monday';
    }
  }
}