import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';

class EnqueteVotingScreen extends StatefulWidget {
  const EnqueteVotingScreen({super.key});

  @override
  State<EnqueteVotingScreen> createState() => _EnqueteVotingScreenState();
}

class _EnqueteVotingScreenState extends State<EnqueteVotingScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _enquetes = [];
  bool _loading = true;
  String _bloco = '';
  String _apto = '';
  String _userId = '';

  // Responses per unit (bloco+apto)
  List<Map<String, dynamic>> _unitRespostas = [];
  // All responses for chart
  List<Map<String, dynamic>> _allRespostas = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ── Load ──────────────────────────────────────────────────
  Future<void> _loadData() async {
    final authState = context.read<AuthBloc>().state;
    final condoId = authState.condominiumId;
    _userId = authState.userId ?? '';
    if (condoId == null) return;

    setState(() => _loading = true);

    try {
      // Get profile
      final profile = await _supabase
          .from('perfil')
          .select('bloco_txt, apto_txt')
          .eq('id', _userId)
          .single();
      _bloco = profile['bloco_txt'] ?? '';
      _apto = profile['apto_txt'] ?? '';

      // Active enquetes
      final data = await _supabase
          .from('enquetes')
          .select('id, pergunta, tipo_resposta, validade, created_at, enquete_opcoes(id, texto, ordem)')
          .eq('condominio_id', condoId)
          .eq('ativa', true)
          .order('created_at', ascending: false);

      // Unit responses
      final unitResp = await _supabase
          .from('enquete_respostas')
          .select('enquete_id, opcao_id, created_at')
          .eq('bloco', _bloco)
          .eq('apto', _apto);

      // All responses for chart
      final allResp = await _supabase
          .from('enquete_respostas')
          .select('enquete_id, opcao_id');

      if (mounted) {
        setState(() {
          _enquetes = List<Map<String, dynamic>>.from(data);
          _unitRespostas = List<Map<String, dynamic>>.from(unitResp);
          _allRespostas = List<Map<String, dynamic>>.from(allResp);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────
  bool _isExpired(Map<String, dynamic> e) {
    final val = e['validade'];
    if (val == null) return false;
    try {
      return DateTime.parse(val.toString()).isBefore(
        DateTime.now().copyWith(hour: 0, minute: 0, second: 0),
      );
    } catch (_) {
      return false;
    }
  }

  List<String> _unitVotedFor(String enqueteId) {
    return _unitRespostas
        .where((r) => r['enquete_id'] == enqueteId)
        .map((r) => r['opcao_id'] as String)
        .toList();
  }

  bool _hasUnitVoted(String enqueteId) {
    return _unitRespostas.any((r) => r['enquete_id'] == enqueteId);
  }

  String _fmtDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  // ── Open voting bottom sheet ──────────────────────────────
  void _openVoting(Map<String, dynamic> enquete) {
    final voted = _unitVotedFor(enquete['id'] as String);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VotingSheet(
        enquete: enquete,
        initialVoted: voted,
        allRespostas: _allRespostas,
        isExpired: _isExpired(enquete),
        bloco: _bloco,
        apto: _apto,
        userId: _userId,
        onVoted: () => _loadData(),
      ),
    );
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
              child: _enquetes.isEmpty
                  ? ListView(children: [
                      const SizedBox(height: 100),
                      Icon(Icons.bar_chart_outlined, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      Text('Nenhuma enquete ativa no momento.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary)),
                    ])
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _enquetes.length,
                      itemBuilder: (ctx, i) => _buildCard(_enquetes[i]),
                    ),
            ),
    );
  }

  // ── Card ──────────────────────────────────────────────────
  Widget _buildCard(Map<String, dynamic> enquete) {
    final expired = _isExpired(enquete);
    final voted = _hasUnitVoted(enquete['id'] as String);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Data da enquete: ${_fmtDate(enquete['created_at'] ?? '')}',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _openVoting(enquete),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: expired
                  ? AppColors.primary
                  : voted
                      ? Colors.green.shade50
                      : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: voted && !expired
                  ? Border.all(color: Colors.green.shade200, width: 2)
                  : expired
                      ? null
                      : Border.all(color: AppColors.border),
              boxShadow: expired
                  ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))]
                  : null,
            ),
            child: Row(children: [
              Icon(Icons.format_list_bulleted,
                  size: 28,
                  color: expired ? Colors.white.withValues(alpha: 0.8) : AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Pergunta:',
                      style: TextStyle(
                          fontSize: 11,
                          color: expired ? Colors.white.withValues(alpha: 0.7) : AppColors.textSecondary)),
                  Text(enquete['pergunta'] ?? '',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: expired ? Colors.white : AppColors.textMain),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ]),
              ),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('Validade:',
                    style: TextStyle(
                        fontSize: 11,
                        color: expired ? Colors.white.withValues(alpha: 0.7) : AppColors.textSecondary)),
                Text(
                  enquete['validade'] != null ? _fmtDate(enquete['validade']) : '—',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: expired ? Colors.white : AppColors.textMain),
                ),
              ]),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right,
                  size: 24, color: expired ? Colors.white : Colors.green),
            ]),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Voting Bottom Sheet
