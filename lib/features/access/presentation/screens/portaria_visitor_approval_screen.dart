import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/features/access/presentation/bloc/invitation_bloc.dart';
import 'package:condomeet/features/access/presentation/bloc/invitation_event.dart';
import 'package:condomeet/features/access/presentation/bloc/invitation_state.dart';
import 'package:condomeet/features/access/domain/models/invitation.dart';

class PortariaVisitorApprovalScreen extends StatefulWidget {
  const PortariaVisitorApprovalScreen({super.key});

  @override
  State<PortariaVisitorApprovalScreen> createState() =>
      _PortariaVisitorApprovalScreenState();
}

class _PortariaVisitorApprovalScreenState
    extends State<PortariaVisitorApprovalScreen> {
  final _codeCtrl = TextEditingController();
  final _blocoCtrl = TextEditingController();
  final _aptoCtrl = TextEditingController();

  bool? _filterLiberado; // null = all, false = not released, true = released
  String? _dateFilter;

  @override
  void initState() {
    super.initState();
    _loadInvitations();
  }

  void _loadInvitations() {
    final authState = context.read<AuthBloc>().state;
    if (authState.condominiumId == null) return;
    context.read<InvitationBloc>().add(
          WatchCondominiumInvitationsRequested(
            condominiumId: authState.condominiumId!,
            liberado: _filterLiberado,
            codeFilter: _codeCtrl.text,
            blocoFilter: _blocoCtrl.text,
            aptoFilter: _aptoCtrl.text,
            dateFilter: _dateFilter,
          ),
        );
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _blocoCtrl.dispose();
    _aptoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<InvitationBloc, InvitationState>(
      listener: (context, state) {
        if (state is VisitorEntryApproved) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Visitante liberado com sucesso!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          // Force immediate refresh after approving
          _loadInvitations();
        } else if (state is InvitationError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Autorização prévia de visitante',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            _buildFilterBar(),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        children: [
          // Row 1: Código | Bloco | Apto | Data
          Row(
            children: [
              Expanded(child: _filterField('Código', _codeCtrl)),
              const SizedBox(width: 6),
              Expanded(child: _filterField('Bloco', _blocoCtrl)),
              const SizedBox(width: 6),
              Expanded(child: _filterField('Apto', _aptoCtrl)),
              const SizedBox(width: 6),
              Expanded(child: _buildDateFilter()),
            ],
          ),
          const SizedBox(height: 8),
          // Row 2: Toggle Liberado | Refresh | Filter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('Status: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  // 3-state toggle: null (all) → false (pendentes) → true (liberados)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_filterLiberado == null) {
                          _filterLiberado = false;
                        } else if (_filterLiberado == false) {
                          _filterLiberado = true;
                        } else {
                          _filterLiberado = null;
                        }
                      });
                      _loadInvitations();
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _filterLiberado == null
                            ? Colors.grey.shade100
                            : _filterLiberado == false
                                ? Colors.orange.shade100
                                : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _filterLiberado == null
                              ? Colors.grey.shade300
                              : _filterLiberado == false
                                  ? Colors.orange.shade300
                                  : Colors.green.shade300,
                        ),
                      ),
                      child: Text(
                        _filterLiberado == null
                            ? '● Todos'
                            : _filterLiberado == false
                                ? '⏳ Pendentes'
                                : '✓ Liberados',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _filterLiberado == null
                              ? Colors.grey.shade600
                              : _filterLiberado == false
                                  ? Colors.orange.shade700
                                  : Colors.green.shade700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  // Clear filters
                  if (_filterLiberado != null ||
                      _codeCtrl.text.isNotEmpty ||
                      _blocoCtrl.text.isNotEmpty ||
                      _aptoCtrl.text.isNotEmpty ||
                      _dateFilter != null)
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                      onPressed: _clearFilters,
                      tooltip: 'Limpar filtros',
                    ),
                  // Refresh
                  IconButton(
                    icon: Icon(Icons.refresh, color: AppColors.primary),
                    onPressed: _loadInvitations,
                    tooltip: 'Atualizar',
                  ),
                  // Search/Apply
                  IconButton(
                    icon: Icon(Icons.filter_alt, color: AppColors.primary),
                    onPressed: _loadInvitations,
                    tooltip: 'Filtrar',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterField(String hint, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      onSubmitted: (_) => _loadInvitations(),
      style: const TextStyle(fontSize: 12),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildDateFilter() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: ColorScheme.light(primary: AppColors.primary),
            ),
            child: child!,
          ),
        );
        if (picked != null) {
          setState(() {
            _dateFilter = DateFormat('yyyy-MM-dd').format(picked);
          });
          _loadInvitations();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _dateFilter != null ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
        child: Text(
          _dateFilter != null
              ? DateFormat('dd/MM').format(DateTime.parse(_dateFilter!))
              : 'Data',
          style: TextStyle(
            fontSize: 11,
            color: _dateFilter != null ? AppColors.primary : Colors.grey,
          ),
        ),
      ),
    );
  }

  void _clearFilters() {
    _codeCtrl.clear();
    _blocoCtrl.clear();
    _aptoCtrl.clear();
    setState(() {
      _filterLiberado = null;
      _dateFilter = null;
    });
    _loadInvitations();
  }

  Widget _buildList() {
    return BlocBuilder<InvitationBloc, InvitationState>(
      builder: (context, state) {
        if (state is InvitationLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final invitations = state is InvitationLoaded
            ? state.invitations
            : <Invitation>[];

        if (invitations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(
                  'Nenhuma autorização encontrada',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: invitations.length,
          itemBuilder: (context, index) {
            return _buildInvitationCard(invitations[index]);
          },
        );
      },
    );
  }

  Widget _buildInvitationCard(Invitation inv) {
    final isLiberado = inv.visitanteCompareceu;
    final code = inv.qrData.length >= 3 ? inv.qrData.substring(0, 3).toUpperCase() : inv.qrData.toUpperCase();
    final dateFormatted = DateFormat('dd/MM/yyyy').format(inv.validityDate);
    final createdFormatted = DateFormat('dd/MM/yyyy – HH:mm').format(inv.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isLiberado
            ? Border.all(color: Colors.green.shade200)
            : Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row (orange/green background)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isLiberado
                  ? Colors.green.shade50
                  : AppColors.primary.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Code badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isLiberado ? Colors.green : AppColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    code,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Unit + resident name stacked
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Bloco: ${inv.blocoTxt ?? '-'}  /  Apto: ${inv.aptoTxt ?? '-'}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Morador: ${inv.residentName ?? '-'}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Status chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: isLiberado ? Colors.green.shade100 : AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isLiberado ? '✓ Liberado' : 'Pendente',
                    style: TextStyle(
                      fontSize: 10,
                      color: isLiberado ? Colors.green.shade700 : AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Solicitado para a data: $dateFormatted',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Nome Visitante: ${inv.guestName.isEmpty ? 'Nome não preenchido' : inv.guestName}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      'Tipo de visitante: ${inv.visitorType ?? '-'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Toggle to release visitor
                Row(
                  children: [
                    const Text(
                      'Visitante compareceu',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 8),
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: isLiberado,
                        onChanged: isLiberado
                            ? null // Already approved — no changing back
                            : (val) {
                                if (val) _showConfirmDialog(inv);
                              },
                        activeThumbColor: AppColors.primary,
                      ),
                    ),
                    if (isLiberado)
                      Text(
                        'Liberado ✓',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Solicitação criada em: $createdFormatted',
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Solicitado por: ${inv.residentName ?? '-'}',
                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showConfirmDialog(Invitation inv) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.how_to_reg, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'Liberar entrada do visitante?',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dialogRow(Icons.person_outline, 'Visitante', inv.guestName.isEmpty ? 'Não informado' : inv.guestName),
            const SizedBox(height: 6),
            _dialogRow(Icons.category_outlined, 'Tipo', inv.visitorType ?? '-'),
            const SizedBox(height: 6),
            _dialogRow(Icons.home_outlined, 'Solicitado por', '${inv.residentName ?? '-'} — Bloco ${inv.blocoTxt ?? '-'} / Apto ${inv.aptoTxt ?? '-'}'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Esta ação não pode ser desfeita.',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final authState = context.read<AuthBloc>().state;
              context.read<InvitationBloc>().add(
                    ApproveVisitorEntryRequested(
                      invitationId: inv.id,
                      porterId: authState.userId ?? '',
                    ),
                  );
              Navigator.pop(dialogCtx);
            },
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('Confirmar Liberação'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dialogRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              children: [
                TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
