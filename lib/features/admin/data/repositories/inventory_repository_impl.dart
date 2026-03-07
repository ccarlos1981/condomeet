import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/core/services/powersync_service.dart';
import 'package:condomeet/features/admin/domain/models/inventory_item.dart';
import 'package:condomeet/features/admin/domain/repositories/inventory_repository.dart';
import 'package:uuid/uuid.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  final PowerSyncService _powerSyncService;

  InventoryRepositoryImpl(this._powerSyncService);

  @override
  Stream<List<InventoryItem>> watchInventoryItems(String condominiumId) {
    return _powerSyncService.db.watch(
      'SELECT * FROM itens_inventario WHERE condominio_id = ? ORDER BY nome ASC',
      parameters: [condominiumId],
    ).map((rows) => rows.map((row) => InventoryItem.fromMap(row)).toList());
  }

  @override
  Stream<List<InventoryTransaction>> watchTransactions(String itemId) {
    return _powerSyncService.db.watch(
      'SELECT * FROM transacoes_inventario WHERE item_id = ? ORDER BY created_at DESC',
      parameters: [itemId],
    ).map((rows) => rows.map((row) => InventoryTransaction.fromMap(row)).toList());
  }

  @override
  Future<Result<void>> addItem(InventoryItem item) async {
    try {
      await _powerSyncService.db.execute(
        '''INSERT INTO itens_inventario 
           (id, condominio_id, nome, descricao, categoria, quantidade_atual, quantidade_minima, eh_consumivel, created_at, updated_at) 
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          item.id,
          item.condominiumId,
          item.name,
          item.description,
          item.category,
          item.currentQuantity,
          item.minQuantity,
          item.isConsumable ? 1 : 0,
          DateTime.now().toIso8601String(),
          DateTime.now().toIso8601String(),
        ],
      );
      return const Success(null);
    } catch (e) {
      return Failure('Erro ao adicionar item: $e');
    }
  }

  @override
  Future<Result<void>> recordTransaction({
    required String itemId,
    String? residentId,
    required TransactionType type,
    required int quantity,
    String? notes,
  }) async {
    try {
      await _powerSyncService.db.writeTransaction((tx) async {
        // 1. Record transaction
        await tx.execute(
          '''INSERT INTO transacoes_inventario 
             (id, item_id, perfil_id, tipo_transacao, quantidade, notas, created_at) 
             VALUES (?, ?, ?, ?, ?, ?, ?)''',
          [
            const Uuid().v4(),
            itemId,
            residentId,
            type.name,
            quantity,
            notes,
            DateTime.now().toIso8601String(),
          ],
        );

        // 2. Update item quantity
        int adjustment = (type == TransactionType.in_stock || type == TransactionType.return_stock) 
            ? quantity 
            : -quantity;

        await tx.execute(
          'UPDATE itens_inventario SET quantidade_atual = quantidade_atual + ?, updated_at = ? WHERE id = ?',
          [adjustment, DateTime.now().toIso8601String(), itemId],
        );
      });
      return const Success(null);
    } catch (e) {
      return Failure('Erro ao registrar movimentação: $e');
    }
  }

  @override
  Future<Result<void>> updateItem(InventoryItem item) async {
    try {
      await _powerSyncService.db.execute(
        '''UPDATE itens_inventario SET 
           nome = ?, descricao = ?, categoria = ?, quantidade_minima = ?, eh_consumivel = ?, updated_at = ?
           WHERE id = ?''',
        [
          item.name,
          item.description,
          item.category,
          item.minQuantity,
          item.isConsumable ? 1 : 0,
          DateTime.now().toIso8601String(),
          item.id,
        ],
      );
      return const Success(null);
    } catch (e) {
      return Failure('Erro ao atualizar item: $e');
    }
  }
}
