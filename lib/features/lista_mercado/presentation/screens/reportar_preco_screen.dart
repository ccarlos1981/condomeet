import 'dart:async';
import 'package:flutter/material.dart';
import 'package:condomeet/features/lista_mercado/lista_mercado_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shimmer/shimmer.dart';
import 'package:condomeet/features/lista_mercado/presentation/screens/product_dashboard_screen.dart';

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
  final _weightController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _supermarkets = [];
  Map<String, dynamic>? _selectedVariant;
  String? _selectedMarketId;
  bool _searching = false;
  bool _submitting = false;
  Timer? _debounce;

  // Brand & Weight state
  List<Map<String, dynamic>> _brands = [];
  String? _selectedBrandName;
  String _selectedUnit = 'kg';
  bool _loadingBrands = false;

  // Feed tab state
  List<Map<String, dynamic>> _recentPrices = [];
  bool _loadingFeed = true;
  String _feedSearchQuery = '';
  String? _feedSelectedMarketId;

  // Pontos
  Map<String, dynamic>? _myPoints;

  // Location state
  bool _loadingSupermarkets = true;
  String? _locationError;
  double? _userLat;
  double? _userLng;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSupermarketsWithLocation();
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

  Future<void> _loadSupermarketsWithLocation() async {
    setState(() {
      _loadingSupermarkets = true;
      _locationError = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Serviço de localização desativado.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Permissão negada.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Permissão negada permanentemente.');
      }

      // Buscar posição do usuário
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      _userLat = position.latitude;
      _userLng = position.longitude;

      // Busca na Edge Function do Google Places
      final markets = await _service.getNearbySupermarkets(position.latitude, position.longitude);

      // Calcular distância e ordenar do mais perto ao mais longe
      _sortByDistance(markets);
      
      if (mounted) {
        setState(() {
          _supermarkets = markets.take(10).toList();
          _loadingSupermarkets = false;
        });
      }
    } catch (e) {
      debugPrint('Erro GPS/Places: $e');
      // Fallback: Busca manual sem geolocalização se der erro ou sem permissão
      try {
        final markets = await _service.getSupermarkets();
        if (mounted) {
          setState(() {
            _supermarkets = markets;
            _locationError = 'Localização indisponível. Mostrando rede padrão.';
            _loadingSupermarkets = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _loadingSupermarkets = false;
            _locationError = 'Erro ao carregar mercados.';
          });
        }
      }
    }
  }

  void _sortByDistance(List<Map<String, dynamic>> markets) {
    if (_userLat == null || _userLng == null) return;
    for (final m in markets) {
      final lat = m['latitude'] as num?;
      final lng = m['longitude'] as num?;
      if (lat != null && lng != null) {
        final dist = Geolocator.distanceBetween(
          _userLat!, _userLng!, lat.toDouble(), lng.toDouble(),
        );
        m['_distance'] = dist;
      } else {
        m['_distance'] = double.infinity;
      }
    }
    markets.sort((a, b) =>
      ((a['_distance'] as double?) ?? double.infinity)
          .compareTo((b['_distance'] as double?) ?? double.infinity));
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.round()} m';
  }

  String _formatRelativeTime(String? isoDate) {
    if (isoDate == null) return '';
    try {
      final dt = DateTime.parse(isoDate);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'agora';
      if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'há ${diff.inHours}h';
      if (diff.inDays < 7) return 'há ${diff.inDays}d';
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }

  Future<void> _loadFeed() async {
    debugPrint('🔄 _loadFeed CALLED - marketId: $_feedSelectedMarketId, query: $_feedSearchQuery');
    setState(() => _loadingFeed = true);
    try {
      debugPrint('🔄 _loadFeed calling getRecentPrices...');
      final prices = await _service.getRecentPrices(limit: 50, marketId: _feedSelectedMarketId);
      debugPrint('🔄 _loadFeed got ${prices.length} prices');
      
      // Filter by text locally
      List<Map<String, dynamic>> filtered = prices;
      if (_feedSearchQuery.trim().isNotEmpty) {
        final q = _feedSearchQuery.trim().toLowerCase();
        filtered = prices.where((p) {
          final sku = p['lista_products_sku'] as Map<String, dynamic>?;
          final variant = sku?['lista_product_variants'] as Map<String, dynamic>?;
          final base = variant?['lista_products_base'] as Map<String, dynamic>?;
          final productName = '${base?['name'] ?? ''} ${variant?['variant_name'] ?? ''}'.trim().toLowerCase();
          
          return productName.contains(q);
        }).toList();
      }
      
      debugPrint('🔄 _loadFeed filtered to ${filtered.length} items');
      if (mounted) setState(() { _recentPrices = filtered; _loadingFeed = false; });
    } catch (e, stackTrace) {
      debugPrint('❌ _loadFeed error: $e');
      debugPrint('❌ _loadFeed stack: $stackTrace');
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

  Future<void> _loadBrandsForCategory(String category) async {
    setState(() => _loadingBrands = true);
    try {
      // Try exact category match, then fallback mappings
      var brands = await _service.getBrandsByCategory(category);
      if (brands.isEmpty) {
        // Category name mapping for brands table
        final mapping = {
          'cereais': 'cereais',
          'carnes': 'carnes',
          'laticínios': 'laticínios',
          'higiene': 'higiene',
          'limpeza': 'limpeza',
          'bebidas': 'bebidas',
          'massas': 'massas',
          'farinhas': 'farinhas',
          'café_manhã': 'café_manhã',
          'açúcar_doces': 'açúcar_doces',
          'congelados': 'congelados',
          'óleos_temperos': 'temperos',
          'hortifruti': 'hortifruti',
          'frios_embutidos': 'frios_embutidos',
          'enlatados_conservas': 'enlatados_conservas',
          'padaria': 'padaria',
          'pet': 'pet',
        };
        final mapped = mapping[category];
        if (mapped != null && mapped != category) {
          brands = await _service.getBrandsByCategory(mapped);
        }
      }
      if (mounted) setState(() { _brands = brands; _loadingBrands = false; });
    } catch (e) {
      if (mounted) setState(() { _brands = []; _loadingBrands = false; });
    }
  }

  Future<void> _submitPrice() async {
    if (_selectedVariant == null || _selectedMarketId == null) return;
    final price = double.tryParse(_priceController.text.replaceAll(',', '.'));
    if (price == null || price <= 0) return;

    // Build weight label
    final weightText = _weightController.text.trim();
    final weightLabel = weightText.isNotEmpty ? '$weightText $_selectedUnit' : null;

    setState(() => _submitting = true);
    try {
      await _service.submitPriceReport(
        variantId: _selectedVariant!['id'],
        supermarketId: _selectedMarketId!,
        price: price,
        brand: _selectedBrandName,
        weightLabel: weightLabel,
      );
      if (mounted) {
        setState(() {
          _submitting = false;
          _selectedVariant = null;
          _selectedBrandName = null;
          _brands = [];
          _priceController.clear();
          _weightController.clear();
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
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
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
            AnimatedSize(
              duration: const Duration(milliseconds: 600),
              curve: Curves.fastLinearToSlowEaseIn,
              child: _searchResults.isNotEmpty ? Column(
                children: [
                  const SizedBox(height: 8),
                  ..._searchResults.map((product) {
                    final variants = List<Map<String, dynamic>>.from(product['lista_product_variants'] ?? []);
                    final emoji = product['icon_emoji'] ?? '🛒';
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
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
                                color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.add, color: Color(0xFF2E7D32), size: 18),
                            ),
                            title: Text(v['variant_name'] ?? '', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                            trailing: Text('${v['default_weight']} ${v['unit']}', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                            onTap: () {
                              final cat = product['category'] as String? ?? '';
                              setState(() {
                                _selectedVariant = {...v, 'icon_emoji': emoji, 'product_name': product['name'], 'category': cat};
                                _searchResults = [];
                                _selectedBrandName = null;
                                _brands = [];
                                // Pre-fill weight from variant
                                _weightController.text = '${v['default_weight'] ?? ''}';
                                _selectedUnit = v['unit'] ?? 'kg';
                                _searchController.clear();
                              });
                              _loadBrandsForCategory(cat);
                            },
                          )),
                        ],
                      ),
                    );
                  }),
                ],
              ) : const SizedBox.shrink(),
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.25)),
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

          // Step 2: Brand
          Text('2. Marca (opcional)', style: TextStyle(color: Colors.grey.shade900, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_loadingBrands)
            Shimmer.fromColors(
              baseColor: Colors.grey.shade200,
              highlightColor: Colors.white,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
              ),
            )
          else
            GestureDetector(
              onTap: _showBrandSelector,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_selectedBrandName ?? 'Genérico / Sem marca', 
                        style: TextStyle(color: _selectedBrandName == null ? Colors.grey.shade500 : Colors.grey.shade900, 
                        fontSize: 16, fontStyle: _selectedBrandName == null ? FontStyle.italic : FontStyle.normal, 
                        fontWeight: _selectedBrandName == null ? FontWeight.normal : FontWeight.w600)),
                    ),
                    Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade400),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 20),

          // Step 3: Weight/Quantity
          Text('3. Peso / Quantidade', style: TextStyle(color: Colors.grey.shade900, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: Colors.grey.shade900, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Ex: 1',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF2E7D32)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedUnit,
                    dropdownColor: Colors.white,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'kg', child: Text('kg')),
                      DropdownMenuItem(value: 'g', child: Text('g')),
                      DropdownMenuItem(value: 'L', child: Text('L')),
                      DropdownMenuItem(value: 'ml', child: Text('ml')),
                      DropdownMenuItem(value: 'un', child: Text('un')),
                      DropdownMenuItem(value: 'pct', child: Text('pct')),
                      DropdownMenuItem(value: 'cx', child: Text('cx')),
                      DropdownMenuItem(value: 'dz', child: Text('dz')),
                    ],
                    onChanged: (v) => setState(() => _selectedUnit = v ?? 'kg'),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Step 4: Select supermarket
          Text('4. Mercado', style: TextStyle(color: Colors.grey.shade900, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _loadingSupermarkets
                ? Shimmer.fromColors(
                    baseColor: Colors.grey.shade200,
                    highlightColor: Colors.white,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                    ),
                  )
                : GestureDetector(
                    onTap: _showMarketSelector,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedMarketId == null 
                                ? 'Selecione o mercado' 
                                : (_supermarkets.firstWhere((m) => m['id'] == _selectedMarketId, orElse: () => {'name': 'Mercado'})['name'] ?? ''),
                              style: TextStyle(color: _selectedMarketId == null ? Colors.grey.shade500 : Colors.grey.shade900, 
                              fontSize: 16, fontWeight: _selectedMarketId == null ? FontWeight.normal : FontWeight.w600),
                            ),
                          ),
                          Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade400),
                        ],
                      ),
                    ),
                  ),
          ),
          if (_locationError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_locationError!, style: TextStyle(color: Colors.orange.shade700, fontSize: 11)),
            ),

          const SizedBox(height: 20),

          // Step 5: Price
          Text('5. Preço', style: TextStyle(color: Colors.grey.shade900, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: Colors.grey.shade900, fontSize: 28, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              prefixText: 'R\$ ',
              prefixStyle: TextStyle(color: Colors.grey.shade400, fontSize: 20, fontWeight: FontWeight.bold),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2)),
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

  void _showBrandSelector() {
    String localSearch = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final filteredBrands = _brands.where((b) {
              final name = (b['name'] as String).toLowerCase();
              return name.contains(localSearch.toLowerCase().trim());
            }).toList();

            final bool exactMatch = filteredBrands.any((b) => (b['name'] as String).toLowerCase() == localSearch.toLowerCase().trim());
            final bool showAddCustom = localSearch.trim().isNotEmpty && !exactMatch;

            return Container(
              height: MediaQuery.of(context).size.height * 0.55,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Buscar ou digitar nova marca...',
                        prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      onChanged: (v) => setModalState(() => localSearch = v),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        ListTile(
                          dense: true,
                          leading: Icon(Icons.close, color: Colors.grey.shade400, size: 20),
                          title: Text('Genérico / Sem marca', style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
                          onTap: () {
                            setState(() => _selectedBrandName = null);
                            Navigator.pop(ctx);
                          },
                        ),
                        if (showAddCustom)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.add_circle, color: Color(0xFF2E7D32), size: 20),
                            title: Text('Adicionar "${localSearch.trim()}"', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                            onTap: () {
                              setState(() => _selectedBrandName = localSearch.trim());
                              Navigator.pop(ctx);
                            },
                          ),
                        ...filteredBrands.map((b) => ListTile(
                          dense: true,
                          title: Text(b['name'], style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.w500)),
                          onTap: () {
                            setState(() => _selectedBrandName = b['name']);
                            Navigator.pop(ctx);
                          },
                        )),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showMarketSelector() {
    String localSearch = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final filteredMarkets = _supermarkets.where((m) {
              final name = (m['name'] as String?)?.toLowerCase() ?? '';
              return name.contains(localSearch.toLowerCase().trim());
            }).toList();

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.55,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Buscar mercado...',
                        prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      onChanged: (v) => setModalState(() => localSearch = v),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredMarkets.length,
                      itemBuilder: (context, index) {
                        final m = filteredMarkets[index];
                        final dist = m['_distance'] as double?;
                        final distText = dist != null && dist != double.infinity ? _formatDistance(dist) : null;
                        
                        return ListTile(
                          dense: true,
                          title: Text(m['name'] ?? '', style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.w600)),
                          trailing: distText != null 
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(distText, style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 12)),
                              )
                            : null,
                          onTap: () {
                            setState(() { _selectedMarketId = m['id']; });
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

  void _showFeedMarketFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String localSearch = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredMarkets = _supermarkets.where((m) {
              final name = (m['name'] ?? '').toString().toLowerCase();
              return name.contains(localSearch.toLowerCase());
            }).toList();

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.7,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Filtrar feed por mercado...',
                        prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      onChanged: (v) => setModalState(() => localSearch = v),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.clear_all_rounded, color: Colors.red),
                    title: const Text('Limpar Filtro de Mercado', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    onTap: () {
                      setState(() {
                        _feedSelectedMarketId = null;
                      });
                      _loadFeed();
                      Navigator.pop(ctx);
                    },
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredMarkets.length,
                      itemBuilder: (context, index) {
                        final m = filteredMarkets[index];
                        return ListTile(
                          dense: true,
                          leading: Icon(Icons.store, color: Colors.grey.shade500),
                          title: Text(m['name'] ?? '', style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.w600)),
                          onTap: () {
                            setState(() {
                              _feedSelectedMarketId = m['id'];
                            });
                            _loadFeed();
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

  Widget _buildFeedTab() {
    return Column(
      children: [
        // Filter Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar no feed...',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (v) {
                    _feedSearchQuery = v;
                    _loadFeed();
                  },
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _showFeedMarketFilter,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _feedSelectedMarketId != null ? const Color(0xFF2E7D32).withValues(alpha: 0.1) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _feedSelectedMarketId != null ? const Color(0xFF2E7D32).withValues(alpha: 0.3) : Colors.transparent),
                  ),
                  child: Icon(Icons.storefront_rounded, size: 22, color: _feedSelectedMarketId != null ? const Color(0xFF2E7D32) : Colors.grey.shade500),
                ),
              ),
            ],
          ),
        ),
        
        // Feed List
        Expanded(
          child: _loadingFeed
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
              : _recentPrices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_rounded, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text('Nenhum preço reportado', style: TextStyle(color: Colors.grey.shade600, fontSize: 18, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          Text('Altere os filtros ou contribua!', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadFeed,
                      color: const Color(0xFF2E7D32),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _recentPrices.length,
                        itemBuilder: (ctx, i) {
          final p = _recentPrices[i];
          final sku = p['lista_products_sku'] as Map<String, dynamic>?;
          final variant = sku?['lista_product_variants'] as Map<String, dynamic>?;
          final base = variant?['lista_products_base'] as Map<String, dynamic>?;
          final market = p['lista_supermarkets'] as Map<String, dynamic>?;
          final price = (p['price'] as num?)?.toDouble() ?? 0;
          final isCurrentUser = p['reported_by'] != null && _service.currentUserId != null && p['reported_by'] == _service.currentUserId;
          
          final skuId = p['sku_id']?.toString() ?? '';
          final productName = '${base?['name'] ?? ''} ${variant?['variant_name'] ?? ''}'.trim();

          return GestureDetector(
            onTap: skuId.isEmpty ? null : () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => ProductDashboardScreen(skuId: skuId, productName: productName),
              ));
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isCurrentUser ? const Color(0xFF2E7D32).withValues(alpha: 0.3) : Colors.grey.shade100, width: isCurrentUser ? 1.5 : 1),
              boxShadow: [
                BoxShadow(
                  color: isCurrentUser ? const Color(0xFF2E7D32).withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Emjoi/Icon Container
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      alignment: Alignment.center,
                      child: Text(base?['icon_emoji'] ?? '📦', style: const TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(width: 14),
                    // Product Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${base?['name'] ?? ''} ${variant?['variant_name'] ?? ''}',
                              style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.bold, fontSize: 15, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 6),
                          // Tiny Chips for Brand and Weight
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (sku?['brand'] != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.blue.shade100)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.sell_rounded, size: 10, color: Colors.blue.shade600),
                                      const SizedBox(width: 4),
                                      Text(sku!['brand'], style: TextStyle(color: Colors.blue.shade700, fontSize: 10, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              if (sku?['weight_label'] != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade200)),
                                  child: Text(sku!['weight_label'], style: TextStyle(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.w600)),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Price and Time
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF43A047)]),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('R\$ ${price.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                        const SizedBox(height: 6),
                        Text(_formatRelativeTime(p['created_at']), style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(height: 1, color: Colors.grey.shade100),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (market != null) ...[
                      Icon(Icons.store_rounded, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(market['name'] ?? '', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                      ),
                    ] else
                      const Spacer(),
                      
                    // Dynamic Avatar / User Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCurrentUser ? Colors.amber.shade50 : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isCurrentUser ? Colors.amber.shade200 : Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(isCurrentUser ? Icons.star_rounded : Icons.person_rounded, size: 12, color: isCurrentUser ? Colors.amber.shade700 : Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(isCurrentUser ? 'Você reportou' : 'Comunidade', style: TextStyle(color: isCurrentUser ? Colors.amber.shade900 : Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ));
        },
      ),
    ),
   ),
  ],
 );
}
}
