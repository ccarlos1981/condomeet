import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/core/utils/structure_helper.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/features/portaria/domain/repositories/resident_repository.dart';
import 'package:condomeet/core/di/injection_container.dart';

/// Status filter for the approval screen
enum _StatusFilter { pendentes, liberados, bloqueados }

class ManagerApprovalScreen extends StatefulWidget {
  const ManagerApprovalScreen({super.key});

  @override
  State<ManagerApprovalScreen> createState() => _ManagerApprovalScreenState();
}

class _ManagerApprovalScreenState extends State<ManagerApprovalScreen> {
  List<Resident> _allResidents = [];
  bool _isLoading = true;
  _StatusFilter _filter = _StatusFilter.pendentes;
  bool _isActing = false;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final condominiumId = context.read<AuthBloc>().state.condominiumId;
    if (condominiumId == null) {
      setState(() => _isLoading = false);
      return;
    }
    final repository = sl<ResidentRepository>();
    final result = await repository.getAllResidents(condominiumId);
    if (mounted) {
      if (result.isSuccess) {
        setState(() {
          _allResidents = result.successData;
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

  List<Resident> get _filtered {
    final q = _searchQuery.toLowerCase();
    return _allResidents.where((r) {
      // Status filter
      final matchesStatus = switch (_filter) {
        _StatusFilter.pendentes => r.status == 'pendente',
        _StatusFilter.liberados => r.status == 'aprovado',
        _StatusFilter.bloqueados => r.status == 'bloqueado' || r.status == 'rejeitado',
      };
      if (!matchesStatus) return false;
      // Search filter
      if (q.isEmpty) return true;
      final name = r.fullName.toLowerCase();
      final bloco = (r.block ?? '').toLowerCase();
      final apto = (r.unitNumber ?? '').toLowerCase();
      return name.contains(q) || bloco.contains(q) || apto.contains(q);
    }).toList();
  }

  Future<void> _approveResident(Resident resident) async {
    setState(() => _isActing = true);
    final repo = sl<ResidentRepository>();
    final result = await repo.approveResident(resident.id);
    if (mounted) {
      setState(() => _isActing = false);
      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${resident.fullName} aprovado!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadAll();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.failureMessage), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _rejectResident(Resident resident) async {
    // Confirm before rejecting
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Recusar cadastro?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Tem certeza que deseja recusar o cadastro de ${resident.fullName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Recusar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isActing = true);
    final repo = sl<ResidentRepository>();
    final result = await repo.rejectResident(resident.id);
    if (mounted) {
      setState(() => _isActing = false);
      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cadastro recusado.'), backgroundColor: Colors.orange),
        );
        _loadAll();
      }
    }
  }

  Future<void> _toggleBlock(Resident resident) async {
    final isBlocked = resident.status == 'bloqueado' || resident.status == 'rejeitado';
    final action = isBlocked ? 'desbloquear' : 'bloquear';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${isBlocked ? 'Desbloquear' : 'Bloquear'} morador?',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Deseja $action ${resident.fullName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isBlocked ? Colors.green : AppColors.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isBlocked ? 'Desbloquear' : 'Bloquear',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isActing = true);
    final repo = sl<ResidentRepository>();
    final result = isBlocked
        ? await repo.unblockResident(resident.id)
        : await repo.blockResident(resident.id);

    if (mounted) {
      setState(() => _isActing = false);
      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isBlocked ? '✅ ${resident.fullName} desbloqueado!' : '🔒 ${resident.fullName} bloqueado.'),
            backgroundColor: isBlocked ? Colors.green : Colors.orange,
          ),
        );
        _loadAll();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.failureMessage), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tipoEstrutura = context.read<AuthBloc>().state.tipoEstrutura;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Aprovar cadastro de morador',
          style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _loadAll,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          _buildSearchBar(),
          if (_isActing)
            LinearProgressIndicator(color: AppColors.primary, backgroundColor: AppColors.primary.withValues(alpha: 0.1)),
          if (_filter == _StatusFilter.pendentes && _filtered.isNotEmpty)
            Container(
              width: double.infinity,
              color: Colors.orange.shade50,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.swipe, size: 14, color: Colors.orange.shade700),
                  const SizedBox(width: 6),
                  Text(
                    'Deslize para direita → Aprovar    |    ← Esquerda → Recusar',
                    style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                  ),
                ],
              ),
            ),
          Expanded(child: _buildBody(tipoEstrutura)),
        ],
      ),
    );
  }


  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _searchQuery = v),
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Buscar por nome, bloco ou apto...',
          hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
          prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16, color: Colors.grey),
                  onPressed: () => setState(() {
                    _searchCtrl.clear();
                    _searchQuery = '';
                  }),
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.primary),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        children: [
          _radioOption('Pendentes', _StatusFilter.pendentes, Colors.orange),
          const SizedBox(width: 4),
          _radioOption('Liberados', _StatusFilter.liberados, Colors.green),
          const SizedBox(width: 4),
          _radioOption('Bloqueados', _StatusFilter.bloqueados, AppColors.error),
        ],
      ),
    );
  }

  Widget _radioOption(String label, _StatusFilter value, Color color) {
    final selected = _filter == value;
    // count badge
    final count = _allResidents.where((r) {
      switch (value) {
        case _StatusFilter.pendentes:
          return r.status == 'pendente';
        case _StatusFilter.liberados:
          return r.status == 'aprovado';
        case _StatusFilter.bloqueados:
          return r.status == 'bloqueado' || r.status == 'rejeitado';
      }
    }).length;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.12) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? color : Colors.grey.shade300,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: selected ? color : Colors.grey,
                size: 16,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: selected ? color : Colors.grey.shade600,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected ? color : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(String? tipoEstrutura) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final residents = _filtered;
    if (residents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _filter == _StatusFilter.pendentes
                  ? Icons.verified_user_rounded
                  : _filter == _StatusFilter.liberados
                      ? Icons.people_alt_outlined
                      : Icons.block,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              _filter == _StatusFilter.pendentes
                  ? 'Nenhuma solicitação pendente'
                  : _filter == _StatusFilter.liberados
                      ? 'Nenhum morador liberado'
                      : 'Nenhum morador bloqueado',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: residents.length,
      itemBuilder: (ctx, i) {
        final resident = residents[i];
        final isPending = resident.status == 'pendente';

        if (!isPending) {
          return _buildCard(resident, tipoEstrutura);
        }

        // ── Swipe-to-approve/reject for pending residents ──
        return Dismissible(
          key: ValueKey(resident.id),
          direction: DismissDirection.horizontal,
          confirmDismiss: (direction) async {
            if (_isActing) return false;
            if (direction == DismissDirection.startToEnd) {
              await _approveResident(resident);
            } else {
              await _rejectResident(resident);
            }
            return false;
          },
          background: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.green.shade400,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 32),
                SizedBox(height: 4),
                Text('APROVAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
          secondaryBackground: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.red.shade400,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cancel_rounded, color: Colors.white, size: 32),
                SizedBox(height: 4),
                Text('RECUSAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
          child: _buildCard(resident, tipoEstrutura),
        );
      },
    );
  }


  Widget _buildCard(Resident resident, String? tipoEstrutura) {
    final isPending = resident.status == 'pendente';
    final isBlocked = resident.status == 'bloqueado' || resident.status == 'rejeitado';
    final isApproved = resident.status == 'aprovado';

    Color headerColor = isPending
        ? Colors.orange.shade50
        : isApproved
            ? Colors.green.shade50
            : Colors.red.shade50;
    Color badgeColor = isPending
        ? Colors.orange
        : isApproved
            ? Colors.green
            : AppColors.error;

    final unitLabel = StructureHelper.getFullUnitName(
        tipoEstrutura, resident.block ?? '-', resident.unitNumber ?? '-');

    final dateLabel = resident.createdAt != null
        ? DateFormat('dd/MM/yyyy').format(resident.createdAt!)
        : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person_outline, size: 20, color: Colors.grey),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(resident.fullName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(unitLabel,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                // Type badges
                if (resident.tipoMorador != null)
                  _badge(resident.tipoMorador!, Colors.grey.shade200, Colors.black87),
                const SizedBox(width: 4),
                if (resident.papelSistema != null)
                  _badge(resident.papelSistema!, badgeColor.withValues(alpha: 0.15), badgeColor),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (resident.email != null)
                  _infoRow(Icons.email_outlined, resident.email!),
                if (resident.phoneNumber != null)
                  _infoRow(Icons.phone_outlined, resident.phoneNumber!),
                _infoRow(Icons.calendar_today_outlined, 'Cadastro criado em: $dateLabel'),
                const SizedBox(height: 10),
                // Action row
                if (isPending)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isActing ? null : () => _rejectResident(resident),
                          icon: const Icon(Icons.cancel_outlined, size: 16),
                          label: const Text('Recusar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: BorderSide(color: AppColors.error),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isActing ? null : () => _approveResident(resident),
                          icon: const Icon(Icons.check_circle_outline, size: 16),
                          label: const Text('Aprovar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isBlocked ? 'Bloquear Morador' : 'Bloquear Morador',
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                      Row(
                        children: [
                          Text(
                            isApproved ? 'Liberado' : 'Bloqueado',
                            style: TextStyle(
                              fontSize: 12,
                              color: isApproved ? Colors.green : AppColors.error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Switch(
                            value: isApproved,
                            onChanged: _isActing ? null : (_) => _toggleBlock(resident),
                            activeThumbColor: Colors.green,
                            inactiveThumbColor: AppColors.error,
                          ),
                        ],
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

  Widget _badge(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w500)),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(icon, size: 13, color: Colors.grey),
          const SizedBox(width: 4),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}
