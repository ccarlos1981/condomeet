import 'package:condomeet/core/design_system/design_system.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  String? _selectedTypeFilter;
  String _blocoFilter = '';
  String _aptoFilter = '';
  bool _showingAll = false;

  static const int _defaultLimit = 5;

  @override
  void initState() {
    super.initState();
    _loadInvitations(limit: _defaultLimit);
  }

  void _loadInvitations({int? limit}) {
    final authState = context.read<AuthBloc>().state;
    if (authState.condominiumId != null) {
      context.read<InvitationBloc>().add(
        WatchCondominiumInvitationsRequested(
          condominiumId: authState.condominiumId!,
          liberado: false,
          limit: limit,
        ),
      );
    }
  }

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _selectedTypeFilter != null ||
      _blocoFilter.isNotEmpty ||
      _aptoFilter.isNotEmpty;

  void _onFilterChanged() {
    if (_hasActiveFilters && !_showingAll) {
      // When filtering, load all to search the full database
      setState(() => _showingAll = true);
      _loadInvitations(limit: null);
    } else if (!_hasActiveFilters && _showingAll) {
      // When filters cleared, go back to limited view
      setState(() => _showingAll = false);
      _loadInvitations(limit: _defaultLimit);
    }
  }

  void _handleShowAll() {
    setState(() => _showingAll = true);
    _loadInvitations(limit: null);
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: CondoInput(
              label: '',
              hint: 'Pesquisar por nome ou código...',
              prefix: const Icon(Icons.search, color: AppColors.textSecondary),
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase());
                _onFilterChanged();
              },
            ),
          ),
          // Bloco + Apto filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Bloco',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        prefixIcon: Icon(Icons.apartment, size: 18, color: Colors.grey.shade400),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      style: const TextStyle(fontSize: 13),
                      onChanged: (v) {
                        setState(() => _blocoFilter = v.toLowerCase());
                        _onFilterChanged();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Apto',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        prefixIcon: Icon(Icons.door_front_door, size: 18, color: Colors.grey.shade400),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      style: const TextStyle(fontSize: 13),
                      onChanged: (v) {
                        setState(() => _aptoFilter = v.toLowerCase());
                        _onFilterChanged();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('Todos', null),
                _buildFilterChip('Visitante', 'Visitante'),
                _buildFilterChip('Uber', 'Uber'),
                _buildFilterChip('Serviços', 'Serviços'),
                _buildFilterChip('Diarista', 'Diarista'),
                _buildFilterChip('Hóspede', 'Hóspede'),
                _buildFilterChip('Outros', 'Outros'),
              ],
            ),
          ),
          const SizedBox(height: 8),
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
                  var filtered = state.invitations.where((i) {
                    final matchesSearch = _searchQuery.isEmpty ||
                        i.guestName.toLowerCase().contains(_searchQuery) ||
                        (i.residentName ?? '').toLowerCase().contains(_searchQuery) ||
                        i.qrData.toLowerCase().contains(_searchQuery);
                    final matchesType = _selectedTypeFilter == null ||
                        i.visitorType == _selectedTypeFilter;
                    final matchesBloco = _blocoFilter.isEmpty ||
                        (i.blocoTxt ?? '').toLowerCase().contains(_blocoFilter);
                    final matchesApto = _aptoFilter.isEmpty ||
                        (i.aptoTxt ?? '').toLowerCase().contains(_aptoFilter);
                    return matchesSearch && matchesType && matchesBloco && matchesApto;
                  }).toList();

                  if (filtered.isEmpty) return _buildEmptyState();
                  return _buildInvitationList(
                    filtered,
                    showLoadMore: !_showingAll && !_hasActiveFilters,
                  );
                }

                return _buildEmptyState();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? type) {
    final isSelected = _selectedTypeFilter == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: TextStyle(
          fontSize: 12,
          color: isSelected ? Colors.white : AppColors.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        )),
        selected: isSelected,
        onSelected: (_) {
          setState(() => _selectedTypeFilter = type);
          _onFilterChanged();
        },
        backgroundColor: Colors.grey.shade100,
        selectedColor: AppColors.primary,
        checkmarkColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

  Widget _buildInvitationList(List<Invitation> invitations, {bool showLoadMore = false}) {
    final itemCount = invitations.length + (showLoadMore ? 1 : 0);
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (showLoadMore && index == invitations.length) {
          return Center(
            child: TextButton.icon(
              onPressed: _handleShowAll,
              icon: const Icon(Icons.expand_more, size: 18),
              label: const Text('Ver mais autorizações'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
          );
        }
        final invitation = invitations[index];
        return _buildInvitationTile(invitation);
      },
    );
  }

  Widget _buildInvitationTile(Invitation invitation) {
    final unit = [
      if (invitation.blocoTxt != null && invitation.blocoTxt!.isNotEmpty) 'Bl. ${invitation.blocoTxt}',
      if (invitation.aptoTxt != null && invitation.aptoTxt!.isNotEmpty) 'Ap. ${invitation.aptoTxt}',
    ].join(' / ');

    final tipoLabel = invitation.visitorType ?? '';
    final validDay = '${invitation.validityDate.day}/${invitation.validityDate.month}';
    final shortCode = invitation.qrData.length > 3
        ? invitation.qrData.substring(invitation.qrData.length - 3).toUpperCase()
        : invitation.qrData.toUpperCase();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invitation.guestName, 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${invitation.residentName ?? ''}${unit.isNotEmpty ? ' · $unit' : ''}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (tipoLabel.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(tipoLabel, style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ),
                    Text('Válido até $validDay', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('🔑$shortCode', style: TextStyle(fontSize: 10, color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            height: 36,
            child: ElevatedButton.icon(
              onPressed: () => _handleCheckin(invitation),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Liberar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
