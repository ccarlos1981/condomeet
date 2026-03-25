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
    _searchController.dispose();
    _priceController.dispose();
    _tabController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadSupermarkets() async {
    try {
      final markets = await _service.getSupermarkets();
      if (mounted) setState(() => _supermarkets = markets);
    } catch (_) {}
  }

  Future<void> _loadFeed() async {
    setState(() => _loadingFeed = true);
    try {
      final prices = await _service.getRecentPrices();
      if (mounted) setState(() { _recentPrices = prices; _loadingFeed = false; });
    } catch (e) {
      if (mounted) setState(() => _loadingFeed = false);
    }
  }

  Future<void> _loadPoints() async {
    try {
      final pts = await _service.getMyPoints();
      if (mounted) setState(() => _myPoints = pts);
    } catch (_) {}
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _searching = true);
      try {
        final results = await _service.searchProducts(query);
        if (mounted) setState(() { _searchResults = results; _searching = false; });
      } catch (e) {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  Future<void> _submitPrice() async {
    if (_selectedVariant == null || _selectedMarketId == null) return;
    final price = double.tryParse(_priceController.text.replaceAll(',', '.'));
    if (price == null || price <= 0) return;

    setState(() => _submitting = true);
    try {
      await _service.submitPriceReport(
        variantId: _selectedVariant!['id'],
        supermarketId: _selectedMarketId!,
        price: price,
      );
      if (mounted) {
        setState(() {
          _submitting = false;
          _selectedVariant = null;
          _priceController.clear();
          _searchController.clear();
          _searchResults = [];
        });
        _loadPoints();
        _loadFeed();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preço reportado! +10 pontos'), backgroundColor: Color(0xFF2E7D32)),
        );
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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: IconThemeData(color: Colors.grey.shade800),
        title: Row(
          children: [
            Icon(Icons.price_change, color: Colors.green.shade700, size: 22),
            const SizedBox(width: 8),
            Text('Reportar Preço', style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.bold)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF2E7D32),
          labelColor: const Color(0xFF2E7D32),
          unselectedLabelColor: Colors.grey.shade500,
          tabs: const [
            Tab(text: 'Reportar'),
            Tab(text: 'Feed'),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Points banner
          if (_myPoints != null)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.star, color: Colors.amber.shade700, size: 24),
                  const SizedBox(width: 10),
                  Text('${_myPoints!['total_points'] ?? 0} pontos',
                      style: TextStyle(color: Colors.grey.shade900, fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('+10 por reporte', style: TextStyle(color: Colors.green.shade700, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

          // Step 1: Search product
          Text('1. Buscar Produto', style: TextStyle(color: Colors.grey.shade900, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          if (_selectedVariant == null) ...[
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: TextStyle(color: Colors.grey.shade900),
              decoration: InputDecoration(
                hintText: 'Ex: arroz, leite, café...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF2E7D32)),
                ),
              ),
            ),
            if (_searching)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32), strokeWidth: 2)),
              ),
            if (_searchResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              ..._searchResults.map((product) {
                final variants = List<Map<String, dynamic>>.from(product['lista_product_variants'] ?? []);
                final emoji = product['icon_emoji'] ?? '🛒';
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                        child: Text('$emoji ${product['name']}', style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      ...variants.map((v) => ListTile(
                        leading: Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.add, color: Color(0xFF2E7D32), size: 18),
                        ),
                        title: Text(v['variant_name'] ?? '', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                        trailing: Text('${v['default_weight']} ${v['unit']}', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                        onTap: () => setState(() {
                          _selectedVariant = {...v, 'icon_emoji': emoji, 'product_name': product['name']};
                          _searchResults = [];
                          _searchController.clear();
                        }),
                      )),
                    ],
                  ),
                );
              }),
            ],
          ] else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  Text(_selectedVariant!['icon_emoji'] ?? '📦', style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_selectedVariant!['product_name'] ?? '', style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.bold)),
                        Text(_selectedVariant!['variant_name'] ?? '', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey.shade500, size: 18),
                    onPressed: () => setState(() => _selectedVariant = null),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),

          // Step 2: Select supermarket
          Text('2. Mercado', style: TextStyle(color: Colors.grey.shade900, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButton<String>(
              value: _selectedMarketId,
              hint: Text('Selecione o mercado', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
              dropdownColor: Colors.white,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: _supermarkets.map((m) => DropdownMenuItem<String>(
                value: m['id'] as String,
                child: Text(m['name'] ?? '', style: TextStyle(color: Colors.grey.shade900, fontSize: 14)),
              )).toList(),
              onChanged: (v) => setState(() => _selectedMarketId = v),
            ),
          ),

          const SizedBox(height: 20),

          // Step 3: Price
          Text('3. Preço', style: TextStyle(color: Colors.grey.shade900, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: Colors.grey.shade900, fontSize: 22, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixText: 'R\$ ',
              prefixStyle: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 20),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF2E7D32)),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Submit
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _submitting || _selectedVariant == null || _selectedMarketId == null
                  ? null : _submitPrice,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                disabledBackgroundColor: Colors.grey.shade200,
              ),
              child: _submitting
                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('Reportar Preço (+10 pts)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedTab() {
    if (_loadingFeed) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)));
    }

    if (_recentPrices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Nenhum preço reportado', style: TextStyle(color: Colors.grey.shade600, fontSize: 18)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFeed,
      color: const Color(0xFF2E7D32),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _recentPrices.length,
        itemBuilder: (ctx, i) {
          final p = _recentPrices[i];
          final sku = p['lista_products_sku'] as Map<String, dynamic>?;
          final variant = sku?['lista_product_variants'] as Map<String, dynamic>?;
          final base = variant?['lista_products_base'] as Map<String, dynamic>?;
          final market = p['lista_supermarkets'] as Map<String, dynamic>?;
          final price = (p['price'] as num?)?.toDouble() ?? 0;
          final source = p['source'] ?? '';

          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Text(base?['icon_emoji'] ?? '📦', style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${base?['name'] ?? ''} ${variant?['variant_name'] ?? ''}',
                          style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
                      if (market != null)
                        Row(
                          children: [
                            Icon(Icons.store, size: 12, color: Colors.grey.shade400),
                            const SizedBox(width: 4),
                            Text(market['name'] ?? '', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                          ],
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('R\$ ${price.toStringAsFixed(2)}', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 14)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                      child: Text(source, style: TextStyle(color: Colors.grey.shade500, fontSize: 9)),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
