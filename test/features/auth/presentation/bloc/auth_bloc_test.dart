import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_event.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_state.dart';
import 'package:condomeet/core/services/security_service.dart';
import 'package:condomeet/features/auth/domain/repositories/auth_repository.dart';
import 'package:condomeet/features/auth/domain/repositories/consent_repository.dart';
import 'package:condomeet/core/errors/result.dart';

class MockAuthRepository extends Mock implements AuthRepository {}
class MockSecurityService extends Mock implements SecurityService {}
class MockConsentRepository extends Mock implements ConsentRepository {}
class MockSession extends Mock implements Session {}
class MockUser extends Mock implements User {}

void main() {
  late AuthBloc authBloc;
  late MockAuthRepository mockAuthRepo;
  late MockSecurityService mockSecurity;
  late MockConsentRepository mockConsent;

  setUp(() {
    mockAuthRepo = MockAuthRepository();
    mockSecurity = MockSecurityService();
    mockConsent = MockConsentRepository();

    authBloc = AuthBloc(
      authRepository: mockAuthRepo,
      securityService: mockSecurity,
      consentRepository: mockConsent,
    );
  });

  tearDown(() {
    authBloc.close();
  });

  group('AuthBloc - Ciclo de Vida e Resiliência de Login', () {
    test('Estado inicial é unknown', () {
      expect(authBloc.state.status, AuthStatus.unknown);
    });

    blocTest<AuthBloc, AuthState>(
      'Emite unauthenticated quando nenhuma sessão existe',
      build: () {
        when(() => mockAuthRepo.currentSession).thenReturn(null);
        when(() => mockSecurity.isAutoLoginActive()).thenAnswer((_) async => false);
        return authBloc;
      },
      act: (bloc) => bloc.add(AuthCheckRequested()),
      expect: () => [
        predicate<AuthState>((state) => state.status == AuthStatus.unauthenticated),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'CENÁRIO DO BUG ORIGINAL: signInWithPassword = SUCESSO + fetchProfile = Connection reset -> Mantém sessão e exibe msg amigável de rede',
      build: () {
        final mockSession = MockSession();
        final mockUser = MockUser();
        when(() => mockSession.user).thenReturn(mockUser);
        when(() => mockUser.id).thenReturn('uuid-user-123');

        when(() => mockAuthRepo.signInWithEmail('user@test.com', 'pass123')).thenAnswer((_) async {});
        when(() => mockSecurity.saveCredentials('user@test.com', 'pass123')).thenAnswer((_) async {});
        when(() => mockAuthRepo.currentSession).thenReturn(mockSession);
        
        // Simula Connection reset no fetchProfile após autenticação bem-sucedida
        when(() => mockAuthRepo.fetchProfile('uuid-user-123')).thenThrow(
          http.ClientException('ClientException: Connection reset by peer'),
        );

        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthLoginSubmitted(
        email: 'user@test.com',
        password: 'pass123',
        rememberMe: true,
      )),
      expect: () => [
        predicate<AuthState>((state) => state.status == AuthStatus.authenticating),
        predicate<AuthState>((state) {
          return state.status == AuthStatus.unauthenticated &&
              state.errorMessage == 'Não foi possível conectar ao servidor. Verifique sua conexão e tente novamente.' &&
              state.errorMessage != 'E-mail ou senha incorretos.';
        }),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'Senha incorreta no signInWithEmail -> Emite mensagem de erro de credenciais sem tentar carregar perfil',
      build: () {
        when(() => mockAuthRepo.signInWithEmail('user@test.com', 'wrongpass')).thenThrow(
          const AuthException('Invalid login credentials'),
        );
        when(() => mockSecurity.clearCredentials()).thenAnswer((_) async {});

        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthLoginSubmitted(
        email: 'user@test.com',
        password: 'wrongpass',
        rememberMe: false,
      )),
      expect: () => [
        predicate<AuthState>((state) => state.status == AuthStatus.authenticating),
        predicate<AuthState>((state) {
          return state.status == AuthStatus.unauthenticated &&
              state.errorMessage == 'E-mail ou senha incorretos.';
        }),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits locked when session exists AND PIN is set but not session-unlocked',
      build: () {
        final mockSession = MockSession();
        final mockUser = MockUser();
        when(() => mockSession.user).thenReturn(mockUser);
        when(() => mockUser.id).thenReturn('uuid-123');
        when(() => mockAuthRepo.currentSession).thenReturn(mockSession);

        when(() => mockAuthRepo.fetchProfile('uuid-123')).thenAnswer((_) async => {
          'id': 'uuid-123',
          'condominium_id': 'condo-1',
          'nome_completo': 'Test User',
          'papel_sistema': 'resident',
          'status_aprovacao': 'aprovado'
        });

        when(() => mockConsent.hasConsent(
          userId: 'uuid-123',
          consentType: any(named: 'consentType'),
        )).thenAnswer((_) async => const Success(true));

        when(() => mockSecurity.getPin()).thenAnswer((_) async => 'hashed-pin');
        when(() => mockSecurity.getCredentials()).thenAnswer((_) async => null);

        return authBloc;
      },
      act: (bloc) => bloc.add(AuthCheckRequested()),
      expect: () => [
        predicate<AuthState>((state) {
          return state.status == AuthStatus.locked &&
              state.userId == 'uuid-123' &&
              state.isUnlocked == false;
        }),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits authenticated when AuthPinUnlocked is received',
      build: () => authBloc,
      seed: () => const AuthState(status: AuthStatus.locked, userId: 'uuid-123'),
      act: (bloc) => bloc.add(AuthPinUnlocked()),
      expect: () => [
        predicate<AuthState>((state) {
          return state.status == AuthStatus.authenticated &&
              state.isUnlocked == true;
        }),
      ],
    );
  });
}
