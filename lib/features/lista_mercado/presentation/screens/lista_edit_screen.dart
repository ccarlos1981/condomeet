import 'dart:async';
import 'package:flutter/material.dart';
import 'package:condomeet/features/lista_mercado/lista_mercado_service.dart';

class ListaEditScreen extends StatefulWidget {
  final String listId;
  const ListaEditScreen({super.key, required this.listId});

  @override
  State<ListaEditScreen> createState() => _ListaEditScreenState();
}

class _ListaEditScreenState extends State<ListaEditScreen> {
  final _service = ListaMercadoService();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  Map<String, dynamic>? _listData;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _loading = true;
  bool _searching = false;
  bool _showSearch = false;
  Timer? _debounce;

  // Estimativas por variante
  final Map<String, Map<String, dynamic>> _priceEstimates = {};

  @override
  void initState() {
    super.initState();
    _loadList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadList() async {
    setState(() => _loading = true);
    try {
      final lists = await _service.getMyLists();
      final list = lists.firstWhere((l) => l['id'] == widget.listId, orElse: () => {});
      if (mounted && list.isNotEmpty) {
        setState(() {
          _listData = list;
          _items = List<Map<String, dynamic>>.from(list['lista_shopping_list_items'] ?? []);
          _loading = false;
        });
        // Carregar estimativas de preço para cada item
        _loadPriceEstimates();
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadPriceEstimates() async {
    for (final item in _items) {
      final variantId = item['variant_id'];
      if (variantId != null && !_priceEstimates.containsKey(variantId)) {
        try {
          final estimate = await _service.getPriceEstimate(variantId);
          if (estimate != null && mounted) {
            setState(() => _priceEstimates[variantId] = estimate);
          }
        } catch (_) {}
      }
    }
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

  Future<void> _addVariantToList(String variantId) async {
    try {
      await _service.addItem(listId: widget.listId, variantId: variantId);
      _searchController.clear();
      setState(() { _searchResults = []; _showSearch = false; });
      _loadList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao adicionar: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _removeItem(String itemId) async {
    await _service.removeItem(itemId);
    _loadList();
  }

  Future<void> _toggleChecked(String itemId, bool isChecked) async {
    await _service.toggleItemChecked(itemId, isChecked);
    // Update local state immediately
    setState(() {
      final idx = _items.indexWhere((i) => i['id'] == itemId);
      if (idx != -1) _items[idx]['is_checked'] = isChecked;
    });
  }

  Future<void> _updateQuantity(String itemId, int newQty) async {
    if (newQty < 1) return;
    await _service.updateItemQuantity(itemId, newQty);
    setState(() {
      final idx = _items.indexWhere((i) => i['id'] == itemId);
      if (idx != -1) _items[idx]['quantity'] = newQty;
    });
  }

  double get _estimatedTotal {
    double total = 0;
    for (final item in _items) {
      final variantId = item['variant_id'];
      final qty = item['quantity'] as int? ?? 1;
      final estimate = _priceEstimates[variantId];
      if (estimate != null) {
        total += (estimate['avg_price'] as double) * qty;
      }
    }
    return total;
  }

  int get _itemsWithPrice {
    int count = 0;
    for (final item in _items) {
      if (_priceEstimates.containsKey(item['variant_id'])) count++;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final uncheckedItems = _items.where((i) => i['is_checked'] != true).toList();
    final checkedItems = _items.where((i) => i['is_checked'] == true).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _listData?['name'] ?? 'Lista',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.compare_arrows),
              tooltip: 'Comparar preços',
              onPressed: () {
                Navigator.pushNamed(context, '/lista-mercado/compare', arguments: widget.listId);
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C853)))
          : Column(
              children: [
                // ── Estimativa ao vivo ──
                if (_estimatedTotal > 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFF1A1A2E), Color(0xFF16213E)]),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('💰 Estimativa ao vivo', style: TextStyle(color: Colors.white54, fontSize: 12)),
                              const SizedBox(height: 2),
                              Text(
                                'R\$ ${_estimatedTotal.toStringAsFixed(2)}',
                                style: const TextStyle(color: Color(0xFF00E676), fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$_itemsWithPrice/${_items.length} com preço',
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Lista de itens ──
                Expanded(
                  child: _items.isEmpty && !_showSearch
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('📝', style: TextStyle(fontSize: 60)),
                              const SizedBox(height: 12),
                              const Text('Lista vazia', style: TextStyle(color: Colors.white54, fontSize: 18)),
                              const SizedBox(height: 8),
                              const Text('Toque + para adicionar produtos', style: TextStyle(color: Colors.white30, fontSize: 14)),
                            ],
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            // Barra de search quando expandida
                            if (_showSearch) _buildSearchSection(),

                            // Itens pendentes
                            ...uncheckedItems.map((item) => _buildItemTile(item)),

                            // Separador de comprados
                            if (checkedItems.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Row(
                                  children: [
                                    const Expanded(child: Divider(color: Colors.white12)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Text('✅ Comprados (${checkedItems.length})', style: const TextStyle(color: Colors.white30, fontSize: 13)),
                                    ),
                                    const Expanded(child: Divider(color: Colors.white12)),
                                  ],
                                ),
                              ),
                              ...checkedItems.map((item) => _buildItemTile(item)),
                            ],
                          ],
                        ),
                ),
              ],
            ),
      floatingActionButton: !_showSearch
          ? FloatingActionButton(
              onPressed: () => setState(() { _showSearch = true; }),
              backgroundColor: const Color(0xFF00C853),
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            )
          : null,
    );
  }

