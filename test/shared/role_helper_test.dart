import 'package:flutter_test/flutter_test.dart';
import 'package:condomeet/shared/utils/role_helper.dart';

void main() {
  group('RoleHelper Tests', () {
    group('isAdministrativeRole', () {
      test('reconhece Admin e suas variações de caixa e termo', () {
        expect(isAdministrativeRole('Admin'), isTrue);
        expect(isAdministrativeRole('admin'), isTrue);
        expect(isAdministrativeRole('ADMIN'), isTrue);
        expect(isAdministrativeRole('administrador'), isTrue);
        expect(isAdministrativeRole('administradora'), isTrue);
        expect(isAdministrativeRole('Administrador'), isTrue);
      });

      test('reconhece Síndico e variações com acento/gênero', () {
        expect(isAdministrativeRole('Síndico'), isTrue);
        expect(isAdministrativeRole('sindico'), isTrue);
        expect(isAdministrativeRole('SÍNDICO'), isTrue);
        expect(isAdministrativeRole('Síndico (a)'), isTrue);
        expect(isAdministrativeRole('sindico (a)'), isTrue);
        expect(isAdministrativeRole('Síndico(a)'), isTrue);
      });

      test('reconhece Subsíndico e variações', () {
        expect(isAdministrativeRole('Subsíndico'), isTrue);
        expect(isAdministrativeRole('subsindico'), isTrue);
        expect(isAdministrativeRole('Subsíndico (a)'), isTrue);
        expect(isAdministrativeRole('sub_sindico'), isTrue);
      });

      test('bloqueia estritamente Morador e variações residenciais', () {
        expect(isAdministrativeRole('Morador'), isFalse);
        expect(isAdministrativeRole('morador'), isFalse);
        expect(isAdministrativeRole('Morador(a)'), isFalse);
        expect(isAdministrativeRole('Inquilino'), isFalse);
        expect(isAdministrativeRole('Inquilino (a)'), isFalse);
        expect(isAdministrativeRole('Proprietário'), isFalse);
        expect(isAdministrativeRole('Proprietário (a)'), isFalse);
        expect(isAdministrativeRole('Cônjuge'), isFalse);
        expect(isAdministrativeRole('Dependente'), isFalse);
        expect(isAdministrativeRole('Família'), isFalse);
      });

      test('bloqueia estritamente Porteiro, Portaria e Zelador', () {
        expect(isAdministrativeRole('Porteiro'), isFalse);
        expect(isAdministrativeRole('porteiro'), isFalse);
        expect(isAdministrativeRole('Portaria'), isFalse);
        expect(isAdministrativeRole('Zelador'), isFalse);
        expect(isAdministrativeRole('Limpeza'), isFalse);
        expect(isAdministrativeRole('Funcionário'), isFalse);
        expect(isAdministrativeRole('Visitante Frequente'), isFalse);
      });

      test('retorna false para valores nulos ou vazios', () {
        expect(isAdministrativeRole(null), isFalse);
        expect(isAdministrativeRole(''), isFalse);
        expect(isAdministrativeRole('   '), isFalse);
      });
    });

    group('isMasterRole', () {
      test('reconhece Master e SuperAdmin', () {
        expect(isMasterRole('master'), isTrue);
        expect(isMasterRole('Master'), isTrue);
        expect(isMasterRole('superadmin'), isTrue);
        expect(isMasterRole('SuperAdmin'), isTrue);
        expect(isMasterRole('super_admin'), isTrue);
      });

      test('garante que Admin local NÃO é Master global', () {
        expect(isMasterRole('Admin'), isFalse);
        expect(isMasterRole('admin'), isFalse);
        expect(isMasterRole('ADMIN'), isFalse);
        expect(isMasterRole('administrador'), isFalse);
        expect(isMasterRole('Síndico'), isFalse);
        expect(isMasterRole('Morador'), isFalse);
      });
    });

    group('formatRoleName', () {
      test('formata Admin para rótulo visual Administrador', () {
        expect(formatRoleName('Admin'), equals('Administrador'));
        expect(formatRoleName('admin'), equals('Administrador'));
        expect(formatRoleName('ADMIN'), equals('Administrador'));
      });

      test('preserva demais papéis', () {
        expect(formatRoleName('Síndico'), equals('Síndico'));
        expect(formatRoleName('Subsíndico'), equals('Subsíndico'));
        expect(formatRoleName('Porteiro'), equals('Porteiro'));
        expect(formatRoleName('Morador'), equals('Morador'));
        expect(formatRoleName(null), equals('Morador'));
      });
    });
  });
}
