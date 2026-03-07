import 'package:equatable/equatable.dart';

/// A generic class for representing the result of an operation.
abstract class Result<T> extends Equatable {
  const Result();

  /// Folds the result into a single value of type [R].
  R fold<R>(R Function(Failure<T> failure) onFailure, R Function(T data) onSuccess);

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;
  T get successData => (this as Success<T>).data;
  String get failureMessage => (this as Failure<T>).message;
  Failure<T>? get failure => isFailure ? this as Failure<T> : null;

  @override
  List<Object?> get props => [];
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);

  @override
  R fold<R>(R Function(Failure<T> failure) onFailure, R Function(T data) onSuccess) => onSuccess(data);

  @override
  List<Object?> get props => [data];
}

class Failure<T> extends Result<T> {
  final String message;
  final Exception? exception;
  
  const Failure(this.message, {this.exception});

  @override
  R fold<R>(R Function(Failure<T> failure) onFailure, R Function(T data) onSuccess) => onFailure(this);

  @override
  List<Object?> get props => [message, exception];
}
