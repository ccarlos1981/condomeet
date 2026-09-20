import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Resultado da avaliação do portão de versão
enum VersionGateStatus {
  allow,
  updateRequired,
  killSwitchBypass,
  offlineAllowed,
}

class VersionPolicyData {
  final int? minAndroidBuild;
  final int? minIosBuild;
  final String? minAndroidVersion;
  final String? minIosVersion;
  final String latestAndroidVersion;
  final String latestIosVersion;
  final String title;
  final String message;
  final String storeUrlAndroid;
  final String storeUrlIos;
  final bool isKillSwitchActive;

  const VersionPolicyData({
    this.minAndroidBuild,
    this.minIosBuild,
    this.minAndroidVersion,
    this.minIosVersion,
    required this.latestAndroidVersion,
    required this.latestIosVersion,
    required this.title,
    required this.message,
    required this.storeUrlAndroid,
    required this.storeUrlIos,
    required this.isKillSwitchActive,
  });

  factory VersionPolicyData.fromMap(Map<String, dynamic> map) {
    return VersionPolicyData(
      minAndroidBuild: map['min_android_build'] as int?,
      minIosBuild: map['min_ios_build'] as int?,
      minAndroidVersion: map['min_android_version'] as String?,
      minIosVersion: map['min_ios_version'] as String?,
      latestAndroidVersion: map['latest_android_version'] as String? ?? '3.9.3',
      latestIosVersion: map['latest_ios_version'] as String? ?? '3.9.3',
      title: map['force_update_title'] as String? ?? 'Atualização Necessária',
      message: map['force_update_message'] as String? ??
          'Você precisa atualizar o aplicativo para continuar.',
      storeUrlAndroid: map['store_url_android'] as String? ?? '',
      storeUrlIos: map['store_url_ios'] as String? ?? '',
      isKillSwitchActive: map['is_kill_switch_active'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'min_android_build': minAndroidBuild,
      'min_ios_build': minIosBuild,
      'min_android_version': minAndroidVersion,
      'min_ios_version': minIosVersion,
      'latest_android_version': latestAndroidVersion,
      'latest_ios_version': latestIosVersion,
      'force_update_title': title,
      'force_update_message': message,
      'store_url_android': storeUrlAndroid,
      'store_url_ios': storeUrlIos,
      'is_kill_switch_active': isKillSwitchActive,
    };
  }
}

class VersionGateResult {
  final VersionGateStatus status;
  final int installedBuild;
  final String installedVersion;
  final int? requiredBuild;
  final String? requiredVersion;
  final String storeUrl;
  final String title;
  final String message;

  const VersionGateResult({
    required this.status,
    required this.installedBuild,
    required this.installedVersion,
    this.requiredBuild,
    this.requiredVersion,
    required this.storeUrl,
    required this.title,
    required this.message,
  });

  bool get isBlocked => status == VersionGateStatus.updateRequired;
}

/// Compara duas versões semânticas (ex: '3.9.4' vs '3.9.5').
/// Retorna < 0 se v1 < v2, > 0 se v1 > v2, e 0 se forem equivalentes.
int compareSemver(String v1, String v2) {
  final clean1 = v1.split('+').first.split('-').first.trim();
  final clean2 = v2.split('+').first.split('-').first.trim();

  final parts1 = clean1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  final parts2 = clean2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

  final maxLen = parts1.length > parts2.length ? parts1.length : parts2.length;
  for (int i = 0; i < maxLen; i++) {
    final p1 = i < parts1.length ? parts1[i] : 0;
    final p2 = i < parts2.length ? parts2[i] : 0;
    if (p1 < p2) return -1;
    if (p1 > p2) return 1;
  }
  return 0;
}

class VersionCheckService {
  final SupabaseClient _supabase;
  final FlutterSecureStorage _storage;

