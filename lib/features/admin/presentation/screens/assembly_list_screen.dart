import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/features/admin/presentation/bloc/assembly_bloc.dart';
import 'package:condomeet/features/admin/domain/models/assembly.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:intl/intl.dart';

class AssemblyListScreen extends StatefulWidget {
  const AssemblyListScreen({super.key});

  @override
  State<AssemblyListScreen> createState() => _AssemblyListScreenState();
}

class _AssemblyListScreenState extends State<AssemblyListScreen> {
  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState.condominiumId != null) {
      context.read<AssemblyBloc>().add(WatchAssembliesRequested(authState.condominiumId!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Assembleias', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.textMain,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateAssemblyDialog(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: BlocBuilder<AssemblyBloc, AssemblyState>(
        builder: (context, state) {
          if (state is AssemblyLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is AssembliesLoaded) {
            if (state.assemblies.isEmpty) {
              return _buildEmptyState();
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.assemblies.length,
              itemBuilder: (context, index) {
                final assembly = state.assemblies[index];
                return _buildAssemblyCard(context, assembly);
              },
            );
          }

          if (state is AssemblyError) {
            return Center(child: Text(state.message, style: const TextStyle(color: Colors.red)));
          }

          return const SizedBox();
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.how_to_vote_outlined, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'Nenhuma assembleia encontrada',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildAssemblyCard(BuildContext context, Assembly assembly) {
    final statusColor = _getStatusColor(assembly.status);
    final statusText = _getStatusText(assembly.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Row(
          children: [
            Expanded(
              child: Text(
                assembly.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                statusText,
                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            if (assembly.description != null)
              Text(
                assembly.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Até ${DateFormat('dd/MM/yyyy').format(assembly.endDate)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          Navigator.pushNamed(context, '/assembly-detail', arguments: assembly.id);
        },
      ),
    );
  }

  Color _getStatusColor(AssemblyStatus status) {
    switch (status) {
      case AssemblyStatus.active:
        return Colors.green;
      case AssemblyStatus.closed:
        return Colors.red;
      case AssemblyStatus.draft:
        return Colors.orange;
    }
  }

  String _getStatusText(AssemblyStatus status) {
    switch (status) {
      case AssemblyStatus.active:
        return 'ATIVA';
      case AssemblyStatus.closed:
        return 'ENCERRADA';
      case AssemblyStatus.draft:
        return 'RASCUNHO';
    }
  }

  void _showCreateAssemblyDialog(BuildContext context) {
    // TODO: Implement Create Assembly Flow
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fluxo de criação em desenvolvimento.')),
    );
  }
}
