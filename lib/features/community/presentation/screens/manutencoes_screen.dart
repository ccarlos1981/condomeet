import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/core/di/injection_container.dart';

class ManutencoesScreen extends StatefulWidget {
  const ManutencoesScreen({super.key});

  @override
  State<ManutencoesScreen> createState() => _ManutencoesScreenState();
}

class _ManutencoesScreenState extends State<ManutencoesScreen> {
  final _supabase = sl<SupabaseClient>();
  
  List<Map<String, dynamic>> _manutencoes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final profile = await _supabase
        .from('perfil')
        .select('condominio_id')
        .eq('id', user.id)
        .maybeSingle();

    final condoId = profile?['condominio_id'] as String?;
    if (condoId == null) { setState(() => _loading = false); return; }

    final data = await _supabase
        .from('manutencoes')
        .select('*')
        .eq('condominio_id', condoId)
        .eq('visivel_moradores', true)
        .order('data_inicio', ascending: false);

    setState(() {
      _manutencoes = List<Map<String, dynamic>>.from(data as List);
      _loading = false;
    });
  }

  void _showDetails(Map<String, dynamic> m) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: _ManutencaoDetailSheet(manutencao: m),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Histórico de Manutenção',
          style: TextStyle(
            color: AppColors.textMain,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 20),
            onPressed: () { _load(); },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: _manutencoes.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 100),
                      Icon(Icons.build_circle_outlined, size: 64, color: AppColors.disabledIcon),
                      SizedBox(height: 16),
                      Text('Nenhuma manutenção visível', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textHint)),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _manutencoes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final m = _manutencoes[index];
                        return _buildCard(m);
                      },
                    ),
            ),
    );
  }

  Widget _buildCard(Map<String, dynamic> m) {
    return GestureDetector(
      onTap: () => _showDetails(m),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.build_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m['titulo'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textMain),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatDate(m['data_inicio'])} até ${_formatDate(m['data_fim'])}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildStatus(m['status'] ?? ''),
                const SizedBox(height: 8),
                const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatus(String status) {
    Color color;
    Color bgColor;
    if (status == 'Concluída') {
      color = Colors.green.shade700;
      bgColor = Colors.green.shade50;
    } else if (status == 'Em Andamento') {
      color = Colors.blue.shade700;
      bgColor = Colors.blue.shade50;
    } else {
      color = Colors.orange.shade700;
      bgColor = Colors.orange.shade50;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '-';
    try {
      final d = DateTime.parse(dateStr.toString());
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year.toString().substring(2)}';
    } catch (_) {
      return '-';
    }
  }
}

class _ManutencaoDetailSheet extends StatefulWidget {
  final Map<String, dynamic> manutencao;
  const _ManutencaoDetailSheet({required this.manutencao});

  @override
  State<_ManutencaoDetailSheet> createState() => _ManutencaoDetailSheetState();
}

class _ManutencaoDetailSheetState extends State<_ManutencaoDetailSheet> {
  int _tabIndex = 0; // 0: Geral, 1: Fotos, 2: Comentarios
  final _supabase = sl<SupabaseClient>();
  
  List<Map<String, dynamic>> _fotos = [];
  bool _loadingFotos = false;

  List<Map<String, dynamic>> _comentarios = [];
  bool _loadingComments = false;
  
