import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/core/services/powersync_service.dart';
import 'package:condomeet/features/community/domain/models/common_area.dart';
import 'package:condomeet/features/community/domain/repositories/booking_repository.dart';
import 'package:uuid/uuid.dart';

class BookingRepositoryImpl implements BookingRepository {
  final PowerSyncService _powerSyncService;

  BookingRepositoryImpl(this._powerSyncService);

  @override
  Stream<List<CommonArea>> watchCommonAreas(String condominiumId) {
    return _powerSyncService.db.watch(
      'SELECT * FROM areas_comuns WHERE condominio_id = ? ORDER BY nome ASC',
      parameters: [condominiumId],
    ).map((rows) => rows.map((row) => CommonArea.fromMap(row)).toList());
  }

  @override
  Stream<List<AvailabilitySlot>> watchAvailability({
    required String condominiumId,
    required String areaId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    // Watch bookings for the area in the range
    return _powerSyncService.db.watch(
      'SELECT * FROM reservas_areas WHERE condominio_id = ? AND area_id = ? AND booking_date >= ? AND booking_date <= ? AND status = ?',
      parameters: [
        condominiumId,
        areaId,
        startDate.toIso8601String().split('T')[0],
        endDate.toIso8601String().split('T')[0],
        'confirmed'
      ],
    ).map((rows) {
      final List<AvailabilitySlot> slots = [];
      final bookedDates = rows.map((r) => r['booking_date'] as String).toSet();

      for (int i = 0; i <= endDate.difference(startDate).inDays; i++) {
        final date = startDate.add(Duration(days: i));
        final dateStr = date.toIso8601String().split('T')[0];
        
        slots.add(AvailabilitySlot(
          date: date,
          isAvailable: !bookedDates.contains(dateStr),
        ));
      }
      return slots;
    });
  }

  @override
  Future<Result<void>> createBooking({
    required String residentId,
    required String condominiumId,
    required String areaId,
    required DateTime date,
  }) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final bookingDate = DateTime(date.year, date.month, date.day);

      if (bookingDate.isBefore(today)) {
        return const Failure('Não é possível realizar reservas para datas passadas.');
      }

      final dateStr = bookingDate.toIso8601String().split('T')[0];
      
      // 1. Check if already booked by anyone (Double check before insert)
      final existing = await _powerSyncService.db.getOptional(
        'SELECT id FROM reservas_areas WHERE condominio_id = ? AND area_id = ? AND booking_date = ? AND status = ?',
        [condominiumId, areaId, dateStr, 'confirmed'],
      );

      if (existing != null) {
        return const Failure('Esta data já está reservada por outro morador.');
      }

      // 2. Check if resident already has an active future booking for this area
      final residentFutureBooking = await _powerSyncService.db.getOptional(
        'SELECT id FROM reservas_areas WHERE resident_id = ? AND area_id = ? AND booking_date >= ? AND status = ?',
        [residentId, areaId, today.toIso8601String().split('T')[0], 'confirmed'],
      );

      if (residentFutureBooking != null) {
        return const Failure('Você já possui uma reserva ativa para este espaço.');
      }

      await _powerSyncService.db.execute(
        '''INSERT INTO reservas_areas 
           (id, condominio_id, area_id, resident_id, booking_date, status, created_at) 
           VALUES (?, ?, ?, ?, ?, ?, ?)''',
        [
          const Uuid().v4(),
          condominiumId,
          areaId,
          residentId,
          dateStr,
          'confirmed',
          now.toIso8601String(),
        ],
      );
      return const Success(null);
    } catch (e) {
      return Failure('Erro ao realizar reserva: $e');
    }
  }

  @override
  Future<Result<void>> cancelBooking({required String bookingId, required String residentId}) async {
    try {
      // Validate ownership
      final booking = await _powerSyncService.db.getOptional(
        'SELECT resident_id FROM reservas_areas WHERE id = ?',
        [bookingId],
      );

      if (booking == null) {
        return const Failure('Reserva não encontrada.');
      }

      if (booking['resident_id'] != residentId) {
        return const Failure('Você não tem permissão para cancelar esta reserva.');
      }

      await _powerSyncService.db.execute(
        'UPDATE reservas_areas SET status = ? WHERE id = ?',
        ['cancelled', bookingId],
      );
      return const Success(null);
    } catch (e) {
      return Failure('Erro ao cancelar reserva: $e');
    }
  }
}
