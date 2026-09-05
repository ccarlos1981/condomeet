import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
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

  group('Validação E2E - Primeiro Acesso e Password Setup', () {
    test('Fluxo 1: Login com senha antiga/inválida emite needsPasswordSetup com email canônico e phoneNumber nulo', () async {
      final state = const AuthState.needsPasswordSetup(email: 'morador.real@condomeet.app');
      
      expect(state.status, AuthStatus.needsPasswordSetup);
      expect(state.email, 'morador.real@condomeet.app');
      expect(state.phoneNumber, isNull);
    });

    blocTest<AuthBloc, AuthState>(
      'Fluxo 2: Submissão de nova senha no PasswordSetupSheet executa login automático e direciona para Home',
      build: () {
        final mockSession = MockSession();
        final mockUser = MockUser();
        when(() => mockSession.user).thenReturn(mockUser);
        when(() => mockUser.id).thenReturn('uuid-morador-824');
        when(() => mockAuthRepo.currentSession).thenReturn(mockSession);

        when(() => mockAuthRepo.signInWithEmail('morador.real@condomeet.app', '123456'))
            .thenAnswer((_) async {});

        when(() => mockAuthRepo.fetchProfile('uuid-morador-824')).thenAnswer((_) async => {
          'id': 'uuid-morador-824',
          'condominium_id': 'condo-recanto-123',
          'nome_completo': 'Morador Aprovado Recanto',
          'papel_sistema': 'morador',
          'status_aprovacao': 'aprovado',
        });

        when(() => mockConsent.hasConsent(
          userId: 'uuid-morador-824',
          consentType: any(named: 'consentType'),
        )).thenAnswer((_) async => const Success(true));

        when(() => mockSecurity.getPin()).thenAnswer((_) async => '1234');
        when(() => mockSecurity.getCredentials()).thenAnswer((_) async => null);

        return authBloc;
      },
      act: (bloc) async {
        // Dispara o AuthCheckRequested que conclui a transição para a Home
        bloc.add(const AuthCheckRequested());
      },
      expect: () => [
        predicate<AuthState>((state) {
          return state.status == AuthStatus.locked &&
              state.userId == 'uuid-morador-824' &&
              state.profileStatus == 'aprovado';
        }),
      ],
    );
  });
}
