import 'package:flutter/material.dart';
import 'package:condomeet/features/lista_mercado/lista_mercado_service.dart';
import 'package:condomeet/features/lista_mercado/presentation/widgets/lista_onboarding_popup.dart';

class ListaMercadoHomeScreen extends StatefulWidget {
  const ListaMercadoHomeScreen({super.key});

  @override
  State<ListaMercadoHomeScreen> createState() => _ListaMercadoHomeScreenState();
}

class _ListaMercadoHomeScreenState extends State<ListaMercadoHomeScreen> {
  final _service = ListaMercadoService();
  List<Map<String, dynamic>> _lists = [];
  List<Map<String, dynamic>> _promotions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Show onboarding on first access
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ListaOnboardingPopup.showIfNeeded(context);
    });
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final lists = await _service.getMyLists();
      final promos = await _service.getActivePromotions(limit: 5);
      if (mounted) {
        setState(() {
          _lists = lists;
          _promotions = promos;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createNewList() async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        String selectedType = 'quick';
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Nova Lista 🛒', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Ex: Compras do Mês',
                    hintStyle: TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildTypeChip('quick', '⚡ Rápida', selectedType, (v) => setDialogState(() => selectedType = v)),
                    const SizedBox(width: 8),
                    _buildTypeChip('monthly', '📅 Mensal', selectedType, (v) => setDialogState(() => selectedType = v)),
                    const SizedBox(width: 8),
                    _buildTypeChip('wholesale', '📦 Atacado', selectedType, (v) => setDialogState(() => selectedType = v)),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, '${controller.text.trim()}|$selectedType'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C853), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text('Criar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );

    if (name != null && name.contains('|')) {
      final parts = name.split('|');
      final listName = parts[0].isEmpty ? 'Minha Lista' : parts[0];
      final listType = parts[1];
      await _service.createList(name: listName, listType: listType);
      _loadData();
    }
  }

  Widget _buildTypeChip(String value, String label, String selected, ValueChanged<String> onTap) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00C853).withOpacity(0.2) : Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF00C853) : Colors.white24),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? const Color(0xFF00C853) : Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        title: const Row(
          children: [
            Text('🛒', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text('Meu Mercado', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Help button — re-show onboarding
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white54),
            tooltip: 'Como funciona?',
            onPressed: () => ListaOnboardingPopup.showAlways(context),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C853)))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFF00C853),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Botão criar lista ──
                  GestureDetector(
                    onTap: _createNewList,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF00C853), Color(0xFF00E676)]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: const Color(0xFF00C853).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline, color: Colors.white, size: 28),
                          SizedBox(width: 12),
                          Text('Criar Nova Lista', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Reportar preço ──
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/lista-mercado/reportar'),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E2E),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('📢', style: TextStyle(fontSize: 22)),
                          SizedBox(width: 10),
                          Text('Reportar Preço', style: TextStyle(color: Colors.orange, fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(width: 6),
                          Text('(ganhe pontos!)', style: TextStyle(color: Colors.white38, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Escanear cupom ──
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/lista-mercado/scanner'),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E2E),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('📷', style: TextStyle(fontSize: 22)),
                          SizedBox(width: 10),
                          Text('Escanear Cupom', style: TextStyle(color: Colors.blueAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(width: 6),
                          Text('(OCR)', style: TextStyle(color: Colors.white38, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Ranking ──
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/lista-mercado/ranking'),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E2E),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('🏆', style: TextStyle(fontSize: 22)),
                          SizedBox(width: 10),
                          Text('Ranking', style: TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(width: 6),
                          Text('(Leaderboard)', style: TextStyle(color: Colors.white38, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Alertas de Preço ──
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/lista-mercado/alertas'),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E2E),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('🔔', style: TextStyle(fontSize: 22)),
                          SizedBox(width: 10),
                          Text('Alertas de Preço', style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Compartilhar Economia ──
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/lista-mercado/cartao'),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [const Color(0xFF00C853).withOpacity(0.15), const Color(0xFF00E676).withOpacity(0.08)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF00C853).withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('📤', style: TextStyle(fontSize: 22)),
                          SizedBox(width: 10),
                          Text('Compartilhar Economia', style: TextStyle(color: Color(0xFF00E676), fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_lists.isNotEmpty) ...[
                    const Row(
                      children: [
                        Text('📋', style: TextStyle(fontSize: 20)),
                        SizedBox(width: 8),
                        Text('Minhas Listas', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._lists.map((list) => _buildListCard(list)),
                    const SizedBox(height: 24),
                  ],

                  // ── Promoções ──
                  if (_promotions.isNotEmpty) ...[
                    const Row(
                      children: [
                        Text('🔥', style: TextStyle(fontSize: 20)),
                        SizedBox(width: 8),
                        Text('Promoções Perto', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._promotions.map((promo) => _buildPromoCard(promo)),
                  ],

                  // ── Estado vazio ──
                  if (_lists.isEmpty && _promotions.isEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 60),
                      child: Column(
                        children: [
                          const Text('🛒', style: TextStyle(fontSize: 80)),
                          const SizedBox(height: 16),
                          const Text('Crie sua primeira lista!', style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text('Compare preços e economize nas compras', style: TextStyle(color: Colors.white38, fontSize: 14)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildListCard(Map<String, dynamic> list) {
    final items = List<Map<String, dynamic>>.from(list['lista_shopping_list_items'] ?? []);
    final itemCount = items.length;
    final checkedCount = items.where((i) => i['is_checked'] == true).length;
    final typeIcon = list['list_type'] == 'monthly' ? '📅' : list['list_type'] == 'wholesale' ? '📦' : '⚡';

    return GestureDetector(
      onTap: () async {
        await Navigator.pushNamed(context, '/lista-mercado/edit', arguments: list['id']);
        _loadData();
      },
      onLongPress: () => _showListOptions(list),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Text(typeIcon, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(list['name'] ?? 'Minha Lista', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('$itemCount itens${checkedCount > 0 ? ' • $checkedCount comprados' : ''}',
                      style: const TextStyle(color: Colors.white54, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  void _showListOptions(Map<String, dynamic> list) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.white70),
              title: const Text('Renomear', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                final controller = TextEditingController(text: list['name']);
                final newName = await showDialog<String>(
                  context: context,
                  builder: (c) => AlertDialog(
                    backgroundColor: const Color(0xFF1E1E2E),
                    title: const Text('Renomear Lista', style: TextStyle(color: Colors.white)),
                    content: TextField(
                      controller: controller,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(c, controller.text.trim()),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C853)),
                        child: const Text('Salvar', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (newName != null && newName.isNotEmpty) {
                  await _service.renameList(list['id'], newName);
                  _loadData();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Excluir', style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    backgroundColor: const Color(0xFF1E1E2E),
                    title: const Text('Excluir Lista?', style: TextStyle(color: Colors.white)),
                    content: Text('Essa ação não pode ser desfeita.', style: TextStyle(color: Colors.white54)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(c, true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                        child: const Text('Excluir', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _service.deleteList(list['id']);
                  _loadData();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoCard(Map<String, dynamic> promo) {
    final sku = promo['lista_products_sku'];
    final variant = sku?['lista_product_variants'];
    final base = variant?['lista_products_base'];
    final market = promo['lista_supermarkets'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(base?['icon_emoji'] ?? '🏷️', style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(variant?['variant_name'] ?? 'Produto', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                Text(market?['name'] ?? '', style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (promo['original_price'] != null)
                Text('R\$ ${(promo['original_price'] as num).toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12, decoration: TextDecoration.lineThrough)),
              Text('R\$ ${(promo['promo_price'] as num).toStringAsFixed(2)}',
                  style: const TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold, fontSize: 16)),
              if (promo['discount_percent'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                  child: Text('-${promo['discount_percent']}%', style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
