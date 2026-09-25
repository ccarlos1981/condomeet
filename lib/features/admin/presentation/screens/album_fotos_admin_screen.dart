import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/design_system/design_system.dart';

const _tipoEventoOptions = [
  {'value': 'evento', 'label': '🎉 Evento'},
  {'value': 'manutencao', 'label': '🔧 Manutenção'},
  {'value': 'reuniao', 'label': '👥 Reunião'},
  {'value': 'outros', 'label': '📌 Outros'},
  {'value': 'aviso', 'label': '⚠️ Aviso'},
  {'value': 'comunicado', 'label': '📢 Comunicado'},
];

String _tipoLabel(String tipo) {
  switch (tipo) {
    case 'evento':
      return 'Evento';
    case 'manutencao':
      return 'Manutenção';
    case 'reuniao':
      return 'Reunião';
    case 'aviso':
      return 'Aviso';
    case 'comunicado':
      return 'Comunicado';
    default:
      return 'Outros';
  }
}

Color _tipoColor(String tipo) {
  switch (tipo) {
    case 'evento':
      return Colors.blue;
    case 'manutencao':
      return Colors.amber.shade700;
    case 'reuniao':
      return Colors.purple;
    case 'aviso':
      return Colors.orange.shade700;
    case 'comunicado':
      return Colors.teal;
    default:
      return Colors.grey;
  }
}

String _tipoNomePrefix(String tipo) {
  switch (tipo) {
    case 'manutencao':
      return 'Nome da Manutenção';
    case 'reuniao':
      return 'Nome da Reunião';
    case 'outros':
      return 'Nome de Outros';
    case 'aviso':
      return 'Nome do Aviso';
    case 'comunicado':
      return 'Nome do Comunicado';
    case 'evento':
    default:
      return 'Nome do Evento';
  }
}

class AlbumFotosAdminScreen extends StatefulWidget {
  const AlbumFotosAdminScreen({super.key});

  @override
  State<AlbumFotosAdminScreen> createState() => _AlbumFotosAdminScreenState();
}

class _AlbumFotosAdminScreenState extends State<AlbumFotosAdminScreen> {
  final _supabase = Supabase.instance.client;

  // Form fields
  final _tituloCtrl = TextEditingController();
  final _descricaoCtrl = TextEditingController();
  String _tipoEvento = 'evento';
  DateTime? _dataEvento;
  List<XFile> _selectedPhotos = [];
  bool _isSending = false;

  // Album list
  bool _loading = true;
  List<Map<String, dynamic>> _albums = [];

  // Edit state
  String? _editingId;
  final _editTituloCtrl = TextEditingController();
  final _editDescricaoCtrl = TextEditingController();
  String _editTipoEvento = 'evento';
  DateTime? _editDataEvento;
  List<XFile> _editNewPhotos = [];
  List<String> _editRemovedImageIds = [];

