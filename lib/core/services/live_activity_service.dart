import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:condomeet/features/access/domain/models/invitation.dart';

/// Serviço responsável pelo gerenciamento da Live Activity única (ActivityKit)
/// para a Credencial de Entrada do Morador no iOS.
class LiveActivityService {
  static const MethodChannel _channel = MethodChannel('br.app.condomeet/live_activity');
  static const MethodChannel _androidChannel = MethodChannel('br.app.condomeet/entry_credential');
  static final Logger _logger = Logger();

  static bool get isIOS => defaultTargetPlatform == TargetPlatform.iOS;
  static bool get isAndroid => defaultTargetPlatform == TargetPlatform.android;

  static final StreamController<String> _deepLinkController = StreamController<String>.broadcast();
  static Stream<String> get deepLinkStream => _deepLinkController.stream;
  static String? _pendingInvitationId;
  static String? get pendingInvitationId => _pendingInvitationId;
  static void clearPendingInvitationId() => _pendingInvitationId = null;
  static bool _deepLinkInitialized = false;

  static String? _cachedMoradorNome;
  static String? get cachedMoradorNome => _cachedMoradorNome;

  static String? _cachedCondominioNome;
  static String? get cachedCondominioNome => _cachedCondominioNome;

  /// Atualiza o cache de nomes em memória para garantir consistência em syncs background/bloc
  static void cacheNames({String? moradorNome, String? condominioNome}) {
    if (moradorNome != null && moradorNome.trim().isNotEmpty) {
      _cachedMoradorNome = moradorNome.trim();
    }
    if (condominioNome != null && condominioNome.trim().isNotEmpty) {
      _cachedCondominioNome = condominioNome.trim();
    }
  }

  /// Inicializa a escuta de deep links vindos da Live Activity / URL scheme (iOS e Android)
  static Future<void> initializeDeepLinking() async {
    if (_deepLinkInitialized) return;
    _deepLinkInitialized = true;

    Future<void> handleMethodCall(MethodCall call) async {
      if (call.method == 'onDeepLink') {
        final args = call.arguments;
        String? id;
        bool isList = false;
        if (args is Map) {
          id = args['invitationId'] as String?;
          isList = args['isList'] == true;
        } else if (args is String) {
          id = args;
          isList = (args == 'list' || args == '__list__');
        }
        final target = isList ? 'list' : (id ?? 'list');
        _logger.i('LiveActivityService: onDeepLink recebido: $target (isList: $isList)');
        _pendingInvitationId = target;
        _deepLinkController.add(target);
      }
    }

    _channel.setMethodCallHandler(handleMethodCall);
    _androidChannel.setMethodCallHandler(handleMethodCall);

    if (isIOS) {
      try {
        final initialId = await _channel.invokeMethod<String>('getInitialDeepLink');
        if (initialId != null && initialId.isNotEmpty) {
          _logger.i('LiveActivityService: getInitialDeepLink retornou: $initialId');
          _pendingInvitationId = initialId;
          _deepLinkController.add(initialId);
        }
      } catch (e) {
        _logger.w('Erro ao obter initial deep link no iOS: $e');
      }
    } else if (isAndroid) {
      try {
        final initialId = await _androidChannel.invokeMethod<String>('getInitialDeepLink');
        if (initialId != null && initialId.isNotEmpty) {
          _logger.i('LiveActivityService: getInitialDeepLink retornou no Android: $initialId');
          _pendingInvitationId = initialId;
          _deepLinkController.add(initialId);
        }
      } catch (e) {
        _logger.w('Erro ao obter initial deep link no Android: $e');
      }
    }
  }

  /// Verifica se o dispositivo suporta e está com Live Activities ativadas (iOS)
  static Future<bool> isLiveActivitySupported() async {
    if (!isIOS) return false;
    try {
      final bool? isSupported = await _channel.invokeMethod<bool>('isLiveActivitySupported');
      return isSupported ?? false;
    } catch (e) {
      _logger.w('Erro ao verificar suporte a Live Activity: $e');
      return false;
    }
  }

  /// Verifica se a Credencial de Entrada é suportada na plataforma atual (iOS ou Android)
  static Future<bool> isEntryCredentialSupported() async {
    if (isIOS) return isLiveActivitySupported();
    if (isAndroid) {
      try {
        final bool? isSupported = await _androidChannel.invokeMethod<bool>('isCredentialSupported');
        return isSupported ?? false;
      } catch (e) {
        _logger.w('Erro ao verificar suporte a Credencial Android: $e');
        return false;
      }
    }
    return false;
  }

