import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Classificação da operação por nível de idempotência.
enum OperationIdempotency {
  /// Somente leitura (queries, selects, rpcs de busca sem efeito colateral)
  readOnly,

  /// Escrita idempotente (ex: updateFcmToken por userId, upsert com chave primária)
  idempotentWrite,

  /// Escrita não idempotente (insert sem chave idempotente, sign-in, sign-up, etc.)
  nonIdempotentWrite,
}

/// Serviço centralizado de resiliência e tratamento de exceções do Supabase.
class SupabaseResilienceService {
  final Logger _logger;

  SupabaseResilienceService({Logger? logger})
      : _logger = logger ??
            Logger(
              printer: PrettyPrinter(
                methodCount: 1,
                errorMethodCount: 5,
                lineLength: 100,
                colors: true,
                printEmojis: true,
              ),
            );

  /// Executa uma operação assíncrona com política de retry controlado, timeout e observabilidade.
  ///
  /// - [operationName]: Nome descritivo da operação para logs/telemetria.
  /// - [idempotency]: Classificação da operação (`readOnly`, `idempotentWrite`, `nonIdempotentWrite`).
  /// - [action]: Função assíncrona a ser executada.
  /// - [maxAttempts]: Máximo de tentativas TOTAIS (padrão: 3 = 1 chamada inicial + 2 retries).
  /// - [timeout]: Timeout individual por tentativa (padrão: 15s).
  Future<T> execute<T>({
    required String operationName,
    required OperationIdempotency idempotency,
    required Future<T> Function() action,
    int maxAttempts = 3,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final startTime = DateTime.now();
    int attempt = 0;

    while (attempt < maxAttempts) {
      attempt++;
      try {
        _logger.d(
          '🔄 [Resilience] Executando $operationName (tentativa $attempt/$maxAttempts | tipo: ${idempotency.name})',
        );

        final result = await action().timeout(
          timeout,
          onTimeout: () {
            throw TimeoutException('Timeout de ${timeout.inSeconds}s atingido em $operationName');
          },
        );

        final duration = DateTime.now().difference(startTime).inMilliseconds;
        _logger.i('✅ [Resilience] $operationName concluído com SUCESSO na tentativa $attempt ($duration ms)');
        return result;
      } catch (e, stackTrace) {
        final duration = DateTime.now().difference(startTime).inMilliseconds;
        final isTransient = isTransientError(e);
        final allowsRetry = (idempotency == OperationIdempotency.readOnly ||
                idempotency == OperationIdempotency.idempotentWrite) &&
            isTransient;

        _logger.w(
          '⚠️ [Resilience] Falha em $operationName (tentativa $attempt/$maxAttempts | $duration ms)\n'
          'Erro: ${e.runtimeType} -> $e\n'
          'Transitório: $isTransient | Retry Permitido: $allowsRetry',
        );

        // Se for a última tentativa OU a operação NÃO permitir retry, relança exceção
        if (attempt >= maxAttempts || !allowsRetry) {
          _logger.e(
            '❌ [Resilience] $operationName FALHOU definitivamente após $attempt tentativa(s).',
            error: e,
            stackTrace: stackTrace,
          );
          rethrow;
        }

        // Backoff exponencial com jitter aleatório
        final backoffMs = attempt == 1 ? 500 : 1500;
        final jitter = DateTime.now().microsecond % (attempt * 150);
        final delay = Duration(milliseconds: backoffMs + jitter);

        _logger.d('⏳ [Resilience] Aguardando ${delay.inMilliseconds}ms para retry em $operationName...');
        await Future.delayed(delay);
      }
    }

    throw Exception('Falha inesperada no loop de resiliência de $operationName');
  }

  /// Verifica se uma exceção é classificada como erro transitório de infraestrutura de rede/servidor.
  bool isTransientError(dynamic error) {
    if (error is TimeoutException) {
      return true;
    }

    if (error is SocketException) {
      return true;
    }

    if (error is http.ClientException) {
      final message = error.message.toLowerCase();
      if (message.contains('connection reset') ||
          message.contains('connection closed') ||
          message.contains('software caused connection abort') ||
          message.contains('broken pipe')) {
        return true;
      }
    }

    if (error is PostgrestException) {
      final code = error.code;
      if (code == '502' || code == '503' || code == '504' || code == '408' || code == 'P0000') {
        return true;
      }
    }

    if (error is HttpException) {
      return true;
    }

    final errString = error.toString().toLowerCase();
    if (errString.contains('connection reset') ||
        errString.contains('connection closed') ||
        errString.contains('socketexception') ||
        errString.contains('timeoutexception') ||
        errString.contains('502 bad gateway') ||
        errString.contains('503 service unavailable') ||
        errString.contains('504 gateway timeout')) {
      return true;
    }

    return false;
  }

  /// Converte qualquer exceção técnica em uma mensagem amigável em português para exibição na UI.
  static String getFriendlyErrorMessage(dynamic error) {
    if (error == null) return 'Ocorreu uma falha inesperada.';

    final errString = error.toString();

    // Regras de Autenticação
    if (errString.contains('Invalid login credentials') ||
        errString.contains('invalid_credentials') ||
        errString.contains('invalid_grant')) {
      return 'E-mail ou senha incorretos.';
    }

    if (errString.contains('email_not_confirmed') || errString.contains('Email not confirmed')) {
      return 'Seu e-mail ainda não foi confirmado. Verifique sua caixa de entrada.';
    }

    // Regras de Permissão / RLS
    if (errString.contains('42501') || errString.contains('permission denied')) {
      return 'Acesso não autorizado para esta operação.';
    }

    // Erros Transitórios de Rede
    if (errString.contains('Connection reset') ||
        errString.contains('SocketException') ||
        errString.contains('TimeoutException') ||
        errString.contains('502') ||
        errString.contains('503') ||
        errString.contains('504')) {
      return 'Não foi possível conectar ao servidor. Verifique sua conexão e tente novamente.';
    }

    return 'Ocorreu uma falha temporária. Tente novamente em alguns instantes.';
  }
}
