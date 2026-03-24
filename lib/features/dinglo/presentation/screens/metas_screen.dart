import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../dinglo_theme.dart';

class MetasScreen extends StatefulWidget {
  const MetasScreen({super.key});
  @override
  State<MetasScreen> createState() => _MetasScreenState();
}

class _MetasScreenState extends State<MetasScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _metas = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _supabase.from('dinglo_metas').select()
          .eq('user_id', _supabase.auth.currentUser!.id).order('created_at', ascending: false);
      if (mounted) setState(() { _metas = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _showAddDialog() {
    String titulo = '';
    double valorAlvo = 0;
    DateTime? dataAlvo;
    final tituloCtrl = TextEditingController();
    final valorCtrl = TextEditingController();

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setBS) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Nova Meta', style: DingloTheme.heading2),
          const SizedBox(height: 16),
          TextField(
            controller: tituloCtrl, autofocus: true,
            decoration: InputDecoration(labelText: 'O que quer alcançar?', hintText: 'Ex: Viagem de férias',
                filled: true, fillColor: DingloTheme.surfaceVariant,
                border: OutlineInputBorder(borderRadius: DingloTheme.inputRadius, borderSide: BorderSide.none)),
            onChanged: (v) => titulo = v,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: valorCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Valor alvo', prefixText: 'R\$ ',
                filled: true, fillColor: DingloTheme.surfaceVariant,
                border: OutlineInputBorder(borderRadius: DingloTheme.inputRadius, borderSide: BorderSide.none)),
            onChanged: (v) => valorAlvo = double.tryParse(v.replaceAll(',', '.')) ?? 0,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(context: ctx, initialDate: DateTime.now().add(const Duration(days: 90)),
                  firstDate: DateTime.now(), lastDate: DateTime(2035),
                  builder: (c, ch) => Theme(data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: DingloTheme.primary)), child: ch!));
              if (picked != null) setBS(() => dataAlvo = picked);
            },
            child: Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: DingloTheme.surfaceVariant, borderRadius: DingloTheme.inputRadius),
              child: Row(children: [
                const Icon(Icons.calendar_today_rounded, color: DingloTheme.primary, size: 18),
                const SizedBox(width: 10),
                Text(dataAlvo != null ? '${dataAlvo!.day.toString().padLeft(2, '0')}/${dataAlvo!.month.toString().padLeft(2, '0')}/${dataAlvo!.year}' : 'Data alvo (opcional)',
                    style: TextStyle(color: dataAlvo != null ? DingloTheme.textPrimary : DingloTheme.textMuted, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () async {
              if (titulo.isEmpty || valorAlvo <= 0) return;
              await _supabase.from('dinglo_metas').insert({
                'user_id': _supabase.auth.currentUser!.id,
                'titulo': titulo, 'valor_alvo': valorAlvo,
                'data_alvo': dataAlvo?.toIso8601String().split('T')[0],
              });
              if (mounted) { Navigator.pop(ctx); _load(); }
            },
            style: ElevatedButton.styleFrom(backgroundColor: DingloTheme.primary, padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: DingloTheme.buttonRadius)),
            child: const Text('Criar Meta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          )),
        ]),
      )),
    );
  }

  void _showUpdateDialog(Map<String, dynamic> meta) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Atualizar valor guardado'),
      content: TextField(
        controller: ctrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), autofocus: true,
        decoration: const InputDecoration(labelText: 'Adicionar valor', prefixText: 'R\$ '),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        TextButton(onPressed: () async {
          final add = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0;
          if (add <= 0) return;
          final atual = (meta['valor_atual'] as num?)?.toDouble() ?? 0;
          final alvo = (meta['valor_alvo'] as num?)?.toDouble() ?? 0;
          final novoValor = atual + add;
          await _supabase.from('dinglo_metas').update({
            'valor_atual': novoValor,
            'status': novoValor >= alvo ? 'concluida' : 'ativa',
          }).eq('id', meta['id']);
          if (mounted) { Navigator.pop(ctx); _load(); }
        }, child: const Text('Guardar', style: TextStyle(color: DingloTheme.primary))),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DingloTheme.background,
      appBar: AppBar(
        backgroundColor: DingloTheme.primary, foregroundColor: Colors.white,
        title: const Text('Minhas Metas', style: TextStyle(fontWeight: FontWeight.w700)), elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog, backgroundColor: DingloTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading ? const Center(child: CircularProgressIndicator(color: DingloTheme.primary))
          : _metas.isEmpty ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.flag_rounded, size: 56, color: DingloTheme.textMuted),
              const SizedBox(height: 12), const Text('Nenhuma meta criada', style: DingloTheme.body),
              const SizedBox(height: 6), const Text('Toque no + para criar sua primeira meta', style: DingloTheme.caption),
            ]))
          : RefreshIndicator(
              color: DingloTheme.primary, onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16), itemCount: _metas.length,
                itemBuilder: (_, i) {
                  final m = _metas[i];
                  final alvo = (m['valor_alvo'] as num?)?.toDouble() ?? 1;
                  final atual = (m['valor_atual'] as num?)?.toDouble() ?? 0;
                  final progress = (atual / alvo).clamp(0.0, 1.0);
                  final concluida = m['status'] == 'concluida';

                  return GestureDetector(
                    onTap: concluida ? null : () => _showUpdateDialog(m),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: DingloTheme.cardRadius,
                        boxShadow: DingloTheme.cardShadow,
                        border: concluida ? Border.all(color: DingloTheme.income, width: 2) : null,
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Icon(concluida ? Icons.emoji_events_rounded : Icons.flag_rounded,
                              color: concluida ? DingloTheme.income : DingloTheme.primary, size: 22),
                          const SizedBox(width: 8),
                          Text(m['titulo'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          const Spacer(),
                          if (concluida) Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: DingloTheme.income.withValues(alpha: 0.1), borderRadius: DingloTheme.chipRadius),
                            child: const Text('Concluída! 🎉', style: TextStyle(color: DingloTheme.income, fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                        ]),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress, minHeight: 8,
                            backgroundColor: DingloTheme.primary.withValues(alpha: 0.1),
                            color: concluida ? DingloTheme.income : DingloTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DingloTheme.formatCurrency(atual), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: DingloTheme.primary)),
                            Text('de ${DingloTheme.formatCurrency(alvo)}', style: DingloTheme.caption),
                            Text('${(progress * 100).toStringAsFixed(0)}%', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: concluida ? DingloTheme.income : DingloTheme.textSecondary)),
                          ],
                        ),
                        if (m['data_alvo'] != null) ...[
                          const SizedBox(height: 6),
                          Text('📅 Meta: ${m['data_alvo']}', style: DingloTheme.caption),
                        ],
                      ]),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
