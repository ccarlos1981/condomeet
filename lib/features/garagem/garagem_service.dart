import 'dart:developer' as dev;
import 'package:supabase_flutter/supabase_flutter.dart';

class GaragemService {
  final _supabase = Supabase.instance.client;

  String? get _userId => _supabase.auth.currentUser?.id;

  // ═══════════════════════════════════════════════════
  // Notificação via Edge Function (fire-and-forget)
  // ═══════════════════════════════════════════════════

  Future<void> _sendNotification({
    required String condominioId,
    required String reservationId,
    required String action,
  }) async {
    try {
      await _supabase.functions.invoke('garagem-notify', body: {
        'condominio_id': condominioId,
        'reservation_id': reservationId,
        'action': action,
      });
      dev.log('[GaragemService] Notification sent: $action');
    } catch (e) {
      dev.log('[GaragemService] Notification failed ($action): $e');
      // Non-blocking — don't throw
    }
  }

  // ═══════════════════════════════════════════════════
  // Vagas (Garages)
  // ═══════════════════════════════════════════════════

  /// Lista vagas ativas do condomínio
  Future<List<Map<String, dynamic>>> listVagas(String condominioId) async {
    final data = await _supabase
        .from('garages')
        .select('*, perfil!garages_owner_id_fkey(nome_completo, foto_url)')
        .eq('condominio_id', condominioId)
        .eq('ativo', true)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Lista minhas vagas
  Future<List<Map<String, dynamic>>> listMinhasVagas() async {
    if (_userId == null) return [];
    final data = await _supabase
        .from('garages')
        .select('*')
        .eq('owner_id', _userId!)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Detalhe de uma vaga (com disponibilidade e avaliações)
  Future<Map<String, dynamic>?> getVagaDetalhe(String vagaId) async {
    final data = await _supabase
        .from('garages')
        .select('''
          *,
          perfil!garages_owner_id_fkey(nome_completo, foto_url, bloco_txt, apto_txt),
          garage_availability(*),
          garage_reviews(rating)
        ''')
        .eq('id', vagaId)
        .maybeSingle();
    return data;
  }

  /// Criar nova vaga
  Future<Map<String, dynamic>> createVaga({
    required String condominioId,
    String? apartamentoId,
    required String numeroVaga,
    required String tipoVaga,
    String? descricao,
    double precoHora = 0,
    double precoDia = 0,
    double precoMes = 0,
    List<Map<String, dynamic>>? disponibilidade,
  }) async {
    final garage = await _supabase
        .from('garages')
        .insert({
          'condominio_id': condominioId,
          'apartamento_id': apartamentoId,
          'owner_id': _userId,
          'numero_vaga': numeroVaga,
          'tipo_vaga': tipoVaga,
          'descricao': descricao,
          'preco_hora': precoHora,
          'preco_dia': precoDia,
          'preco_mes': precoMes,
        })
        .select()
        .single();

    // Se tem disponibilidade programada, inserir
    if (disponibilidade != null && disponibilidade.isNotEmpty) {
      final availRows = disponibilidade.map((d) => {
          'garage_id': garage['id'],
          'dia_semana': d['dia_semana'],
          'hora_inicio': d['hora_inicio'],
          'hora_fim': d['hora_fim'],
        }).toList();
      await _supabase.from('garage_availability').insert(availRows);
    }

    return garage;
  }

  /// Atualizar vaga
  Future<void> updateVaga(String vagaId, Map<String, dynamic> updates) async {
    updates['updated_at'] = DateTime.now().toIso8601String();
    await _supabase.from('garages').update(updates).eq('id', vagaId);
  }

  /// Desativar/Ativar vaga
  Future<void> toggleVaga(String vagaId, bool ativo) async {
    await _supabase
        .from('garages')
        .update({'ativo': ativo, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', vagaId);
  }

  /// Deletar vaga
  Future<void> deleteVaga(String vagaId) async {
    await _supabase.from('garages').delete().eq('id', vagaId);
  }

  // ═══════════════════════════════════════════════════
  // Reservas
  // ═══════════════════════════════════════════════════

  /// Criar reserva via RPC
  Future<Map<String, dynamic>> createReserva({
    required String garageId,
    required String condominioId,
    required String placa,
    required String modelo,
    required String cor,
    required DateTime inicio,
    required DateTime fim,
    String tipoPeriodo = 'hora',
    String? observacao,
  }) async {
    final result = await _supabase.rpc('garage_create_reservation', params: {
      'p_garage_id': garageId,
      'p_placa': placa,
      'p_modelo': modelo,
      'p_cor': cor,
      'p_inicio': inicio.toIso8601String(),
      'p_fim': fim.toIso8601String(),
      'p_tipo_periodo': tipoPeriodo,
      'p_observacao': observacao,
    });
    final reservation = Map<String, dynamic>.from(result);

    // Fire-and-forget: notify owner
    _sendNotification(
      condominioId: condominioId,
      reservationId: reservation['id']?.toString() ?? '',
      action: 'reserva_nova',
    );

    return reservation;
  }

  /// Listar minhas reservas (como motorista)
  Future<List<Map<String, dynamic>>> listMinhasReservas() async {
    if (_userId == null) return [];
    final data = await _supabase
        .from('garage_reservations')
        .select('*, garages(numero_vaga, tipo_vaga, condominio_id, perfil!garages_owner_id_fkey(nome_completo))')
        .eq('user_id', _userId!)
        .order('inicio', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Listar reservas das minhas vagas (como dono)
  Future<List<Map<String, dynamic>>> listReservasDasMinhasVagas() async {
    if (_userId == null) return [];
    // Primeiro pega IDs das vagas do usuário
    final garages = await _supabase
        .from('garages')
        .select('id')
        .eq('owner_id', _userId!);
    final ids = List<Map<String, dynamic>>.from(garages)
        .map((g) => g['id'] as String)
        .toList();
    if (ids.isEmpty) return [];

    final data = await _supabase
        .from('garage_reservations')
        .select('*, perfil!garage_reservations_user_id_fkey(nome_completo, foto_url), garages(numero_vaga)')
        .inFilter('garage_id', ids)
        .order('inicio', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Confirmar reserva (dono aceita)
  Future<void> confirmarReserva(String reservaId, String condominioId) async {
    await _supabase
        .from('garage_reservations')
        .update({'status': 'confirmado', 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', reservaId);

    // Fire-and-forget: notify renter
    _sendNotification(
      condominioId: condominioId,
      reservationId: reservaId,
      action: 'reserva_confirmada',
    );
  }

  /// Cancelar reserva
  Future<void> cancelarReserva(String reservaId, String condominioId) async {
    await _supabase
        .from('garage_reservations')
        .update({'status': 'cancelado', 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', reservaId);

    // Fire-and-forget: notify both parties
    _sendNotification(
      condominioId: condominioId,
      reservationId: reservaId,
      action: 'reserva_cancelada',
    );
  }

  /// Finalizar reserva
  Future<void> finalizarReserva(String reservaId) async {
    await _supabase
        .from('garage_reservations')
        .update({'status': 'finalizado', 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', reservaId);
  }

  /// Reportar problema
  Future<void> reportarProblema(String reservaId) async {
    await _supabase
        .from('garage_reservations')
        .update({'status': 'problema', 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', reservaId);
  }

  // ═══════════════════════════════════════════════════
  // Avaliações
  // ═══════════════════════════════════════════════════

  Future<void> avaliarReserva(String reservaId, int rating, String? comentario) async {
    await _supabase.from('garage_reviews').insert({
      'reservation_id': reservaId,
      'reviewer_id': _userId,
      'rating': rating,
      'comentario': comentario,
    });
  }

  /// Média de avaliação de uma vaga
  Future<double> getRatingVaga(String garageId) async {
    final data = await _supabase
        .from('garage_reviews')
        .select('rating')
        .inFilter('reservation_id',
          (await _supabase
              .from('garage_reservations')
              .select('id')
              .eq('garage_id', garageId))
              .map((r) => r['id'])
              .toList());
    if (data.isEmpty) return 0;
    final ratings = List<Map<String, dynamic>>.from(data);
    final sum = ratings.fold(0, (s, r) => s + (r['rating'] as int));
    return sum / ratings.length;
  }

  // ═══════════════════════════════════════════════════
  // Ranking de ganhos
  // ═══════════════════════════════════════════════════

  /// Top ganhos do mês no condomínio
  Future<List<Map<String, dynamic>>> getRanking(String condominioId) async {
    final now = DateTime.now();
    final mesAtual = DateTime(now.year, now.month, 1).toIso8601String().split('T')[0];

    final data = await _supabase
        .from('garage_reservations')
        .select('''
          valor_total,
          garages!inner(
            id, numero_vaga, condominio_id,
            perfil!garages_owner_id_fkey(nome_completo, foto_url)
          )
        ''')
        .eq('garages.condominio_id', condominioId)
        .eq('status', 'finalizado')
        .gte('created_at', '$mesAtual T00:00:00')
        .order('valor_total', ascending: false);

    // Agrupar por dono
    final Map<String, Map<String, dynamic>> agrupado = {};
    for (final r in List<Map<String, dynamic>>.from(data)) {
      final garage = r['garages'] as Map<String, dynamic>;
      final perfil = garage['perfil'] as Map<String, dynamic>?;
      final ownerId = garage['id'] as String;
      if (!agrupado.containsKey(ownerId)) {
        agrupado[ownerId] = {
          'nome': perfil?['nome_completo'] ?? 'Morador',
          'foto_url': perfil?['foto_url'],
          'vaga': garage['numero_vaga'],
          'total': 0.0,
          'reservas': 0,
        };
      }
      agrupado[ownerId]!['total'] =
          (agrupado[ownerId]!['total'] as double) + ((r['valor_total'] ?? 0) as num).toDouble();
      agrupado[ownerId]!['reservas'] = (agrupado[ownerId]!['reservas'] as int) + 1;
    }

    final ranking = agrupado.values.toList()
      ..sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
    return ranking.take(10).toList();
  }

  // ═══════════════════════════════════════════════════
  // Trial do condomínio
  // ═══════════════════════════════════════════════════

  /// Verificar ou iniciar trial do condomínio
  Future<Map<String, dynamic>> checkTrial(String condominioId) async {
    // Verificar se já existe trial
    var trial = await _supabase
        .from('garage_condo_trial')
        .select()
        .eq('condominio_id', condominioId)
        .maybeSingle();

    trial ??= await _supabase
        .from('garage_condo_trial')
        .insert({'condominio_id': condominioId})
        .select()
        .single();

    final endsAt = DateTime.parse(trial['trial_ends_at']);
    final daysLeft = endsAt.difference(DateTime.now()).inDays;

    return {
      'is_active': trial['is_active'] == true && daysLeft > 0,
      'days_left': daysLeft > 0 ? daysLeft : 0,
      'trial_ends_at': endsAt,
      'is_trial': true,
    };
  }

  /// Calcular preço via RPC
  Future<double> calculatePrice(String garageId, String tipo, DateTime inicio, DateTime fim) async {
    final result = await _supabase.rpc('garage_calculate_price', params: {
      'p_garage_id': garageId,
      'p_tipo': tipo,
      'p_inicio': inicio.toIso8601String(),
      'p_fim': fim.toIso8601String(),
    });
    return (result as num).toDouble();
  }
}
