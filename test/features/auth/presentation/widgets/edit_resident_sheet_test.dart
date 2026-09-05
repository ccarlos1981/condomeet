import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/features/auth/presentation/widgets/edit_resident_sheet.dart';
import 'package:condomeet/features/portaria/domain/repositories/resident_repository.dart';

class MockResidentRepository extends Mock implements ResidentRepository {}

void main() {
  late MockResidentRepository mockResidentRepository;

  setUp(() {
    mockResidentRepository = MockResidentRepository();
    final sl = GetIt.instance;
    if (sl.isRegistered<ResidentRepository>()) {
      sl.unregister<ResidentRepository>();
    }
    sl.registerSingleton<ResidentRepository>(mockResidentRepository);
  });

  tearDown(() {
    final sl = GetIt.instance;
    if (sl.isRegistered<ResidentRepository>()) {
      sl.unregister<ResidentRepository>();
    }
  });

  Widget createSheetApp(Resident resident, {VoidCallback? onSaved, EdgeInsets? viewInsets}) {
    return MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(viewInsets: viewInsets ?? EdgeInsets.zero),
          child: Builder(
            builder: (ctx) => Center(
              child: TextButton(
                key: const Key('open_sheet_btn'),
                onPressed: () {
                  EditResidentSheet.show(
                    ctx,
                    resident,
                    '8a544728-e17a-4d9c-a27d-3cb9228bd79e',
                    onSaved ?? () {},
                  );
                },
                child: const Text('OPEN_SHEET'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openSheet(WidgetTester tester, Resident resident, {VoidCallback? onSaved, EdgeInsets? viewInsets}) async {
    await tester.pumpWidget(createSheetApp(resident, onSaved: onSaved, viewInsets: viewInsets));
    await tester.tap(find.byKey(const Key('open_sheet_btn')));
    await tester.pumpAndSettle();
  }

  group('Gate de Homologação UX/UI - EditResidentSheet', () {
    // =========================================================================
    // TESTE 1 — SALVAMENTO COM SUCESSO
    // =========================================================================
    testWidgets('TESTE 1: Salvamento com sucesso fecha modal e executa onSaved()', (tester) async {
      bool onSavedCalled = false;
      final completer = Completer<Result<void>>();

      when(() => mockResidentRepository.updateResidentProfile(
        residentId: any(named: 'residentId'),
        condominiumId: any(named: 'condominiumId'),
        fullName: any(named: 'fullName'),
        email: any(named: 'email'),
        phone: any(named: 'phone'),
        block: any(named: 'block'),
        unit: any(named: 'unit'),
        tipoMorador: any(named: 'tipoMorador'),
        papelSistema: any(named: 'papelSistema'),
      )).thenAnswer((_) => completer.future);

      final resident = Resident(
        id: 'user-123',
        fullName: 'Morador Teste',
        email: 'morador@teste.com',
        phoneNumber: '5531999990001',
        block: 'Bloco A',
        unitNumber: '101',
        status: 'aprovado',
        tipoMorador: 'Proprietário',
        papelSistema: 'Morador',
      );

      await openSheet(tester, resident, onSaved: () {
        onSavedCalled = true;
      });

      // Clica em SALVAR
      await tester.tap(find.text('SALVAR'));
      await tester.pump(); // Inicia o salvamento

      // Confirma que o loading aparece e o botão está desabilitado
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Completa com sucesso
      completer.complete(const Success(null));
      await tester.pumpAndSettle();

      // Confirma que modal fechou
      expect(find.text('Editar Morador'), findsNothing);

      // Confirma que onSaved foi executado
      expect(onSavedCalled, isTrue);
    });

    // =========================================================================
    // TESTE 2 — ERRO DE SALVAMENTO
    // =========================================================================
    testWidgets('TESTE 2: Erro de salvamento mantém modal aberto, dados intactos e exibe alerta inline amigável', (tester) async {
      when(() => mockResidentRepository.updateResidentProfile(
        residentId: any(named: 'residentId'),
        condominiumId: any(named: 'condominiumId'),
        fullName: any(named: 'fullName'),
        email: any(named: 'email'),
        phone: any(named: 'phone'),
        block: any(named: 'block'),
        unit: any(named: 'unit'),
        tipoMorador: any(named: 'tipoMorador'),
        papelSistema: any(named: 'papelSistema'),
      )).thenAnswer((_) async => Failure('PostgrestException: Could not find the \'apto_txt\' column of \'unidades\' in the schema cache, code: PGRST204'));

      final resident = Resident(
        id: 'user-123',
        fullName: 'Cris11',
        email: 'ccarlos1981+11@gmail.com',
        phoneNumber: '31992707070',
        block: '1',
        unitNumber: '5',
        status: 'aprovado',
        tipoMorador: 'Proprietário',
        papelSistema: 'Morador',
      );

      await openSheet(tester, resident);

      // Clica em SALVAR
      await tester.tap(find.text('SALVAR'));
      await tester.pumpAndSettle();

      // 1. Modal permanece aberto e dados permanecem intactos
      expect(find.text('Editar Morador'), findsOneWidget);
      expect(find.text('Cris11'), findsOneWidget);
      expect(find.text('31992707070'), findsOneWidget);

      // 2. Alerta inline aparece
      expect(find.byKey(const Key('edit_resident_error_banner')), findsOneWidget);
      expect(find.text('Não foi possível salvar'), findsOneWidget);

      // 3. Mensagem técnica foi sanitizada para mensagem amigável no alerta inline
      expect(
        find.descendant(
          of: find.byKey(const Key('edit_resident_error_banner')),
          matching: find.text('Não foi possível salvar as alterações. Verifique os dados e tente novamente.'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('PGRST204'), findsNothing);

      // 4. Botão SALVAR volta a ficar disponível (não em loading)
      expect(find.text('SALVAR'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    // =========================================================================
    // TESTE 3 — NOVA TENTATIVA COM SUCESSO
    // =========================================================================
    testWidgets('TESTE 3: Nova tentativa limpa o alerta inline e conclui com sucesso', (tester) async {
      int callCount = 0;
      final retryCompleter = Completer<Result<void>>();

      when(() => mockResidentRepository.updateResidentProfile(
        residentId: any(named: 'residentId'),
        condominiumId: any(named: 'condominiumId'),
        fullName: any(named: 'fullName'),
        email: any(named: 'email'),
        phone: any(named: 'phone'),
        block: any(named: 'block'),
        unit: any(named: 'unit'),
        tipoMorador: any(named: 'tipoMorador'),
        papelSistema: any(named: 'papelSistema'),
      )).thenAnswer((_) {
        callCount++;
        if (callCount == 1) {
          return Future.value(Failure('Falha temporária de rede'));
        }
        return retryCompleter.future;
      });

      final resident = Resident(
        id: 'user-retry',
        fullName: 'Retry User',
        email: 'retry@teste.com',
        block: '1',
        unitNumber: '5',
        status: 'aprovado',
        papelSistema: 'Morador',
      );

      await openSheet(tester, resident);

      // 1ª tentativa -> Retorna erro
      await tester.tap(find.text('SALVAR'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('edit_resident_error_banner')), findsOneWidget);

      // 2ª tentativa -> Dispara e imediatamente limpa o erro anterior
      await tester.tap(find.text('SALVAR'));
      await tester.pump(); // Inicia nova tentativa
      expect(find.byKey(const Key('edit_resident_error_banner')), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Conclui com sucesso
      retryCompleter.complete(const Success(null));
      await tester.pumpAndSettle();

      expect(callCount, 2);
      expect(find.text('Editar Morador'), findsNothing); // Modal fechou
    });

    // =========================================================================
    // TESTE 4 — DUPLO CLIQUE
    // =========================================================================
    testWidgets('TESTE 4: Duplo clique não dispara múltiplas requisições simultâneas', (tester) async {
      final completer = Completer<Result<void>>();
      int invocations = 0;

      when(() => mockResidentRepository.updateResidentProfile(
        residentId: any(named: 'residentId'),
        condominiumId: any(named: 'condominiumId'),
        fullName: any(named: 'fullName'),
        email: any(named: 'email'),
        phone: any(named: 'phone'),
        block: any(named: 'block'),
        unit: any(named: 'unit'),
        tipoMorador: any(named: 'tipoMorador'),
        papelSistema: any(named: 'papelSistema'),
      )).thenAnswer((_) {
        invocations++;
        return completer.future;
      });

      final resident = Resident(
        id: 'user-double-tap',
        fullName: 'Double Tap User',
        email: 'tap@teste.com',
        block: '1',
        unitNumber: '1',
        status: 'aprovado',
        papelSistema: 'Morador',
      );

      await openSheet(tester, resident);

      // 1º toque
      await tester.tap(find.text('SALVAR'));
      await tester.pump();

      // Toques subsequentes durante _isSaving == true
      await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
      await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
      await tester.pump();

      // Apenas 1 invocação deve ter sido realizada
      expect(invocations, 1);

      completer.complete(const Success(null));
      await tester.pumpAndSettle();
    });

    // =========================================================================
    // TESTE 5 — TECLADO ABERTO
    // =========================================================================
    testWidgets('TESTE 5: Alerta inline e layout funcionam perfeitamente com teclado aberto', (tester) async {
      when(() => mockResidentRepository.updateResidentProfile(
        residentId: any(named: 'residentId'),
        condominiumId: any(named: 'condominiumId'),
        fullName: any(named: 'fullName'),
        email: any(named: 'email'),
        phone: any(named: 'phone'),
        block: any(named: 'block'),
        unit: any(named: 'unit'),
        tipoMorador: any(named: 'tipoMorador'),
        papelSistema: any(named: 'papelSistema'),
      )).thenAnswer((_) async => Failure('Erro simulado'));

      final resident = Resident(
        id: 'user-kb',
        fullName: 'Keyboard Test',
        block: '1',
        unitNumber: '1',
        status: 'aprovado',
        papelSistema: 'Morador',
      );

      // Simula teclado do iPhone aberto com 300px de viewInsets.bottom
      await openSheet(tester, resident, viewInsets: const EdgeInsets.only(bottom: 300));

      await tester.tap(find.text('SALVAR'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('edit_resident_error_banner')), findsOneWidget);
      expect(tester.takeException(), isNull); // Sem overflow de layout
    });

    // =========================================================================
    // TESTE 6 — ADMIN (Preservação de regras e valores)
    // =========================================================================
    testWidgets('TESTE 6: Perfil Admin preserva bloco Admin, apto Admin e papel Admin', (tester) async {
      when(() => mockResidentRepository.updateResidentProfile(
        residentId: any(named: 'residentId'),
        condominiumId: any(named: 'condominiumId'),
        fullName: any(named: 'fullName'),
        email: any(named: 'email'),
        phone: any(named: 'phone'),
        block: any(named: 'block'),
        unit: any(named: 'unit'),
        tipoMorador: any(named: 'tipoMorador'),
        papelSistema: any(named: 'papelSistema'),
      )).thenAnswer((_) async => const Success(null));

      final cristiano = Resident(
        id: 'f53ec30c-c512-40b2-b3fc-47523606acd8',
        fullName: 'Cristiano',
        email: 'ccarlos1981+praca@gmail.com',
        phoneNumber: '5531988887777',
        block: 'Admin',
        unitNumber: 'Admin',
        status: 'aprovado',
        tipoMorador: 'Síndico',
        papelSistema: 'Admin',
      );

      await openSheet(tester, cristiano);

      // Confirma valores na UI
      expect(find.text('Administrador'), findsOneWidget);
      expect(find.text('Síndico'), findsOneWidget);
      expect(find.text('Admin'), findsNWidgets(2));

      await tester.tap(find.text('SALVAR'));
      await tester.pumpAndSettle();

      // Confirma que os parâmetros enviados foram preservados
      verify(() => mockResidentRepository.updateResidentProfile(
        residentId: 'f53ec30c-c512-40b2-b3fc-47523606acd8',
        condominiumId: '8a544728-e17a-4d9c-a27d-3cb9228bd79e',
        fullName: 'Cristiano',
        email: 'ccarlos1981+praca@gmail.com',
        phone: '5531988887777',
        block: 'Admin',
        unit: 'Admin',
        tipoMorador: 'Síndico',
        papelSistema: 'Admin',
      )).called(1);
    });

    // =========================================================================
    // TESTE 7 — SÍNDICO
    // =========================================================================
    testWidgets('TESTE 7: Perfil Síndico preserva nível Síndico e parâmetros', (tester) async {
      when(() => mockResidentRepository.updateResidentProfile(
        residentId: any(named: 'residentId'),
        condominiumId: any(named: 'condominiumId'),
        fullName: any(named: 'fullName'),
        email: any(named: 'email'),
        phone: any(named: 'phone'),
        block: any(named: 'block'),
        unit: any(named: 'unit'),
        tipoMorador: any(named: 'tipoMorador'),
        papelSistema: any(named: 'papelSistema'),
      )).thenAnswer((_) async => const Success(null));

      final sindico = Resident(
        id: 'sindico-1',
        fullName: 'Síndico Geral',
        email: 'sindico@condo.com',
        block: 'Bloco A',
        unitNumber: '101',
        status: 'aprovado',
        tipoMorador: 'Proprietário',
        papelSistema: 'Síndico',
      );

      await openSheet(tester, sindico);

      expect(find.text('Síndico'), findsOneWidget);
      expect(find.text('Proprietário'), findsOneWidget);

      await tester.tap(find.text('SALVAR'));
      await tester.pumpAndSettle();

      verify(() => mockResidentRepository.updateResidentProfile(
        residentId: 'sindico-1',
        condominiumId: '8a544728-e17a-4d9c-a27d-3cb9228bd79e',
        fullName: 'Síndico Geral',
        email: 'sindico@condo.com',
        phone: '',
        block: 'Bloco A',
        unit: '101',
        tipoMorador: 'Proprietário',
        papelSistema: 'Síndico',
      )).called(1);
    });

    // =========================================================================
    // TESTE 8 — MORADOR
    // =========================================================================
    testWidgets('TESTE 8: Perfil Morador preserva nível Morador e parâmetros', (tester) async {
      when(() => mockResidentRepository.updateResidentProfile(
        residentId: any(named: 'residentId'),
        condominiumId: any(named: 'condominiumId'),
        fullName: any(named: 'fullName'),
        email: any(named: 'email'),
        phone: any(named: 'phone'),
        block: any(named: 'block'),
        unit: any(named: 'unit'),
        tipoMorador: any(named: 'tipoMorador'),
        papelSistema: any(named: 'papelSistema'),
      )).thenAnswer((_) async => const Success(null));

      final morador = Resident(
        id: 'morador-1',
        fullName: 'Morador Comum',
        email: 'morador@condo.com',
        block: 'Bloco B',
        unitNumber: '202',
        status: 'aprovado',
        tipoMorador: 'Inquilino',
        papelSistema: 'Morador',
      );

      await openSheet(tester, morador);

      await tester.tap(find.text('SALVAR'));
      await tester.pumpAndSettle();

      verify(() => mockResidentRepository.updateResidentProfile(
        residentId: 'morador-1',
        condominiumId: '8a544728-e17a-4d9c-a27d-3cb9228bd79e',
        fullName: 'Morador Comum',
        email: 'morador@condo.com',
        phone: '',
        block: 'Bloco B',
        unit: '202',
        tipoMorador: 'Inquilino',
        papelSistema: 'Morador',
      )).called(1);
    });

    // =========================================================================
    // TESTE 9 — UNIDADE_PERFIL (Preservação de integridade)
    // =========================================================================
    testWidgets('TESTE 9: Alteração de UX não altera o contrato de repositório nem vínculos', (tester) async {
      when(() => mockResidentRepository.updateResidentProfile(
        residentId: any(named: 'residentId'),
        condominiumId: any(named: 'condominiumId'),
        fullName: any(named: 'fullName'),
        email: any(named: 'email'),
        phone: any(named: 'phone'),
        block: any(named: 'block'),
        unit: any(named: 'unit'),
        tipoMorador: any(named: 'tipoMorador'),
        papelSistema: any(named: 'papelSistema'),
      )).thenAnswer((_) async => const Success(null));

      final admin = Resident(
        id: 'admin-safe-id',
        fullName: 'Admin Safe',
        block: 'Admin',
        unitNumber: 'Admin',
        status: 'aprovado',
        papelSistema: 'Admin',
      );

      await openSheet(tester, admin);

      await tester.tap(find.text('SALVAR'));
      await tester.pumpAndSettle();

      // Confirma que é chamado com 'Admin' e 'Admin', acionando a rota segura de repositório
      verify(() => mockResidentRepository.updateResidentProfile(
        residentId: 'admin-safe-id',
        condominiumId: '8a544728-e17a-4d9c-a27d-3cb9228bd79e',
        fullName: 'Admin Safe',
        email: '',
        phone: '',
        block: 'Admin',
        unit: 'Admin',
        tipoMorador: 'Proprietário',
        papelSistema: 'Admin',
      )).called(1);
    });
  });
}
