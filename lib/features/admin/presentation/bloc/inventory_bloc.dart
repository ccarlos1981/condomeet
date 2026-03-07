import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:condomeet/features/admin/domain/models/inventory_item.dart';
import 'package:condomeet/features/admin/domain/repositories/inventory_repository.dart';
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/core/utils/error_sanitizer.dart';

part 'inventory_event.dart';
part 'inventory_state.dart';

class InventoryBloc extends Bloc<InventoryEvent, InventoryState> {
  final InventoryRepository _inventoryRepository;
  StreamSubscription? _inventorySubscription;
  StreamSubscription? _transactionsSubscription;

  InventoryBloc({required InventoryRepository inventoryRepository})
      : _inventoryRepository = inventoryRepository,
        super(InventoryInitial()) {
    on<WatchInventoryRequested>(_onWatchInventoryRequested);
    on<WatchTransactionsRequested>(_onWatchTransactionsRequested);
    on<AddItemRequested>(_onAddItemRequested);
    on<RecordTransactionRequested>(_onRecordTransactionRequested);
    on<UpdateItemRequested>(_onUpdateItemRequested);
    on<_UpdateInventoryItems>(_onUpdateInventoryItems);
    on<_UpdateTransactions>(_onUpdateTransactions);
  }

  Future<void> _onWatchInventoryRequested(
    WatchInventoryRequested event,
    Emitter<InventoryState> emit,
  ) async {
    emit(InventoryLoading());
    await _inventorySubscription?.cancel();
    _inventorySubscription = _inventoryRepository
        .watchInventoryItems(event.condominiumId)
        .listen((items) => add(_UpdateInventoryItems(items)));
  }

  Future<void> _onWatchTransactionsRequested(
    WatchTransactionsRequested event,
    Emitter<InventoryState> emit,
  ) async {
    emit(InventoryLoading());
    await _transactionsSubscription?.cancel();
    _transactionsSubscription = _inventoryRepository
        .watchTransactions(event.itemId)
        .listen((transactions) => add(_UpdateTransactions(transactions)));
  }

  Future<void> _onAddItemRequested(
    AddItemRequested event,
    Emitter<InventoryState> emit,
  ) async {
    emit(InventoryLoading());
    final result = await _inventoryRepository.addItem(event.item);
    if (result is Success) {
      emit(const InventorySuccess('Item adicionado com sucesso!'));
    } else {
      emit(InventoryError(ErrorSanitizer.sanitize((result as Failure).message)));
    }
  }

  Future<void> _onRecordTransactionRequested(
    RecordTransactionRequested event,
    Emitter<InventoryState> emit,
  ) async {
    emit(InventoryLoading());
    final result = await _inventoryRepository.recordTransaction(
      itemId: event.itemId,
      residentId: event.residentId,
      type: event.type,
      quantity: event.quantity,
      notes: event.notes,
    );
    if (result is Success) {
      emit(const InventorySuccess('Movimentação registrada com sucesso!'));
    } else {
      emit(InventoryError(ErrorSanitizer.sanitize((result as Failure).message)));
    }
  }

  Future<void> _onUpdateItemRequested(
    UpdateItemRequested event,
    Emitter<InventoryState> emit,
  ) async {
    emit(InventoryLoading());
    final result = await _inventoryRepository.updateItem(event.item);
    if (result is Success) {
      emit(const InventorySuccess('Item atualizado com sucesso!'));
    } else {
      emit(InventoryError(ErrorSanitizer.sanitize((result as Failure).message)));
    }
  }

  void _onUpdateInventoryItems(
    _UpdateInventoryItems event,
    Emitter<InventoryState> emit,
  ) {
    emit(InventoryLoaded(event.items));
  }

  void _onUpdateTransactions(
    _UpdateTransactions event,
    Emitter<InventoryState> emit,
  ) {
    emit(TransactionHistoryLoaded(event.transactions));
  }

  @override
  Future<void> close() {
    _inventorySubscription?.cancel();
    _transactionsSubscription?.cancel();
    return super.close();
  }
}
