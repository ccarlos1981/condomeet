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

  // Light theme colors
  static const _accent = Color(0xFF00C853);
  static const _accentDark = Color(0xFF00A844);

  @override
  void initState() {
    super.initState();
    _loadData();
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
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_shopping_cart, color: _accent, size: 20),
                ),
                const SizedBox(width: 12),
                Text('Nova Lista', style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: TextStyle(color: Colors.grey.shade900),
                  decoration: InputDecoration(
                    hintText: 'Ex: Compras do Mês',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildTypeChip('quick', Icons.bolt, 'Rápida', selectedType, (v) => setDialogState(() => selectedType = v)),
                    const SizedBox(width: 8),
                    _buildTypeChip('monthly', Icons.calendar_month, 'Mensal', selectedType, (v) => setDialogState(() => selectedType = v)),
                    const SizedBox(width: 8),
                    _buildTypeChip('wholesale', Icons.inventory_2, 'Atacado', selectedType, (v) => setDialogState(() => selectedType = v)),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancelar', style: TextStyle(color: Colors.grey.shade500)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, '${controller.text.trim()}|$selectedType'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Criar', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildTypeChip(String value, IconData icon, String label, String selected, ValueChanged<String> onTap) {
    final isSelected = value == selected;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? _accent.withValues(alpha: 0.12) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? _accent : Colors.grey.shade300),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? _accent : Colors.grey.shade500, size: 18),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: isSelected ? _accentDark : Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: Colors.grey.shade800),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.shopping_cart_rounded, color: _accent, size: 22),
            ),
            const SizedBox(width: 10),
            Text('Meu Mercado', style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline_rounded, color: Colors.grey.shade500),
            tooltip: 'Como funciona?',
            onPressed: () => ListaOnboardingPopup.showAlways(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: _accent,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── CTA: Criar Lista ──
                  _buildCTAButton(),
                  const SizedBox(height: 20),

                  // ── Quick Actions Grid ──
                  _buildQuickActionsGrid(),
                  const SizedBox(height: 24),

                  // ── Minhas Listas ──
                  if (_lists.isNotEmpty) ...[
                    _buildSectionHeader(Icons.checklist_rounded, 'Minhas Listas'),
                    const SizedBox(height: 12),
                    ..._lists.map((list) => _buildListCard(list)),
                    const SizedBox(height: 24),
                  ],

                  // ── Promoções ──
                  if (_promotions.isNotEmpty) ...[
                    _buildSectionHeader(Icons.local_fire_department_rounded, 'Promoções Perto', color: Colors.orange.shade700),
                    const SizedBox(height: 12),
                    ..._promotions.map((promo) => _buildPromoCard(promo)),
                  ],

                  // ── Empty State ──
                  if (_lists.isEmpty && _promotions.isEmpty)
                    _buildEmptyState(),

                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  // ── CTA Button ──
  Widget _buildCTAButton() {
    return GestureDetector(
      onTap: _createNewList,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_accent, Color(0xFF00E676)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: _accent.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 5)),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: Colors.white, size: 26),
            SizedBox(width: 10),
            Text('Criar Nova Lista', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
          ],
        ),
      ),
    );
  }

  // ── Quick Actions Grid ──
  Widget _buildQuickActionsGrid() {
    final actions = [
      _QuickAction('Reportar\nPreço', Icons.campaign_rounded, const Color(0xFFF57C00), '/lista-mercado/reportar'),
      _QuickAction('Escanear\nCupom', Icons.qr_code_scanner_rounded, const Color(0xFF1976D2), '/lista-mercado/scanner'),
      _QuickAction('Ranking', Icons.emoji_events_rounded, const Color(0xFFF9A825), '/lista-mercado/ranking'),
      _QuickAction('Alertas\nde Preço', Icons.notifications_active_rounded, const Color(0xFFE53935), '/lista-mercado/alertas'),
      _QuickAction('Compartilhar\nEconomia', Icons.share_rounded, const Color(0xFF43A047), '/lista-mercado/cartao'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.grid_view_rounded, 'Ações Rápidas'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.05,
          children: actions.map((a) => _buildActionTile(a)).toList(),
        ),
      ],
    );
  }

  Widget _buildActionTile(_QuickAction action) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, action.route),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: action.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(action.icon, color: action.color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              action.label,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 11, fontWeight: FontWeight.w600, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section Header ──
  Widget _buildSectionHeader(IconData icon, String title, {Color color = _accent}) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(color: Colors.grey.shade900, fontSize: 17, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ── List Card ──
  Widget _buildListCard(Map<String, dynamic> list) {
    final items = List<Map<String, dynamic>>.from(list['lista_shopping_list_items'] ?? []);
    final itemCount = items.length;
    final checkedCount = items.where((i) => i['is_checked'] == true).length;
    final progress = itemCount > 0 ? checkedCount / itemCount : 0.0;
    final typeIcon = list['list_type'] == 'monthly' ? Icons.calendar_month
        : list['list_type'] == 'wholesale' ? Icons.inventory_2 : Icons.bolt;
    final typeColor = list['list_type'] == 'monthly' ? const Color(0xFF1976D2)
        : list['list_type'] == 'wholesale' ? const Color(0xFF7B1FA2) : _accent;

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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(typeIcon, color: typeColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(list['name'] ?? 'Minha Lista', style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('$itemCount itens${checkedCount > 0 ? ' • $checkedCount comprados' : ''}',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                  if (itemCount > 0) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation(typeColor),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 22),
          ],
        ),
      ),
    );
  }

  // ── Empty State ──
  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shopping_cart_outlined, size: 48, color: _accent.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 20),
          Text('Crie sua primeira lista!', style: TextStyle(color: Colors.grey.shade800, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Compare preços e economize nas compras', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
        ],
      ),
    );
  }

  // ── List Options Bottom Sheet ──
  void _showListOptions(Map<String, dynamic> list) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF1976D2).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.edit_rounded, color: Color(0xFF1976D2), size: 20),
              ),
              title: Text('Renomear', style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(ctx);
                final controller = TextEditingController(text: list['name']);
                final newName = await showDialog<String>(
                  context: context,
                  builder: (c) => AlertDialog(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: Text('Renomear Lista', style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.bold)),
                    content: TextField(
                      controller: controller,
                      style: TextStyle(color: Colors.grey.shade900),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c), child: Text('Cancelar', style: TextStyle(color: Colors.grey.shade500))),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(c, controller.text.trim()),
                        style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: const Text('Salvar', style: TextStyle(fontWeight: FontWeight.bold)),
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
            const SizedBox(height: 4),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
              ),
              title: const Text('Excluir', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: Text('Excluir Lista?', style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.bold)),
                    content: Text('Essa ação não pode ser desfeita.', style: TextStyle(color: Colors.grey.shade600)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Cancelar', style: TextStyle(color: Colors.grey.shade500))),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(c, true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: const Text('Excluir', style: TextStyle(fontWeight: FontWeight.bold)),
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

  // ── Promo Card ──
  Widget _buildPromoCard(Map<String, dynamic> promo) {
    final sku = promo['lista_products_sku'];
    final variant = sku?['lista_product_variants'];
    final base = variant?['lista_products_base'];
    final market = promo['lista_supermarkets'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(base?['icon_emoji'] ?? '🏷️', style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(variant?['variant_name'] ?? 'Produto', style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(market?['name'] ?? '', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (promo['original_price'] != null)
                Text('R\$ ${(promo['original_price'] as num).toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 11, decoration: TextDecoration.lineThrough)),
              Text('R\$ ${(promo['promo_price'] as num).toStringAsFixed(2)}',
                  style: const TextStyle(color: _accent, fontWeight: FontWeight.bold, fontSize: 16)),
              if (promo['discount_percent'] != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('-${promo['discount_percent']}%', style: TextStyle(color: Colors.orange.shade800, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final String route;
  const _QuickAction(this.label, this.icon, this.color, this.route);
}
