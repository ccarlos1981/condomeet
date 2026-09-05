import 'dart:async';
import 'dart:io';

import 'package:condomeet/core/network/supabase_resilience_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseResilienceService service;

  setUp(() {
    service = SupabaseResilienceService();
  });

  group('SupabaseResilienceService - Classificação de Erros Transitórios', () {
    test('Identifica TimeoutException como transitório', () {
      expect(service.isTransientError(TimeoutException('timeout')), isTrue);
    });

    test('Identifica SocketException como transitório', () {
      expect(service.isTransientError(const SocketException('Failed host lookup')), isTrue);
    });

    test('Identifica ClientException "Connection reset by peer" como transitório', () {
      expect(
        service.isTransientError(http.ClientException('ClientException: Connection reset by peer')),
        isTrue,
      );
    });

    test('Identifica HTTP Status 502/503/504 em PostgrestException como transitório', () {
      expect(service.isTransientError(const PostgrestException(message: 'Bad Gateway', code: '502')), isTrue);
      expect(service.isTransientError(const PostgrestException(message: 'Service Unavailable', code: '503')), isTrue);
      expect(service.isTransientError(const PostgrestException(message: 'Gateway Timeout', code: '504')), isTrue);
    });

    test('Classifica erros permanentes como NÃO transitórios', () {
      expect(service.isTransientError(const AuthException('Invalid login credentials')), isFalse);
      expect(service.isTransientError(const PostgrestException(message: 'Permission Denied', code: '42501')), isFalse);
      expect(service.isTransientError(const PostgrestException(message: 'Unique violation', code: '23505')), isFalse);
    });
  });

  group('SupabaseResilienceService - Testes Obrigatórios de Login & Idempotência', () {
    test('Teste 1 — Sign In com sucesso (retorna o valor esperado)', () async {
      int attempts = 0;
      final result = await service.execute<String>(
        operationName: 'signInWithEmail',
        idempotency: OperationIdempotency.nonIdempotentWrite,
        timeout: const Duration(seconds: 20),
        action: () async {
          attempts++;
          return 'authenticated_session';
        },
      );

      expect(result, equals('authenticated_session'));
      expect(attempts, equals(1));
    });

    test('Teste 2 — Sign In com timeout (timeout aplicado, 0 retries executados, estouro de exceção)', () async {
      int attempts = 0;

      expect(
        () => service.execute<String>(
          operationName: 'signInWithEmail',
          idempotency: OperationIdempotency.nonIdempotentWrite,
          timeout: const Duration(milliseconds: 100),
          action: () async {
            attempts++;
            await Future.delayed(const Duration(milliseconds: 500));
            return 'never_reached';
          },
        ),
        throwsA(isA<TimeoutException>()),
      );

      await Future.delayed(const Duration(milliseconds: 600));
      expect(attempts, equals(1));
    });

    test('Teste 3 — Sign In com erro de credencial (0 retries executados, lança erro imediatamente)', () async {
      int attempts = 0;

      expect(
        () => service.execute<String>(
          operationName: 'signInWithEmail',
          idempotency: OperationIdempotency.nonIdempotentWrite,
          timeout: const Duration(seconds: 20),
          action: () async {
            attempts++;
            throw const AuthException('Invalid login credentials');
          },
        ),
        throwsA(isA<AuthException>()),
      );

      expect(attempts, equals(1));
    });

    test('Teste 4 — Fetch Profile com Connection Reset (1ª falha, 2ª sucesso -> recupera)', () async {
      int attempts = 0;
      final profile = await service.execute<Map<String, dynamic>>(
        operationName: 'fetchProfile',
        idempotency: OperationIdempotency.readOnly,
        action: () async {
          attempts++;
          if (attempts == 1) {
            throw http.ClientException('ClientException: Connection reset by peer');
          }
          return {'id': 'user-123', 'nome_completo': 'João Silva'};
        },
      );

      expect(profile['nome_completo'], equals('João Silva'));
      expect(attempts, equals(2));
    });

    test('Teste 5 — Fetch Profile falha 3 vezes (interrompe retries após máximo 3 tentativas)', () async {
      int attempts = 0;

      expect(
        () => service.execute<Map<String, dynamic>>(
          operationName: 'fetchProfile',
          idempotency: OperationIdempotency.readOnly,
          action: () async {
            attempts++;
            throw const SocketException('Connection reset');
          },
        ),
        throwsA(isA<SocketException>()),
      );

      await Future.delayed(const Duration(milliseconds: 2500));
      expect(attempts, equals(3));
    });

    test('Teste 6 — Has Consent com falha transitória (retries permitidos por ser READ_ONLY)', () async {
      int attempts = 0;

      final hasConsent = await service.execute<bool>(
        operationName: 'hasConsent',
        idempotency: OperationIdempotency.readOnly,
        action: () async {
          attempts++;
          if (attempts == 1) {
            throw http.ClientException('Software caused connection abort');
          }
          return true;
        },
      );

      expect(hasConsent, isTrue);
      expect(attempts, equals(2));
    });

    test('Teste 7 — Operação NON_IDEMPOTENT com erro transitório (timeout aplicado, retry NÃO executado)', () async {
      int attempts = 0;

      expect(
        () => service.execute<String>(
          operationName: 'registerResident',
          idempotency: OperationIdempotency.nonIdempotentWrite,
          timeout: const Duration(seconds: 20),
          action: () async {
            attempts++;
            throw http.ClientException('Connection reset by peer');
          },
        ),
        throwsA(isA<http.ClientException>()),
      );

      expect(attempts, equals(1));
    });
  });

  group('SupabaseResilienceService - Mensagens Amigáveis Sanitizadas', () {
    test('Mapeia credenciais inválidas para mensagem amigável de e-mail/senha', () {
      final msg = SupabaseResilienceService.getFriendlyErrorMessage(const AuthException('Invalid login credentials'));
      expect(msg, equals('E-mail ou senha incorretos.'));
    });

    test('Mapeia Connection reset para mensagem amigável de conexão sem expor stack trace', () {
      final msg = SupabaseResilienceService.getFriendlyErrorMessage(http.ClientException('Connection reset by peer'));
      expect(msg, equals('Não foi possível conectar ao servidor. Verifique sua conexão e tente novamente.'));
      expect(msg, isNot(contains('ClientException')));
      expect(msg, isNot(contains('Connection reset')));
    });

    test('Mapeia RLS (42501) para mensagem de acesso não autorizado', () {
      final msg = SupabaseResilienceService.getFriendlyErrorMessage(const PostgrestException(message: 'RLS', code: '42501'));
      expect(msg, equals('Acesso não autorizado para esta operação.'));
    });

    test('Mapeia TimeoutException para mensagem amigável de tempo esgotado sem stack trace', () {
      final msg = SupabaseResilienceService.getFriendlyErrorMessage(TimeoutException('Timeout de 20s atingido'));
      expect(msg, equals('Não foi possível conectar ao servidor. Verifique sua conexão e tente novamente.'));
      expect(msg, isNot(contains('TimeoutException')));
    });
  });
}
