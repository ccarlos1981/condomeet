import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../dinglo_theme.dart';
import '../../plano_service.dart';

class CartoesScreen extends StatefulWidget {
  const CartoesScreen({super.key});
  @override
  State<CartoesScreen> createState() => _CartoesScreenState();
}

class _CartoesScreenState extends State<CartoesScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _cartoes = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _supabase.from('dinglo_cartoes').select('*, dinglo_contas(banco)')
          .eq('user_id', _supabase.auth.currentUser!.id).order('nome');
      if (mounted) setState(() { _cartoes = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Excluir cartão?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir', style: TextStyle(color: Colors.red))),
      ],
    ));
    if (ok != true) return;
    await _supabase.from('dinglo_cartoes').delete().eq('id', id);
    _load();
  }

  void _showAddDialog() {
    String nome = '', bandeira = 'visa';
    double limite = 0;
    int diaVenc = 10, diaFech = 3;
    final nomeCtrl = TextEditingController();
    final limiteCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setBS) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Novo Cartão', style: DingloTheme.heading2),
              const SizedBox(height: 16),
              TextField(
                controller: nomeCtrl,
                decoration: InputDecoration(
                  labelText: 'Nome do cartão',
                  hintText: 'Ex: Nubank Platinum',
                  filled: true, fillColor: DingloTheme.surfaceVariant,
                  border: OutlineInputBorder(borderRadius: DingloTheme.inputRadius, borderSide: BorderSide.none),
                ),
                onChanged: (v) => nome = v,
              ),
              const SizedBox(height: 12),
              const Text('Bandeira', style: DingloTheme.heading3),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: ['visa', 'mastercard', 'elo', 'amex', 'hipercard'].map((b) {
                final sel = bandeira == b;
                return ChoiceChip(
                  label: Text(b[0].toUpperCase() + b.substring(1)),
                  selected: sel,
                  selectedColor: DingloTheme.primary.withValues(alpha: 0.15),
                  labelStyle: TextStyle(color: sel ? DingloTheme.primary : DingloTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 12),
                  onSelected: (_) => setBS(() => bandeira = b),
                );
              }).toList()),
              const SizedBox(height: 12),
              TextField(
                controller: limiteCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Limite', prefixText: 'R\$ ',
                  filled: true, fillColor: DingloTheme.surfaceVariant,
                  border: OutlineInputBorder(borderRadius: DingloTheme.inputRadius, borderSide: BorderSide.none),
                ),
                onChanged: (v) => limite = double.tryParse(v.replaceAll(',', '.')) ?? 0,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Dia vencimento',
                    filled: true, fillColor: DingloTheme.surfaceVariant,
                    border: OutlineInputBorder(borderRadius: DingloTheme.inputRadius, borderSide: BorderSide.none),
                  ),
                  onChanged: (v) => diaVenc = int.tryParse(v) ?? 10,
                )),
                const SizedBox(width: 12),
                Expanded(child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Dia fechamento',
                    filled: true, fillColor: DingloTheme.surfaceVariant,
                    border: OutlineInputBorder(borderRadius: DingloTheme.inputRadius, borderSide: BorderSide.none),
                  ),
                  onChanged: (v) => diaFech = int.tryParse(v) ?? 3,
                )),
              ]),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nome.isEmpty) return;
                    await _supabase.from('dinglo_cartoes').insert({
                      'user_id': _supabase.auth.currentUser!.id,
                      'nome': nome, 'bandeira': bandeira,
                      'limite': limite, 'dia_vencimento': diaVenc, 'dia_fechamento': diaFech,
                    });
                    if (mounted) { Navigator.pop(ctx); _load(); }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DingloTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: DingloTheme.buttonRadius),
                  ),
                  child: const Text('Salvar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DingloTheme.background,
      appBar: AppBar(
        backgroundColor: DingloTheme.primary, foregroundColor: Colors.white,
        title: const Text('Meus Cartões', style: TextStyle(fontWeight: FontWeight.w700)), elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final canAdd = await PlanoService.canAddCartao();
          if (!canAdd && mounted) {
            PlanoService.showUpgradeDialog(context,
              recurso: 'cartões',
              limite: 'até ${PlanoService.maxCartoesBasico} cartão',
            );
            return;
          }
          if (mounted) _showAddDialog();
        },
        backgroundColor: DingloTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading ? const Center(child: CircularProgressIndicator(color: DingloTheme.primary))
          : _cartoes.isEmpty ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.credit_card_off_rounded, size: 56, color: DingloTheme.textMuted),
              const SizedBox(height: 12), const Text('Nenhum cartão cadastrado', style: DingloTheme.body),
            ]))
          : RefreshIndicator(
              color: DingloTheme.primary, onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16), itemCount: _cartoes.length,
                itemBuilder: (_, i) {
                  final c = _cartoes[i];
                  final limite = (c['limite'] as num?)?.toDouble() ?? 0;
                  final colors = _bandeiraCores(c['bandeira']);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(color: colors[0].withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.credit_card_rounded, color: Colors.white, size: 24),
                          const SizedBox(width: 8),
                          Text(c['nome'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => _delete(c['id']),
                            child: const Icon(Icons.more_vert_rounded, color: Colors.white54),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        Row(children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Limite', style: TextStyle(color: Colors.white60, fontSize: 11)),
                            Text(DingloTheme.formatCurrency(limite), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                          ]),
                          const SizedBox(width: 30),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Vencimento', style: TextStyle(color: Colors.white60, fontSize: 11)),
                            Text('Dia ${c['dia_vencimento'] ?? '-'}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                          ]),
                        ]),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            (c['bandeira'] ?? '').toString().toUpperCase(),
                            style: const TextStyle(color: Colors.white38, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  List<Color> _bandeiraCores(String? b) {
    switch (b) {
      case 'mastercard': return [const Color(0xFFEB001B), const Color(0xFFF79E1B)];
      case 'elo': return [const Color(0xFF00A4E0), const Color(0xFFFFCB05)];
      case 'amex': return [const Color(0xFF006FCF), const Color(0xFF002663)];
      case 'hipercard': return [const Color(0xFF822124), const Color(0xFFB71C1C)];
      default: return [const Color(0xFF1A237E), const Color(0xFF3F51B5)]; // visa
    }
  }
}