// ═══════════════════════════════════════════════════════════════

class _VotingSheet extends StatefulWidget {
  final Map<String, dynamic> enquete;
  final List<String> initialVoted;
  final List<Map<String, dynamic>> allRespostas;
  final bool isExpired;
  final String bloco, apto, userId;
  final VoidCallback onVoted;

  const _VotingSheet({
    required this.enquete,
    required this.initialVoted,
    required this.allRespostas,
    required this.isExpired,
    required this.bloco,
    required this.apto,
    required this.userId,
    required this.onVoted,
  });

  @override
  State<_VotingSheet> createState() => _VotingSheetState();
}

class _VotingSheetState extends State<_VotingSheet> {
  final _supabase = Supabase.instance.client;
  late Set<String> _selected;
  bool _showResult = false;
  bool _sending = false;
  late List<Map<String, dynamic>> _allRespostas;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.initialVoted);
    _showResult = widget.initialVoted.isNotEmpty;
    _allRespostas = List.from(widget.allRespostas);
  }

  List<Map<String, dynamic>> get _opcoes {
    final raw = (widget.enquete['enquete_opcoes'] as List?) ?? [];
    final list = List<Map<String, dynamic>>.from(raw);
    list.sort((a, b) => (a['ordem'] as int? ?? 0).compareTo(b['ordem'] as int? ?? 0));
    return list;
  }

  String get _tipo => widget.enquete['tipo_resposta'] ?? 'unica';

  void _handleSelect(String opcaoId) {
    setState(() {
      if (_tipo == 'unica') {
        _selected = {opcaoId};
      } else {
        if (_selected.contains(opcaoId)) {
          _selected.remove(opcaoId);
        } else {
          _selected.add(opcaoId);
        }
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (_selected.isEmpty) return;
    setState(() => _sending = true);
    HapticFeedback.mediumImpact();

    try {
      // Delete previous unit responses
      await _supabase
          .from('enquete_respostas')
          .delete()
          .eq('enquete_id', widget.enquete['id'])
          .eq('bloco', widget.bloco)
          .eq('apto', widget.apto);

      // Insert new
      final rows = _selected.map((opcaoId) => {
            'enquete_id': widget.enquete['id'],
            'opcao_id': opcaoId,
            'user_id': widget.userId,
            'bloco': widget.bloco,
            'apto': widget.apto,
          }).toList();

      await _supabase.from('enquete_respostas').insert(rows);

      // Update local chart data
      _allRespostas.removeWhere(
        (r) => r['enquete_id'] == widget.enquete['id'],
      );
      for (final r in rows) {
        _allRespostas.add({
          'enquete_id': r['enquete_id'],
          'opcao_id': r['opcao_id'],
        });
      }

      if (mounted) {
        setState(() => _showResult = true);
        widget.onVoted();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
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

  @override
  Widget build(BuildContext context) {
    final pergunta = widget.enquete['pergunta'] ?? '';
    final validade = widget.enquete['validade'];

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(20),
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Enquete', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                Text(pergunta,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('Válida até:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                Text(
                  validade != null ? _fmtDate(validade) : '—',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ]),
            ]),
            const SizedBox(height: 20),

            // Pergunta
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Pergunta:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(pergunta, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ]),
            ),
            const SizedBox(height: 16),

            // Opções
            Text('Opções de respostas:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            ..._opcoes.map((opcao) {
              final id = opcao['id'] as String;
              final isSelected = _selected.contains(id);
              final disabled = _showResult && !widget.isExpired;

              return GestureDetector(
                onTap: disabled ? null : () => _handleSelect(id),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: isSelected ? 2 : 1,
                    ),
                    color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : Colors.white,
                  ),
                  child: Row(children: [
                    Icon(
                      _tipo == 'unica'
                          ? (isSelected ? Icons.radio_button_checked : Icons.radio_button_off)
                          : (isSelected ? Icons.check_box : Icons.check_box_outline_blank),
                      size: 20,
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(opcao['texto'] ?? '',
                          style: TextStyle(fontSize: 14, color: AppColors.textMain)),
                    ),
                  ]),
                ),
              );
            }),
            const SizedBox(height: 12),

            // ── After voting ───────────────────────────────
            if (_showResult) ...[
              // Confirmation
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(children: [
                  const Text('Obrigado!',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Seu apto já respondeu a pesquisa.',
                      style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 2),
                  Text('Até a validade da enquete, seu apto poderá responder novamente.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      textAlign: TextAlign.center),
                ]),
              ),
              const SizedBox(height: 12),

              // Last response
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text.rich(TextSpan(children: [
                  const TextSpan(
                      text: 'Última(s) resposta(s) do seu APTO: ',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  TextSpan(
                    text: _opcoes
                        .where((o) => _selected.contains(o['id']))
                        .map((o) => o['texto'])
                        .join(', '),
                    style: const TextStyle(fontSize: 12),
                  ),
                ])),
              ),
              const SizedBox(height: 12),

              // Revote button
              if (!widget.isExpired)
                Center(
                  child: CondoButton(
                    label: 'Responder novamente',
                    onPressed: () => setState(() => _showResult = false),
                    backgroundColor: Colors.grey.shade600,
                    foregroundColor: Colors.white,
                    isFullWidth: false,
                  ),
                ),
              const SizedBox(height: 20),

              // Chart
              Text('Resultado parcial da enquete:',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              _buildChart(),
            ] else ...[
              // Submit button
              CondoButton(
                label: _sending
                    ? 'Enviando...'
                    : widget.isExpired
                        ? 'Enquete encerrada'
                        : 'Responder',
                onPressed: _selected.isNotEmpty && !_sending && !widget.isExpired
                    ? _handleSubmit
                    : null,
              ),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── Bar chart ─────────────────────────────────────────────
  Widget _buildChart() {
    final enqueteId = widget.enquete['id'] as String;
    final counts = <String, int>{};
    for (final r in _allRespostas) {
      if (r['enquete_id'] == enqueteId) {
        final key = r['opcao_id'] as String;
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    final maxVal = counts.values.fold<int>(0, (a, b) => a > b ? a : b).clamp(1, 999999);
    final colors = [
      AppColors.primary,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.teal,
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        // Title
        Text(widget.enquete['pergunta'] ?? '',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            textAlign: TextAlign.center),
        const SizedBox(height: 12),

        // Bars
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: _opcoes.asMap().entries.map((e) {
              final i = e.key;
              final opcao = e.value;
              final val = counts[opcao['id']] ?? 0;
              final heightPct = val / maxVal;
              final color = colors[i % colors.length];
              return Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text('$val', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Container(
                    height: (heightPct * 80).clamp(4, 80),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Resp ${i + 1}',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                ]),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Legend
        const Divider(height: 1),
        const SizedBox(height: 8),
        ..._opcoes.asMap().entries.map((e) {
          final i = e.key;
          final opcao = e.value;
          final color = colors[i % colors.length];
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              Container(width: 12, height: 12,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 6),
              Text('Resp ${i + 1}:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(width: 4),
              Expanded(
                  child: Text(opcao['texto'] ?? '',
                      style: const TextStyle(fontSize: 11),
                      overflow: TextOverflow.ellipsis)),
            ]),
          );
        }),
      ]),
    );
  }
}
