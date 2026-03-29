import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../lista_mercado_service.dart';
import 'package:intl/intl.dart';

class ProductDashboardScreen extends StatefulWidget {
  final String skuId;
  final String productName;

  const ProductDashboardScreen({
    super.key,
    required this.skuId,
    required this.productName,
  });

  @override
  State<ProductDashboardScreen> createState() => _ProductDashboardScreenState();
}

class _ProductDashboardScreenState extends State<ProductDashboardScreen> {
  final ListaMercadoService _service = ListaMercadoService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _history = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await _service.getProductPriceHistory(widget.skuId);
      setState(() {
        _history = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)));
    }

    if (_error != null) {
      return Center(child: Text('Erro: $_error', style: const TextStyle(color: Colors.red)));
    }

    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Sem histórico', style: TextStyle(color: Colors.grey.shade600, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Nenhum preço reportado para este produto ainda.', style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Variação de Preço', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          _buildChart(),
          const SizedBox(height: 32),
          const Text('Últimos Registros', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildHistoryList(),
        ],
      ),
    );
  }

  Widget _buildChart() {
    if (_history.isEmpty) return const SizedBox();

    List<FlSpot> spots = [];
    double minPrice = double.infinity;
    double maxPrice = -double.infinity;

    for (int i = 0; i < _history.length; i++) {
        final item = _history[i];
        final price = (item['price'] as num).toDouble();
        if (price < minPrice) minPrice = price;
        if (price > maxPrice) maxPrice = price;
        spots.add(FlSpot(i.toDouble(), price));
    }

    // Add some padding to Y axis
    final padding = (maxPrice - minPrice) * 0.2;
    final minY = (minPrice - padding).clamp(0.0, double.infinity);
    final maxY = maxPrice + padding;

    return AspectRatio(
      aspectRatio: 1.5,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: padding == 0 ? 1 : padding / 2,
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= _history.length) return const SizedBox();
                  
                  if (_history.length > 5 && index % (_history.length ~/ 4) != 0) return const SizedBox();

                  final dtStr = _history[index]['created_at'];
                  if (dtStr == null) return const SizedBox();
                  final dt = DateTime.parse(dtStr.toString()).toLocal();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(DateFormat('dd/MM').format(dt), style: TextStyle(color: Colors.grey.shade600, fontSize: 10)),
                  );
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 45,
                getTitlesWidget: (value, meta) {
                  return Text('R\$ ${value.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 10));
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (_history.length - 1).toDouble() > 0 ? (_history.length - 1).toDouble() : 1, // Avoid minX == maxX
          minY: minY,
          maxY: maxY == minY ? maxY + 1 : maxY, // Avoid maxY == minY
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFF2E7D32),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: Colors.white,
                    strokeWidth: 2,
                    strokeColor: const Color(0xFF2E7D32),
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        // Reverse order to show latest first
        final item = _history[_history.length - 1 - index];
        final price = (item['price'] as num).toDouble();
        
        DateTime? dt;
        if (item['created_at'] != null) {
          dt = DateTime.tryParse(item['created_at'].toString())?.toLocal();
        }

        final storeMap = item['lista_supermarkets'];
        String storeName = 'Mercado desconhecido';
        if (storeMap is Map) {
          storeName = storeMap['name'] ?? storeName;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(storeName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    if (dt != null) ...[
                      const SizedBox(height: 4),
                      Text(DateFormat('dd/MM/yyyy HH:mm').format(dt), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    ]
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text('R\$ ${price.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }
}
