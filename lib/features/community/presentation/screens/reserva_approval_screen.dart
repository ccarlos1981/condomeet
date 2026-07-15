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
      // Only show pending reservations with future/today dates
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final pendentes = await _supabase
          .from('reservas')
          .select(
              'id, data_reserva, nome_evento, status, created_at, user_id, '
              'areas_comuns(id, tipo_agenda, local), '
              'perfil!reservas_user_id_fkey(nome_completo, bloco_txt, apto_txt), '
              'areas_comuns_horarios(hora_inicio)')
          .eq('condominio_id', condoId)
          .eq('status', 'pendente')
          .gte('data_reserva', today)
          .order('created_at', ascending: false);

      // Fetch recent history (approved/rejected/cancelled)
      final historico = await _supabase
          .from('reservas')
          .select(
              'id, data_reserva, nome_evento, status, created_at, updated_at, user_id, '
              'areas_comuns(id, tipo_agenda, local), '
              'perfil!reservas_user_id_fkey(nome_completo, bloco_txt, apto_txt), '
              'areas_comuns_horarios(hora_inicio)')
          .eq('condominio_id', condoId)
          .inFilter('status', ['aprovado', 'reprovado', 'cancelado'])
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
    String dialogTitle;
    String dialogContent;
    String confirmLabel;
    Color confirmColor;

    switch (newStatus) {
      case 'aprovado':
        dialogTitle = 'Confirmar aprovação';
        dialogContent = 'Deseja aprovar esta reserva?';
        confirmLabel = 'Aprovar';
        confirmColor = Colors.green;
        break;
      case 'cancelado':
        dialogTitle = 'Cancelar reserva';
        dialogContent = 'Deseja cancelar esta reserva? O morador será notificado.';
        confirmLabel = 'Cancelar Reserva';
        confirmColor = Colors.red;
        break;
      default:
        dialogTitle = 'Confirmar reprovação';
        dialogContent = 'Deseja reprovar esta reserva?';
        confirmLabel = 'Reprovar';
        confirmColor = Colors.red;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(dialogTitle),
        content: Text(dialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmLabel,
              style: TextStyle(
                color: confirmColor,
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
        String snackMsg;
        Color snackColor;
        switch (newStatus) {
          case 'aprovado':
            snackMsg = 'Reserva aprovada com sucesso! ✅';
            snackColor = Colors.green.shade700;
            break;
          case 'cancelado':
            snackMsg = 'Reserva cancelada pelo síndico. 🚫';
            snackColor = Colors.orange.shade700;
            break;
          default:
            snackMsg = 'Reserva reprovada. ❌';
            snackColor = Colors.red.shade700;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(snackMsg),
          behavior: SnackBarBehavior.floating,
          backgroundColor: snackColor,
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

            // Details with calendar button on the right
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow(Icons.person_outline, 'Morador', moradorNome),
                      if (unidade.isNotEmpty)
                        _infoRow(Icons.apartment, 'Unidade', unidade),
                      _infoRow(Icons.calendar_today, 'Data', hora != null ? '$data às $hora' : data),
                      if (nomeEvento.isNotEmpty && nomeEvento != areaNome)
                        _infoRow(Icons.celebration, 'Evento', nomeEvento),
                      _infoRow(Icons.access_time, 'Solicitado em', criadoEm),
                    ],
                  ),
                ),
                if (area?['id'] != null) ...[
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _showAreaCalendar(
                      area!['id'] as String,
                      areaNome,
                      r['data_reserva'] as String?,
                    ),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(
                        Icons.calendar_month_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ],
            ),

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
    final isCancelado = status == 'cancelado';
    final statusColor = isAprovado ? Colors.green : isCancelado ? Colors.grey : Colors.red;
    final statusLabel = isAprovado ? 'Aprovado' : isCancelado ? 'Cancelado' : 'Reprovado';

    // Síndico can cancel any approved reservation
    final canCancel = isAprovado;
    final dataReserva = r['data_reserva'] as String?;
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final isEventoPast = dataReserva != null && dataReserva.compareTo(todayStr) < 0;

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
        child: Column(
          children: [
            Row(
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
                  child: Row(
                    children: [
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
                      if (area?['id'] != null) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _showAreaCalendar(
                            area!['id'] as String,
                            areaNome,
                            r['data_reserva'] as String?,
                          ),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                            ),
                            child: const Icon(
                              Icons.calendar_month_rounded,
                              color: AppColors.primary,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
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
            if (canCancel) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isEventoPast
                      ? null
                      : () => _updateStatus(r['id'] as String, 'cancelado'),
                  icon: Icon(
                    isEventoPast ? Icons.block : Icons.event_busy,
                    size: 16,
                  ),
                  label: Text(
                    isEventoPast ? 'Evento Vencido' : 'Cancelar Evento',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isEventoPast ? Colors.grey.shade400 : Colors.red.shade600,
                    side: BorderSide(color: isEventoPast ? Colors.grey.shade300 : Colors.red.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    disabledForegroundColor: Colors.grey.shade400,
                  ),
                ),
              ),
            ],
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

  void _showAreaCalendar(String areaId, String areaNome, String? focusDate) {
    showDialog(
      context: context,
      builder: (_) => AreaCalendarDialog(
        areaId: areaId,
        areaNome: areaNome,
        focusDate: focusDate,
      ),
    );
  }
}

const _mesesList = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro'
];

const _diasSemanaList = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];

class AreaCalendarDialog extends StatefulWidget {
  final String areaId;
  final String areaNome;
  final String? focusDate;

  const AreaCalendarDialog({
    super.key,
    required this.areaId,
    required this.areaNome,
    this.focusDate,
  });

  @override
  State<AreaCalendarDialog> createState() => _AreaCalendarDialogState();
}

class _AreaCalendarDialogState extends State<AreaCalendarDialog> {
  late int _viewYear;
  late int _viewMonth;
  String? _selectedDate;
  List<Map<String, dynamic>> _reservations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.focusDate != null && widget.focusDate!.isNotEmpty) {
      final dt = DateTime.tryParse(widget.focusDate!);
      if (dt != null) {
        _viewYear = dt.year;
        _viewMonth = dt.month;
        _selectedDate = widget.focusDate;
      } else {
        final now = DateTime.now();
        _viewYear = now.year;
        _viewMonth = now.month;
        _selectedDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      }
    } else {
      final now = DateTime.now();
      _viewYear = now.year;
      _viewMonth = now.month;
      _selectedDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }
    _loadReservations();
  }

  Future<void> _loadReservations() async {
    setState(() => _loading = true);
    try {
      final firstOfMonth = '$_viewYear-${_viewMonth.toString().padLeft(2, '0')}-01';
      final lastDay = DateTime(_viewYear, _viewMonth + 1, 0).day;
      final lastOfMonth = '$_viewYear-${_viewMonth.toString().padLeft(2, '0')}-$lastDay';

      final data = await sl<SupabaseClient>()
          .from('reservas')
          .select(
              'id, data_reserva, status, nome_evento, '
              'perfil!reservas_user_id_fkey(nome_completo, bloco_txt, apto_txt), '
              'areas_comuns_horarios(hora_inicio)')
          .eq('area_id', widget.areaId)
          .inFilter('status', ['pendente', 'aprovado'])
          .gte('data_reserva', firstOfMonth)
          .lte('data_reserva', lastOfMonth);

      if (mounted) {
        setState(() {
          _reservations = List<Map<String, dynamic>>.from(data as List);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading calendar reservations: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _prevMonth() {
    setState(() {
      if (_viewMonth == 1) {
        _viewYear--;
        _viewMonth = 12;
      } else {
        _viewMonth--;
      }
      _selectedDate = null;
    });
    _loadReservations();
  }

  void _nextMonth() {
    setState(() {
      if (_viewMonth == 12) {
        _viewYear++;
        _viewMonth = 1;
      } else {
        _viewMonth++;
      }
      _selectedDate = null;
    });
    _loadReservations();
  }

  String _fmtDateBr(String iso) {
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Map<String, dynamic>>> resByDate = {};
    for (final r in _reservations) {
      final date = r['data_reserva'] as String?;
      if (date != null) {
        resByDate[date] ??= [];
        resByDate[date]!.add(r);
      }
    }

    final firstDay = DateTime(_viewYear, _viewMonth, 1);
    final lastDay = DateTime(_viewYear, _viewMonth + 1, 0).day;
    final startDow = firstDay.weekday % 7; // 0 = Sunday

    final selectedDayReservations = _selectedDate != null ? (resByDate[_selectedDate] ?? []) : [];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 620),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Agenda da Área Comum',
                        style: TextStyle(fontSize: 11, color: AppColors.textHint, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.areaNome,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.primary, size: 22),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: AppColors.primary),
                  onPressed: _prevMonth,
                ),
                const Spacer(),
                Text(
                  '${_mesesList[_viewMonth - 1]} de $_viewYear',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMain),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: AppColors.primary),
                  onPressed: _nextMonth,
                ),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              children: _diasSemanaList
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: const TextStyle(fontSize: 11, color: AppColors.textHint, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 6),

            if (_loading)
              const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1.2,
                ),
                itemCount: startDow + lastDay,
                itemBuilder: (_, i) {
                  if (i < startDow) return const SizedBox();
                  final day = i - startDow + 1;
                  final iso = '$_viewYear-${_viewMonth.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                  final dayReservations = resByDate[iso] ?? [];
                  
                  final isSelected = iso == _selectedDate;
                  final isFocus = iso == widget.focusDate;

                  bool hasPending = false;
                  bool hasApproved = false;
                  for (final r in dayReservations) {
                    if (r['status'] == 'pendente') hasPending = true;
                    if (r['status'] == 'aprovado') hasApproved = true;
                  }

                  Color textColor = AppColors.textMain;
                  BoxDecoration? boxDec;

                  if (isSelected) {
                    textColor = Colors.white;
                    boxDec = BoxDecoration(
                      color: AppColors.textMain,
                      shape: BoxShape.circle,
                    );
                  } else if (isFocus) {
                    boxDec = BoxDecoration(
                      border: Border.all(color: Colors.orange.shade400, width: 2),
                      shape: BoxShape.circle,
                    );
                  }

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedDate = iso;
                      });
                    },
                    child: Container(
                      decoration: boxDec,
                      margin: const EdgeInsets.all(2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected || isFocus ? FontWeight.bold : FontWeight.normal,
                              color: textColor,
                            ),
                          ),
                          if (dayReservations.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (hasApproved)
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                if (hasApproved && hasPending) const SizedBox(width: 2),
                                if (hasPending)
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      color: Colors.orange,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),

            Expanded(
              child: _selectedDate == null
                  ? const Center(
                      child: Text(
                        'Selecione um dia para ver as reservas',
                        style: TextStyle(fontSize: 12, color: AppColors.textHint),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reservas em ${_fmtDateBr(_selectedDate!)}:',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMain),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: selectedDayReservations.isEmpty
                              ? Center(
                                  child: Text(
                                    'Nenhuma reserva para este dia',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: selectedDayReservations.length,
                                  itemBuilder: (_, idx) {
                                    final res = selectedDayReservations[idx];
                                    final p = res['perfil'] as Map<String, dynamic>?;
                                    final h = res['areas_comuns_horarios'] as Map<String, dynamic>?;
                                    final morador = p?['nome_completo'] as String? ?? 'Morador';
                                    final blk = p?['bloco_txt'] as String? ?? '';
                                    final apt = p?['apto_txt'] as String? ?? '';
                                    final unitStr = blk.isNotEmpty && apt.isNotEmpty ? ' ($blk/$apt)' : '';
                                    
                                    final status = res['status'] as String? ?? '';
                                    final isAppr = status == 'aprovado';
                                    
                                    final time = h != null && h['hora_inicio'] != null
                                        ? (h['hora_inicio'] as String).substring(0, 5)
                                        : 'Dia inteiro';

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isAppr ? Icons.check_circle : Icons.pending,
                                            color: isAppr ? Colors.green : Colors.orange,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '$morador$unitStr',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.textMain,
                                                  ),
                                                ),
                                                Text(
                                                  'Horário: $time',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isAppr ? Colors.green.shade50 : Colors.orange.shade50,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              isAppr ? 'Aprovado' : 'Pendente',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: isAppr ? Colors.green.shade700 : Colors.orange.shade700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
