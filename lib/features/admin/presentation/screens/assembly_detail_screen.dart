import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/features/admin/presentation/bloc/assembly_bloc.dart';
import 'package:condomeet/features/admin/domain/models/assembly.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';

class AssemblyDetailScreen extends StatefulWidget {
  final String assemblyId;
  const AssemblyDetailScreen({super.key, required this.assemblyId});

  @override
  State<AssemblyDetailScreen> createState() => _AssemblyDetailScreenState();
}

class _AssemblyDetailScreenState extends State<AssemblyDetailScreen> {
  String? _selectedOptionId;

  @override
  void initState() {
    super.initState();
    context.read<AssemblyBloc>().add(WatchAssemblyDetailsRequested(widget.assemblyId));
  }

  @override
  Widget build(BuildContext context) {
    final residentId = context.read<AuthBloc>().state.userId ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Votação Online'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.textMain,
      ),
      body: BlocConsumer<AssemblyBloc, AssemblyState>(
        listener: (context, state) {
          if (state is AssemblySuccess) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
          }
          if (state is AssemblyError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
            );
          }
        },
        builder: (context, state) {
          if (state is AssemblyLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is AssemblyDetailsLoaded) {
            final userVote = state.votes.firstWhere(
              (v) => v.residentId == residentId,
              orElse: () => AssemblyVote(
                id: '',
                assemblyId: '',
                optionId: '',
                residentId: '',
                createdAt: DateTime.now(),
              ),
            );

            final bool hasVoted = userVote.id.isNotEmpty;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(hasVoted),
                  const SizedBox(height: 24),
                  const Text(
                    'Pautas para Votação',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  ...state.options.map((option) {
                    final voteCount = state.votes.where((v) => v.optionId == option.id).length;
                    final totalVotes = state.votes.length;
                    final percentage = totalVotes > 0 ? (voteCount / totalVotes) : 0.0;

                    return _buildOptionCard(
                      option,
                      hasVoted: hasVoted,
                      isSelected: _selectedOptionId == option.id || userVote.optionId == option.id,
                      percentage: percentage,
                      voteCount: voteCount,
                    );
                  }),
                  const SizedBox(height: 32),
                  if (!hasVoted)
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _selectedOptionId == null
                            ? null
                            : () => _castVote(context, residentId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Registrar Voto', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          }

          return const SizedBox();
        },
      ),
    );
  }

  Widget _buildHeader(bool hasVoted) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: hasVoted ? Colors.green.withOpacity(0.1) : AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hasVoted ? Colors.green : AppColors.primary, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasVoted ? Icons.check_circle : Icons.info_outline,
                color: hasVoted ? Colors.green : AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                hasVoted ? 'Seu voto foi registrado' : 'Votação disponível',
                style: TextStyle(
                  color: hasVoted ? Colors.green : AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasVoted
                ? 'Você já manifestou sua participação nesta assembleia. O resultado será publicado após o encerramento.'
                : 'Selecione uma das opções abaixo para registrar sua decisão. Lembre-se que o voto é único e intransferível.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(
    AssemblyOption option, {
    required bool hasVoted,
    required bool isSelected,
    required double percentage,
    required int voteCount,
  }) {
    return GestureDetector(
      onTap: hasVoted ? null : () => setState(() => _selectedOptionId = option.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (!hasVoted)
                  Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: isSelected ? AppColors.primary : Colors.grey,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    option.title,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (hasVoted)
                  Text(
                    '${(percentage * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
              ],
            ),
            if (hasVoted) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percentage,
                  backgroundColor: Colors.grey.withOpacity(0.1),
                  color: isSelected ? AppColors.primary : Colors.grey,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$voteCount votos',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _castVote(BuildContext context, String residentId) {
    if (_selectedOptionId != null) {
      context.read<AssemblyBloc>().add(CastVoteRequested(
            assemblyId: widget.assemblyId,
            optionId: _selectedOptionId!,
            residentId: residentId,
          ));
    }
  }
}
