import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/features/vistoria/vistoria_service.dart';

class VistoriaEditorScreen extends StatefulWidget {
  final String vistoriaId;
  const VistoriaEditorScreen({super.key, required this.vistoriaId});

  @override
  State<VistoriaEditorScreen> createState() => _VistoriaEditorScreenState();
}

class _VistoriaEditorScreenState extends State<VistoriaEditorScreen> {
  final _service = VistoriaService();
  final _picker = ImagePicker();

  bool _loading = true;
  bool _saving = false;
  Map<String, dynamic> _vistoria = {};
  List<Map<String, dynamic>> _secoes = [];
  List<Map<String, dynamic>> _itens = [];
  List<Map<String, dynamic>> _fotos = [];
  String? _activeSecaoId;
  String? _expandedItemId;
  String? _lightboxUrl;

  static const _statusOptions = [
    {'value': 'ok', 'label': 'OK', 'icon': Icons.check_circle, 'color': Color(0xFF10B981)},
    {'value': 'atencao', 'label': 'Atenção', 'icon': Icons.warning_amber_rounded, 'color': Color(0xFFF59E0B)},
    {'value': 'danificado', 'label': 'Danificado', 'icon': Icons.cancel, 'color': Color(0xFFEF4444)},
    {'value': 'nao_existe', 'label': 'N/A', 'icon': Icons.remove_circle_outline, 'color': Color(0xFF9CA3AF)},
  ];

  Map<String, dynamic> get _limits =>
      VistoriaService.getLimits(_vistoria['plano'] as String? ?? 'free');
  bool get _isPlus => (_vistoria['plano'] as String? ?? 'free') == 'plus';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // Fetch vistoria details from the list (we already have the ID)
      final authState = context.read<AuthBloc>().state;
      final condoId = authState.condominiumId;
      if (condoId == null) return;

      final vistorias = await _service.listVistorias(condoId);
      _vistoria = vistorias.firstWhere(
        (v) => v['id'] == widget.vistoriaId,
        orElse: () => {},
      );

      _secoes = await _service.listSecoes(widget.vistoriaId);
      final secIds = _secoes.map((s) => s['id'] as String).toList();
      _itens = await _service.listItens(secIds);
      final itemIds = _itens.map((i) => i['id'] as String).toList();
      _fotos = await _service.listFotos(itemIds);

      if (_secoes.isNotEmpty && _activeSecaoId == null) {
        _activeSecaoId = _secoes.first['id'] as String;
      }

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

