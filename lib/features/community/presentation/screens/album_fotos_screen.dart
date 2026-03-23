import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/design_system/design_system.dart';

const _emojis = ['❤️', '👏', '😍', '🎉'];

String _tipoLabel(String tipo) {
  switch (tipo) {
    case 'evento': return 'Evento';
    case 'manutencao': return 'Manutenção';
    case 'reuniao': return 'Reunião';
    default: return 'Outros';
  }
}

Color _tipoColor(String tipo) {
  switch (tipo) {
    case 'evento': return Colors.blue;
    case 'manutencao': return Colors.amber.shade700;
    case 'reuniao': return Colors.purple;
    default: return Colors.grey;
  }
}

class AlbumFotosScreen extends StatefulWidget {
  const AlbumFotosScreen({super.key});

  @override
  State<AlbumFotosScreen> createState() => _AlbumFotosScreenState();
}

class _AlbumFotosScreenState extends State<AlbumFotosScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _albums = [];
  String? _userId;
  String _userName = '';

  // Carousel
  final Map<String, PageController> _pageControllers = {};
  final Map<String, int> _carouselIndex = {};

  @override
  void initState() {
    super.initState();
    _userId = _supabase.auth.currentUser?.id;
    _loadData();
  }

  @override
  void dispose() {
    for (final c in _pageControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<String?> _getCondoId() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    final profile = await _supabase
        .from('perfil')
        .select('condominio_id, nome_completo')
        .eq('id', user.id)
        .maybeSingle();
    if (profile != null) {
      _userName = profile['nome_completo'] ?? '';
    }
    return profile?['condominio_id'] as String?;
  }

  Future<void> _loadData() async {
    try {
      final condoId = await _getCondoId();
      if (condoId == null) return;

      final data = await _supabase
          .from('album_fotos')
          .select('''
            id, titulo, descricao, tipo_evento, data_evento, created_at,
            perfil:autor_id (nome_completo),
            album_fotos_imagens (id, imagem_url, ordem),
            album_fotos_reacoes (id, user_id, emoji),
            album_fotos_comentarios (
              id, conteudo, created_at, parent_id,
              perfil:user_id (id, nome_completo)
            ),
            album_fotos_visualizacoes (count)
          ''')
          .eq('condominio_id', condoId)
          .order('created_at', ascending: false);

      final albums = List<Map<String, dynamic>>.from(data).map((a) {
        final imagens = List<Map<String, dynamic>>.from(a['album_fotos_imagens'] ?? []);
        imagens.sort((x, y) => (x['ordem'] as int? ?? 0).compareTo(y['ordem'] as int? ?? 0));

        final reacoes = List<Map<String, dynamic>>.from(a['album_fotos_reacoes'] ?? []);
        final comentarios = List<Map<String, dynamic>>.from(a['album_fotos_comentarios'] ?? []);
        comentarios.sort((x, y) =>
            (x['created_at'] as String).compareTo(y['created_at'] as String));

        int viewsCount = 0;
        final v = a['album_fotos_visualizacoes'];
        if (v is List && v.isNotEmpty && v[0] is Map) {
          viewsCount = (v[0]['count'] as int?) ?? 0;
        }

        // Author name
        String autorNome = 'Administrador';
        if (a['perfil'] is Map) {
          autorNome = (a['perfil'] as Map)['nome_completo'] ?? autorNome;
        }

        return {
          ...a,
          'imagens': imagens,
          'reacoes': reacoes,
          'comentarios': comentarios,
          'views_count': viewsCount,
          'autor_nome': autorNome,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _albums = albums;
          _loading = false;
        });
        // Register views
        for (final album in albums) {
          _registerView(album['id']);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _registerView(String albumId) async {
    try {
      await _supabase.from('album_fotos_visualizacoes').upsert({
        'album_id': albumId,
        'user_id': _userId,
      }, onConflict: 'album_id,user_id');
    } catch (_) {}
  }

  // ── Reactions ──
  Future<void> _toggleReaction(String albumId, String emoji) async {
    if (_userId == null) return;
    HapticFeedback.lightImpact();

    final albumIdx = _albums.indexWhere((a) => a['id'] == albumId);
    if (albumIdx == -1) return;
    final album = _albums[albumIdx];
    final reacoes = List<Map<String, dynamic>>.from(album['reacoes']);

    // Find any existing reaction by this user
    final existingIdx = reacoes.indexWhere((r) => r['user_id'] == _userId);

    if (existingIdx >= 0) {
      final existing = reacoes[existingIdx];
      if (existing['emoji'] == emoji) {
        // Same emoji → remove (toggle off)
        final id = existing['id'];
        reacoes.removeAt(existingIdx);
        setState(() => _albums[albumIdx] = {...album, 'reacoes': reacoes});
        try {
          await _supabase.from('album_fotos_reacoes').delete().eq('id', id);
        } catch (_) {}
      } else {
        // Different emoji → replace
        final id = existing['id'];
        reacoes[existingIdx] = {...existing, 'emoji': emoji};
        setState(() => _albums[albumIdx] = {...album, 'reacoes': reacoes});
        try {
          await _supabase.from('album_fotos_reacoes')
              .update({'emoji': emoji}).eq('id', id);
        } catch (_) {}
      }
    } else {
      // No existing → add
      try {
        final result = await _supabase.from('album_fotos_reacoes').insert({
          'album_id': albumId,
          'user_id': _userId,
          'emoji': emoji,
        }).select('id').single();
        reacoes.add({'id': result['id'], 'user_id': _userId, 'emoji': emoji});
        if (mounted) {
          setState(() => _albums[albumIdx] = {...album, 'reacoes': reacoes});
        }
      } catch (_) {}
    }
  }

  // ── Comments ──
  Future<void> _addComment(String albumId, String conteudo, {String? parentId}) async {
    if (_userId == null || conteudo.trim().isEmpty) return;

    try {
      final result = await _supabase.from('album_fotos_comentarios').insert({
        'album_id': albumId,
        'user_id': _userId,
        'conteudo': conteudo.trim(),
        'parent_id': parentId,
      }).select('id, conteudo, created_at, parent_id').single();

      final albumIdx = _albums.indexWhere((a) => a['id'] == albumId);
      if (albumIdx == -1) return;
      final album = _albums[albumIdx];
      final comentarios = List<Map<String, dynamic>>.from(album['comentarios']);
      comentarios.add({
        ...result,
        'perfil': {'id': _userId, 'nome_completo': _userName},
      });
      if (mounted) {
        setState(() => _albums[albumIdx] = {...album, 'comentarios': comentarios});
      }
    } catch (_) {}
  }

  Future<void> _deleteComment(String albumId, String commentId) async {
    try {
      await _supabase.from('album_fotos_comentarios').delete().eq('id', commentId);
      final albumIdx = _albums.indexWhere((a) => a['id'] == albumId);
      if (albumIdx == -1) return;
      final album = _albums[albumIdx];
      final comentarios = List<Map<String, dynamic>>.from(album['comentarios']);
      comentarios.removeWhere((c) => c['id'] == commentId);
      if (mounted) {
        setState(() => _albums[albumIdx] = {...album, 'comentarios': comentarios});
      }
    } catch (_) {}
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final d = DateTime.tryParse(dateStr);
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _formatDateTime(String dateStr) {
    final d = DateTime.tryParse(dateStr);
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} – ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  // ────────── BUILD ──────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Álbum de Fotos',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadData,
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _albums.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 100),
                        const Icon(Icons.photo_camera_outlined, size: 56, color: AppColors.disabledIcon),
                        const SizedBox(height: 12),
                        const Text('Nenhum álbum de fotos ainda',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textHint, fontSize: 14)),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _albums.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) => _buildAlbumCard(_albums[i]),
                    ),
        ),
      ),
    );
  }

  Widget _buildAlbumCard(Map<String, dynamic> album) {
    final imagens = List<Map<String, dynamic>>.from(album['imagens'] ?? []);
    final reacoes = List<Map<String, dynamic>>.from(album['reacoes'] ?? []);
    final comentarios = List<Map<String, dynamic>>.from(album['comentarios'] ?? []);
    final tipo = album['tipo_evento'] ?? 'outros';
    final albumId = album['id'] as String;
    final idx = _carouselIndex[albumId] ?? 0;

    // Reaction counts
    final reactionCounts = <String, int>{};
    for (final r in reacoes) {
      final emoji = r['emoji'] as String;
      reactionCounts[emoji] = (reactionCounts[emoji] ?? 0) + 1;
    }
    bool hasUserReacted(String emoji) =>
        reacoes.any((r) => r['user_id'] == _userId && r['emoji'] == emoji);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _tipoColor(tipo).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _tipoLabel(tipo),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _tipoColor(tipo)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('por ${album['autor_nome'] ?? ''}',
                      style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                  const Spacer(),
                  if (album['data_evento'] != null)
                    Text(_formatDate(album['data_evento']),
                        style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                ]),
                const SizedBox(height: 6),
                Text(album['titulo'] ?? '',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                if ((album['descricao'] ?? '').toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(album['descricao'],
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                  ),
              ],
            ),
          ),

          // Photo carousel
          if (imagens.isNotEmpty)
            SizedBox(
              height: 220,
              child: Stack(children: [
                PageView.builder(
                  controller: _pageControllers.putIfAbsent(albumId, () => PageController()),
                  itemCount: imagens.length,
                  onPageChanged: (i) => setState(() => _carouselIndex[albumId] = i),
                  itemBuilder: (ctx, i) => GestureDetector(
                    onDoubleTap: () => _toggleReaction(albumId, '❤️'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          imagens[i]['imagem_url'],
                          fit: BoxFit.cover, width: double.infinity,
                          loadingBuilder: (ctx, child, progress) {
                            if (progress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade100,
                            child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Dots
                if (imagens.length > 1)
                  Positioned(
                    bottom: 8, left: 0, right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(imagens.length, (i) => Container(
                        width: 7, height: 7,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == idx ? AppColors.primary : Colors.white.withValues(alpha: 0.6),
                        ),
                      )),
                    ),
                  ),
                // Counter
                if (imagens.length > 1)
                  Positioned(
                    top: 8, right: 22,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('${idx + 1}/${imagens.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                  ),
              ]),
            ),

          // Reaction chips
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Row(children: [
              if (reactionCounts.isEmpty)
                Text('Nenhuma reação ainda', style: TextStyle(fontSize: 11, color: AppColors.textHint))
              else
                ...reactionCounts.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => _toggleReaction(albumId, e.key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: hasUserReacted(e.key)
                            ? Colors.red.shade50 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: hasUserReacted(e.key)
                              ? Colors.red.shade200 : Colors.grey.shade200,
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(e.key, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 3),
                        Text('${e.value}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      ]),
                    ),
                  ),
                )),
              const Spacer(),
              Icon(Icons.visibility_outlined, size: 14, color: AppColors.textHint),
              const SizedBox(width: 3),
              Text('${album['views_count'] ?? 0}',
                  style: TextStyle(fontSize: 11, color: AppColors.textHint)),
            ]),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
            child: Row(children: [
              // React button
              PopupMenuButton<String>(
                onSelected: (emoji) => _toggleReaction(albumId, emoji),
                itemBuilder: (_) => _emojis.map((e) => PopupMenuItem(
                  value: e,
                  child: Row(children: [
                    Text(e, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    if (hasUserReacted(e))
                      const Icon(Icons.check_circle, color: Colors.red, size: 16),
                  ]),
                )).toList(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.favorite,
                        size: 18,
                        color: reacoes.isNotEmpty ? Colors.red : AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('Reagir',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ]),
                ),
              ),

              // Comment button
              GestureDetector(
                onTap: () => _showComments(context, album),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.chat_bubble_outline, size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('Comentar', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    if (comentarios.isNotEmpty) ...[
                      const SizedBox(width: 3),
                      Text('(${comentarios.length})',
                          style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                    ],
                  ]),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Comments Bottom Sheet ──
  void _showComments(BuildContext context, Map<String, dynamic> album) {
    final albumId = album['id'] as String;
    final textCtrl = TextEditingController();
    String? replyToId;
    String? replyToName;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final albumIdx = _albums.indexWhere((a) => a['id'] == albumId);
          if (albumIdx == -1) return const SizedBox();
          final currentAlbum = _albums[albumIdx];
          final comentarios = List<Map<String, dynamic>>.from(currentAlbum['comentarios'] ?? []);

          // Build tree
          final roots = comentarios.where((c) => c['parent_id'] == null).toList();
          final replies = comentarios.where((c) => c['parent_id'] != null).toList();

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.65,
              child: Column(children: [
                // Handle
                const SizedBox(height: 8),
                Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Comentários', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: const Icon(Icons.close, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),

                // Comment list
                Expanded(
                  child: comentarios.isEmpty
                      ? const Center(child: Text('Nenhum comentário. Seja o primeiro!',
                          style: TextStyle(color: AppColors.textHint, fontSize: 13)))
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: roots.map((comment) {
                            final commentReplies = replies.where((r) => r['parent_id'] == comment['id']).toList();
                            final perfil = comment['perfil'] as Map? ?? {};
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Root comment
                                _buildCommentTile(
                                  perfil: perfil,
                                  comment: comment,
                                  albumId: albumId,
                                  onReply: () {
                                    setSheetState(() {
                                      replyToId = comment['id'];
                                      replyToName = perfil['nome_completo'] ?? '';
                                    });
                                  },
                                  setSheetState: setSheetState,
                                ),
                                // Replies
                                if (commentReplies.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 36),
                                    child: Column(
                                      children: commentReplies.map((reply) {
                                        final rPerfil = reply['perfil'] as Map? ?? {};
                                        return _buildCommentTile(
                                          perfil: rPerfil,
                                          comment: reply,
                                          albumId: albumId,
                                          isReply: true,
                                          setSheetState: setSheetState,
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                              ],
                            );
                          }).toList(),
                        ),
                ),

                // Input
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Column(children: [
                    if (replyToId != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          const Icon(Icons.reply, size: 14, color: AppColors.textHint),
                          const SizedBox(width: 4),
                          Text('Respondendo a $replyToName',
                              style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => setSheetState(() {
                              replyToId = null;
                              replyToName = null;
                            }),
                            child: const Icon(Icons.close, size: 16, color: AppColors.textHint),
                          ),
                        ]),
                      ),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: textCtrl,
                          maxLength: 500,
                          decoration: InputDecoration(
                            hintText: 'Escreva um comentário...',
                            hintStyle: TextStyle(color: AppColors.textHint, fontSize: 13),
                            counterText: '',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: AppColors.primary),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            isDense: true,
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (text) async {
                            if (text.trim().isEmpty) return;
                            await _addComment(albumId, text, parentId: replyToId);
                            textCtrl.clear();
                            setSheetState(() {
                              replyToId = null;
                              replyToName = null;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () async {
                          final text = textCtrl.text;
                          if (text.trim().isEmpty) return;
                          await _addComment(albumId, text, parentId: replyToId);
                          textCtrl.clear();
                          setSheetState(() {
                            replyToId = null;
                            replyToName = null;
                          });
                        },
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.send, color: Colors.white, size: 18),
                        ),
                      ),
                    ]),
                  ]),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCommentTile({
    required Map perfil,
    required Map<String, dynamic> comment,
    required String albumId,
    bool isReply = false,
    VoidCallback? onReply,
    required void Function(void Function()) setSheetState,
  }) {
    final name = perfil['nome_completo'] ?? '?';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final isOwner = perfil['id'] == _userId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: isReply ? 12 : 16,
            backgroundColor: isReply ? Colors.grey.shade200 : AppColors.primary.withValues(alpha: 0.1),
            child: Text(initial,
                style: TextStyle(
                    fontSize: isReply ? 10 : 12,
                    fontWeight: FontWeight.bold,
                    color: isReply ? AppColors.textSecondary : AppColors.primary)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(name,
                      style: TextStyle(fontSize: isReply ? 11 : 12, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  Text(_formatDateTime(comment['created_at'] ?? ''),
                      style: TextStyle(fontSize: 10, color: AppColors.textHint)),
                ]),
                const SizedBox(height: 2),
                Text(comment['conteudo'] ?? '',
                    style: TextStyle(fontSize: 13, color: AppColors.textMain)),
                Row(children: [
                  if (!isReply && onReply != null)
                    GestureDetector(
                      onTap: onReply,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.reply, size: 12, color: AppColors.textHint),
                          const SizedBox(width: 2),
                          Text('Responder',
                              style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                        ]),
                      ),
                    ),
                  if (isOwner) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () async {
                        await _deleteComment(albumId, comment['id']);
                        setSheetState(() {});
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.delete_outline, size: 12, color: Colors.red.shade300),
                          const SizedBox(width: 2),
                          Text('Excluir',
                              style: TextStyle(fontSize: 11, color: Colors.red.shade300)),
                        ]),
                      ),
                    ),
                  ],
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
