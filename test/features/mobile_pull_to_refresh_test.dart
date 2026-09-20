import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:condomeet/core/design_system/widgets/condo_pull_to_refresh.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mobile Pull-To-Refresh Gate Validation', () {
    testWidgets('1. Empty state: user drags down on empty list and refresh triggers', (tester) async {
      int refreshCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Documentos')),
            body: CondoPullToRefresh(
              onRefresh: () async {
                refreshCount++;
              },
              isEmpty: true,
              emptyWidget: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_open_outlined, size: 64),
                  Text('Nenhum documento disponível'),
                ],
              ),
              child: ListView(
                children: const [Text('Documento 1')],
              ),
            ),
          ),
        ),
      );

      // Verify empty widget is displayed
      expect(find.text('Nenhum documento disponível'), findsOneWidget);
      expect(find.text('Documento 1'), findsNothing);

      // Fling down on empty state
      await tester.fling(find.text('Nenhum documento disponível'), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(refreshCount, 1);
    });

    testWidgets('2. TabBarView: horizontal swipe preserved and each tab has independent vertical refresh', (tester) async {
      int tab1RefreshCount = 0;
      int tab2RefreshCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                bottom: const TabBar(
                  tabs: [
                    Tab(text: 'Disponíveis'),
                    Tab(text: 'Meus Agendamentos'),
                  ],
                ),
              ),
              body: TabBarView(
                children: [
                  CondoPullToRefresh(
                    onRefresh: () async {
                      tab1RefreshCount++;
                    },
                    isEmpty: true,
                    emptyWidget: const Text('Nenhuma área disponível'),
                    child: ListView(),
                  ),
                  CondoPullToRefresh(
                    onRefresh: () async {
                      tab2RefreshCount++;
                    },
                    isEmpty: true,
                    emptyWidget: const Text('Você ainda não tem agendamentos'),
                    child: ListView(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // On Tab 1
      expect(find.text('Nenhuma área disponível'), findsOneWidget);
      expect(find.text('Você ainda não tem agendamentos'), findsNothing);

      // Pull down on Tab 1
      await tester.fling(find.text('Nenhuma área disponível'), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(tab1RefreshCount, 1);
      expect(tab2RefreshCount, 0);

      // Horizontal swipe to Tab 2
      await tester.fling(find.text('Nenhuma área disponível'), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      // On Tab 2
      expect(find.text('Você ainda não tem agendamentos'), findsOneWidget);

      // Pull down on Tab 2
      await tester.fling(find.text('Você ainda não tem agendamentos'), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(tab1RefreshCount, 1);
      expect(tab2RefreshCount, 1);
    });

    testWidgets('3. Form state preservation: refresh does NOT clear text inputs or selections', (tester) async {
      int refreshCount = 0;
      final textController = TextEditingController(text: 'João da Silva');
      String selectedType = 'Delivery';

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                appBar: AppBar(title: const Text('Autorizar Visitante')),
                body: CondoPullToRefresh(
                  onRefresh: () async {
                    refreshCount++;
                    // Refresh only loads background data, does NOT clear form
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        TextField(
                          controller: textController,
                          decoration: const InputDecoration(labelText: 'Nome'),
                        ),
                        Text('Tipo: $selectedType'),
                        const SizedBox(height: 500),
                        const Text('Lista de autorizações'),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );

      expect(find.text('João da Silva'), findsOneWidget);
      expect(find.text('Tipo: Delivery'), findsOneWidget);

      // User types additional text
      await tester.enterText(find.byType(TextField), 'João da Silva Santos');
      await tester.pump();
      expect(find.text('João da Silva Santos'), findsOneWidget);

      // Drag down to trigger refresh
      await tester.fling(find.text('Tipo: Delivery'), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(refreshCount, 1);
      // Verify text and selection are 100% preserved
      expect(find.text('João da Silva Santos'), findsOneWidget);
      expect(find.text('Tipo: Delivery'), findsOneWidget);
    });

    testWidgets('4. Concurrency: multiple rapid refresh triggers execute exactly once', (tester) async {
      int executions = 0;
      final completer = Completer<void>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CondoPullToRefresh(
              onRefresh: () async {
                executions++;
                await completer.future;
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  Text('Lista Encomendas'),
                ],
              ),
            ),
          ),
        ),
      );

      final indicator = tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));

      // First trigger
      final f1 = indicator.onRefresh();
      expect(executions, 1);

      // Rapid concurrent second and third triggers
      final f2 = indicator.onRefresh();
      final f3 = indicator.onRefresh();

      // Executions must strictly remain 1
      expect(executions, 1);

      completer.complete();
      await f1;
      await f2;
      await f3;
      await tester.pump();

      expect(executions, 1);
    });
  });
}