  // Carousel
  final Map<String, int> _carouselIndex = {};

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descricaoCtrl.dispose();
    _editTituloCtrl.dispose();
    _editDescricaoCtrl.dispose();
    super.dispose();
  }

  Future<String?> _getCondoId() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    final profile = await _supabase
        .from('perfil')
        .select('condominio_id')
        .eq('id', user.id)
        .maybeSingle();
    return profile?['condominio_id'] as String?;
  }

  Future<void> _loadAlbums() async {
    try {
      final condoId = await _getCondoId();
      if (condoId == null) return;

      final data = await _supabase
          .from('album_fotos')
          .select('''
            id, titulo, descricao, tipo_evento, data_evento, created_at,
            album_fotos_imagens (id, imagem_url, ordem),
            album_fotos_reacoes (count),
            album_fotos_comentarios (count),
            album_fotos_visualizacoes (count)
          ''')
          .eq('condominio_id', condoId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _albums = List<Map<String, dynamic>>.from(data).map((a) {
            final imagens = List<Map<String, dynamic>>.from(
              a['album_fotos_imagens'] ?? [],
            );
            imagens.sort(
              (x, y) =>
                  (x['ordem'] as int? ?? 0).compareTo(y['ordem'] as int? ?? 0),
            );

            // Count extraction from Supabase's aggregate format
            int reacoes = 0;
            int comentarios = 0;
            int views = 0;
            final r = a['album_fotos_reacoes'];
            if (r is List && r.isNotEmpty && r[0] is Map) {
              reacoes = (r[0]['count'] as int?) ?? 0;
            }
            final c = a['album_fotos_comentarios'];
            if (c is List && c.isNotEmpty && c[0] is Map) {
              comentarios = (c[0]['count'] as int?) ?? 0;
            }
            final v = a['album_fotos_visualizacoes'];
            if (v is List && v.isNotEmpty && v[0] is Map) {
              views = (v[0]['count'] as int?) ?? 0;
            }

            return {
              ...a,
              'imagens': imagens,
              'reacoes_count': reacoes,
              'comentarios_count': comentarios,
              'visualizacoes_count': views,
            };
          }).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Photo selection ──
  Future<void> _pickPhotos({bool forEdit = false}) async {
    int currentCount = 0;
    if (forEdit) {
      final album = _albums.firstWhere(
        (a) => a['id'] == _editingId,
        orElse: () => {},
      );
      final existingCount =
          (album['imagens'] as List? ?? []).length -
          _editRemovedImageIds.length;
      currentCount =
          (existingCount > 0 ? existingCount : 0) + _editNewPhotos.length;
    } else {
      currentCount = _selectedPhotos.length;
    }
    final maxRemaining = 5 - currentCount;
    if (maxRemaining <= 0) {
      _showSnack('Máximo de 5 fotos por comunicado', Colors.orange);
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primaryLight,
                child: Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.primary,
                ),
              ),
              title: const Text('Tirar foto com a câmera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primaryLight,
                child: Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.primary,
                ),
              ),
              title: const Text('Escolher da galeria'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    try {
      if (source == ImageSource.gallery) {
        final photos = await picker.pickMultiImage(
          maxWidth: 1280,
          maxHeight: 1280,
          imageQuality: 85,
        );
        if (photos.isNotEmpty && mounted) {
          final toAdd = photos.take(maxRemaining).toList();
          setState(() {
            if (forEdit) {
              _editNewPhotos.addAll(toAdd);
            } else {
              _selectedPhotos.addAll(toAdd);
            }
          });
        }
      } else {
        final photo = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1280,
          maxHeight: 1280,
          imageQuality: 85,
        );
        if (photo != null && mounted) {
          setState(() {
            if (forEdit) {
              _editNewPhotos.add(photo);
            } else {
              _selectedPhotos.add(photo);
            }
          });
        }
      }
    } catch (e) {
      _showSnack('Erro ao selecionar foto', Colors.red);
    }
  }

  /// Extrai deterministicamente o caminho do objeto no bucket 'album-fotos'
  String? _extractStoragePath(String imageUrl) {
    try {
      if (imageUrl.isEmpty) return null;
      if (!imageUrl.startsWith('http://') && !imageUrl.startsWith('https://')) {
        return imageUrl.trim();
      }
      final uri = Uri.tryParse(imageUrl);
      if (uri == null) return null;
      const marker = '/album-fotos/';
      final index = uri.path.indexOf(marker);
      if (index != -1) {
        final rawPath = uri.path.substring(index + marker.length);
        final decoded = Uri.decodeComponent(rawPath).trim();
        return decoded.isNotEmpty ? decoded : null;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Create album ──
  Future<void> _handleCreate() async {
    final titulo = _tituloCtrl.text.trim();
    if (titulo.isEmpty) {
      _showSnack('Informe o título do comunicado', Colors.orange);
      return;
    }
    if (titulo.length > 100) {
      _showSnack('O título deve ter no máximo 100 caracteres', Colors.orange);
      return;
    }
    if (_selectedPhotos.isEmpty) {
      _showSnack('Adicione pelo menos uma foto', Colors.orange);
      return;
    }
    if (_selectedPhotos.length > 5) {
      _showSnack('Máximo de 5 fotos por comunicado', Colors.orange);
      return;
    }

    setState(() => _isSending = true);
    HapticFeedback.mediumImpact();

    String? createdAlbumId;
    final uploadedStoragePaths = <String>[];

    try {
      final condoId = await _getCondoId();
      final user = _supabase.auth.currentUser;
      if (condoId == null || user == null) throw Exception('Não autenticado');

      // 1. Inserir registro do álbum explicitamente em 'rascunho' (NÃO dispara Push)
      final albumData = await _supabase
          .from('album_fotos')
          .insert({
            'condominio_id': condoId,
            'autor_id': user.id,
            'titulo': titulo,
            'descricao': _descricaoCtrl.text.trim(),
            'tipo_evento': _tipoEvento,
            'data_evento': _dataEvento?.toIso8601String().split('T').first,
            'status': 'rascunho',
          })
          .select('id')
          .single();

      final albumId = albumData['id'] as String;
      createdAlbumId = albumId;

      // 2. Upload de todas as fotos para o bucket 'album-fotos' com isolamento
      final imageRecords = <Map<String, dynamic>>[];
      for (int i = 0; i < _selectedPhotos.length; i++) {
        final photo = _selectedPhotos[i];
        final ext = photo.name.contains('.')
            ? photo.name.split('.').last.toLowerCase()
            : (photo.path.contains('.')
                  ? photo.path.split('.').last.toLowerCase()
                  : 'jpg');
        final contentType = ext == 'png'
            ? 'image/png'
            : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
        final path =
            '$condoId/$albumId/${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
        final bytes = await photo.readAsBytes();

        await _supabase.storage
            .from('album-fotos')
            .uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(contentType: contentType, upsert: true),
            );

        uploadedStoragePaths.add(path);

        final publicUrl = _supabase.storage
            .from('album-fotos')
            .getPublicUrl(path);
        imageRecords.add({
          'album_id': albumId,
          'imagem_url': publicUrl,
          'ordem': i,
        });
      }

      // 3. Persistir todas as imagens em public.album_fotos_imagens
      await _supabase.from('album_fotos_imagens').insert(imageRecords);

      // 4. Somente após fotos estarem gravadas: atualizar status para 'publicado'
      // Essa transição dispara exatamente UM Push através do trigger de banco
      await _supabase
          .from('album_fotos')
          .update({'status': 'publicado'})
          .eq('id', albumId);

      // 5. Reset form
      _tituloCtrl.clear();
      _descricaoCtrl.clear();
      setState(() {
        _tipoEvento = 'evento';
        _dataEvento = null;
        _selectedPhotos = [];
      });

      _showSnack('✅ Comunicado criado com sucesso!', Colors.green);
      _loadAlbums();
    } catch (e) {
      debugPrint('[Mobile AlbumFotos] Falha no fluxo de criação: $e');

      // COMPENSAÇÃO DE ROLLBACK (BEST-EFFORT E OBSERVÁVEL)
      if (uploadedStoragePaths.isNotEmpty) {
        try {
          await _supabase.storage
              .from('album-fotos')
              .remove(uploadedStoragePaths);
        } catch (storageErr) {
          debugPrint(
            '[Mobile AlbumFotos] Falha ao compensar Storage: $storageErr',
          );
        }
      }

      if (createdAlbumId != null) {
        try {
          await _supabase.from('album_fotos').delete().eq('id', createdAlbumId);
        } catch (dbErr) {
          debugPrint('[Mobile AlbumFotos] Falha ao excluir rascunho: $dbErr');
        }
      }

      _showSnack('❌ Erro ao criar comunicado: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ── Delete album ──
  Future<void> _handleDelete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir comunicado?'),
        content: const Text(
          'Todas as fotos, reações e comentários serão removidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      // 1. Obter todas as imagens associadas ao álbum
      final imagesRes = await _supabase
          .from('album_fotos_imagens')
          .select('imagem_url')
          .eq('album_id', id);
      final images = List<Map<String, dynamic>>.from(imagesRes);

      // 2. Determinar os paths determinísticos no bucket 'album-fotos'
      final paths = images
          .map((img) => _extractStoragePath(img['imagem_url'] as String? ?? ''))
          .where((p) => p != null && p.isNotEmpty)
          .cast<String>()
          .toList();

      // 3. Remover arquivos físicos do Storage primeiro (não tolerar órfãos conhecidos)
      if (paths.isNotEmpty) {
        try {
          await _supabase.storage.from('album-fotos').remove(paths);
        } catch (storageErr) {
          throw Exception(
            'Falha ao remover fotos do Storage: $storageErr. Exclusão abortada para evitar arquivos órfãos.',
          );
        }
      }

      // 4. Excluir o registro de album_fotos no banco (ON DELETE CASCADE cuidará das filhas)
      await _supabase.from('album_fotos').delete().eq('id', id);
      _showSnack('🗑️ Comunicado excluído', Colors.orange);
      _loadAlbums();
    } catch (e) {
      _showSnack('❌ Erro ao excluir: $e', Colors.red);
    }
  }

  // ── Edit album ──
  void _startEdit(Map<String, dynamic> album) {
    _editTituloCtrl.text = album['titulo'] ?? '';
    _editDescricaoCtrl.text = album['descricao'] ?? '';
    setState(() {
      _editingId = album['id'];
      _editTipoEvento = album['tipo_evento'] ?? 'evento';
      _editDataEvento = album['data_evento'] != null
          ? DateTime.tryParse(album['data_evento'])
          : null;
      _editNewPhotos = [];
      _editRemovedImageIds = [];
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingId = null;
      _editNewPhotos = [];
      _editRemovedImageIds = [];
    });
  }

  Future<void> _handleSaveEdit() async {
    if (_editingId == null) return;
    final albumId = _editingId!;

    final titulo = _editTituloCtrl.text.trim();
    if (titulo.isEmpty) {
      _showSnack('Informe o título do comunicado', Colors.orange);
      return;
    }
    if (titulo.length > 100) {
      _showSnack('O título deve ter no máximo 100 caracteres', Colors.orange);
      return;
    }

    setState(() => _isSending = true);

    try {
      final condoId = await _getCondoId();
      if (condoId == null) throw Exception('Não autenticado');

      // 1. Buscar a quantidade real atual de imagens no banco para este álbum
      final currentImagesRes = await _supabase
          .from('album_fotos_imagens')
          .select('id, imagem_url, ordem')
          .eq('album_id', albumId);

      final currentImages = List<Map<String, dynamic>>.from(currentImagesRes);
      final existingIds = currentImages
          .map((img) => img['id'] as String)
          .toSet();

      // Validar que os IDs solicitados para remoção realmente pertencem ao álbum
      final validRemovedIds = _editRemovedImageIds
          .where((id) => existingIds.contains(id))
          .toList();

      // 2. Calcular o saldo final e validar
      final totalFinal =
          currentImages.length - validRemovedIds.length + _editNewPhotos.length;

      if (totalFinal < 1) {
        _showSnack(
          'O comunicado deve conter pelo menos 1 foto. Não é permitido remover todas as fotos.',
          Colors.orange,
        );
        return;
      }

      if (totalFinal > 5) {
        _showSnack('Máximo de 5 fotos por comunicado', Colors.orange);
        return;
      }

      // 3. Atualizar metadados do álbum
      await _supabase
          .from('album_fotos')
          .update({
            'titulo': titulo,
            'descricao': _editDescricaoCtrl.text.trim(),
            'tipo_evento': _editTipoEvento,
            'data_evento': _editDataEvento?.toIso8601String().split('T').first,
          })
          .eq('id', albumId);

      // 4. ORDEM DA SUBSTITUIÇÃO: PRIMEIRO UPLOAD E INSERT DAS NOVAS FOTOS
      final newUploadedPaths = <String>[];
      final newInsertedIds = <String>[];

      if (_editNewPhotos.isNotEmpty) {
        try {
          final newImageRecords = <Map<String, dynamic>>[];
          final baseOrder = currentImages.length;

          for (int i = 0; i < _editNewPhotos.length; i++) {
            final photo = _editNewPhotos[i];
            final ext = photo.name.contains('.')
                ? photo.name.split('.').last.toLowerCase()
                : (photo.path.contains('.')
                      ? photo.path.split('.').last.toLowerCase()
                      : 'jpg');
            final contentType = ext == 'png'
                ? 'image/png'
                : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
            final path =
                '$condoId/$albumId/${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
            final bytes = await photo.readAsBytes();

            await _supabase.storage
                .from('album-fotos')
                .uploadBinary(
                  path,
                  bytes,
                  fileOptions: FileOptions(
                    contentType: contentType,
                    upsert: true,
                  ),
                );

            newUploadedPaths.add(path);

            final publicUrl = _supabase.storage
                .from('album-fotos')
                .getPublicUrl(path);
            newImageRecords.add({
              'album_id': albumId,
              'imagem_url': publicUrl,
              'ordem': baseOrder + i,
            });
          }

          final insertedData = await _supabase
              .from('album_fotos_imagens')
              .insert(newImageRecords)
              .select('id');

          for (final row in (insertedData as List)) {
            newInsertedIds.add(row['id'] as String);
          }
        } catch (err) {
          // Compensar os novos uploads sem remover imagens antigas
          if (newUploadedPaths.isNotEmpty) {
            try {
              await _supabase.storage
                  .from('album-fotos')
                  .remove(newUploadedPaths);
            } catch (storageCleanupErr) {
              debugPrint(
                '[Mobile AlbumFotos] Falha ao compensar Storage no PUT: $storageCleanupErr',
              );
            }
          }
          if (newInsertedIds.isNotEmpty) {
            try {
              await _supabase
                  .from('album_fotos_imagens')
                  .delete()
                  .inFilter('id', newInsertedIds);
            } catch (dbCleanupErr) {
              debugPrint(
                '[Mobile AlbumFotos] Falha ao compensar DB no PUT: $dbCleanupErr',
              );
            }
          }
          rethrow;
        }
      }

      // 5. ORDEM DA SUBSTITUIÇÃO: DEPOIS REMOVER AS FOTOS ANTIGAS AUTORIZADAS
      if (validRemovedIds.isNotEmpty) {
        final imagesToDelete = currentImages
            .where((img) => validRemovedIds.contains(img['id']))
            .toList();
        final pathsToRemove = imagesToDelete
            .map(
              (img) => _extractStoragePath(img['imagem_url'] as String? ?? ''),
            )
            .where((p) => p != null && p.isNotEmpty)
            .cast<String>()
            .toList();

        if (pathsToRemove.isNotEmpty) {
          try {
            await _supabase.storage.from('album-fotos').remove(pathsToRemove);
          } catch (storageRemoveErr) {
            debugPrint(
              '[Mobile AlbumFotos] Falha ao remover arquivos antigos do Storage: $storageRemoveErr',
            );
          }
        }

        await _supabase
            .from('album_fotos_imagens')
            .delete()
            .inFilter('id', validRemovedIds);
      }

      _cancelEdit();
      _showSnack('✅ Comunicado atualizado!', Colors.green);
      _loadAlbums();
    } catch (e) {
      _showSnack('❌ Erro ao atualizar: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickDate({bool forEdit = false}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (forEdit ? _editDataEvento : _dataEvento) ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(
          context,
        ).copyWith(colorScheme: ColorScheme.light(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        if (forEdit) {
          _editDataEvento = picked;
        } else {
          _dataEvento = picked;
        }
      });
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final d = DateTime.tryParse(dateStr);
    if (d == null) return dateStr;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  // ────────── BUILD ──────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text(
          'Comunicados',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadAlbums,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _buildCreateForm(),
              const SizedBox(height: 24),
              _buildSectionTitle('Comunicados publicados'),
              const SizedBox(height: 8),
              if (_loading)
                const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              else if (_albums.isEmpty)
                _buildEmptyState()
              else
                ..._albums.map(_buildAlbumCard),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: const Column(
        children: [
          Icon(
            Icons.photo_camera_outlined,
            size: 48,
            color: AppColors.disabledIcon,
          ),
          SizedBox(height: 12),
          Text(
            'Nenhum comunicado criado ainda',
            style: TextStyle(color: AppColors.textHint, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ── CREATE FORM ──
  Widget _buildCreateForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.photo_camera_rounded,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              const Text(
                'Criar comunicado',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Title
          TextFormField(
            controller: _tituloCtrl,
            maxLength: 100,
            decoration: InputDecoration(
              labelText: 'Nome do comunicado',
              hintText: 'Ex: Festa Junina 2026',
              prefixIcon: Icon(Icons.title_rounded, color: AppColors.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Type selector
          const Text(
            'Tipo do comunicado:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tipoEventoOptions.map((opt) {
              final selected = _tipoEvento == opt['value'];
              return GestureDetector(
                onTap: () => setState(() => _tipoEvento = opt['value']!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    opt['label']!,
                    style: TextStyle(
                      fontSize: 13,
                      color: selected ? Colors.white : AppColors.textSecondary,
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Description
          TextFormField(
            controller: _descricaoCtrl,
            maxLines: 3,
            minLines: 2,
            decoration: InputDecoration(
              labelText: 'Descrição (opcional)',
              hintText: 'Conte sobre o evento...',
              prefixIcon: Icon(Icons.notes_outlined, color: AppColors.primary),
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Date picker
          GestureDetector(
            onTap: () => _pickDate(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _dataEvento != null
                        ? '${_dataEvento!.day.toString().padLeft(2, '0')}/${_dataEvento!.month.toString().padLeft(2, '0')}/${_dataEvento!.year}'
                        : 'Data do evento (opcional)',
                    style: TextStyle(
                      color: _dataEvento != null
                          ? AppColors.textMain
                          : AppColors.textHint,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  if (_dataEvento != null)
                    GestureDetector(
                      onTap: () => setState(() => _dataEvento = null),
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Photo selection
          _buildPhotoSelector(),
          const SizedBox(height: 20),

          // Submit button
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed:
                  _isSending ||
                      _selectedPhotos.isEmpty ||
                      _selectedPhotos.length > 5
                  ? null
                  : _handleCreate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: AppColors.primary.withValues(
                  alpha: 0.5,
                ),
              ),
              icon: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                _isSending ? 'Enviando...' : 'Criar comunicado',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fotos do comunicado (máx. 5)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        if (_selectedPhotos.isEmpty)
          GestureDetector(
            onTap: () => _pickPhotos(),
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.border,
                  width: 1.5,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 28,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Adicionar fotos',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: [
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount:
                      _selectedPhotos.length +
                      (_selectedPhotos.length < 5 ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    if (i == _selectedPhotos.length) {
                      // Add more button
                      return GestureDetector(
                        onTap: () => _pickPhotos(),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.add,
                            color: AppColors.primary,
                            size: 28,
                          ),
                        ),
                      );
                    }
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(_selectedPhotos[i].path),
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _selectedPhotos.removeAt(i)),
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_selectedPhotos.length}/5 fotos selecionadas',
                style: TextStyle(fontSize: 11, color: AppColors.textHint),
              ),
            ],
          ),
      ],
    );
  }

  // ── ALBUM CARD ──
  Widget _buildAlbumCard(Map<String, dynamic> album) {
    final imagens = List<Map<String, dynamic>>.from(album['imagens'] ?? []);
    final isEditing = _editingId == album['id'];
    final currentImages = isEditing
        ? imagens
              .where((img) => !_editRemovedImageIds.contains(img['id']))
              .toList()
        : imagens;
    final idx = _carouselIndex[album['id']] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isEditing
          ? _buildEditMode(album, currentImages)
          : _buildViewMode(album, currentImages, idx),
    );
  }

  Widget _buildViewMode(
    Map<String, dynamic> album,
    List<Map<String, dynamic>> imagens,
    int idx,
  ) {
    final tipo = album['tipo_evento'] ?? 'outros';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _tipoColor(tipo).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _tipoLabel(tipo),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _tipoColor(tipo),
                            ),
                          ),
                        ),
                        if (album['data_evento'] != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            _formatDate(album['data_evento']),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_tipoNomePrefix(tipo)}: ${album['titulo'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMain,
                      ),
                    ),
                    if ((album['descricao'] ?? '').toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          album['descricao'],
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _startEdit(album),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.edit_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _handleDelete(album['id']),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Image carousel
        if (imagens.isNotEmpty)
          SizedBox(
            height: 200,
            child: Stack(
              children: [
                PageView.builder(
                  itemCount: imagens.length,
                  onPageChanged: (i) =>
                      setState(() => _carouselIndex[album['id']] = i),
                  itemBuilder: (ctx, i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imagens[i]['imagem_url'],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        loadingBuilder: (ctx, child, progress) {
                          if (progress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded /
                                        progress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade100,
                          child: const Icon(
                            Icons.broken_image,
                            size: 40,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (imagens.length > 1)
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        imagens.length,
                        (i) => Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == idx
                                ? AppColors.primary
                                : Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

        // Stats
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: Row(
            children: [
              _buildStat(
                Icons.favorite,
                Colors.red.shade400,
                '${album['reacoes_count'] ?? 0}',
              ),
              const SizedBox(width: 16),
              _buildStat(
                Icons.chat_bubble_outline,
                Colors.blue.shade400,
                '${album['comentarios_count'] ?? 0}',
              ),
              const SizedBox(width: 16),
              _buildStat(
                Icons.visibility_outlined,
                Colors.grey,
                '${album['visualizacoes_count'] ?? 0}',
              ),
              const Spacer(),
              Text(
                '${imagens.length}/5 fotos',
                style: TextStyle(fontSize: 11, color: AppColors.textHint),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStat(IconData icon, Color color, String count) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 3),
        Text(
          count,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── EDIT MODE ──
  Widget _buildEditMode(
    Map<String, dynamic> album,
    List<Map<String, dynamic>> currentImages,
  ) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Editar comunicado',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              GestureDetector(
                onTap: _cancelEdit,
                child: const Icon(
                  Icons.close,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          TextFormField(
            controller: _editTituloCtrl,
            maxLength: 100,
            decoration: InputDecoration(
              labelText: 'Título',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Type selector
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tipoEventoOptions.map((opt) {
              final selected = _editTipoEvento == opt['value'];
              return GestureDetector(
                onTap: () => setState(() => _editTipoEvento = opt['value']!),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Text(
                    opt['label']!,
                    style: TextStyle(
                      fontSize: 12,
                      color: selected ? Colors.white : AppColors.textSecondary,
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // Description
          TextFormField(
            controller: _editDescricaoCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Descrição',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Date
          GestureDetector(
            onTap: () => _pickDate(forEdit: true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _editDataEvento != null
                        ? '${_editDataEvento!.day.toString().padLeft(2, '0')}/${_editDataEvento!.month.toString().padLeft(2, '0')}/${_editDataEvento!.year}'
                        : 'Sem data',
                    style: TextStyle(
                      fontSize: 13,
                      color: _editDataEvento != null
                          ? AppColors.textMain
                          : AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Current images
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount:
                  currentImages.length +
                  _editNewPhotos.length +
                  (currentImages.length + _editNewPhotos.length < 5 ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (ctx, i) {
                if (i < currentImages.length) {
                  // Existing server images
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          currentImages[i]['imagem_url'],
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => setState(
                            () => _editRemovedImageIds.add(
                              currentImages[i]['id'],
                            ),
                          ),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }
                final newIdx = i - currentImages.length;
                if (newIdx < _editNewPhotos.length) {
                  // New local images
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(_editNewPhotos[newIdx].path),
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _editNewPhotos.removeAt(newIdx)),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.green,
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }
                // Add more button
                return GestureDetector(
                  onTap: () => _pickPhotos(forEdit: true),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.add, color: AppColors.primary, size: 24),
                  ),
                );
              },
            ),
          ),
          // Contador de fotos na edição e alerta
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${currentImages.length + _editNewPhotos.length}/5 fotos',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: (currentImages.length + _editNewPhotos.length) < 1
                        ? Colors.red
                        : AppColors.textSecondary,
                  ),
                ),
                if (currentImages.length + _editNewPhotos.length < 1)
                  const Text(
                    'Adicione ao menos 1 foto para salvar',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),

          // Buttons
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    onPressed:
                        _isSending ||
                            (currentImages.length + _editNewPhotos.length) <
                                1 ||
                            (currentImages.length + _editNewPhotos.length) > 5
                        ? null
                        : _handleSaveEdit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      disabledBackgroundColor: AppColors.primary.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    child: Text(
                      _isSending ? 'Salvando...' : 'Salvar',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 42,
                child: OutlinedButton(
                  onPressed: _cancelEdit,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
