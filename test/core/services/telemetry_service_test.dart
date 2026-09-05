import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/services/telemetry_service.dart';
import 'package:condomeet/core/network/supabase_resilience_service.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

class FakePostgrestFilterBuilder extends Fake implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {
  @override
  Future<R> then<R>(FutureOr<R> Function(List<Map<String, dynamic>> value) onValue, {Function? onError}) async {
    return onValue([]);
  }
}

// ignore: must_be_immutable
class FakeSupabaseQueryBuilder extends Fake implements SupabaseQueryBuilder {
  final FakePostgrestFilterBuilder filterBuilder;
  int upsertCallCount = 0;
  dynamic lastPayload;
  String? lastOnConflict;

  FakeSupabaseQueryBuilder(this.filterBuilder);

  @override
  PostgrestFilterBuilder upsert(Object values, {String? onConflict, bool ignoreDuplicates = false, bool defaultToNull = true, int? count}) {
    upsertCallCount++;
    lastPayload = values;
    lastOnConflict = onConflict;
    return filterBuilder;
  }
}

class FakeSupabaseClient extends Fake implements SupabaseClient {
  final FakeSupabaseQueryBuilder queryBuilder;
  FakeSupabaseClient(this.queryBuilder);

  @override
  SupabaseQueryBuilder from(String table) => queryBuilder;
}

class FakeSupabaseResilienceService extends SupabaseResilienceService {
  int executeCallCount = 0;
  String? lastOperationName;
  OperationIdempotency? lastIdempotency;
  bool shouldThrow = false;

  @override
  Future<T> execute<T>({
    required String operationName,
    required OperationIdempotency idempotency,
    required Future<T> Function() action,
    int maxAttempts = 3,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    executeCallCount++;
    lastOperationName = operationName;
    lastIdempotency = idempotency;

    if (shouldThrow) {
      throw Exception('Simulated Resilience Failure');
    }

    return await action();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakePostgrestFilterBuilder fakeFilterBuilder;
  late FakeSupabaseQueryBuilder fakeQueryBuilder;
  late FakeSupabaseClient fakeSupabase;
  late MockFlutterSecureStorage mockStorage;
  late FakeSupabaseResilienceService fakeResilienceService;
  late TelemetryService telemetryService;

  setUp(() {
    fakeFilterBuilder = FakePostgrestFilterBuilder();
    fakeQueryBuilder = FakeSupabaseQueryBuilder(fakeFilterBuilder);
    fakeSupabase = FakeSupabaseClient(fakeQueryBuilder);
    mockStorage = MockFlutterSecureStorage();
    fakeResilienceService = FakeSupabaseResilienceService();

    telemetryService = TelemetryService(
      supabase: fakeSupabase,
      resilienceService: fakeResilienceService,
      storage: mockStorage,
    );
  });

  group('TelemetryService - Unit Tests', () {
    test('getOrCreateDeviceIdentifierHash returns 64-char sha256 hash and persists uuid', () async {
      when(() => mockStorage.read(key: '_telemetry_device_uuid'))
          .thenAnswer((_) async => null);
      when(() => mockStorage.write(key: '_telemetry_device_uuid', value: any(named: 'value')))
          .thenAnswer((_) async => {});

      final hash = await telemetryService.getOrCreateDeviceIdentifierHash();

      expect(hash, isNotEmpty);
      expect(hash.length, 64); // SHA256 hex length
      verify(() => mockStorage.write(key: '_telemetry_device_uuid', value: any(named: 'value'))).called(1);
    });

    test('getOrCreateDeviceIdentifierHash reuses existing uuid', () async {
      when(() => mockStorage.read(key: '_telemetry_device_uuid'))
          .thenAnswer((_) async => 'existing-uuid-12345');

      final hash1 = await telemetryService.getOrCreateDeviceIdentifierHash();
      final hash2 = await telemetryService.getOrCreateDeviceIdentifierHash();

      expect(hash1, equals(hash2));
      verifyNever(() => mockStorage.write(key: '_telemetry_device_uuid', value: any(named: 'value')));
    });

    test('getPlatformName returns valid platform string', () {
      final platform = telemetryService.getPlatformName();
      expect(['ios', 'android', 'web'], contains(platform));
    });

    test('recordDeviceActivity ignores empty userId or empty condominiumId', () async {
      await telemetryService.recordDeviceActivity(userId: '', condominiumId: 'condo-1');
      await telemetryService.recordDeviceActivity(userId: 'user-1', condominiumId: null);
      await telemetryService.recordDeviceActivity(userId: 'user-1', condominiumId: '');

      expect(fakeResilienceService.executeCallCount, 0);
      expect(fakeQueryBuilder.upsertCallCount, 0);
    });

    test('recordDeviceActivity applies 6-hour throttling for last_seen_at when isLogin is false', () async {
      final recentTime = DateTime.now().toUtc().subtract(const Duration(hours: 2));
      when(() => mockStorage.read(key: '_telemetry_last_seen_user-123'))
          .thenAnswer((_) async => recentTime.toIso8601String());

      await telemetryService.recordDeviceActivity(
        userId: 'user-123',
        condominiumId: 'condo-456',
        isLogin: false,
      );

      // Should be throttled (< 6h), so executeCallCount and upsertCallCount should be 0
      expect(fakeResilienceService.executeCallCount, 0);
      expect(fakeQueryBuilder.upsertCallCount, 0);
    });

    test('recordDeviceActivity bypasses throttling and updates payload when isLogin is true', () async {
      final recentTime = DateTime.now().toUtc().subtract(const Duration(hours: 1));
      when(() => mockStorage.read(key: '_telemetry_last_seen_user-123'))
          .thenAnswer((_) async => recentTime.toIso8601String());
      when(() => mockStorage.read(key: '_telemetry_device_uuid'))
          .thenAnswer((_) async => 'test-device-uuid');
      when(() => mockStorage.write(key: any(named: 'key'), value: any(named: 'value')))
          .thenAnswer((_) async => {});

      await telemetryService.recordDeviceActivity(
        userId: 'user-123',
        condominiumId: 'condo-456',
        isLogin: true,
      );

      expect(fakeResilienceService.executeCallCount, 1);
      expect(fakeResilienceService.lastOperationName, 'recordDeviceActivity');
      expect(fakeResilienceService.lastIdempotency, OperationIdempotency.idempotentWrite);
      expect(fakeQueryBuilder.upsertCallCount, 1);
      expect(fakeQueryBuilder.lastOnConflict, 'user_id,device_identifier_hash,platform');
      expect(fakeQueryBuilder.lastPayload['user_id'], 'user-123');
      expect(fakeQueryBuilder.lastPayload['condominio_id'], 'condo-456');
      expect(fakeQueryBuilder.lastPayload['last_login_at'], isNotNull);
    });

    test('recordDeviceActivity fails open without throwing when storage or network fails', () async {
      when(() => mockStorage.read(key: any(named: 'key')))
          .thenAnswer((_) async => throw Exception('SecureStorage unavailable'));
      fakeResilienceService.shouldThrow = true;

      // Should complete normally without throwing
      await expectLater(
        telemetryService.recordDeviceActivity(
          userId: 'user-123',
          condominiumId: 'condo-456',
          isLogin: true,
        ),
        completes,
      );
    });
  });
}
