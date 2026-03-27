import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/features/access/presentation/bloc/invitation_bloc.dart';
import 'package:condomeet/features/access/presentation/bloc/invitation_event.dart';
import 'package:condomeet/features/access/presentation/bloc/invitation_state.dart';
import 'package:condomeet/features/access/domain/models/invitation.dart';
import 'package:condomeet/shared/utils/structure_labels.dart';

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

  bool? _filterLiberado = false; // false = pendentes (default), null = all, true = released
  String? _dateFilter;
  int _displayLimit = 5;

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
            limit: _displayLimit,
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
              Expanded(child: _filterField(getBlocoLabel(context.read<AuthBloc>().state.tipoEstrutura), _blocoCtrl)),
              const SizedBox(width: 6),
              Expanded(child: _filterField(getAptoLabel(context.read<AuthBloc>().state.tipoEstrutura), _aptoCtrl)),
              const SizedBox(width: 6),
              Expanded(child: _buildDateFilter()),
            ],
          ),
          const SizedBox(height: 8),
          // Row 2: Status filter chips
          Row(
            children: [
              const Text('Status: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(width: 4),
              _buildFilterChip('Pendentes', false, Colors.orange),
              const SizedBox(width: 6),
              _buildFilterChip('Todos', null, Colors.grey),
              const SizedBox(width: 6),
              _buildFilterChip('Liberados', true, Colors.green),
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
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

  Widget _buildFilterChip(String label, bool? value, MaterialColor color) {
    final isActive = _filterLiberado == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterLiberado = value;
          _displayLimit = 5;
        });
        _loadInvitations();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? color.shade100 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? color.shade400 : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: isActive ? color.shade700 : Colors.grey.shade500,
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
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

        final hasMore = invitations.length >= _displayLimit;
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: invitations.length + (hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index < invitations.length) {
              return _buildInvitationCard(invitations[index]);
            }
            // "Carregar mais" button
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: TextButton.icon(
                  onPressed: () {
                    setState(() => _displayLimit += 5);
                    _loadInvitations();
                  },
                  icon: const Icon(Icons.expand_more),
                  label: const Text('Carregar mais'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInvitationCard(Invitation inv) {
    final isLiberado = inv.visitanteCompareceu;
    final code = inv.qrData.length >= 3 ? inv.qrData.substring(inv.qrData.length - 3).toUpperCase() : inv.qrData.toUpperCase();
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
                        '${getBlocoLabel(context.read<AuthBloc>().state.tipoEstrutura)}: ${inv.blocoTxt ?? '-'}  /  ${getAptoLabel(context.read<AuthBloc>().state.tipoEstrutura)}: ${inv.aptoTxt ?? '-'}',
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
                // Confirmar Entrada button or Confirmado label
                Row(
                  children: [
                    const Text(
                      'Visitante compareceu',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 12),
                    if (!isLiberado)
                      ElevatedButton(
                        onPressed: () => _showConfirmDialog(inv),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        child: const Text('Confirmar Entrada'),
                      )
                    else
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green.shade600, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            'Confirmado',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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
            _dialogRow(Icons.home_outlined, 'Solicitado por', '${inv.residentName ?? '-'} — ${getBlocoLabel(context.read<AuthBloc>().state.tipoEstrutura)} ${inv.blocoTxt ?? '-'} / ${getAptoLabel(context.read<AuthBloc>().state.tipoEstrutura)} ${inv.aptoTxt ?? '-'}'),
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
