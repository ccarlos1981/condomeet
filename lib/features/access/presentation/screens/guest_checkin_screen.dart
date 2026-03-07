import 'package:condomeet/core/design_system/design_system.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/core/design_system/theme.dart';
import 'package:condomeet/core/design_system/condo_button.dart';
import 'package:condomeet/core/design_system/condo_input.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/features/access/domain/models/invitation.dart';
import '../bloc/invitation_bloc.dart';
import '../bloc/invitation_event.dart';
import '../bloc/invitation_state.dart';

class GuestCheckinScreen extends StatefulWidget {
  const GuestCheckinScreen({super.key});

  @override
  State<GuestCheckinScreen> createState() => _GuestCheckinScreenState();
}

class _GuestCheckinScreenState extends State<GuestCheckinScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState.condominiumId != null) {
      context.read<InvitationBloc>().add(WatchAllActiveInvitationsRequested(authState.condominiumId!));
    }
  }

  void _handleCheckin(Invitation invitation) {
    HapticFeedback.mediumImpact();
    context.read<InvitationBloc>().add(MarkInvitationAsUsedRequested(invitation.id));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Entrada de ${invitation.guestName} autorizada!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terminal de Visitantes'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: CondoInput(
              label: '',
              hint: 'Pesquisar convites hoje...',
              prefix: const Icon(Icons.search, color: AppColors.textSecondary),
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          Expanded(
            child: BlocBuilder<InvitationBloc, InvitationState>(
              builder: (context, state) {
                if (state is InvitationLoading) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                
                if (state is InvitationError) {
                  return Center(child: Text(state.message, style: const TextStyle(color: AppColors.error)));
                }

                if (state is InvitationLoaded) {
                  final filtered = state.invitations.where((i) => 
                    i.guestName.toLowerCase().contains(_searchQuery)
                  ).toList();

                  if (filtered.isEmpty) return _buildEmptyState();
                  return _buildInvitationList(filtered);
                }

                return _buildEmptyState();
              },
            ),
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
          const Icon(Icons.people_outline, size: 80, color: AppColors.border),
          const SizedBox(height: 16),
          const Text('Nenhum convite ativo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Aguardando novos convites digitais.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildInvitationList(List<Invitation> invitations) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: invitations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final invitation = invitations[index];
        return _buildInvitationTile(invitation);
      },
    );
  }

  Widget _buildInvitationTile(Invitation invitation) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.surface,
            child: Icon(Icons.person, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invitation.guestName, 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'Válido até: ${invitation.validityDate.day}/${invitation.validityDate.month}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
