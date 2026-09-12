import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/core/di/injection_container.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/features/community/domain/models/common_area.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Deterministic Color Palette for Common Areas (matching Web implementation)
// ──────────────────────────────────────────────────────────────────────────────
const List<Color> _areaPalette = [
  Color(0xFFFC5931), // Brand Coral/Orange
  Color(0xFF10B981), // Emerald
  Color(0xFF3B82F6), // Blue
  Color(0xFF8B5CF6), // Purple
  Color(0xFFF59E0B), // Amber
  Color(0xFFEC4899), // Pink
  Color(0xFF06B6D4), // Cyan
  Color(0xFF6366F1), // Indigo
];

Color getAreaColor(String areaIdOrName) {
  if (areaIdOrName.isEmpty) return _areaPalette[0];
  int hash = 0;
  for (int i = 0; i < areaIdOrName.length; i++) {
    hash = (hash << 5) - hash + areaIdOrName.codeUnitAt(i);
    hash &= 0xFFFFFFFF;
    if (hash > 0x7FFFFFFF) {
      hash -= 0x100000000;
    }
  }
  final index = hash.abs() % _areaPalette.length;
  return _areaPalette[index];
}

const _mesesList = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
];

const _diasSemanaList = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];

/// Screen for syndic/admin to approve or reject pending space reservations,
/// with administrative filters (Bloco, Apto, Área) and Calendar view.
class ReservaApprovalScreen extends StatefulWidget {
  const ReservaApprovalScreen({super.key});

  @override
  State<ReservaApprovalScreen> createState() => _ReservaApprovalScreenState();
}

