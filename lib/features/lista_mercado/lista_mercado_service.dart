import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
class ListaMercadoService {
  final _client = Supabase.instance.client;

  String? get _userId => _client.auth.currentUser?.id;
  String? get currentUserId => _userId;

  // ══════════════════════════════════════════
  // BUSCA DE PRODUTOS (autocomplete)
  // ══════════════════════════════════════════

  /// Busca produtos base por texto (full-text search com unaccent)
  String _removeAccents(String str) {
    var withDia = 'ÀÁÂÃÄÅàáâãäåÒÓÔÕÕÖØòóôõöøÈÉÊËèéêëðÇçÐÌÍÎÏìíîïÙÚÛÜùúûüÑñŠšŸÿýŽž';
    var withoutDia = 'AAAAAAaaaaaaOOOOOOOooooooEEEEeeeeeCcDIIIIiiiiUUUUuuuuNnSsYyyZz';
    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
    }
    return str;
  }

  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    if (query.trim().length < 2) return [];

    // Remove acentos para bater com o to_tsvector do Supabase que armazenou sem acento
    final unaccented = _removeAccents(query.trim());
    
    // Cria formato de prefix search do tsquery: "feijão preto" -> "feijao:* & preto:*"
    final words = unaccented.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final ftsQuery = words.isEmpty ? '' : words.map((w) => "'$w':*").join(' & ');

    if (ftsQuery.isEmpty) return [];

    final data = await _client
        .from('lista_products_base')
        .select('id, name, category, icon_emoji, lista_product_variants(id, variant_name, unit, default_weight)')
        .textSearch('search_tokens', ftsQuery, config: 'portuguese', type: TextSearchType.plain)
        .limit(10);

    return List<Map<String, dynamic>>.from(data);
  }

  /// Busca variantes por nome parcial (fallback se full-text não retornar)
  Future<List<Map<String, dynamic>>> searchVariants(String query) async {
    if (query.trim().length < 2) return [];

    final data = await _client
        .from('lista_product_variants')
        .select('id, variant_name, unit, default_weight, lista_products_base!inner(id, name, icon_emoji, category)')
        .ilike('variant_name', '%${query.trim()}%')
        .limit(15);

    return List<Map<String, dynamic>>.from(data);
  }

  // ══════════════════════════════════════════
  // CRUD LISTAS DE COMPRAS
  // ══════════════════════════════════════════

  /// Buscar todas as listas do usuário
  Future<List<Map<String, dynamic>>> getMyLists() async {
    final data = await _client
        .from('lista_shopping_lists')
        .select('*, lista_shopping_list_items(id, variant_id, quantity, is_checked, custom_name, custom_note, unit_amount, unit_type, lista_product_variants(id, variant_name, unit, lista_products_base(name, icon_emoji)))')
        .eq('user_id', _userId!)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  /// Criar nova lista
  Future<Map<String, dynamic>> createList({
    required String name,
    String listType = 'quick',
  }) async {
    final data = await _client
        .from('lista_shopping_lists')
        .insert({
          'user_id': _userId,
          'name': name,
          'list_type': listType,
        })
        .select()
        .single();

    return data;
  }

  /// Renomear lista
  Future<void> renameList(String listId, String newName) async {
    await _client
        .from('lista_shopping_lists')
        .update({'name': newName})
        .eq('id', listId);
  }

  /// Deletar lista
  Future<void> deleteList(String listId) async {
    await _client
        .from('lista_shopping_lists')
        .delete()
        .eq('id', listId);
  }

  // ══════════════════════════════════════════
  // ITENS DA LISTA
  // ══════════════════════════════════════════

  /// Adicionar item à lista
  Future<Map<String, dynamic>> addItem({
    required String listId,
    required String variantId,
    String unitType = 'un',
    double unitAmount = 1.0,
  }) async {
    // Incrementar popularidade da variante
    await _client.rpc('lista_increment_variant_popularity', params: {
      'p_variant_id': variantId,
    });

    final data = await _client
        .from('lista_shopping_list_items')
        .insert({
          'list_id': listId,
          'variant_id': variantId,
          'unit_type': unitType,
          'unit_amount': unitAmount,
        })
        .select('*, lista_product_variants(id, variant_name, unit, lista_products_base(name, icon_emoji))')
        .single();

    return data;
  }

  /// Adicionar item de texto livre (Bring!-style)
  Future<Map<String, dynamic>> addFreeTextItem({
    required String listId,
    required String customName,
    String unitType = 'un',
    double unitAmount = 1.0,
    String? note,
  }) async {
    // Normalização básica client-side
    final trimmed = customName.trim();
    final displayName = trimmed.isEmpty ? '' : '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';

    final data = await _client
        .from('lista_shopping_list_items')
        .insert({
          'list_id': listId,
          'custom_name': displayName,
          'unit_type': unitType,
          'unit_amount': unitAmount,
          'custom_note': note,
        })
        .select()
        .single();

    return data;
  }

  /// Atualizar quantidade/unidade de um item
  Future<void> updateItemUnit(String itemId, double amount) async {
    await _client
        .from('lista_shopping_list_items')
        .update({'unit_amount': amount})
        .eq('id', itemId);
  }

  /// Marcar/desmarcar item como comprado
  Future<void> toggleItemChecked(String itemId, bool isChecked) async {
    await _client
        .from('lista_shopping_list_items')
        .update({'is_checked': isChecked})
        .eq('id', itemId);
  }

  /// Remover item da lista
  Future<void> removeItem(String itemId) async {
    await _client
        .from('lista_shopping_list_items')
        .delete()
        .eq('id', itemId);
  }

  // ══════════════════════════════════════════
  // ESTIMATIVA DE PREÇOS AO VIVO
  // ══════════════════════════════════════════

  /// Buscar estimativa de preço para uma variante (range min/max)
  Future<Map<String, dynamic>?> getPriceEstimate(String variantId) async {
    final data = await _client
        .from('lista_prices_current')
        .select('price, supermarket_id, lista_supermarkets(name), lista_products_sku!inner(variant_id)')
        .eq('lista_products_sku.variant_id', variantId)
        .eq('is_stale', false)
        .order('price')
        .limit(10);

    if (data.isEmpty) return null;

    final prices = List<Map<String, dynamic>>.from(data);
    final allPrices = prices.map((p) => (p['price'] as num).toDouble()).toList();

    return {
      'min_price': allPrices.first,
      'max_price': allPrices.last,
      'avg_price': allPrices.reduce((a, b) => a + b) / allPrices.length,
      'cheapest_market': prices.first['lista_supermarkets']?['name'] ?? 'N/A',
      'count': allPrices.length,
    };
  }

  /// Buscar estimativa total da lista por supermercado
  Future<List<Map<String, dynamic>>> getListEstimate(String listId) async {
    // Buscar itens da lista
    final items = await _client
        .from('lista_shopping_list_items')
        .select('variant_id, quantity')
        .eq('list_id', listId);

    if (items.isEmpty) return [];

    // Buscar supermercados que têm preços
    final markets = await _client
        .from('lista_supermarkets')
        .select('id, name, logo_url')
        .limit(20);

    List<Map<String, dynamic>> estimates = [];

    for (final market in markets) {
      double total = 0;
      int matchedItems = 0;

      for (final item in items) {
        final variantId = item['variant_id'];
        final quantity = item['quantity'] as int;

        // Buscar preço neste mercado para este produto
        final priceData = await _client
            .from('lista_prices_current')
            .select('price, lista_products_sku!inner(variant_id)')
            .eq('supermarket_id', market['id'])
            .eq('lista_products_sku.variant_id', variantId)
            .eq('is_stale', false)
            .order('price')
            .limit(1);

        if (priceData.isNotEmpty) {
          total += (priceData.first['price'] as num).toDouble() * quantity;
          matchedItems++;
        }
      }

      if (matchedItems > 0) {
        estimates.add({
          'market_id': market['id'],
          'market_name': market['name'],
          'logo_url': market['logo_url'],
          'total': total,
          'matched_items': matchedItems,
          'total_items': items.length,
          'coverage': (matchedItems / items.length * 100).round(),
        });
      }
    }

    estimates.sort((a, b) => (a['total'] as double).compareTo(b['total'] as double));
    return estimates;
  }

  // ══════════════════════════════════════════
  // PROMOÇÕES PRÓXIMAS
  // ══════════════════════════════════════════

  /// Buscar promoções ativas
  Future<List<Map<String, dynamic>>> getActivePromotions({int limit = 10}) async {
    final data = await _client
        .from('lista_promotions')
        .select('*, lista_supermarkets(name, logo_url), lista_products_sku(brand, weight_label, lista_product_variants(variant_name, lista_products_base(name, icon_emoji)))')
        .gte('ends_at', DateTime.now().toIso8601String())
        .order('discount_percent', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(data);
  }

  // ══════════════════════════════════════════
  // GAMIFICAÇÃO
  // ══════════════════════════════════════════

  /// Buscar pontos do usuário
  Future<Map<String, dynamic>?> getMyPoints() async {
    final data = await _client
        .from('lista_user_points')
        .select()
        .eq('user_id', _userId!)
        .maybeSingle();

    return data;
  }

  /// Buscar ranking semanal
  Future<List<Map<String, dynamic>>> getWeeklyRanking({int limit = 10}) async {
    final data = await _client
        .from('lista_user_points')
        .select('user_id, weekly_points, rank_title, total_points')
        .order('weekly_points', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(data);
  }

  // ══════════════════════════════════════════
  // CROWDSOURCING
  // ══════════════════════════════════════════

  // ══════════════════════════════════════════
  // SUPERS / SUPERMERCADOS (COM GEOLOCALIZAÇÃO)
  // ══════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getSupermarkets() async {
    final data = await _client
        .from('lista_supermarkets')
        .select('*')
        .order('name');
    return List<Map<String, dynamic>>.from(data);
  }

  /// Busca supermercados nas redondezas via GPS chamando a Edge Function.
  /// A Function faz UPSERT automático na base para futuros acessos!
  Future<List<Map<String, dynamic>>> getNearbySupermarkets(double lat, double lng) async {
    try {
      final response = await _client.functions.invoke(
        'lista-supermarkets-nearby',
        body: {'lat': lat, 'lng': lng, 'radius': 5000},
      );
      
      if (response.status == 200 && response.data != null) {
        final List lists = response.data as List;
        return List<Map<String, dynamic>>.from(lists);
      } else {
        throw Exception('Erro ao buscar locais próximos: ${response.status}');
      }
    } catch (e) {
      // Fallback para os mercados hardcoded se a Edge Function falhar
      debugPrint('Falha ao buscar GPS Google Places, fazendo fallback: $e');
      return getSupermarkets();
    }
  }

  /// Buscar variantes populares (para seleção rápida)
  Future<List<Map<String, dynamic>>> getPopularVariants({int limit = 30}) async {
    final data = await _client
        .from('lista_product_variants')
        .select('id, variant_name, unit, default_weight, lista_products_base(name, icon_emoji, category)')
        .order('popularity_score', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Reportar preço (crowdsourcing)
  /// Buscar marcas por categoria do produto
  Future<List<Map<String, dynamic>>> getBrandsByCategory(String category) async {
    final data = await _client
        .from('lista_brands')
        .select('id, name')
        .eq('category', category)
        .order('name');
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> submitPriceReport({
    required String variantId,
    required String supermarketId,
    required double price,
    String? receiptPhotoUrl,
    String? brand,
    String? weightLabel,
  }) async {
    final brandName = (brand != null && brand.isNotEmpty) ? brand : 'Genérico';

    if (brandName != 'Genérico') {
      try {
        final variantData = await _client
            .from('lista_product_variants')
            .select('lista_products_base(category)')
            .eq('id', variantId)
            .single();
        
        final categoryMap = variantData['lista_products_base'];
        if (categoryMap != null && categoryMap is Map) {
          final category = categoryMap['category'];
          if (category != null) {
            await _client.from('lista_brands').upsert({
              'name': brandName,
              'category': category
            }, onConflict: 'name');
          }
        }
      } catch (e) {
        print('Erro ao persistir marca customizada: $e');
      }
    }

    // 1) Buscar ou criar SKU para variante+marca
    var query = _client
        .from('lista_products_sku')
        .select('id')
        .eq('variant_id', variantId)
        .eq('brand', brandName);
    
    var skuData = await query.limit(1);

    String skuId;
    if (skuData.isEmpty) {
      final insertData = <String, dynamic>{
        'variant_id': variantId,
        'brand': brandName,
      };
      if (weightLabel != null && weightLabel.isNotEmpty) {
        insertData['weight_label'] = weightLabel;
      }
      final newSku = await _client
          .from('lista_products_sku')
          .insert(insertData)
          .select('id')
          .single();
      skuId = newSku['id'];
    } else {
      skuId = skuData.first['id'];
    }

    // 2) Inserir preço bruto
    await _client.from('lista_prices_raw').insert({
      'sku_id': skuId,
      'supermarket_id': supermarketId,
      'price': price,
      'source': 'crowd',
      'confidence_score': 0.6,
      'reported_by': _userId,
    });

    // 3) Inserir no relatório
    await _client.from('lista_price_reports').insert({
      'user_id': _userId,
      'sku_id': skuId,
      'supermarket_id': supermarketId,
      'price': price,
      'receipt_photo_url': receiptPhotoUrl,
    });

    // 4) Upsert no prices_current
    await _client.from('lista_prices_current').upsert({
      'sku_id': skuId,
      'supermarket_id': supermarketId,
      'price': price,
      'price_type': 'regular',
      'confidence_score': 0.6,
      'is_stale': false,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'sku_id,supermarket_id');

    // 5) Adicionar pontos ao usuário
    await _client.rpc('lista_add_points', params: {
      'p_user_id': _userId,
      'p_points': 10,
    });
  }

  /// Salva itens identificados no OCR, mas que não foram encontrados no catálogo
  Future<void> submitProductSuggestion({
    required String rawName,
    required String supermarketId,
    double? unitPrice,
    double? totalPrice,
    double? quantity,
    String? brand,
    String? weightLabel,
  }) async {
    final _userId = _client.auth.currentUser?.id;
    if (_userId == null) return;

    await _client.from('lista_product_suggestions').insert({
      'user_id': _userId,
      'raw_name': rawName,
      'supermarket_id': supermarketId,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      'quantity': quantity,
      'brand': brand,
      'weight_label': weightLabel,
      'status': 'pending',
    });

    // Recompensar contribuição (ex: 10 pontos)
    await _client.rpc('lista_add_points', params: {
      'p_user_id': _userId,
      'p_points': 10,
    });
  }

  /// Buscar preços recentes (feed para votar)
  Future<List<Map<String, dynamic>>> getRecentPrices({int limit = 50, String? marketId}) async {
    final selectStr = 'id, price, source, confidence_score, confirmations, created_at, supermarket_id, sku_id, reported_by, lista_products_sku(brand, weight_label, lista_product_variants(variant_name, lista_products_base(name, icon_emoji))), lista_supermarkets(name)';
    
    dynamic data;
    if (marketId != null && marketId.isNotEmpty) {
      data = await _client
          .from('lista_prices_raw')
          .select(selectStr)
          .eq('supermarket_id', marketId)
          .order('created_at', ascending: false)
          .limit(limit);
    } else {
      data = await _client
          .from('lista_prices_raw')
          .select(selectStr)
          .order('created_at', ascending: false)
          .limit(limit);
    }
    return List<Map<String, dynamic>>.from(data);
  }

  /// Votar em preço (confirmar ou negar)
  Future<void> voteOnPrice(String priceRawId, String vote) async {
    await _client.from('lista_price_votes').upsert({
      'price_raw_id': priceRawId,
      'user_id': _userId,
      'vote': vote,
    }, onConflict: 'price_raw_id,user_id');

    // Incrementar confirmações se confirmou
    if (vote == 'confirm') {
      await _client.rpc('lista_increment_confirmations', params: {
        'p_price_id': priceRawId,
      });
    }

    // Pontos por voto
    await _client.rpc('lista_add_points', params: {
      'p_user_id': _userId,
      'p_points': 2,
    });
  }

  // ══════════════════════════════════════════
  // GAMIFICAÇÃO & LEADERBOARD
  // ══════════════════════════════════════════

  /// Ranking semanal (top users)
  Future<List<Map<String, dynamic>>> getWeeklyLeaderboard({int limit = 20}) async {
    final data = await _client
        .from('lista_user_points')
        .select('user_id, total_points, weekly_points, reports_count, rank_title')
        .order('weekly_points', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Ranking geral (all time)
  Future<List<Map<String, dynamic>>> getAllTimeLeaderboard({int limit = 20}) async {
    final data = await _client
        .from('lista_user_points')
        .select('user_id, total_points, weekly_points, reports_count, rank_title')
        .order('total_points', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Buscar perfil de nomes para o leaderboard
  Future<Map<String, String>> getUserNames(List<String> userIds) async {
    if (userIds.isEmpty) return {};
    final data = await _client
        .from('perfil')
        .select('id, nome_completo')
        .inFilter('id', userIds);
    final map = <String, String>{};
    for (final p in data) {
      map[p['id']] = p['nome_completo'] ?? 'Anônimo';
    }
    return map;
  }

  /// Stats gerais da comunidade
  Future<Map<String, dynamic>> getCommunityStats() async {
    final prices = await _client.from('lista_prices_raw').select('id').limit(1000);
    final users = await _client.from('lista_user_points').select('user_id').limit(1000);

    return {
      'total_prices': (prices as List).length,
      'total_contributors': (users as List).length,
    };
  }

  // ══════════════════════════════════════════
  // ALERTAS DE PREÇO
  // ══════════════════════════════════════════

  /// Buscar meus alertas de preço
  Future<List<Map<String, dynamic>>> getMyAlerts() async {
    final data = await _client
        .from('lista_price_alerts')
        .select('*, lista_product_variants(id, variant_name, unit, lista_products_base(name, icon_emoji))')
        .eq('user_id', _userId!)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Criar alerta de preço
  Future<void> createPriceAlert({
    required String variantId,
    String? supermarketId,
    required double targetPrice,
  }) async {
    await _client.from('lista_price_alerts').insert({
      'user_id': _userId,
      'variant_id': variantId,
      'target_price': targetPrice,
      'is_active': true,
    });
  }

  /// Deletar alerta
  Future<void> deletePriceAlert(String alertId) async {
    await _client.from('lista_price_alerts').delete().eq('id', alertId);
  }

  /// Reativar alerta (resetar triggered)
  Future<void> reactivatePriceAlert(String alertId) async {
    await _client.from('lista_price_alerts').update({
      'is_active': true,
    }).eq('id', alertId);
  }

  // ══════════════════════════════════════════
  // DASHBOARD E HISTÓRICO 
  // ══════════════════════════════════════════

  /// Busca o histórico de preços de um determinado SKU (variante + marca)
  Future<List<Map<String, dynamic>>> getProductPriceHistory(String skuId) async {
    final data = await _client
        .from('lista_prices_raw')
        .select('price, created_at, lista_supermarkets!inner(name)')
        .eq('sku_id', skuId)
        .order('created_at');
    
    return List<Map<String, dynamic>>.from(data);
  }

  /// Busca dados agregados para o Dashboard Global
  Future<List<Map<String, dynamic>>> getGlobalDashboardData({String? skuId, String? marketName, int days = 30}) async {
    final threshold = DateTime.now().subtract(Duration(days: days)).toIso8601String();
    var query = _client
        .from('lista_prices_raw')
        .select('price, created_at, sku_id, lista_products_sku!inner(lista_product_variants(variant_name, lista_products_base(name, icon_emoji)), brand, weight_label), lista_supermarkets!inner(name, latitude, longitude)')
        .gte('created_at', threshold);

    if (skuId != null && skuId.isNotEmpty) {
      query = query.eq('sku_id', skuId);
    }

    final data = await query.order('created_at', ascending: true);
    final list = List<Map<String, dynamic>>.from(data);

    if (marketName != null && marketName.isNotEmpty) {
      return list.where((item) {
        final rawName = item['lista_supermarkets']?['name'] as String? ?? '';
        final cleanName = rawName.split('-').first.split(':').first.trim();
        return cleanName.toLowerCase() == marketName.toLowerCase();
      }).toList();
    }

    return list;
  }
}
