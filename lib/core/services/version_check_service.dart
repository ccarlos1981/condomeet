import 'dart:io';
import 'package:flutter/foundation.dart';
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
  final int minAndroidBuild;
  final int minIosBuild;
  final String latestAndroidVersion;
  final String latestIosVersion;
  final String title;
  final String message;
  final String storeUrlAndroid;
  final String storeUrlIos;
  final bool isKillSwitchActive;

  const VersionPolicyData({
    required this.minAndroidBuild,
    required this.minIosBuild,
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
      minAndroidBuild: map['min_android_build'] as int? ?? 101,
      minIosBuild: map['min_ios_build'] as int? ?? 101,
      latestAndroidVersion: map['latest_android_version'] as String? ?? '3.9.3',
      latestIosVersion: map['latest_ios_version'] as String? ?? '3.9.3',
      title: map['force_update_title'] as String? ?? 'Atualização Necessária',
      message: map['force_update_message'] as String? ??
          'Uma nova versão do Condomeet está disponível com melhorias essenciais de estabilidade e segurança. Atualize para continuar.',
      storeUrlAndroid: map['store_url_android'] as String? ??
          'https://play.google.com/store/apps/details?id=br.com.condod.wwwc',
      storeUrlIos: map['store_url_ios'] as String? ??
          'https://apps.apple.com/app/condomeet/id6740927806',
      isKillSwitchActive: map['is_kill_switch_active'] as bool? ?? false,
    );
  }
}

class VersionGateResult {
  final VersionGateStatus status;
  final int installedBuild;
  final String installedVersion;
  final int requiredBuild;
  final String requiredVersion;
  final String storeUrl;
  final String title;
  final String message;

  const VersionGateResult({
    required this.status,
    required this.installedBuild,
    required this.installedVersion,
    required this.requiredBuild,
    required this.requiredVersion,
    required this.storeUrl,
    required this.title,
    required this.message,
  });

  bool get isBlocked => status == VersionGateStatus.updateRequired;
}

class VersionCheckService {
  final SupabaseClient _supabase;

  VersionCheckService(this._supabase);

  static const String defaultAppVersion = '3.9.3';
  static const int defaultBuildNumber = 102;
  static const Duration _checkTimeout = Duration(seconds: 3);

  /// Executa a checagem com proteção Fail-Open absoluta
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

    final isAndroid = Platform.isAndroid;
    final fallbackStoreUrl = isAndroid
        ? 'https://play.google.com/store/apps/details?id=br.com.condod.wwwc'
        : 'https://apps.apple.com/app/condomeet/id6740927806';

    try {
      // 2. Consulta remota com timeout estrito de 3 segundos
      final response = await _supabase
          .from('app_version_policy')
          .select()
          .eq('id', 1)
          .maybeSingle()
          .timeout(_checkTimeout);

      if (response == null) {
        debugPrint('ℹ️ [VersionCheck] Tabela de política vazia/indisponível. Fail-Open ativado.');
        return VersionGateResult(
          status: VersionGateStatus.allow,
          installedBuild: installedBuild,
          installedVersion: installedVersion,
          requiredBuild: installedBuild,
          requiredVersion: installedVersion,
          storeUrl: fallbackStoreUrl,
          title: '',
          message: '',
        );
      }

      final policy = VersionPolicyData.fromMap(response);

      // 3. Checagem de Kill Switch
      if (policy.isKillSwitchActive) {
        debugPrint('🛡️ [VersionCheck] Kill Switch ATIVO no backend. Bloqueio suspenso.');
        return VersionGateResult(
          status: VersionGateStatus.killSwitchBypass,
          installedBuild: installedBuild,
          installedVersion: installedVersion,
          requiredBuild: isAndroid ? policy.minAndroidBuild : policy.minIosBuild,
          requiredVersion: isAndroid ? policy.latestAndroidVersion : policy.latestIosVersion,
          storeUrl: isAndroid ? policy.storeUrlAndroid : policy.storeUrlIos,
          title: policy.title,
          message: policy.message,
        );
      }

      final requiredBuild = isAndroid ? policy.minAndroidBuild : policy.minIosBuild;
      final requiredVersion = isAndroid ? policy.latestAndroidVersion : policy.latestIosVersion;
      final storeUrl = isAndroid ? policy.storeUrlAndroid : policy.storeUrlIos;

      // 4. Comparação universal permanente: installed < minimum => BLOCK
      if (installedBuild < requiredBuild) {
        debugPrint('🚫 [VersionCheck] Force Update necessário: Build instalada ($installedBuild) < Mínima exigida ($requiredBuild)');
        return VersionGateResult(
          status: VersionGateStatus.updateRequired,
          installedBuild: installedBuild,
          installedVersion: installedVersion,
          requiredBuild: requiredBuild,
          requiredVersion: requiredVersion,
          storeUrl: storeUrl,
          title: policy.title,
          message: policy.message,
        );
      }

      debugPrint('✅ [VersionCheck] Build compatível ($installedBuild >= $requiredBuild). Acesso liberado.');
      return VersionGateResult(
        status: VersionGateStatus.allow,
        installedBuild: installedBuild,
        installedVersion: installedVersion,
        requiredBuild: requiredBuild,
        requiredVersion: requiredVersion,
        storeUrl: storeUrl,
        title: policy.title,
        message: policy.message,
      );
    } catch (e) {
      // 5. Fail-Open em caso de timeout, offline ou erro de banco
      debugPrint('⚠️ [VersionCheck] Erro na verificação remota (Fail-Open): $e');
      return VersionGateResult(
        status: VersionGateStatus.offlineAllowed,
        installedBuild: installedBuild,
        installedVersion: installedVersion,
        requiredBuild: installedBuild,
        requiredVersion: installedVersion,
        storeUrl: fallbackStoreUrl,
        title: '',
        message: '',
      );
    }
  }
}