class _ReservaApprovalScreenState extends State<ReservaApprovalScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = sl<SupabaseClient>();
  static const int _pageSize = 20;

  List<Map<String, dynamic>> _pendentes = [];
  List<Map<String, dynamic>> _historico = [];
  bool _loading = true;
  bool _loadingMoreHistorico = false;
  bool _hasMoreHistorico = true;
  bool _isUpdatingStatus = false;
  late TabController _tabController;

  // View mode toggle
  bool _isCalendarView = false;

  // Administrative Filters state (shared between List and Calendar)
  String? _selectedAreaId;
  String? _selectedBloco;
  String? _selectedApto;

  List<Map<String, dynamic>> _areas = [];
  List<String> _blocos = [];
  Map<String, List<String>> _aptosPorBloco = {};
  List<String> _todosAptos = [];

  // Calendar state
  late int _calYear;
  late int _calMonth;
  String? _calSelectedDate;
  List<Map<String, dynamic>> _calReservations = [];
  bool _loadingCalendar = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _calYear = now.year;
    _calMonth = now.month;
    _calSelectedDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFilterOptions(String condoId) async {
    try {
      final areasRes = await _supabase
          .from('areas_comuns')
          .select('id, tipo_agenda, local, outro_local')
          .eq('condominio_id', condoId)
          .order('tipo_agenda');

      final perfisRes = await _supabase
          .from('perfil')
          .select('bloco_txt, apto_txt')
          .eq('condominio_id', condoId)
          .not('bloco_txt', 'is', null)
          .not('apto_txt', 'is', null);

      if (!mounted) return;

      final areasList = List<Map<String, dynamic>>.from(areasRes as List);
      final perfisList = List<Map<String, dynamic>>.from(perfisRes as List);

      final blocosSet = <String>{};
      final aptosPorBlocoMap = <String, Set<String>>{};
      final todosAptosSet = <String>{};

      for (final p in perfisList) {
        final b = (p['bloco_txt'] as String?)?.trim();
        final a = (p['apto_txt'] as String?)?.trim();
        if (b != null && b.isNotEmpty) {
          blocosSet.add(b);
          if (a != null && a.isNotEmpty) {
            aptosPorBlocoMap.putIfAbsent(b, () => <String>{}).add(a);
          }
        }
        if (a != null && a.isNotEmpty) {
          todosAptosSet.add(a);
        }
      }

      final sortedBlocos = blocosSet.toList()..sort();
      final sortedAptosPorBloco = <String, List<String>>{};
      for (final entry in aptosPorBlocoMap.entries) {
        final list = entry.value.toList()
          ..sort((a, b) => int.tryParse(a) != null && int.tryParse(b) != null
              ? int.parse(a).compareTo(int.parse(b))
              : a.compareTo(b));
        sortedAptosPorBloco[entry.key] = list;
      }
      final sortedTodosAptos = todosAptosSet.toList()
        ..sort((a, b) => int.tryParse(a) != null && int.tryParse(b) != null
            ? int.parse(a).compareTo(int.parse(b))
            : a.compareTo(b));

      setState(() {
        _areas = areasList;
        _blocos = sortedBlocos;
        _aptosPorBloco = sortedAptosPorBloco;
        _todosAptos = sortedTodosAptos;
      });
    } catch (e) {
      debugPrint('Error loading filter options: $e');
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final condoId = context.read<AuthBloc>().state.condominiumId;
    if (condoId == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      if (_areas.isEmpty && _blocos.isEmpty) {
        _loadFilterOptions(condoId);
      }

      final today = DateTime.now().toIso8601String().substring(0, 10);

      final hasPerfilFilter = _selectedBloco != null || _selectedApto != null;
      final perfilSelect = hasPerfilFilter
          ? 'perfil!inner!reservas_user_id_fkey(nome_completo, bloco_txt, apto_txt)'
          : 'perfil!reservas_user_id_fkey(nome_completo, bloco_txt, apto_txt)';

      final selectStr =
          'id, data_reserva, nome_evento, status, created_at, user_id, '
          'areas_comuns(id, tipo_agenda, local, outro_local), '
          '$perfilSelect, '
          'areas_comuns_horarios(hora_inicio)';

      var pendentesQuery = _supabase
          .from('reservas')
          .select(selectStr)
          .eq('condominio_id', condoId)
          .eq('status', 'pendente')
          .gte('data_reserva', today);

      var historicoQuery = _supabase
          .from('reservas')
          .select(selectStr)
          .eq('condominio_id', condoId)
          .inFilter('status', ['aprovado', 'reprovado', 'cancelado']);

      if (_selectedAreaId != null) {
        pendentesQuery = pendentesQuery.eq('area_id', _selectedAreaId!);
        historicoQuery = historicoQuery.eq('area_id', _selectedAreaId!);
      }
      if (_selectedBloco != null) {
        pendentesQuery = pendentesQuery.eq('perfil.bloco_txt', _selectedBloco!);
        historicoQuery = historicoQuery.eq('perfil.bloco_txt', _selectedBloco!);
      }
      if (_selectedApto != null) {
        pendentesQuery = pendentesQuery.eq('perfil.apto_txt', _selectedApto!);
        historicoQuery = historicoQuery.eq('perfil.apto_txt', _selectedApto!);
      }

      final pendentes =
          await pendentesQuery.order('created_at', ascending: false);

      final historico = await historicoQuery
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .range(0, _pageSize - 1);

      if (!mounted) return;
      final historicoList = List<Map<String, dynamic>>.from(historico as List);
      setState(() {
        _pendentes = List<Map<String, dynamic>>.from(pendentes as List);
        _historico = historicoList;
        _hasMoreHistorico = historicoList.length >= _pageSize;
        _loading = false;
      });

      if (_isCalendarView) {
        _loadCalendarReservations();
      }
    } catch (e) {
      debugPrint('Error loading reservations: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMoreHistorico() async {
    if (_loadingMoreHistorico || !_hasMoreHistorico) return;

    final condoId = context.read<AuthBloc>().state.condominiumId;
    if (condoId == null) return;

    setState(() => _loadingMoreHistorico = true);

    try {
      final from = _historico.length;
      final to = from + _pageSize - 1;

      final hasPerfilFilter = _selectedBloco != null || _selectedApto != null;
      final perfilSelect = hasPerfilFilter
          ? 'perfil!inner!reservas_user_id_fkey(nome_completo, bloco_txt, apto_txt)'
          : 'perfil!reservas_user_id_fkey(nome_completo, bloco_txt, apto_txt)';

      final selectStr =
          'id, data_reserva, nome_evento, status, created_at, updated_at, user_id, '
          'areas_comuns(id, tipo_agenda, local, outro_local), '
          '$perfilSelect, '
          'areas_comuns_horarios(hora_inicio)';

      var query = _supabase
          .from('reservas')
          .select(selectStr)
          .eq('condominio_id', condoId)
          .inFilter('status', ['aprovado', 'reprovado', 'cancelado']);

      if (_selectedAreaId != null) {
        query = query.eq('area_id', _selectedAreaId!);
      }
      if (_selectedBloco != null) {
        query = query.eq('perfil.bloco_txt', _selectedBloco!);
      }
      if (_selectedApto != null) {
        query = query.eq('perfil.apto_txt', _selectedApto!);
      }

      final moreData = await query
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .range(from, to);

      if (!mounted) return;

      final incomingList = List<Map<String, dynamic>>.from(moreData as List);
      final existingIds = _historico.map((r) => r['id']).toSet();
      final newUniqueItems =
          incomingList.where((r) => !existingIds.contains(r['id'])).toList();

      setState(() {
        _historico.addAll(newUniqueItems);
        _hasMoreHistorico = incomingList.length >= _pageSize;
        _loadingMoreHistorico = false;
      });
    } catch (e) {
      debugPrint('Error loading more history: $e');
      if (mounted) setState(() => _loadingMoreHistorico = false);
    }
  }

  Future<void> _loadCalendarReservations() async {
    final condoId = context.read<AuthBloc>().state.condominiumId;
    if (condoId == null) return;

    setState(() => _loadingCalendar = true);
    try {
      final firstOfMonth =
          '$_calYear-${_calMonth.toString().padLeft(2, '0')}-01';
      final lastDay = DateTime(_calYear, _calMonth + 1, 0).day;
      final lastOfMonth =
          '$_calYear-${_calMonth.toString().padLeft(2, '0')}-$lastDay';

      final hasPerfilFilter = _selectedBloco != null || _selectedApto != null;
      final perfilSelect = hasPerfilFilter
          ? 'perfil!inner!reservas_user_id_fkey(nome_completo, bloco_txt, apto_txt)'
          : 'perfil!reservas_user_id_fkey(nome_completo, bloco_txt, apto_txt)';

      final selectStr =
          'id, data_reserva, status, nome_evento, user_id, '
          'areas_comuns(id, tipo_agenda, local, outro_local), '
          '$perfilSelect, '
          'areas_comuns_horarios(hora_inicio)';

      var query = _supabase
          .from('reservas')
          .select(selectStr)
          .eq('condominio_id', condoId)
          .inFilter('status', ['pendente', 'aprovado'])
          .gte('data_reserva', firstOfMonth)
          .lte('data_reserva', lastOfMonth);

      if (_selectedAreaId != null) {
        query = query.eq('area_id', _selectedAreaId!);
      }
      if (_selectedBloco != null) {
        query = query.eq('perfil.bloco_txt', _selectedBloco!);
      }
      if (_selectedApto != null) {
        query = query.eq('perfil.apto_txt', _selectedApto!);
      }

      final data = await query.order('data_reserva', ascending: true);

      if (mounted) {
        setState(() {
          _calReservations = List<Map<String, dynamic>>.from(data as List);
          _loadingCalendar = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading calendar reservations: $e');
      if (mounted) setState(() => _loadingCalendar = false);
    }
  }

  void _prevCalMonth() {
    setState(() {
      if (_calMonth == 1) {
        _calYear--;
        _calMonth = 12;
      } else {
        _calMonth--;
      }
      _calSelectedDate = null;
    });
    _loadCalendarReservations();
  }

  void _nextCalMonth() {
    setState(() {
      if (_calMonth == 12) {
        _calYear++;
        _calMonth = 1;
      } else {
        _calMonth++;
      }
      _calSelectedDate = null;
    });
    _loadCalendarReservations();
  }

  void _goToCalToday() {
    final now = DateTime.now();
    setState(() {
      _calYear = now.year;
      _calMonth = now.month;
      _calSelectedDate =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    });
    _loadCalendarReservations();
  }

  void _onFilterChanged() {
    if (_isCalendarView) {
      _loadCalendarReservations();
    } else {
      _load();
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedAreaId = null;
      _selectedBloco = null;
      _selectedApto = null;
    });
    _onFilterChanged();
  }

  void _setBloco(String? newBloco) {
    setState(() {
      _selectedBloco = newBloco;
      if (newBloco != null) {
        final allowedAptos = _aptosPorBloco[newBloco] ?? [];
        if (_selectedApto != null && !allowedAptos.contains(_selectedApto)) {
          _selectedApto = null;
        }
      }
    });
    _onFilterChanged();
  }

  Future<void> _updateStatus(String reservaId, String newStatus) async {
    if (_isUpdatingStatus) return;

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
        dialogContent =
            'Deseja cancelar esta reserva? O morador será notificado.';
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
    if (_isUpdatingStatus) return;

    setState(() => _isUpdatingStatus = true);

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
        await _load();
        if (_isCalendarView) {
          await _loadCalendarReservations();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
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

  String _getAreaNome(String areaId) {
    final a = _areas.firstWhere(
      (element) => element['id'] == areaId,
      orElse: () => {'tipo_agenda': 'Área'},
    );
    return a['tipo_agenda'] as String? ?? 'Área';
  }

  bool get _hasActiveFilters =>
      _selectedAreaId != null ||
      _selectedBloco != null ||
      _selectedApto != null;

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
            icon: Icon(
              _isCalendarView
                  ? Icons.list_alt_rounded
                  : Icons.calendar_month_rounded,
              color: AppColors.primary,
              size: 22,
            ),
            tooltip: _isCalendarView ? 'Ver Lista' : 'Ver Calendário',
            onPressed: () {
              setState(() {
                _isCalendarView = !_isCalendarView;
                if (_isCalendarView) {
                  _loadCalendarReservations();
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.primary, size: 20),
            onPressed: () {
              if (_isCalendarView) {
                _loadCalendarReservations();
              } else {
                _load();
              }
            },
          ),
        ],
        bottom: _isCalendarView
            ? null
            : TabBar(
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
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _isCalendarView
                    ? _buildCalendarView()
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildPendentes(),
                          _buildHistorico(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Filter Bar Widget (Shared between List and Calendar)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Area Filter Chip
            _filterChip(
              label: _selectedAreaId == null
                  ? 'Área'
                  : _getAreaNome(_selectedAreaId!),
              icon: Icons.meeting_room_outlined,
              isActive: _selectedAreaId != null,
              onTap: _showAreaPickerModal,
            ),
            const SizedBox(width: 8),

            // Bloco Filter Chip
            _filterChip(
              label: _selectedBloco == null
                  ? 'Bloco'
                  : 'Bloco $_selectedBloco',
              icon: Icons.apartment_outlined,
              isActive: _selectedBloco != null,
              onTap: _showBlocoPickerModal,
            ),
            const SizedBox(width: 8),

            // Apto Filter Chip
            _filterChip(
              label: _selectedApto == null
                  ? 'Apto'
                  : 'Apto $_selectedApto',
              icon: Icons.door_front_door_outlined,
              isActive: _selectedApto != null,
              onTap: _showAptoPickerModal,
            ),
            const SizedBox(width: 8),

            // Clear Filters Action
            if (_hasActiveFilters)
              InkWell(
                onTap: _clearFilters,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.filter_alt_off,
                          size: 14, color: Colors.red.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Limpar',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? AppColors.primary : Colors.grey.shade600,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? AppColors.primary : AppColors.textMain,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: isActive ? AppColors.primary : Colors.grey.shade500,
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Filter Pickers (Modals)
  // ──────────────────────────────────────────────────────────────────────────
  void _showAreaPickerModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'Filtrar por Área Comum',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Todas as áreas'),
                trailing: _selectedAreaId == null
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _selectedAreaId = null);
                  _onFilterChanged();
                },
              ),
              ..._areas.map((a) {
                final id = a['id'] as String;
                final nome = a['tipo_agenda'] as String? ?? 'Área';
                final isSel = _selectedAreaId == id;
                final color = getAreaColor(id);
                return ListTile(
                  leading: Container(
                    width: 12,
                    height: 12,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  title: Text(nome),
                  trailing: isSel
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedAreaId = id);
                    _onFilterChanged();
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showBlocoPickerModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'Filtrar por Bloco',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Todos os blocos'),
                trailing: _selectedBloco == null
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  _setBloco(null);
                },
              ),
              ..._blocos.map((b) {
                final isSel = _selectedBloco == b;
                return ListTile(
                  title: Text('Bloco $b'),
                  trailing: isSel
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    _setBloco(b);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showAptoPickerModal() {
    final aptosToShow = _selectedBloco != null
        ? (_aptosPorBloco[_selectedBloco] ?? [])
        : _todosAptos;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (_, controller) {
            return SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      _selectedBloco != null
                          ? 'Filtrar Apartamento (Bloco $_selectedBloco)'
                          : 'Filtrar por Apartamento',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Todos os apartamentos'),
                    trailing: _selectedApto == null
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _selectedApto = null);
                      _onFilterChanged();
                    },
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: controller,
                      itemCount: aptosToShow.length,
                      itemBuilder: (_, i) {
                        final a = aptosToShow[i];
                        final isSel = _selectedApto == a;
                        return ListTile(
                          title: Text('Apartamento $a'),
                          trailing: isSel
                              ? const Icon(Icons.check,
                                  color: AppColors.primary)
                              : null,
                          onTap: () {
                            Navigator.pop(context);
                            setState(() => _selectedApto = a);
                            _onFilterChanged();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // VIEW: CALENDAR
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildCalendarView() {
    final Map<String, List<Map<String, dynamic>>> resByDate = {};
    for (final r in _calReservations) {
      final date = r['data_reserva'] as String?;
      if (date != null) {
        resByDate[date] ??= [];
        resByDate[date]!.add(r);
      }
    }

    final firstDay = DateTime(_calYear, _calMonth, 1);
    final lastDay = DateTime(_calYear, _calMonth + 1, 0).day;
    final startDow = firstDay.weekday % 7; // 0 = Sunday

    final selectedDayReservations =
        _calSelectedDate != null ? (resByDate[_calSelectedDate] ?? []) : [];

    // Distinct areas in current month for legend
    final Map<String, String> areasInMonth = {};
    for (final r in _calReservations) {
      final area = r['areas_comuns'] as Map<String, dynamic>?;
      final areaId = area?['id'] as String? ?? r['area_id'] as String? ?? '';
      final areaNome = area?['tipo_agenda'] as String? ?? 'Área';
      if (areaId.isNotEmpty) {
        areasInMonth[areaId] = areaNome;
      }
    }

    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadCalendarReservations,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        children: [
          // Month navigation bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: AppColors.primary),
                  onPressed: _prevCalMonth,
                ),
                const Spacer(),
                Text(
                  '${_mesesList[_calMonth - 1]} de $_calYear',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMain),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: AppColors.primary),
                  onPressed: _nextCalMonth,
                ),
                TextButton(
                  onPressed: _goToCalToday,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(40, 30),
                  ),
                  child: const Text('Hoje',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Calendar Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                // Weekday Header
                Row(
                  children: _diasSemanaList
                      .map((d) => Expanded(
                            child: Center(
                              child: Text(
                                d,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textHint,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 6),

                if (_loadingCalendar)
                  const SizedBox(
                    height: 190,
                    child: Center(
                        child:
                            CircularProgressIndicator(color: AppColors.primary)),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 1.15,
                    ),
                    itemCount: startDow + lastDay,
                    itemBuilder: (_, i) {
                      if (i < startDow) return const SizedBox();
                      final day = i - startDow + 1;
                      final iso =
                          '$_calYear-${_calMonth.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                      final dayReservations = resByDate[iso] ?? [];

                      final isSelected = iso == _calSelectedDate;
                      final isToday = iso == todayStr;

                      Color textColor = AppColors.textMain;
                      BoxDecoration? boxDec;

                      if (isSelected) {
                        textColor = Colors.white;
                        boxDec = const BoxDecoration(
                          color: AppColors.textMain,
                          shape: BoxShape.circle,
                        );
                      } else if (isToday) {
                        boxDec = BoxDecoration(
                          border: Border.all(color: AppColors.primary, width: 2),
                          shape: BoxShape.circle,
                        );
                      }

                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _calSelectedDate = iso;
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
                                  fontWeight: isSelected || isToday
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: textColor,
                                ),
                              ),
                              if (dayReservations.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: dayReservations.take(3).map((r) {
                                    final area = r['areas_comuns']
                                        as Map<String, dynamic>?;
                                    final areaId = area?['id'] as String? ??
                                        r['area_id'] as String? ??
                                        '';
                                    final dotColor = getAreaColor(areaId);
                                    return Container(
                                      width: 5,
                                      height: 5,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 1),
                                      decoration: BoxDecoration(
                                        color: dotColor,
                                        shape: BoxShape.circle,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                // Compact Legend
                if (areasInMonth.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: areasInMonth.entries.map((e) {
                      final color = getAreaColor(e.key);
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            e.value,
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey.shade700),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Day Reservations Section
          if (_calSelectedDate != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  Text(
                    'Reservas em ${_fmtData(_calSelectedDate)}:',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMain),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${selectedDayReservations.length}',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            if (selectedDayReservations.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Center(
                  child: Text(
                    'Nenhuma reserva para este dia',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  ),
                ),
              )
            else
              ...selectedDayReservations.map((res) {
                final area = res['areas_comuns'] as Map<String, dynamic>?;
                final perfil = res['perfil'] as Map<String, dynamic>?;
                final horario =
                    res['areas_comuns_horarios'] as Map<String, dynamic>?;

                final areaNome = area?['tipo_agenda'] as String? ?? 'Área';
                final areaId = area?['id'] as String? ?? '';
                final areaColor = getAreaColor(areaId);

                final moradorNome =
                    perfil?['nome_completo'] as String? ?? 'Morador';
                final blk = perfil?['bloco_txt'] as String? ?? '';
                final apt = perfil?['apto_txt'] as String? ?? '';
                final unitStr =
                    blk.isNotEmpty && apt.isNotEmpty ? ' ($blk / $apt)' : '';

                final status = res['status'] as String? ?? '';
                final isAppr = status == 'aprovado';
                final isPend = status == 'pendente';

                final time = horario != null && horario['hora_inicio'] != null
                    ? (horario['hora_inicio'] as String).substring(0, 5)
                    : 'Dia inteiro';

                final eventName = res['nome_evento'] as String? ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: areaColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              areaNome,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textMain),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isAppr
                                  ? Colors.green.shade50
                                  : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isAppr ? 'Aprovado' : 'Pendente',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isAppr
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$moradorNome$unitStr',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMain),
                      ),
                      if (eventName.isNotEmpty && eventName != areaNome)
                        Text(
                          'Evento: $eventName',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600),
                        ),
                      Text(
                        'Horário: $time',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      // Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (isPend) ...[
                            TextButton(
                              onPressed: _isUpdatingStatus
                                  ? null
                                  : () => _updateStatus(
                                      res['id'] as String, 'reprovado'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                              ),
                              child: const Text('Reprovar',
                                  style: TextStyle(fontSize: 11)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _isUpdatingStatus
                                  ? null
                                  : () => _updateStatus(
                                      res['id'] as String, 'aprovado'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                minimumSize: Size.zero,
                              ),
                              child: const Text('Aprovar',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                          if (isAppr)
                            OutlinedButton.icon(
                              onPressed: _isUpdatingStatus
                                  ? null
                                  : () => _updateStatus(
                                      res['id'] as String, 'cancelado'),
                              icon: const Icon(Icons.event_busy, size: 13),
                              label: const Text('Cancelar Evento',
                                  style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade600,
                                side: BorderSide(color: Colors.red.shade300),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // VIEW: LIST - PENDENTES
  // ──────────────────────────────────────────────────────────────────────────
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

  // ──────────────────────────────────────────────────────────────────────────
  // VIEW: LIST - HISTÓRICO (Paginado 20 em 20)
  // ──────────────────────────────────────────────────────────────────────────
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

    final showFooter = _hasMoreHistorico ||
        _loadingMoreHistorico ||
        _historico.length >= _pageSize;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _historico.length + (showFooter ? 1 : 0),
        itemBuilder: (_, i) {
          if (i < _historico.length) {
            return _buildHistoricoCard(_historico[i]);
          }

          if (_loadingMoreHistorico) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.primary,
                  ),
                ),
              ),
            );
          }

          if (_hasMoreHistorico) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: OutlinedButton.icon(
                  onPressed: _loadMoreHistorico,
                  icon: const Icon(Icons.expand_more, size: 18),
                  label: const Text(
                    'Carregar mais',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Todos os registros foram carregados.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPendenteCard(Map<String, dynamic> r) {
    final area = r['areas_comuns'] as Map<String, dynamic>?;
    final perfil = r['perfil'] as Map<String, dynamic>?;
    final horario = r['areas_comuns_horarios'] as Map<String, dynamic>?;

    final areaNome = area?['tipo_agenda'] as String? ?? '—';
    final areaId = area?['id'] as String? ?? '';
    final areaColor = getAreaColor(areaId);

    final areaLocal = CommonArea.formatLocalDisplay(
      local: area?['local'] as String?,
      outroLocal: area?['outro_local'] as String?,
    );
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
                    color: areaColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.pending_actions,
                      color: areaColor, size: 22),
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
                      _infoRow(Icons.calendar_today, 'Data',
                          hora != null ? '$data às $hora' : data),
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
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3)),
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
                    onPressed: _isUpdatingStatus
                        ? null
                        : () => _updateStatus(r['id'] as String, 'reprovado'),
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
                    onPressed: _isUpdatingStatus
                        ? null
                        : () => _updateStatus(r['id'] as String, 'aprovado'),
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
    final areaId = area?['id'] as String? ?? '';
    final areaColor = getAreaColor(areaId);

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
    final statusColor =
        isAprovado ? Colors.green : isCancelado ? Colors.grey : Colors.red;
    final statusLabel =
        isAprovado ? 'Aprovado' : isCancelado ? 'Cancelado' : 'Reprovado';

    // Síndico/Admin can cancel any approved reservation regardless of date
    final canCancel = isAprovado;

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
                    color: areaColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                      isAprovado ? Icons.check_circle : Icons.cancel,
                      color: areaColor,
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
                              border: Border.all(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.3)),
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
                  onPressed: _isUpdatingStatus
                      ? null
                      : () => _updateStatus(r['id'] as String, 'cancelado'),
                  icon: const Icon(
                    Icons.event_busy,
                    size: 16,
                  ),
                  label: const Text(
                    'Cancelar Evento',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade600,
                    side: BorderSide(color: Colors.red.shade300),
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

// ──────────────────────────────────────────────────────────────────────────────
// AreaCalendarDialog (Retained and Enhanced with Deterministic Area Colors)
// ──────────────────────────────────────────────────────────────────────────────
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
        _selectedDate =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      }
    } else {
      final now = DateTime.now();
      _viewYear = now.year;
      _viewMonth = now.month;
      _selectedDate =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }
    _loadReservations();
  }

  Future<void> _loadReservations() async {
    setState(() => _loading = true);
    try {
      final firstOfMonth =
          '$_viewYear-${_viewMonth.toString().padLeft(2, '0')}-01';
      final lastDay = DateTime(_viewYear, _viewMonth + 1, 0).day;
      final lastOfMonth =
          '$_viewYear-${_viewMonth.toString().padLeft(2, '0')}-$lastDay';

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

    final selectedDayReservations =
        _selectedDate != null ? (resByDate[_selectedDate] ?? []) : [];
    final areaColor = getAreaColor(widget.areaId);

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
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textHint,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: areaColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              widget.areaNome,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textMain),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close,
                      color: AppColors.primary, size: 22),
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
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMain),
                ),
                const Spacer(),
                IconButton(
                  icon:
                      const Icon(Icons.chevron_right, color: AppColors.primary),
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
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textHint,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 6),

            if (_loading)
              const SizedBox(
                height: 180,
                child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary)),
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
                  final iso =
                      '$_viewYear-${_viewMonth.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
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
                    boxDec = const BoxDecoration(
                      color: AppColors.textMain,
                      shape: BoxShape.circle,
                    );
                  } else if (isFocus) {
                    boxDec = BoxDecoration(
                      border:
                          Border.all(color: Colors.orange.shade400, width: 2),
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
                              fontWeight: isSelected || isFocus
                                  ? FontWeight.bold
                                  : FontWeight.normal,
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
                                    decoration: BoxDecoration(
                                      color: areaColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                if (hasApproved && hasPending)
                                  const SizedBox(width: 2),
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
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textHint),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reservas em ${_fmtDateBr(_selectedDate!)}:',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textMain),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: selectedDayReservations.isEmpty
                              ? Center(
                                  child: Text(
                                    'Nenhuma reserva para este dia',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade400),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: selectedDayReservations.length,
                                  itemBuilder: (_, idx) {
                                    final res = selectedDayReservations[idx];
                                    final p =
                                        res['perfil'] as Map<String, dynamic>?;
                                    final h = res['areas_comuns_horarios']
                                        as Map<String, dynamic>?;
                                    final morador =
                                        p?['nome_completo'] as String? ??
                                            'Morador';
                                    final blk =
                                        p?['bloco_txt'] as String? ?? '';
                                    final apt =
                                        p?['apto_txt'] as String? ?? '';
                                    final unitStr =
                                        blk.isNotEmpty && apt.isNotEmpty
                                            ? ' ($blk/$apt)'
                                            : '';

                                    final status =
                                        res['status'] as String? ?? '';
                                    final isAppr = status == 'aprovado';

                                    final time = h != null &&
                                            h['hora_inicio'] != null
                                        ? (h['hora_inicio'] as String)
                                            .substring(0, 5)
                                        : 'Dia inteiro';

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Colors.grey.shade200),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isAppr
                                                ? Icons.check_circle
                                                : Icons.pending,
                                            color: isAppr
                                                ? Colors.green
                                                : Colors.orange,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
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
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isAppr
                                                  ? Colors.green.shade50
                                                  : Colors.orange.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              isAppr ? 'Aprovado' : 'Pendente',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: isAppr
                                                    ? Colors.green.shade700
                                                    : Colors.orange.shade700,
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
