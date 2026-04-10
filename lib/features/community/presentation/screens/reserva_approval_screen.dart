import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/core/di/injection_container.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';


/// Screen for syndic/admin to approve or reject pending space reservations.
class ReservaApprovalScreen extends StatefulWidget {
  const ReservaApprovalScreen({super.key});

  @override
  State<ReservaApprovalScreen> createState() => _ReservaApprovalScreenState();
}

class _ReservaApprovalScreenState extends State<ReservaApprovalScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = sl<SupabaseClient>();
  List<Map<String, dynamic>> _pendentes = [];
  List<Map<String, dynamic>> _historico = [];
  bool _loading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final condoId = context.read<AuthBloc>().state.condominiumId;
    if (condoId == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      // Fetch pending reservations with area info and resident profile
      final pendentes = await _supabase
          .from('reservas')
          .select(
              'id, data_reserva, nome_evento, status, created_at, user_id, '
              'areas_comuns(tipo_agenda, local), '
              'perfil!reservas_user_id_fkey(nome_completo, bloco_txt, apto_txt), '
              'areas_comuns_horarios(hora_inicio)')
          .eq('condominio_id', condoId)
          .eq('status', 'pendente')
          .order('created_at', ascending: false);

      // Fetch recent history (approved/rejected)
      final historico = await _supabase
          .from('reservas')
          .select(
              'id, data_reserva, nome_evento, status, created_at, updated_at, user_id, '
              'areas_comuns(tipo_agenda, local), '
              'perfil!reservas_user_id_fkey(nome_completo, bloco_txt, apto_txt), '
              'areas_comuns_horarios(hora_inicio)')
          .eq('condominio_id', condoId)
          .inFilter('status', ['aprovado', 'reprovado'])
          .order('updated_at', ascending: false)
          .limit(50);

      if (!mounted) return;
      setState(() {
        _pendentes = List<Map<String, dynamic>>.from(pendentes as List);
        _historico = List<Map<String, dynamic>>.from(historico as List);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading reservations: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(String reservaId, String newStatus) async {
    final label = newStatus == 'aprovado' ? 'aprovar' : 'reprovar';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Confirmar ${newStatus == 'aprovado' ? 'aprovação' : 'reprovação'}'),
        content: Text('Deseja $label esta reserva?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              newStatus == 'aprovado' ? 'Aprovar' : 'Reprovar',
              style: TextStyle(
                color: newStatus == 'aprovado' ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    HapticFeedback.mediumImpact();

    try {
      await _supabase.from('reservas').update({
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', reservaId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            newStatus == 'aprovado'
                ? 'Reserva aprovada com sucesso! ✅'
                : 'Reserva reprovada. ❌',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              newStatus == 'aprovado' ? Colors.green.shade700 : Colors.red.shade700,
        ));
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  String _fmtData(String? d) {
    if (d == null || d.isEmpty) return '—';
    final dt = DateTime.tryParse('$d 12:00:00');
    if (dt == null) return d;
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _fmtDateTime(String? d) {
    if (d == null) return '—';
    final dt = DateTime.tryParse(d);
    if (dt == null) return d;
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.primary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Aprovar Reservas',
          style: TextStyle(
              color: AppColors.textMain,
              fontSize: 16,
              fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.primary, size: 20),
            onPressed: _load,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          indicatorColor: AppColors.primary,
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Pendentes'),
                  if (_pendentes.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _pendentes.length.toString(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Histórico'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPendentes(),
                _buildHistorico(),
              ],
            ),
    );
  }

  Widget _buildPendentes() {
    if (_pendentes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 56, color: Colors.green.shade200),
            const SizedBox(height: 16),
            Text(
              'Nenhuma reserva pendente! 🎉',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendentes.length,
        itemBuilder: (_, i) => _buildPendenteCard(_pendentes[i]),
      ),
    );
  }

  Widget _buildHistorico() {
    if (_historico.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Nenhum histórico de aprovações.',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _historico.length,
        itemBuilder: (_, i) => _buildHistoricoCard(_historico[i]),
      ),
    );
  }

  Widget _buildPendenteCard(Map<String, dynamic> r) {
    final area = r['areas_comuns'] as Map<String, dynamic>?;
    final perfil = r['perfil'] as Map<String, dynamic>?;
    final horario = r['areas_comuns_horarios'] as Map<String, dynamic>?;

    final areaNome = area?['tipo_agenda'] as String? ?? '—';
    final areaLocal = area?['local'] as String? ?? '';
    final moradorNome = perfil?['nome_completo'] as String? ?? 'Morador';
    final bloco = perfil?['bloco_txt'] as String? ?? '';
    final apto = perfil?['apto_txt'] as String? ?? '';
    final unidade = bloco.isNotEmpty && apto.isNotEmpty ? '$bloco / $apto' : '';
    final data = _fmtData(r['data_reserva'] as String?);
    final nomeEvento = r['nome_evento'] as String? ?? '';
    final hora = horario != null
        ? (horario['hora_inicio'] as String?)?.substring(0, 5)
        : null;
    final criadoEm = _fmtDateTime(r['created_at'] as String?);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.orange.withValues(alpha: 0.08), blurRadius: 8)
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Area + badge
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.pending_actions,
                      color: Colors.orange, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(areaNome,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.textMain)),
                      if (areaLocal.isNotEmpty)
                        Text(areaLocal,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Pendente',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange)),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Details
            _infoRow(Icons.person_outline, 'Morador', moradorNome),
            if (unidade.isNotEmpty)
              _infoRow(Icons.apartment, 'Unidade', unidade),
            _infoRow(Icons.calendar_today, 'Data', hora != null ? '$data às $hora' : data),
            if (nomeEvento.isNotEmpty && nomeEvento != areaNome)
              _infoRow(Icons.celebration, 'Evento', nomeEvento),
            _infoRow(Icons.access_time, 'Solicitado em', criadoEm),

            const SizedBox(height: 14),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _updateStatus(r['id'] as String, 'reprovado'),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reprovar',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red.shade700,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _updateStatus(r['id'] as String, 'aprovado'),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Aprovar',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoricoCard(Map<String, dynamic> r) {
    final area = r['areas_comuns'] as Map<String, dynamic>?;
    final perfil = r['perfil'] as Map<String, dynamic>?;
    final horario = r['areas_comuns_horarios'] as Map<String, dynamic>?;

    final areaNome = area?['tipo_agenda'] as String? ?? '—';
    final moradorNome = perfil?['nome_completo'] as String? ?? 'Morador';
    final bloco = perfil?['bloco_txt'] as String? ?? '';
    final apto = perfil?['apto_txt'] as String? ?? '';
    final unidade = bloco.isNotEmpty && apto.isNotEmpty ? '$bloco / $apto' : '';
    final data = _fmtData(r['data_reserva'] as String?);
    final hora = horario != null
        ? (horario['hora_inicio'] as String?)?.substring(0, 5)
        : null;
    final status = r['status'] as String? ?? '';

    final isAprovado = status == 'aprovado';
    final statusColor = isAprovado ? Colors.green : Colors.red;
    final statusLabel = isAprovado ? 'Aprovado' : 'Reprovado';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                  isAprovado ? Icons.check_circle : Icons.cancel,
                  color: statusColor,
                  size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(areaNome,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textMain)),
                  const SizedBox(height: 2),
                  Text(
                    '$moradorNome${unidade.isNotEmpty ? ' • $unidade' : ''}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textHint),
                  ),
                  Text(
                    hora != null ? '$data às $hora' : data,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textHint),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(statusLabel,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade400),
          const SizedBox(width: 8),
          Text('$label: ',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500)),
          Flexible(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMain,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