  List<Map<String, dynamic>> get _activeItens =>
      _itens.where((i) => i['secao_id'] == _activeSecaoId).toList()
        ..sort((a, b) => (a['posicao'] as int).compareTo(b['posicao'] as int));

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textMain),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    // Lightbox overlay
    if (_lightboxUrl != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: () => setState(() => _lightboxUrl = null),
          child: Center(
            child: InteractiveViewer(
              child: Image.network(_lightboxUrl!, fit: BoxFit.contain),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Section tabs
          _buildSecaoTabs(),
          // Items list
          Expanded(
            child: _activeItens.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: _activeItens.length,
                    itemBuilder: (context, index) =>
                        _buildItemCard(_activeItens[index]),
                  ),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.textMain),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _vistoria['titulo'] ?? 'Vistoria',
            style: const TextStyle(
              color: AppColors.textMain,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            '#${_vistoria['cod_interno'] ?? ''} · ${(_vistoria['tipo_vistoria'] as String? ?? 'entrada').toUpperCase()}',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 11,
            ),
          ),
        ],
      ),
      actions: [
        // Conclude button
        if (_vistoria['status'] != 'concluida' && _vistoria['status'] != 'assinada')
          TextButton(
            onPressed: _saving ? null : _concluirVistoria,
            child: const Text(
              'Concluir',
              style: TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppColors.textMain),
          onSelected: _handleMenuAction,
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'add_secao', child: Text('➕ Adicionar seção')),
            const PopupMenuItem(value: 'add_item', child: Text('➕ Adicionar item')),
            const PopupMenuItem(value: 'timeline', child: Text('📊 Timeline do imóvel')),
            const PopupMenuItem(value: 'share', child: Text('🔗 Compartilhar')),
          ],
        ),
      ],
    );
  }

  Widget _buildSecaoTabs() {
    if (_secoes.isEmpty) return const SizedBox.shrink();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: _secoes.map((s) {
            final isActive = s['id'] == _activeSecaoId;
            final secItens = _itens.where((i) => i['secao_id'] == s['id']);
            final okCount = secItens.where((i) => i['status'] == 'ok').length;
            final total = secItens.length;
            return GestureDetector(
              onTap: () => setState(() => _activeSecaoId = s['id'] as String),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      s['icone_emoji'] ?? '🏠',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      s['nome'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isActive ? Colors.white : AppColors.textMain,
                      ),
                    ),
                    if (total > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.white.withValues(alpha: 0.2)
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$okCount/$total',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isActive ? Colors.white : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final isExpanded = _expandedItemId == item['id'];
    final status = item['status'] as String? ?? 'ok';
    final statusOpt = _statusOptions.firstWhere(
      (s) => s['value'] == status,
      orElse: () => _statusOptions.first,
    );
    final itemFotos = _fotos.where((f) => f['item_id'] == item['id']).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Item header
          InkWell(
            onTap: () => setState(() =>
                _expandedItemId = isExpanded ? null : item['id'] as String),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    statusOpt['icon'] as IconData,
                    color: statusOpt['color'] as Color,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item['nome'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textMain,
                      ),
                    ),
                  ),
                  if (itemFotos.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.camera_alt, size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 3),
                          Text(
                            '${itemFotos.length}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Expanded area
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status selector
                  const Text(
                    'Status',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: _statusOptions.map((opt) {
                      final selected = status == opt['value'];
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => _updateItemStatus(
                            item['id'] as String,
                            opt['value'] as String,
                          ),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? (opt['color'] as Color).withValues(alpha: 0.1)
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? opt['color'] as Color
                                    : Colors.grey.shade200,
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  opt['icon'] as IconData,
                                  size: 18,
                                  color: opt['color'] as Color,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  opt['label'] as String,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: opt['color'] as Color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  // Observation
                  const SizedBox(height: 14),
                  TextField(
                    controller: TextEditingController(
                      text: item['observacao'] as String? ?? '',
                    ),
                    onChanged: (v) => _updateItemObs(item['id'] as String, v),
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Observação...',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),

                  // Photos
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Text(
                        'Fotos',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      // Camera button
                      GestureDetector(
                        onTap: () => _takePhoto(item['id'] as String),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.camera_alt,
                                  size: 14, color: AppColors.primary),
                              SizedBox(width: 4),
                              Text(
                                'Tirar Foto',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Gallery button
                      GestureDetector(
                        onTap: () => _pickPhoto(item['id'] as String),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.photo_library,
                                  size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                'Galeria',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (itemFotos.isNotEmpty)
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: itemFotos.length,
                        itemBuilder: (context, index) {
                          final foto = itemFotos[index];
                          final aiResult = foto['ai_analise'] as Map<String, dynamic>?;
                          return GestureDetector(
                            onTap: () => setState(
                                () => _lightboxUrl = foto['foto_url'] as String),
                            onLongPress: () => _confirmDeleteFoto(foto['id'] as String),
                            child: Container(
                              width: 80,
                              margin: const EdgeInsets.only(right: 6),
                              child: Column(
                                children: [
                                  Container(
                                    width: 80,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      image: DecorationImage(
                                        image: NetworkImage(foto['foto_url'] as String),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  if (aiResult != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: aiResult['dano_detectado'] == true
                                            ? const Color(0xFFFEE2E2)
                                            : const Color(0xFFD1FAE5),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        aiResult['dano_detectado'] == true
                                            ? '⚠️ ${aiResult['severidade']}'
                                            : '✅ OK',
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color: aiResult['dano_detectado'] == true
                                              ? Colors.red.shade700
                                              : Colors.green.shade700,
                                        ),
                                      ),
                                    )
                                  else if (_isPlus)
                                    GestureDetector(
                                      onTap: () => _analyzePhoto(foto, item['nome'] as String? ?? ''),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '🤖 Analisar',
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.playlist_add, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'Nenhum item nesta seção',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _showAddItemDialog(),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Adicionar Item'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Add item FAB
        FloatingActionButton(
          heroTag: 'add_item',
          onPressed: () => _showAddItemDialog(),
          backgroundColor: AppColors.primary,
          mini: true,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ],
    );
  }

  // ── Actions ──

  void _handleMenuAction(String action) {
    switch (action) {
      case 'add_secao':
        _showAddSecaoDialog();
        break;
      case 'add_item':
        _showAddItemDialog();
        break;
      case 'timeline':
        final endereco = _vistoria['endereco'] as String? ?? '';
        if (endereco.isNotEmpty) {
          Navigator.pushNamed(context, '/vistoria-timeline', arguments: endereco);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nenhum endereço cadastrado nesta vistoria'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        break;
      case 'share':
        _shareVistoria();
        break;
    }
  }

  Future<void> _updateItemStatus(String itemId, String status) async {
    setState(() {
      final idx = _itens.indexWhere((i) => i['id'] == itemId);
      if (idx >= 0) _itens[idx] = {..._itens[idx], 'status': status};
    });
    try {
      await _service.updateItem(itemId, {'status': status});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateItemObs(String itemId, String obs) async {
    // Debounced - just update locally and save
    final idx = _itens.indexWhere((i) => i['id'] == itemId);
    if (idx >= 0) _itens[idx] = {..._itens[idx], 'observacao': obs};
    try {
      await _service.updateItem(itemId, {'observacao': obs});
    } catch (_) {}
  }

  Future<void> _takePhoto(String itemId) async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (photo == null) return;
    await _uploadPhoto(itemId, File(photo.path));
  }

  Future<void> _pickPhoto(String itemId) async {
    final photo = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (photo == null) return;
    await _uploadPhoto(itemId, File(photo.path));
  }

  Future<void> _uploadPhoto(String itemId, File file) async {
    // Check plan limits
    final maxFotos = _limits['max_fotos_por_item'] as int;
    final currentFotos = _fotos.where((f) => f['item_id'] == itemId).length;
    if (currentFotos >= maxFotos) {
      _showUpgradeDialog('Limite de $maxFotos fotos por item no plano Free');
      return;
    }

    final authState = context.read<AuthBloc>().state;
    final condoId = authState.condominiumId;
    if (condoId == null) return;

    setState(() => _saving = true);
    try {
      final foto = await _service.uploadFoto(
        itemId: itemId,
        condominioId: condoId,
        vistoriaId: widget.vistoriaId,
        file: file,
        posicao: _fotos.where((f) => f['item_id'] == itemId).length,
        condoNome: _vistoria['endereco'] as String? ?? '',
      );
      setState(() {
        _fotos.add(foto);
        _saving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📸 Foto adicionada!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar foto: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _confirmDeleteFoto(String fotoId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir foto?'),
        content: const Text('Esta ação não pode ser desfeita.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _service.deleteFoto(fotoId);
              setState(() => _fotos.removeWhere((f) => f['id'] == fotoId));
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddSecaoDialog() {
    // Check plan limits
    final maxSecoes = _limits['max_secoes'] as int;
    if (_secoes.length >= maxSecoes) {
      _showUpgradeDialog('Limite de $maxSecoes seções no plano Free');
      return;
    }
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova Seção'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Ex: Quarto, Cozinha, Motor...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final nome = controller.text.trim();
              if (nome.isEmpty) return;
              Navigator.pop(ctx);
              final secao = await _service.addSecao(
                widget.vistoriaId,
                nome,
                _secoes.length,
              );
              setState(() {
                _secoes.add(secao);
                _activeSecaoId = secao['id'] as String;
              });
            },
            child: const Text('Adicionar',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog() {
    if (_activeSecaoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione ou crie uma seção primeiro'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    // Check plan limits
    final maxItens = _limits['max_itens_por_secao'] as int;
    final currentItens = _itens.where((i) => i['secao_id'] == _activeSecaoId).length;
    if (currentItens >= maxItens) {
      _showUpgradeDialog('Limite de $maxItens itens por seção no plano Free');
      return;
    }
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Novo Item'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Ex: Piso, Paredes, Janelas...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final nome = controller.text.trim();
              if (nome.isEmpty) return;
              Navigator.pop(ctx);
              final item = await _service.addItem(
                _activeSecaoId!,
                nome,
                _activeItens.length,
              );
              setState(() {
                _itens.add(item);
                _expandedItemId = item['id'] as String;
              });
            },
            child: const Text('Adicionar',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Future<void> _concluirVistoria() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Concluir Vistoria?'),
        content: const Text(
            'A vistoria será marcada como concluída e poderá ser compartilhada.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Concluir',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _service.updateStatus(widget.vistoriaId, 'concluida');
      setState(() => _vistoria['status'] = 'concluida');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Vistoria concluída!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _shareVistoria() async {
    try {
      String? token = _vistoria['link_publico_token'] as String?;
      if (token == null || token.isEmpty) {
        token = await _service.gerarLinkPublico(widget.vistoriaId);
        setState(() => _vistoria['link_publico_token'] = token);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🔗 Link: condomeet.app/vistoria/$token'),
            backgroundColor: AppColors.info,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── AI Analysis ──

  Future<void> _analyzePhoto(Map<String, dynamic> foto, String itemName) async {
    if (!_isPlus) {
      _showUpgradeDialog('Análise por IA disponível apenas no plano Plus');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🤖 Analisando com IA...'),
        backgroundColor: AppColors.info,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 10),
      ),
    );

    final result = await _service.analyzePhoto(
      foto['id'] as String,
      foto['foto_url'] as String,
      itemName,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (result != null && result['analysis'] != null) {
      final analysis = Map<String, dynamic>.from(result['analysis'] as Map);
      setState(() {
        final idx = _fotos.indexWhere((f) => f['id'] == foto['id']);
        if (idx >= 0) _fotos[idx] = {..._fotos[idx], 'ai_analise': analysis};
      });

      final dano = analysis['dano_detectado'] == true;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                dano ? Icons.warning_amber_rounded : Icons.check_circle,
                color: dano ? Colors.orange : AppColors.success,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dano ? 'Dano Detectado' : 'Item OK',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (dano) ...[                Text(
                  'Severidade: ${analysis['severidade']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
              ],
              Text(analysis['descricao'] as String? ?? ''),
              const SizedBox(height: 8),
              Text(
                '💡 ${analysis['recomendacao'] ?? ''}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível analisar a foto'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  bool _purchasing = false;

  void _showUpgradeDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Text('⭐', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text('Upgrade para Plus', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Plano Plus — R\$49,90/vistoria',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  SizedBox(height: 6),
                  Text('✅ Seções ilimitadas', style: TextStyle(fontSize: 12)),
                  Text('✅ Itens ilimitados por seção', style: TextStyle(fontSize: 12)),
                  Text('✅ Fotos ilimitadas por item', style: TextStyle(fontSize: 12)),
                  Text('✅ Análise por IA', style: TextStyle(fontSize: 12)),
                  Text('✅ Exportar PDF', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Depois'),
          ),
          StatefulBuilder(
            builder: (context, setDialogState) => ElevatedButton(
              onPressed: _purchasing ? null : () async {
                setDialogState(() => _purchasing = true);
                await _purchaseVistoriaPlus();
                setDialogState(() => _purchasing = false);
                if (mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _purchasing
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Fazer Upgrade',
                      style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  /// Purchase vistoria Plus via RevenueCat consumable product
  Future<void> _purchaseVistoriaPlus() async {
    try {
      // Get offerings from RevenueCat
      final offerings = await Purchases.getOfferings();
      
      // Look for vistoria offering or fall back to current
      final offering = offerings.getOffering('vistoria_plus') ?? offerings.current;
      if (offering == null || offering.availablePackages.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Produto não disponível no momento'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Find the vistoria_plus package (consumable)
      final package = offering.availablePackages.first;

      // Purchase
      final result = await Purchases.purchasePackage(package);
      
      // Check if purchase was successful
      if (result.customerInfo.nonSubscriptionTransactions.isNotEmpty) {
        // Update the vistoria plan in Supabase
        await _service.updateVistoriaPlano(widget.vistoriaId, 'plus');
        
        setState(() => _vistoria['plano'] = 'plus');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Upgrade realizado! Todos os recursos desbloqueados.'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().contains('PurchasesCancelled')
            ? 'Compra cancelada'
            : 'Erro na compra: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
