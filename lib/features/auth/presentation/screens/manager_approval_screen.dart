import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:condomeet/core/utils/structure_helper.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/core/design_system/theme.dart';
import 'package:condomeet/core/services/powersync_service.dart';
import 'package:condomeet/features/portaria/domain/repositories/resident_repository.dart';
import 'package:condomeet/features/portaria/data/repositories/resident_repository_impl.dart';
import 'package:condomeet/core/di/injection_container.dart';

class ManagerApprovalScreen extends StatefulWidget {
  const ManagerApprovalScreen({super.key});

  @override
  State<ManagerApprovalScreen> createState() => _ManagerApprovalScreenState();
}

class _ManagerApprovalScreenState extends State<ManagerApprovalScreen> {
  List<Resident> _pendingResidents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    setState(() => _isLoading = true);
    final condominiumId = context.read<AuthBloc>().state.condominiumId;
    if (condominiumId == null) {
      setState(() => _isLoading = false);
      return;
    }
    final repository = sl<ResidentRepository>();
    final result = await repository.getPendingResidents(condominiumId);
    if (mounted) {
      if (result.isSuccess) {
        setState(() {
          _pendingResidents = result.successData;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.failureMessage), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _handleAction(Resident resident, bool approved) async {
    HapticFeedback.mediumImpact();
    
    final originalList = List<Resident>.from(_pendingResidents);
    setState(() {
      _pendingResidents.removeWhere((r) => r.id == resident.id);
    });

    final repository = sl<ResidentRepository>();
    final result = approved 
      ? await repository.approveResident(resident.id)
      : await repository.rejectResident(resident.id);

    if (mounted) {
      if (!result.isSuccess) {
        setState(() => _pendingResidents = originalList);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.failureMessage), backgroundColor: AppColors.error),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approved ? '${resident.fullName} aprovado!' : 'Solicitação removida.'),
            backgroundColor: approved ? Colors.green : AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aprovações Pendentes'),
        centerTitle: true,
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
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_user_rounded, size: 80, color: Colors.green),
          ),
          const SizedBox(height: 24),
          const Text(
            'Tudo em dia!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textMain),
          ),
          const SizedBox(height: 8),
          const Text(
            'Nenhuma solicitação de acesso pendente.',
            style: TextStyle(color: AppColors.textSecondary),
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.swipe_outlined, color: AppColors.primary, size: 24),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Deslize para a DIREITA para aprovar e para a ESQUERDA para recusar.',
                    style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      background: _buildActionBackground(Alignment.centerLeft, Colors.green, Icons.check_circle_outline),
      secondaryBackground: _buildActionBackground(Alignment.centerRight, AppColors.error, Icons.cancel_outlined),
      onDismissed: (direction) {
        _handleAction(resident, direction == DismissDirection.startToEnd);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.surface,
              child: Icon(Icons.person_outline, color: AppColors.primary, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resident.fullName, 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textMain),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          StructureHelper.getFullUnitName(context.read<AuthBloc>().state.tipoEstrutura, resident.block ?? '?', resident.unitNumber ?? '?'),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.border),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBackground(Alignment alignment, Color color, IconData icon) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(icon, color: Colors.white, size: 40),
    );
  }
}
