import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
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

class InMemorySecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _data[key] = value;
    } else {
      _data.remove(key);
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _data[key];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Condomeet',
      packageName: 'br.com.condod.wwwc',
      version: '3.9.4',
      buildNumber: '104',
      buildSignature: '',
    );
  });

  group('SemVer Comparator - Unit Tests', () {
    test('compareSemver evaluates versions accurately', () {
      expect(compareSemver('3.9.4', '3.9.3'), greaterThan(0));
      expect(compareSemver('3.9.4', '3.9.5'), lessThan(0));
      expect(compareSemver('3.9.4', '3.10.0'), lessThan(0));
      expect(compareSemver('3.10.0', '3.9.4'), greaterThan(0));
      expect(compareSemver('3.9.4', '3.9.4'), equals(0));
      expect(compareSemver('3.9.4+104', '3.9.4'), equals(0));
    });
  });

  group('VersionPolicyData - Model Tests', () {
    test('fromMap parses valid payload with optional null versions', () {
      final map = {
        'min_android_build': 102,
        'min_ios_build': 102,
        'min_android_version': null,
        'min_ios_version': null,
        'latest_android_version': '3.9.4',
        'latest_ios_version': '3.9.4',
        'force_update_title': 'Atualização Obrigatória',
        'force_update_message': 'Você precisa atualizar o aplicativo para continuar.',
        'store_url_android': 'https://play.google.com/store/apps/details?id=br.com.condod.wwwc',
        'store_url_ios': 'https://apps.apple.com/app/condomeet/id6740927806',
        'is_kill_switch_active': false,
      };

      final policy = VersionPolicyData.fromMap(map);
      expect(policy.minAndroidBuild, 102);
      expect(policy.minIosBuild, 102);
      expect(policy.minAndroidVersion, isNull);
      expect(policy.minIosVersion, isNull);
      expect(policy.message, 'Você precisa atualizar o aplicativo para continuar.');
      expect(policy.isKillSwitchActive, false);
    });

    test('fromMap leaves min_versions as null without hardcoded defaults', () {
      final policy = VersionPolicyData.fromMap({});
      expect(policy.minAndroidBuild, isNull);
      expect(policy.minIosBuild, isNull);
      expect(policy.minAndroidVersion, isNull);
      expect(policy.minIosVersion, isNull);
      expect(policy.isKillSwitchActive, false);
    });
  });

  group('VersionCheckService - Decision & Priority Tests', () {
    test('Priority Rule: When min_build is set, it takes precedence over min_version', () async {
      // Installed: build 104, version 3.9.4
      // Policy: min_build = 103 (smaller than installed), min_version = 3.9.9 (higher)
      // Because min_build is present, SemVer is NOT checked, so it is ALLOWED.
      final client = FakeSupabaseClient(dataToReturn: {
        'min_android_build': 103,
        'min_ios_build': 103,
        'min_android_version': '3.9.9',
        'min_ios_version': '3.9.9',
        'latest_android_version': '3.9.9',
        'latest_ios_version': '3.9.9',
        'force_update_title': 'Atualização',
        'force_update_message': 'Você precisa atualizar o aplicativo para continuar.',
        'store_url_android': 'https://play.google.com/store/apps/details?id=br.com.condod.wwwc',
        'store_url_ios': 'https://apps.apple.com/app/condomeet/id6740927806',
        'is_kill_switch_active': false,
      });

      final storage = InMemorySecureStorage();
      final service = VersionCheckService(client, storage: storage);
      final result = await service.checkVersionGate();

      expect(result.status, VersionGateStatus.allow);
      expect(result.isBlocked, isFalse);
    });

    test('Priority Rule: When min_build is higher than installed, app is BLOCKED', () async {
      // Installed: build 104
      // Policy: min_build = 105
      final client = FakeSupabaseClient(dataToReturn: {
        'min_android_build': 105,
        'min_ios_build': 105,
        'min_android_version': null,
        'min_ios_version': null,
        'latest_android_version': '3.9.5',
        'latest_ios_version': '3.9.5',
        'force_update_title': 'Atualização Obrigatória',
        'force_update_message': 'Você precisa atualizar o aplicativo para continuar.',
        'store_url_android': 'https://play.google.com/store/apps/details?id=br.com.condod.wwwc',
        'store_url_ios': 'https://apps.apple.com/app/condomeet/id6740927806',
        'is_kill_switch_active': false,
      });

      final storage = InMemorySecureStorage();
      final service = VersionCheckService(client, storage: storage);
      final result = await service.checkVersionGate();

      expect(result.status, VersionGateStatus.updateRequired);
      expect(result.isBlocked, isTrue);
      expect(result.message, 'Você precisa atualizar o aplicativo para continuar.');
    });

    test('SemVer Rule: When min_build is null, SemVer is checked and BLOCKS if installed < min_version', () async {
      // Installed: version 3.9.4
      // Policy: min_build = null, min_version = 3.9.5
      final client = FakeSupabaseClient(dataToReturn: {
        'min_android_build': null,
        'min_ios_build': null,
        'min_android_version': '3.9.5',
        'min_ios_version': '3.9.5',
        'latest_android_version': '3.9.5',
        'latest_ios_version': '3.9.5',
        'force_update_title': 'Atualização Obrigatória',
        'force_update_message': 'Você precisa atualizar o aplicativo para continuar.',
        'store_url_android': 'https://play.google.com/store/apps/details?id=br.com.condod.wwwc',
        'store_url_ios': 'https://apps.apple.com/app/condomeet/id6740927806',
        'is_kill_switch_active': false,
      });

      final storage = InMemorySecureStorage();
      final service = VersionCheckService(client, storage: storage);
      final result = await service.checkVersionGate();

      expect(result.status, VersionGateStatus.updateRequired);
      expect(result.isBlocked, isTrue);
    });

    test('Kill Switch: When active, bypasses block regardless of versions', () async {
      final client = FakeSupabaseClient(dataToReturn: {
        'min_android_build': 999,
        'min_ios_build': 999,
        'latest_android_version': '9.0.0',
        'latest_ios_version': '9.0.0',
        'is_kill_switch_active': true,
      });

      final storage = InMemorySecureStorage();
      final service = VersionCheckService(client, storage: storage);
      final result = await service.checkVersionGate();

      expect(result.status, VersionGateStatus.killSwitchBypass);
      expect(result.isBlocked, isFalse);
    });

    test('Network Failure with Cached Policy: enforces cached policy block', () async {
      final storage = InMemorySecureStorage();
      // Pre-seed storage with a blocking policy
      await storage.write(
        key: 'cached_app_version_policy',
        value: '{"min_android_build": 105, "min_ios_build": 105, "is_kill_switch_active": false}',
      );

      // Client throws on network
      final client = FakeSupabaseClient(shouldThrow: true);
      final service = VersionCheckService(client, storage: storage);

      final result = await service.checkVersionGate();

      // Uses cached policy -> still blocked!
      expect(result.status, VersionGateStatus.updateRequired);
      expect(result.isBlocked, isTrue);
    });

    test('Network Failure without Cached Policy: Fail-Open allows access temporarily', () async {
      final storage = InMemorySecureStorage();
      final client = FakeSupabaseClient(shouldThrow: true);
      final service = VersionCheckService(client, storage: storage);

      final result = await service.checkVersionGate();

      // No cache -> Fail-Open
      expect(result.status, VersionGateStatus.offlineAllowed);
      expect(result.isBlocked, isFalse);
    });
  });
}
