import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:condomeet/features/lista_mercado/lista_mercado_service.dart';

/// Admin panel — accessible only by cristiano.santos@gmx.com
class ListaAdminScreen extends StatefulWidget {
  const ListaAdminScreen({super.key});

  static const adminEmail = 'cristiano.santos@gmx.com';

  static bool isAdmin() {
    final email = Supabase.instance.client.auth.currentUser?.email;
    return email == adminEmail;
  }

  @override
  State<ListaAdminScreen> createState() => _ListaAdminScreenState();
}

class _ListaAdminScreenState extends State<ListaAdminScreen> {
  final _service = ListaMercadoService();
  final _client = Supabase.instance.client;

  bool _loading = true;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _topUsers = [];
  List<Map<String, dynamic>> _recentPrices = [];
  List<Map<String, dynamic>> _supermarkets = [];
  Map<String, String> _userNames = {};

  @override
  void initState() {
    super.initState();
    if (!ListaAdminScreen.isAdmin()) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.pop(context));
      return;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final stats = await _service.getCommunityStats();

      // Count alerts, products, supermarkets
      final alerts = await _client.from('lista_price_alerts').select('id').limit(1000);
      final products = await _client.from('lista_products_base').select('id').limit(1000);
      final variants = await _client.from('lista_product_variants').select('id').limit(1000);
      final skus = await _client.from('lista_products_sku').select('id').limit(1000);
      final supermarkets = await _service.getSupermarkets();

      stats['total_alerts'] = (alerts as List).length;
      stats['total_products'] = (products as List).length;
      stats['total_variants'] = (variants as List).length;
      stats['total_skus'] = (skus as List).length;
      stats['total_supermarkets'] = supermarkets.length;

      // Top users
      final topUsers = await _service.getAllTimeLeaderboard(limit: 10);
      final userIds = topUsers.map((u) => u['user_id'] as String).toList();
      final names = await _service.getUserNames(userIds);

      // Recent prices
      final recent = await _service.getRecentPrices(limit: 10);

