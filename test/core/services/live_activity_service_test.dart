import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:condomeet/core/services/live_activity_service.dart';
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/features/access/domain/models/invitation.dart';
import 'package:condomeet/features/access/domain/repositories/invitation_repository.dart';
import 'package:condomeet/features/access/presentation/bloc/invitation_bloc.dart';
import 'package:condomeet/features/access/presentation/bloc/invitation_event.dart';
import 'package:intl/intl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('br.app.condomeet/live_activity');
  final List<MethodCall> log = <MethodCall>[];

  setUp(() {
    log.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      log.add(methodCall);
      switch (methodCall.method) {
        case 'isLiveActivitySupported':
          return true;
        case 'startLiveActivity':
          return {
            'success': true,
            'activityId': 'act-test-123',
            'invitationId': methodCall.arguments['invitationId'],
          };
        case 'syncLiveActivityState':
          return {
            'success': true,
            'action': (methodCall.arguments['countAbertas'] ?? 0) > 0 ? 'updated' : 'ended',
            'countAbertas': methodCall.arguments['countAbertas'],
          };
        case 'endLiveActivity':
          return {
            'success': true,
            'endedCount': 1,
          };
        default:
          return null;
      }
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('LiveActivityService', () {
    test('isLiveActivitySupported calls platform channel when on iOS', () async {
      final supported = await LiveActivityService.isLiveActivitySupported();
      expect(supported, isTrue);
      expect(log, hasLength(1));
      expect(log.first.method, 'isLiveActivitySupported');
    });

    test('isLiveActivitySupported returns false immediately on non-iOS', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final supported = await LiveActivityService.isLiveActivitySupported();
      expect(supported, isFalse);
      expect(log, isEmpty);
    });

    test('startCredencialActivity sends exact qr_data and formatted validity for night window', () async {
      final nightTime = DateTime(2026, 9, 23, 23, 55);
      final validity = DateTime(2026, 9, 23, 23, 59);
      final success = await LiveActivityService.startCredencialActivity(
        invitationId: 'inv-456',
        codigoAcesso: '883921', // Exatamente o qr_data do convite
        moradorNome: 'Carlos Silva',
        condominioNome: 'Montserrat',
        validityDate: validity,
        status: 'active',
        createdAt: nightTime,
      );

      expect(success, isTrue);
      expect(log, hasLength(1));
      final call = log.first;
      expect(call.method, 'syncLiveActivityState');
      expect(call.arguments['invitationId'], 'inv-456');
      expect(call.arguments['codigoAcesso'], '883921');
      expect(call.arguments['moradorNome'], 'Carlos Silva');
      expect(call.arguments['condominioNome'], 'Montserrat');
      expect(call.arguments['status'], 'active');
      expect(call.arguments['validadeHora'], '05:55');
      expect(call.arguments['validityDateIso'], DateTime(2026, 9, 24, 5, 55).toUtc().toIso8601String());
    });

    test('startCredencialActivity for day time (created before 22:00) sets display to 23:59 and staleDate to end of day', () async {
      final created = DateTime(2026, 9, 23, 14, 0);
      final expectedEndOfDay = DateTime(2026, 9, 23, 23, 59, 59);

      final success = await LiveActivityService.startCredencialActivity(
        invitationId: 'inv-fullday',
        codigoAcesso: '741258',
        moradorNome: 'Juliana Costa',
        condominioNome: 'Montserrat',
        validityDate: created,
        status: 'active',
        createdAt: created,
      );

      expect(success, isTrue);
      expect(log, hasLength(1));
      final call = log.first;
      expect(call.method, 'syncLiveActivityState');
      expect(call.arguments['countAbertas'], 1);
      expect(call.arguments['codigoAcesso'], '741258');
      expect(call.arguments['validadeHora'], '23:59');
      expect(call.arguments['validityDateIso'], expectedEndOfDay.toUtc().toIso8601String());
    });

    test('startCredencialActivity for DateTime daytime (created today before 22:00) sets validity to 23:59 and staleDate to end of day', () async {
      final daytime = DateTime(2026, 9, 23, 14, 0);
      final expectedEndOfDay = DateTime(daytime.year, daytime.month, daytime.day, 23, 59, 59);

      final success = await LiveActivityService.startCredencialActivity(
        invitationId: 'inv-today-now',
        codigoAcesso: '998877',
        moradorNome: 'Morador Teste',
        condominioNome: 'Montserrat',
        validityDate: daytime,
        createdAt: daytime,
        status: 'active',
      );

      expect(success, isTrue);
      expect(log, hasLength(1));
      final call = log.first;
      expect(call.method, 'syncLiveActivityState');
      expect(call.arguments['countAbertas'], 1);
      expect(call.arguments['codigoAcesso'], '998877');
      expect(call.arguments['validadeHora'], '23:59');
      expect(call.arguments['validityDateIso'], expectedEndOfDay.toUtc().toIso8601String());
    });

    test('startCredencialActivity for past date daytime heals to 23:59 of that day and avoids staleDate in past', () async {
      final pastDate = DateTime(2026, 9, 23, 15, 0);
      final expectedEndOfDay = DateTime(pastDate.year, pastDate.month, pastDate.day, 23, 59, 59);

      final success = await LiveActivityService.startCredencialActivity(
        invitationId: 'inv-past',
        codigoAcesso: '554433',
        moradorNome: 'Morador Passado',
        condominioNome: 'Montserrat',
        validityDate: pastDate,
        createdAt: pastDate,
        status: 'active',
      );

      expect(success, isTrue);
      expect(log, hasLength(1));
      final call = log.first;
      expect(call.arguments['validadeHora'], '23:59');
      expect(call.arguments['validityDateIso'], expectedEndOfDay.toUtc().toIso8601String());
    });

    test('startCredencialActivity prevents concurrent in-flight starts for same invitationId', () async {
      // Simula uma resposta assíncrona com atraso
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        log.add(methodCall);
        await Future.delayed(const Duration(milliseconds: 50));
        return {
          'success': true,
          'activityId': 'act-slow',
          'action': 'created',
          'countAbertas': 1,
        };
      });

      final future1 = LiveActivityService.startCredencialActivity(
        invitationId: 'inv-concurrent',
        codigoAcesso: '111222',
        moradorNome: 'Morador 1',
        condominioNome: 'Condomínio',
        validityDate: DateTime.now(),
      );

      // Segunda chamada imediata enquanto a primeira está em andamento
      final future2 = LiveActivityService.startCredencialActivity(
        invitationId: 'inv-concurrent',
        codigoAcesso: '111222',
        moradorNome: 'Morador 1',
        condominioNome: 'Condomínio',
        validityDate: DateTime.now(),
      );

      final results = await Future.wait([future1, future2]);
      expect(results[0], isTrue);
      expect(results[1], isFalse); // Chamada concorrente duplicada foi descartada
      // Apenas 1 chamada de canal foi disparada
      expect(log.where((c) => c.method == 'syncLiveActivityState' && c.arguments['invitationId'] == 'inv-concurrent'), hasLength(1));
    });

    test('endCredencialActivity sends invitationId to platform channel', () async {
      final success = await LiveActivityService.endCredencialActivity(
        invitationId: 'inv-456',
      );

      expect(success, isTrue);
      expect(log, hasLength(1));
      final call = log.first;
      expect(call.method, 'endLiveActivity');
      expect(call.arguments['invitationId'], 'inv-456');
    });

    test('Cenário A: startCredencialActivity passes visitanteNome when present', () async {
      final success = await LiveActivityService.startCredencialActivity(
        invitationId: 'inv-visitor-named',
        codigoAcesso: '7AV8',
        moradorNome: 'Cristiano Santos',
        condominioNome: 'Montserrat',
        validityDate: DateTime.now(),
        visitanteNome: 'João da Silva',
      );

      expect(success, isTrue);
      expect(log, hasLength(1));
      final call = log.first;
      expect(call.arguments['visitanteNome'], 'João da Silva');
      expect(call.arguments['guestName'], 'João da Silva');
    });

    test('Cenário B: startCredencialActivity omits visitanteNome when empty or null', () async {
      final success = await LiveActivityService.startCredencialActivity(
        invitationId: 'inv-visitor-empty',
        codigoAcesso: '9B2C',
        moradorNome: 'Cristiano Santos',
        condominioNome: 'Montserrat',
        validityDate: DateTime.now(),
        visitanteNome: '',
      );

      expect(success, isTrue);
      expect(log, hasLength(1));
      final call = log.first;
      expect(call.arguments.containsKey('visitanteNome'), isFalse);
      expect(call.arguments.containsKey('guestName'), isFalse);
    });

    test('startCredencialActivity degrades gracefully on PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw PlatformException(
          code: 'UNAVAILABLE',
          message: 'Live Activities disabled',
        );
      });

      // Não deve lançar exceção e não deve interromper fluxo
      final success = await LiveActivityService.startCredencialActivity(
        invitationId: 'inv-fail',
        codigoAcesso: '123456',
        moradorNome: 'Ana',
        condominioNome: 'Montserrat',
        validityDate: DateTime.now(),
      );

      expect(success, isFalse);
    });

    test('startCredencialActivity does nothing on Android (zero Android impact)', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      final success = await LiveActivityService.startCredencialActivity(
        invitationId: 'inv-android',
        codigoAcesso: '999999',
        moradorNome: 'Android User',
        condominioNome: 'Montserrat',
        validityDate: DateTime.now(),
      );

      expect(success, isFalse);
      expect(log, isEmpty); // Zero channel invocations on Android
    });

    test('deepLinkStream and pendingInvitationId buffer and emit deep links', () async {
      await LiveActivityService.initializeDeepLinking();
      LiveActivityService.clearPendingInvitationId();
      expect(LiveActivityService.pendingInvitationId, isNull);

      final emissions = <String>[];
      final subscription = LiveActivityService.deepLinkStream.listen(emissions.add);

      // Simular onDeepLink vindo do MethodChannel nativo
      final binaryMessenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const codec = StandardMethodCodec();
      final byteData = codec.encodeMethodCall(const MethodCall('onDeepLink', {'invitationId': 'inv-deep-link-123'}));
      
      await binaryMessenger.handlePlatformMessage(
        channel.name,
        byteData,
        (ByteData? reply) {},
      );

      expect(emissions, contains('inv-deep-link-123'));
      expect(LiveActivityService.pendingInvitationId, 'inv-deep-link-123');

      LiveActivityService.clearPendingInvitationId();
      expect(LiveActivityService.pendingInvitationId, isNull);

      await subscription.cancel();
    });

    test('deepLinkStream handles aggregated list deep link', () async {
      await LiveActivityService.initializeDeepLinking();
      LiveActivityService.clearPendingInvitationId();

      final emissions = <String>[];
      final subscription = LiveActivityService.deepLinkStream.listen(emissions.add);

      final binaryMessenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const codec = StandardMethodCodec();
      final byteData = codec.encodeMethodCall(const MethodCall('onDeepLink', {'isList': true, 'invitationId': null}));

      await binaryMessenger.handlePlatformMessage(
        channel.name,
        byteData,
        (ByteData? reply) {},
      );

      expect(emissions, contains('list'));
      expect(LiveActivityService.pendingInvitationId, 'list');

      LiveActivityService.clearPendingInvitationId();
      await subscription.cancel();
    });

    test('isInvitationOpen accurately evaluates status, visit and expiration', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 14, 0);

      // 1. Aberto normal
      final openInv = Invitation(
        id: '1', residentId: 'r', condominiumId: 'c', guestName: 'G',
        validityDate: today, qrData: 'AAA', status: 'active',
        visitanteCompareceu: false, createdAt: now, updatedAt: now,
      );
      expect(LiveActivityService.isInvitationOpen(openInv), isTrue);

      // 2. Cancelado / Expirado no status
      expect(LiveActivityService.isInvitationOpen(openInv.copyWith(validUntil: null)), isTrue);
      final expiredStatus = Invitation(
        id: '2', residentId: 'r', condominiumId: 'c', guestName: 'G',
        validityDate: today, qrData: 'AAA', status: 'expired',
        visitanteCompareceu: false, createdAt: now, updatedAt: now,
      );
      expect(LiveActivityService.isInvitationOpen(expiredStatus), isFalse);

      // 3. Visitante compareceu (liberado na portaria)
      final visited = openInv.copyWith(visitanteCompareceu: true);
      expect(LiveActivityService.isInvitationOpen(visited), isFalse);

      // 4. Data no passado (ontem)
      final yesterday = now.subtract(const Duration(days: 2));
      final pastInv = Invitation(
        id: '4', residentId: 'r', condominiumId: 'c', guestName: 'G',
        validityDate: yesterday, qrData: 'AAA', status: 'active',
        visitanteCompareceu: false, createdAt: yesterday, updatedAt: yesterday,
      );
      expect(LiveActivityService.isInvitationOpen(pastInv), isFalse);
    });

    test('syncActiveInvitationsState with 0 invitations ends Live Activity', () async {
      final success = await LiveActivityService.syncActiveInvitationsState(
        openInvitations: [],
        moradorNome: 'Cristiano',
        condominioNome: 'Montserrat',
      );

      expect(success, isTrue);
      expect(log, hasLength(1));
      final call = log.first;
      expect(call.method, 'syncLiveActivityState');
      expect(call.arguments['countAbertas'], 0);
    });

    test('syncActiveInvitationsState with 1 invitation renders detailed credential', () async {
      final now = DateTime.now();
      final inv = Invitation(
        id: 'inv-single-1', residentId: 'r', condominiumId: 'c', guestName: 'Érika',
        validityDate: now, qrData: 'KJ9', status: 'active',
        visitanteCompareceu: false, createdAt: now, updatedAt: now,
      );

      final success = await LiveActivityService.syncActiveInvitationsState(
        openInvitations: [inv],
        moradorNome: 'Cristiano',
        condominioNome: 'Montserrat',
      );

      expect(success, isTrue);
      expect(log, hasLength(1));
      final call = log.first;
      expect(call.method, 'syncLiveActivityState');
      expect(call.arguments['countAbertas'], 1);
      expect(call.arguments['invitationId'], 'inv-single-1');
      expect(call.arguments['codigoAcesso'], 'KJ9');
      expect(call.arguments['visitanteNome'], 'Érika');
      expect(call.arguments['statusText'], '🟢 Autorização ativa');
    });

    test('syncActiveInvitationsState with 2 invitations renders aggregated credential', () async {
      final now = DateTime.now();
      final inv1 = Invitation(
        id: 'inv-1', residentId: 'r', condominiumId: 'c', guestName: 'Érika',
        validityDate: now, qrData: 'KJ9', status: 'active',
        visitanteCompareceu: false, createdAt: now, updatedAt: now,
      );
      final inv2 = Invitation(
        id: 'inv-2', residentId: 'r', condominiumId: 'c', guestName: 'Roberto',
        validityDate: now, qrData: 'XYZ', status: 'active',
        visitanteCompareceu: false, createdAt: now.add(const Duration(minutes: 5)), updatedAt: now,
      );

      final success = await LiveActivityService.syncActiveInvitationsState(
        openInvitations: [inv1, inv2],
        moradorNome: 'Cristiano',
        condominioNome: 'Montserrat',
      );

      expect(success, isTrue);
      expect(log, hasLength(1));
      final call = log.first;
      expect(call.method, 'syncLiveActivityState');
      expect(call.arguments['countAbertas'], 2);
      expect(call.arguments.containsKey('codigoAcesso'), isFalse);
      expect(call.arguments['statusText'], '🟢 2 autorizações abertas');
    });

    test('syncActiveInvitationsState executes full state transition flow: 1 -> 2 -> 3 -> 2 -> 1 -> 0', () async {
      final now = DateTime.now();
      final inv1 = Invitation(
        id: 'inv-1', residentId: 'r', condominiumId: 'c', guestName: 'Visitante 1',
        validityDate: now, qrData: 'COD1', status: 'active',
        visitanteCompareceu: false, createdAt: now, updatedAt: now,
      );
      final inv2 = Invitation(
        id: 'inv-2', residentId: 'r', condominiumId: 'c', guestName: 'Visitante 2',
        validityDate: now, qrData: 'COD2', status: 'active',
        visitanteCompareceu: false, createdAt: now.add(const Duration(minutes: 1)), updatedAt: now,
      );
      final inv3 = Invitation(
        id: 'inv-3', residentId: 'r', condominiumId: 'c', guestName: 'Visitante 3',
        validityDate: now, qrData: 'COD3', status: 'active',
        visitanteCompareceu: false, createdAt: now.add(const Duration(minutes: 2)), updatedAt: now,
      );

      // Estado 1: 1 autorização
      await LiveActivityService.syncActiveInvitationsState(
        openInvitations: [inv1],
        moradorNome: 'Cristiano',
        condominioNome: 'Montserrat',
      );
      expect(log.last.arguments['countAbertas'], 1);
      expect(log.last.arguments['codigoAcesso'], 'COD1');

      // Estado 2: Transição 1 -> 2
      await LiveActivityService.syncActiveInvitationsState(
        openInvitations: [inv1, inv2],
        moradorNome: 'Cristiano',
        condominioNome: 'Montserrat',
      );
      expect(log.last.arguments['countAbertas'], 2);
      expect(log.last.arguments['statusText'], '🟢 2 autorizações abertas');

      // Estado 3: Transição 2 -> 3
      await LiveActivityService.syncActiveInvitationsState(
        openInvitations: [inv1, inv2, inv3],
        moradorNome: 'Cristiano',
        condominioNome: 'Montserrat',
      );
      expect(log.last.arguments['countAbertas'], 3);
      expect(log.last.arguments['statusText'], '🟢 3 autorizações abertas');

      // Estado 4: Transição 3 -> 2 (uma liberada na portaria)
      await LiveActivityService.syncActiveInvitationsState(
        openInvitations: [inv1, inv2],
        moradorNome: 'Cristiano',
        condominioNome: 'Montserrat',
      );
      expect(log.last.arguments['countAbertas'], 2);
      expect(log.last.arguments['statusText'], '🟢 2 autorizações abertas');

      // Estado 5: Transição 2 -> 1 (outra liberada, volta ao modo completo com código da restante)
      await LiveActivityService.syncActiveInvitationsState(
        openInvitations: [inv1],
        moradorNome: 'Cristiano',
        condominioNome: 'Montserrat',
      );
      expect(log.last.arguments['countAbertas'], 1);
      expect(log.last.arguments['codigoAcesso'], 'COD1');
      expect(log.last.arguments['statusText'], '🟢 Autorização ativa');

      // Estado 6: Transição 1 -> 0 (todas liberadas/usadas, encerra)
      await LiveActivityService.syncActiveInvitationsState(
        openInvitations: [],
        moradorNome: 'Cristiano',
        condominioNome: 'Montserrat',
      );
      expect(log.last.arguments['countAbertas'], 0);
    });

    test('cacheNames updates in-memory cached names for subsequent sync calls', () {
      LiveActivityService.cacheNames(
        moradorNome: 'Cristiano Santos',
        condominioNome: 'Residencial Real Park',
      );
      expect(LiveActivityService.cachedMoradorNome, 'Cristiano Santos');
      expect(LiveActivityService.cachedCondominioNome, 'Residencial Real Park');
    });

    group('Phase 2.1 — Visible Open Codes in Aggregated State', () {
      final now = DateTime.now();
      final validFuture = DateTime(now.year, now.month, now.day + 1, 22, 0);

      Invitation makeInv(String id, String code, Duration age, {String status = 'active', bool compareceu = false, DateTime? validity}) {
        final created = now.subtract(age);
        return Invitation(
          id: id,
          residentId: 'res-cris',
          condominiumId: 'condo-realpark',
          guestName: 'Visitante $id',
          validityDate: validity ?? validFuture,
          qrData: code,
          status: status,
          visitanteCompareceu: compareceu,
          createdAt: created,
          updatedAt: created,
        );
      }

      test('0 autorizações: count 0, codigosAbertos vazio, outras 0', () async {
        await LiveActivityService.syncActiveInvitationsState(
          openInvitations: [],
          moradorNome: 'Cristiano Santos',
          condominioNome: 'Real Park',
        );
        expect(log.last.arguments['countAbertas'], 0);
        expect(log.last.arguments['codigosAbertos'], isEmpty);
        expect(log.last.arguments['outrasAbertas'], 0);
      });

      test('1 autorização: preserva formato individual com codigoAcesso e codigosAbertos vazio', () async {
        final inv1 = makeInv('1', '9BE', const Duration(minutes: 10));
        await LiveActivityService.syncActiveInvitationsState(
          openInvitations: [inv1],
          moradorNome: 'Cristiano Santos',
          condominioNome: 'Real Park',
        );
        expect(log.last.arguments['countAbertas'], 1);
        expect(log.last.arguments['codigoAcesso'], '9BE');
        expect(log.last.arguments['codigosAbertos'], isEmpty);
        expect(log.last.arguments['outrasAbertas'], 0);
      });

      test('2 autorizações: exibe 2 códigos ordenados por mais recente, outrasAbertas = 0', () async {
        final inv1 = makeInv('1', '9BE', const Duration(minutes: 20));
        final inv2 = makeInv('2', 'KJ9', const Duration(minutes: 5)); // mais recente

        await LiveActivityService.syncActiveInvitationsState(
          openInvitations: [inv1, inv2],
          moradorNome: 'Cristiano Santos',
          condominioNome: 'Real Park',
        );

        expect(log.last.arguments['countAbertas'], 2);
        expect(log.last.arguments['codigosAbertos'], ['KJ9', '9BE']);
        expect(log.last.arguments['outrasAbertas'], 0);
      });

      test('3 autorizações: exibe 3 códigos ordenados por mais recente, outrasAbertas = 0', () async {
        final inv1 = makeInv('1', '9BE', const Duration(minutes: 30));
        final inv2 = makeInv('2', 'KJ9', const Duration(minutes: 20));
        final inv3 = makeInv('3', 'I38', const Duration(minutes: 5)); // mais recente

        await LiveActivityService.syncActiveInvitationsState(
          openInvitations: [inv1, inv2, inv3],
          moradorNome: 'Cristiano Santos',
          condominioNome: 'Real Park',
        );

        expect(log.last.arguments['countAbertas'], 3);
        expect(log.last.arguments['codigosAbertos'], ['I38', 'KJ9', '9BE']);
        expect(log.last.arguments['outrasAbertas'], 0);
      });

      test('4 autorizações: exibe 3 códigos mais recentes e outrasAbertas = 1', () async {
        final inv1 = makeInv('1', 'AAA', const Duration(minutes: 40));
        final inv2 = makeInv('2', '9BE', const Duration(minutes: 30));
        final inv3 = makeInv('3', 'KJ9', const Duration(minutes: 20));
        final inv4 = makeInv('4', 'I38', const Duration(minutes: 5)); // mais recente

        await LiveActivityService.syncActiveInvitationsState(
          openInvitations: [inv1, inv2, inv3, inv4],
          moradorNome: 'Cristiano Santos',
          condominioNome: 'Real Park',
        );

        expect(log.last.arguments['countAbertas'], 4);
        expect(log.last.arguments['codigosAbertos'], ['I38', 'KJ9', '9BE']);
        expect(log.last.arguments['outrasAbertas'], 1);
      });

      test('6 autorizações: exibe 3 códigos mais recentes e outrasAbertas = 3', () async {
        final invA = makeInv('A', 'AAA', const Duration(minutes: 60));
        final invB = makeInv('B', 'BBB', const Duration(minutes: 50));
        final invC = makeInv('C', 'CCC', const Duration(minutes: 40));
        final invD = makeInv('D', 'DDD', const Duration(minutes: 30));
        final invE = makeInv('E', 'EEE', const Duration(minutes: 20));
        final invF = makeInv('F', 'FFF', const Duration(minutes: 10)); // mais recente

        await LiveActivityService.syncActiveInvitationsState(
          openInvitations: [invA, invB, invC, invD, invE, invF],
          moradorNome: 'Cristiano Santos',
          condominioNome: 'Real Park',
        );

        expect(log.last.arguments['countAbertas'], 6);
        expect(log.last.arguments['codigosAbertos'], ['FFF', 'EEE', 'DDD']);
        expect(log.last.arguments['outrasAbertas'], 3);
      });

      test('Cancelamento de uma das 3 mais recentes promove a 4ª mais recente para os códigos exibidos', () async {
        final invA = makeInv('A', 'AAA', const Duration(minutes: 60));
        final invB = makeInv('B', 'BBB', const Duration(minutes: 50));
        final invC = makeInv('C', 'CCC', const Duration(minutes: 40));
        final invD = makeInv('D', 'DDD', const Duration(minutes: 30));
        final invE = makeInv('E', 'EEE', const Duration(minutes: 20));
        final invF = makeInv('F', 'FFF', const Duration(minutes: 10));

        // Inicial: 6 abertas -> exibe FFF, EEE, DDD
        await LiveActivityService.syncActiveInvitationsState(
          openInvitations: [invA, invB, invC, invD, invE, invF],
          moradorNome: 'Cristiano Santos',
          condominioNome: 'Real Park',
        );
        expect(log.last.arguments['codigosAbertos'], ['FFF', 'EEE', 'DDD']);

        // Cancelamento de F (a mais recente): agora as abertas são E, D, C, B, A
        await LiveActivityService.syncActiveInvitationsState(
          openInvitations: [invA, invB, invC, invD, invE],
          moradorNome: 'Cristiano Santos',
          condominioNome: 'Real Park',
        );
        expect(log.last.arguments['countAbertas'], 5);
        expect(log.last.arguments['codigosAbertos'], ['EEE', 'DDD', 'CCC']);
        expect(log.last.arguments['outrasAbertas'], 2);
      });

      test('Autorizações canceladas, expiradas ou usadas não aparecem', () {
        final exp = makeInv('exp', 'EXP1', const Duration(days: 2), status: 'expired');
        final canc = makeInv('canc', 'CAN2', const Duration(minutes: 10), status: 'cancelled');
        final used = makeInv('used', 'USD3', const Duration(minutes: 10), status: 'used');
        final comp = makeInv('comp', 'CMP4', const Duration(minutes: 10), compareceu: true);
        final open = makeInv('open', 'OPN5', const Duration(minutes: 10));

        expect(LiveActivityService.isInvitationOpen(exp), isFalse);
        expect(LiveActivityService.isInvitationOpen(canc), isFalse);
        expect(LiveActivityService.isInvitationOpen(used), isFalse);
        expect(LiveActivityService.isInvitationOpen(comp), isFalse);
        expect(LiveActivityService.isInvitationOpen(open), isTrue);
      });

      test('Fase 2.2: Autorização de ontem ainda ativa NÃO entra na Live Activity', () {
        // Criada ontem
        final yesterday = now.subtract(const Duration(days: 1));
        final invYesterday = Invitation(
          id: 'y-1',
          residentId: 'res-cris',
          condominiumId: 'condo-realpark',
          guestName: 'Ontem',
          validityDate: validFuture,
          qrData: 'OLD1',
          status: 'active',
          visitanteCompareceu: false,
          createdAt: yesterday,
          updatedAt: yesterday,
        );

        expect(LiveActivityService.isInvitationOpen(invYesterday), isFalse);
      });

      test('Fase 2.2: Autorização de ontem + uma de hoje -> countAbertas = 1 (apenas a de hoje)', () async {
        final yesterday = now.subtract(const Duration(days: 1));
        final invYesterday = Invitation(
          id: 'y-1',
          residentId: 'res-cris',
          condominiumId: 'condo-realpark',
          guestName: 'Ontem',
          validityDate: validFuture,
          qrData: 'OLD1',
          status: 'active',
          visitanteCompareceu: false,
          createdAt: yesterday,
          updatedAt: yesterday,
        );
        final invToday = makeInv('today-1', 'NEW1', const Duration(minutes: 10));

        final allCached = [invYesterday, invToday];
        final eligible = allCached.where(LiveActivityService.isInvitationOpen).toList();

        expect(eligible.length, 1);
        expect(eligible.first.id, 'today-1');

        await LiveActivityService.syncActiveInvitationsState(
          openInvitations: eligible,
          moradorNome: 'Cristiano Santos',
          condominioNome: 'Real Park',
        );

        expect(log.last.arguments['countAbertas'], 1);
        expect(log.last.arguments['codigoAcesso'], 'NEW1');
        expect(log.last.arguments['codigosAbertos'], isEmpty);
      });

      test('Fase 2.2: Três de ontem + duas de hoje -> countAbertas = 2 (exibe 2 códigos)', () async {
        final yesterday = now.subtract(const Duration(days: 1));
        final invOld1 = Invitation(
          id: 'y-1',
          residentId: 'res-cris',
          condominiumId: 'condo-realpark',
          guestName: 'Ontem 1',
          validityDate: validFuture,
          qrData: 'OLD1',
          status: 'active',
          visitanteCompareceu: false,
          createdAt: yesterday,
          updatedAt: yesterday,
        );
        final invOld2 = Invitation(
          id: 'y-2',
          residentId: 'res-cris',
          condominiumId: 'condo-realpark',
          guestName: 'Ontem 2',
          validityDate: validFuture,
          qrData: 'OLD2',
          status: 'active',
          visitanteCompareceu: false,
          createdAt: yesterday,
          updatedAt: yesterday,
        );
        final invOld3 = Invitation(
          id: 'y-3',
          residentId: 'res-cris',
          condominiumId: 'condo-realpark',
          guestName: 'Ontem 3',
          validityDate: validFuture,
          qrData: 'OLD3',
          status: 'active',
          visitanteCompareceu: false,
          createdAt: yesterday,
          updatedAt: yesterday,
        );

        final invToday1 = makeInv('t-1', 'RE9', const Duration(minutes: 20));
        final invToday2 = makeInv('t-2', 'Q9Z', const Duration(minutes: 5)); // mais recente

        final allCached = [invOld1, invOld2, invOld3, invToday1, invToday2];
        final eligible = allCached.where(LiveActivityService.isInvitationOpen).toList();

        expect(eligible.length, 2);

        await LiveActivityService.syncActiveInvitationsState(
          openInvitations: eligible,
          moradorNome: 'Cristiano Santos',
          condominioNome: 'Real Park',
        );

        expect(log.last.arguments['countAbertas'], 2);
        expect(log.last.arguments['codigosAbertos'], ['Q9Z', 'RE9']);
        expect(log.last.arguments['outrasAbertas'], 0);
      });

    });

    group('Phase 2.3 — Hardening Temporal da Live Activity (Validade Noturna 6h)', () {
      final day23 = DateTime(2026, 9, 23);
      final day24 = DateTime(2026, 9, 24);

      Invitation makeTimedInv(String id, String code, DateTime createdAt, {String status = 'active', bool compareceu = false}) {
        return Invitation(
          id: id,
          residentId: 'res-cris',
          condominiumId: 'condo-realpark',
          guestName: 'Visitante $id',
          validityDate: createdAt,
          qrData: code,
          status: status,
          visitanteCompareceu: compareceu,
          createdAt: createdAt,
          updatedAt: createdAt,
        );
      }

      test('1. criação 21:59 -> expira 23:59', () {
        final created = DateTime(day23.year, day23.month, day23.day, 21, 59);
        final exp = LiveActivityService.calculateEffectiveExpiration(created);
        expect(exp, DateTime(day23.year, day23.month, day23.day, 23, 59, 59));
        expect(DateFormat('HH:mm').format(exp), '23:59');

        final inv = makeTimedInv('inv-2159', 'COD2159', created);
        expect(LiveActivityService.isInvitationOpen(inv, DateTime(day23.year, day23.month, day23.day, 23, 58)), isTrue);
        expect(LiveActivityService.isInvitationOpen(inv, DateTime(day24.year, day24.month, day24.day, 0, 0, 1)), isFalse);
      });

      test('2. criação 22:00 -> expira 04:00 do dia seguinte', () {
        final created = DateTime(day23.year, day23.month, day23.day, 22, 0);
        final exp = LiveActivityService.calculateEffectiveExpiration(created);
        expect(exp, DateTime(day24.year, day24.month, day24.day, 4, 0));
        expect(DateFormat('HH:mm').format(exp), '04:00');

        final inv = makeTimedInv('inv-2200', 'COD2200', created);
        expect(LiveActivityService.isInvitationOpen(inv, DateTime(day24.year, day24.month, day24.day, 3, 59)), isTrue);
        expect(LiveActivityService.isInvitationOpen(inv, DateTime(day24.year, day24.month, day24.day, 4, 0, 1)), isFalse);
      });

      test('3. criação 23:55 -> expira 05:55 do dia seguinte', () {
        final created = DateTime(day23.year, day23.month, day23.day, 23, 55);
        final exp = LiveActivityService.calculateEffectiveExpiration(created);
        expect(exp, DateTime(day24.year, day24.month, day24.day, 5, 55));
        expect(DateFormat('HH:mm').format(exp), '05:55');
      });

      test('4. autorização criada 23:55 permanece elegível às 00:10 (atravessa meia-noite)', () {
        final created = DateTime(day23.year, day23.month, day23.day, 23, 55);
        final inv = makeTimedInv('inv-2355', 'COD2355', created);
        final checkTime = DateTime(day24.year, day24.month, day24.day, 0, 10);
        expect(LiveActivityService.isInvitationOpen(inv, checkTime), isTrue);
      });

      test('5. autorização criada 23:55 permanece elegível às 05:54', () {
        final created = DateTime(day23.year, day23.month, day23.day, 23, 55);
        final inv = makeTimedInv('inv-2355', 'COD2355', created);
        final checkTime = DateTime(day24.year, day24.month, day24.day, 5, 54);
        expect(LiveActivityService.isInvitationOpen(inv, checkTime), isTrue);
      });

      test('6. autorização criada 23:55 deixa de ser elegível após 05:55', () {
        final created = DateTime(day23.year, day23.month, day23.day, 23, 55);
        final inv = makeTimedInv('inv-2355', 'COD2355', created);
        final checkTime = DateTime(day24.year, day24.month, day24.day, 5, 55, 1);
        expect(LiveActivityService.isInvitationOpen(inv, checkTime), isFalse);
      });

      test('7. autorização cancelada durante a madrugada desaparece', () {
        final created = DateTime(day23.year, day23.month, day23.day, 23, 55);
        final inv = makeTimedInv('inv-2355', 'COD2355', created, status: 'cancelled');
        final checkTime = DateTime(day24.year, day24.month, day24.day, 2, 0);
        expect(LiveActivityService.isInvitationOpen(inv, checkTime), isFalse);
      });

      test('8. autorização utilizada/visitanteCompareceu desaparece', () {
        final created = DateTime(day23.year, day23.month, day23.day, 23, 55);
        final invVisited = makeTimedInv('inv-2355', 'COD2355', created, compareceu: true);
        final checkTime = DateTime(day24.year, day24.month, day24.day, 2, 0);
        expect(LiveActivityService.isInvitationOpen(invVisited, checkTime), isFalse);

        final invUsed = makeTimedInv('inv-used', 'COD2355', created, status: 'used');
        expect(LiveActivityService.isInvitationOpen(invUsed, checkTime), isFalse);
      });

      test('9. coexistência: autorização noturna ainda válida do dia anterior + novas do dia atual (ordenação createdAt DESC)', () async {
        final invNight = makeTimedInv('inv-night', 'NIT1', DateTime(day23.year, day23.month, day23.day, 23, 55));
        final invMidnight = makeTimedInv('inv-mid', 'MID2', DateTime(day24.year, day24.month, day24.day, 0, 15));

        final checkTime = DateTime(day24.year, day24.month, day24.day, 0, 30);
        expect(LiveActivityService.isInvitationOpen(invNight, checkTime), isTrue);
        expect(LiveActivityService.isInvitationOpen(invMidnight, checkTime), isTrue);

        final openList = [invNight, invMidnight];
        await LiveActivityService.syncActiveInvitationsState(
          openInvitations: openList,
          moradorNome: 'Cristiano Santos',
          condominioNome: 'Real Park',
        );

        // Deve ordenar por createdAt DESC: MID2 (00:15) primeiro, depois NIT1 (23:55)
        expect(log.last.arguments['countAbertas'], 2);
        expect(log.last.arguments['codigosAbertos'], ['MID2', 'NIT1']);
        // Validade agregada deve ser a MAIOR entre as elegíveis (05:55 da noturna vs 23:59 da meia-noite) -> 23:59
        expect(log.last.arguments['validadeHora'], '23:59');
      });

      test('10. transições completas 0 / 1 / 2 / 3 / 4+', () async {
        final inv1 = makeTimedInv('i-1', 'C1', DateTime(day24.year, day24.month, day24.day, 10, 0));
        final inv2 = makeTimedInv('i-2', 'C2', DateTime(day24.year, day24.month, day24.day, 11, 0));
        final inv3 = makeTimedInv('i-3', 'C3', DateTime(day24.year, day24.month, day24.day, 12, 0));
        final inv4 = makeTimedInv('i-4', 'C4', DateTime(day24.year, day24.month, day24.day, 13, 0));

        // 0
        await LiveActivityService.syncActiveInvitationsState(
          openInvitations: [],
          moradorNome: 'Cristiano',
          condominioNome: 'Real Park',
        );
        expect(log.last.arguments['countAbertas'], 0);

        // 1
        await LiveActivityService.syncActiveInvitationsState(
          openInvitations: [inv1],
          moradorNome: 'Cristiano',
          condominioNome: 'Real Park',
        );
        expect(log.last.arguments['countAbertas'], 1);
        expect(log.last.arguments['codigoAcesso'], 'C1');
        expect(log.last.arguments['codigosAbertos'], isEmpty);
        expect(log.last.arguments['outrasAbertas'], 0);

        // 2
        await LiveActivityService.syncActiveInvitationsState(
          openInvitations: [inv1, inv2],
          moradorNome: 'Cristiano',
          condominioNome: 'Real Park',
        );
        expect(log.last.arguments['countAbertas'], 2);
        expect(log.last.arguments['codigosAbertos'], ['C2', 'C1']);
        expect(log.last.arguments['outrasAbertas'], 0);

        // 3
        await LiveActivityService.syncActiveInvitationsState(
          openInvitations: [inv1, inv2, inv3],
          moradorNome: 'Cristiano',
          condominioNome: 'Real Park',
        );
        expect(log.last.arguments['countAbertas'], 3);
        expect(log.last.arguments['codigosAbertos'], ['C3', 'C2', 'C1']);
        expect(log.last.arguments['outrasAbertas'], 0);

        // 4
        await LiveActivityService.syncActiveInvitationsState(
          openInvitations: [inv1, inv2, inv3, inv4],
          moradorNome: 'Cristiano',
          condominioNome: 'Real Park',
        );
        expect(log.last.arguments['countAbertas'], 4);
        expect(log.last.arguments['codigosAbertos'], ['C4', 'C3', 'C2']);
        expect(log.last.arguments['outrasAbertas'], 1);
      });

      test('11. estado individual permanece com layout aprovado e hora real da validade efetiva', () async {
        final invNight = makeTimedInv('single-night', 'NGH9', DateTime(day23.year, day23.month, day23.day, 23, 55));
        await LiveActivityService.syncActiveInvitationsState(
          openInvitations: [invNight],
          moradorNome: 'Cristiano',
          condominioNome: 'Real Park',
        );

        expect(log.last.arguments['countAbertas'], 1);
        expect(log.last.arguments['codigoAcesso'], 'NGH9');
        expect(log.last.arguments['validadeHora'], '05:55');
        expect(log.last.arguments['statusText'], '🟢 Autorização ativa');
      });

      test('12. estado agregado preserva maior validade e estrutura aprovada', () async {
        final invA = makeTimedInv('agg-1', 'CD1', DateTime(day23.year, day23.month, day23.day, 23, 30)); // expira 05:30
        final invB = makeTimedInv('agg-2', 'CD2', DateTime(day23.year, day23.month, day23.day, 23, 55)); // expira 05:55
        await LiveActivityService.syncActiveInvitationsState(
          openInvitations: [invA, invB],
          moradorNome: 'Cristiano',
          condominioNome: 'Real Park',
        );

        expect(log.last.arguments['countAbertas'], 2);
        expect(log.last.arguments['codigosAbertos'], ['CD2', 'CD1']);
        expect(log.last.arguments['validadeHora'], '05:55'); // Maior validade
        expect(log.last.arguments['statusText'], '🟢 2 autorizações abertas');
      });
    });
  });

  group('InvitationBloc Centralized Live Activity Synchronization', () {
    test('LoadResidentInvitationsPaginated and CreateInvitationRequested trigger 1 -> 2 -> 3 transitions', () async {
      final now = DateTime.now();
      final validFuture = DateTime(now.year, now.month, now.day + 1);

      final inv1 = Invitation(
        id: 'inv-1',
        residentId: 'res-1',
        condominiumId: 'condo-1',
        guestName: 'Visitante 1',
        validityDate: validFuture,
        qrData: 'ABC1',
        status: 'active',
        visitanteCompareceu: false,
        createdAt: now.subtract(const Duration(hours: 1)),
        updatedAt: now.subtract(const Duration(hours: 1)),
      );

      final inv2 = Invitation(
        id: 'inv-2',
        residentId: 'res-1',
        condominiumId: 'condo-1',
        guestName: 'Visitante 2',
        validityDate: validFuture,
        qrData: 'DEF2',
        status: 'active',
        visitanteCompareceu: false,
        createdAt: now,
        updatedAt: now,
      );

      final inv3 = Invitation(
        id: 'inv-3',
        residentId: 'res-1',
        condominiumId: 'condo-1',
        guestName: 'Visitante 3',
        validityDate: validFuture,
        qrData: 'GHI3',
        status: 'active',
        visitanteCompareceu: false,
        createdAt: now.add(const Duration(minutes: 5)),
        updatedAt: now.add(const Duration(minutes: 5)),
      );

      final fakeRepo = _FakeInvitationRepository(
        initialInvitations: [inv1],
        createdInvitations: [inv2, inv3],
      );

      final bloc = InvitationBloc(invitationRepository: fakeRepo);
      LiveActivityService.cacheNames(moradorNome: 'Cristiano', condominioNome: 'Montserrat');

      // 1. Carregamento paginado inicial com 1 autorização aberta
      bloc.add(const LoadResidentInvitationsPaginated(residentId: 'res-1', isRefresh: true));
      await Future.delayed(const Duration(milliseconds: 100));

      expect(bloc.cachedResidentInvitations.length, 1);
      expect(log.any((call) => call.method == 'syncLiveActivityState' && call.arguments['countAbertas'] == 1), isTrue);
      expect(log.last.arguments['countAbertas'], 1);
      expect(log.last.arguments['codigoAcesso'], 'ABC1');

      // 2. Criação da 2ª autorização -> BLoC acumula e dispara transição 1 -> 2
      bloc.add(CreateInvitationRequested(
        residentId: 'res-1',
        guestName: 'Visitante 2',
        validityDate: validFuture,
        condominiumId: 'condo-1',
      ));
      await Future.delayed(const Duration(milliseconds: 100));

      expect(bloc.cachedResidentInvitations.length, 2);
      expect(log.last.arguments['countAbertas'], 2);
      expect(log.last.arguments['statusText'], '🟢 2 autorizações abertas');
      expect(log.last.arguments['codigoAcesso'], isNull);
      expect(log.last.arguments['codigosAbertos'], ['DEF2', 'ABC1']);
      expect(log.last.arguments['outrasAbertas'], 0);

      // 3. Criação da 3ª autorização -> BLoC acumula e dispara transição 2 -> 3
      bloc.add(CreateInvitationRequested(
        residentId: 'res-1',
        guestName: 'Visitante 3',
        validityDate: validFuture,
        condominiumId: 'condo-1',
      ));
      await Future.delayed(const Duration(milliseconds: 100));

      expect(bloc.cachedResidentInvitations.length, 3);
      expect(log.last.arguments['countAbertas'], 3);
      expect(log.last.arguments['statusText'], '🟢 3 autorizações abertas');
      expect(log.last.arguments['codigosAbertos'], ['GHI3', 'DEF2', 'ABC1']);
      expect(log.last.arguments['outrasAbertas'], 0);

      // 4. Cancelamento de uma autorização -> BLoC transiciona 3 -> 2
      bloc.add(const CancelInvitationRequested('inv-3'));
      await Future.delayed(const Duration(milliseconds: 100));

      expect(log.last.arguments['countAbertas'], 2);
      expect(log.last.arguments['statusText'], '🟢 2 autorizações abertas');
      expect(log.last.arguments['codigosAbertos'], ['DEF2', 'ABC1']);
      expect(log.last.arguments['outrasAbertas'], 0);

      // 5. Cancelamento de outra -> BLoC transiciona 2 -> 1 (restaura credencial individual com código)
      bloc.add(const CancelInvitationRequested('inv-2'));
      await Future.delayed(const Duration(milliseconds: 100));

      expect(log.last.arguments['countAbertas'], 1);
      expect(log.last.arguments['codigoAcesso'], 'ABC1');
      expect(log.last.arguments['statusText'], '🟢 Autorização ativa');
      expect(log.last.arguments['codigosAbertos'], isEmpty);
      expect(log.last.arguments['outrasAbertas'], 0);

      // 6. Cancelamento da última -> BLoC transiciona 1 -> 0 (encerra Live Activity)
      bloc.add(const CancelInvitationRequested('inv-1'));
      await Future.delayed(const Duration(milliseconds: 100));

      expect(log.last.arguments['countAbertas'], 0);
      expect(log.last.arguments['codigosAbertos'], isEmpty);
      expect(log.last.arguments['outrasAbertas'], 0);

      await bloc.close();
    });
  });

  group('EntryCredential Android Platform', () {
    const androidChannel = MethodChannel('br.app.condomeet/entry_credential');
    final List<MethodCall> androidLog = <MethodCall>[];

    setUp(() {
      androidLog.clear();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(androidChannel, (MethodCall methodCall) async {
        androidLog.add(methodCall);
        switch (methodCall.method) {
          case 'isCredentialSupported':
            return true;
          case 'syncCredentialState':
            return {
              'success': true,
              'count': methodCall.arguments['countAbertas'] ?? 0,
            };
          case 'endCredential':
            return {
              'success': true,
            };
          case 'getInitialDeepLink':
            return 'list';
          default:
            return null;
        }
      });
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(androidChannel, null);
    });

    test('isEntryCredentialSupported calls Android method channel when on Android', () async {
      final supported = await LiveActivityService.isEntryCredentialSupported();
      expect(supported, isTrue);
      expect(androidLog, hasLength(1));
      expect(androidLog.first.method, 'isCredentialSupported');
    });

    test('syncActiveInvitationsState on Android: 0 invitations ends credential', () async {
      final success = await LiveActivityService.syncActiveInvitationsState(
        openInvitations: [],
        moradorNome: 'Carlos Silva',
        condominioNome: 'Montserrat',
      );

      expect(success, isTrue);
      expect(androidLog, hasLength(1));
      expect(androidLog.first.method, 'syncCredentialState');
      expect(androidLog.first.arguments['countAbertas'], 0);
    });

    test('syncActiveInvitationsState on Android: 1 invitation sends individual card with code', () async {
      final now = DateTime(2026, 9, 23, 14, 0);
      final inv = Invitation(
        id: 'inv-android-1',
        residentId: 'res-1',
        condominiumId: 'condo-1',
        guestName: 'Visitante Teste',
        validityDate: now,
        qrData: 'ANDR1',
        status: 'active',
        visitanteCompareceu: false,
        createdAt: now,
        updatedAt: now,
      );

      final success = await LiveActivityService.syncActiveInvitationsState(
        openInvitations: [inv],
        moradorNome: 'Carlos Silva',
        condominioNome: 'Montserrat',
      );

      expect(success, isTrue);
      expect(androidLog, hasLength(1));
      final call = androidLog.first;
      expect(call.method, 'syncCredentialState');
      expect(call.arguments['countAbertas'], 1);
      expect(call.arguments['invitationId'], 'inv-android-1');
      expect(call.arguments['codigoAcesso'], 'ANDR1');
      expect(call.arguments['visitanteNome'], 'Visitante Teste');
      expect(call.arguments['validadeHora'], '23:59');
      expect(call.arguments['codigosAbertos'], isEmpty);
      expect(call.arguments['outrasAbertas'], 0);
    });

    test('syncActiveInvitationsState on Android: 2 invitations sends latest 2 codes', () async {
      final t1 = DateTime(2026, 9, 23, 20, 0);
      final t2 = DateTime(2026, 9, 23, 21, 0);

      final inv1 = Invitation(
        id: 'inv-1',
        residentId: 'res-1',
        condominiumId: 'condo-1',
        guestName: 'G1',
        validityDate: t1,
        qrData: 'CODE1',
        status: 'active',
        visitanteCompareceu: false,
        createdAt: t1,
        updatedAt: t1,
      );
      final inv2 = Invitation(
        id: 'inv-2',
        residentId: 'res-1',
        condominiumId: 'condo-1',
        guestName: 'G2',
        validityDate: t2,
        qrData: 'CODE2',
        status: 'active',
        visitanteCompareceu: false,
        createdAt: t2,
        updatedAt: t2,
      );

      final success = await LiveActivityService.syncActiveInvitationsState(
        openInvitations: [inv1, inv2],
        moradorNome: 'Carlos Silva',
        condominioNome: 'Montserrat',
      );

      expect(success, isTrue);
      expect(androidLog, hasLength(1));
      final call = androidLog.first;
      expect(call.method, 'syncCredentialState');
      expect(call.arguments['countAbertas'], 2);
      expect(call.arguments['codigosAbertos'], ['CODE2', 'CODE1']);
      expect(call.arguments['outrasAbertas'], 0);
    });

    test('syncActiveInvitationsState on Android: 3 invitations sends latest 3 codes', () async {
      final t1 = DateTime(2026, 9, 23, 10, 0);
      final t2 = DateTime(2026, 9, 23, 11, 0);
      final t3 = DateTime(2026, 9, 23, 12, 0);

      final invitations = [
        Invitation(
          id: 'i1',
          residentId: 'res-1',
          condominiumId: 'c1',
          guestName: 'G1',
          validityDate: t1,
          qrData: 'C1',
          status: 'active',
          visitanteCompareceu: false,
          createdAt: t1,
          updatedAt: t1,
        ),
        Invitation(
          id: 'i2',
          residentId: 'res-1',
          condominiumId: 'c1',
          guestName: 'G2',
          validityDate: t2,
          qrData: 'C2',
          status: 'active',
          visitanteCompareceu: false,
          createdAt: t2,
          updatedAt: t2,
        ),
        Invitation(
          id: 'i3',
          residentId: 'res-1',
          condominiumId: 'c1',
          guestName: 'G3',
          validityDate: t3,
          qrData: 'C3',
          status: 'active',
          visitanteCompareceu: false,
          createdAt: t3,
          updatedAt: t3,
        ),
      ];

      final success = await LiveActivityService.syncActiveInvitationsState(
        openInvitations: invitations,
        moradorNome: 'Carlos Silva',
        condominioNome: 'Montserrat',
      );

      expect(success, isTrue);
      final call = androidLog.first;
      expect(call.arguments['countAbertas'], 3);
      expect(call.arguments['codigosAbertos'], ['C3', 'C2', 'C1']);
      expect(call.arguments['outrasAbertas'], 0);
    });

    test('syncActiveInvitationsState on Android: 4+ invitations sends 3 latest + remaining count', () async {
      final invitations = List.generate(6, (i) {
        final t = DateTime(2026, 9, 23, 10 + i, 0);
        return Invitation(
          id: 'inv-$i',
          residentId: 'res-1',
          condominiumId: 'c1',
          guestName: 'Guest $i',
          validityDate: t,
          qrData: 'QR$i',
          status: 'active',
          visitanteCompareceu: false,
          createdAt: t,
          updatedAt: t,
        );
      });

      final success = await LiveActivityService.syncActiveInvitationsState(
        openInvitations: invitations,
        moradorNome: 'Carlos Silva',
        condominioNome: 'Montserrat',
      );

      expect(success, isTrue);
      final call = androidLog.first;
      expect(call.arguments['countAbertas'], 6);
      expect(call.arguments['codigosAbertos'], ['QR5', 'QR4', 'QR3']);
      expect(call.arguments['outrasAbertas'], 3);
    });

    test('Transitions cycle on Android: 1 -> 2 -> 3 -> 2 -> 1 -> 0', () async {
      final t = DateTime(2026, 9, 23, 15, 0);
      Invitation makeInv(int id) => Invitation(
        id: 'inv-$id',
        residentId: 'res-1',
        condominiumId: 'c1',
        guestName: 'G$id',
        validityDate: t.add(Duration(minutes: id)),
        qrData: 'CODE$id',
        status: 'active',
        visitanteCompareceu: false,
        createdAt: t.add(Duration(minutes: id)),
        updatedAt: t.add(Duration(minutes: id)),
      );

      final inv1 = makeInv(1);
      final inv2 = makeInv(2);
      final inv3 = makeInv(3);

      // 1
      await LiveActivityService.syncActiveInvitationsState(
        openInvitations: [inv1],
        moradorNome: 'Carlos',
        condominioNome: 'Condo',
      );
      expect(androidLog.last.arguments['countAbertas'], 1);
      expect(androidLog.last.arguments['codigoAcesso'], 'CODE1');

      // 1 -> 2
      await LiveActivityService.syncActiveInvitationsState(
        openInvitations: [inv1, inv2],
        moradorNome: 'Carlos',
        condominioNome: 'Condo',
      );
      expect(androidLog.last.arguments['countAbertas'], 2);
      expect(androidLog.last.arguments['codigosAbertos'], ['CODE2', 'CODE1']);

      // 2 -> 3
      await LiveActivityService.syncActiveInvitationsState(
        openInvitations: [inv1, inv2, inv3],
        moradorNome: 'Carlos',
        condominioNome: 'Condo',
      );
      expect(androidLog.last.arguments['countAbertas'], 3);
      expect(androidLog.last.arguments['codigosAbertos'], ['CODE3', 'CODE2', 'CODE1']);

      // 3 -> 2
      await LiveActivityService.syncActiveInvitationsState(
        openInvitations: [inv1, inv2],
        moradorNome: 'Carlos',
        condominioNome: 'Condo',
      );
      expect(androidLog.last.arguments['countAbertas'], 2);
      expect(androidLog.last.arguments['codigosAbertos'], ['CODE2', 'CODE1']);

      // 2 -> 1
      await LiveActivityService.syncActiveInvitationsState(
        openInvitations: [inv1],
        moradorNome: 'Carlos',
        condominioNome: 'Condo',
      );
      expect(androidLog.last.arguments['countAbertas'], 1);
      expect(androidLog.last.arguments['codigoAcesso'], 'CODE1');

      // 1 -> 0
      await LiveActivityService.syncActiveInvitationsState(
        openInvitations: [],
        moradorNome: 'Carlos',
        condominioNome: 'Condo',
      );
      expect(androidLog.last.arguments['countAbertas'], 0);
    });

    test('Shared temporal business rules: 21:59 -> 23:59, 22:00 -> 04:00, 23:55 -> 05:55', () {
      final t2159 = DateTime(2026, 9, 23, 21, 59);
      final exp2159 = LiveActivityService.calculateEffectiveExpiration(t2159);
      expect(exp2159.hour, 23);
      expect(exp2159.minute, 59);
      expect(exp2159.second, 59);
      expect(exp2159.day, 23);

      final t2200 = DateTime(2026, 9, 23, 22, 0);
      final exp2200 = LiveActivityService.calculateEffectiveExpiration(t2200);
      expect(exp2200.hour, 4);
      expect(exp2200.minute, 0);
      expect(exp2200.day, 24);

      final t2355 = DateTime(2026, 9, 23, 23, 55);
      final exp2355 = LiveActivityService.calculateEffectiveExpiration(t2355);
      expect(exp2355.hour, 5);
      expect(exp2355.minute, 55);
      expect(exp2355.day, 24);
    });

    test('Eligibility rules: midnight crossing, cancellation, visited, used, expired', () {
      final nightTime = DateTime(2026, 9, 23, 23, 30);
      Invitation makeInv({
        String status = 'active',
        bool visited = false,
        DateTime? createdAt,
      }) {
        final c = createdAt ?? nightTime;
        return Invitation(
          id: 'test-eligibility',
          residentId: 'r1',
          condominiumId: 'c1',
          guestName: 'G',
          validityDate: c,
          qrData: 'TEST',
          status: status,
          visitanteCompareceu: visited,
          createdAt: c,
          updatedAt: c,
        );
      }

      // Travessia da meia-noite (referência 02:00 do dia seguinte)
      final nextDay2am = DateTime(2026, 9, 24, 2, 0);
      expect(LiveActivityService.isInvitationOpen(makeInv(), nextDay2am), isTrue);

      // Expiração após 6 horas noturnas (referência 06:00 do dia seguinte)
      final nextDay6am = DateTime(2026, 9, 24, 6, 0);
      expect(LiveActivityService.isInvitationOpen(makeInv(), nextDay6am), isFalse);

      // Cancelamento
      expect(LiveActivityService.isInvitationOpen(makeInv(status: 'cancelled'), nextDay2am), isFalse);

      // Visitante compareceu
      expect(LiveActivityService.isInvitationOpen(makeInv(visited: true), nextDay2am), isFalse);

      // Used
      expect(LiveActivityService.isInvitationOpen(makeInv(status: 'used'), nextDay2am), isFalse);

      // Expired
      expect(LiveActivityService.isInvitationOpen(makeInv(status: 'expired'), nextDay2am), isFalse);
    });

    test('endCredencialActivity on Android calls endCredential on Android channel', () async {
      final success = await LiveActivityService.endCredencialActivity(invitationId: 'inv-del');
      expect(success, isTrue);
      expect(androidLog, hasLength(1));
      expect(androidLog.first.method, 'endCredential');
      expect(androidLog.first.arguments['invitationId'], 'inv-del');
    });
  });
}

