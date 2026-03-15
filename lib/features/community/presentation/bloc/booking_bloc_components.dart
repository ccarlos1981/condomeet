import 'package:equatable/equatable.dart';
import 'package:condomeet/features/community/domain/models/common_area.dart';

abstract class BookingState extends Equatable {
  const BookingState();
  
  @override
  List<Object?> get props => [];
}

class BookingInitial extends BookingState {}

class BookingLoading extends BookingState {}

class BookingAreasLoaded extends BookingState {
  final List<CommonArea> areas;
  const BookingAreasLoaded(this.areas);

  @override
  List<Object?> get props => [areas];
}

class BookingAvailabilityLoaded extends BookingState {
  final List<AvailabilitySlot> availability;
  const BookingAvailabilityLoaded(this.availability);

  @override
  List<Object?> get props => [availability];
}

class BookingSuccess extends BookingState {
  final String message;
  const BookingSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class BookingError extends BookingState {
  final String message;
  const BookingError(this.message);

  @override
  List<Object?> get props => [message];
}

abstract class BookingEvent extends Equatable {
  const BookingEvent();

  @override
  List<Object?> get props => [];
}

class WatchCommonAreasRequested extends BookingEvent {
  final String condominiumId;
  const WatchCommonAreasRequested(this.condominiumId);

  @override
  List<Object?> get props => [condominiumId];
}

class WatchAvailabilityRequested extends BookingEvent {
  final String condominiumId;
  final String areaId;
  final DateTime startDate;
  final DateTime endDate;

  const WatchAvailabilityRequested({
    required this.condominiumId,
    required this.areaId,
    required this.startDate,
    required this.endDate,
  });

  @override
  List<Object?> get props => [condominiumId, areaId, startDate, endDate];
}

class CreateBookingRequested extends BookingEvent {
  final String residentId;
  final String condominiumId;
  final String areaId;
  final DateTime date;

  const CreateBookingRequested({
    required this.residentId,
    required this.condominiumId,
    required this.areaId,
    required this.date,
  });

  @override
  List<Object?> get props => [residentId, condominiumId, areaId, date];
}

class CancelBookingRequested extends BookingEvent {
  final String bookingId;
  final String residentId;
  const CancelBookingRequested({required this.bookingId, required this.residentId});

  @override
  List<Object?> get props => [bookingId, residentId];
}

// ignore: unused_element
class _UpdateCommonAreas extends BookingEvent {
  final List<CommonArea> areas;
  const _UpdateCommonAreas(this.areas);

  @override
  List<Object?> get props => [areas];
}

// ignore: unused_element
class _UpdateAvailability extends BookingEvent {
  final List<AvailabilitySlot> availability;
  const _UpdateAvailability(this.availability);

  @override
  List<Object?> get props => [availability];
}
