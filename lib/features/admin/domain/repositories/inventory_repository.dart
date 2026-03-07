import 'package:condomeet/core/errors/result.dart';
import '../models/inventory_item.dart';

abstract class InventoryRepository {
  /// Watches all inventory items for a condominium.
  Stream<List<InventoryItem>> watchInventoryItems(String condominiumId);

  /// Watches transactions for a specific item.
  Stream<List<InventoryTransaction>> watchTransactions(String itemId);

  /// Adds a new inventory item.
  Future<Result<void>> addItem(InventoryItem item);

  /// Records a stock movement (in, out, return).
  Future<Result<void>> recordTransaction({
    required String itemId,
    String? residentId,
    required TransactionType type,
    required int quantity,
    String? notes,
  });

  /// Updates an existing item (e.g., changing min quantity).
  Future<Result<void>> updateItem(InventoryItem item);
}
