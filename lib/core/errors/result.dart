import 'package:equatable/equatable.dart';

/// A generic class for representing the result of an operation.
abstract class Result<T> extends Equatable {
  const Result();

  @override
  List<Object?> get props => [];
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);

  @override
  List<Object?> get props => [data];
}

class Failure<T> extends Result<T> {
  final String message;
  final Exception? exception;
  
  const Failure(this.message, {this.exception});

  @override
  List<Object?> get props => [message, exception];
}
