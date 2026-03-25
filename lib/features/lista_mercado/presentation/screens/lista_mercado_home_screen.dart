import 'package:flutter/material.dart';
import 'package:condomeet/features/lista_mercado/lista_mercado_service.dart';
import 'package:condomeet/features/lista_mercado/presentation/widgets/lista_onboarding_popup.dart';

class ListaMercadoHomeScreen extends StatefulWidget {
  const ListaMercadoHomeScreen({super.key});

  @override
  State<ListaMercadoHomeScreen> createState() => _ListaMercadoHomeScreenState();
}

class _ListaMercadoHomeScreenState extends State<ListaMercadoHomeScreen> with SingleTickerProviderStateMixin {
  final _service = ListaMercadoService();
  List<Map<String, dynamic>> _lists = [];
  List<Map<String, dynamic>> _promotions = [];
  bool _loading = true;
  late AnimationController _animController;

  // Premium colors
  static const _bg = Color(0xFF0F0F1A);
  static const _surface = Color(0xFF1A1A2E);
  static const _accent = Color(0xFF00C853);
  static const _accentLight = Color(0xFF69F0AE);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ListaOnboardingPopup.showIfNeeded(context);
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
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
            backgroundColor: _surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_accent, _accentLight]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_shopping_cart, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text('Nova Lista', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Ex: Compras do Mês',
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
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
                child: Text('Cancelar', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_accent, _accentLight]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, '${controller.text.trim()}|$selectedType'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Criar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
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
            gradient: isSelected ? const LinearGradient(colors: [_accent, _accentLight]) : null,
            color: isSelected ? null : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: isSelected ? null : Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.white54, size: 18),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── Premium SliverAppBar ──
                SliverAppBar(
                  expandedHeight: 130,
                  floating: false,
                  pinned: true,
                  backgroundColor: _surface,
                  iconTheme: const IconThemeData(color: Colors.white),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.help_outline_rounded, color: Colors.white54),
                      tooltip: 'Como funciona?',
                      onPressed: () => ListaOnboardingPopup.showAlways(context),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    centerTitle: false,
                    titlePadding: const EdgeInsets.only(left: 56, bottom: 14),
                    title: const Text('Meu Mercado', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1A3A2A), _surface],
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 50, right: 20),
                          child: Icon(Icons.shopping_cart_rounded, size: 60, color: _accent.withValues(alpha: 0.15)),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Content ──
                SliverToBoxAdapter(
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    color: _accent,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── CTA: Criar Lista ──
                          _buildCTAButton(),
                          const SizedBox(height: 20),

                          // ── Quick Actions Grid (2x2) ──
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
                            _buildSectionHeader(Icons.local_fire_department_rounded, 'Promoções Perto', color: Colors.orange),
                            const SizedBox(height: 12),
                            ..._promotions.map((promo) => _buildPromoCard(promo)),
                          ],

                          // ── Empty State ──
                          if (_lists.isEmpty && _promotions.isEmpty)
                            _buildEmptyState(),

                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
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
          gradient: const LinearGradient(
            colors: [_accent, Color(0xFF00E676)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: _accent.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 6)),
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

  // ── Quick Actions 2x3 Grid ──
  Widget _buildQuickActionsGrid() {
    final actions = [
      _QuickAction('Reportar\nPreço', Icons.campaign_rounded, const Color(0xFFFF9800), '/lista-mercado/reportar'),
      _QuickAction('Escanear\nCupom', Icons.qr_code_scanner_rounded, const Color(0xFF42A5F5), '/lista-mercado/scanner'),
      _QuickAction('Ranking', Icons.emoji_events_rounded, const Color(0xFFFFD600), '/lista-mercado/ranking'),
      _QuickAction('Alertas\nde Preço', Icons.notifications_active_rounded, const Color(0xFFEF5350), '/lista-mercado/alertas'),
      _QuickAction('Compartilhar\nEconomia', Icons.share_rounded, const Color(0xFF66BB6A), '/lista-mercado/cartao'),
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
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: action.color.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(color: action.color.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: action.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(action.icon, color: action.color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              action.label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600, height: 1.2),
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
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
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
    final typeColor = list['list_type'] == 'monthly' ? Colors.blue
        : list['list_type'] == 'wholesale' ? Colors.purple : _accent;

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
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(typeIcon, color: typeColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(list['name'] ?? 'Minha Lista', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('$itemCount itens${checkedCount > 0 ? ' • $checkedCount comprados' : ''}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
                  if (itemCount > 0) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation(typeColor),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.3), size: 22),
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
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shopping_cart_outlined, size: 48, color: _accent.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 20),
          const Text('Crie sua primeira lista!', style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Compare preços e economize nas compras', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14)),
        ],
      ),
    );
  }

  // ── List Options Bottom Sheet ──
  void _showListOptions(Map<String, dynamic> list) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.edit_rounded, color: Colors.blue, size: 20),
              ),
              title: const Text('Renomear', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(ctx);
                final controller = TextEditingController(text: list['name']);
                final newName = await showDialog<String>(
                  context: context,
                  builder: (c) => AlertDialog(
                    backgroundColor: _surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text('Renomear Lista', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    content: TextField(
                      controller: controller,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c), child: Text('Cancelar', style: TextStyle(color: Colors.white.withValues(alpha: 0.5)))),
                      Container(
                        decoration: BoxDecoration(gradient: const LinearGradient(colors: [_accent, _accentLight]), borderRadius: BorderRadius.circular(12)),
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(c, controller.text.trim()),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                          child: const Text('Salvar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
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
                decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
              ),
              title: const Text('Excluir', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    backgroundColor: _surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text('Excluir Lista?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    content: Text('Essa ação não pode ser desfeita.', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Cancelar', style: TextStyle(color: Colors.white.withValues(alpha: 0.5)))),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(c, true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: const Text('Excluir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(base?['icon_emoji'] ?? '🏷️', style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(variant?['variant_name'] ?? 'Produto', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(market?['name'] ?? '', style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (promo['original_price'] != null)
                Text('R\$ ${(promo['original_price'] as num).toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11, decoration: TextDecoration.lineThrough)),
              Text('R\$ ${(promo['promo_price'] as num).toStringAsFixed(2)}',
                  style: const TextStyle(color: _accent, fontWeight: FontWeight.bold, fontSize: 16)),
              if (promo['discount_percent'] != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.orange.withValues(alpha: 0.25), Colors.deepOrange.withValues(alpha: 0.15)]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('-${promo['discount_percent']}%', style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Data class for quick actions ──
class _QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final String route;
  const _QuickAction(this.label, this.icon, this.color, this.route);
}
