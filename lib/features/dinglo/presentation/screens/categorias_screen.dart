import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../dinglo_theme.dart';

class CategoriasScreen extends StatefulWidget {
  const CategoriasScreen({super.key});
  @override
  State<CategoriasScreen> createState() => _CategoriasScreenState();
}

class _CategoriasScreenState extends State<CategoriasScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  List<Map<String, dynamic>> _categorias = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      final data = await _supabase.from('dinglo_categorias').select()
          .or('user_id.eq.$userId,is_default.eq.true').order('nome');
      if (mounted) setState(() { _categorias = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _showAddDialog() {
    String nome = '', icone = 'category', cor = '#3B82F6';
    String tipo = _tabController.index == 0 ? 'despesa' : 'receita';
    final ctrl = TextEditingController();

    final icones = ['restaurant', 'directions_car', 'home', 'local_hospital', 'school', 'sports_esports', 'checkroom', 'shopping_cart', 'subscriptions', 'pets', 'payments', 'work', 'trending_up', 'attach_money', 'savings', 'receipt'];
    final cores = ['#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7', '#DDA0DD', '#F8B500', '#FF7F50', '#7B68EE', '#20B2AA', '#2ECC71', '#3498DB', '#F39C12', '#E74C3C', '#9B59B6', '#1ABC9C'];

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setBS) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Nova Categoria', style: DingloTheme.heading2),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl, autofocus: true,
            decoration: InputDecoration(labelText: 'Nome da categoria', filled: true, fillColor: DingloTheme.surfaceVariant,
                border: OutlineInputBorder(borderRadius: DingloTheme.inputRadius, borderSide: BorderSide.none)),
            onChanged: (v) => nome = v,
          ),
          const SizedBox(height: 12),
          const Text('Ícone', style: DingloTheme.heading3),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: icones.map((ic) {
            final sel = icone == ic;
            return GestureDetector(
              onTap: () => setBS(() => icone = ic),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: sel ? DingloTheme.primary.withValues(alpha: 0.15) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: sel ? Border.all(color: DingloTheme.primary, width: 2) : null,
                ),
                child: Icon(DingloTheme.getIcon(ic), size: 20, color: sel ? DingloTheme.primary : DingloTheme.textMuted),
              ),
            );
          }).toList()),
          const SizedBox(height: 12),
          const Text('Cor', style: DingloTheme.heading3),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: cores.map((c) {
            final sel = cor == c;
            return GestureDetector(
              onTap: () => setBS(() => cor = c),
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: DingloTheme.parseColor(c), shape: BoxShape.circle,
                  border: sel ? Border.all(color: Colors.white, width: 3) : null,
                  boxShadow: sel ? [BoxShadow(color: DingloTheme.parseColor(c).withValues(alpha: 0.5), blurRadius: 6)] : null,
                ),
              ),
            );
          }).toList()),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () async {
              if (nome.isEmpty) return;
              await _supabase.from('dinglo_categorias').insert({
                'user_id': _supabase.auth.currentUser!.id,
                'nome': nome, 'icone': icone, 'cor': cor, 'tipo': tipo,
              });
              if (mounted) { Navigator.pop(ctx); _load(); }
            },
            style: ElevatedButton.styleFrom(backgroundColor: DingloTheme.primary, padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: DingloTheme.buttonRadius)),
            child: const Text('Salvar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          )),
        ]),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DingloTheme.background,
      appBar: AppBar(
        backgroundColor: DingloTheme.primary, foregroundColor: Colors.white,
        title: const Text('Categorias', style: TextStyle(fontWeight: FontWeight.w700)), elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white, labelColor: Colors.white, unselectedLabelColor: Colors.white54,
          tabs: const [Tab(text: 'Despesas'), Tab(text: 'Receitas')],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog, backgroundColor: DingloTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: DingloTheme.primary))
          : TabBarView(controller: _tabController, children: [
              _buildCatList('despesa'),
              _buildCatList('receita'),
            ]),
    );
  }

  Widget _buildCatList(String tipo) {
    final items = _categorias.where((c) => c['tipo'] == tipo).toList();
    if (items.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.category_rounded, size: 48, color: DingloTheme.textMuted),
      const SizedBox(height: 12), const Text('Nenhuma categoria', style: DingloTheme.body),
    ]));

    return ListView.builder(
      padding: const EdgeInsets.all(16), itemCount: items.length,
      itemBuilder: (_, i) {
        final c = items[i];
        final isDefault = c['is_default'] == true;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: DingloTheme.cardRadius, boxShadow: DingloTheme.cardShadow),
          child: ListTile(
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: DingloTheme.parseColor(c['cor']).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(DingloTheme.getIcon(c['icone']), color: DingloTheme.parseColor(c['cor']), size: 20),
            ),
            title: Text(c['nome'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: isDefault ? const Text('Padrão do sistema', style: DingloTheme.caption) : null,
            trailing: isDefault ? null : IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
              onPressed: () async {
                await _supabase.from('dinglo_categorias').delete().eq('id', c['id']);
                _load();
              },
            ),
          ),
        );
      },
    );
  }
}
