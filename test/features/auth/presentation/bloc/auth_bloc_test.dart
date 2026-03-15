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

  group('AuthBloc - Epic 1 Lifecycle (Refactored)', () {
    test('Initial state is unknown', () {
      expect(authBloc.state.status, AuthStatus.unknown);
    });

    blocTest<AuthBloc, AuthState>(
      'emits unauthenticated when no session exists',
      build: () {
        when(() => mockAuthRepo.currentSession).thenReturn(null);
        return authBloc;
      },
      act: (bloc) => bloc.add(AuthCheckRequested()),
      expect: () => [
        predicate<AuthState>((state) => state.status == AuthStatus.unauthenticated),
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
          'full_name': 'Test User',
          'role': 'resident',
          'status': 'active'
        });

        when(() => mockConsent.hasConsent(
          userId: 'uuid-123',
          consentType: any(named: 'consentType'),
        )).thenAnswer((_) async => const Success(true));

        when(() => mockSecurity.getPin()).thenAnswer((_) async => 'hashed-pin');

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

class MockSession extends Mock implements Session {}
class MockUser extends Mock implements User {}