  /// Calcula a data/hora de validade efetiva da autorização para a Live Activity.
  ///
  /// Regra canônica da Fase 2.3:
  /// 1. Criada ANTES das 22:00 (localCreated.hour < 22):
  ///    - Validade efetiva = 23:59:59 do próprio dia de criação.
  /// 2. Criada A PARTIR das 22:00, inclusive (localCreated.hour >= 22):
  ///    - Validade efetiva = createdAt + 6 horas (janela mínima noturna).
  ///    - Permanece elegível mesmo atravessando a meia-noite.
  static DateTime calculateEffectiveExpiration(DateTime createdAt) {
    final localCreated = createdAt.toLocal();
    if (localCreated.hour < 22) {
      return DateTime(
        localCreated.year,
        localCreated.month,
        localCreated.day,
        23,
        59,
        59,
      );
    } else {
      return localCreated.add(const Duration(hours: 6));
    }
  }

  /// Avalia se uma autorização é elegível para participar da Live Activity.
  ///
  /// Regras canônicas da Fase 2.3:
  /// 1. Status ativo ('active');
  /// 2. Não cancelada, não usada e não expirada ('cancelled', 'used', 'expired');
  /// 3. Visitante ainda não compareceu (!visitanteCompareceu);
  /// 4. Não expirada pela validade efetiva (now < effectiveExpiration).
  ///    - Autorizações criadas a partir das 22:00 possuem janela mínima de 6 horas
  ///      e permanecem elegíveis mesmo após a virada da meia-noite.
  static bool isInvitationOpen(Invitation inv, [DateTime? referenceNow]) {
    // 1. Status ativo obrigatório
    if (inv.status != 'active') return false;

    // 2. Não cancelada, expirada ou usada
    if (inv.status == 'cancelled' || inv.status == 'used' || inv.status == 'expired') {
      return false;
    }

    // 3. Visitante ainda não compareceu
    if (inv.visitanteCompareceu) return false;

    final now = referenceNow ?? DateTime.now();

    // 4. Validade efetiva (regra noturna com janela mínima de 6 horas)
    final effectiveExpiration = calculateEffectiveExpiration(inv.createdAt);
    if (!now.isBefore(effectiveExpiration)) return false;

    return true;
  }

  static bool _isSyncInFlight = false;

