import 'package:flutter/material.dart';
import 'package:condomeet/features/lista_mercado/lista_mercado_service.dart';

class ListaCompareScreen extends StatefulWidget {
  final String listId;
  const ListaCompareScreen({super.key, required this.listId});

  @override
  State<ListaCompareScreen> createState() => _ListaCompareScreenState();
}

class _ListaCompareScreenState extends State<ListaCompareScreen> {
  final _service = ListaMercadoService();
  List<Map<String, dynamic>> _estimates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEstimates();
  }

  Future<void> _loadEstimates() async {
    setState(() => _loading = true);
    try {
      final data = await _service.getListEstimate(widget.listId);
      if (mounted) setState(() { _estimates = data; _loading = false; });
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
            Icon(Icons.bar_chart, color: Colors.grey.shade800, size: 22),
            const SizedBox(width: 8),
            Text('Comparar Preços', style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF2E7D32)),
                  const SizedBox(height: 16),
                  Text('Comparando preços...', style: TextStyle(color: Colors.grey.shade600)),
                  Text('Analisando mercados da região', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                ],
              ),
            )
          : _estimates.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bar_chart, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('Sem dados de preço ainda', style: TextStyle(color: Colors.grey.shade600, fontSize: 18)),
                      const SizedBox(height: 8),
                      Text('Contribua reportando preços!', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadEstimates,
                  color: const Color(0xFF2E7D32),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // ── Card do mais barato ──
                      if (_estimates.isNotEmpty) _buildBestDealCard(_estimates.first),
                      const SizedBox(height: 20),

                      // ── Economia ──
                      if (_estimates.length >= 2) _buildSavingsCard(),
                      const SizedBox(height: 20),

                      // ── Ranking de mercados ──
                      Row(
                        children: [
                          Icon(Icons.store, color: Colors.grey.shade800, size: 22),
                          const SizedBox(width: 8),
                          Text('Ranking por Preço', style: TextStyle(color: Colors.grey.shade900, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._estimates.asMap().entries.map((entry) => _buildMarketCard(entry.key, entry.value)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildBestDealCard(Map<String, dynamic> best) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF43A047)]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: const Color(0xFF2E7D32).withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events, color: Colors.white70, size: 20),
              const SizedBox(width: 6),
              const Text('MELHOR PREÇO', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 8),
          Text(best['market_name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            'R\$ ${(best['total'] as double).toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
            child: Text(
              '${best['matched_items']}/${best['total_items']} itens com preço (${best['coverage']}%)',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsCard() {
    final cheapest = (_estimates.first['total'] as double);
    final mostExpensive = (_estimates.last['total'] as double);
    final saving = mostExpensive - cheapest;
    if (saving <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Icon(Icons.savings, color: Colors.amber.shade700, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Possível economia', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                Text(
                  'R\$ ${saving.toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.amber.shade800, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Comparando ${_estimates.first['market_name']} vs ${_estimates.last['market_name']}',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketCard(int index, Map<String, dynamic> market) {
    final isFirst = index == 0;
    final total = market['total'] as double;
    final coverage = market['coverage'] as int;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isFirst ? const Color(0xFF2E7D32).withOpacity(0.4) : Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Row(
        children: [
          // Posição
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: isFirst ? const Color(0xFF2E7D32).withOpacity(0.1) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: isFirst ? const Color(0xFF2E7D32) : Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(market['market_name'] ?? '', style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Text('Cobertura: $coverage% dos itens', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),
          // Preço
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'R\$ ${total.toStringAsFixed(2)}',
                style: TextStyle(
                  color: isFirst ? const Color(0xFF2E7D32) : Colors.grey.shade900,
                  fontSize: 18, fontWeight: FontWeight.bold,
                ),
              ),
              if (index > 0)
                Text(
                  '+R\$ ${(total - (_estimates.first['total'] as double)).toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.red.shade400, fontSize: 12),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
