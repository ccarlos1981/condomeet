import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';

const _categorias = <String, String>{
  'eletronicos': 'Eletrônicos',
  'moveis': 'Móveis',
  'roupas': 'Roupas',
  'veiculos': 'Veículos',
  'servicos': 'Serviços',
  'imoveis': 'Imóveis',
  'carros_e_pecas': 'Carros e Peças',
  'outros': 'Outros',
};

class ClassificadosScreen extends StatefulWidget {
  const ClassificadosScreen({super.key});

  @override
  State<ClassificadosScreen> createState() => _ClassificadosScreenState();
}

class _ClassificadosScreenState extends State<ClassificadosScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _classificados = [];
  Set<String> _favoritosIds = {};
  bool _loading = true;
  String _userId = '';
  String _condoId = '';
  String _tipoEstrutura = 'predio';

  // Filters
  String _tab = 'aprovados'; // 'aprovados' | 'pendentes'
  String _search = '';
  String _catFilter = '';
  bool _showFavs = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String get _blocoLabel {
    if (_tipoEstrutura == 'casa_quadra') return 'Quadra';
    if (_tipoEstrutura == 'casa_rua') return 'Rua';
    return 'Bloco';
  }

  String get _aptoLabel {
    if (_tipoEstrutura == 'casa_quadra') return 'Lote';
    if (_tipoEstrutura == 'casa_rua') return 'Número';
    return 'Apto';
  }

  // ── Load Data ──────────────────────────────────────────────
  Future<void> _loadData() async {
    final authState = context.read<AuthBloc>().state;
    _condoId = authState.condominiumId ?? '';
    _userId = authState.userId ?? '';
    if (_condoId.isEmpty) return;

    setState(() => _loading = true);

    try {
      // Classificados do condomínio
      final data = await _supabase
          .from('classificados')
          .select('*, perfil:criado_por (nome_completo, bloco_txt, apto_txt, whatsapp)')
          .eq('condominio_id', _condoId)
          .order('created_at', ascending: false);

      // Favoritos do usuário
      final favs = await _supabase
          .from('classificados_favoritos')
          .select('classificado_id')
          .eq('usuario_id', _userId);

      // Tipo estrutura
      final condo = await _supabase
          .from('condominios')
          .select('tipo_estrutura')
          .eq('id', _condoId)
          .single();

      if (mounted) {
        setState(() {
          _classificados = List<Map<String, dynamic>>.from(data).map((c) {
            final p = c['perfil'];
            if (p is List && p.isNotEmpty) {
              c['perfil'] = p[0];
            }
            return c;
          }).toList();
          _favoritosIds = Set<String>.from(
            (favs as List).map((f) => f['classificado_id'] as String),
          );
          _tipoEstrutura = condo['tipo_estrutura'] ?? 'predio';
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading classificados: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Filtered list ──────────────────────────────────────────
  List<Map<String, dynamic>> get _filtered {
    var result = _classificados.toList();
    if (_tab == 'pendentes') {
      result = result.where((c) =>
          c['criado_por'] == _userId &&
          (c['status'] == 'pendente' || c['status'] == 'rejeitado')).toList();
    } else {
      result = result.where((c) =>
          c['status'] == 'aprovado' || c['status'] == 'vendido').toList();
    }
    if (_showFavs) {
      result = result.where((c) => _favoritosIds.contains(c['id'])).toList();
    }
    if (_catFilter.isNotEmpty) {
      result = result.where((c) => c['categoria'] == _catFilter).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      result = result.where((c) =>
          (c['titulo'] ?? '').toString().toLowerCase().contains(q) ||
          (c['descricao'] ?? '').toString().toLowerCase().contains(q) ||
          (c['marca_modelo'] ?? '').toString().toLowerCase().contains(q)).toList();
    }
    return result;
  }

  int get _myPendingCount => _classificados.where((c) =>
      c['criado_por'] == _userId &&
      (c['status'] == 'pendente' || c['status'] == 'rejeitado')).length;

  // ── Toggle Favorite ────────────────────────────────────────
  Future<void> _toggleFavorite(String id) async {
    HapticFeedback.lightImpact();
    final isFav = _favoritosIds.contains(id);
    setState(() {
      if (isFav) {
        _favoritosIds.remove(id);
      } else {
        _favoritosIds.add(id);
      }
    });
    try {
      if (isFav) {
        await _supabase.from('classificados_favoritos')
            .delete().eq('classificado_id', id).eq('usuario_id', _userId);
      } else {
        await _supabase.from('classificados_favoritos')
            .insert({'classificado_id': id, 'usuario_id': _userId});
      }
    } catch (_) {}
  }

  // ── Delete ─────────────────────────────────────────────────
  Future<void> _handleDelete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir anúncio?'),
        content: const Text('Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    await _supabase.from('classificados').delete().eq('id', id);
    setState(() => _classificados.removeWhere((c) => c['id'] == id));
  }

  // ── Mark as sold ───────────────────────────────────────────
  Future<void> _handleMarkSold(String id) async {
    await _supabase.from('classificados').update({'status': 'vendido'}).eq('id', id);
    setState(() {
      final i = _classificados.indexWhere((c) => c['id'] == id);
      if (i >= 0) _classificados[i]['status'] = 'vendido';
    });
  }

  // ── Format ─────────────────────────────────────────────────
  String _fmtDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  String _fmtPrice(dynamic price) {
    if (price == null) return '';
    final v = double.tryParse(price.toString()) ?? 0;
    return 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  // ── Open Create / Edit Bottom Sheet ────────────────────────
  void _openForm({Map<String, dynamic>? editing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ClassificadoForm(
        supabase: _supabase,
        condoId: _condoId,
        userId: _userId,
        editing: editing,
        onSaved: () => _loadData(),
      ),
    );
  }

  // ── Open Detail Bottom Sheet ───────────────────────────────
  void _openDetail(Map<String, dynamic> c) {
    // Increment views if not own ad
    if (c['criado_por'] != _userId) {
      final views = (c['visualizacoes'] as int?) ?? 0;
      _supabase.from('classificados').update({'visualizacoes': views + 1}).eq('id', c['id']);
    }

    final perfil = c['perfil'] as Map<String, dynamic>?;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.all(20),
            children: [
              // Handle
              Center(child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              )),

              // Photo
              if (c['foto_url'] != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(c['foto_url'], height: 250, width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 200, color: Colors.grey.shade100,
                      child: const Icon(Icons.image, size: 48, color: Colors.grey),
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Title + price
              Text(c['titulo'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              if (c['preco'] != null) ...[
                const SizedBox(height: 4),
                Text(_fmtPrice(c['preco']),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
              ],
              const SizedBox(height: 12),

              // Status badge
              if (c['status'] == 'pendente')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('⏳ Aguardando aprovação',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.orange)),
                ),
              if (c['status'] == 'rejeitado')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('❌ Rejeitado',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red)),
                ),
              if (c['status'] == 'vendido')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('✅ Vendido',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                ),
              const SizedBox(height: 16),

              // Info grid
              _detailRow('Categoria', _categorias[c['categoria']] ?? c['categoria'] ?? ''),
              _detailRow('Condição', c['condicao'] == 'novo' ? 'Novo' : 'Usado'),
              if (c['marca_modelo'] != null && (c['marca_modelo'] as String).isNotEmpty)
                _detailRow('Marca/Modelo', c['marca_modelo']),
              _detailRow('Anunciante', perfil?['nome_completo'] ?? 'N/A'),
              _detailRow('$_blocoLabel / $_aptoLabel',
                '${perfil?['bloco_txt'] ?? '?'} / ${perfil?['apto_txt'] ?? '?'}'),
              if (c['mostrar_telefone'] == true && perfil?['whatsapp'] != null)
                _detailRow('WhatsApp', perfil!['whatsapp']),
              _detailRow('Data', _fmtDate(c['created_at'])),
              _detailRow('Visualizações', '${c['visualizacoes'] ?? 0}'),
              _detailRow('Cód. interno', c['cod_interno'] ?? ''),

              if (c['descricao'] != null && (c['descricao'] as String).isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Descrição:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(c['descricao'], style: const TextStyle(fontSize: 14)),
              ],
              const SizedBox(height: 20),

              // Owner actions
              if (c['criado_por'] == _userId && c['status'] != 'vendido') ...[
                if (c['status'] == 'aprovado') ...[
                  Row(children: [
                    Expanded(child: CondoButton(
                      label: 'Editar',
                      onPressed: () {
                        Navigator.pop(context);
                        _openForm(editing: c);
                      },
                      backgroundColor: AppColors.info,
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: CondoButton(
                      label: 'Vendi',
                      onPressed: () {
                        Navigator.pop(context);
                        _handleMarkSold(c['id']);
                      },
                      backgroundColor: AppColors.success,
                    )),
                  ]),
                  const SizedBox(height: 8),
                ],
                CondoButton(
                  label: 'Excluir',
                  onPressed: () {
                    Navigator.pop(context);
                    _handleDelete(c['id']);
                  },
                  backgroundColor: AppColors.error,
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(width: 130,
          child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
      ]),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('🛒 Classificados'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Anunciar', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  // ── Tabs ──────────────────────────────────────
                  SliverToBoxAdapter(child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(children: [
                      _buildTab('aprovados', '✅ Aprovados'),
                      const SizedBox(width: 8),
                      _buildTab('pendentes', '⏳ Meus Pendentes', badge: _myPendingCount),
                    ]),
                  )),

                  // ── Search & Filters ──────────────────────────
                  SliverToBoxAdapter(child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(children: [
                        // Search
                        TextField(
                          onChanged: (v) => setState(() => _search = v),
                          decoration: InputDecoration(
                            hintText: 'Buscar produto...',
                            hintStyle: TextStyle(color: AppColors.textHint),
                            prefixIcon: const Icon(Icons.search, size: 20),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.primary),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(children: [
                          // Category
                          Expanded(child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _catFilter.isEmpty ? null : _catFilter,
                                isExpanded: true,
                                hint: const Text('Todas Categorias', style: TextStyle(fontSize: 13)),
                                style: const TextStyle(fontSize: 13, color: AppColors.textMain),
                                items: [
                                  const DropdownMenuItem(value: '', child: Text('Todas Categorias')),
                                  ..._categorias.entries.map((e) =>
                                    DropdownMenuItem(value: e.key, child: Text(e.value))),
                                ],
                                onChanged: (v) => setState(() => _catFilter = v ?? ''),
                              ),
                            ),
                          )),
                          const SizedBox(width: 8),
                          // Favs toggle
                          GestureDetector(
                            onTap: () => setState(() => _showFavs = !_showFavs),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: _showFavs ? Colors.red.shade50 : Colors.white,
                                border: Border.all(
                                  color: _showFavs ? Colors.red.shade300 : AppColors.border),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.favorite,
                                  size: 16,
                                  color: _showFavs ? Colors.red : Colors.grey),
                                const SizedBox(width: 4),
                                Text('Favs', style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600,
                                  color: _showFavs ? Colors.red : Colors.grey)),
                              ]),
                            ),
                          ),
                        ]),
                      ]),
                    ),
                  )),

                  // ── Count ─────────────────────────────────────
                  SliverToBoxAdapter(child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text(
                      '${_filtered.length} anúncio${_filtered.length != 1 ? 's' : ''}',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  )),

                  // ── Grid ──────────────────────────────────────
                  if (_filtered.isEmpty)
                    SliverFillRemaining(child: Center(child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_bag_outlined, size: 56, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        Text('Nenhum anúncio encontrado',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text(_tab == 'pendentes' ? 'Seus anúncios pendentes aparecerão aqui' : 'Seja o primeiro a anunciar!',
                          style: TextStyle(fontSize: 13, color: AppColors.textHint)),
                      ],
                    )))
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.65,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _buildCard(_filtered[i]),
                          childCount: _filtered.length,
                        ),
                      ),
                    ),

                  // Bottom padding for FAB
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
    );
  }

  // ── Tab button ─────────────────────────────────────────────
  Widget _buildTab(String value, String label, {int badge = 0}) {
    final active = _tab == value;
    return GestureDetector(
      onTap: () => setState(() => _tab = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? (value == 'aprovados' ? AppColors.success : AppColors.warning)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(24),
          boxShadow: active ? [BoxShadow(
            color: (value == 'aprovados' ? AppColors.success : AppColors.warning).withValues(alpha: 0.3),
            blurRadius: 8, offset: const Offset(0, 2),
          )] : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.bold,
            color: active ? Colors.white : AppColors.textSecondary)),
          if (badge > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$badge', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold,
                color: active ? Colors.white : AppColors.textSecondary)),
            ),
          ],
        ]),
      ),
    );
  }

  // ── Ad Card ────────────────────────────────────────────────
  Widget _buildCard(Map<String, dynamic> c) {
    final perfil = c['perfil'] as Map<String, dynamic>?;
    final isFav = _favoritosIds.contains(c['id']);
    final statusColor = c['status'] == 'pendente'
        ? Colors.amber
        : c['status'] == 'rejeitado'
            ? Colors.red
            : c['status'] == 'vendido'
                ? Colors.grey
                : null;

    return GestureDetector(
      onTap: () => _openDetail(c),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: statusColor?.withValues(alpha: 0.4) ?? AppColors.border,
            width: statusColor != null ? 2 : 1,
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Photo
          Expanded(
            flex: 3,
            child: Stack(children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: c['foto_url'] != null
                    ? Image.network(c['foto_url'], width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade100,
                          child: const Center(child: Icon(Icons.image, size: 32, color: Colors.grey)),
                        ))
                    : Container(
                        color: Colors.grey.shade100,
                        child: const Center(child: Icon(Icons.image_outlined, size: 32, color: Colors.grey))),
              ),

              // Status badge
              if (c['status'] == 'pendente')
                Positioned(top: 8, left: 8, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('⏳ Pendente', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                )),
              if (c['status'] == 'rejeitado')
                Positioned(top: 8, left: 8, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('❌ Rejeitado', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                )),
              if (c['status'] == 'vendido')
                Positioned(top: 8, left: 8, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('✅ Vendido', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                )),

              // Favorite
              Positioned(top: 6, right: 6, child: GestureDetector(
                onTap: () => _toggleFavorite(c['id']),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    size: 16,
                    color: isFav ? Colors.red : Colors.grey,
                  ),
                ),
              )),
            ]),
          ),

          // Info
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c['titulo'] ?? '',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  '$_blocoLabel: ${perfil?['bloco_txt'] ?? '?'} / $_aptoLabel: ${perfil?['apto_txt'] ?? '?'}',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                if (c['preco'] != null)
                  Text(_fmtPrice(c['preco']),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Icons.visibility, size: 12, color: AppColors.textHint),
                  const SizedBox(width: 2),
                  Text('${c['visualizacoes'] ?? 0}',
                    style: TextStyle(fontSize: 10, color: AppColors.textHint)),
                  const SizedBox(width: 8),
                  Text(_fmtDate(c['created_at']),
                    style: TextStyle(fontSize: 10, color: AppColors.textHint)),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Create / Edit Form Bottom Sheet
