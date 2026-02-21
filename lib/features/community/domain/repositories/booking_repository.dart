import 'package:condomeet/core/errors/result.dart';
import '../models/common_area.dart';

abstract class BookingRepository {
  /// Fetches all bookable common areas.
  Future<Result<List<CommonArea>>> getCommonAreas();

  /// Fetches availability for a specific area in a date range.
  Future<Result<List<AvailabilitySlot>>> getAvailability({
    required String areaId,
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Creates a new booking.
  Future<Result<void>> createBooking({
    required String residentId,
    required String areaId,
    required DateTime date,
  });
}
