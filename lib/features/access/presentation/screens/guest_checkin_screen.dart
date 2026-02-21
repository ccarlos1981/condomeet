import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/features/access/domain/models/invitation.dart';
import 'package:condomeet/features/access/domain/repositories/invitation_repository.dart';
import 'package:condomeet/features/access/data/repositories/invitation_repository_impl.dart';

class GuestCheckinScreen extends StatefulWidget {
  const GuestCheckinScreen({super.key});

  @override
  State<GuestCheckinScreen> createState() => _GuestCheckinScreenState();
}

class _GuestCheckinScreenState extends State<GuestCheckinScreen> {
  final InvitationRepository _repository = InvitationRepositoryImpl();
  List<Invitation> _invitations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActiveInvitations();
  }

  Future<void> _loadActiveInvitations() async {
    setState(() => _isLoading = true);
    final result = await _repository.getActiveInvitations();
    if (mounted) {
      setState(() {
        if (result is Success<List<Invitation>>) {
          _invitations = result.data;
        }
        _isLoading = false;
      });
    }
  }

  void _handleCheckin(Invitation invitation) async {
    HapticFeedback.lightImpact();
    final result = await _repository.markAsUsed(invitation.id);
    
    if (mounted) {
      if (result is Success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Entrada de ${invitation.guestName} autorizada!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadActiveInvitations();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terminal de Visitantes'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: CondoInput(
              label: '',
              hint: 'Buscar convidado por nome...',
              prefix: const Icon(Icons.search, color: AppColors.textSecondary),
              onChanged: (value) {
                // TODO: Implement local filtering
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _invitations.isEmpty
                    ? _buildEmptyState()
                    : _buildInvitationList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: AppColors.border),
          const SizedBox(height: 16),
          Text('Nenhum convite ativo', style: AppTypography.h2),
          const SizedBox(height: 8),
          Text(
            'Convide residentes a gerarem convites digitais.',
            style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildInvitationList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _invitations.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final invitation = _invitations[index];
        return _buildInvitationTile(invitation);
      },
    );
  }

  Widget _buildInvitationTile(Invitation invitation) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.surface,
            child: const Icon(Icons.person, color: AppColors.textMain),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(invitation.guestName, style: AppTypography.h3),
                Text(
                  'Convidado por: Morador Unit 123', // Mock resident info
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          CondoButton(
            label: 'Autorizar',
            onPressed: () => _handleCheckin(invitation),
            isFullWidth: false,
          ),
        ],
      ),
    );
  }
}
