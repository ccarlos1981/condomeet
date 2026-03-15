import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import '../bloc/structure_bloc.dart';
import '../bloc/structure_event.dart';
import '../bloc/structure_state.dart';

class BlockDetailScreen extends StatefulWidget {
  final String blocoId;
  final String blocoNome;

  const BlockDetailScreen({
    super.key,
    required this.blocoId,
    required this.blocoNome,
  });

  @override
  State<BlockDetailScreen> createState() => _BlockDetailScreenState();
}

class _BlockDetailScreenState extends State<BlockDetailScreen> {
  @override
  void initState() {
    super.initState();
    final condoId = context.read<AuthBloc>().state.condominiumId;
    if (condoId != null) {
      context.read<StructureBloc>().add(WatchUnidadesStarted(
        condominiumId: condoId,
        blocoId: widget.blocoId,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(widget.blocoNome, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocBuilder<StructureBloc, StructureState>(
        builder: (context, state) {
          if (state.status == StructureStatus.loading && state.unidades.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.unidades.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.door_front_door_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Nenhuma unidade cadastrada neste bloco.', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showAddUnidadeDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar Unidade'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            itemCount: state.unidades.length,
            itemBuilder: (context, index) {
              final unidade = state.unidades[index];
              return _buildUnitCard(context, unidade);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddUnidadeDialog(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildUnitCard(BuildContext context, dynamic unidade) {
    return GestureDetector(
      onLongPress: () => _showDeleteUnidadeDialog(context, unidade.id, unidade.aptoNumero ?? '...'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.home_outlined, color: AppColors.primary, size: 24),
            const SizedBox(height: 4),
            Text(
              unidade.aptoNumero ?? '...',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddUnidadeDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adicionar Apartamento'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Ex: 101, 102, 21...',
            labelText: 'Número do Apartamento',
          ),
          keyboardType: TextInputType.text,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                final condoId = context.read<AuthBloc>().state.condominiumId;
                if (condoId != null) {
                  context.read<StructureBloc>().add(UnidadeAdded(
                    condominiumId: condoId,
                    blocoId: widget.blocoId,
                    aptoNumero: controller.text.trim(),
                  ));
                }
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  void _showDeleteUnidadeDialog(BuildContext context, String id, String numero) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Unidade'),
        content: Text('Deseja excluir o apartamento $numero?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              context.read<StructureBloc>().add(UnidadeDeleted(id));
              Navigator.pop(context);
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