  VersionCheckService(
    this._supabase, {
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const String defaultAppVersion = '3.9.3';
  static const int defaultBuildNumber = 102;
  static const Duration _checkTimeout = Duration(seconds: 3);
  static const String _cacheKey = 'cached_app_version_policy';

  /// Salva política em cache local
  Future<void> _savePolicyToCache(Map<String, dynamic> data) async {
    try {
      await _storage.write(key: _cacheKey, value: jsonEncode(data));
    } catch (e) {
      debugPrint('⚠️ [VersionCheck] Erro ao gravar cache local de política: $e');
    }
  }

  /// Recupera última política válida em cache local
  Future<Map<String, dynamic>?> _loadPolicyFromCache() async {
    try {
      final jsonStr = await _storage.read(key: _cacheKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        return jsonDecode(jsonStr) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('⚠️ [VersionCheck] Erro ao ler cache local de política: $e');
    }
    return null;
  }

  /// Executa a checagem de versão respeitando:
  /// 1. Prioridade estrita de min_*_build (SemVer somente se build mínimo ausente).
  /// 2. Cache local em caso de falha de rede (fail-open se não houver cache).
  Future<VersionGateResult> checkVersionGate() async {
    // 1. Web não possui bloqueio de app store
    if (kIsWeb) {
      return const VersionGateResult(
        status: VersionGateStatus.allow,
        installedBuild: defaultBuildNumber,
        installedVersion: defaultAppVersion,
        requiredBuild: defaultBuildNumber,
        requiredVersion: defaultAppVersion,
        storeUrl: '',
        title: '',
        message: '',
      );
    }

    String installedVersion = defaultAppVersion;
    int installedBuild = defaultBuildNumber;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      installedVersion = packageInfo.version.isNotEmpty ? packageInfo.version : defaultAppVersion;
      installedBuild = int.tryParse(packageInfo.buildNumber) ?? defaultBuildNumber;
    } catch (e) {
      debugPrint('⚠️ [VersionCheck] Falha ao ler PackageInfo nativo: $e');
    }

    final isAndroid = defaultTargetPlatform == TargetPlatform.android ||
        (!kIsWeb && Platform.isAndroid);

    try {
      // 2. Consulta remota com timeout estrito de 3 segundos
      final response = await _supabase
          .from('app_version_policy')
          .select()
          .eq('id', 1)
          .maybeSingle()
          .timeout(_checkTimeout);

      if (response == null) {
        debugPrint('ℹ️ [VersionCheck] Tabela de política vazia/indisponível.');
        return _handleFallbackOrCache(
          installedBuild: installedBuild,
          installedVersion: installedVersion,
          isAndroid: isAndroid,
        );
      }

      // Salva no cache local para resiliência
      await _savePolicyToCache(response);

      final policy = VersionPolicyData.fromMap(response);
      return _evaluatePolicy(
        policy: policy,
        installedBuild: installedBuild,
        installedVersion: installedVersion,
        isAndroid: isAndroid,
      );
    } catch (e) {
      debugPrint('⚠️ [VersionCheck] Falha de rede na verificação remota: $e');
      // 3. Em falha de rede, usa a última política válida salva localmente
      return _handleFallbackOrCache(
        installedBuild: installedBuild,
        installedVersion: installedVersion,
        isAndroid: isAndroid,
      );
    }
  }

  /// Trata falha de rede: busca última política em cache; se não houver, Fail-Open
  Future<VersionGateResult> _handleFallbackOrCache({
    required int installedBuild,
    required String installedVersion,
    required bool isAndroid,
  }) async {
    final cachedMap = await _loadPolicyFromCache();
    if (cachedMap != null) {
      debugPrint('📦 [VersionCheck] Usando última política salva localmente em cache.');
      final policy = VersionPolicyData.fromMap(cachedMap);
      return _evaluatePolicy(
        policy: policy,
        installedBuild: installedBuild,
        installedVersion: installedVersion,
        isAndroid: isAndroid,
      );
    }

    // Sem cache: libera o app (fail-open) e tenta novamente na próxima abertura
    debugPrint('ℹ️ [VersionCheck] Sem cache local prévio. Acesso liberado (Fail-Open temporário).');
    return VersionGateResult(
      status: VersionGateStatus.offlineAllowed,
      installedBuild: installedBuild,
      installedVersion: installedVersion,
      requiredBuild: installedBuild,
      requiredVersion: installedVersion,
      storeUrl: '',
      title: '',
      message: '',
    );
  }

  /// Avalia as regras de política de versão
  VersionGateResult _evaluatePolicy({
    required VersionPolicyData policy,
    required int installedBuild,
    required String installedVersion,
    required bool isAndroid,
  }) {
    final storeUrl = isAndroid ? policy.storeUrlAndroid : policy.storeUrlIos;
    final minBuild = isAndroid ? policy.minAndroidBuild : policy.minIosBuild;
    final minVersion = isAndroid ? policy.minAndroidVersion : policy.minIosVersion;

    // 1. Kill Switch de emergência
    if (policy.isKillSwitchActive) {
      debugPrint('🛡️ [VersionCheck] Kill Switch ATIVO. Bloqueio suspenso.');
      return VersionGateResult(
        status: VersionGateStatus.killSwitchBypass,
        installedBuild: installedBuild,
        installedVersion: installedVersion,
        requiredBuild: minBuild,
        requiredVersion: minVersion,
        storeUrl: storeUrl,
        title: policy.title,
        message: policy.message,
      );
    }

    // 2. Decisão de bloqueio: Prioriza min_*_build. Compara SemVer SOMENTE se build ausente.
    bool isUpdateRequired = false;

    if (minBuild != null && minBuild > 0) {
      // Prioridade 1: Comparação por build
      if (installedBuild < minBuild) {
        isUpdateRequired = true;
        debugPrint('🚫 [VersionCheck] Bloqueio por Build: instalada ($installedBuild) < mínima ($minBuild)');
      }
    } else if (minVersion != null && minVersion.trim().isNotEmpty) {
      // Prioridade 2: Comparação SemVer somente se minBuild ausente/nulo
      if (compareSemver(installedVersion, minVersion) < 0) {
        isUpdateRequired = true;
        debugPrint('🚫 [VersionCheck] Bloqueio por SemVer: instalada ($installedVersion) < mínima ($minVersion)');
      }
    }

    if (isUpdateRequired) {
      return VersionGateResult(
        status: VersionGateStatus.updateRequired,
        installedBuild: installedBuild,
        installedVersion: installedVersion,
        requiredBuild: minBuild,
        requiredVersion: minVersion,
        storeUrl: storeUrl,
        title: 'Atualização Obrigatória',
        message: 'Você precisa atualizar o aplicativo para continuar.',
      );
    }

    debugPrint('✅ [VersionCheck] Versão compatível. Acesso liberado.');
    return VersionGateResult(
      status: VersionGateStatus.allow,
      installedBuild: installedBuild,
      installedVersion: installedVersion,
      requiredBuild: minBuild,
      requiredVersion: minVersion,
      storeUrl: storeUrl,
      title: policy.title,
      message: policy.message,
    );
  }
}
