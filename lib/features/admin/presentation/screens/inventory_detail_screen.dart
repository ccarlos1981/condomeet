import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/features/admin/presentation/bloc/inventory_bloc.dart';
import 'package:condomeet/features/admin/domain/models/inventory_item.dart';
import 'package:intl/intl.dart';

class InventoryDetailScreen extends StatefulWidget {
  final String itemId;
  const InventoryDetailScreen({super.key, required this.itemId});

  @override
  State<InventoryDetailScreen> createState() => _InventoryDetailScreenState();
}

class _InventoryDetailScreenState extends State<InventoryDetailScreen> {
  @override
  void initState() {
    super.initState();
    context.read<InventoryBloc>().add(WatchTransactionsRequested(widget.itemId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Histórico de Movimentação'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.textMain,
      ),
      body: BlocConsumer<InventoryBloc, InventoryState>(
        listener: (context, state) {
          if (state is InventorySuccess) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
          }
          if (state is InventoryError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
            );
          }
        },
        builder: (context, state) {
          if (state is InventoryLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is TransactionHistoryLoaded) {
            return Column(
              children: [
                _buildActionButtons(context),
                Expanded(
                  child: state.transactions.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: state.transactions.length,
                          itemBuilder: (context, index) {
                            final tx = state.transactions[index];
                            return _buildTransactionCard(tx);
                          },
                        ),
                ),
              ],
            );
          }

          return const SizedBox();
        },
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showMovementDialog(context, TransactionType.in_stock),
              icon: const Icon(Icons.add),
              label: const Text('Entrada'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showMovementDialog(context, TransactionType.out_permanent),
              icon: const Icon(Icons.remove),
              label: const Text('Saída'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'Nenhuma movimentação registrada',
        style: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildTransactionCard(InventoryTransaction tx) {
    final bool isPositive = tx.type == TransactionType.in_stock || tx.type == TransactionType.return_stock;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (isPositive ? Colors.green : AppColors.error).withValues(alpha: 0.1),
          child: Icon(
            isPositive ? Icons.arrow_downward : Icons.arrow_upward,
            color: isPositive ? Colors.green : AppColors.error,
          ),
        ),
        title: Text(
          isPositive ? 'Entrada em estoque' : 'Saída de estoque',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tx.notes != null) Text(tx.notes!),
            Text(
              DateFormat('dd/MM/yyyy HH:mm').format(tx.createdAt),
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
        trailing: Text(
          '${isPositive ? '+' : '-'}${tx.quantity}',
          style: TextStyle(
            color: isPositive ? Colors.green : AppColors.error,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  void _showMovementDialog(BuildContext context, TransactionType type) {
    final TextEditingController quantityController = TextEditingController();
    final TextEditingController notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(type == TransactionType.in_stock ? 'Registrar Entrada' : 'Registrar Saída'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantidade'),
            ),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'Observações (opcional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final quantity = int.tryParse(quantityController.text) ?? 0;
              if (quantity > 0) {
                this.context.read<InventoryBloc>().add(RecordTransactionRequested(
                      itemId: widget.itemId,
                      type: type,
                      quantity: quantity,
                      notes: notesController.text.isEmpty ? null : notesController.text,
                    ));
                Navigator.pop(context);
              }
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}
