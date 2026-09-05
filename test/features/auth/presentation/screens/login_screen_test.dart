import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:condomeet/core/services/security_service.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_event.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_state.dart';
import 'package:condomeet/features/auth/presentation/screens/login_screen.dart';
import 'package:condomeet/features/auth/presentation/screens/password_setup_sheet.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}
class MockSecurityService extends Mock implements SecurityService {}

void main() {
  late MockAuthBloc mockAuthBloc;
  late MockSecurityService mockSecurityService;

  setUp(() {
    mockAuthBloc = MockAuthBloc();
    mockSecurityService = MockSecurityService();

    final sl = GetIt.instance;
    if (sl.isRegistered<SecurityService>()) {
      sl.unregister<SecurityService>();
    }
    sl.registerSingleton<SecurityService>(mockSecurityService);
    when(() => mockSecurityService.getCredentials()).thenAnswer((_) async => null);
  });

  tearDown(() {
    final sl = GetIt.instance;
    if (sl.isRegistered<SecurityService>()) {
      sl.unregister<SecurityService>();
    }
  });

  testWidgets('Critério 4: LoginScreen abre PasswordSetupSheet quando recebe status needsPasswordSetup com email e phoneNumber nulo', (tester) async {
    // 1. Inicia com estado não autenticado
    whenListen(
      mockAuthBloc,
      Stream<AuthState>.fromIterable([
        const AuthState(status: AuthStatus.unauthenticated),
        const AuthState(
          status: AuthStatus.needsPasswordSetup,
          email: 'morador@teste.com',
          phoneNumber: null, // EXACT Causa Raiz: phoneNumber é nulo
        ),
      ]),
      initialState: const AuthState(status: AuthStatus.unauthenticated),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AuthBloc>.value(
          value: mockAuthBloc,
          child: const LoginScreen(),
        ),
      ),
    );

    // Aguarda o listener disparar e a animação do ModalBottomSheet concluir
    await tester.pumpAndSettle();

    // 2. Validações Mandatórias:
    // O modal PasswordSetupSheet DEVE estar presente na árvore de widgets
    expect(find.byType(PasswordSetupSheet), findsOneWidget);
    expect(find.text('Atualize sua senha'), findsOneWidget);
    expect(find.text('Nova senha (somente números)'), findsOneWidget);
    expect(find.text('Confirmar senha'), findsOneWidget);
  });
}
