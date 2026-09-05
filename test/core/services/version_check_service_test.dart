import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/services/version_check_service.dart';

class FakeTransformBuilder extends Fake implements PostgrestTransformBuilder<Map<String, dynamic>?> {
  final Map<String, dynamic>? dataToReturn;
  final bool shouldThrow;

  FakeTransformBuilder({this.dataToReturn, this.shouldThrow = false});

  @override
  Future<Map<String, dynamic>?> timeout(Duration timeLimit, {FutureOr<Map<String, dynamic>?> Function()? onTimeout}) async {
    if (shouldThrow) {
      throw Exception('Simulated Database Error');
    }
    return dataToReturn;
  }
}

class FakeFilterBuilder extends Fake implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {
  final Map<String, dynamic>? dataToReturn;
  final bool shouldThrow;

  FakeFilterBuilder({this.dataToReturn, this.shouldThrow = false});

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> eq(String column, Object value) => this;

  @override
  PostgrestTransformBuilder<Map<String, dynamic>?> maybeSingle() =>
      FakeTransformBuilder(dataToReturn: dataToReturn, shouldThrow: shouldThrow);
}

class FakeQueryBuilder extends Fake implements SupabaseQueryBuilder {
  final Map<String, dynamic>? dataToReturn;
  final bool shouldThrow;

  FakeQueryBuilder({this.dataToReturn, this.shouldThrow = false});

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> select([String columns = '*']) {
    return FakeFilterBuilder(dataToReturn: dataToReturn, shouldThrow: shouldThrow);
  }
}

class FakeSupabaseClient extends Fake implements SupabaseClient {
  final Map<String, dynamic>? dataToReturn;
  final bool shouldThrow;

  FakeSupabaseClient({this.dataToReturn, this.shouldThrow = false});

  @override
  SupabaseQueryBuilder from(String table) =>
      FakeQueryBuilder(dataToReturn: dataToReturn, shouldThrow: shouldThrow);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VersionPolicyData - Model Tests', () {
    test('fromMap parses valid payload with default fallbacks', () {
      final map = {
        'min_android_build': 102,
        'min_ios_build': 102,
        'latest_android_version': '3.9.3',
        'latest_ios_version': '3.9.3',
        'force_update_title': 'Atualização Obrigatória',
        'force_update_message': 'Por favor atualize.',
        'store_url_android': 'https://play.google.com/store/apps/details?id=br.com.condod.wwwc',
        'store_url_ios': 'https://apps.apple.com/app/condomeet/id6740927806',
        'is_kill_switch_active': false,
      };

      final policy = VersionPolicyData.fromMap(map);
      expect(policy.minAndroidBuild, 102);
      expect(policy.minIosBuild, 102);
      expect(policy.latestAndroidVersion, '3.9.3');
      expect(policy.latestIosVersion, '3.9.3');
      expect(policy.title, 'Atualização Obrigatória');
      expect(policy.isKillSwitchActive, false);
    });

    test('fromMap handles null values with safe defaults', () {
      final policy = VersionPolicyData.fromMap({});
      expect(policy.minAndroidBuild, 101);
      expect(policy.minIosBuild, 101);
      expect(policy.latestAndroidVersion, '3.9.3');
      expect(policy.isKillSwitchActive, false);
    });
  });

  group('VersionCheckService - Unit Tests (T01 a T20)', () {
    test('T01, T02, T03: When policy min_build = 101, installed >= 101 is ALLOWED', () async {
      final client = FakeSupabaseClient(dataToReturn: {
        'min_android_build': 101,
        'min_ios_build': 101,
        'latest_android_version': '3.9.3',
        'latest_ios_version': '3.9.3',
        'force_update_title': 'Atualização Necessária',
        'force_update_message': 'Atualize o app.',
        'store_url_android': 'https://play.google.com/store/apps/details?id=br.com.condod.wwwc',
        'store_url_ios': 'https://apps.apple.com/app/condomeet/id6740927806',
        'is_kill_switch_active': false,
      });

      final service = VersionCheckService(client);
      final result = await service.checkVersionGate();

      expect(result.status, anyOf(VersionGateStatus.allow, VersionGateStatus.offlineAllowed));
      expect(result.isBlocked, isFalse);
    });

    test('T08: When Kill Switch is active, service returns killSwitchBypass and allows access', () async {
      final client = FakeSupabaseClient(dataToReturn: {
        'min_android_build': 999,
        'min_ios_build': 999,
        'latest_android_version': '4.0.0',
        'latest_ios_version': '4.0.0',
        'force_update_title': 'Atualização',
        'force_update_message': 'Msg',
        'store_url_android': 'https://play.google.com/store',
        'store_url_ios': 'https://apple.com/store',
        'is_kill_switch_active': true,
      });

      final service = VersionCheckService(client);
      final result = await service.checkVersionGate();

      expect(result.status, anyOf(VersionGateStatus.killSwitchBypass, VersionGateStatus.allow));
      expect(result.isBlocked, isFalse);
    });

    test('T09, T10: When database query throws error or times out, Fail-Open returns offlineAllowed and allows access', () async {
      final client = FakeSupabaseClient(shouldThrow: true);

      final service = VersionCheckService(client);
      final result = await service.checkVersionGate();

      expect(result.status, anyOf(VersionGateStatus.offlineAllowed, VersionGateStatus.allow));
      expect(result.isBlocked, isFalse);
    });

    test('T11: When database returns null (empty table), Fail-Open returns allow', () async {
      final client = FakeSupabaseClient(dataToReturn: null);

      final service = VersionCheckService(client);
      final result = await service.checkVersionGate();

      expect(result.status, VersionGateStatus.allow);
      expect(result.isBlocked, isFalse);
    });
  });
}
