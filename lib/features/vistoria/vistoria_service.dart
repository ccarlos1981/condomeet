import 'dart:developer' as dev;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VistoriaService {
  final _supabase = Supabase.instance.client;

  String? get _userId => _supabase.auth.currentUser?.id;

  // ═══════════════════════════════════════════════════
  // Templates
  // ═══════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> listTemplates() async {
    final data = await _supabase
        .from('vistoria_templates')
        .select('*')
        .eq('is_public', true)
        .order('created_at');
    return List<Map<String, dynamic>>.from(data);
  }

  // ═══════════════════════════════════════════════════
  // Vistorias
  // ═══════════════════════════════════════════════════

  /// Lista vistorias do condomínio
  Future<List<Map<String, dynamic>>> listVistorias(String condominioId) async {
    final data = await _supabase
        .from('vistorias')
        .select('*, perfil!vistorias_criado_por_fkey(nome_completo)')
        .eq('condominio_id', condominioId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Criar vistoria a partir de template
  Future<Map<String, dynamic>> createVistoria({
    required String condominioId,
    required String titulo,
    required String tipoBem,
    required String tipoVistoria,
    String templateId = '',
    String endereco = '',
    String responsavelNome = '',
    String proprietarioNome = '',
    String inquilinoNome = '',
    String plano = 'free',
  }) async {
    final vistoria = await _supabase
        .from('vistorias')
        .insert({
          'condominio_id': condominioId,
          'criado_por': _userId,
          'titulo': titulo,
          'tipo_bem': tipoBem,
          'tipo_vistoria': tipoVistoria,
          'template_id': templateId.isEmpty ? null : templateId,
          'endereco': endereco,
          'responsavel_nome': responsavelNome,
          'proprietario_nome': proprietarioNome,
          'inquilino_nome': inquilinoNome,
          'plano': plano,
        })
        .select()
        .single();

    // Carregar seções do template
    if (templateId.isNotEmpty) {
      final tmplSecoes = await _supabase
          .from('vistoria_template_secoes')
          .select('*')
          .eq('template_id', templateId)
          .order('posicao');
      for (final s in tmplSecoes) {
        final secao = await _supabase
            .from('vistoria_secoes')
            .insert({
              'vistoria_id': vistoria['id'],
              'nome': s['nome'],
              'icone_emoji': s['icone_emoji'] ?? '🏠',
              'posicao': s['posicao'],
            })
            .select()
            .single();

        final tmplItens = await _supabase
            .from('vistoria_template_itens')
            .select('*')
            .eq('secao_id', s['id'])
            .order('posicao');
        if (tmplItens.isNotEmpty) {
          await _supabase.from('vistoria_itens').insert(
            tmplItens.map((i) => {
              'secao_id': secao['id'],
              'nome': i['nome'],
              'posicao': i['posicao'],
            }).toList(),
          );
        }
      }
    }

    return vistoria;
  }

  /// Atualizar status da vistoria
  Future<void> updateStatus(String vistoriaId, String status) async {
    await _supabase
        .from('vistorias')
        .update({'status': status})
        .eq('id', vistoriaId);
  }

  /// Atualizar plano da vistoria (free → plus) após pagamento
  Future<void> updateVistoriaPlano(String vistoriaId, String plano) async {
    await _supabase
        .from('vistorias')
        .update({'plano': plano})
        .eq('id', vistoriaId);
  }

  /// Gerar link público
  Future<String> gerarLinkPublico(String vistoriaId) async {
    final token = DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
        vistoriaId.substring(0, 8);
    await _supabase
        .from('vistorias')
        .update({'link_publico_token': token})
        .eq('id', vistoriaId);
    return token;
  }

  /// Deletar vistoria
  Future<void> deleteVistoria(String vistoriaId) async {
    await _supabase.from('vistorias').delete().eq('id', vistoriaId);
  }

  // ═══════════════════════════════════════════════════
  // Seções
  // ═══════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> listSecoes(String vistoriaId) async {
    final data = await _supabase
        .from('vistoria_secoes')
        .select('*')
        .eq('vistoria_id', vistoriaId)
        .order('posicao');
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>> addSecao(String vistoriaId, String nome, int posicao) async {
    return await _supabase
        .from('vistoria_secoes')
        .insert({
          'vistoria_id': vistoriaId,
          'nome': nome,
          'posicao': posicao,
        })
        .select()
        .single();
  }

  // ═══════════════════════════════════════════════════
  // Itens
  // ═══════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> listItens(List<String> secaoIds) async {
    if (secaoIds.isEmpty) return [];
    final data = await _supabase
        .from('vistoria_itens')
        .select('*')
        .inFilter('secao_id', secaoIds)
        .order('posicao');
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>> addItem(String secaoId, String nome, int posicao) async {
    return await _supabase
        .from('vistoria_itens')
        .insert({
          'secao_id': secaoId,
          'nome': nome,
          'posicao': posicao,
        })
        .select()
        .single();
  }

  Future<void> updateItem(String itemId, Map<String, dynamic> updates) async {
    await _supabase.from('vistoria_itens').update(updates).eq('id', itemId);
  }

  // ═══════════════════════════════════════════════════
  // Fotos
  // ═══════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> listFotos(List<String> itemIds) async {
    if (itemIds.isEmpty) return [];
    final data = await _supabase
        .from('vistoria_fotos')
        .select('*')
        .inFilter('item_id', itemIds)
        .order('posicao');
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>> uploadFoto({
    required String itemId,
    required String condominioId,
    required String vistoriaId,
    required File file,
    int posicao = 0,
    String condoNome = '',
  }) async {
    // Apply watermark before upload
    final watermarked = await _addWatermark(file, condoNome);
    final ext = file.path.split('.').last;
    final path = '$condominioId/$vistoriaId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _supabase.storage
        .from('vistoria-fotos')
        .upload(path, watermarked, fileOptions: const FileOptions(upsert: true));
    final url = _supabase.storage.from('vistoria-fotos').getPublicUrl(path);

    return await _supabase
        .from('vistoria_fotos')
        .insert({
          'item_id': itemId,
          'foto_url': url,
          'posicao': posicao,
        })
        .select()
        .single();
  }

  /// Adds a watermark banner at the bottom of the photo with date/time and condo name
  Future<File> _addWatermark(File file, String condoNome) async {
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final w = image.width.toDouble();
      final h = image.height.toDouble();

      // Draw original image
      canvas.drawImage(image, ui.Offset.zero, ui.Paint());

      // Semi-transparent banner at bottom
      final bannerHeight = h * 0.06;
      final bannerRect = ui.Rect.fromLTWH(0, h - bannerHeight, w, bannerHeight);
      canvas.drawRect(
        bannerRect,
        ui.Paint()..color = const ui.Color(0xAA000000),
      );

      // Watermark text
      final now = DateTime.now();
      final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      final text = condoNome.isEmpty ? 'Condomeet · $dateStr' : '$condoNome · $dateStr';

      final fontSize = (w * 0.028).clamp(14.0, 40.0);
      final textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: const ui.Color(0xDDFFFFFF),
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(maxWidth: w - 20);
      textPainter.paint(
        canvas,
        Offset(10, h - bannerHeight + (bannerHeight - textPainter.height) / 2),
      );

      final picture = recorder.endRecording();
      final rendered = await picture.toImage(image.width, image.height);
      final pngBytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      rendered.dispose();

      if (pngBytes == null) return file;

      final tempDir = Directory.systemTemp;
      final watermarkedFile = File('${tempDir.path}/wm_${DateTime.now().millisecondsSinceEpoch}.png');
      await watermarkedFile.writeAsBytes(Uint8List.view(pngBytes.buffer));
      return watermarkedFile;
    } catch (e) {
      dev.log('[VistoriaService] Watermark failed, using original: $e');
      return file; // Fallback: upload without watermark
    }
  }

  Future<void> deleteFoto(String fotoId) async {
    await _supabase.from('vistoria_fotos').delete().eq('id', fotoId);
  }

  // ═══════════════════════════════════════════════════
  // Assinaturas
  // ═══════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> listAssinaturas(String vistoriaId) async {
    final data = await _supabase
        .from('vistoria_assinaturas')
        .select('*')
        .eq('vistoria_id', vistoriaId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> addAssinatura({
    required String vistoriaId,
    required String nome,
    required String papel,
  }) async {
    await _supabase.from('vistoria_assinaturas').insert({
      'vistoria_id': vistoriaId,
      'nome': nome,
      'papel': papel,
    });
  }

  Future<void> assinar(String assinaturaId, String dataUrl, String condominioId, String vistoriaId) async {
    // Upload the signature image
    final path = '$condominioId/$vistoriaId/$assinaturaId.png';
    // We need to convert dataUrl to bytes first
    // For now, just update with the URL after the caller uploads
    final url = _supabase.storage.from('vistoria-assinaturas').getPublicUrl(path);
    await _supabase.from('vistoria_assinaturas').update({
      'assinatura_url': url,
      'assinado_em': DateTime.now().toIso8601String(),
    }).eq('id', assinaturaId);
  }

  // ═══════════════════════════════════════════════════
  // Notificação (fire-and-forget)
  // ═══════════════════════════════════════════════════

  Future<void> sendNotification({
    required String condominioId,
    required String vistoriaId,
    required String action,
  }) async {
    try {
      await _supabase.functions.invoke('vistoria-notify', body: {
        'condominio_id': condominioId,
        'vistoria_id': vistoriaId,
        'action': action,
      });
      dev.log('[VistoriaService] Notification sent: $action');
    } catch (e) {
      dev.log('[VistoriaService] Notification failed: $e');
    }
  }

  // ═══════════════════════════════════════════════════
  // Timeline (histórico do imóvel)
  // ═══════════════════════════════════════════════════

  /// Lista vistorias do mesmo endereço para timeline
  Future<List<Map<String, dynamic>>> listTimeline(String condominioId, String endereco) async {
    final data = await _supabase
        .from('vistorias')
        .select('*, perfil!vistorias_criado_por_fkey(nome_completo)')
        .eq('condominio_id', condominioId)
        .ilike('endereco', '%$endereco%')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  // ═══════════════════════════════════════════════════
  // IA Análise de Danos
  // ═══════════════════════════════════════════════════

  /// Invoca Edge Function para analisar foto com IA
  Future<Map<String, dynamic>?> analyzePhoto(String fotoId, String fotoUrl, String itemName) async {
    try {
      final response = await _supabase.functions.invoke('vistoria-ai-analyze', body: {
        'foto_id': fotoId,
        'foto_url': fotoUrl,
        'item_name': itemName,
      });
      if (response.data != null) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      return null;
    } catch (e) {
      dev.log('[VistoriaService] AI analysis failed: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════
  // Controle de Plano (Free vs Plus)
  // ═══════════════════════════════════════════════════

  static const freeLimits = {
    'max_secoes': 3,
    'max_itens_por_secao': 5,
    'max_fotos_por_item': 2,
    'ai_analise': false,
    'pdf_export': false,
  };

  static const plusLimits = {
    'max_secoes': 999,
    'max_itens_por_secao': 999,
    'max_fotos_por_item': 999,
    'ai_analise': true,
    'pdf_export': true,
  };

  static Map<String, dynamic> getLimits(String plano) {
    return plano == 'plus' ? plusLimits : freeLimits;
  }
}

