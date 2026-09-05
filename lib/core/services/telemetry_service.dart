import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:condomeet/core/network/supabase_resilience_service.dart';
import 'package:condomeet/core/services/security_service.dart';

/// Serviço responsável pela observabilidade e telemetria anônima de versões e dispositivos.
/// Opera de forma 100% assíncrona, não bloqueante e com fail-open total.
class TelemetryService {
  final SupabaseClient _supabase;
  final SupabaseResilienceService _resilienceService;
  final FlutterSecureStorage _storage;

  static const String _deviceUuidKey = '_telemetry_device_uuid';
  static const String _salt = 'condomeet_device_salt_2026';
  static const Duration _throttleWindow = Duration(hours: 6);

  TelemetryService({
    SupabaseClient? supabase,
    SupabaseResilienceService? resilienceService,
    FlutterSecureStorage? storage,
    SecurityService? securityService,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _resilienceService = resilienceService ?? SupabaseResilienceService(),
        _storage = storage ?? const FlutterSecureStorage();

  /// Gera ou recupera um identificador técnico anônimo (UUID v4) persistido localmente,
  /// protegido via SHA256 (sem IMEI, MAC Address ou PII).
  Future<String> getOrCreateDeviceIdentifierHash() async {
    try {
      String? deviceUuid;
      try {
        deviceUuid = await _storage.read(key: _deviceUuidKey);
      } catch (_) {}

      if (deviceUuid == null || deviceUuid.isEmpty) {
        deviceUuid = const Uuid().v4();
        try {
          await _storage.write(key: _deviceUuidKey, value: deviceUuid);
        } catch (_) {}
      }

      final bytes = utf8.encode('$deviceUuid:$_salt');
      return sha256.convert(bytes).toString();
    } catch (e) {
      // Fallback determinístico seguro
      return sha256.convert(utf8.encode('fallback_device:$_salt')).toString();
    }
  }

  /// Identifica a plataforma de execução de forma canônica
  String getPlatformName() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'web';
  }

  static const String defaultAppVersion = '3.9.1';
  static const int defaultBuildNumber = 101;

  /// Obtém dinamicamente a versão e build do binário instalado
  Future<Map<String, dynamic>> getAppVersionInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final version = info.version.isNotEmpty ? info.version : defaultAppVersion;
      final build = int.tryParse(info.buildNumber) ?? defaultBuildNumber;
      return {
        'version': version,
        'buildNumber': build,
      };
    } catch (e) {
      return {
        'version': defaultAppVersion,
        'buildNumber': defaultBuildNumber,
      };
    }
  }

  /// Registra ou atualiza a telemetria do dispositivo no Supabase.
  /// 1. Idempotente (Upsert em user_id, device_identifier_hash, platform).
  /// 2. Throttling de 6 horas para last_seen_at (a menos que isLogin == true).
  /// 3. Fail-open absoluto: nunca lança erro ou interrompe o chamador.
  Future<void> recordDeviceActivity({
    required String userId,
    required String? condominiumId,
    String? fcmToken,
    bool isLogin = false,
  }) async {
    // Validação de entrada canônica
    if (userId.isEmpty || condominiumId == null || condominiumId.isEmpty) {
      debugPrint('ℹ️ [Telemetry] Ignorando registro: userId ou condominiumId ausentes.');
      return;
    }

    try {
      final now = DateTime.now().toUtc();
      final throttleKey = '_telemetry_last_seen_$userId';

      // Checagem de Throttling de 6 horas se não for evento formal de login
      if (!isLogin) {
        String? lastSeenStr;
        try {
          lastSeenStr = await _storage.read(key: throttleKey);
        } catch (_) {}

        if (lastSeenStr != null) {
          final lastSeen = DateTime.tryParse(lastSeenStr);
          if (lastSeen != null && now.difference(lastSeen) < _throttleWindow) {
            debugPrint('⏱️ [Telemetry] Throttling ativo (< 6h). Escrita suprimida.');
            return;
          }
        }
      }

      final deviceHash = await getOrCreateDeviceIdentifierHash();
      final platformName = getPlatformName();
      final versionInfo = await getAppVersionInfo();

      final payload = <String, dynamic>{
        'user_id': userId,
        'condominio_id': condominiumId,
        'platform': platformName,
        'app_version': versionInfo['version'],
        'build_number': versionInfo['buildNumber'],
        'device_identifier_hash': deviceHash,
        'last_seen_at': now.toIso8601String(),
        'is_active': true,
      };

      if (fcmToken != null && fcmToken.isNotEmpty) {
        payload['fcm_token'] = fcmToken;
      }

      if (isLogin) {
        payload['last_login_at'] = now.toIso8601String();
      }

      await _resilienceService.execute<void>(
        operationName: 'recordDeviceActivity',
        idempotency: OperationIdempotency.idempotentWrite,
        timeout: const Duration(seconds: 5),
        action: () async {
          await _supabase.from('user_devices').upsert(
                payload,
                onConflict: 'user_id,device_identifier_hash,platform',
              );
        },
      );

      // Atualiza o cache local de throttling após sucesso
      try {
        await _storage.write(key: throttleKey, value: now.toIso8601String());
      } catch (_) {}

      debugPrint('📊 [Telemetry] Dispositivo registrado com sucesso para $userId ($platformName - ${versionInfo['version']}+${versionInfo['buildNumber']})');
    } catch (e) {
      debugPrint('⚠️ [Telemetry] Falha silenciosa de telemetria (fail-open): $e');
    }
  }
}
