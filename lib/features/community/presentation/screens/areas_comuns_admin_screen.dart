import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/core/di/injection_container.dart';

class AreasComunsAdminScreen extends StatefulWidget {
  const AreasComunsAdminScreen({super.key});

  @override
  State<AreasComunsAdminScreen> createState() => _AreasComunsAdminScreenState();
}

class _AreasComunsAdminScreenState extends State<AreasComunsAdminScreen> {
  final _supabase = sl<SupabaseClient>();
  List<Map<String, dynamic>> _areas = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final profile = await _supabase
        .from('perfil')
        .select('condominio_id')
        .eq('id', user.id)
        .maybeSingle();

    final condoId = profile?['condominio_id'] as String?;
    if (condoId == null) { setState(() => _loading = false); return; }

    final data = await _supabase
        .from('areas_comuns')
        .select('*')
        .eq('condominio_id', condoId)
        .order('tipo_agenda');

    setState(() {
      _areas = List<Map<String, dynamic>>.from(data as List);
      _loading = false;
    });
  }

  Future<void> _toggleAtivo(Map<String, dynamic> area) async {
    HapticFeedback.selectionClick();
    final newVal = !(area['ativo'] == true || area['ativo'] == 1);
    await _supabase
        .from('areas_comuns')
        .update({'ativo': newVal})
        .eq('id', area['id'] as String);
    _load();
  }

  Future<void> _delete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: const Text('Deseja excluir esta área comum?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _supabase.from('areas_comuns').delete().eq('id', id);
    _load();
  }

  Future<void> _toggleAprovacao(Map<String, dynamic> area) async {
    HapticFeedback.selectionClick();
    final cur = area['aprovacao_automatica'] == true || area['aprovacao_automatica'] == 1;
    await _supabase
        .from('areas_comuns')
        .update({'aprovacao_automatica': !cur})
        .eq('id', area['id'] as String);
    _load();
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
          'Áreas Comuns',
          style: TextStyle(color: Color(0xFF1A1A1A), fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 20),
            onPressed: () { setState(() => _loading = true); _load(); },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: _areas.isEmpty
                  ? ListView(children: [
                      const SizedBox(height: 80),
                      const Icon(Icons.location_city, size: 56, color: Color(0xFFCCCCCC)),
                      const SizedBox(height: 16),
                      const Text(
                        'Nenhuma área comum cadastrada.\nCadastre pelo painel web.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
                      ),
                    ])
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _areas.length,
                      itemBuilder: (context, i) => _buildCard(_areas[i]),
                    ),
            ),
    );
  }

  Widget _buildCard(Map<String, dynamic> area) {
    final isAtivo = area['ativo'] == true || area['ativo'] == 1;
    final isAutoAprov = area['aprovacao_automatica'] == true || area['aprovacao_automatica'] == 1;
    final tipo = area['tipo_agenda'] as String? ?? '—';
    final local = area['local'] as String? ?? '';
    final cap = area['capacidade']?.toString() ?? '0';
    final tipoReserva = area['tipo_reserva'] as String? ?? 'por_dia';
    final isPorHora = tipoReserva == 'por_hora';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isAtivo ? Colors.white : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isAtivo ? const Color(0xFFEEEEEE) : const Color(0xFFDDDDDD)),
        boxShadow: isAtivo ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)] : [],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: isAtivo ? 0.12 : 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_iconFor(tipo), color: isAtivo ? AppColors.primary : Colors.grey.shade400, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tipo, style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14,
                        color: isAtivo ? const Color(0xFF1A1A1A) : Colors.grey.shade500,
                      )),
                      const SizedBox(height: 2),
                      Row(children: [
                        Text(local, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: isPorHora ? Colors.blue.shade50 : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isPorHora ? 'Por Hora' : 'Por Dia',
                            style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w600,
                              color: isPorHora ? Colors.blue.shade700 : Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
                Column(children: [
                  Text('Cap.', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                  Text(cap, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ]),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Actions row 1: Ativo + Aprovação automática
            Row(
              children: [
                // Ativo toggle
                GestureDetector(
                  onTap: () => _toggleAtivo(area),
                  child: Row(children: [
                    Icon(isAtivo ? Icons.toggle_on : Icons.toggle_off,
                      color: isAtivo ? Colors.green : Colors.grey.shade400, size: 28),
                    const SizedBox(width: 3),
                    Text(isAtivo ? 'Ativo' : 'Inativo',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: isAtivo ? Colors.green : Colors.grey.shade400)),
                  ]),
                ),
                const SizedBox(width: 16),
                // Aprovação automática toggle
                GestureDetector(
                  onTap: () => _toggleAprovacao(area),
                  child: Row(children: [
                    Icon(isAutoAprov ? Icons.check_circle : Icons.cancel_outlined,
                      color: isAutoAprov ? Colors.green.shade600 : Colors.grey.shade400, size: 18),
                    const SizedBox(width: 3),
                    Text(isAutoAprov ? 'Aprov. Auto' : 'Aprov. Manual',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: isAutoAprov ? Colors.green.shade600 : Colors.grey.shade400)),
                  ]),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Actions row 2: Horários (por_hora only) + Apagar
            Row(
              children: [
                if (isPorHora) ...[  
                  GestureDetector(
                    onTap: () => Navigator.of(context).pushNamed(
                      '/admin-horarios',
                      arguments: {'areaId': area['id'], 'tipo': tipo},
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Icon(Icons.schedule, size: 14, color: Colors.blue.shade600),
                        const SizedBox(width: 4),
                        Text('Horários', style: TextStyle(fontSize: 11, color: Colors.blue.shade600, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                const Spacer(),
                // Apagar
                GestureDetector(
                  onTap: () => _delete(area['id'] as String),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      Icon(Icons.delete_outline, size: 14, color: Colors.red.shade400),
                      const SizedBox(width: 4),
                      Text('Apagar', style: TextStyle(fontSize: 11, color: Colors.red.shade400, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