      if (mounted) {
        setState(() {
          _stats = stats;
          _topUsers = topUsers;
          _recentPrices = recent;
          _supermarkets = supermarkets;
          _userNames = names;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: IconThemeData(color: Colors.grey.shade800),
        title: Row(
          children: [
            Icon(Icons.admin_panel_settings, color: Colors.grey.shade800, size: 22),
            const SizedBox(width: 8),
            Text('Admin Lista', style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(onPressed: _loadData, icon: Icon(Icons.refresh, color: Colors.grey.shade600)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFF2E7D32),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildStatsGrid(),
                  const SizedBox(height: 20),
                  _buildTopUsers(),
                  const SizedBox(height: 20),
                  _buildRecentPrices(),
                  const SizedBox(height: 20),
                  _buildSupermarkets(),
                  const SizedBox(height: 20),
                  _buildAdminActions(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bar_chart, color: Colors.grey.shade800, size: 20),
            const SizedBox(width: 6),
            Text('Métricas', style: TextStyle(color: Colors.grey.shade900, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.3,
          mainAxisSpacing: 8, crossAxisSpacing: 8,
          children: [
            _buildStatTile(Icons.group, '${_stats['total_contributors'] ?? 0}', 'Colaboradores'),
            _buildStatTile(Icons.attach_money, '${_stats['total_prices'] ?? 0}', 'Preços'),
            _buildStatTile(Icons.notifications, '${_stats['total_alerts'] ?? 0}', 'Alertas'),
            _buildStatTile(Icons.inventory_2, '${_stats['total_products'] ?? 0}', 'Produtos'),
            _buildStatTile(Icons.list, '${_stats['total_variants'] ?? 0}', 'Variantes'),
            _buildStatTile(Icons.label, '${_stats['total_skus'] ?? 0}', 'SKUs'),
            _buildStatTile(Icons.store, '${_stats['total_supermarkets'] ?? 0}', 'Mercados'),
          ],
        ),
      ],
    );
  }

  Widget _buildStatTile(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 18),
          Text(value, style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.bold, fontSize: 18)),
          Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildTopUsers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber.shade700, size: 20),
            const SizedBox(width: 6),
            Text('Top Colaboradores', style: TextStyle(color: Colors.grey.shade900, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        ..._topUsers.asMap().entries.map((e) {
          final i = e.key;
          final u = e.value;
          final name = _userNames[u['user_id']] ?? 'Anônimo';
          final pts = u['total_points'] as int? ?? 0;
          final reports = u['reports_count'] as int? ?? 0;
          final rank = u['rank_title'] ?? 'Iniciante';

          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Text('#${i + 1}', style: TextStyle(color: i < 3 ? Colors.amber.shade700 : Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('$rank • $reports reportes', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                  ],
                )),
                Text('$pts pts', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRecentPrices() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.edit_note, color: Colors.grey.shade800, size: 20),
            const SizedBox(width: 6),
            Text('Últimos Preços', style: TextStyle(color: Colors.grey.shade900, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        ..._recentPrices.map((p) {
          final sku = p['lista_products_sku'] as Map<String, dynamic>?;
          final variant = sku?['lista_product_variants'] as Map<String, dynamic>?;
          final base = variant?['lista_products_base'] as Map<String, dynamic>?;
          final price = (p['price'] as num?)?.toDouble() ?? 0;
          final source = p['source'] ?? '';

          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Text(base?['icon_emoji'] ?? '📦', style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(child: Text('${base?['name'] ?? ''} ${variant?['variant_name'] ?? ''}',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12), overflow: TextOverflow.ellipsis)),
                Text('R\$ ${price.toStringAsFixed(2)}', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                  child: Text(source, style: TextStyle(color: Colors.grey.shade500, fontSize: 9)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSupermarkets() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.store, color: Colors.grey.shade800, size: 20),
            const SizedBox(width: 6),
            Text('Mercados', style: TextStyle(color: Colors.grey.shade900, fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            TextButton(onPressed: _showAddSupermarketDialog,
                child: Text('+ Adicionar', style: TextStyle(color: Colors.green.shade700, fontSize: 13))),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _supermarkets.map((m) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(m['name'] ?? '', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildAdminActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.build, color: Colors.grey.shade800, size: 20),
            const SizedBox(width: 6),
            Text('Ações', style: TextStyle(color: Colors.grey.shade900, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        _buildActionButton('Adicionar Produto Base', Icons.add_box, () => _showAddProductDialog()),
        const SizedBox(height: 8),
        _buildActionButton('Adicionar Mercado', Icons.store, () => _showAddSupermarketDialog()),
        const SizedBox(height: 8),
        _buildActionButton('Enviar Push para Usuários', Icons.notifications_active, () => _showSendPushDialog()),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF2E7D32), size: 22),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: Colors.grey.shade900, fontSize: 14)),
            const Spacer(),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddSupermarketDialog() async {
    final nameCtl = TextEditingController();
    final cnpjCtl = TextEditingController();
    final addrCtl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.store, color: Colors.grey.shade800, size: 22),
            const SizedBox(width: 8),
            Text('Novo Mercado', style: TextStyle(color: Colors.grey.shade900)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogField(nameCtl, 'Nome do mercado'),
            const SizedBox(height: 10),
            _buildDialogField(cnpjCtl, 'CNPJ (opcional)'),
            const SizedBox(height: 10),
            _buildDialogField(addrCtl, 'Endereço (opcional)'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancelar', style: TextStyle(color: Colors.grey.shade600))),
          ElevatedButton(
            onPressed: () async {
              if (nameCtl.text.trim().isEmpty) return;
              await _client.from('lista_supermarkets').insert({
                'name': nameCtl.text.trim(),
                'cnpj': cnpjCtl.text.trim().isEmpty ? null : cnpjCtl.text.trim(),
                'address': addrCtl.text.trim().isEmpty ? null : addrCtl.text.trim(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
              _loadData();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
            child: const Text('Salvar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddProductDialog() async {
    final nameCtl = TextEditingController();
    final catCtl = TextEditingController();
    String selectedEmoji = '📦';
    final emojis = ['🍚', '🫘', '🥛', '🍖', '🍗', '🥩', '🧀', '🍞', '🥚', '🍝', '🥫', '🧈', '☕', '🍺', '🧃', '🧹', '🧼', '📦'];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.inventory_2, color: Colors.grey.shade800, size: 22),
              const SizedBox(width: 8),
              Text('Novo Produto', style: TextStyle(color: Colors.grey.shade900)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField(nameCtl, 'Nome do produto'),
              const SizedBox(height: 10),
              _buildDialogField(catCtl, 'Categoria (ex: grãos)'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: emojis.map((e) => GestureDetector(
                  onTap: () => setDialogState(() => selectedEmoji = e),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: selectedEmoji == e ? const Color(0xFF2E7D32).withValues(alpha: 0.15) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: selectedEmoji == e ? const Color(0xFF2E7D32) : Colors.transparent),
                    ),
                    child: Center(child: Text(e, style: const TextStyle(fontSize: 18))),
                  ),
                )).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancelar', style: TextStyle(color: Colors.grey.shade600))),
            ElevatedButton(
              onPressed: () async {
                if (nameCtl.text.trim().isEmpty) return;
                await _client.from('lista_products_base').insert({
                  'name': nameCtl.text.trim(),
                  'category': catCtl.text.trim().isEmpty ? 'outros' : catCtl.text.trim(),
                  'icon_emoji': selectedEmoji,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
              child: const Text('Salvar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSendPushDialog() async {
    final titleCtl = TextEditingController(text: 'Lista Inteligente');
    final bodyCtl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.grey.shade800, size: 22),
            const SizedBox(width: 8),
            Text('Push Segmentado', style: TextStyle(color: Colors.grey.shade900)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogField(titleCtl, 'Título'),
            const SizedBox(height: 10),
            TextField(
              controller: bodyCtl,
              maxLines: 3,
              style: TextStyle(color: Colors.grey.shade900),
              decoration: InputDecoration(
                hintText: 'Mensagem...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true, fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 8),
            Text('Push será enviado apenas para usuários que reportaram preços.',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancelar', style: TextStyle(color: Colors.grey.shade600))),
          ElevatedButton(
            onPressed: () async {
              if (bodyCtl.text.trim().isEmpty) return;
              // Get user IDs from lista_user_points (only active users)
              final users = await _client.from('lista_user_points').select('user_id');
              final userIds = (users as List).map((u) => u['user_id'] as String).toList();

              if (userIds.isEmpty) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Nenhum usuário ativo'), backgroundColor: Colors.orange),
                  );
                }
                return;
              }

              // Send push via existing FCM function
              try {
                await _client.functions.invoke('parcel-push-notify', body: {
                  'user_ids': userIds,
                  'title': titleCtl.text.trim(),
                  'body': bodyCtl.text.trim(),
                  'data': {'type': 'lista_mercado_promo'},
                });
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Push enviado para ${userIds.length} usuários!'), backgroundColor: const Color(0xFF2E7D32)),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
            child: const Text('Enviar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogField(TextEditingController ctl, String hint) {
    return TextField(
      controller: ctl,
      style: TextStyle(color: Colors.grey.shade900),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400),
        filled: true, fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }
}
