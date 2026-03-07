import 'package:condomeet/core/errors/result.dart';
import '../models/common_area.dart';

abstract class BookingRepository {
  /// Watches all bookable common areas for a condominium.
  Stream<List<CommonArea>> watchCommonAreas(String condominiumId);

  /// Watches availability for a specific area in a date range.
  Stream<List<AvailabilitySlot>> watchAvailability({
    required String condominiumId,
    required String areaId,
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Creates a new booking.
  Future<Result<void>> createBooking({
    required String residentId,
    required String condominiumId,
    required String areaId,
    required DateTime date,
  });

  /// Cancels an existing booking.
  Future<Result<void>> cancelBooking({required String bookingId, required String residentId});
}
