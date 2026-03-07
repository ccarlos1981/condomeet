import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/features/community/domain/repositories/booking_repository.dart';
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/features/community/domain/models/common_area.dart';
import 'booking_bloc_components.dart';
import 'package:condomeet/core/utils/error_sanitizer.dart';

class BookingBloc extends Bloc<BookingEvent, BookingState> {
  final BookingRepository _bookingRepository;
  StreamSubscription? _areasSubscription;
  StreamSubscription? _availabilitySubscription;

  BookingBloc({required BookingRepository bookingRepository})
      : _bookingRepository = bookingRepository,
        super(BookingInitial()) {
    on<WatchCommonAreasRequested>(_onWatchCommonAreasRequested);
    on<WatchAvailabilityRequested>(_onWatchAvailabilityRequested);
    on<CreateBookingRequested>(_onCreateBookingRequested);
    on<CancelBookingRequested>(_onCancelBookingRequested);
    on<_UpdateCommonAreas>(_onUpdateCommonAreas);
    on<_UpdateAvailability>(_onUpdateAvailability);
  }

  Future<void> _onWatchCommonAreasRequested(
    WatchCommonAreasRequested event,
    Emitter<BookingState> emit,
  ) async {
    emit(BookingLoading());
    await _areasSubscription?.cancel();
    _areasSubscription = _bookingRepository
        .watchCommonAreas(event.condominiumId)
        .listen((areas) => add(_UpdateCommonAreas(areas)));
  }

  Future<void> _onWatchAvailabilityRequested(
    WatchAvailabilityRequested event,
    Emitter<BookingState> emit,
  ) async {
    emit(BookingLoading());
    await _availabilitySubscription?.cancel();
    _availabilitySubscription = _bookingRepository
        .watchAvailability(
          condominiumId: event.condominiumId,
          areaId: event.areaId,
          startDate: event.startDate,
          endDate: event.endDate,
        )
        .listen((availability) => add(_UpdateAvailability(availability)));
  }

  Future<void> _onCreateBookingRequested(
    CreateBookingRequested event,
    Emitter<BookingState> emit,
  ) async {
    emit(BookingLoading());
    final result = await _bookingRepository.createBooking(
      residentId: event.residentId,
      condominiumId: event.condominiumId,
      areaId: event.areaId,
      date: event.date,
    );

    if (result is Success) {
      emit(const BookingSuccess('Reserva realizada com sucesso!'));
    } else {
      emit(BookingError(ErrorSanitizer.sanitize((result as Failure).message)));
    }
  }

  Future<void> _onCancelBookingRequested(
    CancelBookingRequested event,
    Emitter<BookingState> emit,
  ) async {
    emit(BookingLoading());
    final result = await _bookingRepository.cancelBooking(
      bookingId: event.bookingId,
      residentId: event.residentId,
    );

    if (result is Success) {
      emit(const BookingSuccess('Reserva cancelada com sucesso!'));
    } else {
      emit(BookingError(ErrorSanitizer.sanitize((result as Failure).message)));
    }
  }

  void _onUpdateCommonAreas(
    _UpdateCommonAreas event,
    Emitter<BookingState> emit,
  ) {
    emit(BookingAreasLoaded(event.areas));
  }

  void _onUpdateAvailability(
    _UpdateAvailability event,
    Emitter<BookingState> emit,
  ) {
    emit(BookingAvailabilityLoaded(event.availability));
  }

  @override
  Future<void> close() {
    _areasSubscription?.cancel();
    _availabilitySubscription?.cancel();
    return super.close();
  }
}

class _UpdateCommonAreas extends BookingEvent {
  final List<CommonArea> areas;
  const _UpdateCommonAreas(this.areas);
}

class _UpdateAvailability extends BookingEvent {
  final List<AvailabilitySlot> availability;
  const _UpdateAvailability(this.availability);
}
