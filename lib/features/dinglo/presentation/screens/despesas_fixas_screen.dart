import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../dinglo_theme.dart';

class DespesasFixasScreen extends StatefulWidget {
  const DespesasFixasScreen({super.key});
  @override
  State<DespesasFixasScreen> createState() => _DespesasFixasScreenState();
}

class _DespesasFixasScreenState extends State<DespesasFixasScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _despesas = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _supabase.from('dinglo_despesas_fixas')
          .select('*, dinglo_categorias(nome, icone, cor)')
          .eq('user_id', _supabase.auth.currentUser!.id)
          .order('dia_vencimento');
      if (mounted) setState(() { _despesas = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _showAddDialog() {
    String descricao = '';
    double valor = 0;
    int diaVenc = 5;

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Nova Despesa Fixa', style: DingloTheme.heading2),
          const SizedBox(height: 16),
          TextField(
            autofocus: true,
            decoration: InputDecoration(labelText: 'Descrição', hintText: 'Ex: Aluguel, Netflix...',
                filled: true, fillColor: DingloTheme.surfaceVariant,
                border: OutlineInputBorder(borderRadius: DingloTheme.inputRadius, borderSide: BorderSide.none)),
            onChanged: (v) => descricao = v,
          ),
          const SizedBox(height: 12),
          TextField(
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Valor mensal', prefixText: 'R\$ ',
                filled: true, fillColor: DingloTheme.surfaceVariant,
                border: OutlineInputBorder(borderRadius: DingloTheme.inputRadius, borderSide: BorderSide.none)),
            onChanged: (v) => valor = double.tryParse(v.replaceAll(',', '.')) ?? 0,
          ),
          const SizedBox(height: 12),
          TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Dia do vencimento', hintText: '5',
                filled: true, fillColor: DingloTheme.surfaceVariant,
                border: OutlineInputBorder(borderRadius: DingloTheme.inputRadius, borderSide: BorderSide.none)),
            onChanged: (v) => diaVenc = int.tryParse(v) ?? 5,
          ),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () async {
              if (descricao.isEmpty || valor <= 0) return;
              await _supabase.from('dinglo_despesas_fixas').insert({
                'user_id': _supabase.auth.currentUser!.id,
                'descricao': descricao, 'valor': valor, 'dia_vencimento': diaVenc,
              });
              if (mounted) { Navigator.pop(ctx); _load(); }
            },
            style: ElevatedButton.styleFrom(backgroundColor: DingloTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: DingloTheme.buttonRadius)),
            child: const Text('Salvar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          )),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalMensal = 0;
    for (final d in _despesas) { totalMensal += (d['valor'] as num?)?.toDouble() ?? 0; }

    return Scaffold(
      backgroundColor: DingloTheme.background,
      appBar: AppBar(
        backgroundColor: DingloTheme.primary, foregroundColor: Colors.white,
        title: const Text('Despesas Fixas', style: TextStyle(fontWeight: FontWeight.w700)), elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog, backgroundColor: DingloTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading ? const Center(child: CircularProgressIndicator(color: DingloTheme.primary))
          : Column(children: [
              // Total header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: DingloTheme.expenseGradient,
                  borderRadius: DingloTheme.cardRadius,
                  boxShadow: [BoxShadow(color: DingloTheme.expense.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Column(children: [
                  const Text('Total mensal de despesas fixas', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text(DingloTheme.formatCurrency(totalMensal),
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                  Text('${_despesas.length} despesas cadastradas', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ]),
              ),
              // List
              Expanded(
                child: _despesas.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.repeat_rounded, size: 48, color: DingloTheme.textMuted),
                        const SizedBox(height: 12), const Text('Nenhuma despesa fixa', style: DingloTheme.body),
                      ]))
                    : RefreshIndicator(
                        color: DingloTheme.primary, onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: _despesas.length,
                          itemBuilder: (_, i) {
                            final d = _despesas[i];
                            final valor = (d['valor'] as num?)?.toDouble() ?? 0;
                            final cat = d['dinglo_categorias'];
                            final hoje = DateTime.now().day;
                            final diaVenc = d['dia_vencimento'] as int? ?? 0;
                            final isVencendo = diaVenc > 0 && (diaVenc - hoje).abs() <= 3;

                            return Dismissible(
                              key: Key(d['id']),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20),
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(color: Colors.red, borderRadius: DingloTheme.cardRadius),
                                child: const Icon(Icons.delete_rounded, color: Colors.white),
                              ),
                              onDismissed: (_) async {
                                await _supabase.from('dinglo_despesas_fixas').delete().eq('id', d['id']);
                                _load();
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white, borderRadius: DingloTheme.cardRadius,
                                  boxShadow: DingloTheme.cardShadow,
                                  border: isVencendo ? Border.all(color: DingloTheme.warning, width: 1.5) : null,
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                  leading: Container(
                                    width: 38, height: 38,
                                    decoration: BoxDecoration(
                                      color: DingloTheme.expense.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      cat != null ? DingloTheme.getIcon(cat['icone']) : Icons.repeat_rounded,
                                      color: DingloTheme.expense, size: 20,
                                    ),
                                  ),
                                  title: Text(d['descricao'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  subtitle: Text(
                                    'Vence dia $diaVenc${isVencendo ? ' ⚠️' : ''}',
                                    style: TextStyle(fontSize: 11, color: isVencendo ? DingloTheme.warning : DingloTheme.textMuted),
                                  ),
                                  trailing: Text(DingloTheme.formatCurrency(valor),
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: DingloTheme.expense)),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ]),
    );
  }
}
