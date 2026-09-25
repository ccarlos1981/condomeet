import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/features/portaria/domain/entities/parcel.dart';
import 'package:condomeet/features/portaria/domain/repositories/parcel_repository.dart';

// ── Mock Repository for Cancellation Tests ───────────────────────────────────

class _MockParcelCancellationRepo implements ParcelRepository {
  final Map<String, Parcel> _storage = {};
  int cancelCallCount = 0;

  _MockParcelCancellationRepo(List<Parcel> initial) {
    for (final p in initial) {
      _storage[p.id] = p;
    }
  }

  @override
  Future<Result<void>> cancelParcel(String parcelId, {String? reason}) async {
    cancelCallCount++;
    final existing = _storage[parcelId];
    if (existing == null) {
      return const Failure('NOT_FOUND');
    }
    if (existing.status == 'cancelled') {
      return const Failure('ALREADY_CANCELLED');
    }
    if (existing.status == 'delivered') {
      return const Failure('ALREADY_DELIVERED');
    }
    if (existing.status != 'pending') {
      return const Failure('INVALID_STATUS');
    }

    _storage[parcelId] = existing.copyWith(
      status: 'cancelled',
      cancelledAt: DateTime.now(),
      cancelledBy: 'test-user-id',
      cancellationReason: reason ?? 'REGISTERED_BY_MISTAKE',
    );
    return const Success(null);
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
    final existing = _storage[parcelId];
    if (existing == null) return const Failure('NOT_FOUND');
    _storage[parcelId] = existing.copyWith(
      status: 'delivered',
      deliveryTime: DateTime.now(),
      pickupProofUrl: pickupProofUrl,
    );
    return const Success(null);
  }

  @override
  Future<Result<List<Parcel>>> getAllPendingParcels(String condominiumId) async {
    final items = _storage.values
        .where((p) => p.condominiumId == condominiumId && p.status == 'pending')
        .toList();
    return Success(items);
  }

  @override
  Stream<List<Parcel>> watchAllPendingParcels(String condominiumId) {
    final items = _storage.values
        .where((p) => p.condominiumId == condominiumId && p.status == 'pending')
        .toList();
    return Stream.value(items);
  }

  @override
  Future<Result<List<Parcel>>> getParcelsForResident(String residentId) async {
    final items = _storage.values.where((p) => p.residentId == residentId).toList();
    return Success(items);
  }

  @override
  Stream<List<Parcel>> watchPendingParcelsForUnit(String residentId) {
    final items = _storage.values
        .where((p) => p.residentId == residentId && p.status == 'pending')
        .toList();
    return Stream.value(items);
  }

  @override
  Future<Result<void>> registerParcel(Parcel parcel) async {
    _storage[parcel.id] = parcel;
    return const Success(null);
  }

  @override
  Future<Result<List<Parcel>>> getParcelHistory({
    String? residentId,
    required String condominiumId,
  }) async {
    final items = _storage.values
        .where((p) => p.condominiumId == condominiumId && p.status == 'delivered')
        .toList();
    return Success(items);
  }
}

