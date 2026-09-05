import 'package:flutter_test/flutter_test.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_state.dart';

void main() {
  group('AuthState - Contrato Canônico e Integridade de Campos', () {
    test('Critério 1: needsPasswordSetup preenche email e mantém phoneNumber estritamente nulo', () {
      const state = AuthState.needsPasswordSetup(email: 'morador@teste.com');

      expect(state.status, AuthStatus.needsPasswordSetup);
      expect(state.email, 'morador@teste.com');
      expect(state.phoneNumber, isNull, reason: 'phoneNumber NUNCA deve receber cópia do e-mail');
      expect(state.props.contains('morador@teste.com'), isTrue);
    });

    test('Critério 1.1: forgotPasswordCodeSent preenche email, maskedWhatsapp e mantém phoneNumber nulo', () {
      const state = AuthState.forgotPasswordCodeSent(
        email: 'morador@teste.com',
        maskedWhatsapp: '***1234',
      );

      expect(state.status, AuthStatus.forgotPasswordCodeSent);
      expect(state.email, 'morador@teste.com');
      expect(state.maskedWhatsapp, '***1234');
      expect(state.phoneNumber, isNull, reason: 'phoneNumber deve ser nulo no fluxo de reset por email');
    });

    test('Critério 1.2: copyWith preserva e atualiza o campo email canônico', () {
      const state = AuthState(
        status: AuthStatus.unauthenticated,
        email: 'inicial@teste.com',
      );

      final updated = state.copyWith(email: 'novo@teste.com');
      expect(updated.email, 'novo@teste.com');
      expect(updated.phoneNumber, isNull);

      final sameEmail = updated.copyWith(status: AuthStatus.authenticating);
      expect(sameEmail.email, 'novo@teste.com');
      expect(sameEmail.status, AuthStatus.authenticating);
    });

    test('Critério 1.3: Igualdade Equatable considera o campo email', () {
      const state1 = AuthState(status: AuthStatus.needsPasswordSetup, email: 'a@teste.com');
      const state2 = AuthState(status: AuthStatus.needsPasswordSetup, email: 'a@teste.com');
      const state3 = AuthState(status: AuthStatus.needsPasswordSetup, email: 'b@teste.com');

      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));
    });
  });
}
