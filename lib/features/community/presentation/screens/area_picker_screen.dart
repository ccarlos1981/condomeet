import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/core/di/injection_container.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/features/community/presentation/screens/areas_comuns_admin_screen.dart';
import 'package:condomeet/features/community/presentation/screens/booking_form_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Simple resident-facing area picker — no PowerSync dependency
class AreaPickerScreen extends StatefulWidget {
  const AreaPickerScreen({super.key});

  @override
  State<AreaPickerScreen> createState() => _AreaPickerScreenState();
}

class _AreaPickerScreenState extends State<AreaPickerScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = sl<SupabaseClient>();
  List<Map<String, dynamic>> _areas = [];
  List<Map<String, dynamic>> _reservas = [];
  bool _loading = true;
  bool _loadingReservas = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final authState = context.read<AuthBloc>().state;

    // Route admins/síndicos to the management screen
    final role = (authState.role ?? '').toLowerCase();
    final isAdmin = role.contains('admin') || role.contains('sindico') ||
        role.contains('síndico') || role.contains('portaria') ||
        role.contains('zelador') || role.contains('funcionário');

    if (isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AreasComunsAdminScreen()),
        );
      });
      return;
    }

    _load();
    _loadReservas();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = _supabase.auth.currentUser;
    if (user == null) { setState(() => _loading = false); return; }

    final profile = await _supabase
        .from('perfil')
        .select('condominio_id')
        .eq('id', user.id)
        .maybeSingle();

    final condoId = profile?['condominio_id'] as String?;
    if (condoId == null) { setState(() => _loading = false); return; }

    final data = await _supabase
        .from('areas_comuns')
        .select('id, tipo_agenda, local, outro_local, tipo_reserva, capacidade, hrs_cancelar, instrucao_uso, precos, aprovacao_automatica')
        .eq('condominio_id', condoId)
        .eq('ativo', true)
        .order('tipo_agenda');

    setState(() {
      _areas = List<Map<String, dynamic>>.from(data as List);
      _loading = false;
    });
  }

  Future<void> _loadReservas() async {
    setState(() => _loadingReservas = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) { setState(() => _loadingReservas = false); return; }

      final data = await _supabase
          .from('reservas')
          .select('id, data_reserva, status, nome_evento, areas_comuns(tipo_agenda), areas_comuns_horarios(hora_inicio)')
          .eq('user_id', user.id)
          .order('data_reserva', ascending: false)
          .limit(50);

      setState(() {
        _reservas = List<Map<String, dynamic>>.from(data as List);
        _loadingReservas = false;
      });
    } catch (e) {
      setState(() => _loadingReservas = false);
    }
  }

  IconData _iconFor(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'salão de festa': return Icons.celebration;
      case 'churrasqueira': return Icons.outdoor_grill;
      case 'piscina': return Icons.pool;
      case 'academia': return Icons.fitness_center;
      case 'sauna': return Icons.hot_tub;
      case 'quadra de tênis': case 'campo de futebol': return Icons.sports;
      default: return Icons.location_on;
    }
  }

  String _labelTipo(String tipo) => tipo == 'por_hora' ? 'Por Hora' : 'Por Dia';

  String _fmtData(String d) {
    final dt = DateTime.tryParse('$d 12:00:00');
    if (dt == null) return d;
    return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Reservar Espaço',
          style: TextStyle(color: Color(0xFF1A1A1A), fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 20),
            onPressed: () {
              setState(() { _loading = true; _loadingReservas = true; });
              _load();
              _loadReservas();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: const Color(0xFF999999),
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Disponíveis'),
            Tab(text: 'Meus Agendamentos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDisponiveis(),
          _buildMeusAgendamentos(),
        ],
      ),
    );
  }

  Widget _buildDisponiveis() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: _areas.isEmpty
          ? ListView(children: const [
              SizedBox(height: 80),
              Icon(Icons.event_available, size: 56, color: Color(0xFFCCCCCC)),
              SizedBox(height: 16),
              Text(
                'Nenhuma área disponível para reserva.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
              ),
            ])
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _areas.length,
              itemBuilder: (context, i) => _buildCard(_areas[i]),
            ),
    );
  }

  Widget _buildMeusAgendamentos() {
    if (_loadingReservas) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_reservas.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Você ainda não tem agendamentos.',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadReservas,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _reservas.length,
        itemBuilder: (_, i) => _buildReservaCard(_reservas[i]),
      ),
    );
  }

  Widget _buildReservaCard(Map<String, dynamic> r) {
    final area = r['areas_comuns'] as Map<String, dynamic>?;
    final horario = r['areas_comuns_horarios'] as Map<String, dynamic>?;
    final nome = area?['tipo_agenda'] as String? ?? r['nome_evento'] as String? ?? '—';
    final data = _fmtData(r['data_reserva'] as String? ?? '');
    final hora = horario != null
        ? (horario['hora_inicio'] as String?)?.substring(0, 5) ?? 'Dia inteiro'
        : 'Dia inteiro';
    final status = r['status'] as String? ?? 'pendente';

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'aprovado': statusColor = Colors.green; statusLabel = 'Aprovado'; break;
      case 'pendente': statusColor = Colors.orange; statusLabel = 'Pendente'; break;
      case 'reprovado': statusColor = Colors.red; statusLabel = 'Reprovado'; break;
      case 'cancelado': statusColor = Colors.grey; statusLabel = 'Cancelado'; break;
      default: statusColor = Colors.grey; statusLabel = status;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.event, color: statusColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A1A1A))),
              const SizedBox(height: 2),
              Text('$data  •  $hora', style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
            ],
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(statusLabel,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
          ),
        ]),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> area) {
    final tipo = area['tipo_agenda'] as String? ?? '—';
    final local = area['local'] as String? ?? '';
    final cap = area['capacidade']?.toString() ?? '0';
    final hrs = area['hrs_cancelar']?.toString() ?? '0';
    final tipoReserva = area['tipo_reserva'] as String? ?? 'por_dia';

    String preco = 'Gratuito';
    try {
      final precos = (area['precos'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final p = precos.firstWhere((p) => (p['valor'] as num? ?? 0) > 0, orElse: () => {});
      if (p.isNotEmpty) {
        final v = (p['valor'] as num).toDouble();
        preco = 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
      }
    } catch (_) {}

    return GestureDetector(
      onTap: () => HapticFeedback.lightImpact(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEEEEEE)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_iconFor(tipo), color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tipo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A1A1A))),
                    const SizedBox(height: 2),
                    Row(children: [
                      Text(local, style: const TextStyle(fontSize: 11, color: Color(0xFF999999))),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: tipoReserva == 'por_hora' ? Colors.blue.shade50 : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _labelTipo(tipoReserva),
                          style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w600,
                            color: tipoReserva == 'por_hora' ? Colors.blue.shade700 : Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ]),
                  ],
                )),
              ]),

              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),

              Row(children: [
                _stat(Icons.group, 'Capacidade', '$cap pessoas'),
                const SizedBox(width: 20),
                _stat(Icons.attach_money, 'Taxa', preco),
                const SizedBox(width: 20),
                _stat(Icons.timer_outlined, 'Cancelar', '${hrs}h antes'),
              ]),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => BookingFormScreen(area: area),
                      ),
                    );
                    if (result == true && mounted) {
                      final aprovAuto = area['aprovacao_automatica'] == true;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(aprovAuto
                          ? 'Reserva aprovada automaticamente! ✅'
                          : 'Reserva enviada! Aguardando aprovação do síndico.'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.green.shade700,
                      ));
                      // Refresh meus agendamentos and switch to that tab
                      await _loadReservas();
                      if (mounted) _tabController.animateTo(1);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: const Text('Reservar', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 12, color: const Color(0xFFAAAAAA)),
          const SizedBox(width: 3),
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFFAAAAAA))),
        ]),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
      ],
    );
  }
}
