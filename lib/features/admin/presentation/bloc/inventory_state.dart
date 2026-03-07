part of 'inventory_bloc.dart';

abstract class InventoryState extends Equatable {
  const InventoryState();
  
  @override
  List<Object?> get props => [];
}

class InventoryInitial extends InventoryState {}

class InventoryLoading extends InventoryState {}

class InventoryLoaded extends InventoryState {
  final List<InventoryItem> items;
  const InventoryLoaded(this.items);

  @override
  List<Object?> get props => [items];
}

class TransactionHistoryLoaded extends InventoryState {
  final List<InventoryTransaction> transactions;
  const TransactionHistoryLoaded(this.transactions);

  @override
  List<Object?> get props => [transactions];
}

class InventorySuccess extends InventoryState {
  final String message;
  const InventorySuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class InventoryError extends InventoryState {
  final String message;
  const InventoryError(this.message);

  @override
  List<Object?> get props => [message];
}
