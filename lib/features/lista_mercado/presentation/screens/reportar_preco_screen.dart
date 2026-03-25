import 'dart:async';
import 'package:flutter/material.dart';
import 'package:condomeet/features/lista_mercado/lista_mercado_service.dart';

class ReportarPrecoScreen extends StatefulWidget {
  const ReportarPrecoScreen({super.key});

  @override
  State<ReportarPrecoScreen> createState() => _ReportarPrecoScreenState();
}

class _ReportarPrecoScreenState extends State<ReportarPrecoScreen> with SingleTickerProviderStateMixin {
  final _service = ListaMercadoService();
  late TabController _tabController;

  // Reportar tab state
  final _searchController = TextEditingController();
  final _priceController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _supermarkets = [];
  Map<String, dynamic>? _selectedVariant;
  String? _selectedMarketId;
  bool _searching = false;
  bool _submitting = false;
  Timer? _debounce;

  // Feed tab state
  List<Map<String, dynamic>> _recentPrices = [];
  bool _loadingFeed = true;

  // Pontos
  Map<String, dynamic>? _myPoints;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSupermarkets();
    _loadFeed();
    _loadPoints();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _priceController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadSupermarkets() async {
    final data = await _service.getSupermarkets();
    if (mounted) setState(() => _supermarkets = data);
  }

  Future<void> _loadFeed() async {
    setState(() => _loadingFeed = true);
    final data = await _service.getRecentPrices();
    if (mounted) setState(() { _recentPrices = data; _loadingFeed = false; });
  }

