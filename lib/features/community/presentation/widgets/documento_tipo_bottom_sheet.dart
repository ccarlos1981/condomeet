import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/features/community/domain/models/document_type.dart';

IconData getDocumentoTipoIcon(String? iconeName) {
  switch (iconeName) {
    case 'book':
      return Icons.menu_book_outlined;
    case 'scroll':
      return Icons.article_outlined;
    case 'users':
      return Icons.groups_outlined;
    case 'megaphone':
      return Icons.campaign_outlined;
    case 'dollar-sign':
      return Icons.attach_money;
    case 'file-spreadsheet':
      return Icons.table_chart_outlined;
    case 'bar-chart':
      return Icons.bar_chart_outlined;
    case 'receipt':
      return Icons.receipt_long_outlined;
    case 'shield-check':
      return Icons.shield_outlined;
    case 'flame':
      return Icons.local_fire_department_outlined;
    case 'clipboard-check':
      return Icons.assignment_turned_in_outlined;
    case 'sparkles':
      return Icons.auto_awesome_outlined;
    case 'award':
      return Icons.military_tech_outlined;
    case 'compass':
      return Icons.architecture_outlined;
    case 'calculator':
      return Icons.calculate_outlined;
    case 'file-signature':
      return Icons.draw_outlined;
    default:
      return Icons.description_outlined;
  }
}

class DocumentoTipoBottomSheet extends StatefulWidget {
  final String condoId;
  final List<DocumentoTipo> tipos;
  final List<DocumentoTipoPrioridade> prioridades;
  final List<String> documentosTipoIds;
  final String? selectedTipoId;
  final ValueChanged<DocumentoTipo> onSelected;
  final ValueChanged<DocumentoTipo>? onTipoCreated;

  const DocumentoTipoBottomSheet({
    super.key,
    required this.condoId,
    required this.tipos,
    required this.prioridades,
    this.documentosTipoIds = const [],
    this.selectedTipoId,
    required this.onSelected,
    this.onTipoCreated,
  });

  static Future<DocumentoTipo?> show({
    required BuildContext context,
    required String condoId,
    required List<DocumentoTipo> tipos,
    required List<DocumentoTipoPrioridade> prioridades,
    List<String> documentosTipoIds = const [],
    String? selectedTipoId,
    ValueChanged<DocumentoTipo>? onTipoCreated,
  }) {
    return showModalBottomSheet<DocumentoTipo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DocumentoTipoBottomSheet(
        condoId: condoId,
        tipos: tipos,
        prioridades: prioridades,
        documentosTipoIds: documentosTipoIds,
        selectedTipoId: selectedTipoId,
        onSelected: (tipo) => Navigator.pop(context, tipo),
        onTipoCreated: onTipoCreated,
      ),
    );
  }

  @override
  State<DocumentoTipoBottomSheet> createState() => _DocumentoTipoBottomSheetState();
}

