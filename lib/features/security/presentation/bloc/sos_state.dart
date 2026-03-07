import 'package:equatable/equatable.dart';
import '../../domain/repositories/sos_repository.dart';

abstract class SOSState extends Equatable {
  const SOSState();
  
  @override
  List<Object?> get props => [];
}

class SOSInitial extends SOSState {}

class SOSLoading extends SOSState {}

class SOSActive extends SOSState {
  final List<SOSAlert> alerts;

  const SOSActive(this.alerts);

  @override
  List<Object?> get props => [alerts];
}

class SOSSuccess extends SOSState {}

class SOSError extends SOSState {
  final String message;

  const SOSError(this.message);

  @override
  List<Object?> get props => [message];
}
