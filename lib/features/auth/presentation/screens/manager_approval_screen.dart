import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/features/portaria/domain/repositories/resident_repository.dart';
import 'package:condomeet/features/portaria/data/repositories/resident_repository_impl.dart';

class ManagerApprovalScreen extends StatefulWidget {
  const ManagerApprovalScreen({super.key});

  @override
  State<ManagerApprovalScreen> createState() => _ManagerApprovalScreenState();
}

class _ManagerApprovalScreenState extends State<ManagerApprovalScreen> {
  final ResidentRepository _repository = ResidentRepositoryImpl();
  List<Resident> _pendingResidents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    setState(() => _isLoading = true);
    final result = await _repository.getPendingResidents();
    if (mounted) {
      setState(() {
        if (result is Success<List<Resident>>) {
          _pendingResidents = result.data;
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _handleAction(Resident resident, bool approved) async {
    HapticFeedback.mediumImpact();
    
    // Optimistic UI update
    setState(() {
      _pendingResidents.removeWhere((r) => r.id == resident.id);
    });

    final result = approved 
      ? await _repository.approveResident(resident.id)
      : await _repository.rejectResident(resident.id);

    if (mounted && result is! Success) {
      // Revert if error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao processar ação. Tente novamente.')),
      );
      _loadPending();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approved ? '${resident.fullName} aprovado!' : 'Solicitação removida.'),
          backgroundColor: approved ? Colors.green : Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aprovações Pendentes'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _pendingResidents.isEmpty
              ? _buildEmptyState()
              : _buildApprovalList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified_user_outlined, size: 80, color: AppColors.border),
          const SizedBox(height: 16),
          Text('Tudo em dia!', style: AppTypography.h2),
          const SizedBox(height: 8),
          Text(
            'Nenhuma solicitação de acesso pendente.',
            style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.primaryDark, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Dica: Deslize para a DIREITA para aprovar e para a ESQUERDA para recusar.',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.primaryDark),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _pendingResidents.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final resident = _pendingResidents[index];
              return _buildSwipeableCard(resident);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSwipeableCard(Resident resident) {
    return Dismissible(
      key: Key(resident.id),
      direction: DismissDirection.horizontal,
      background: _buildActionBackground(Alignment.centerLeft, Colors.green, Icons.check),
      secondaryBackground: _buildActionBackground(Alignment.centerRight, Colors.red, Icons.close),
      onDismissed: (direction) {
        _handleAction(resident, direction == DismissDirection.startToEnd);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.border,
              child: const Icon(Icons.person, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(resident.fullName, style: AppTypography.h3),
                  Text(
                    'Unidade ${resident.unitNumber} • Bloco ${resident.block}',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.swap_horiz, color: AppColors.border, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBackground(Alignment alignment, Color color, IconData icon) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: Colors.white, size: 32),
    );
  }
}
