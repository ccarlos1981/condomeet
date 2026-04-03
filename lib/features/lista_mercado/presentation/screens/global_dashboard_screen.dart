import 'package:flutter/material.dart';
import 'package:condomeet/features/lista_mercado/lista_mercado_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:geolocator/geolocator.dart';

class GlobalDashboardScreen extends StatefulWidget {
  const GlobalDashboardScreen({super.key});

  @override
  State<GlobalDashboardScreen> createState() => _GlobalDashboardScreenState();
}

class _GlobalDashboardScreenState extends State<GlobalDashboardScreen> {
  final _service = ListaMercadoService();
  bool _loading = true;

  List<Map<String, dynamic>> _data = [];
  List<Map<String, dynamic>> _supermarkets = [];
  List<Map<String, dynamic>> _allSkus = [];

  String? _selectedMarketName;
  String? _selectedSkuId;
  int _selectedDays = 30; // 7 ou 30

  @override
  void initState() {
    super.initState();
    _loadFiltersAndData();
  }

  Future<void> _loadFiltersAndData() async {
    setState(() => _loading = true);
    try {
      // Buscar os dados brutos com base nos filtros
      final rawData = await _service.getGlobalDashboardData(
        skuId: _selectedSkuId,
        marketName: _selectedMarketName,
        days: _selectedDays,
      );

      // Carregar e padronizar supermercados com base nos citados + ordenar por distância
      if (_supermarkets.isEmpty && rawData.isNotEmpty) {
        final Map<String, Map<String, dynamic>> uniqueMarkets = {};
        for (final item in rawData) {
           final m = item['lista_supermarkets'] as Map<String, dynamic>?;
           if (m != null) {
              final rawName = m['name'] as String? ?? 'Mercado';
              final cleanName = rawName.split('-').first.split(':').first.trim();
              if (!uniqueMarkets.containsKey(cleanName)) {
                uniqueMarkets[cleanName] = {
                  'id': cleanName,
                  'name': cleanName,
                  'latitude': m['latitude'],
                  'longitude': m['longitude'],
                };
              }
           }
        }
        final list = uniqueMarkets.values.toList();
        
        try {
          bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
          if (serviceEnabled) {
            LocationPermission permission = await Geolocator.checkPermission();
            if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
               Position? pos;
               try {
                 pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium, timeLimit: const Duration(seconds: 4));
               } catch (_) {
                 pos = await Geolocator.getLastKnownPosition();
               }
               
               if (pos != null) {
                 for (var a in list) {
                   final lat = (a['latitude'] as num?)?.toDouble();
                   final lng = (a['longitude'] as num?)?.toDouble();
                   if (lat != null && lng != null) {
                     final dist = Geolocator.distanceBetween(pos.latitude, pos.longitude, lat, lng);
                     a['_distance'] = dist;
                     if (dist < 1000) {
                        a['dist_text'] = '${dist.toStringAsFixed(0)} m';
                     } else {
                        a['dist_text'] = '${(dist / 1000).toStringAsFixed(1)} km';
                     }
                   }
                 }
                 list.sort((a, b) {
                   final distA = a['_distance'] as double? ?? double.infinity;
                   final distB = b['_distance'] as double? ?? double.infinity;
                   return distA.compareTo(distB);
                 });
               } else {
                 list.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
               }
            } else {
              list.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
            }
          } else {
            list.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
          }
        } catch (e) {
          list.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
        }
        
        _supermarkets = list;
      }

      // Extract unique SKUs from the raw data to populate SKU filter if not populated yet
      if (_allSkus.isEmpty && rawData.isNotEmpty) {
        final Map<String, Map<String, dynamic>> skuMap = {};
        for (var p in rawData) {
          final skuId = p['sku_id']?.toString() ?? '';
          if (skuId.isNotEmpty && !skuMap.containsKey(skuId)) {
             final skuInfo = p['lista_products_sku'] as Map<String, dynamic>?;
             if (skuInfo != null) {
               final variant = skuInfo['lista_product_variants'] as Map<String, dynamic>?;
               final base = variant?['lista_products_base'] as Map<String, dynamic>?;
               final name = '${base?['name'] ?? ''} ${variant?['variant_name'] ?? ''}'.trim();
               skuMap[skuId] = {
                 'id': skuId,
                 'name': name,
                 'brand': skuInfo['brand'] ?? '',
                 'emoji': base?['icon_emoji'] ?? '📦',
               };
             }
          }
        }
        _allSkus = skuMap.values.toList();
        _allSkus.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
      }

