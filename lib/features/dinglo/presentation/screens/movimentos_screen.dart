import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../dinglo_theme.dart';

class MovimentosScreen extends StatefulWidget {
  const MovimentosScreen({super.key});
  @override
  State<MovimentosScreen> createState() => _MovimentosScreenState();
}

class _MovimentosScreenState extends State<MovimentosScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _movimentos = [];
  bool _loading = true;
  DateTime _mesSelecionado = DateTime.now();
  String _filtroStatus = 'todos'; // todos, realizado, pendente

  @override
  void initState() {
    super.initState();
    _loadMovimentos();
  }

  Future<void> _loadMovimentos() async {
    setState(() => _loading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      final firstDay = DateTime(_mesSelecionado.year, _mesSelecionado.month, 1).toIso8601String().split('T')[0];
      final lastDay = DateTime(_mesSelecionado.year, _mesSelecionado.month + 1, 0).toIso8601String().split('T')[0];

      var query = _supabase.from('dinglo_lancamentos')
          .select('*, dinglo_categorias(nome, icone, cor)')
          .eq('user_id', userId)
          .gte('data_lancamento', firstDay)
          .lte('data_lancamento', lastDay);

      if (_filtroStatus != 'todos') {
        query = query.eq('status', _filtroStatus);
      }

      final data = await query.order('data_lancamento', ascending: false);
      if (mounted) setState(() { _movimentos = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _changeMonth(int delta) {
    setState(() {
      _mesSelecionado = DateTime(_mesSelecionado.year, _mesSelecionado.month + delta, 1);
    });
    _loadMovimentos();
  }

  Future<void> _toggleStatus(Map<String, dynamic> mov) async {
    final newStatus = mov['status'] == 'realizado' ? 'pendente' : 'realizado';
    await _supabase.from('dinglo_lancamentos').update({'status': newStatus}).eq('id', mov['id']);
    _loadMovimentos();
  }

  Future<void> _deleteMovimento(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir lançamento?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    await _supabase.from('dinglo_lancamentos').delete().eq('id', id);
    _loadMovimentos();
  }

  @override
  Widget build(BuildContext context) {
    final meses = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    double totalReceitas = 0, totalDespesas = 0;
    for (final m in _movimentos) {
      final v = (m['valor'] as num?)?.toDouble() ?? 0;
      if (m['tipo'] == 'receita') totalReceitas += v; else totalDespesas += v;
    }

    return Scaffold(
      backgroundColor: DingloTheme.background,
      appBar: AppBar(
        backgroundColor: DingloTheme.primary,
        foregroundColor: Colors.white,
        title: const Text('Movimentações', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Month selector
          Container(
            color: DingloTheme.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => _changeMonth(-1),
                      icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
                    ),
                    Text(
                      '${meses[_mesSelecionado.month - 1]} ${_mesSelecionado.year}',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    IconButton(
                      onPressed: () => _changeMonth(1),
                      icon: const Icon(Icons.chevron_right_rounded, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildMiniTotal('Receitas', totalReceitas, DingloTheme.income)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildMiniTotal('Despesas', totalDespesas, DingloTheme.expense)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildMiniTotal('Saldo', totalReceitas - totalDespesas,
                        totalReceitas >= totalDespesas ? DingloTheme.income : DingloTheme.expense)),
                  ],
                ),
              ],
            ),
          ),
          // Filter chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('todos', 'Todos'),
                const SizedBox(width: 8),
                _buildFilterChip('realizado', 'Realizado'),
                const SizedBox(width: 8),
                _buildFilterChip('pendente', 'Pendente'),
              ],
            ),
          ),
          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: DingloTheme.primary))
                : _movimentos.isEmpty
                    ? _buildEmpty()
                    : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniTotal(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9)),
          const SizedBox(height: 2),
          Text(DingloTheme.formatCurrency(value),
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final selected = _filtroStatus == value;
    return GestureDetector(
      onTap: () {
        setState(() => _filtroStatus = value);
        _loadMovimentos();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? DingloTheme.primary : Colors.transparent,
          borderRadius: DingloTheme.chipRadius,
          border: Border.all(color: selected ? DingloTheme.primary : Colors.grey.shade300),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: selected ? Colors.white : DingloTheme.textSecondary,
        )),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded, size: 48, color: DingloTheme.textMuted),
          const SizedBox(height: 12),
          const Text('Nenhum movimento neste mês', style: DingloTheme.body),
        ],
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      color: DingloTheme.primary,
      onRefresh: _loadMovimentos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _movimentos.length,
        itemBuilder: (_, i) {
          final m = _movimentos[i];
          final isReceita = m['tipo'] == 'receita';
          final valor = (m['valor'] as num?)?.toDouble() ?? 0;
          final isPendente = m['status'] == 'pendente';
          final cat = m['dinglo_categorias'];
          final dataStr = m['data_lancamento'] ?? '';
          final parts = dataStr.split('-');
          final dateLabel = parts.length == 3 ? '${parts[2]}/${parts[1]}' : dataStr;

          return Dismissible(
            key: Key(m['id']),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: Colors.red, borderRadius: DingloTheme.cardRadius),
              child: const Icon(Icons.delete_rounded, color: Colors.white),
            ),
            onDismissed: (_) => _deleteMovimento(m['id']),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: DingloTheme.cardRadius,
                boxShadow: DingloTheme.cardShadow,
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                leading: GestureDetector(
                  onTap: () => _toggleStatus(m),
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: isPendente ? Colors.orange.withValues(alpha: 0.1) : DingloTheme.income.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isPendente ? Icons.schedule_rounded : Icons.check_circle_rounded,
                      color: isPendente ? Colors.orange : DingloTheme.income,
                      size: 20,
                    ),
                  ),
                ),
                title: Text(m['descricao'] ?? '', style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  decoration: isPendente ? null : null,
                )),
                subtitle: Text(
                  '${cat?['nome'] ?? 'Sem cat.'} • $dateLabel${m['parcela_total'] != null ? ' • ${m['parcela_atual']}/${m['parcela_total']}' : ''}',
                  style: DingloTheme.caption,
                ),
                trailing: Text(
                  '${isReceita ? '+' : '-'} ${DingloTheme.formatCurrency(valor)}',
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: isReceita ? DingloTheme.income : DingloTheme.expense,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
