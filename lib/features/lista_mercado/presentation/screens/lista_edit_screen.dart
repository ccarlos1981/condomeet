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
  Timer? _debounce;
  String _selectedUnit = 'un';
  final _amountController = TextEditingController(text: '1');

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
    _amountController.dispose();
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
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 1.0;
    try {
      await _service.addItem(
        listId: widget.listId, 
        variantId: variantId,
        unitType: _selectedUnit,
        unitAmount: amount,
      );
      _searchController.clear();
      _amountController.text = '1';
      setState(() { _searchResults = []; _selectedUnit = 'un'; });
      _loadList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao adicionar: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _addFreeTextItem(String customName) async {
    if (customName.trim().isEmpty) return;
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 1.0;
    try {
      await _service.addFreeTextItem(
        listId: widget.listId, 
        customName: customName.trim(),
        unitType: _selectedUnit,
        unitAmount: amount,
      );
      _searchController.clear();
      _amountController.text = '1';
      setState(() { _searchResults = []; _selectedUnit = 'un'; });
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

  Future<void> _updateQuantity(String itemId, double newAmount) async {
    if (newAmount <= 0) return;
    await _service.updateItemUnit(itemId, newAmount);
    setState(() {
      final idx = _items.indexWhere((i) => i['id'] == itemId);
      if (idx != -1) _items[idx]['unit_amount'] = newAmount;
    });
  }

  double get _estimatedTotal {
    double total = 0;
    for (final item in _items) {
      final variantId = item['variant_id'];
      final qty = (item['unit_amount'] as num?)?.toDouble() ?? 1.0;
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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: IconThemeData(color: Colors.grey.shade800),
        title: Text(
          _listData?['name'] ?? 'Lista',
          style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              icon: Icon(Icons.compare_arrows, color: Colors.grey.shade700),
              tooltip: 'Comparar preços',
              onPressed: () {
                Navigator.pushNamed(context, '/lista-mercado/compare', arguments: widget.listId);
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
          : Column(
              children: [
                // ── Estimativa ao vivo ──
                if (_estimatedTotal > 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.savings_outlined, color: Colors.green.shade700, size: 18),
                                  const SizedBox(width: 6),
                                  Text('Estimativa ao vivo', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'R\$ ${_estimatedTotal.toStringAsFixed(2)}',
                                style: TextStyle(color: Colors.green.shade700, fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$_itemsWithPrice/${_items.length} com preço',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Lista de itens ──
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      // Barra de search sempre visível
                      _buildSearchSection(),

                      if (_items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text('Lista vazia', style: TextStyle(color: Colors.grey.shade600, fontSize: 18, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                Text('Busque ou digite um produto acima', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                              ],
                            ),
                          ),
                        ),

                      // Itens pendentes
                      ...uncheckedItems.map((item) => _buildItemTile(item)),

                      // Separador de comprados
                      if (checkedItems.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Expanded(child: Divider(color: Colors.grey.shade300)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
                                    const SizedBox(width: 6),
                                    Text('Comprados (${checkedItems.length})', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                                  ],
                                ),
                              ),
                              Expanded(child: Divider(color: Colors.grey.shade300)),
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
    );
  }

  Widget _buildSearchSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Campo de Busca (Sempre visível)
        Row(
          children: [
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Icon(Icons.search, color: Colors.grey),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocus,
                        style: TextStyle(color: Colors.grey.shade900),
                        decoration: InputDecoration(
                          hintText: 'Digite o nome do produto...',
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                        onChanged: _onSearchChanged,
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.grey.shade500),
                        onPressed: () {
                          _searchController.clear();
                          setState(() { _searchResults = []; });
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        
        // 2. Fileira de Quantidade
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Row(
            children: [
              Text('Quantidade:', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              Container(
                width: 80,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.bold, fontSize: 16),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Resultados
        if (_searching)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32), strokeWidth: 2)),
          )
        else if (_searchResults.isNotEmpty) ...[
          const SizedBox(height: 16),
          ..._searchResults.map((product) => _buildProductResult(product)),
          // Bring!-style: always show free-text option below results
          if (_searchController.text.length >= 2)
            _buildFreeTextButton(_searchController.text),
          const SizedBox(height: 16),
        ] else if (_searchController.text.length >= 2) ...[
          const SizedBox(height: 16),
          // No results: prominent free-text add
          _buildFreeTextButton(_searchController.text),
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Center(
              child: Text('Produto não encontrado no catálogo', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProductResult(Map<String, dynamic> product) {
    final variants = List<Map<String, dynamic>>.from(product['lista_product_variants'] ?? []);
    final emoji = product['icon_emoji'] ?? '🛒';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
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
                Text(product['name'] ?? '', style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(product['category'] ?? '', style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
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
                          color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add, color: Color(0xFF2E7D32), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(v['variant_name'] ?? '', style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                      ),
                      Text('${v['default_weight']} ${v['unit']}',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildFreeTextButton(String text) {
    final capitalized = text.trim();
    if (capitalized.isEmpty) return const SizedBox.shrink();
    final displayName = '${capitalized[0].toUpperCase()}${capitalized.substring(1)}';
    
    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.3)),
      ),
      child: InkWell(
        onTap: () => _addFreeTextItem(displayName),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add, color: Color(0xFF2E7D32), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Adicionar "$displayName"', style: TextStyle(color: const Color(0xFF2E7D32), fontWeight: FontWeight.w600, fontSize: 14)),
                    Text('Texto livre • ${_amountController.text} $_selectedUnit', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.edit_note, color: Color(0xFF2E7D32), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemTile(Map<String, dynamic> item) {
    final isChecked = item['is_checked'] == true;
    final variant = item['lista_product_variants'];
    final base = variant?['lista_products_base'];
    final customName = item['custom_name'] as String?;
    final isCustom = customName != null && customName.isNotEmpty;
    final emoji = isCustom ? '✏️' : (base?['icon_emoji'] ?? '🛒');
    final name = isCustom ? customName : (variant?['variant_name'] ?? 'Produto');
    
    // Novas colunas de unidade
    final amount = (item['unit_amount'] as num?)?.toDouble() ?? 1.0;
    final unitType = item['unit_type'] as String? ?? 'un';
    
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
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete, color: Colors.red.shade400),
      ),
      onDismissed: (_) => _removeItem(item['id']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isChecked ? Colors.grey.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isChecked ? Colors.green.shade200 : Colors.grey.shade200),
          boxShadow: isChecked ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Row(
          children: [
            // Checkbox
            GestureDetector(
              onTap: () => _toggleChecked(item['id'], !isChecked),
              child: Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  color: isChecked ? const Color(0xFF2E7D32) : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: isChecked ? const Color(0xFF2E7D32) : Colors.grey.shade400, width: 2),
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
                      color: isChecked ? Colors.grey.shade500 : Colors.grey.shade900,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      decoration: isChecked ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (isCustom && !isChecked)
                    Text('Texto livre', style: TextStyle(color: Colors.orange.shade400, fontSize: 10)),
                  if (estimate != null)
                    Text(
                      '≈ R\$ ${(estimate['avg_price'] as double).toStringAsFixed(2)} • ${estimate['cheapest_market']}',
                      style: TextStyle(color: Colors.green.shade700, fontSize: 11),
                    ),
                ],
              ),
            ),
            // Quantidade
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _updateQuantity(item['id'], (amount - 1).clamp(0.1, 999.0)),
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.remove, color: Colors.grey.shade600, size: 16),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        amount == amount.truncateToDouble() ? amount.toInt().toString() : amount.toString(),
                        style: TextStyle(color: Colors.grey.shade900, fontSize: 15, fontWeight: FontWeight.bold)
                      ),
                      Text(unitType, style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _updateQuantity(item['id'], amount + 1),
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(color: const Color(0xFF2E7D32).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.add, color: Color(0xFF2E7D32), size: 16),
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
