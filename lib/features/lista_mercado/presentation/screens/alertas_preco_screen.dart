import 'package:flutter/material.dart';
import 'package:condomeet/features/lista_mercado/lista_mercado_service.dart';
import 'package:geolocator/geolocator.dart';

class AlertasPrecoScreen extends StatefulWidget {
  const AlertasPrecoScreen({super.key});

  @override
  State<AlertasPrecoScreen> createState() => _AlertasPrecoScreenState();
}

class _AlertasPrecoScreenState extends State<AlertasPrecoScreen> {
  final _service = ListaMercadoService();

  List<Map<String, dynamic>> _alerts = [];
  bool _loading = true;

  // Nearby supermarkets cache
  List<Map<String, dynamic>> _nearbyMarkets = [];

  @override
  void initState() {
    super.initState();
    _loadAlerts();
    _loadNearbyMarkets();
  }

  Future<void> _loadAlerts() async {
    setState(() => _loading = true);
    try {
      final data = await _service.getMyAlerts();
      if (mounted) setState(() { _alerts = data; _loading = false; });
    } catch (e) {
      debugPrint('❌ _loadAlerts error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadNearbyMarkets() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      final markets = await _service.getNearbySupermarkets(position.latitude, position.longitude);

      for (final m in markets) {
        final lat = m['latitude'] as num?;
        final lng = m['longitude'] as num?;
        if (lat != null && lng != null) {
          final dist = Geolocator.distanceBetween(position.latitude, position.longitude, lat.toDouble(), lng.toDouble());
          m['_distance'] = dist;
        } else {
          m['_distance'] = double.infinity;
        }
      }
      markets.sort((a, b) =>
          ((a['_distance'] as double?) ?? double.infinity)
              .compareTo((b['_distance'] as double?) ?? double.infinity));

      if (mounted) setState(() => _nearbyMarkets = markets.take(10).toList());
    } catch (e) {
      debugPrint('Erro GPS Alertas: $e');
      try {
        final markets = await _service.getSupermarkets();
        if (mounted) setState(() => _nearbyMarkets = markets.take(10).toList());
      } catch (_) {}
    }
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
    return '${meters.round()} m';
  }

  Future<void> _showCreateAlertDialog() async {
    List<Map<String, dynamic>> searchResults = [];
    Map<String, dynamic>? selectedVariant;
    String? selectedMarketId;
    final priceController = TextEditingController();

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.notifications_active, color: Colors.amber.shade700, size: 24),
                    const SizedBox(width: 10),
                    Text('Novo Alerta de Preço', style: TextStyle(color: Colors.grey.shade900, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),

                // Step 1: Search product
                if (selectedVariant == null) ...[
                  TextField(
                    onChanged: (v) async {
                      if (v.length >= 2) {
                        final results = await _service.searchProducts(v);
                        setModalState(() => searchResults = results);
                      }
                    },
                    style: TextStyle(color: Colors.grey.shade900),
                    decoration: InputDecoration(
                      hintText: 'Buscar produto...',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  if (searchResults.isNotEmpty)
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        itemCount: searchResults.length,
                        itemBuilder: (ctx, i) {
                          final prod = searchResults[i];
                          final variants = List<Map<String, dynamic>>.from(prod['lista_product_variants'] ?? []);
                          return Column(
                            children: variants.map((v) => ListTile(
                              leading: Text(prod['icon_emoji'] ?? '📦', style: const TextStyle(fontSize: 22)),
                              title: Text('${prod['name']} - ${v['variant_name']}', style: TextStyle(color: Colors.grey.shade900, fontSize: 13)),
                              onTap: () => setModalState(() { selectedVariant = {...v, 'icon_emoji': prod['icon_emoji'], 'product_name': prod['name']}; }),
                            )).toList(),
                          );
                        },
                      ),
                    ),
                ],

                // Step 2: Configure alert
                if (selectedVariant != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Text(selectedVariant!['icon_emoji'] ?? '📦', style: const TextStyle(fontSize: 26)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(selectedVariant!['product_name'] ?? '', style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.bold)),
                              Text(selectedVariant!['variant_name'] ?? '', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.grey.shade400, size: 18),
                          onPressed: () => setModalState(() => selectedVariant = null),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Supermarket selector — nearby with distance
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButton<String>(
                      value: selectedMarketId,
                      hint: Text('Qualquer mercado', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      dropdownColor: Colors.white,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      items: [
                        DropdownMenuItem<String>(value: null, child: Text('Qualquer mercado', style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
                        ..._nearbyMarkets.map((m) {
                          final dist = m['_distance'] as double?;
                          final distText = (dist != null && dist != double.infinity) ? ' (${_formatDistance(dist)})' : '';
                          return DropdownMenuItem<String>(
                            value: m['id'] as String,
                            child: Text('${m['name'] ?? ''}$distText', style: TextStyle(color: Colors.grey.shade900, fontSize: 13), overflow: TextOverflow.ellipsis),
                          );
                        }),
                      ],
                      onChanged: (v) => setModalState(() => selectedMarketId = v),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Target price
                  TextField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: Colors.grey.shade900, fontSize: 20, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Preço alvo (R\$)',
                      labelStyle: TextStyle(color: Colors.grey.shade500),
                      prefixText: 'R\$ ',
                      prefixStyle: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 18),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Você será notificado quando o preço atingir ou ficar abaixo desse valor.',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                  const SizedBox(height: 16),

                  // Create button
                  SizedBox(
                    width: double.infinity, height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        final price = double.tryParse(priceController.text.replaceAll(',', '.'));
                        if (price == null || price <= 0) return;
                        try {
                          await _service.createPriceAlert(
                            variantId: selectedVariant!['id'],
                            supermarketId: selectedMarketId,
                            targetPrice: price,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          _loadAlerts();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Alerta criado com sucesso! 🔔'), backgroundColor: Color(0xFF2E7D32)),
                            );
                          }
                        } catch (e) {
                          debugPrint('❌ createPriceAlert error: $e');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Erro ao criar alerta: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_active, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text('Criar Alerta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeAlerts = _alerts.where((a) => a['is_active'] == true).toList();
    final inactiveAlerts = _alerts.where((a) => a['is_active'] != true).toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: IconThemeData(color: Colors.grey.shade800),
        title: Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.amber.shade700, size: 22),
            const SizedBox(width: 8),
            Text('Alertas de Preço', style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateAlertDialog,
        backgroundColor: const Color(0xFF2E7D32),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Novo Alerta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
          : RefreshIndicator(
              onRefresh: _loadAlerts,
              color: const Color(0xFF2E7D32),
              child: _alerts.isEmpty
                  ? _buildEmptyState()
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Info card
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade100),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.lightbulb_outline, color: Colors.blue.shade600, size: 22),
                              const SizedBox(width: 10),
                              Expanded(child: Text('Receba notificação quando o preço atingir sua meta!',
                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Active alerts
                        if (activeAlerts.isNotEmpty) ...[
                          _buildSectionHeader(Icons.hourglass_top, 'Monitorando', activeAlerts.length),
                          ...activeAlerts.map((a) => _buildAlertCard(a, 'active')),
                          const SizedBox(height: 16),
                        ],

                        // Inactive
                        if (inactiveAlerts.isNotEmpty) ...[
                          _buildSectionHeader(Icons.pause_circle_outline, 'Inativos', inactiveAlerts.length),
                          ...inactiveAlerts.map((a) => _buildAlertCard(a, 'inactive')),
                        ],

                        const SizedBox(height: 80), // FAB space
                      ],
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Nenhum alerta ainda', style: TextStyle(color: Colors.grey.shade800, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Crie um alerta para ser notificado\nquando o preço de um produto cair!',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showCreateAlertDialog,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Criar Primeiro Alerta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(title, style: TextStyle(color: Colors.grey.shade900, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)),
            child: Text('$count', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert, String status) {
    final variant = alert['lista_product_variants'] as Map<String, dynamic>?;
    final base = variant?['lista_products_base'] as Map<String, dynamic>?;
    final emoji = base?['icon_emoji'] ?? '📦';
    final productName = base?['name'] ?? '';
    final variantName = variant?['variant_name'] ?? '';
    final targetPrice = (alert['target_price'] as num?)?.toDouble() ?? 0;
    final isActive = alert['is_active'] == true;

    Color borderColor;
    Color bgColor;
    switch (status) {
      case 'inactive':
        borderColor = Colors.grey.shade200;
        bgColor = Colors.grey.shade50;
        break;
      default:
        borderColor = Colors.amber.shade200;
        bgColor = Colors.white;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$productName $variantName', style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text('Meta: R\$ ${targetPrice.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.amber.shade800, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          // Actions
          if (!isActive)
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF2E7D32)),
              tooltip: 'Reativar',
              onPressed: () async {
                await _service.reactivatePriceAlert(alert['id']);
                _loadAlerts();
              },
            ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red.shade300, size: 20),
            onPressed: () async {
              await _service.deletePriceAlert(alert['id']);
              _loadAlerts();
            },
          ),
        ],
      ),
    );
  }
}
