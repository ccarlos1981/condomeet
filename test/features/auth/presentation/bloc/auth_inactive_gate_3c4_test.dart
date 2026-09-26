import 'package:flutter_test/flutter_test.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_state.dart';
import 'package:condomeet/core/navigation/app_router.dart';

void main() {
  group('Gate 3C.4 - Flutter Inactive Account Contract Tests', () {
    test('Teste J & Contrato: AuthState.inactiveAccount possui status inactiveAccount e profileStatus inativo', () {
      const state = AuthState.inactiveAccount(
        userId: 'user-inactive-123',
        userName: 'Morador Inativo Teste',
        condominiumId: 'condo-456',
        role: 'Morador',
      );

      expect(state.status, AuthStatus.inactiveAccount);
      expect(state.userId, 'user-inactive-123');
      expect(state.userName, 'Morador Inativo Teste');
      expect(state.condominiumId, 'condo-456');
      expect(state.role, 'Morador');
      expect(state.profileStatus, 'inativo');
      expect(state.status != AuthStatus.pendingApproval, isTrue, reason: 'Inativo NUNCA deve ser tratado como pendingApproval');
      expect(state.status != AuthStatus.authenticated, isTrue, reason: 'Inativo NUNCA deve ser autenticado diretamente');
    });

    test('Teste G, H, I: Distinção semântica estrita entre aprovado, pendente, bloqueado e inativo', () {
      const stateAprovado = AuthState.authenticated(userId: 'u1', profileStatus: 'aprovado');
      const statePendente = AuthState.pendingApproval(userId: 'u2');
      const stateInativo = AuthState.inactiveAccount(userId: 'u3');

      expect(stateAprovado.status, AuthStatus.authenticated);
      expect(statePendente.status, AuthStatus.pendingApproval);
      expect(stateInativo.status, AuthStatus.inactiveAccount);

      expect(stateInativo.status, isNot(equals(statePendente.status)));
      expect(stateInativo.status, isNot(equals(stateAprovado.status)));
    });

    test('Roteamento Canônico: AppRouter.getInitialRoute direciona inactiveAccount para /inactive-account', () {
      const stateInativo = AuthState.inactiveAccount(userId: 'u-123');
      final route = AppRouter.getInitialRoute(stateInativo);

      expect(route, '/inactive-account');
    });

    test('Rotas Registradas: AppRouter.getRoutes contém /inactive-account', () {
      const stateInativo = AuthState.inactiveAccount(userId: 'u-123');
      final routes = AppRouter.getRoutes(stateInativo);

      expect(routes.containsKey('/inactive-account'), isTrue);
    });
  });
}