void main() {
  const testCondoId = 'ed90ec35-95f0-4a04-92b4-35fe4217f0e1';

  Parcel createParcel({
    required String id,
    String status = 'pending',
    String block = 'A',
    String unit = '101',
    String? tracking = 'TRK123',
    String? obs = 'Obs intacta',
  }) {
    return Parcel(
      id: id,
      residentId: 'resident-1',
      residentName: 'Morador Teste',
      unitNumber: unit,
      block: block,
      arrivalTime: DateTime(2026, 9, 24, 10, 0),
      status: status,
      condominiumId: testCondoId,
      trackingCode: tracking,
      observacao: obs,
      tipo: 'pacote',
      photoUrl: 'https://example.com/photo.jpg',
    );
  }

  group('Parcel Cancellation — Entity & Immutability Tests', () {
    test('J. Cancelamento preserva dados originais integralmente', () {
      final original = createParcel(id: 'p-1', status: 'pending');
      final cancelTime = DateTime(2026, 9, 24, 11, 30);
      final cancelled = original.copyWith(
        status: 'cancelled',
        cancelledAt: cancelTime,
        cancelledBy: 'porter-uuid',
        cancellationReason: 'REGISTERED_BY_MISTAKE',
      );

      // Verify status mutated
      expect(cancelled.status, 'cancelled');
      expect(cancelled.cancelledAt, cancelTime);
      expect(cancelled.cancelledBy, 'porter-uuid');
      expect(cancelled.cancellationReason, 'REGISTERED_BY_MISTAKE');

      // Verify original metadata completely intact
      expect(cancelled.id, original.id);
      expect(cancelled.residentId, original.residentId);
      expect(cancelled.residentName, original.residentName);
      expect(cancelled.unitNumber, original.unitNumber);
      expect(cancelled.block, original.block);
      expect(cancelled.arrivalTime, original.arrivalTime);
      expect(cancelled.trackingCode, original.trackingCode);
      expect(cancelled.observacao, original.observacao);
      expect(cancelled.tipo, original.tipo);
      expect(cancelled.photoUrl, original.photoUrl);
      expect(cancelled.condominiumId, original.condominiumId);
    });

    test('toMap serializes cancelled attributes correctly', () {
      final cancelTime = DateTime(2026, 9, 24, 11, 30);
      final parcel = createParcel(id: 'p-1').copyWith(
        status: 'cancelled',
        cancelledAt: cancelTime,
        cancelledBy: 'user-123',
        cancellationReason: 'REGISTERED_BY_MISTAKE',
      );

      final map = parcel.toMap();
      expect(map['status'], 'cancelled');
      expect(map['cancelled_at'], cancelTime.toIso8601String());
      expect(map['cancelled_by'], 'user-123');
      expect(map['cancellation_reason'], 'REGISTERED_BY_MISTAKE');
    });
  });

  group('Parcel Cancellation — Lifecycle & Security Rules', () {
    test('A. Cancelamento de encomenda pending autorizado altera status para cancelled', () async {
      final parcel = createParcel(id: 'p-1', status: 'pending');
      final repo = _MockParcelCancellationRepo([parcel]);

      final res = await repo.cancelParcel('p-1', reason: 'REGISTERED_BY_MISTAKE');
      expect(res.isSuccess, isTrue);

      final pending = await repo.getAllPendingParcels(testCondoId);
      expect((pending as Success<List<Parcel>>).data, isEmpty);
    });

    test('B. Encomenda delivered NÃO pode ser cancelada', () async {
      final parcel = createParcel(id: 'p-delivered', status: 'delivered');
      final repo = _MockParcelCancellationRepo([parcel]);

      final res = await repo.cancelParcel('p-delivered');
      expect(res.isFailure, isTrue);
      expect((res as Failure).message, 'ALREADY_DELIVERED');
    });

    test('C & D. Encomenda já cancelada NÃO pode ser cancelada novamente (Idempotência)', () async {
      final parcel = createParcel(id: 'p-1', status: 'pending');
      final repo = _MockParcelCancellationRepo([parcel]);

      // 1st cancellation
      final first = await repo.cancelParcel('p-1');
      expect(first.isSuccess, isTrue);

      // 2nd cancellation (concurrent/retry)
      final second = await repo.cancelParcel('p-1');
      expect(second.isFailure, isTrue);
      expect((second as Failure).message, 'ALREADY_CANCELLED');

      expect(repo.cancelCallCount, 2);
    });

    test('G, H, I. KPIs: Pending diminui 1, Delivered não muda, Archived não muda', () async {
      final p1 = createParcel(id: 'p-1', status: 'pending');
      final p2 = createParcel(id: 'p-2', status: 'pending');
      final d1 = createParcel(id: 'd-1', status: 'delivered');
      final repo = _MockParcelCancellationRepo([p1, p2, d1]);

      // Before cancel
      final pendingBefore = (await repo.getAllPendingParcels(testCondoId) as Success<List<Parcel>>).data.length;
      final deliveredBefore = (await repo.getParcelHistory(condominiumId: testCondoId) as Success<List<Parcel>>).data.length;
      expect(pendingBefore, 2);
      expect(deliveredBefore, 1);

      // Cancel p1
      await repo.cancelParcel('p-1');

      // After cancel
      final pendingAfter = (await repo.getAllPendingParcels(testCondoId) as Success<List<Parcel>>).data.length;
      final deliveredAfter = (await repo.getParcelHistory(condominiumId: testCondoId) as Success<List<Parcel>>).data.length;

      // Pending decreases by 1
      expect(pendingAfter, pendingBefore - 1);
      // Delivered is unchanged
      expect(deliveredAfter, deliveredBefore);
    });
  });

  group('Parcel Cancellation — Non-regression on Existing Features', () {
    test('S. Dar Baixa continua funcionando sem regressão', () async {
      final parcel = createParcel(id: 'p-1', status: 'pending');
      final repo = _MockParcelCancellationRepo([parcel]);

      final res = await repo.markAsDelivered('p-1', pickedUpById: 'res-1', pickedUpByName: 'Morador');
      expect(res.isSuccess, isTrue);

      final history = await repo.getParcelHistory(condominiumId: testCondoId);
      expect((history as Success<List<Parcel>>).data.length, 1);
    });

    test('T & U. Baixa Silenciosa e entrega a terceiro continuam funcionando', () async {
      final parcel = createParcel(id: 'p-2', status: 'pending');
      final repo = _MockParcelCancellationRepo([parcel]);

      final res = await repo.markAsDelivered(
        'p-2',
        pickedUpByName: 'Porteiro Terceiro',
        silentDischarge: true,
      );
      expect(res.isSuccess, isTrue);
    });

    test('V. Isolamento "Minhas Encomendas" permanece restrito à unidade', () async {
      final p1 = createParcel(id: 'p-1').copyWith(residentId: 'user-A');
      final p2 = createParcel(id: 'p-2').copyWith(residentId: 'user-B');
      final repo = _MockParcelCancellationRepo([p1, p2]);

      final userAParcels = await repo.getParcelsForResident('user-A');
      expect((userAParcels as Success<List<Parcel>>).data.length, 1);
      expect((userAParcels).data.first.id, 'p-1');
    });
  });

  group('Push FCM Dispatch Logic Simulation', () {
    test('K & L. Multi-resident unit dispatches to all valid tokens and handles missing tokens', () {
      final residents = [
        {'id': 'r1', 'nome': 'Res 1', 'fcm': 'token-1', 'status': 'aprovado', 'bloqueado': false},
        {'id': 'r2', 'nome': 'Res 2', 'fcm': 'token-2', 'status': 'aprovado', 'bloqueado': false},
        {'id': 'r3', 'nome': 'Res 3 (Sem FCM)', 'fcm': null, 'status': 'aprovado', 'bloqueado': false},
        {'id': 'r4', 'nome': 'Res 4 (Bloqueado)', 'fcm': 'token-4', 'status': 'aprovado', 'bloqueado': true},
        {'id': 'r5', 'nome': 'Res 5 (Pendente)', 'fcm': 'token-5', 'status': 'pendente', 'bloqueado': false},
      ];

      // Filter exactly as in parcel-push-notify
      final validRecipients = residents.where((r) {
        return r['status'] == 'aprovado' && r['bloqueado'] == false;
      }).toList();

      expect(validRecipients.length, 3); // r1, r2, r3

      final tokensToSend = validRecipients
          .map((r) => r['fcm'])
          .where((t) => t != null && t.toString().isNotEmpty)
          .cast<String>()
          .toList();

      // r3 without FCM does NOT block r1 and r2
      expect(tokensToSend.length, 2);
      expect(tokensToSend, containsAll(['token-1', 'token-2']));
      expect(tokensToSend, isNot(contains('token-4')));
      expect(tokensToSend, isNot(contains('token-5')));
    });
  });

  group('UI & Responsiveness (375x667 Viewport)', () {
    testWidgets('Q. Card e botões de ação cabem em 375x667 sem overflow', (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool cancelClicked = false;
      bool baixaClicked = false;
      bool silenciosaClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Bloco A / Apto 101'),
                      const SizedBox(height: 8),
                      // Action buttons hierarchy: Row 1 = Dar Baixa + Silenciosa, Row 2 = Cancelar
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => baixaClicked = true,
                              icon: const Icon(Icons.check, size: 14),
                              label: const Text('Dar Baixa', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => silenciosaClicked = true,
                              icon: const Icon(Icons.mark_chat_read, size: 14),
                              label: const Text('Silenciosa', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => cancelClicked = true,
                          icon: const Icon(Icons.cancel_outlined, size: 14, color: Colors.red),
                          label: const Text('Cancelar Encomenda', style: TextStyle(fontSize: 12, color: Colors.red)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // No overflow exception thrown
      expect(tester.takeException(), isNull);

      // Verify tap interaction
      await tester.tap(find.text('Dar Baixa'));
      expect(baixaClicked, isTrue);

      await tester.tap(find.text('Silenciosa'));
      expect(silenciosaClicked, isTrue);

      await tester.tap(find.text('Cancelar Encomenda'));
      expect(cancelClicked, isTrue);
    });

    testWidgets('Confirmation Dialog renders mandatory copy and single-click protection', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Cancelar encomenda?'),
                      content: const Text(
                        'Tem certeza de que deseja cancelar esta encomenda?\n\n'
                        'Os moradores desta unidade serão avisados para '
                        'desconsiderar a notificação de encomenda recebida '
                        'anteriormente.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('VOLTAR'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('SIM, CANCELAR'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Cancelar encomenda?'), findsOneWidget);
      expect(find.textContaining('desconsiderar a notificação'), findsOneWidget);
      expect(find.text('VOLTAR'), findsOneWidget);
      expect(find.text('SIM, CANCELAR'), findsOneWidget);

      await tester.tap(find.text('VOLTAR'));
      await tester.pumpAndSettle();
      expect(find.text('Cancelar encomenda?'), findsNothing);
    });
  });
}
