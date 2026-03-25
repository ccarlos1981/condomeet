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
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Row(
          children: [
            Text('📊', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text('Comparar Preços', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF00C853)),
                  SizedBox(height: 16),
                  Text('Comparando preços...', style: TextStyle(color: Colors.white54)),
                  Text('Analisando mercados da região', style: TextStyle(color: Colors.white30, fontSize: 12)),
                ],
              ),
            )
          : _estimates.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('📊', style: TextStyle(fontSize: 60)),
                      const SizedBox(height: 16),
                      const Text('Sem dados de preço ainda', style: TextStyle(color: Colors.white54, fontSize: 18)),
                      const SizedBox(height: 8),
                      Text('Contribua reportando preços!', style: TextStyle(color: Colors.white30, fontSize: 14)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadEstimates,
                  color: const Color(0xFF00C853),
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
                      const Row(
                        children: [
                          Text('🏪', style: TextStyle(fontSize: 20)),
                          SizedBox(width: 8),
                          Text('Ranking por Preço', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
        gradient: const LinearGradient(colors: [Color(0xFF00C853), Color(0xFF00E676)]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: const Color(0xFF00C853).withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          const Text('🏆 MELHOR PREÇO', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
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
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Text('💰', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Possível economia', style: TextStyle(color: Colors.white54, fontSize: 13)),
                Text(
                  'R\$ ${saving.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Comparando ${_estimates.first['market_name']} vs ${_estimates.last['market_name']}',
                  style: const TextStyle(color: Colors.white30, fontSize: 11),
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
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isFirst ? const Color(0xFF00C853).withOpacity(0.4) : Colors.white10),
      ),
      child: Row(
        children: [
          // Posição
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: isFirst ? const Color(0xFF00C853).withOpacity(0.2) : Colors.white10,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: isFirst ? const Color(0xFF00C853) : Colors.white54,
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
                Text(market['market_name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Text('Cobertura: $coverage% dos itens', style: const TextStyle(color: Colors.white38, fontSize: 12)),
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
                  color: isFirst ? const Color(0xFF00C853) : Colors.white,
                  fontSize: 18, fontWeight: FontWeight.bold,
                ),
              ),
              if (index > 0)
                Text(
                  '+R\$ ${(total - (_estimates.first['total'] as double)).toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
