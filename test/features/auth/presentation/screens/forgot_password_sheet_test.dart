import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_event.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_state.dart';
import 'package:condomeet/features/auth/presentation/screens/forgot_password_sheet.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

void main() {
  late MockAuthBloc mockAuthBloc;

  setUpAll(() {
    registerFallbackValue(const AuthForgotPasswordRequested(email: ''));
    registerFallbackValue(const AuthResetCodeSubmitted(email: '', code: '', newPassword: ''));
  });

  setUp(() {
    mockAuthBloc = MockAuthBloc();
  });

  Widget createWidgetUnderTest({String? email}) {
    return MaterialApp(
      home: Scaffold(
        body: BlocProvider<AuthBloc>.value(
          value: mockAuthBloc,
          child: ForgotPasswordSheet(initialEmail: email),
        ),
      ),
    );
  }

  group('ForgotPasswordSheet — Cooldown & Hardening UX Tests', () {
    testWidgets('1. Step 1: Renderiza campos iniciais e envia solicitação de código', (tester) async {
      when(() => mockAuthBloc.state).thenReturn(const AuthState(status: AuthStatus.unauthenticated));

      await tester.pumpWidget(createWidgetUnderTest(email: 'user@condomeet.com'));
      await tester.pumpAndSettle();

      expect(find.text('Esqueci a Senha'), findsOneWidget);
      expect(find.text('user@condomeet.com'), findsOneWidget);
      expect(find.text('Enviar código via WhatsApp'), findsOneWidget);

      await tester.tap(find.text('Enviar código via WhatsApp'));
      await tester.pump();

      verify(() => mockAuthBloc.add(const AuthForgotPasswordRequested(email: 'user@condomeet.com'))).called(1);
    });

    testWidgets('2. Envio bem-sucedido inicia cooldown de 5 minutos e desabilita botão', (tester) async {
      whenListen(
        mockAuthBloc,
        Stream<AuthState>.fromIterable([
          const AuthState(status: AuthStatus.unauthenticated),
          const AuthState(
            status: AuthStatus.forgotPasswordCodeSent,
            email: 'user@condomeet.com',
            maskedWhatsapp: '***7070',
          ),
        ]),
        initialState: const AuthState(status: AuthStatus.unauthenticated),
      );

      await tester.pumpWidget(createWidgetUnderTest(email: 'user@condomeet.com'));
      await tester.pumpAndSettle();

      // Transicionou para Step 2
      expect(find.text('Verificar Código'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('***7070')),
        findsOneWidget,
      );

      // Botão está desabilitado com o timer de 5:00
      expect(find.text('Enviar novamente em 5:00'), findsOneWidget);

      // Avança 1 segundo
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Enviar novamente em 4:59'), findsOneWidget);

      // Avança 59 segundos
      await tester.pump(const Duration(seconds: 59));
      expect(find.text('Enviar novamente em 4:00'), findsOneWidget);

      // Tenta clicar no botão durante o cooldown -> Não deve emitir evento
      await tester.tap(find.text('Enviar novamente em 4:00'), warnIfMissed: false);
      await tester.pump();

      verifyNever(() => mockAuthBloc.add(any(that: isA<AuthForgotPasswordRequested>())));
    });

    testWidgets('3. Cooldown expira após 300 segundos e reabilita botão', (tester) async {
      whenListen(
        mockAuthBloc,
        Stream<AuthState>.fromIterable([
          const AuthState(status: AuthStatus.unauthenticated),
          const AuthState(
            status: AuthStatus.forgotPasswordCodeSent,
            email: 'user@condomeet.com',
            maskedWhatsapp: '***7070',
          ),
        ]),
        initialState: const AuthState(status: AuthStatus.unauthenticated),
      );

      await tester.pumpWidget(createWidgetUnderTest(email: 'user@condomeet.com'));
      await tester.pumpAndSettle();

      expect(find.text('Enviar novamente em 5:00'), findsOneWidget);

      // Avança 300 segundos
      await tester.pump(const Duration(seconds: 300));

      // Botão deve voltar ao texto original e estar habilitado
      expect(find.text('Não recebeu? Enviar novamente'), findsOneWidget);

      // Clicar agora deve disparar o evento
      await tester.tap(find.text('Não recebeu? Enviar novamente'));
      await tester.pump();

      verify(() => mockAuthBloc.add(const AuthForgotPasswordRequested(email: 'user@condomeet.com'))).called(1);
    });

    testWidgets('4. Dois cliques rápidos no Step 1 não produzem chamadas duplicadas', (tester) async {
      when(() => mockAuthBloc.state).thenReturn(const AuthState(status: AuthStatus.unauthenticated));

      await tester.pumpWidget(createWidgetUnderTest(email: 'user@condomeet.com'));
      await tester.pumpAndSettle();

      final button = find.text('Enviar código via WhatsApp');

      // Primeiro clique
      await tester.tap(button);
      // Segundo clique imediato sem pump intermediário de resolução
      await tester.tap(button, warnIfMissed: false);
      await tester.pump();

      // Somente 1 chamada deve ter sido realizada pois _isLoading tornou-se true
      verify(() => mockAuthBloc.add(const AuthForgotPasswordRequested(email: 'user@condomeet.com'))).called(1);
    });

    testWidgets('5. Falha de envio não inicia cooldown indevido e exibe erro', (tester) async {
      whenListen(
        mockAuthBloc,
        Stream<AuthState>.fromIterable([
          const AuthState(status: AuthStatus.authenticating),
          const AuthState(
            status: AuthStatus.unauthenticated,
            errorMessage: 'Erro ao solicitar código. Tente novamente.',
          ),
        ]),
        initialState: const AuthState(status: AuthStatus.unauthenticated),
      );

      await tester.pumpWidget(createWidgetUnderTest(email: 'user@condomeet.com'));
      await tester.pumpAndSettle();

      // Permanece no Step 1 com a mensagem de erro
      expect(find.text('Esqueci a Senha'), findsOneWidget);
      expect(find.text('Erro ao solicitar código. Tente novamente.'), findsOneWidget);
      expect(find.text('Enviar código via WhatsApp'), findsOneWidget);
    });

    testWidgets('6. Rebuild do widget não reinicia contador indevidamente', (tester) async {
      whenListen(
        mockAuthBloc,
        Stream<AuthState>.fromIterable([
          const AuthState(status: AuthStatus.unauthenticated),
          const AuthState(
            status: AuthStatus.forgotPasswordCodeSent,
            email: 'user@condomeet.com',
            maskedWhatsapp: '***7070',
          ),
        ]),
        initialState: const AuthState(status: AuthStatus.unauthenticated),
      );

      await tester.pumpWidget(createWidgetUnderTest(email: 'user@condomeet.com'));
      await tester.pumpAndSettle();

      // Avança 30 segundos -> 4:30
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Enviar novamente em 4:30'), findsOneWidget);

      // Força rebuild digitando no campo de código
      await tester.enterText(find.byType(TextField).first, '123');
      await tester.pump();

      // O contador deve continuar em 4:30 e não resetar para 5:00
      expect(find.text('Enviar novamente em 4:30'), findsOneWidget);

      // Avança mais 10 segundos
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('Enviar novamente em 4:20'), findsOneWidget);
    });

    testWidgets('7. Dispose cancela timer sem lançar exceções', (tester) async {
      whenListen(
        mockAuthBloc,
        Stream<AuthState>.fromIterable([
          const AuthState(status: AuthStatus.unauthenticated),
          const AuthState(
            status: AuthStatus.forgotPasswordCodeSent,
            email: 'user@condomeet.com',
            maskedWhatsapp: '***7070',
          ),
        ]),
        initialState: const AuthState(status: AuthStatus.unauthenticated),
      );

      await tester.pumpWidget(createWidgetUnderTest(email: 'user@condomeet.com'));
      await tester.pumpAndSettle();

      // Avança 10 segundos
      await tester.pump(const Duration(seconds: 10));

      // Remove widget da árvore (provoca dispose)
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();

      // Não deve lançar erro após dispose
      expect(tester.takeException(), isNull);
    });

    testWidgets('8. Submit de nova senha no Step 2 continua funcionando normalmente', (tester) async {
      whenListen(
        mockAuthBloc,
        Stream<AuthState>.fromIterable([
          const AuthState(status: AuthStatus.unauthenticated),
          const AuthState(
            status: AuthStatus.forgotPasswordCodeSent,
            email: 'user@condomeet.com',
            maskedWhatsapp: '***7070',
          ),
        ]),
        initialState: const AuthState(status: AuthStatus.unauthenticated),
      );

      await tester.pumpWidget(createWidgetUnderTest(email: 'user@condomeet.com'));
      await tester.pumpAndSettle();

      // Preenche código e senhas
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(3));
      await tester.enterText(textFields.at(0), '123456'); // Código
      await tester.enterText(textFields.at(1), '1234');   // Nova senha
      await tester.enterText(textFields.at(2), '1234');   // Confirmar senha

      await tester.tap(find.text('Confirmar Nova Senha'));
      await tester.pump();

      verify(() => mockAuthBloc.add(const AuthResetCodeSubmitted(
        email: 'user@condomeet.com',
        code: '123456',
        newPassword: '1234',
      ))).called(1);
    });
  });
}
