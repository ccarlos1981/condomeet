import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/shared/utils/structure_labels.dart';



class EnqueteAdminScreen extends StatefulWidget {
  const EnqueteAdminScreen({super.key});

  @override
  State<EnqueteAdminScreen> createState() => _EnqueteAdminScreenState();
}

class _EnqueteAdminScreenState extends State<EnqueteAdminScreen> {
  final _supabase = Supabase.instance.client;

  // ── Data ──────────────────────────────────────────────────
  List<Map<String, dynamic>> _enquetes = [];
  bool _loading = true;
  int _totalUnidades = 0;

  // ── Create form ──────────────────────────────────────────
  final _perguntaCtrl = TextEditingController();
  final _novaOpcaoCtrl = TextEditingController();
  String _tipoResposta = 'unica';
  final List<String> _opcoes = [];
  DateTime? _validade;
  bool _saving = false;

  // ── Expanded responses ───────────────────────────────────
  String? _expandedId;
  List<Map<String, dynamic>> _respostas = [];
  bool _loadingRespostas = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _perguntaCtrl.dispose();
    _novaOpcaoCtrl.dispose();
    super.dispose();
  }

  // ── Load enquetes ────────────────────────────────────────
  Future<void> _loadData() async {
    final condoId = context.read<AuthBloc>().state.condominiumId;
    if (condoId == null) return;

    setState(() => _loading = true);

    try {
      final data = await _supabase
          .from('enquetes')
          .select('''
            id, pergunta, tipo_resposta, ativa, validade, created_at,
            enquete_opcoes(id, texto, ordem),
            enquete_respostas(count)
          ''')
          .eq('condominio_id', condoId)
          .order('created_at', ascending: false);

      // Count unique units
      final units = await _supabase
          .from('perfil')
          .select('bloco_txt, apto_txt')
          .eq('condominio_id', condoId)
          .eq('status_aprovacao', 'aprovado')
          .not('bloco_txt', 'is', null)
          .not('apto_txt', 'is', null);

      final uniqueUnits = <String>{};
      for (final u in (units as List)) {
        uniqueUnits.add('${u['bloco_txt']}-${u['apto_txt']}');
      }

      if (mounted) {
        setState(() {
          _enquetes = List<Map<String, dynamic>>.from(data);
          _totalUnidades = uniqueUnits.length;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Create enquete ───────────────────────────────────────
  Future<void> _handleCreate() async {
    if (_perguntaCtrl.text.trim().isEmpty || _opcoes.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Preencha a pergunta e adicione pelo menos 2 opções.'),
      ));
      return;
    }

    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    final condoId = context.read<AuthBloc>().state.condominiumId ?? '';

    try {
      final res = await _supabase
          .from('enquetes')
          .insert({
            'condominio_id': condoId,
            'pergunta': _perguntaCtrl.text.trim(),
            'tipo_resposta': _tipoResposta,
            'ativa': false,
            'validade': _validade?.toIso8601String().split('T').first,
          })
          .select()
          .single();

      final enqueteId = res['id'];

      // Insert options
      final opcoesData = <Map<String, dynamic>>[];
      for (var i = 0; i < _opcoes.length; i++) {
        opcoesData.add({
          'enquete_id': enqueteId,
          'texto': _opcoes[i],
          'ordem': i + 1,
        });
      }

      await _supabase.from('enquete_opcoes').insert(opcoesData);

      // Reset form
      _perguntaCtrl.clear();
      _novaOpcaoCtrl.clear();
      _opcoes.clear();
      _tipoResposta = 'unica';
      _validade = null;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Enquete criada!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }

      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Toggle active ────────────────────────────────────────
  Future<void> _toggleAtiva(Map<String, dynamic> enquete) async {
    final newAtiva = !(enquete['ativa'] as bool);
    setState(() {
      enquete['ativa'] = newAtiva;
    });
    await _supabase
        .from('enquetes')
        .update({'ativa': newAtiva})
        .eq('id', enquete['id']);

    // Push notification para todos ao ATIVAR
    if (newAtiva) {
      final condoId = context.read<AuthBloc>().state.condominiumId ?? '';
      try {
        await _supabase.functions.invoke('enquete-push-notify', body: {
          'condominio_id': condoId,
          'enquete_id': enquete['id'],
          'pergunta': enquete['pergunta'] ?? 'Nova enquete disponível',
        });
      } catch (e) {
        debugPrint('Push enquete error: $e');
      }
    }
  }

  // ── Delete ───────────────────────────────────────────────
  Future<void> _handleDelete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir enquete?'),
        content: const Text('Todas as respostas serão perdidas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _enquetes.removeWhere((e) => e['id'] == id));
    await _supabase.from('enquetes').delete().eq('id', id);
  }

  // ── Show chart ───────────────────────────────────────────
  Future<void> _showChart(Map<String, dynamic> enquete) async {
    final opcoes = (enquete['enquete_opcoes'] as List?) ?? [];
    final data = await _supabase
        .from('enquete_respostas')
        .select('opcao_id')
        .eq('enquete_id', enquete['id']);

    final counts = <String, int>{};
    for (final r in (data as List)) {
      final key = r['opcao_id'] as String;
      counts[key] = (counts[key] ?? 0) + 1;
    }

    final chartItems = opcoes.map<Map<String, dynamic>>((o) {
      return {'texto': o['texto'], 'count': counts[o['id']] ?? 0};
    }).toList();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => _ChartDialog(
        pergunta: enquete['pergunta'] ?? '',
        items: chartItems,
      ),
    );
  }

  // ── Load responses ───────────────────────────────────────
  Future<void> _loadRespostas(Map<String, dynamic> enquete) async {
    final eid = enquete['id'] as String;
    if (_expandedId == eid) {
      setState(() => _expandedId = null);
      return;
    }
    setState(() {
      _expandedId = eid;
      _loadingRespostas = true;
    });

    final data = await _supabase
        .from('enquete_respostas')
        .select('created_at, bloco, apto, opcao_id, perfil:user_id(nome_completo)')
        .eq('enquete_id', eid)
        .order('created_at', ascending: false);

    final opcoes = (enquete['enquete_opcoes'] as List?) ?? [];
    final opcaoMap = <String, String>{};
    for (final o in opcoes) {
      opcaoMap[o['id'] as String] = o['texto'] as String;
    }

    if (mounted) {
      setState(() {
        _respostas = (data as List).map<Map<String, dynamic>>((r) {
          final perfil = r['perfil'];
          return {
            'nome': perfil is Map ? perfil['nome_completo'] ?? '' : '',
            'data': _fmtDate(r['created_at'] ?? ''),
            'bloco': r['bloco'] ?? '',
            'apto': r['apto'] ?? '',
            'resultado': opcaoMap[r['opcao_id']] ?? '',
          };
        }).toList();
        _loadingRespostas = false;
      });
    }
  }

  String _fmtDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  int _pct(Map<String, dynamic> enquete) {
    if (_totalUnidades == 0) return 0;
    final cnt = (enquete['enquete_respostas'] as List?)?.isNotEmpty == true
        ? ((enquete['enquete_respostas'] as List)[0] as Map)['count'] as int? ?? 0
        : 0;
    return (cnt / _totalUnidades * 100).round();
  }

  // ════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('📊 Enquetes'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildCreateForm(),
                  const SizedBox(height: 24),
                  ..._enquetes.map(_buildEnqueteCard),
                  if (_enquetes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Column(children: [
                        Icon(Icons.bar_chart_outlined, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        Text('Nenhuma enquete cadastrada.',
                            style: TextStyle(color: AppColors.textSecondary)),
                      ]),
                    ),
                ],
              ),
            ),
    );
  }

  // ── Create form ──────────────────────────────────────────
  Widget _buildCreateForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Criar Nova Enquete',
            style: AppTypography.h2.copyWith(fontSize: 16)),
        const SizedBox(height: 16),

        // Pergunta
        TextFormField(
          controller: _perguntaCtrl,
          decoration: InputDecoration(
            labelText: 'Pergunta da Enquete',
            hintText: 'Ex: Qual cor preferem para o hall?',
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border)),
          ),
        ),
        const SizedBox(height: 16),

        // Tipo
        Text('Tipo de Resposta', style: AppTypography.label),
        const SizedBox(height: 8),
        Row(children: [
          _buildRadio('unica', '🔘 Única'),
          const SizedBox(width: 16),
          _buildRadio('multipla', '☑️ Múltipla'),
        ]),
        const SizedBox(height: 16),

        // Opções
        Text('Respostas (mínimo 2)', style: AppTypography.label),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextFormField(
              controller: _novaOpcaoCtrl,
              decoration: InputDecoration(
                hintText: 'Acrescente sua resposta aqui',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onFieldSubmitted: (_) => _addOpcao(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _addOpcao,
            icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 32),
          ),
        ]),
        const SizedBox(height: 8),
        ..._opcoes.asMap().entries.map((e) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Expanded(
                    child: Text('Resposta: ${e.value}',
                        style: const TextStyle(fontSize: 14))),
                GestureDetector(
                  onTap: () => setState(() => _opcoes.removeAt(e.key)),
                  child: const Icon(Icons.close, size: 18, color: Colors.red),
                ),
              ]),
            )),
        const SizedBox(height: 12),

        // Validade
        Text('Validade da Enquete', style: AppTypography.label),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now().add(const Duration(days: 7)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) setState(() => _validade = picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              const Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                _validade != null
                    ? '${_validade!.day.toString().padLeft(2, '0')}/${_validade!.month.toString().padLeft(2, '0')}/${_validade!.year}'
                    : 'Selecionar data',
                style: TextStyle(
                    color: _validade != null
                        ? AppColors.textMain
                        : AppColors.textSecondary),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 20),

        // Submit
        _saving
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : CondoButton(
                label: 'Inserir Enquete',
                onPressed:
                    _perguntaCtrl.text.trim().isNotEmpty && _opcoes.length >= 2
                        ? _handleCreate
                        : null,
              ),
      ]),
    );
  }

  Widget _buildRadio(String value, String label) {
    final selected = _tipoResposta == value;
    return GestureDetector(
      onTap: () => setState(() => _tipoResposta = value),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
          size: 20,
          color: selected ? AppColors.primary : AppColors.textSecondary,
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 14, color: AppColors.textMain)),
      ]),
    );
  }

  void _addOpcao() {
    final text = _novaOpcaoCtrl.text.trim();
    if (text.isEmpty || _opcoes.contains(text)) return;
    setState(() {
      _opcoes.add(text);
      _novaOpcaoCtrl.clear();
    });
  }

  // ── Enquete card ─────────────────────────────────────────
  Widget _buildEnqueteCard(Map<String, dynamic> enquete) {
    final id = enquete['id'] as String;
    final pergunta = enquete['pergunta'] ?? '';
    final tipo = enquete['tipo_resposta'] ?? 'unica';
    final ativa = enquete['ativa'] as bool? ?? false;
    final opcoes = (enquete['enquete_opcoes'] as List?) ?? [];
    final pctVal = _pct(enquete);
    final isExpanded = _expandedId == id;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        // Status bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(children: [
            Text('Status: ', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: pctVal / 100,
                  minHeight: 16,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('$pctVal%',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ]),
        ),

        // Info
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Pergunta: $pergunta',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: ativa ? Colors.green.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ativa ? 'Ativa' : 'Inativa',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: ativa ? Colors.green : Colors.grey,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Tipo: ${tipo == 'unica' ? 'Única' : 'Múltipla'}',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ]),
            const SizedBox(height: 8),
            ...opcoes.map<Widget>((o) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('  • ${o['texto']}',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                )),
            if (enquete['validade'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Validade: ${_fmtDate(enquete['validade'])}',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ),
          ]),
        ),

        // Action buttons
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            _actionBtn(
              icon: ativa ? Icons.toggle_on : Icons.toggle_off,
              color: ativa ? Colors.green : Colors.grey,
              tooltip: ativa ? 'Desativar' : 'Ativar',
              onTap: () => _toggleAtiva(enquete),
            ),
            _actionBtn(
              icon: Icons.bar_chart_rounded,
              color: Colors.blue,
              tooltip: 'Gráfico',
              onTap: () => _showChart(enquete),
            ),
            _actionBtn(
              icon: Icons.delete_outline,
              color: Colors.red,
              tooltip: 'Excluir',
              onTap: () => _handleDelete(id),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _loadRespostas(enquete),
              icon: Icon(
                isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                size: 18,
              ),
              label: Text(isExpanded ? 'Ocultar' : 'Respostas',
                  style: const TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ]),
        ),

        // Expanded responses
        if (isExpanded)
          _loadingRespostas
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary)))
              : _respostas.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Nenhuma resposta ainda.',
                          style: TextStyle(color: AppColors.textSecondary)),
                    )
                  : Column(
                      children: [
                        const Divider(height: 1),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowHeight: 36,
                            dataRowMinHeight: 32,
                            dataRowMaxHeight: 40,
                            columnSpacing: 16,
                            columns: [
                              const DataColumn(label: Text('Nome', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              const DataColumn(label: Text('Data', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text(getBlocoLabel(context.read<AuthBloc>().state.tipoEstrutura), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataColumn(label: Text(getAptoLabel(context.read<AuthBloc>().state.tipoEstrutura), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              const DataColumn(label: Text('Resposta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            ],
                            rows: _respostas.map((r) => DataRow(cells: [
                              DataCell(Text(r['nome'] ?? '', style: const TextStyle(fontSize: 12))),
                              DataCell(Text(r['data'] ?? '', style: const TextStyle(fontSize: 12))),
                              DataCell(Text(r['bloco'] ?? '', style: const TextStyle(fontSize: 12))),
                              DataCell(Text(r['apto'] ?? '', style: const TextStyle(fontSize: 12))),
                              DataCell(Text(r['resultado'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                            ])).toList(),
                          ),
                        ),
                      ],
                    ),
      ]),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Chart Dialog
// ═══════════════════════════════════════════════════════════════

class _ChartDialog extends StatelessWidget {
  final String pergunta;
  final List<Map<String, dynamic>> items;
  const _ChartDialog({required this.pergunta, required this.items});

  @override
  Widget build(BuildContext context) {
    final total = items.fold<int>(0, (s, i) => s + (i['count'] as int));
    final colors = [
      AppColors.primary,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.pink,
    ];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('📊 Resultado', style: AppTypography.h2),
          const SizedBox(height: 4),
          Text(pergunta,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ...items.asMap().entries.map((e) {
            final i = e.key;
            final item = e.value;
            final count = item['count'] as int;
            final pctVal = total > 0 ? (count / total * 100).round() : 0;
            final color = colors[i % colors.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(item['texto'] ?? '',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          Text('$count votos ($pctVal%)',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ]),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: total > 0 ? count / total : 0,
                        minHeight: 14,
                        backgroundColor: Colors.grey.shade100,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ]),
            );
          }),
          const SizedBox(height: 8),
          Text('Total: $total votos',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ]),
      ),
    );
  }
}
