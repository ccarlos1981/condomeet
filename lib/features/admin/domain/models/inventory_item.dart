import 'package:equatable/equatable.dart';

enum TransactionType { in_stock, out_permanent, out_temporary, return_stock }

class InventoryItem extends Equatable {
  final String id;
  final String condominiumId;
  final String name;
  final String? description;
  final String? category;
  final int currentQuantity;
  final int? minQuantity;
  final bool isConsumable;

  const InventoryItem({
    required this.id,
    required this.condominiumId,
    required this.name,
    this.description,
    this.category,
    required this.currentQuantity,
    this.minQuantity,
    required this.isConsumable,
  });

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      id: map['id'],
      condominiumId: map['condominio_id'] ?? map['condominium_id'],
      name: map['nome'] ?? map['name'],
      description: map['descricao'] ?? map['description'],
      category: map['categoria'] ?? map['category'],
      currentQuantity: map['quantidade_atual'] ?? map['current_quantity'] ?? 0,
      minQuantity: map['quantidade_minima'] ?? map['min_quantity'],
      isConsumable: (map['eh_consumivel'] ?? map['is_consumable']) == 1 || (map['eh_consumivel'] ?? map['is_consumable']) == true,
    );
  }

  @override
  List<Object?> get props => [id, condominiumId, name, currentQuantity];
}

class InventoryTransaction extends Equatable {
  final String id;
  final String itemId;
  final String? residentId;
  final TransactionType type;
  final int quantity;
  final String? notes;
  final DateTime createdAt;

  const InventoryTransaction({
    required this.id,
    required this.itemId,
    this.residentId,
    required this.type,
    required this.quantity,
    this.notes,
    required this.createdAt,
  });

  factory InventoryTransaction.fromMap(Map<String, dynamic> map) {
    return InventoryTransaction(
      id: map['id'],
      itemId: map['item_id'],
      residentId: map['perfil_id'] ?? map['resident_id'],
      type: TransactionType.values.firstWhere(
        (e) => e.name == (map['tipo_transacao'] ?? map['transaction_type']),
        orElse: () => TransactionType.out_permanent,
      ),
      quantity: map['quantidade'] ?? map['quantity'] ?? 0,
      notes: map['notas'] ?? map['notes'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  @override
  List<Object?> get props => [id, itemId, type, quantity, createdAt];
}
