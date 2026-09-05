import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:condomeet/core/design_system/app_colors.dart';

void main() {
  group('Self Registration Mobile Validation - UX/UI', () {
    Widget createTestApp({
      required Size screenSize,
      required EdgeInsets viewPadding,
    }) {
      return MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: screenSize,
            viewPadding: viewPadding,
            padding: viewPadding,
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TestRegistrationForm(),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('1. Full validation on Android Mobile (360x800 with 48px system nav bar)', (WidgetTester tester) async {
      final binding = tester.binding;
      binding.platformDispatcher.implicitView?.physicalSize = const Size(1080, 2400);
      binding.platformDispatcher.implicitView?.devicePixelRatio = 3.0;

      addTearDown(() {
        binding.platformDispatcher.implicitView?.resetPhysicalSize();
        binding.platformDispatcher.implicitView?.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp(
        screenSize: const Size(360, 800),
        viewPadding: const EdgeInsets.only(bottom: 48, top: 24),
      ));
      await tester.pumpAndSettle();

      // Verify fields are present
      expect(find.text('Perfil de Usuário'), findsOneWidget);
      expect(find.text('Tipo de Usuário'), findsOneWidget);
      expect(find.text('Morador(a)'), findsOneWidget);
      expect(find.text('Proprietário (a)'), findsOneWidget);

      // --- PASSO 1 a 4: Abrir Perfil de Usuário e fazer scroll ---
      await tester.tap(find.text('Morador(a)'));
      await tester.pumpAndSettle();

      // Modal aberto
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('Perfil de Usuário')), findsOneWidget);

      // Verificar que o modal está limitado a no máximo 85% da tela (800 * 0.85 = 680)
      final bottomSheetFinder = find.descendant(of: find.byType(BottomSheet), matching: find.byType(ConstrainedBox)).first;
      final bottomSheetSize = tester.getSize(bottomSheetFinder);
      expect(bottomSheetSize.height, lessThanOrEqualTo(800 * 0.85 + 1.0));

      // Verificar que opções inferiores são acessíveis por scroll
      final optionsToVerify = [
        'Porteiro (a)',
        'Zelador (a)',
        'Síndico (a)',
        'Sub Síndico (a)',
        'Afiliado (a)',
        'Terceirizado (a)',
        'Financeiro',
        'Serviços',
      ];

      for (final option in optionsToVerify) {
        final optionFinder = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(option),
        );
        await tester.scrollUntilVisible(
          optionFinder,
          100,
          scrollable: find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first,
        );
        await tester.pumpAndSettle();
        expect(optionFinder, findsOneWidget, reason: 'Opção $option deve estar visível');
      }

      // --- PASSO 5 a 8: Selecionar Síndico(a) ---
      final sindicoFinder = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Síndico (a)'),
      );
      await tester.scrollUntilVisible(
        sindicoFinder,
        -100,
        scrollable: find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(sindicoFinder);
      await tester.pumpAndSettle();

      // Confirmar que o modal fechou e o campo no formulário agora exibe Síndico (a)
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Síndico (a)'), findsOneWidget);

      // --- PASSO 9: Reabrir e verificar check no Síndico (a) ---
      await tester.tap(find.text('Síndico (a)'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      final sindicoInModal = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Síndico (a)'),
      );
      await tester.scrollUntilVisible(
        sindicoInModal,
        100,
        scrollable: find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first,
      );
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.byIcon(Icons.check)), findsOneWidget);

      // Fechar modal tocando na opção selecionada
      await tester.tap(sindicoInModal);
      await tester.pumpAndSettle();

      // --- PASSO 10: Validar Tipo de Usuário (ausência de regressão) ---
      await tester.tap(find.text('Proprietário (a)'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('Tipo de Usuário')), findsOneWidget);
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('Inquilino (a)')), findsOneWidget);
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('Cônjuge')), findsOneWidget);
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('Dependente')), findsOneWidget);
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('Família')), findsOneWidget);
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('Funcionário (a)')), findsOneWidget);
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('Terceirizado (a)')), findsOneWidget);

      // Selecionar Inquilino (a)
      await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text('Inquilino (a)')));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Inquilino (a)'), findsOneWidget);
    });

    testWidgets('2. Full validation on Small Screen Device (320x568)', (WidgetTester tester) async {
      final binding = tester.binding;
      binding.platformDispatcher.implicitView?.physicalSize = const Size(640, 1136);
      binding.platformDispatcher.implicitView?.devicePixelRatio = 2.0;

      addTearDown(() {
        binding.platformDispatcher.implicitView?.resetPhysicalSize();
        binding.platformDispatcher.implicitView?.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp(
        screenSize: const Size(320, 568),
        viewPadding: const EdgeInsets.only(bottom: 34, top: 20),
      ));
      await tester.pumpAndSettle();

      // Abrir Perfil de Usuário
      await tester.tap(find.text('Morador(a)'));
      await tester.pumpAndSettle();

      // Verificar que o modal respeita o tamanho da tela pequena
      final bottomSheetFinder = find.descendant(of: find.byType(BottomSheet), matching: find.byType(ConstrainedBox)).first;
      final bottomSheetSize = tester.getSize(bottomSheetFinder);
      expect(bottomSheetSize.height, lessThanOrEqualTo(568 * 0.85 + 1.0));

      // Scroll até a última opção "Serviços"
      final servicosFinder = find.descendant(of: find.byType(BottomSheet), matching: find.text('Serviços'));
      await tester.scrollUntilVisible(
        servicosFinder,
        100,
        scrollable: find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first,
      );
      await tester.pumpAndSettle();
      expect(servicosFinder, findsOneWidget);

      // Selecionar Serviços
      await tester.tap(servicosFinder);
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Serviços'), findsOneWidget);
    });
  });
}

class TestRegistrationForm extends StatefulWidget {
  const TestRegistrationForm({super.key});

  @override
  State<TestRegistrationForm> createState() => _TestRegistrationFormState();
}

class _TestRegistrationFormState extends State<TestRegistrationForm> {
  String _tipoUsuario = 'Proprietário (a)';
  String _perfilUsuario = 'Morador(a)';

  Widget _buildSafeSelector({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (ctx, index) {
                        final opt = options[index];
                        final isSelected = opt == value;
                        return ListTile(
                          title: Text(
                            opt,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? AppColors.primary : Colors.black87,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check, color: AppColors.primary)
                              : null,
                          onTap: () {
                            Navigator.pop(ctx);
                            onChanged(opt);
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(value, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSafeSelector(
          label: 'Tipo de Usuário',
          value: _tipoUsuario,
          options: const [
            'Proprietário (a)',
            'Inquilino (a)',
            'Cônjuge',
            'Dependente',
            'Família',
            'Funcionário (a)',
            'Terceirizado (a)',
          ],
          onChanged: (val) => setState(() => _tipoUsuario = val),
        ),
        const SizedBox(height: 16),
        _buildSafeSelector(
          label: 'Perfil de Usuário',
          value: _perfilUsuario,
          options: const [
            'Morador(a)',
            'Proprietário não morador',
            'Locatário (a)',
            'Locador',
            'Funcionário (a)',
            'Porteiro (a)',
            'Zelador (a)',
            'Síndico (a)',
            'Sub Síndico (a)',
            'Afiliado (a)',
            'Terceirizado (a)',
            'Financeiro',
            'Serviços',
          ],
          onChanged: (val) => setState(() => _perfilUsuario = val),
        ),
      ],
    );
  }
}
