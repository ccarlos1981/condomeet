import 'package:supabase_flutter/supabase_flutter.dart';

class ListaMercadoService {
  final _client = Supabase.instance.client;

  String? get _userId => _client.auth.currentUser?.id;

  // ══════════════════════════════════════════
  // BUSCA DE PRODUTOS (autocomplete)
  // ══════════════════════════════════════════

  /// Busca produtos base por texto (full-text search com unaccent)
  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    if (query.trim().length < 2) return [];

    final data = await _client
        .from('lista_products_base')
        .select('id, name, category, icon_emoji, lista_product_variants(id, variant_name, unit, default_weight)')
        .textSearch('search_tokens', "'${query.trim()}'", config: 'portuguese')
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
        .select('*, lista_shopping_list_items(id, variant_id, quantity, is_checked, lista_product_variants(id, variant_name, unit, lista_products_base(name, icon_emoji)))')
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
    int quantity = 1,
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
          'quantity': quantity,
        })
        .select('*, lista_product_variants(id, variant_name, unit, lista_products_base(name, icon_emoji))')
        .single();

    return data;
  }

  /// Atualizar quantidade de item
  Future<void> updateItemQuantity(String itemId, int quantity) async {
    await _client
        .from('lista_shopping_list_items')
        .update({'quantity': quantity})
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

  /// Listar supermercados para seleção
  Future<List<Map<String, dynamic>>> getSupermarkets() async {
    final data = await _client
        .from('lista_supermarkets')
        .select('id, name, is_chain')
        .order('name');
    return List<Map<String, dynamic>>.from(data);
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
  Future<void> submitPriceReport({
    required String variantId,
    required String supermarketId,
    required double price,
    String? receiptPhotoUrl,
  }) async {
    // 1) Buscar ou criar SKU genérico para a variante
    var skuData = await _client
        .from('lista_products_sku')
        .select('id')
        .eq('variant_id', variantId)
        .limit(1);

    String skuId;
    if (skuData.isEmpty) {
      final newSku = await _client
          .from('lista_products_sku')
          .insert({'variant_id': variantId, 'brand': 'Genérico'})
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

  /// Buscar preços recentes (feed para votar)
  Future<List<Map<String, dynamic>>> getRecentPrices({int limit = 20}) async {
    final data = await _client
        .from('lista_prices_raw')
        .select('id, price, source, confidence_score, confirmations, created_at, lista_products_sku(brand, weight_label, lista_product_variants(variant_name, lista_products_base(name, icon_emoji))), lista_supermarkets(name)')
        .order('created_at', ascending: false)
        .limit(limit);
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
        .select('user_id, total_points, weekly_points, reports_count, rank_title, confirmations_given')
        .order('weekly_points', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Ranking geral (all time)
  Future<List<Map<String, dynamic>>> getAllTimeLeaderboard({int limit = 20}) async {
    final data = await _client
        .from('lista_user_points')
        .select('user_id, total_points, weekly_points, reports_count, rank_title, confirmations_given')
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
        .select('*, lista_product_variants(id, variant_name, unit, lista_products_base(name, icon_emoji)), lista_supermarkets(name)')
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
      'supermarket_id': supermarketId,
      'target_price': targetPrice,
      'is_active': true,
      'is_triggered': false,
    });
  }

  /// Deletar alerta
  Future<void> deletePriceAlert(String alertId) async {
    await _client.from('lista_price_alerts').delete().eq('id', alertId);
  }

  /// Reativar alerta (resetar triggered)
  Future<void> reactivatePriceAlert(String alertId) async {
    await _client.from('lista_price_alerts').update({
      'is_triggered': false,
      'is_active': true,
      'triggered_at': null,
      'current_price': null,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', alertId);
  }
}

