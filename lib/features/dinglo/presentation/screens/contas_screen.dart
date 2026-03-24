import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../dinglo_theme.dart';
import '../../plano_service.dart';

class ContasScreen extends StatefulWidget {
  const ContasScreen({super.key});
  @override
  State<ContasScreen> createState() => _ContasScreenState();
}

class _ContasScreenState extends State<ContasScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _contas = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContas();
  }

  Future<void> _loadContas() async {
    setState(() => _loading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      final data = await _supabase.from('dinglo_contas')
          .select()
          .eq('user_id', userId)
          .order('created_at');
      if (mounted) setState(() { _contas = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _deleteConta(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir conta?'),
        content: const Text('Lançamentos vinculados perderão a referência.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    await _supabase.from('dinglo_contas').delete().eq('id', id);
    _loadContas();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DingloTheme.background,
      appBar: AppBar(
        backgroundColor: DingloTheme.primary,
        foregroundColor: Colors.white,
        title: const Text('Minhas Contas', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final canAdd = await PlanoService.canAddConta();
          if (!canAdd && mounted) {
            PlanoService.showUpgradeDialog(context,
              recurso: 'contas bancárias',
              limite: 'até ${PlanoService.maxContasBasico} contas',
            );
            return;
          }
          if (mounted) {
            Navigator.pushNamed(context, '/dinglo/cadastro-conta').then((_) => _loadContas());
          }
        },
        backgroundColor: DingloTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: DingloTheme.primary))
          : _contas.isEmpty
              ? _buildEmpty()
              : _buildList(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_rounded, size: 56, color: DingloTheme.textMuted),
          const SizedBox(height: 12),
          const Text('Nenhuma conta cadastrada', style: DingloTheme.body),
          const SizedBox(height: 6),
          const Text('Toque no + para adicionar', style: DingloTheme.caption),
        ],
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      color: DingloTheme.primary,
      onRefresh: _loadContas,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _contas.length,
        itemBuilder: (_, i) {
          final c = _contas[i];
          final saldo = (c['saldo_inicial'] as num?)?.toDouble() ?? 0;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: DingloTheme.cardRadius,
              boxShadow: DingloTheme.cardShadow,
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: DingloTheme.cardGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 22),
              ),
              title: Text(c['banco'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: Text(
                '${c['descricao'] ?? ''} • ${(c['tipo'] ?? 'corrente').toString().replaceFirst(RegExp(r'^[a-z]'), (c['tipo'] ?? 'c')[0].toUpperCase())}',
                style: DingloTheme.caption,
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(DingloTheme.formatCurrency(saldo),
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: saldo >= 0 ? DingloTheme.income : DingloTheme.expense)),
                  const SizedBox(height: 2),
                  const Text('saldo', style: DingloTheme.caption),
                ],
              ),
              onLongPress: () => _deleteConta(c['id']),
            ),
          );
        },
      ),
    );
  }
}
