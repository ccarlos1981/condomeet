part of 'inventory_bloc.dart';

abstract class InventoryEvent extends Equatable {
  const InventoryEvent();

  @override
  List<Object?> get props => [];
}

class WatchInventoryRequested extends InventoryEvent {
  final String condominiumId;
  const WatchInventoryRequested(this.condominiumId);

  @override
  List<Object?> get props => [condominiumId];
}

class WatchTransactionsRequested extends InventoryEvent {
  final String itemId;
  const WatchTransactionsRequested(this.itemId);

  @override
  List<Object?> get props => [itemId];
}

class AddItemRequested extends InventoryEvent {
  final InventoryItem item;
  const AddItemRequested(this.item);

  @override
  List<Object?> get props => [item];
}

class RecordTransactionRequested extends InventoryEvent {
  final String itemId;
  final String? residentId;
  final TransactionType type;
  final int quantity;
  final String? notes;

  const RecordTransactionRequested({
    required this.itemId,
    this.residentId,
    required this.type,
    required this.quantity,
    this.notes,
  });

  @override
  List<Object?> get props => [itemId, residentId, type, quantity, notes];
}

class UpdateItemRequested extends InventoryEvent {
  final InventoryItem item;
  const UpdateItemRequested(this.item);

  @override
  List<Object?> get props => [item];
}

class _UpdateInventoryItems extends InventoryEvent {
  final List<InventoryItem> items;
  const _UpdateInventoryItems(this.items);

  @override
  List<Object?> get props => [items];
}

class _UpdateTransactions extends InventoryEvent {
  final List<InventoryTransaction> transactions;
  const _UpdateTransactions(this.transactions);

  @override
  List<Object?> get props => [transactions];
}
