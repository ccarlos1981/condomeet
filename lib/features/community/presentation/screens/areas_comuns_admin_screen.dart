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

  Future<void> _showEditForm(Map<String, dynamic> area) async {
    final tipoCtrl = TextEditingController(text: area['tipo_agenda'] as String? ?? '');
    final localCtrl = TextEditingController(text: area['local'] as String? ?? '');
    final capacidadeCtrl = TextEditingController(text: (area['capacidade'] ?? 0).toString());
    final limiteCtrl = TextEditingController(text: (area['limite_acesso'] ?? 1).toString());
    final hrsCancelarCtrl = TextEditingController(text: (area['hrs_cancelar'] ?? 24).toString());
    // Extract taxa from precos array
    final precos = area['precos'];
    double taxaAtual = 0;
    if (precos is List && precos.isNotEmpty) {
      taxaAtual = (precos[0]['valor'] as num?)?.toDouble() ?? 0;
    }
    final taxaCtrl = TextEditingController(text: taxaAtual > 0 ? taxaAtual.toString() : '0');
    String tipoReserva = area['tipo_reserva'] as String? ?? 'por_dia';
    bool aprovAuto = area['aprovacao_automatica'] == true || area['aprovacao_automatica'] == 1;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text(
                    'Editar Área Comum',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
                  ),
                  const SizedBox(height: 16),

                  // Tipo (nome)
                  TextField(
                    controller: tipoCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nome da Área *',
                      hintText: 'Ex: Salão de Festa, Churrasqueira...',
                      prefixIcon: const Icon(Icons.celebration, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Local
                  TextField(
                    controller: localCtrl,
                    decoration: InputDecoration(
                      labelText: 'Localização',
                      hintText: 'Ex: Bloco A, Térreo...',
                      prefixIcon: const Icon(Icons.location_on, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tipo Reserva
                  Row(
                    children: [
                      const Text('Tipo de Reserva:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      ChoiceChip(
                        label: const Text('Por Dia'),
                        selected: tipoReserva == 'por_dia',
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        onSelected: (_) => setSheetState(() => tipoReserva = 'por_dia'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Por Hora'),
                        selected: tipoReserva == 'por_hora',
                        selectedColor: Colors.blue.withValues(alpha: 0.2),
                        onSelected: (_) => setSheetState(() => tipoReserva = 'por_hora'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Capacidade + Limite + Hrs cancelar
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: capacidadeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Capacidade',
                            prefixIcon: const Icon(Icons.people, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: limiteCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Limite/Dia',
                            prefixIcon: const Icon(Icons.event_repeat, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: hrsCancelarCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Hrs Cancelar',
                            prefixIcon: const Icon(Icons.timer, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Taxa
                  TextField(
                    controller: taxaCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Taxa (R\$)',
                      hintText: '0 = sem taxa',
                      prefixIcon: const Icon(Icons.attach_money, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Aprovação automática toggle
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Aprovação automática', style: TextStyle(fontSize: 14)),
                    subtitle: Text(
                      aprovAuto
                          ? 'Reservas serão aprovadas automaticamente'
                          : 'Síndico precisa aprovar cada reserva',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    value: aprovAuto,
                    activeThumbColor: AppColors.primary,
                    onChanged: (v) => setSheetState(() => aprovAuto = v),
                  ),
                  const SizedBox(height: 16),

                  // Botão Salvar
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final nome = tipoCtrl.text.trim();
                        if (nome.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Informe o nome da área'), backgroundColor: Colors.orange),
                          );
                          return;
                        }

                        final taxa = double.tryParse(taxaCtrl.text.replaceAll(',', '.')) ?? 0;
                        final novosPrecos = taxa > 0
                            ? [{'perfil': 'morador', 'valor': taxa}]
                            : <Map<String, dynamic>>[];

                        try {
                          await _supabase.from('areas_comuns').update({
                            'tipo_agenda': nome,
                            'local': localCtrl.text.trim().isEmpty ? 'Espaço comum' : localCtrl.text.trim(),
                            'tipo_reserva': tipoReserva,
                            'capacidade': int.tryParse(capacidadeCtrl.text) ?? 0,
                            'limite_acesso': int.tryParse(limiteCtrl.text) ?? 1,
                            'hrs_cancelar': int.tryParse(hrsCancelarCtrl.text) ?? 24,
                            'precos': novosPrecos,
                            'aprovacao_automatica': aprovAuto,
                          }).eq('id', area['id'] as String);
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.save_outlined, size: 20),
                      label: const Text('Salvar Alterações', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (result == true) {
      setState(() => _loading = true);
      _load();
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

  Future<void> _showCreateForm() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final profile = await _supabase
        .from('perfil')
        .select('condominio_id')
        .eq('id', user.id)
        .maybeSingle();
    final condoId = profile?['condominio_id'] as String?;
    if (condoId == null) return;

    final tipoCtrl = TextEditingController();
    final localCtrl = TextEditingController(text: 'Bloco A');
    final capacidadeCtrl = TextEditingController(text: '10');
    final limiteCtrl = TextEditingController(text: '1');
    final hrsCancelarCtrl = TextEditingController(text: '48');
    final taxaCtrl = TextEditingController(text: '0');
    String tipoReserva = 'por_dia';
    bool aprovAuto = false;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text(
                    'Nova Área Comum',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
                  ),
                  const SizedBox(height: 16),

                  // Tipo (nome)
                  TextField(
                    controller: tipoCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nome da Área *',
                      hintText: 'Ex: Salão de Festa, Churrasqueira...',
                      prefixIcon: const Icon(Icons.celebration, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Local
                  TextField(
                    controller: localCtrl,
                    decoration: InputDecoration(
                      labelText: 'Localização',
                      hintText: 'Ex: Bloco A, Térreo...',
                      prefixIcon: const Icon(Icons.location_on, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tipo Reserva
                  Row(
                    children: [
                      const Text('Tipo de Reserva:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      ChoiceChip(
                        label: const Text('Por Dia'),
                        selected: tipoReserva == 'por_dia',
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        onSelected: (_) => setSheetState(() => tipoReserva = 'por_dia'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Por Hora'),
                        selected: tipoReserva == 'por_hora',
                        selectedColor: Colors.blue.withValues(alpha: 0.2),
                        onSelected: (_) => setSheetState(() => tipoReserva = 'por_hora'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Capacidade + Limite + Hrs cancelar
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: capacidadeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Capacidade',
                            prefixIcon: const Icon(Icons.people, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: limiteCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Limite/Dia',
                            prefixIcon: const Icon(Icons.event_repeat, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: hrsCancelarCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Hrs Cancelar',
                            prefixIcon: const Icon(Icons.timer, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Taxa
                  TextField(
                    controller: taxaCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Taxa (R\$)',
                      hintText: '0 = sem taxa',
                      prefixIcon: const Icon(Icons.attach_money, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Aprovação automática toggle
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Aprovação automática', style: TextStyle(fontSize: 14)),
                    subtitle: Text(
                      aprovAuto
                          ? 'Reservas serão aprovadas automaticamente'
                          : 'Síndico precisa aprovar cada reserva',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    value: aprovAuto,
                    activeThumbColor: AppColors.primary,
                    onChanged: (v) => setSheetState(() => aprovAuto = v),
                  ),
                  const SizedBox(height: 16),

                  // Botão Criar
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final nome = tipoCtrl.text.trim();
                        if (nome.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Informe o nome da área'), backgroundColor: Colors.orange),
                          );
                          return;
                        }

                        final taxa = double.tryParse(taxaCtrl.text.replaceAll(',', '.')) ?? 0;
                        final precos = taxa > 0
                            ? [{'perfil': 'morador', 'valor': taxa}]
                            : <Map<String, dynamic>>[];

                        try {
                          await _supabase.from('areas_comuns').insert({
                            'condominio_id': condoId,
                            'tipo_agenda': nome,
                            'local': localCtrl.text.trim().isEmpty ? 'Espaço comum' : localCtrl.text.trim(),
                            'tipo_reserva': tipoReserva,
                            'capacidade': int.tryParse(capacidadeCtrl.text) ?? 0,
                            'limite_acesso': int.tryParse(limiteCtrl.text) ?? 1,
                            'hrs_cancelar': int.tryParse(hrsCancelarCtrl.text) ?? 24,
                            'precos': precos,
                            'aprovacao_automatica': aprovAuto,
                            'ativo': true,
                          });
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      label: const Text('Criar Área Comum', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (result == true) {
      setState(() => _loading = true);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Áreas Comuns',
          style: TextStyle(color: AppColors.textMain, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 20),
            onPressed: () { setState(() => _loading = true); _load(); },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateForm,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: _areas.isEmpty
                  ? ListView(children: [
                      const SizedBox(height: 80),
                      const Icon(Icons.location_city, size: 56, color: AppColors.disabledIcon),
                      const SizedBox(height: 16),
                      const Text(
                        'Nenhuma área comum cadastrada.\nToque no + para criar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textHint, fontSize: 14),
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
        color: isAtivo ? Colors.white : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isAtivo ? AppColors.border : AppColors.surfaceAlt),
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
                        color: isAtivo ? AppColors.textMain : AppColors.textSecondary,
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

            // Actions row 2: Editar + Horários (por_hora only) + Apagar
            Row(
              children: [
                // Editar
                GestureDetector(
                  onTap: () => _showEditForm(area),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 14, color: Colors.orange.shade700),
                      const SizedBox(width: 4),
                      Text('Editar', style: TextStyle(fontSize: 11, color: Colors.orange.shade700, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
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