      if (mounted) {
        setState(() {
          _data = rawData;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  // Aggregate data by day
  List<FlSpot> _getChartSpots() {
    if (_data.isEmpty) return [];

    Map<DateTime, List<double>> dailyPrices = {};
    for (var p in _data) {
      final dateStr = p['created_at'] as String?;
      final priceVal = p['price'] as num?;
      if (dateStr == null || priceVal == null) continue;

      final date = DateTime.parse(dateStr).toLocal();
      final dayKey = DateTime(date.year, date.month, date.day);

      if (!dailyPrices.containsKey(dayKey)) {
        dailyPrices[dayKey] = [];
      }
      dailyPrices[dayKey]!.add(priceVal.toDouble());
    }

    if (dailyPrices.isEmpty) return [];

    final sortedDates = dailyPrices.keys.toList()..sort();
    final List<FlSpot> spots = [];

    // Pegamos a primeira data como x=0
    final firstDate = sortedDates.first;

    for (var day in sortedDates) {
      final prices = dailyPrices[day]!;
      // Media diaria
      final avgPrice = prices.reduce((a, b) => a + b) / prices.length;
      final x = day.difference(firstDate).inDays.toDouble();
      spots.add(FlSpot(x, avgPrice));
    }

    return spots;
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Filtros', style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          
          // Row 1: Period
          Row(
            children: [
              Expanded(
                child: _FilterChip(
                  label: 'Últimos 7 dias',
                  selected: _selectedDays == 7,
                  onTap: () {
                    setState(() => _selectedDays = 7);
                    _loadFiltersAndData();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FilterChip(
                  label: 'Últimos 30 dias',
                  selected: _selectedDays == 30,
                  onTap: () {
                    setState(() => _selectedDays = 30);
                    _loadFiltersAndData();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Row 2: Mercado
          DropdownButtonFormField<String?>(
            initialValue: _selectedMarketName,
            isExpanded: true,
            decoration: InputDecoration(
              isDense: true,
              labelText: 'Supermercado',
              prefixIcon: Icon(Icons.storefront_rounded, color: Colors.grey.shade500),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            ),
            selectedItemBuilder: (context) {
              return [
                const Text('Todos os Mercados', overflow: TextOverflow.ellipsis),
                ..._supermarkets.map((m) => Text(m['name'] ?? '', overflow: TextOverflow.ellipsis)),
              ];
            },
            items: [
              const DropdownMenuItem(value: null, child: Text('Todos os Mercados')),
              ..._supermarkets.map((m) {
                 final hasDist = m['dist_text'] != null;
                 return DropdownMenuItem(
                   value: m['id'].toString(), 
                   child: Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Expanded(child: Text(m['name'] ?? '', overflow: TextOverflow.ellipsis)),
                       if (hasDist) ...[
                         const SizedBox(width: 8),
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                           decoration: BoxDecoration(
                             color: Colors.green.shade50,
                             borderRadius: BorderRadius.circular(12),
                           ),
                           child: Text(
                             m['dist_text'],
                             style: TextStyle(
                               fontSize: 12,
                               fontWeight: FontWeight.bold,
                               color: Colors.green.shade700,
                             ),
                           ),
                         ),
                       ],
                     ],
                   ),
                 );
              }),
            ],
            onChanged: (v) {
              setState(() => _selectedMarketName = v);
              _loadFiltersAndData();
            },
          ),
          const SizedBox(height: 12),

          // Row 3: Produto
          DropdownButtonFormField<String?>(
            initialValue: _selectedSkuId,
            isExpanded: true,
            decoration: InputDecoration(
              isDense: true,
              labelText: 'Produto Específico',
              prefixIcon: Icon(Icons.shopping_basket_rounded, color: Colors.grey.shade500),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Todos os Produtos')),
              ..._allSkus.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text('${s['emoji']} ${s['name']} ${s['brand'] != '' ? '(${s['brand']})' : ''}', overflow: TextOverflow.ellipsis))),
            ],
            onChanged: (v) {
              setState(() => _selectedSkuId = v);
              _loadFiltersAndData();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChart(List<FlSpot> spots) {
    if (spots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_graph_rounded, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Sem dados no período', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
          ],
        ),
      );
    }

    final minPrice = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxPrice = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    
    // Add padding to margins
    final yMin = (minPrice * 0.9).floorToDouble();
    final yMax = (maxPrice * 1.1).ceilToDouble();

    // Encontrar primeira data para os labels do eixo X
    DateTime firstDate = DateTime.now().subtract(Duration(days: _selectedDays));
    if (_data.isNotEmpty) {
      final str = _data.first['created_at'] as String?;
      if (str != null) firstDate = DateTime.parse(str).toLocal();
    }
    firstDate = DateTime(firstDate.year, firstDate.month, firstDate.day);

    return AspectRatio(
      aspectRatio: 1.5,
      child: LineChart(
        LineChartData(
          minY: yMin,
          maxY: yMax,
          minX: 0,
          maxX: spots.isNotEmpty ? spots.last.x : 0,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (yMax - yMin) / 4 == 0 ? 1 : (yMax - yMin) / 4,
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: spots.isNotEmpty && spots.last.x > 7 ? (spots.last.x / 4).ceilToDouble() : 1,
                getTitlesWidget: (value, meta) {
                  final date = firstDate.add(Duration(days: value.toInt()));
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('${date.day}/${date.month}', style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: (yMax - yMin) / 4 == 0 ? 1 : (yMax - yMin) / 4,
                getTitlesWidget: (value, meta) {
                  return Text('R\$${value.toStringAsFixed(1)}', style: TextStyle(color: Colors.grey.shade500, fontSize: 10));
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFF673AB7),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: const Color(0xFF673AB7),
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF673AB7).withValues(alpha: 0.3),
                    const Color(0xFF673AB7).withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => Colors.black87,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final date = firstDate.add(Duration(days: spot.x.toInt()));
                  final dateFmt = '${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}';
                  return LineTooltipItem(
                    '$dateFmt\nR\$ ${spot.y.toStringAsFixed(2)}',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    if (_data.isEmpty) return const SizedBox.shrink();

    int totalReports = _data.length;
    double sumPrice = 0;
    double minPrice = double.infinity;
    double maxPrice = 0;

    for (var p in _data) {
      final pr = (p['price'] as num?)?.toDouble() ?? 0;
      sumPrice += pr;
      if (pr < minPrice) minPrice = pr;
      if (pr > maxPrice) maxPrice = pr;
    }
    double avgPrice = sumPrice / totalReports;

    return Row(
      children: [
        Expanded(child: _InfoCard(label: 'Preço Médio', value: 'R\$ ${avgPrice.toStringAsFixed(2)}', icon: Icons.functions_rounded, color: Colors.blue)),
        const SizedBox(width: 8),
        Expanded(child: _InfoCard(label: 'Menor Preço', value: 'R\$ ${minPrice.toStringAsFixed(2)}', icon: Icons.arrow_downward_rounded, color: Colors.green)),
        const SizedBox(width: 8),
        Expanded(child: _InfoCard(label: 'Maior Preço', value: 'R\$ ${maxPrice.toStringAsFixed(2)}', icon: Icons.arrow_upward_rounded, color: Colors.red)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final spots = _getChartSpots();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Dashboard Global', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: Colors.grey.shade200, height: 1)),
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF673AB7)))
        : RefreshIndicator(
            onRefresh: _loadFiltersAndData,
            color: const Color(0xFF673AB7),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildFilters(),
                const SizedBox(height: 24),
                
                Text('Visão Geral de Preços', style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 12),
                
                _buildSummaryCards(),
                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Evolução do Preço Médio Diário', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 24),
                      _buildChart(spots),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF673AB7).withValues(alpha: 0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? const Color(0xFF673AB7) : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF673AB7) : Colors.grey.shade600,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final MaterialColor color;

  const _InfoCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color.shade400, size: 20),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
        ],
      ),
    );
  }
}
