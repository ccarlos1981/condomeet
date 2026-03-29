import 'package:flutter/material.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/features/vistoria/vistoria_service.dart';

class VistoriaComparacaoScreen extends StatefulWidget {
  final String entradaId;
  final String saidaId;
  const VistoriaComparacaoScreen({
    super.key,
    required this.entradaId,
    required this.saidaId,
  });

  @override
  State<VistoriaComparacaoScreen> createState() =>
      _VistoriaComparacaoScreenState();
}

class _VistoriaComparacaoScreenState extends State<VistoriaComparacaoScreen> {
  final _service = VistoriaService();
  bool _loading = true;

  Map<String, dynamic> _entradaData = {};
  Map<String, dynamic> _saidaData = {};

  // Merged sections for display
  List<_ComparedSection> _comparedSections = [];
  int _totalChanges = 0;
  int _totalWorse = 0;
  int _totalBetter = 0;

  static const _statusLabels = {
    'ok': '✅ OK',
    'atencao': '⚠️ Atenção',
    'danificado': '❌ Danificado',
    'nao_existe': '⚪ N/A',
  };

  static const _statusSeverity = {
    'ok': 0,
    'atencao': 1,
    'danificado': 2,
    'nao_existe': -1,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _service.loadFullVistoria(widget.entradaId),
        _service.loadFullVistoria(widget.saidaId),
      ]);
      _entradaData = results[0];
      _saidaData = results[1];
      _buildComparison();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _buildComparison() {
    final entradaSecoes =
        _entradaData['secoes'] as List<Map<String, dynamic>>? ?? [];
    final saidaSecoes =
        _saidaData['secoes'] as List<Map<String, dynamic>>? ?? [];
    final entradaItens =
        _entradaData['itens'] as List<Map<String, dynamic>>? ?? [];
    final saidaItens =
        _saidaData['itens'] as List<Map<String, dynamic>>? ?? [];
    final entradaFotos =
        _entradaData['fotos'] as List<Map<String, dynamic>>? ?? [];
    final saidaFotos =
        _saidaData['fotos'] as List<Map<String, dynamic>>? ?? [];

    // Build foto maps: itemId -> list of foto URLs
    final entradaFotoMap = <String, List<String>>{};
    for (final f in entradaFotos) {
      final itemId = f['item_id'] as String? ?? '';
      entradaFotoMap.putIfAbsent(itemId, () => []);
      final url = f['foto_url'] as String? ?? '';
      if (url.isNotEmpty) entradaFotoMap[itemId]!.add(url);
    }
    final saidaFotoMap = <String, List<String>>{};
    for (final f in saidaFotos) {
      final itemId = f['item_id'] as String? ?? '';
      saidaFotoMap.putIfAbsent(itemId, () => []);
      final url = f['foto_url'] as String? ?? '';
      if (url.isNotEmpty) saidaFotoMap[itemId]!.add(url);
    }

    // Build a map of section name -> items for both
    final entradaBySection = <String, List<Map<String, dynamic>>>{};
    for (final secao in entradaSecoes) {
      final nome = secao['nome'] as String? ?? '';
      entradaBySection[nome] = entradaItens
          .where((i) => i['secao_id'] == secao['id'])
          .toList();
    }

    final saidaBySection = <String, List<Map<String, dynamic>>>{};
    for (final secao in saidaSecoes) {
      final nome = secao['nome'] as String? ?? '';
      saidaBySection[nome] = saidaItens
          .where((i) => i['secao_id'] == secao['id'])
          .toList();
    }

    // Merge all section names
    final allSections = <String>{
      ...entradaBySection.keys,
      ...saidaBySection.keys,
    };

    _comparedSections = [];
    _totalChanges = 0;
    _totalWorse = 0;
    _totalBetter = 0;

    for (final secaoNome in allSections) {
      final eItens = entradaBySection[secaoNome] ?? [];
      final sItens = saidaBySection[secaoNome] ?? [];

      // Build item map by name
      final eByName = <String, Map<String, dynamic>>{};
      for (final item in eItens) {
        eByName[item['nome'] as String? ?? ''] = item;
      }
      final sByName = <String, Map<String, dynamic>>{};
      for (final item in sItens) {
        sByName[item['nome'] as String? ?? ''] = item;
      }

      final allItemNames = <String>{...eByName.keys, ...sByName.keys};

      final comparedItems = <_ComparedItem>[];
      for (final name in allItemNames) {
        final eItem = eByName[name];
        final sItem = sByName[name];
        final eStatus = eItem?['status'] as String? ?? 'nao_existe';
        final sStatus = sItem?['status'] as String? ?? 'nao_existe';
        final eSev = _statusSeverity[eStatus] ?? 0;
        final sSev = _statusSeverity[sStatus] ?? 0;

        _ChangeType change;
        if (eStatus == sStatus) {
          change = _ChangeType.unchanged;
        } else if (sSev > eSev) {
          change = _ChangeType.worse;
          _totalWorse++;
          _totalChanges++;
        } else {
          change = _ChangeType.better;
          _totalBetter++;
          _totalChanges++;
        }

        final eItemId = eItem?['id'] as String? ?? '';
        final sItemId = sItem?['id'] as String? ?? '';

        comparedItems.add(_ComparedItem(
          name: name,
          entradaStatus: eStatus,
          saidaStatus: sStatus,
          entradaObs: eItem?['observacao'] as String? ?? '',
          saidaObs: sItem?['observacao'] as String? ?? '',
          entradaFotos: entradaFotoMap[eItemId] ?? [],
          saidaFotos: saidaFotoMap[sItemId] ?? [],
          change: change,
        ));
      }

      _comparedSections.add(_ComparedSection(
        name: secaoNome,
        items: comparedItems,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final entradaVistoria =
        _entradaData['vistoria'] as Map<String, dynamic>? ?? {};
    final saidaVistoria =
        _saidaData['vistoria'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textMain),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🔍 Comparação de Vistorias',
              style: TextStyle(
                color: AppColors.textMain,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              'Entrada vs Saída',
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                // Summary header
                _buildSummaryHeader(entradaVistoria, saidaVistoria),
                // Sections list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: _comparedSections.length,
                    itemBuilder: (ctx, idx) =>
                        _buildSectionCard(_comparedSections[idx]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryHeader(
    Map<String, dynamic> entrada,
    Map<String, dynamic> saida,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          // Dates row
          Row(
            children: [
              Expanded(
                child: _buildDateChip(
                  '📥 Entrada',
                  entrada['created_at'] as String? ?? '',
                  const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.compare_arrows, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDateChip(
                  '📤 Saída',
                  saida['created_at'] as String? ?? '',
                  const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Stats chips
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatChip(
                '$_totalChanges',
                'Alterações',
                Colors.blue,
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                '$_totalWorse',
                'Pioraram',
                Colors.red,
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                '$_totalBetter',
                'Melhoraram',
                Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateChip(String label, String dateStr, Color color) {
    final date = DateTime.tryParse(dateStr);
    final formatted = date != null
        ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
        : '—';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formatted,
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(_ComparedSection section) {
    final hasChanges = section.items.any((i) => i.change != _ChangeType.unchanged);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: hasChanges
            ? Border.all(color: Colors.red.withValues(alpha: 0.2), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hasChanges
                  ? Colors.red.withValues(alpha: 0.05)
                  : Colors.grey.shade50,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    section.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMain,
                    ),
                  ),
                ),
                if (hasChanges)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${section.items.where((i) => i.change != _ChangeType.unchanged).length} alterações',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Column headers
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: Colors.grey.shade100,
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Item',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'ENTRADA',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'SAÍDA',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ),
                SizedBox(width: 24),
              ],
            ),
          ),
          // Items
          ...section.items.map((item) => _buildComparedItem(item)),
        ],
      ),
    );
  }

  Widget _buildComparedItem(_ComparedItem item) {
    Color bgColor;
    IconData changeIcon;
    Color changeColor;

    switch (item.change) {
      case _ChangeType.worse:
        bgColor = const Color(0xFFFEF2F2);
        changeIcon = Icons.trending_down;
        changeColor = Colors.red;
        break;
      case _ChangeType.better:
        bgColor = const Color(0xFFF0FDF4);
        changeIcon = Icons.trending_up;
        changeColor = Colors.green;
        break;
      case _ChangeType.unchanged:
        bgColor = Colors.white;
        changeIcon = Icons.remove;
        changeColor = Colors.grey.shade300;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Item name
              Expanded(
                flex: 3,
                child: Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: item.change != _ChangeType.unchanged
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: AppColors.textMain,
                  ),
                ),
              ),
              // Entrada status
              Expanded(
                flex: 2,
                child: _buildStatusBadge(item.entradaStatus),
              ),
              // Saída status
              Expanded(
                flex: 2,
                child: _buildStatusBadge(item.saidaStatus),
              ),
              // Change indicator
              SizedBox(
                width: 24,
                child: Icon(changeIcon, size: 16, color: changeColor),
              ),
            ],
          ),
          // Show obs diff if changed
          if (item.change != _ChangeType.unchanged &&
              (item.entradaObs.isNotEmpty || item.saidaObs.isNotEmpty)) ...[
            const SizedBox(height: 6),
            if (item.entradaObs.isNotEmpty)
              Text(
                '📥 ${ item.entradaObs}',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            if (item.saidaObs.isNotEmpty)
              Text(
                '📤 ${item.saidaObs}',
                style: TextStyle(
                  fontSize: 10,
                  color: item.change == _ChangeType.worse
                      ? Colors.red.shade700
                      : Colors.grey.shade600,
                  fontWeight: item.change == _ChangeType.worse
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
          ],
          // Photos comparison
          if (item.entradaFotos.isNotEmpty || item.saidaFotos.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                // Empty space under Item Name to align photos
                const Expanded(flex: 3, child: SizedBox()),
                // Entrada photos (under ENTRADA column)
                Expanded(
                  flex: 2,
                  child: item.entradaFotos.isNotEmpty
                      ? SizedBox(
                          height: 50,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: item.entradaFotos.length,
                            itemBuilder: (_, i) => Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: GestureDetector(
                                onTap: () => _showFullScreenImage(context, item.entradaFotos[i]),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    item.entradaFotos[i],
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 50,
                                      height: 50,
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.broken_image, size: 16),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      : Container(
                          height: 50,
                          alignment: Alignment.center,
                          child: const Text('Sem foto', style: TextStyle(fontSize: 9, color: Colors.grey)),
                        ),
                ),
                // Saída photos (under SAÍDA column)
                Expanded(
                  flex: 2,
                  child: item.saidaFotos.isNotEmpty
                      ? SizedBox(
                          height: 50,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: item.saidaFotos.length,
                            itemBuilder: (_, i) => Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: GestureDetector(
                                onTap: () => _showFullScreenImage(context, item.saidaFotos[i]),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    item.saidaFotos[i],
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 50,
                                      height: 50,
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.broken_image, size: 16),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      : Container(
                          height: 50,
                          alignment: Alignment.center,
                          child: const Text('Sem foto', style: TextStyle(fontSize: 9, color: Colors.grey)),
                        ),
                ),
                // Empty space to align with change icon column
                const SizedBox(width: 24),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final label = _statusLabels[status] ?? status;
    Color bgColor;
    Color textColor;
    switch (status) {
      case 'ok':
        bgColor = const Color(0xFFD1FAE5);
        textColor = const Color(0xFF059669);
        break;
      case 'atencao':
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFD97706);
        break;
      case 'danificado':
        bgColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFFDC2626);
        break;
      default:
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey;
    }
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data Models ──

enum _ChangeType { unchanged, worse, better }

class _ComparedSection {
  final String name;
  final List<_ComparedItem> items;
  _ComparedSection({required this.name, required this.items});
}

class _ComparedItem {
  final String name;
  final String entradaStatus;
  final String saidaStatus;
  final String entradaObs;
  final String saidaObs;
  final List<String> entradaFotos;
  final List<String> saidaFotos;
  final _ChangeType change;

  _ComparedItem({
    required this.name,
    required this.entradaStatus,
    required this.saidaStatus,
    required this.entradaObs,
    required this.saidaObs,
    required this.entradaFotos,
    required this.saidaFotos,
    required this.change,
  });
}
