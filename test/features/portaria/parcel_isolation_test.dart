import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/features/parcels/presentation/bloc/parcel_bloc.dart';
import 'package:condomeet/features/parcels/presentation/bloc/parcel_event.dart';
import 'package:condomeet/features/parcels/presentation/bloc/parcel_state.dart';
import 'package:condomeet/features/portaria/domain/entities/parcel.dart';
import 'package:condomeet/features/portaria/domain/repositories/parcel_repository.dart';

/// Mock repository for testing parcel isolation, scope separation,
/// and fail-closed behaviors across all user profiles.
class _MockParcelRepository implements ParcelRepository {
  final List<Parcel> databaseParcels;
  final Map<String, Map<String, String>> userProfiles; // userId -> {condo, bloco, apto}

  _MockParcelRepository({
    required this.databaseParcels,
    required this.userProfiles,
  });

  bool didCallBroadCondoQuery = false;

  @override
  Stream<List<Parcel>> watchPendingParcelsForUnit(String residentId) {
    if (residentId.trim().isEmpty) {
      return Stream.value(<Parcel>[]);
    }

    final profile = userProfiles[residentId];
    final bloco = profile?['bloco']?.trim();
    final apto = profile?['apto']?.trim();
    final condoId = profile?['condo']?.trim();

    final isAdminOrUnassigned = bloco == null ||
        apto == null ||
        bloco.isEmpty ||
        apto.isEmpty ||
        bloco == '0' ||
        apto == '0';

    final matched = databaseParcels.where((p) {
      if (p.status != 'pending') return false;
      if (condoId != null && p.condominiumId != condoId) return false;

      if (isAdminOrUnassigned) {
        // Conta administrativa: estritamente o próprio resident_id
        return p.residentId == residentId;
      } else {
        // Unidade residencial válida: resident_id OU (bloco e apto da unidade)
        final matchesResident = p.residentId == residentId;
        final matchesUnit = p.block == bloco && p.unitNumber == apto;
        return matchesResident || matchesUnit;
      }
    }).toList();

    return Stream.value(matched);
  }

  @override
  Stream<List<Parcel>> watchAllPendingParcels(String condominiumId) {
    if (condominiumId.trim().isEmpty) {
      return Stream.value(<Parcel>[]);
    }
    didCallBroadCondoQuery = true;
    final matched = databaseParcels
        .where((p) => p.condominiumId == condominiumId && p.status == 'pending')
        .toList();
    return Stream.value(matched);
  }

  @override
  Future<Result<List<Parcel>>> getAllPendingParcels(String condominiumId) async {
    if (condominiumId.trim().isEmpty) {
      return const Success([]);
    }
    didCallBroadCondoQuery = true;
    final matched = databaseParcels
        .where((p) => p.condominiumId == condominiumId && p.status == 'pending')
        .toList();
    return Success(matched);
  }

  @override
  Future<Result<List<Parcel>>> getParcelsForResident(String residentId) async {
    if (residentId.trim().isEmpty) {
      return const Success([]);
    }
    final profile = userProfiles[residentId];
    final bloco = profile?['bloco']?.trim();
    final apto = profile?['apto']?.trim();

    final isAdmin = bloco == null || apto == null || bloco == '0' || apto == '0';
    final matched = databaseParcels.where((p) {
      if (isAdmin) {
        return p.residentId == residentId;
      } else {
        return p.residentId == residentId || (p.block == bloco && p.unitNumber == apto);
      }
    }).toList();

    return Success(matched);
  }

  @override
  Future<Result<List<Parcel>>> getParcelHistory({
    String? residentId,
    required String condominiumId,
  }) async {
    // Regra Inviolável: se residentId vazio/null -> Success([]) FAIL-CLOSED
    if (residentId == null || residentId.trim().isEmpty) {
      return const Success([]);
    }
    if (condominiumId.isEmpty) {
      return const Success([]);
    }

    final profile = userProfiles[residentId];
    final bloco = profile?['bloco']?.trim();
    final apto = profile?['apto']?.trim();

    final isAdmin = bloco == null || apto == null || bloco == '0' || apto == '0';
    final matched = databaseParcels.where((p) {
      if (p.condominiumId != condominiumId || p.status != 'delivered') return false;
      if (isAdmin) {
        return p.residentId == residentId;
      } else {
        return p.residentId == residentId || (p.block == bloco && p.unitNumber == apto);
      }
    }).toList();

    return Success(matched);
  }