// ═══════════════════════════════════════════════════════════════

class _ClassificadoForm extends StatefulWidget {
  final SupabaseClient supabase;
  final String condoId, userId;
  final Map<String, dynamic>? editing;
  final VoidCallback onSaved;

  const _ClassificadoForm({
    required this.supabase,
    required this.condoId,
    required this.userId,
    this.editing,
    required this.onSaved,
  });

  @override
  State<_ClassificadoForm> createState() => _ClassificadoFormState();
}

class _ClassificadoFormState extends State<_ClassificadoForm> {
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _descricaoCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();
  final _precoCtrl = TextEditingController();

  String _categoria = 'outros';
  String _condicao = 'usado';
  bool _mostrarTelefone = true;
  bool _saving = false;
  XFile? _foto;
  String? _fotoUrl;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final c = widget.editing!;
      _tituloCtrl.text = c['titulo'] ?? '';
      _descricaoCtrl.text = c['descricao'] ?? '';
      _marcaCtrl.text = c['marca_modelo'] ?? '';
      _precoCtrl.text = c['preco'] != null ? c['preco'].toString() : '';
      _categoria = c['categoria'] ?? 'outros';
      _condicao = c['condicao'] ?? 'usado';
      _mostrarTelefone = c['mostrar_telefone'] ?? true;
      _fotoUrl = c['foto_url'];
    }
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descricaoCtrl.dispose();
    _marcaCtrl.dispose();
    _precoCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 80);
    if (picked != null) setState(() => _foto = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      String? fotoUrl = _fotoUrl;

      // Upload photo
      if (_foto != null) {
        final ext = _foto!.name.split('.').last;
        final path = '${widget.condoId}/${DateTime.now().millisecondsSinceEpoch}.$ext';
        await widget.supabase.storage
            .from('classificados-fotos')
            .upload(path, File(_foto!.path), fileOptions: const FileOptions(upsert: true));
        fotoUrl = widget.supabase.storage.from('classificados-fotos').getPublicUrl(path);
      }

      final record = {
        'titulo': _tituloCtrl.text.trim(),
        'descricao': _descricaoCtrl.text.trim().isNotEmpty ? _descricaoCtrl.text.trim() : null,
        'categoria': _categoria,
        'marca_modelo': _marcaCtrl.text.trim().isNotEmpty ? _marcaCtrl.text.trim() : null,
        'preco': _precoCtrl.text.isNotEmpty ? double.tryParse(_precoCtrl.text) : null,
        'condicao': _condicao,
        'mostrar_telefone': _mostrarTelefone,
        'foto_url': fotoUrl,
      };

      if (_isEditing) {
        // Edit → back to pendente for re-approval
        await widget.supabase.from('classificados')
            .update({...record, 'status': 'pendente'})
            .eq('id', widget.editing!['id']);
      } else {
        // Create new
        final inserted = await widget.supabase.from('classificados').insert({
          ...record,
          'condominio_id': widget.condoId,
          'criado_por': widget.userId,
          'status': 'pendente',
        }).select('id').single();

        // Trigger notification
        try {
          await widget.supabase.functions.invoke('classificados-notify', body: {
            'condominio_id': widget.condoId,
            'classificado_id': inserted['id'],
            'action': 'novo',
          });
        } catch (_) {}
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing
                ? 'Anúncio atualizado! Enviado para re-aprovação.'
                : 'Anúncio criado! Aguardando aprovação.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.all(20),
            children: [
              // Handle
              Center(child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              )),

              Text(_isEditing ? 'Editar Anúncio' : 'Novo Anúncio',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              if (_isEditing)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('⚠️ Ao salvar, o anúncio volta para aprovação.',
                    style: TextStyle(fontSize: 12, color: Colors.orange)),
                ),
              const SizedBox(height: 20),

              // Photo
              GestureDetector(
                onTap: _pickPhoto,
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: _foto != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.file(File(_foto!.path), fit: BoxFit.cover, width: double.infinity))
                      : _fotoUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Image.network(_fotoUrl!, fit: BoxFit.cover, width: double.infinity))
                          : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.camera_alt_outlined, size: 40, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text('Toque para adicionar foto',
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                            ]),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              TextFormField(
                controller: _tituloCtrl,
                decoration: const InputDecoration(labelText: 'Título *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Título obrigatório' : null,
              ),
              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: _descricaoCtrl,
                decoration: const InputDecoration(labelText: 'Descrição'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),

              // Category
              DropdownButtonFormField<String>(
                value: _categoria,
                decoration: const InputDecoration(labelText: 'Categoria'),
                items: _categorias.entries.map((e) =>
                  DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                onChanged: (v) => setState(() => _categoria = v ?? 'outros'),
              ),
              const SizedBox(height: 12),

              // Brand/Model
              TextFormField(
                controller: _marcaCtrl,
                decoration: const InputDecoration(labelText: 'Marca / Modelo'),
              ),
              const SizedBox(height: 12),

              // Price
              TextFormField(
                controller: _precoCtrl,
                decoration: const InputDecoration(labelText: 'Preço (R\$)', prefixText: 'R\$ '),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),

              // Condition
              Row(children: [
                const Text('Condição: ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('Novo'),
                  selected: _condicao == 'novo',
                  onSelected: (_) => setState(() => _condicao = 'novo'),
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Usado'),
                  selected: _condicao == 'usado',
                  onSelected: (_) => setState(() => _condicao = 'usado'),
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                ),
              ]),
              const SizedBox(height: 12),

              // Show phone
              SwitchListTile(
                value: _mostrarTelefone,
                onChanged: (v) => setState(() => _mostrarTelefone = v),
                title: const Text('Mostrar meu telefone', style: TextStyle(fontSize: 14)),
                activeThumbColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 20),

              // Submit
              CondoButton(
                label: _saving
                    ? 'Salvando...'
                    : _isEditing ? 'Salvar alterações' : 'Publicar anúncio',
                onPressed: _saving ? null : _submit,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
