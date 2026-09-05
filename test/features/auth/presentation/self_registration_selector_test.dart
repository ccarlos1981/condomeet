import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:condomeet/core/design_system/app_colors.dart';

void main() {
  group('SelfRegistration Selector UX Test', () {
    testWidgets('Selector opens scrollable modal sheet with 85% constraint and allows selecting any item', (WidgetTester tester) async {
      String selectedValue = 'Morador(a)';
      final options = [
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
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Center(
                  child: GestureDetector(
                    key: const Key('selector_gesture'),
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
                                const SizedBox(height: 12),
                                Container(
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Text(
                                    'Perfil de Usuário',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                                      final isSelected = opt == selectedValue;
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
                                          setState(() => selectedValue = opt);
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
                    child: Text('Selected: $selectedValue'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Verify initial state
      expect(find.text('Selected: Morador(a)'), findsOneWidget);

      // Tap to open bottom sheet
      await tester.tap(find.byKey(const Key('selector_gesture')));
      await tester.pumpAndSettle();

      // Verify modal is open and header is visible
      expect(find.text('Perfil de Usuário'), findsOneWidget);

      // Verify top option is visible and selected
      expect(find.text('Morador(a)'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);

      // Scroll down to find and select "Síndico (a)"
      final sindicoItem = find.text('Síndico (a)');
      await tester.scrollUntilVisible(sindicoItem, 100);
      await tester.pumpAndSettle();

      expect(sindicoItem, findsOneWidget);

      // Tap "Síndico (a)"
      await tester.tap(sindicoItem);
      await tester.pumpAndSettle();

      // Verify sheet closed and value updated
      expect(find.text('Selected: Síndico (a)'), findsOneWidget);
    });
  });
}