class _FakeInvitationRepository implements InvitationRepository {
  final List<Invitation> initialInvitations;
  final List<Invitation> createdInvitations;
  int _createIdx = 0;

  _FakeInvitationRepository({
    required this.initialInvitations,
    required this.createdInvitations,
  });

  @override
  Future<Result<List<Invitation>>> getResidentInvitationsPaginated({
    required String residentId,
    required int limit,
    required int offset,
  }) async {
    return Success(List.from(initialInvitations));
  }

  @override
  Future<Result<Invitation>> createInvitation({
    required String residentId,
    required String guestName,
    required DateTime validityDate,
    required String condominiumId,
    String? visitorType,
    String? visitorPhone,
    String? observation,
    String? documento,
    String? placa,
    String? crachaReferencia,
    DateTime? validUntil,
  }) async {
    if (_createIdx < createdInvitations.length) {
      final inv = createdInvitations[_createIdx++];
      return Success(inv);
    }
    return const Failure('No more fake invitations');
  }

  @override
  Future<Result<void>> cancelInvitation(String invitationId) async {
    return const Success(null);
  }

  @override
  Future<Result<void>> approveVisitorEntry({required String invitationId, required String porterId}) async =>
      const Success(null);

  @override
  Future<Result<void>> markAsUsed(String invitationId) async => const Success(null);

  @override
  Stream<List<Invitation>> watchAllActiveInvitations(String condominiumId) => const Stream.empty();

  @override
  Stream<List<Invitation>> watchCondominiumInvitations({
    required String condominiumId,
    bool? liberado,
    String? codeFilter,
    String? blocoFilter,
    String? aptoFilter,
    String? dateFilter,
    int? limit,
  }) =>
      const Stream.empty();

  @override
  Stream<List<Invitation>> watchInvitationsForResident(String residentId) => const Stream.empty();
}