  Widget _buildSearchSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF00C853).withOpacity(0.4)),
          ),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 14),
                child: Icon(Icons.search, color: Color(0xFF00C853), size: 22),
              ),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Buscar produto... Ex: arroz, leite',
                    hintStyle: TextStyle(color: Colors.white30),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white38),
                onPressed: () {
                  _searchController.clear();
                  setState(() { _showSearch = false; _searchResults = []; });
                },
              ),
            ],
          ),
        ),

        // Resultados
        if (_searching)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(color: Color(0xFF00C853), strokeWidth: 2)),
          )
        else if (_searchResults.isNotEmpty) ...[
          ..._searchResults.map((product) => _buildProductResult(product)),
          const SizedBox(height: 16),
        ] else if (_searchController.text.length >= 2)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text('Nenhum produto encontrado 😕', style: TextStyle(color: Colors.white38, fontSize: 14)),
            ),
          ),
      ],
    );
  }

  Widget _buildProductResult(Map<String, dynamic> product) {
    final variants = List<Map<String, dynamic>>.from(product['lista_product_variants'] ?? []);
    final emoji = product['icon_emoji'] ?? '🛒';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header do produto
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Text(product['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(product['category'] ?? '', style: const TextStyle(color: Colors.white30, fontSize: 10)),
                ),
              ],
            ),
          ),
          // Variantes
          ...variants.map((v) => InkWell(
                onTap: () => _addVariantToList(v['id']),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C853).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add, color: Color(0xFF00C853), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(v['variant_name'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      ),
                      Text('${v['default_weight']} ${v['unit']}',
                          style: const TextStyle(color: Colors.white30, fontSize: 12)),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildItemTile(Map<String, dynamic> item) {
    final isChecked = item['is_checked'] == true;
    final variant = item['lista_product_variants'];
    final base = variant?['lista_products_base'];
    final emoji = base?['icon_emoji'] ?? '🛒';
    final name = variant?['variant_name'] ?? 'Produto';
    final qty = item['quantity'] as int? ?? 1;
    final variantId = item['variant_id'];
    final estimate = _priceEstimates[variantId];

    return Dismissible(
      key: Key(item['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.redAccent),
      ),
      onDismissed: (_) => _removeItem(item['id']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isChecked ? const Color(0xFF1A1A2E).withOpacity(0.5) : const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isChecked ? Colors.green.withOpacity(0.2) : Colors.white10),
        ),
        child: Row(
          children: [
            // Checkbox
            GestureDetector(
              onTap: () => _toggleChecked(item['id'], !isChecked),
              child: Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  color: isChecked ? const Color(0xFF00C853) : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: isChecked ? const Color(0xFF00C853) : Colors.white30, width: 2),
                ),
                child: isChecked ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
              ),
            ),
            const SizedBox(width: 12),
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            // Nome + preço
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: isChecked ? Colors.white38 : Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      decoration: isChecked ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (estimate != null)
                    Text(
                      '≈ R\$ ${(estimate['avg_price'] as double).toStringAsFixed(2)} • ${estimate['cheapest_market']}',
                      style: const TextStyle(color: Color(0xFF00C853), fontSize: 11),
                    ),
                ],
              ),
            ),
            // Quantidade
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _updateQuantity(item['id'], qty - 1),
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.remove, color: Colors.white54, size: 16),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('$qty', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                ),
                GestureDetector(
                  onTap: () => _updateQuantity(item['id'], qty + 1),
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(color: const Color(0xFF00C853).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.add, color: Color(0xFF00C853), size: 16),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
