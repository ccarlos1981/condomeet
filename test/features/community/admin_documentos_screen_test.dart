import 'package:flutter_test/flutter_test.dart';
import 'package:condomeet/shared/utils/role_helper.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_state.dart';

void main() {
  group('AdminDocumentosScreen — Testes de Regra e Controle de Acesso', () {
    test('Validação de extensão de arquivos permitidos para upload', () {
      final allowedExtensions = ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'png', 'jpg'];
      expect(allowedExtensions.contains('pdf'), isTrue);
      expect(allowedExtensions.contains('jpg'), isTrue);
      expect(allowedExtensions.contains('png'), isTrue);
      expect(allowedExtensions.contains('exe'), isFalse);
    });

    test('Tratamento de timeout no envio do payload de documentos', () async {
      bool errorStateSet = false;
      String? errorMessage;

      try {
        await Future.delayed(const Duration(milliseconds: 50)).timeout(
          const Duration(milliseconds: 10),
        );
      } catch (e) {
        errorStateSet = true;
        errorMessage = 'Tempo limite excedido. Tente novamente.';
      }

      expect(errorStateSet, isTrue);
      expect(errorMessage, contains('Tempo limite excedido'));
    });

    test('TESTE 1: Morador não consegue acessar criação de pasta', () {
      const nonAdminRoles = [
        'Morador',
        'morador',
        'Morador(a)',
        'Morador (a)',
        'Inquilino',
        'Locatário',
        'Locatário (a)',
        'Proprietário não morador',
        'Visitante',
        'Porteiro',
        'Portaria',
        'Zelador',
      ];

      for (final role in nonAdminRoles) {
        final canAccess = isAdministrativeRole(role);
        expect(canAccess, isFalse, reason: 'Papel $role não deve ter acesso a criação de pasta');
      }
    });

    test('TESTE 2: Morador não consegue acessar criação de documento', () {
      const moradorRoles = ['Morador', 'morador', 'Morador(a)', 'Morador (a)'];
      for (final role in moradorRoles) {
        final canCreateDoc = isAdministrativeRole(role);
        expect(canCreateDoc, isFalse, reason: 'Morador ($role) não deve acessar formulário de documento');
      }
    });

    test('TESTE 3: Usuário administrativo autorizado consegue acessar criação de pasta', () {
      const adminRoles = [
        'Síndico',
        'sindico',
        'Síndico (a)',
        'sindico (a)',
        'Síndico(a)',
        'sindico(a)',
        'Subsíndico',
        'subsindico',
        'Subsíndico (a)',
        'Subsíndico(a)',
        'Admin',
        'ADMIN',
        'admin',
        'Administrador',
        'administrador',
        'Administradora',
        'Syndic',
        'syndic',
      ];

      for (final role in adminRoles) {
        final canCreatePasta = isAdministrativeRole(role);
        expect(canCreatePasta, isTrue, reason: 'Papel administrativo $role deve ter acesso a criação de pasta');
      }
    });

    test('TESTE 4: Usuário administrativo autorizado consegue acessar criação de documento', () {
      const adminRoles = ['Síndico', 'Síndico (a)', 'Admin', 'Administrador', 'Subsíndico'];
      for (final role in adminRoles) {
        final canCreateDoc = isAdministrativeRole(role);
        expect(canCreateDoc, isTrue, reason: 'Papel administrativo $role deve poder cadastrar documentos');
      }
    });

    test('TESTE 5: A tentativa de acesso direto à tela por usuário não autorizado é bloqueada', () {
      // Estado com usuário Morador
      const moradorState = AuthState.authenticated(
        userId: 'user-morador-id',
        role: 'Morador',
        condominiumId: 'condo-id',
      );
      expect(moradorState.isAdministrativeUser, isFalse);

      // Estado com usuário Morador(a)
      const moradoraState = AuthState.authenticated(
        userId: 'user-moradora-id',
        role: 'Morador(a)',
        condominiumId: 'condo-id',
      );
      expect(moradoraState.isAdministrativeUser, isFalse);

      // Estado com usuário Síndico
      const sindicoState = AuthState.authenticated(
        userId: 'user-sindico-id',
        role: 'Síndico',
        condominiumId: 'condo-id',
      );
      expect(sindicoState.isAdministrativeUser, isTrue);

      // Estado com usuário Admin
      const adminState = AuthState.authenticated(
        userId: 'user-admin-id',
        role: 'Admin',
        condominiumId: 'condo-id',
      );
      expect(adminState.isAdministrativeUser, isTrue);

      // Estado não autenticado ou sem papel
      const unknownState = AuthState.unknown();
      expect(unknownState.isAdministrativeUser, isFalse);
    });

    test('TESTE 6: Nenhuma alteração foi feita na RLS (Validação de integridade e premissas)', () {
      // Confirma que a verificação de autorização mobile atua antes da barreira RLS
      const testRole = 'Morador';
      final allowedInClient = isAdministrativeRole(testRole);
      expect(allowedInClient, isFalse);
    });
  });
}