class _DocumentoTipoBottomSheetState extends State<DocumentoTipoBottomSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  late List<DocumentoTipo> _tipos;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tipos = List.from(widget.tipos);
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<DocumentoTipo> get _activeTipos => _tipos.where((t) => t.ativo).toList();

  List<DocumentoTipo> get _prioritarios {
    final prioridadeMap = <String, int>{};
    for (final p in widget.prioridades) {
      if (p.isPrioritario) prioridadeMap[p.tipoId] = p.ordem;
    }
    final list = _activeTipos.where((t) => prioridadeMap.containsKey(t.id)).toList();
    list.sort((a, b) => (prioridadeMap[a.id] ?? 0).compareTo(prioridadeMap[b.id] ?? 0));
    return list;
  }

  List<DocumentoTipo> get _maisUtilizados {
    final counts = <String, int>{};
    for (final id in widget.documentosTipoIds) {
      counts[id] = (counts[id] ?? 0) + 1;
    }
    final list = _activeTipos.where((t) => (counts[t.id] ?? 0) > 0).toList();
    list.sort((a, b) => (counts[b.id] ?? 0).compareTo(counts[a.id] ?? 0));
    return list.take(5).toList();
  }

  Map<String, List<DocumentoTipo>> get _agrupadosPorCategoria {
    final map = <String, List<DocumentoTipo>>{};
    for (final t in _activeTipos) {
      final cat = t.categoriaPadrao.isEmpty ? 'Outros' : t.categoriaPadrao;
      map.putIfAbsent(cat, () => []).add(t);
    }
    return map;
  }

  List<DocumentoTipo> get _filteredTipos {
    if (_searchQuery.isEmpty) return _activeTipos;
    return _activeTipos.where((t) {
      return t.nome.toLowerCase().contains(_searchQuery) ||
          (t.descricao?.toLowerCase().contains(_searchQuery) ?? false) ||
          t.categoriaPadrao.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  Future<void> _showCriarNovoTipoDialog() async {
    final nomeCtrl = TextEditingController();
    final catCtrl = TextEditingController(text: 'Manutenção');
    String iconeSelecionado = 'file-text';
    bool temValidade = false;
    bool saving = false;
    String? error;

    final icons = [
      {'name': 'file-text', 'label': 'Documento'},
      {'name': 'book', 'label': 'Manual'},
      {'name': 'scroll', 'label': 'Regimento'},
      {'name': 'users', 'label': 'Assembleia'},
      {'name': 'shield-check', 'label': 'Segurança'},
      {'name': 'flame', 'label': 'Bombeiros'},
      {'name': 'clipboard-check', 'label': 'Laudo'},
      {'name': 'sparkles', 'label': 'Limpeza'},
      {'name': 'award', 'label': 'Licença'},
      {'name': 'compass', 'label': 'Obras'},
    ];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: const [
                Icon(Icons.add_circle_outline, color: AppColors.primary, size: 22),
                SizedBox(width: 8),
                Text('Novo Tipo de Documento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Text(error!, style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Text('Nome do tipo *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: nomeCtrl,
                    decoration: InputDecoration(
                      hintText: 'Ex: Laudo do Gerador, Certificado da Piscina...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Categoria Padrão *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: catCtrl,
                    decoration: InputDecoration(
                      hintText: 'Ex: Manutenção, Segurança, Obras...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Ícone visual', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: icons.map((ic) {
                      final isSelected = iconeSelecionado == ic['name'];
                      return InkWell(
                        onTap: () => setDialogState(() => iconeSelecionado = ic['name']!),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(getDocumentoTipoIcon(ic['name']), size: 14, color: isSelected ? AppColors.primary : Colors.grey.shade700),
                              const SizedBox(width: 4),
                              Text(ic['label']!, style: TextStyle(fontSize: 11, color: isSelected ? AppColors.primary : Colors.grey.shade800, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: temValidade,
                    onChanged: (v) => setDialogState(() => temValidade = v ?? false),
                    title: const Text('Normalmente tem data de validade', style: TextStyle(fontSize: 12)),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: saving ? null : () async {
                  if (nomeCtrl.text.trim().isEmpty) {
                    setDialogState(() => error = 'Informe o nome do tipo.');
                    return;
                  }
                  setDialogState(() { saving = true; error = null; });
                  try {
                    final sb = Supabase.instance.client;
                    final res = await sb.from('documento_tipos').insert({
                      'condominio_id': widget.condoId,
                      'nome': nomeCtrl.text.trim(),
                      'categoria_padrao': catCtrl.text.trim().isEmpty ? 'Outros' : catCtrl.text.trim(),
                      'icone': iconeSelecionado,
                      'is_system': false,
                      'ativo': true,
                      'ordem': 100,
                      'normalmente_tem_validade': temValidade,
                    }).select().single();

                    final novoTipo = DocumentoTipo.fromMap(res);
                    if (mounted) {
                      setState(() {
                        _tipos.add(novoTipo);
                      });
                      widget.onTipoCreated?.call(novoTipo);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    widget.onSelected(novoTipo);
                  } catch (e) {
                    setDialogState(() {
                      saving = false;
                      error = e.toString().contains('uq_documento_tipos_condo_nome')
                          ? 'Já existe um tipo com este nome neste condomínio.'
                          : 'Erro ao criar tipo: $e';
                    });
                  }
                },
                child: saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Criar Tipo', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prioritariosList = _prioritarios;
    final maisUtilizadosList = _maisUtilizados;
    final categoriasMap = _agrupadosPorCategoria;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ── Handle ──
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // ── Header ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tipo de Documento',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                TextButton.icon(
                  onPressed: _showCriarNovoTipoDialog,
                  icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                  label: const Text('Novo Tipo', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Search Field ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar tipo de documento...',
                prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Content ──
          Expanded(
            child: _searchQuery.isNotEmpty
                ? _buildSearchResults()
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    children: [
                      // 1. Prioritários do Condomínio
                      if (prioritariosList.isNotEmpty) ...[
                        Row(
                          children: const [
                            Icon(Icons.star, size: 16, color: Colors.amber),
                            SizedBox(width: 6),
                            Text(
                              'PRIORITÁRIOS DO CONDOMÍNIO',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: prioritariosList.map((t) => _buildChipItem(t, isGold: true)).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 2. Mais Utilizados
                      if (maisUtilizadosList.isNotEmpty) ...[
                        Row(
                          children: const [
                            Icon(Icons.trending_up, size: 16, color: Colors.blue),
                            SizedBox(width: 6),
                            Text(
                              'MAIS UTILIZADOS',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: maisUtilizadosList.map((t) => _buildChipItem(t)).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 3. Todos agrupados por categoria
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        'TODOS OS TIPOS POR CATEGORIA',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 8),

                      ...categoriasMap.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  entry.key,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                                ),
                              ),
                              const SizedBox(height: 4),
                              ...entry.value.map((t) => _buildListItem(t)),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final results = _filteredTipos;
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Nenhum tipo encontrado para "$_searchQuery".',
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: results.length,
      itemBuilder: (_, i) => _buildListItem(results[i]),
    );
  }

  Widget _buildChipItem(DocumentoTipo t, {bool isGold = false}) {
    final isSelected = widget.selectedTipoId == t.id;
    return InkWell(
      onTap: () => widget.onSelected(t),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : isGold
                  ? Colors.amber.shade50
                  : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : isGold
                    ? Colors.amber.shade200
                    : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              getDocumentoTipoIcon(t.icone),
              size: 16,
              color: isSelected
                  ? Colors.white
                  : isGold
                      ? Colors.amber.shade900
                      : Colors.grey.shade700,
            ),
            const SizedBox(width: 6),
            Text(
              t.nome,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : isGold
                        ? Colors.amber.shade900
                        : Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListItem(DocumentoTipo t) {
    final isSelected = widget.selectedTipoId == t.id;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      onTap: () => widget.onSelected(t),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          getDocumentoTipoIcon(t.icone),
          size: 18,
          color: isSelected ? AppColors.primary : Colors.grey.shade700,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              t.nome,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primary : Colors.black87,
              ),
            ),
          ),
          if (!t.isSystem) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Custom', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
      subtitle: Text(
        '${t.categoriaPadrao}${t.descricao != null && t.descricao!.isNotEmpty ? " • ${t.descricao}" : ""}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: AppColors.primary, size: 20)
          : null,
    );
  }
}