  Future<void> _loadPoints() async {
    final pts = await _service.getMyPoints();
    if (mounted) setState(() => _myPoints = pts);
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.length < 2) { setState(() => _searchResults = []); return; }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _searching = true);
      final results = await _service.searchProducts(query);
      if (mounted) setState(() { _searchResults = results; _searching = false; });
    });
  }

  void _selectVariant(Map<String, dynamic> variant, Map<String, dynamic> base) {
    setState(() {
      _selectedVariant = {...variant, 'base': base};
      _searchResults = [];
      _searchController.clear();
    });
  }

  Future<void> _submitReport() async {
    if (_selectedVariant == null || _selectedMarketId == null || _priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos'), backgroundColor: Colors.orange),
      );
      return;
    }

    final price = double.tryParse(_priceController.text.replaceAll(',', '.'));
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preço inválido'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await _service.submitPriceReport(
        variantId: _selectedVariant!['id'],
        supermarketId: _selectedMarketId!,
        price: price,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [Text('✅ Preço reportado! +10 pontos 🎉')]),
            backgroundColor: Color(0xFF00C853),
          ),
        );
        setState(() {
          _selectedVariant = null;
          _selectedMarketId = null;
          _priceController.clear();
          _submitting = false;
        });
        _loadPoints();
        _loadFeed();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Row(
          children: [
            Text('📢', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text('Reportar Preço', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          if (_myPoints != null)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF00C853).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('⭐', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text('${_myPoints!['total_points'] ?? 0}', style: const TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00C853),
          labelColor: const Color(0xFF00C853),
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: '📝 Reportar'),
            Tab(text: '📋 Feed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReportTab(),
          _buildFeedTab(),
        ],
      ),
    );
  }

  Widget _buildReportTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Pontos info ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [const Color(0xFF00C853).withOpacity(0.1), const Color(0xFF00E676).withOpacity(0.05)]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF00C853).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Text('💰', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ganhe pontos reportando preços!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('+10 por preço • +2 por voto • ${_myPoints?['rank_title'] ?? 'Iniciante'}',
                        style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── 1. Selecionar produto ──
        const Text('1️⃣ Qual produto?', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (_selectedVariant != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF1E1E2E), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF00C853).withOpacity(0.4))),
            child: Row(
              children: [
                Text(_selectedVariant!['base']?['icon_emoji'] ?? '🛒', style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_selectedVariant!['variant_name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      Text(_selectedVariant!['base']?['name'] ?? '', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white38, size: 20),
                  onPressed: () => setState(() => _selectedVariant = null),
                ),
              ],
            ),
          )
        else ...[
          Container(
            decoration: BoxDecoration(color: const Color(0xFF1E1E2E), borderRadius: BorderRadius.circular(12)),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Buscar... Ex: arroz, leite, café',
                hintStyle: TextStyle(color: Colors.white30),
                prefixIcon: Icon(Icons.search, color: Color(0xFF00C853)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          if (_searching)
            const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(color: Color(0xFF00C853), strokeWidth: 2)))
          else
            ..._searchResults.map((product) {
              final variants = List<Map<String, dynamic>>.from(product['lista_product_variants'] ?? []);
              return Column(
                children: variants.map((v) => ListTile(
                  leading: Text(product['icon_emoji'] ?? '🛒', style: const TextStyle(fontSize: 22)),
                  title: Text(v['variant_name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: Text(product['name'] ?? '', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  trailing: const Icon(Icons.add_circle, color: Color(0xFF00C853)),
                  onTap: () => _selectVariant(v, product),
                )).toList(),
              );
            }),
        ],
        const SizedBox(height: 20),

        // ── 2. Selecionar supermercado ──
        const Text('2️⃣ Qual mercado?', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: const Color(0xFF1E1E2E), borderRadius: BorderRadius.circular(12)),
          child: DropdownButton<String>(
            value: _selectedMarketId,
            hint: const Text('Selecione o supermercado', style: TextStyle(color: Colors.white30)),
            dropdownColor: const Color(0xFF1E1E2E),
            isExpanded: true,
            underline: const SizedBox.shrink(),
            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00C853)),
            items: _supermarkets.map((m) => DropdownMenuItem<String>(
              value: m['id'] as String,
              child: Row(
                children: [
                  Icon(m['is_chain'] == true ? Icons.store : Icons.storefront, color: Colors.white54, size: 18),
                  const SizedBox(width: 10),
                  Text(m['name'] ?? '', style: const TextStyle(color: Colors.white)),
                ],
              ),
            )).toList(),
            onChanged: (v) => setState(() => _selectedMarketId = v),
          ),
        ),
        const SizedBox(height: 20),

        // ── 3. Preço ──
        const Text('3️⃣ Qual o preço?', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: const Color(0xFF1E1E2E), borderRadius: BorderRadius.circular(12)),
          child: TextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixText: 'R\$ ',
              prefixStyle: const TextStyle(color: Color(0xFF00C853), fontSize: 22, fontWeight: FontWeight.bold),
              hintText: '0,00',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 28),

        // ── Botão enviar ──
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submitReport,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              disabledBackgroundColor: Colors.white10,
            ),
            child: _submitting
                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send, color: Colors.white),
                      SizedBox(width: 10),
                      Text('Enviar Preço', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeedTab() {
    if (_loadingFeed) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00C853)));
    }

    if (_recentPrices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📢', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 12),
            const Text('Nenhum preço reportado ainda', style: TextStyle(color: Colors.white54, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Seja o primeiro a contribuir! 🎉', style: TextStyle(color: Colors.white30)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFeed,
      color: const Color(0xFF00C853),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _recentPrices.length,
        itemBuilder: (ctx, i) => _buildPriceCard(_recentPrices[i]),
      ),
    );
  }

  Widget _buildPriceCard(Map<String, dynamic> price) {
    final sku = price['lista_products_sku'];
    final variant = sku?['lista_product_variants'];
    final base = variant?['lista_products_base'];
    final market = price['lista_supermarkets'];
    final emoji = base?['icon_emoji'] ?? '🛒';
    final confirmations = price['confirmations'] as int? ?? 1;
    final confidence = ((price['confidence_score'] as num?)?.toDouble() ?? 0.5) * 100;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(variant?['variant_name'] ?? 'Produto', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(market?['name'] ?? '', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),
              Text('R\$ ${(price['price'] as num).toStringAsFixed(2)}',
                  style: const TextStyle(color: Color(0xFF00E676), fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          // Confiança + votos
          Row(
            children: [
              // Confiança
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: confidence >= 70 ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${confidence.round()}% confiável',
                  style: TextStyle(
                    color: confidence >= 70 ? Colors.green : Colors.orange,
                    fontSize: 11, fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('$confirmations confirmações', style: const TextStyle(color: Colors.white30, fontSize: 12)),
              const Spacer(),
              // Botões de voto
              GestureDetector(
                onTap: () async {
                  await _service.voteOnPrice(price['id'], 'confirm');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Confirmado! +2 pontos'), backgroundColor: Color(0xFF00C853), duration: Duration(seconds: 1)),
                  );
                  _loadFeed();
                  _loadPoints();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.thumb_up, color: Colors.green, size: 16),
                      SizedBox(width: 4),
                      Text('Confirmo', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () async {
                  await _service.voteOnPrice(price['id'], 'incorrect');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('❌ Reportado como incorreto'), backgroundColor: Colors.orange, duration: Duration(seconds: 1)),
                  );
                  _loadFeed();
                  _loadPoints();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.thumb_down, color: Colors.redAccent, size: 16),
                      SizedBox(width: 4),
                      Text('Errado', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