  final _commentController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Default tab is 0, no need to fetch until changed
  }
  
  void _setTab(int index) {
    setState(() { _tabIndex = index; });
    if (index == 1 && _fotos.isEmpty) _fetchFotos();
    if (index == 2 && _comentarios.isEmpty) _fetchComentarios();
  }

  Future<void> _fetchFotos() async {
    setState(() => _loadingFotos = true);
    try {
      final data = await _supabase
          .from('manutencao_fotos')
          .select('*')
          .eq('manutencao_id', widget.manutencao['id'])
          .order('ordem', ascending: true);
      if (mounted) {
        setState(() { 
          _fotos = List<Map<String, dynamic>>.from(data as List); 
        });
      }
    } catch (e) {
      debugPrint('Error fetching photos: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingFotos = false);
      }
    }
  }

  Future<void> _fetchComentarios() async {
    setState(() => _loadingComments = true);
    try {
      final data = await _supabase
          .from('manutencao_comentarios')
          .select('id, texto, created_at, perfil(nome_completo, papel_sistema)')
          .eq('manutencao_id', widget.manutencao['id'])
          .order('created_at', ascending: true);
      if (mounted) {
        setState(() { 
          _comentarios = List<Map<String, dynamic>>.from(data as List); 
        });
      }
    } catch (e) {
      debugPrint('Error fetching comments: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingComments = false);
      }
    }
  }

  Future<void> _sendComment() async {
    if (_commentController.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    final user = _supabase.auth.currentUser;
    if (user != null) {
      await _supabase.from('manutencao_comentarios').insert({
        'manutencao_id': widget.manutencao['id'],
        'perfil_id': user.id,
        'texto': _commentController.text.trim(),
      });
      _commentController.clear();
      await _fetchComentarios();
    }
    if (mounted) setState(() => _submitting = false);
  }

  String _formatDateTime(dynamic dateStr) {
    if (dateStr == null) return '-';
    try {
      final d = DateTime.parse(dateStr.toString());
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} as ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              const Expanded(child: Text('Detalhes', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain))),
              IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
        // Tabs
        Row(
          children: [
            _buildTab(0, 'Geral'),
            _buildTab(1, 'Fotos'),
            _buildTab(2, 'Comentários'),
          ],
        ),
        const Divider(height: 1),
        // Content
        Expanded(
          child: IndexedStack(
            index: _tabIndex,
            children: [
              _buildGeral(),
              _buildFotos(),
              _buildComentarios(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTab(int index, String label) {
    final active = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _setTab(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: active ? AppColors.primary : Colors.transparent, width: 2)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: active ? AppColors.primary : Colors.grey.shade500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGeral() {
    final m = widget.manutencao;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSection('Manutenção', m['titulo']),
        const SizedBox(height: 16),
        _buildSection('Descrição', m['descricao'] ?? '-'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildSection('Início', _formatDateTime(m['data_inicio']))),
            Expanded(child: _buildSection('Fim', _formatDateTime(m['data_fim']))),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildSection('Status', m['status'])),
            Expanded(child: _buildSection('Tipo', m['tipo'])),
          ],
        ),
      ],
    );
  }

  Widget _buildSection(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, color: AppColors.textMain)),
      ],
    );
  }

  Widget _buildFotos() {
    if (_loadingFotos) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_fotos.isEmpty) return const Center(child: Text('Nenhuma foto registrada.', style: TextStyle(color: Colors.grey)));
    
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10,
      ),
      itemCount: _fotos.length,
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(_fotos[index]['url'], fit: BoxFit.cover),
        );
      },
    );
  }

  Widget _buildComentarios() {
    return Column(
      children: [
        Expanded(
          child: _loadingComments 
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _comentarios.isEmpty 
              ? const Center(child: Text('Nenhum comentário.', style: TextStyle(color: Colors.grey)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _comentarios.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final c = _comentarios[index];
                    final perf = c['perfil'] ?? {};
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(perf['nome_completo'] ?? perf['nome'] ?? 'Usuário', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              if (perf['papel_sistema'] != null && perf['papel_sistema'] != 'morador') ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                                  child: Text(perf['papel_sistema'].toString().toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                              ]
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(c['texto'] ?? '', style: const TextStyle(fontSize: 14)),
                          const SizedBox(height: 6),
                          Align(alignment: Alignment.centerRight, child: Text(_formatDateTime(c['created_at']), style: const TextStyle(fontSize: 10, color: Colors.grey))),
                        ],
                      ),
                    );
                  },
                ),
        ),
        // Input
        Container(
          padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
          decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: 'Escreva um comentário...',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _submitting 
                ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)))
                : IconButton(
                    icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                    onPressed: _sendComment,
                  ),
            ],
          ),
        ),
      ],
    );
  }
}