  /// Sincroniza o estado da única Live Activity (iOS) ou Credencial de Entrada (Android) com as autorizações abertas do morador.
  ///
  /// Estados possíveis:
  /// - 0 autorizações: encerra a Live Activity / Credencial Android.
  /// - 1 autorização: exibe a credencial completa com código de acesso.
  /// - 2+ autorizações: exibe o estado agregado com contador ('🟢 N autorizações abertas').
  static Future<bool> syncActiveInvitationsState({
    required List<Invitation> openInvitations,
    required String moradorNome,
    required String condominioNome,
  }) async {
    if (!isIOS && !isAndroid) return false;

    if (_isSyncInFlight) {
      _logger.d('LiveActivityService: syncActiveInvitationsState já em execução. Ignorando chamada concorrente.');
      return false;
    }
    _isSyncInFlight = true;

    try {
      final int count = openInvitations.length;

      if (count <= 0) {
        _logger.i('LiveActivityService: Encerrando credencial ativa (0 autorizações abertas)');
        if (isIOS) {
          final result = await _channel.invokeMapMethod<String, dynamic>('syncLiveActivityState', {
            'countAbertas': 0,
            'codigosAbertos': <String>[],
            'outrasAbertas': 0,
          });
          return result?['success'] == true;
        } else {
          final result = await _androidChannel.invokeMapMethod<String, dynamic>('syncCredentialState', {
            'countAbertas': 0,
            'codigosAbertos': <String>[],
            'outrasAbertas': 0,
          });
          return result?['success'] == true;
        }
      }

      // Ordenar: mais recente primeiro
      final sorted = List<Invitation>.from(openInvitations)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final activeInv = sorted.first;

      // Validade efetiva do card:
      // - 1 autorização: validade efetiva da autorização individual.
      // - 2+ autorizações: adota determinísticamente a maior validade entre as
      //   autorizações atualmente elegíveis, garantindo que o card permaneça
      //   coerente enquanto houver qualquer código válido no lote.
      final DateTime effectiveExpiration;
      if (count == 1) {
        effectiveExpiration = calculateEffectiveExpiration(activeInv.createdAt);
      } else {
        effectiveExpiration = sorted
            .map((inv) => calculateEffectiveExpiration(inv.createdAt))
            .reduce((a, b) => a.isAfter(b) ? a : b);
      }

      final String validadeHora = DateFormat('HH:mm').format(effectiveExpiration);
      final String validityDateIso = effectiveExpiration.toUtc().toIso8601String();

      if (moradorNome.trim().isNotEmpty) _cachedMoradorNome = moradorNome.trim();
      if (condominioNome.trim().isNotEmpty) _cachedCondominioNome = condominioNome.trim();

      final effectiveMoradorNome = moradorNome.trim().isNotEmpty
          ? moradorNome.trim()
          : (_cachedMoradorNome ?? 'Morador');
      final effectiveCondominioNome = condominioNome.trim().isNotEmpty
          ? condominioNome.trim()
          : (_cachedCondominioNome ?? 'Condomínio');

      final Map<String, dynamic> arguments = {
        'countAbertas': count,
        'moradorNome': effectiveMoradorNome,
        'condominioNome': effectiveCondominioNome,
        'validadeHora': validadeHora,
        'validityDateIso': validityDateIso,
        'status': 'active',
        'statusText': count == 1 ? '🟢 Autorização ativa' : '🟢 $count autorizações abertas',
      };

      if (count == 1) {
        arguments['invitationId'] = activeInv.id;
        arguments['codigoAcesso'] = activeInv.qrData;
        if (activeInv.guestName.trim().isNotEmpty) {
          arguments['visitanteNome'] = activeInv.guestName.trim();
          arguments['guestName'] = activeInv.guestName.trim();
        }
        arguments['codigosAbertos'] = <String>[];
        arguments['outrasAbertas'] = 0;
      } else {
        final codigos = sorted
            .map((inv) => inv.qrData.trim())
            .where((c) => c.isNotEmpty)
            .take(3)
            .toList();
        final outras = count > codigos.length ? count - codigos.length : 0;

        arguments['codigosAbertos'] = codigos;
        arguments['outrasAbertas'] = outras;
      }

      _logger.i('LiveActivityService: Sincronizando (count: $count, validade: $validadeHora, codigos: ${arguments['codigosAbertos']})');
      final Map<String, dynamic>? result;
      if (isIOS) {
        result = await _channel.invokeMapMethod<String, dynamic>('syncLiveActivityState', arguments);
      } else {
        result = await _androidChannel.invokeMapMethod<String, dynamic>('syncCredentialState', arguments);
      }
      final success = result?['success'] == true;
      if (!success) {
        _logger.w('LiveActivityService: Sincronização retornou insucesso: $result');
      }
      return success;
    } catch (e) {
      _logger.w('LiveActivityService: Falha graciosa ao sincronizar: $e');
      return false;
    } finally {
      _isSyncInFlight = false;
    }
  }

  /// Inicia ou atualiza a Live Activity ou Credencial Android para uma autorização individual (retrocompatibilidade).
  static Future<bool> startCredencialActivity({
    required String invitationId,
    required String codigoAcesso,
    required String moradorNome,
    required String condominioNome,
    required DateTime validityDate,
    String? visitanteNome,
    String? status,
    String? statusText,
    DateTime? createdAt,
  }) async {
    final effectiveCreatedAt = createdAt ?? DateTime.now();
    return syncActiveInvitationsState(
      openInvitations: [
        Invitation(
          id: invitationId,
          residentId: '',
          condominiumId: '',
          guestName: visitanteNome ?? '',
          validityDate: validityDate,
          qrData: codigoAcesso,
          status: status ?? 'active',
          visitanteCompareceu: false,
          createdAt: effectiveCreatedAt,
          updatedAt: effectiveCreatedAt,
        ),
      ],
      moradorNome: moradorNome,
      condominioNome: condominioNome,
    );
  }

  /// Encerra imediatamente a Live Activity (iOS) ou Credencial de Entrada (Android).
  static Future<bool> endCredencialActivity({String? invitationId}) async {
    if (!isIOS && !isAndroid) return false;
    try {
      _logger.i('Encerrando Live Activity / Credencial Android');
      final Map<String, dynamic>? result;
      if (isIOS) {
        result = await _channel.invokeMapMethod<String, dynamic>('endLiveActivity', {
          if (invitationId != null) 'invitationId': invitationId,
        });
      } else {
        result = await _androidChannel.invokeMapMethod<String, dynamic>('endCredential', {
          if (invitationId != null) 'invitationId': invitationId,
        });
      }
      return result?['success'] == true;
    } catch (e) {
      _logger.w('Erro ao encerrar Live Activity / Credencial Android: $e');
      return false;
    }
  }
}
