import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_event.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_state.dart';
import 'package:condomeet/core/services/security_service.dart';
import 'package:condomeet/core/services/notification_service.dart';
import 'package:condomeet/features/auth/domain/repositories/auth_repository.dart';
import 'package:condomeet/features/auth/domain/repositories/consent_repository.dart';
import 'package:condomeet/core/errors/result.dart';

class MockAuthRepository extends Mock implements AuthRepository {}
class MockSecurityService extends Mock implements SecurityService {}
class MockConsentRepository extends Mock implements ConsentRepository {}
class MockNotificationService extends Mock implements NotificationService {}
class MockSession extends Mock implements Session {}
class MockUser extends Mock implements User {}

void main() {
  late MockAuthRepository mockAuthRepo;
  late MockSecurityService mockSecurity;
  late MockConsentRepository mockConsent;
  late MockNotificationService mockNotificationService;
  late StreamController<String> tokenRefreshController;

  setUp(() {
    mockAuthRepo = MockAuthRepository();
    mockSecurity = MockSecurityService();
    mockConsent = MockConsentRepository();
    mockNotificationService = MockNotificationService();
    tokenRefreshController = StreamController<String>.broadcast();

    when(() => mockNotificationService.onTokenRefresh)
        .thenAnswer((_) => tokenRefreshController.stream);
    when(() => mockNotificationService.deleteToken())
        .thenAnswer((_) async {});
  });

  tearDown(() {
    tokenRefreshController.close();
  });

  AuthBloc buildBloc() {
    return AuthBloc(
      authRepository: mockAuthRepo,
      securityService: mockSecurity,
      consentRepository: mockConsent,
      notificationService: mockNotificationService,
    );
  }

  group('ETAPA 6F.4-A — Hardening do Ciclo de Vida do FCM Token no Flutter', () {
    // -------------------------------------------------------------------------
    // A. Usuário aprovado + login + token → token gravado
    // -------------------------------------------------------------------------
    test('A. Usuário aprovado + login + token -> token gravado em public.perfil', () async {
      final mockSession = MockSession();
      final mockUser = MockUser();
      when(() => mockSession.user).thenReturn(mockUser);
      when(() => mockUser.id).thenReturn('user-approved-1');
      when(() => mockAuthRepo.currentSession).thenReturn(mockSession);

      when(() => mockAuthRepo.signInWithEmail('morador@mondrian.com', 'senha123'))
          .thenAnswer((_) async {});
      when(() => mockSecurity.saveCredentials(any(), any()))
          .thenAnswer((_) async {});
      when(() => mockAuthRepo.fetchProfile('user-approved-1')).thenAnswer((_) async => {
        'id': 'user-approved-1',
        'condominio_id': 'mondrian-condo-id',
        'nome_completo': 'Morador Aprovado',
        'papel_sistema': 'morador',
        'status_aprovacao': 'aprovado',
        'fcm_token': null,
      });
      when(() => mockConsent.hasConsent(
        userId: 'user-approved-1',
        consentType: any(named: 'consentType'),
      )).thenAnswer((_) async => const Success(true));
      when(() => mockSecurity.getPin()).thenAnswer((_) async => '1234');
      when(() => mockNotificationService.getToken())
          .thenAnswer((_) async => 'fcm-token-morador-1');
      when(() => mockAuthRepo.updateFcmToken('user-approved-1', 'fcm-token-morador-1'))
          .thenAnswer((_) async {});

      final bloc = buildBloc();

      bloc.add(const AuthLoginSubmitted(
        email: 'morador@mondrian.com',
        password: 'senha123',
        rememberMe: true,
      ));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AuthState>((s) => s.status == AuthStatus.authenticating),
          predicate<AuthState>((s) => s.status == AuthStatus.authenticated && s.userId == 'user-approved-1'),
        ]),
      );

      // Aguarda execução assíncrona do _syncFcmToken
      await Future.delayed(const Duration(milliseconds: 50));

      verify(() => mockNotificationService.getToken()).called(1);
      verify(() => mockAuthRepo.updateFcmToken('user-approved-1', 'fcm-token-morador-1')).called(1);

      await bloc.close();
    });

    // -------------------------------------------------------------------------
    // B. Usuário aprovado + reabertura do app → token sincronizado
    // -------------------------------------------------------------------------
    test('B. Usuário aprovado + reabertura do app -> token sincronizado no banco se NULL ou diferente', () async {
      final mockSession = MockSession();
      final mockUser = MockUser();
      when(() => mockSession.user).thenReturn(mockUser);
      when(() => mockUser.id).thenReturn('user-reopen-1');
      when(() => mockAuthRepo.currentSession).thenReturn(mockSession);
      when(() => mockSecurity.isAutoLoginActive()).thenAnswer((_) async => false);
      when(() => mockSecurity.getCredentials()).thenAnswer((_) async => {'email': 'a', 'password': 'b'});

      when(() => mockAuthRepo.fetchProfile('user-reopen-1')).thenAnswer((_) async => {
        'id': 'user-reopen-1',
        'condominio_id': 'mondrian-condo-id',
        'nome_completo': 'Morador Reopen',
        'papel_sistema': 'morador',
        'status_aprovacao': 'aprovado',
        'fcm_token': null, // Banco estava NULL
      });
      when(() => mockConsent.hasConsent(
        userId: 'user-reopen-1',
        consentType: any(named: 'consentType'),
      )).thenAnswer((_) async => const Success(true));
      when(() => mockSecurity.getPin()).thenAnswer((_) async => '1234');
      when(() => mockNotificationService.getToken())
          .thenAnswer((_) async => 'fcm-fresh-token-reopen');
      when(() => mockAuthRepo.updateFcmToken('user-reopen-1', 'fcm-fresh-token-reopen'))
          .thenAnswer((_) async {});

      final bloc = buildBloc();

      bloc.add(const AuthCheckRequested());

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<AuthState>((s) => s.status == AuthStatus.authenticated && s.userId == 'user-reopen-1'),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 50));

      verify(() => mockNotificationService.getToken()).called(1);
      verify(() => mockAuthRepo.updateFcmToken('user-reopen-1', 'fcm-fresh-token-reopen')).called(1);

      await bloc.close();
    });

    // -------------------------------------------------------------------------
    // C. Firebase token refresh → novo token gravado
    // -------------------------------------------------------------------------
    test('C. Firebase onTokenRefresh -> identifica sessão ativa e grava novo token', () async {
      final mockSession = MockSession();
      final mockUser = MockUser();
      when(() => mockSession.user).thenReturn(mockUser);
      when(() => mockUser.id).thenReturn('user-session-refresh');
      when(() => mockAuthRepo.currentSession).thenReturn(mockSession);

      when(() => mockAuthRepo.updateFcmToken('user-session-refresh', 'newly-rotated-fcm-token'))
          .thenAnswer((_) async {});

      final bloc = buildBloc();

      // Emite novo token no stream oficial onTokenRefresh
      tokenRefreshController.add('newly-rotated-fcm-token');

      await Future.delayed(const Duration(milliseconds: 50));

      verify(() => mockAuthRepo.updateFcmToken('user-session-refresh', 'newly-rotated-fcm-token')).called(1);

      await bloc.close();
    });

    // -------------------------------------------------------------------------
    // D. Logout → token removido do perfil anterior e deletado no Firebase
    // -------------------------------------------------------------------------
    test('D. Logout -> limpa public.perfil.fcm_token antes do signOut e deleta token no Firebase', () async {
      final mockSession = MockSession();
      final mockUser = MockUser();
      when(() => mockSession.user).thenReturn(mockUser);
      when(() => mockUser.id).thenReturn('user-logging-out');
      when(() => mockAuthRepo.currentSession).thenReturn(mockSession);

      when(() => mockAuthRepo.clearFcmToken('user-logging-out')).thenAnswer((_) async {});
      when(() => mockNotificationService.deleteToken()).thenAnswer((_) async {});
      when(() => mockSecurity.setAutoLoginActive(false)).thenAnswer((_) async {});
      when(() => mockAuthRepo.signOut()).thenAnswer((_) async {});

      final bloc = buildBloc();

      bloc.add(const AuthLogoutRequested());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AuthState>((s) => s.status == AuthStatus.unauthenticated),
        ]),
      );

      // Ordem estrita: clearFcmToken deve ocorrer antes de signOut!
      verifyInOrder([
        () => mockAuthRepo.clearFcmToken('user-logging-out'),
        () => mockNotificationService.deleteToken(),
        () => mockSecurity.setAutoLoginActive(false),
        () => mockAuthRepo.signOut(),
      ]);

      await bloc.close();
    });

    // -------------------------------------------------------------------------
    // E. Troca de usuário no mesmo aparelho
    // -------------------------------------------------------------------------
    test('E. Troca de usuário -> Perfil A limpo no logout, Perfil B recebe novo token', () async {
      // Passo 1: Usuário A faz logout
      final mockSessionA = MockSession();
      final mockUserA = MockUser();
      when(() => mockSessionA.user).thenReturn(mockUserA);
      when(() => mockUserA.id).thenReturn('user-A');
      when(() => mockAuthRepo.currentSession).thenReturn(mockSessionA);

      when(() => mockAuthRepo.clearFcmToken('user-A')).thenAnswer((_) async {});
      when(() => mockNotificationService.deleteToken()).thenAnswer((_) async {});
      when(() => mockSecurity.setAutoLoginActive(false)).thenAnswer((_) async {});
      when(() => mockAuthRepo.signOut()).thenAnswer((_) async {});

      final bloc = buildBloc();

      bloc.add(const AuthLogoutRequested());
      await expectLater(
        bloc.stream,
        emitsInOrder([predicate<AuthState>((s) => s.status == AuthStatus.unauthenticated)]),
      );
      verify(() => mockAuthRepo.clearFcmToken('user-A')).called(1);

      // Passo 2: Usuário B faz login no mesmo aparelho
      final mockSessionB = MockSession();
      final mockUserB = MockUser();
      when(() => mockSessionB.user).thenReturn(mockUserB);
      when(() => mockUserB.id).thenReturn('user-B');
      when(() => mockAuthRepo.currentSession).thenReturn(mockSessionB);

      when(() => mockAuthRepo.signInWithEmail('userB@mondrian.com', 'senhaB')).thenAnswer((_) async {});
      when(() => mockSecurity.clearCredentials()).thenAnswer((_) async {});
      when(() => mockAuthRepo.fetchProfile('user-B')).thenAnswer((_) async => {
        'id': 'user-B',
        'condominio_id': 'mondrian-condo-id',
        'nome_completo': 'Usuário B',
        'papel_sistema': 'morador',
        'status_aprovacao': 'aprovado',
      });
      when(() => mockConsent.hasConsent(userId: 'user-B', consentType: any(named: 'consentType')))
          .thenAnswer((_) async => const Success(true));
      when(() => mockSecurity.getPin()).thenAnswer((_) async => '9999');
      when(() => mockNotificationService.getToken()).thenAnswer((_) async => 'fcm-token-user-B');
      when(() => mockAuthRepo.updateFcmToken('user-B', 'fcm-token-user-B')).thenAnswer((_) async {});

      bloc.add(const AuthLoginSubmitted(
        email: 'userB@mondrian.com',
        password: 'senhaB',
        rememberMe: false,
      ));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AuthState>((s) => s.status == AuthStatus.authenticating),
          predicate<AuthState>((s) => s.status == AuthStatus.authenticated && s.userId == 'user-B'),
        ]),
      );

      await Future.delayed(const Duration(milliseconds: 50));

      // Garante que User B recebeu seu token e User A nunca recebeu o token de B
      verify(() => mockAuthRepo.updateFcmToken('user-B', 'fcm-token-user-B')).called(1);
      verifyNever(() => mockAuthRepo.updateFcmToken('user-A', any()));

      await bloc.close();
    });

    // -------------------------------------------------------------------------
    // F. Usuário pendente → não se torna elegível para Push (token NÃO gravado)
    // -------------------------------------------------------------------------
    test('F. Usuário pendente -> não sincroniza token e emite pendingApproval', () async {
      final mockSession = MockSession();
      final mockUser = MockUser();
      when(() => mockSession.user).thenReturn(mockUser);
      when(() => mockUser.id).thenReturn('user-pendente-1');
      when(() => mockAuthRepo.currentSession).thenReturn(mockSession);

      when(() => mockAuthRepo.signInWithEmail('pendente@mondrian.com', 'senha123'))
          .thenAnswer((_) async {});
      when(() => mockSecurity.saveCredentials(any(), any())).thenAnswer((_) async {});
      when(() => mockAuthRepo.fetchProfile('user-pendente-1')).thenAnswer((_) async => {
        'id': 'user-pendente-1',
        'condominio_id': 'mondrian-condo-id',
        'nome_completo': 'Morador Em Análise',
        'papel_sistema': 'morador',
        'status_aprovacao': 'pendente', // PENDENTE!
      });

      final bloc = buildBloc();

      bloc.add(const AuthLoginSubmitted(
        email: 'pendente@mondrian.com',
        password: 'senha123',
        rememberMe: true,
      ));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AuthState>((s) => s.status == AuthStatus.authenticating),
          predicate<AuthState>((s) => s.status == AuthStatus.pendingApproval && s.userId == 'user-pendente-1'),
        ]),
      );

      await Future.delayed(const Duration(milliseconds: 50));

      // PENDENTE NÃO PODE REGISTRAR TOKEN!
      verifyNever(() => mockNotificationService.getToken());
      verifyNever(() => mockAuthRepo.updateFcmToken(any(), any()));

      await bloc.close();
    });

    // -------------------------------------------------------------------------
    // G. Pendente posteriormente aprovado → token sincronizado na detecção
    // -------------------------------------------------------------------------
    test('G. Usuário pendente que foi aprovado -> sincroniza token ao detectar aprovação via AuthCheckRequested', () async {
      final mockSession = MockSession();
      final mockUser = MockUser();
      when(() => mockSession.user).thenReturn(mockUser);
      when(() => mockUser.id).thenReturn('user-recem-aprovado');
      when(() => mockAuthRepo.currentSession).thenReturn(mockSession);
      when(() => mockSecurity.isAutoLoginActive()).thenAnswer((_) async => false);
      when(() => mockSecurity.getCredentials()).thenAnswer((_) async => {'email': 'x', 'password': 'y'});

      // Síndico aprovou no web-app! status agora é 'aprovado'
      when(() => mockAuthRepo.fetchProfile('user-recem-aprovado')).thenAnswer((_) async => {
        'id': 'user-recem-aprovado',
        'condominio_id': 'mondrian-condo-id',
        'nome_completo': 'Morador Liberado',
        'papel_sistema': 'morador',
        'status_aprovacao': 'aprovado',
        'fcm_token': null,
      });
      when(() => mockConsent.hasConsent(
        userId: 'user-recem-aprovado',
        consentType: any(named: 'consentType'),
      )).thenAnswer((_) async => const Success(true));
      when(() => mockSecurity.getPin()).thenAnswer((_) async => '1234');
      when(() => mockNotificationService.getToken())
          .thenAnswer((_) async => 'fcm-token-recem-aprovado');
      when(() => mockAuthRepo.updateFcmToken('user-recem-aprovado', 'fcm-token-recem-aprovado'))
          .thenAnswer((_) async {});

      final bloc = buildBloc();

      // Dispara verificação de status (ex: usuário clicou "Verificar Aprovação" ou pull-to-refresh)
      bloc.add(const AuthCheckRequested());

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<AuthState>((s) => s.status == AuthStatus.authenticated && s.userId == 'user-recem-aprovado'),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 50));

      verify(() => mockNotificationService.getToken()).called(1);
      verify(() => mockAuthRepo.updateFcmToken('user-recem-aprovado', 'fcm-token-recem-aprovado')).called(1);

      await bloc.close();
    });

    // -------------------------------------------------------------------------
    // Permissão Negada → App não quebra, não inventa token
    // -------------------------------------------------------------------------
    test('Permissão negada: getToken retorna null -> app autentica normalmente sem gravar token', () async {
      final mockSession = MockSession();
      final mockUser = MockUser();
      when(() => mockSession.user).thenReturn(mockUser);
      when(() => mockUser.id).thenReturn('user-sem-permissao');
      when(() => mockAuthRepo.currentSession).thenReturn(mockSession);

      when(() => mockAuthRepo.signInWithEmail('sempermissao@mondrian.com', 'senha123'))
          .thenAnswer((_) async {});
      when(() => mockSecurity.saveCredentials(any(), any())).thenAnswer((_) async {});
      when(() => mockAuthRepo.fetchProfile('user-sem-permissao')).thenAnswer((_) async => {
        'id': 'user-sem-permissao',
        'condominio_id': 'mondrian-condo-id',
        'nome_completo': 'Morador Sem Notif',
        'papel_sistema': 'morador',
        'status_aprovacao': 'aprovado',
      });
      when(() => mockConsent.hasConsent(
        userId: 'user-sem-permissao',
        consentType: any(named: 'consentType'),
      )).thenAnswer((_) async => const Success(true));
      when(() => mockSecurity.getPin()).thenAnswer((_) async => '1234');

      // Permissão negada pelo SO -> getToken() retorna null
      when(() => mockNotificationService.getToken()).thenAnswer((_) async => null);

      final bloc = buildBloc();

      bloc.add(const AuthLoginSubmitted(
        email: 'sempermissao@mondrian.com',
        password: 'senha123',
        rememberMe: true,
      ));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<AuthState>((s) => s.status == AuthStatus.authenticating),
          predicate<AuthState>((s) => s.status == AuthStatus.authenticated && s.userId == 'user-sem-permissao'),
        ]),
      );

      await Future.delayed(const Duration(milliseconds: 50));

      verify(() => mockNotificationService.getToken()).called(1);
      verifyNever(() => mockAuthRepo.updateFcmToken(any(), any()));

      await bloc.close();
    });
  });
}