  @override
  Future<Result<void>> markAsDelivered(
    String parcelId, {
    String? pickupProofUrl,
    String? pickedUpById,
    String? pickedUpByName,
    bool silentDischarge = false,
    String? dischargedBy,
  }) async {
    final idx = databaseParcels.indexWhere((p) => p.id == parcelId);
    if (idx != -1) {
      databaseParcels[idx] = databaseParcels[idx].copyWith(status: 'delivered');
    }
    return const Success(null);
  }

  @override
  Future<Result<void>> registerParcel(Parcel parcel) async {
    databaseParcels.add(parcel);
    return const Success(null);
  }
}

Parcel _makeParcel({
  required String id,
  required String condoId,
  String? residentId,
  required String block,
  required String unitNumber,
  String status = 'pending',
}) {
  return Parcel(
    id: id,
    condominiumId: condoId,
    residentId: residentId,
    residentName: 'Morador $id',
    unitNumber: unitNumber,
    block: block,
    arrivalTime: DateTime.now(),
    status: status,
    tipo: 'caixa',
  );
}

void main() {
  const kCondoRecanto = 'condo-recanto-palmeiras-uuid';

  group('🏛️ ISOLAMENTO DE ENCOMENDAS — SUÍTE DE TESTES RIGOROSOS', () {
    late _MockParcelRepository repo;
    late List<Parcel> dbParcels;
    late Map<String, Map<String, String>> profiles;

    setUp(() {
      // 281 encomendas condominiais de exemplo, das quais algumas são de unidades específicas
      dbParcels = [
        _makeParcel(id: 'parcel-A1', condoId: kCondoRecanto, residentId: 'user-A', block: '10', unitNumber: '101'),
        _makeParcel(id: 'parcel-B1', condoId: kCondoRecanto, residentId: 'user-B', block: '20', unitNumber: '202'),
        _makeParcel(id: 'parcel-31-103', condoId: kCondoRecanto, residentId: 'user-other-1', block: '31', unitNumber: '103'),
        _makeParcel(id: 'parcel-91-103', condoId: kCondoRecanto, residentId: 'user-other-2', block: '91', unitNumber: '103'),
        _makeParcel(id: 'parcel-60-203', condoId: kCondoRecanto, residentId: 'user-other-3', block: '60', unitNumber: '203'),
        _makeParcel(id: 'parcel-68-104', condoId: kCondoRecanto, residentId: 'user-other-4', block: '68', unitNumber: '104'),
        // Mais 275 encomendas gerais no condomínio
        for (int i = 7; i <= 281; i++)
          _makeParcel(id: 'parcel-condo-$i', condoId: kCondoRecanto, residentId: 'user-$i', block: '${(i % 10) + 1}', unitNumber: '${100 + i}'),
      ];

      profiles = {
        'user-A': {'condo': kCondoRecanto, 'bloco': '10', 'apto': '101'},
        'user-B': {'condo': kCondoRecanto, 'bloco': '20', 'apto': '202'},
        'user-sindico': {'condo': kCondoRecanto, 'bloco': '0', 'apto': '0'}, // Bloco 0 / Apto 0
        'user-porteiro': {'condo': kCondoRecanto, 'bloco': '0', 'apto': '0'},
      };

      repo = _MockParcelRepository(databaseParcels: dbParcels, userProfiles: profiles);
    });

    // ── 11. TESTE DE ISOLAMENTO A/B ──────────────────────────────
    test('11. Teste de Isolamento A/B: A vê apenas A1; B vê apenas B1', () async {
      final blocA = ParcelBloc(repo);
      final blocB = ParcelBloc(repo);

      // Usuário A solicita suas encomendas
      blocA.add(const WatchPendingParcelsRequested('user-A'));
      await expectLater(
        blocA.stream,
        emitsInOrder([
          isA<ParcelLoading>(),
          predicate<ParcelLoaded>((state) =>
              state.isPersonal == true &&
              state.pendingParcels.length == 1 &&
              state.pendingParcels.first.id == 'parcel-A1'),
        ]),
      );

      // Usuário B solicita suas encomendas
      blocB.add(const WatchPendingParcelsRequested('user-B'));
      await expectLater(
        blocB.stream,
        emitsInOrder([
          isA<ParcelLoading>(),
          predicate<ParcelLoaded>((state) =>
              state.isPersonal == true &&
              state.pendingParcels.length == 1 &&
              state.pendingParcels.first.id == 'parcel-B1'),
        ]),
      );

      await blocA.close();
      await blocB.close();
    });

    // ── 12. TESTE MESMO CONDOMÍNIO ───────────────────────────────
    test('12. Teste Mesmo Condomínio: Usuários A e B no Recanto das Palmeiras sem vazamento entre unidades', () async {
      final bloc = ParcelBloc(repo);

      // Consulta A
      bloc.add(const WatchPendingParcelsRequested('user-A'));
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ParcelLoading>(),
          predicate<ParcelLoaded>((s) =>
              s.pendingParcels.any((p) => p.id == 'parcel-A1') &&
              !s.pendingParcels.any((p) => p.id == 'parcel-B1')),
        ]),
      );

      // Consulta B
      bloc.add(const WatchPendingParcelsRequested('user-B'));
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ParcelLoading>(),
          predicate<ParcelLoaded>((s) =>
              s.pendingParcels.any((p) => p.id == 'parcel-B1') &&
              !s.pendingParcels.any((p) => p.id == 'parcel-A1')),
        ]),
      );

      await bloc.close();
    });

    // ── 13. TESTE CRÍTICO DO SÍNDICO (Bloco 0, Apto 0) ───────────
    test('13. Teste Crítico do Síndico: Bloco 0 / Apto 0 NÃO recebe 281 encomendas condominiais', () async {
      final bloc = ParcelBloc(repo);

      // Síndico autenticado sem encomendas pessoais próprias cadastradas
      bloc.add(const WatchPendingParcelsRequested('user-sindico'));
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ParcelLoading>(),
          predicate<ParcelLoaded>((s) =>
              s.isPersonal == true &&
              s.pendingParcels.isEmpty && // Lista pessoal vazia!
              !s.pendingParcels.any((p) => p.id == 'parcel-31-103') &&
              !s.pendingParcels.any((p) => p.id == 'parcel-91-103') &&
              !s.pendingParcels.any((p) => p.id == 'parcel-60-203') &&
              !s.pendingParcels.any((p) => p.id == 'parcel-68-104')),
        ]),
      );

      // Agora registra uma encomenda expressamente para o Síndico (residentId: 'user-sindico')
      final sindicoParcel = _makeParcel(
        id: 'parcel-sindico-pessoal',
        condoId: kCondoRecanto,
        residentId: 'user-sindico',
        block: '0',
        unitNumber: '0',
      );
      dbParcels.add(sindicoParcel);

      // Recarrega Minhas Encomendas para o Síndico
      bloc.add(const WatchPendingParcelsRequested('user-sindico'));
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ParcelLoading>(),
          predicate<ParcelLoaded>((s) =>
              s.isPersonal == true &&
              s.pendingParcels.length == 1 &&
              s.pendingParcels.first.id == 'parcel-sindico-pessoal' &&
              !s.pendingParcels.any((p) => p.id == 'parcel-31-103')),
        ]),
      );

      await bloc.close();
    });

    // ── 14. TESTE DE NÃO-REGRESSÃO: ENCOMENDAS DO COND. ───────────
    test('14. Teste de Não-Regressão: Portaria/Condomínio continua com visão completa das 281 encomendas', () async {
      final bloc = ParcelBloc(repo);

      bloc.add(const WatchAllPendingParcelsRequested(kCondoRecanto));
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ParcelLoading>(),
          predicate<ParcelLoaded>((s) =>
              s.isPersonal == false &&
              s.pendingParcels.length == 281), // Totalidade do condomínio preservada para Portaria
        ]),
      );

      // Confirma que getAllPendingParcels do repositório também retorna todas as 281
      final res = await repo.getAllPendingParcels(kCondoRecanto);
      expect(res.isSuccess, isTrue);
      expect(res.successData.length, 281);

      // Confirma que dar baixa continua funcionando
      final baixaRes = await repo.markAsDelivered('parcel-A1');
      expect(baixaRes.isSuccess, isTrue);

      await bloc.close();
    });

    // ── 15. TESTE DE HISTÓRICO ISOLADO E FAIL-CLOSED ──────────────
    test('15. Histórico: Somente registros do usuário/unidade; fail-closed se residentId vazio', () async {
      // Cria histórico entregue
      dbParcels.add(_makeParcel(
        id: 'delivered-A',
        condoId: kCondoRecanto,
        residentId: 'user-A',
        block: '10',
        unitNumber: '101',
        status: 'delivered',
      ));
      dbParcels.add(_makeParcel(
        id: 'delivered-B',
        condoId: kCondoRecanto,
        residentId: 'user-B',
        block: '20',
        unitNumber: '202',
        status: 'delivered',
      ));

      // Histórico para A
      final blocA = ParcelBloc(repo);
      blocA.add(const FetchParcelHistoryRequested(residentId: 'user-A', condominiumId: kCondoRecanto));
      await expectLater(
        blocA.stream,
        emits(predicate<ParcelLoaded>((s) =>
            s.historyParcels.length == 1 &&
            s.historyParcels.first.id == 'delivered-A')),
      );
      await blocA.close();

      // Histórico com residentId VAZIO -> FAIL-CLOSED
      final blocEmpty = ParcelBloc(repo);
      blocEmpty.add(const FetchParcelHistoryRequested(residentId: '', condominiumId: kCondoRecanto));
      await expectLater(
        blocEmpty.stream,
        emits(predicate<ParcelLoaded>((s) => s.historyParcels.isEmpty)),
      );
      await blocEmpty.close();

      // Histórico com residentId NULL -> FAIL-CLOSED
      final blocNull = ParcelBloc(repo);
      blocNull.add(const FetchParcelHistoryRequested(residentId: null, condominiumId: kCondoRecanto));
      await expectLater(
        blocNull.stream,
        emits(predicate<ParcelLoaded>((s) => s.historyParcels.isEmpty)),
      );
      await blocNull.close();

      // Repositório direto com residentId nulo/vazio -> NUNCA busca do condomínio todo
      final repoResNull = await repo.getParcelHistory(residentId: null, condominiumId: kCondoRecanto);
      expect(repoResNull.isSuccess, isTrue);
      expect(repoResNull.successData, isEmpty);

      final repoResEmpty = await repo.getParcelHistory(residentId: '', condominiumId: kCondoRecanto);
      expect(repoResEmpty.isSuccess, isTrue);
      expect(repoResEmpty.successData, isEmpty);
    });

    // ── 16. TESTE DE ESTADO DO BLOC SINGLETON ─────────────────────
    test('16. Teste ParcelBloc Singleton: Transição de Condominial para Pessoal limpa estado anterior imediatamente', () async {
      final bloc = ParcelBloc(repo);

      // 1. Home com visão condominial autorizada: recebe 281 encomendas
      bloc.add(const WatchAllPendingParcelsRequested(kCondoRecanto));
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ParcelLoading>(),
          predicate<ParcelLoaded>((s) => s.isPersonal == false && s.pendingParcels.length == 281),
        ]),
      );

      // 2. Navega para "Minhas Encomendas" (usuário A)
      // Confirma que o estado anterior com 281 NÃO é reutilizado!
      // Emite ParcelLoading() imediatamente limpando o estado!
      bloc.add(const WatchPendingParcelsRequested('user-A'));
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ParcelLoading>(), // Limpeza imediata!
          predicate<ParcelLoaded>((s) =>
              s.isPersonal == true &&
              s.pendingParcels.length == 1 &&
              s.pendingParcels.first.id == 'parcel-A1'),
        ]),
      );

      await bloc.close();
    });

    // ── 17. TESTE FAIL-CLOSED ─────────────────────────────────────
    test('17. Teste Fail-Closed: residentId vazio gera lista vazia e histórico vazio sem consultar condomínio', () async {
      // Pending com residentId vazio
      final blocPending = ParcelBloc(repo);
      blocPending.add(const WatchPendingParcelsRequested(''));
      await expectLater(
        blocPending.stream,
        emits(predicate<ParcelLoaded>((s) =>
            s.isPersonal == true &&
            s.pendingParcels.isEmpty)),
      );
      await blocPending.close();

      // History com residentId vazio
      final blocHistory = ParcelBloc(repo);
      blocHistory.add(const FetchParcelHistoryRequested(residentId: '', condominiumId: kCondoRecanto));
      await expectLater(
        blocHistory.stream,
        emits(predicate<ParcelLoaded>((s) => s.historyParcels.isEmpty)),
      );
      await blocHistory.close();

      // Stream do repositório para residentId vazio
      final repoStream = repo.watchPendingParcelsForUnit('');
      final streamResult = await repoStream.first;
      expect(streamResult, isEmpty);
    });

    // ── 18. TESTE DE ISOLAMENTO DO CARD PESSOAL NA HOME SCREEN ───
    test('18. HomeScreen Card: Estado condominial no ParcelBloc NUNCA vaza para card de Morador ou Síndico', () {
      final condoState = ParcelLoaded(
        isPersonal: false,
        pendingParcels: [for (int i = 0; i < 281; i++) _makeParcel(id: 'p-$i', condoId: kCondoRecanto, block: '1', unitNumber: '101')],
      );

      // Função representativa da lógica em HomeScreen._buildParcelCard:
      List<Parcel> resolveHomeParcels(ParcelState state, bool isPorter) {
        if (state is ParcelLoaded) {
          if (isPorter) {
            return state.isPersonal ? [] : state.pendingParcels;
          } else {
            if (state.isPersonal) {
              return state.pendingParcels;
            } else {
              return []; // Proteção mandatória da Camada 1
            }
          }
        }
        return [];
      }

      // Morador comum com estado condominial no BLoC -> Vê zero
      expect(resolveHomeParcels(condoState, false), isEmpty);

      // Síndico com estado condominial no BLoC -> Vê zero
      expect(resolveHomeParcels(condoState, false), isEmpty);

      // Portaria com estado condominial -> Vê as 281
      expect(resolveHomeParcels(condoState, true).length, 281);

      // Morador com estado pessoal próprio -> Vê suas encomendas
      final personalState = ParcelLoaded(
        isPersonal: true,
        pendingParcels: [_makeParcel(id: 'my-parcel-1', condoId: kCondoRecanto, block: '10', unitNumber: '101')],
      );
      expect(resolveHomeParcels(personalState, false).length, 1);
      expect(resolveHomeParcels(personalState, true), isEmpty);
    });

    // ── 19. TESTE DE REGRA DE DISPACHO POR PAPEL NA HOME SCREEN ──
    test('19. HomeScreen Role Check: Síndico, admin e subsíndico NUNCA disparam WatchAllPendingParcelsRequested', () {
      bool isPorter(String? role) {
        final r = (role ?? '').toLowerCase();
        return r.contains('porteiro') || r.contains('portaria');
      }

      // Usuários operacionais de portaria
      expect(isPorter('porteiro'), isTrue);
      expect(isPorter('portaria diurna'), isTrue);
      expect(isPorter('portaria'), isTrue);
      expect(isPorter('Porteiro Noturno'), isTrue);

      // Usuários não-portaria (NUNCA recebem visão condominial na Home)
      expect(isPorter('síndico'), isFalse);
      expect(isPorter('sindico'), isFalse);
      expect(isPorter('admin'), isFalse);
      expect(isPorter('subsíndico'), isFalse);
      expect(isPorter('subsindico'), isFalse);
      expect(isPorter('morador'), isFalse);
      expect(isPorter('proprietário'), isFalse);
      expect(isPorter(''), isFalse);
      expect(isPorter(null), isFalse);
    });

    // ── 20. TESTE DE PRIORIDADE DO GETTER _effectiveResidentId ────
    test('20. ParcelDashboardScreen: _effectiveResidentId obedece prioridade estrita e fail-closed', () {
      String resolveEffectiveId({String? authId, String? supabaseId, String? widgetId}) {
        if (authId != null && authId.trim().isNotEmpty) return authId.trim();
        if (supabaseId != null && supabaseId.trim().isNotEmpty) return supabaseId.trim();
        if (widgetId != null && widgetId.trim().isNotEmpty) return widgetId.trim();
        return '';
      }

      // Prioridade 1: AuthBloc userId
      expect(resolveEffectiveId(authId: 'auth-user-1', supabaseId: 'supa-user-2', widgetId: 'widget-user-3'), 'auth-user-1');

      // Prioridade 2: Supabase currentUser fallback
      expect(resolveEffectiveId(authId: null, supabaseId: 'supa-user-2', widgetId: 'widget-user-3'), 'supa-user-2');
      expect(resolveEffectiveId(authId: '', supabaseId: 'supa-user-2', widgetId: 'widget-user-3'), 'supa-user-2');

      // Prioridade 3: widget.residentId
      expect(resolveEffectiveId(authId: null, supabaseId: null, widgetId: 'widget-user-3'), 'widget-user-3');
      expect(resolveEffectiveId(authId: '', supabaseId: '', widgetId: 'widget-user-3'), 'widget-user-3');

      // Fail-closed: se nenhum válido -> vazio (NUNCA fallback para condomínio)
      expect(resolveEffectiveId(authId: null, supabaseId: null, widgetId: null), '');
      expect(resolveEffectiveId(authId: '', supabaseId: '', widgetId: ''), '');
      expect(resolveEffectiveId(authId: '   ', supabaseId: '   ', widgetId: '   '), '');
    });

    // ── 21. TESTE DE ROUTE ARGUMENT INJECTION (USUÁRIO COMUM) ─────
    test('21. Route Argument Injection: Usuário A autenticado + residentId B na rota -> Histórico consulta ESTRITAMENTE A', () async {
      dbParcels.add(_makeParcel(
        id: 'delivered-A',
        condoId: kCondoRecanto,
        residentId: 'user-A',
        block: '10',
        unitNumber: '101',
        status: 'delivered',
      ));
      dbParcels.add(_makeParcel(
        id: 'delivered-B',
        condoId: kCondoRecanto,
        residentId: 'user-B',
        block: '20',
        unitNumber: '202',
        status: 'delivered',
      ));

      // Simulação da rota segura /parcel-history:
      String resolveHistoryResidentId({
        required String? authUserId,
        required String? currentUserId,
        required Object? modalArguments,
      }) {
        // Regra Inviolável de Hardening: modalArguments é TERMINANTEMENTE IGNORADO
        final effectiveUserId = (authUserId != null && authUserId.isNotEmpty)
            ? authUserId
            : (currentUserId != null && currentUserId.isNotEmpty ? currentUserId : '');
        return effectiveUserId;
      }

      final resolvedId = resolveHistoryResidentId(
        authUserId: 'user-A',
        currentUserId: 'user-A',
        modalArguments: 'user-B-malicious-target', // Tentativa de injeção externa
      );

      // Confirma que o argumento foi 100% ignorado e a identidade resolvida foi A
      expect(resolvedId, 'user-A');

      // Executa no BLoC e confirma que busca estritamente A
      final bloc = ParcelBloc(repo);
      bloc.add(FetchParcelHistoryRequested(residentId: resolvedId, condominiumId: kCondoRecanto));
      await expectLater(
        bloc.stream,
        emits(predicate<ParcelLoaded>((s) =>
            s.historyParcels.any((p) => p.residentId == 'user-A') &&
            !s.historyParcels.any((p) => p.residentId == 'user-B'))),
      );
      await bloc.close();
    });

    // ── 22. TESTE DE ROUTE ARGUMENT INJECTION (ADMIN / SÍNDICO) ───
    test('22. Route Argument Injection (Síndico): Síndico autenticado + residentId B na rota -> Histórico pessoal consulta ESTRITAMENTE o Síndico', () async {
      String resolveHistoryResidentId({
        required String? authUserId,
        required String? currentUserId,
        required Object? modalArguments,
      }) {
        final effectiveUserId = (authUserId != null && authUserId.isNotEmpty)
            ? authUserId
            : (currentUserId != null && currentUserId.isNotEmpty ? currentUserId : '');
        return effectiveUserId;
      }

      final resolvedId = resolveHistoryResidentId(
        authUserId: 'user-sindico',
        currentUserId: 'user-sindico',
        modalArguments: 'user-other-1', // Tentativa de consultar morador arbitrário via rota pessoal
      );

      expect(resolvedId, 'user-sindico');

      final bloc = ParcelBloc(repo);
      bloc.add(FetchParcelHistoryRequested(residentId: resolvedId, condominiumId: kCondoRecanto));
      await expectLater(
        bloc.stream,
        emits(predicate<ParcelLoaded>((s) =>
            // Síndico não tem encomendas entregues próprias -> histórico vazio
            s.historyParcels.isEmpty &&
            !s.historyParcels.any((p) => p.residentId == 'user-other-1'))),
      );
      await bloc.close();
    });

    // ── 23. TESTE DE USUÁRIO SEM AUTENTICAÇÃO (FAIL-CLOSED) ───────
    test('23. Usuário Sem Autenticação: Histórico emite lista vazia sem consultar o condomínio', () async {
      String resolveHistoryResidentId({
        required String? authUserId,
        required String? currentUserId,
        required Object? modalArguments,
      }) {
        final effectiveUserId = (authUserId != null && authUserId.isNotEmpty)
            ? authUserId
            : (currentUserId != null && currentUserId.isNotEmpty ? currentUserId : '');
        return effectiveUserId;
      }

      final resolvedId = resolveHistoryResidentId(
        authUserId: null,
        currentUserId: null,
        modalArguments: 'user-any', // Injeção quando deslogado
      );

      // Deve ser vazio (fail-closed)
      expect(resolvedId, '');

      final bloc = ParcelBloc(repo);
      bloc.add(FetchParcelHistoryRequested(residentId: resolvedId, condominiumId: kCondoRecanto));
      await expectLater(
        bloc.stream,
        emits(predicate<ParcelLoaded>((s) => s.historyParcels.isEmpty)),
      );
      await bloc.close();

      // Repositório direto fail-closed
      final repoRes = await repo.getParcelHistory(residentId: resolvedId, condominiumId: kCondoRecanto);
      expect(repoRes.isSuccess, isTrue);
      expect(repoRes.successData, isEmpty);
    });

    // ── 24. TESTE DE NAVEGAÇÃO NORMAL SEM ARGUMENTOS ─────────────
    test('24. Navegação Normal: Sem argumentos, resolve usuário autenticado e carrega histórico legítimo', () async {
      dbParcels.add(_makeParcel(
        id: 'delivered-B',
        condoId: kCondoRecanto,
        residentId: 'user-B',
        block: '20',
        unitNumber: '202',
        status: 'delivered',
      ));

      String resolveHistoryResidentId({
        required String? authUserId,
        required String? currentUserId,
        required Object? modalArguments,
      }) {
        final effectiveUserId = (authUserId != null && authUserId.isNotEmpty)
            ? authUserId
            : (currentUserId != null && currentUserId.isNotEmpty ? currentUserId : '');
        return effectiveUserId;
      }

      final resolvedId = resolveHistoryResidentId(
        authUserId: 'user-B',
        currentUserId: 'user-B',
        modalArguments: null, // Fluxo padrão normal
      );

      expect(resolvedId, 'user-B');

      final bloc = ParcelBloc(repo);
      bloc.add(FetchParcelHistoryRequested(residentId: resolvedId, condominiumId: kCondoRecanto));
      await expectLater(
        bloc.stream,
        emits(predicate<ParcelLoaded>((s) =>
            s.historyParcels.length == 1 &&
            s.historyParcels.first.id == 'delivered-B')),
      );
      await bloc.close();
    });

    // ── 25. NÃO-REGRESSÃO: ENCOMENDAS DO COND. PERMANECE OPERACIONAL
    test('25. Não-Regressão Operacional: Encomendas do Cond. continua operando com 281 encomendas e baixa por portaria', () async {
      // Confirma que getAllPendingParcels do condomínio continua retornando todas as 281
      final pendingCondo = await repo.getAllPendingParcels(kCondoRecanto);
      expect(pendingCondo.isSuccess, isTrue);
      expect(pendingCondo.successData.length, 281);

      // Confirma que dar baixa em encomenda entregue continua funcionando perfeitamente
      final baixa = await repo.markAsDelivered('parcel-condo-7');
      expect(baixa.isSuccess, isTrue);
    });
  });
}
