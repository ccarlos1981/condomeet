import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/features/community/domain/models/common_area.dart';
import 'package:condomeet/features/community/domain/repositories/booking_repository.dart';

class BookingRepositoryImpl implements BookingRepository {
  final List<CommonArea> _mockAreas = [
    CommonArea(
      id: '1',
      name: 'Churrasqueira A',
      description: 'Espaço gourmet externo com churrasqueira e forno de pizza.',
      iconPath: 'grill',
      capacity: 15,
      rules: 'Uso das 09h às 22h. Limpeza inclusa na taxa.',
    ),
    CommonArea(
      id: '2',
      name: 'Salão de Festas',
      description: 'Salão climatizado com cozinha completa.',
      iconPath: 'party_room',
      capacity: 50,
      rules: 'Uso das 10h às 00h. Proibido som alto após as 22h.',
    ),
    CommonArea(
      id: '3',
      name: 'Quadra Poliesportiva',
      description: 'Quadra para futebol, basquete e vôlei.',
      iconPath: 'sports',
      capacity: 20,
      rules: 'Uso das 08h às 21h. Necessário calçado apropriado.',
    ),
  ];

  // In-memory storage for active bookings (AreaID -> List of booked dates)
  final Map<String, List<DateTime>> _activeBookings = {};

  @override
  Future<Result<List<CommonArea>>> getCommonAreas() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return Success(_mockAreas);
  }

  @override
  Future<Result<List<AvailabilitySlot>>> getAvailability({
    required String areaId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    
    final List<AvailabilitySlot> slots = [];
    final alreadyBooked = _activeBookings[areaId] ?? [];

    for (int i = 0; i <= endDate.difference(startDate).inDays; i++) {
        final date = startDate.add(Duration(days: i));
        
        // Simple mock logic: every 3rd day is taken + our active bookings
        final isMockBooked = i % 5 == 0 && i != 0;
        final isActuallyBooked = alreadyBooked.any((d) => 
          d.year == date.year && d.month == date.month && d.day == date.day
        );

        final isAvailable = !isMockBooked && !isActuallyBooked;

        slots.add(AvailabilitySlot(
            date: date,
            isAvailable: isAvailable,
            bookedByUnit: isAvailable ? null : (isActuallyBooked ? 'Sua Unidade' : 'Unidade 102-A'),
        ));
    }
    
    return Success(slots);
  }

  @override
  Future<Result<void>> createBooking({
    required String residentId,
    required String areaId,
    required DateTime date,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));

    // Validation: Cannot book in the past
    final today = DateTime.now();
    if (date.isBefore(DateTime(today.year, today.month, today.day))) {
      return const Failure('Não é possível reservar datas passadas.');
    }

    // Validation: Check if already booked
    final areaBookings = _activeBookings[areaId] ?? [];
    if (areaBookings.any((d) => d.year == date.year && d.month == date.month && d.day == date.day)) {
      return const Failure('Esta data já está reservada.');
    }

    // Persistence
    _activeBookings.putIfAbsent(areaId, () => []).add(date);
    
    return const Success(null);
  }
}

final bookingRepository = BookingRepositoryImpl();
