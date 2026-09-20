import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/core/design_system/widgets/condo_pull_to_refresh.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CondoPullToRefresh', () {
    testWidgets('renders RefreshIndicator with AppColors.primary by default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CondoPullToRefresh(
              onRefresh: () async {},
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [Text('Item 1')],
              ),
            ),
          ),
        ),
      );

      final indicatorFinder = find.byType(RefreshIndicator);
      expect(indicatorFinder, findsOneWidget);

      final indicator = tester.widget<RefreshIndicator>(indicatorFinder);
      expect(indicator.color, AppColors.primary);
      expect(indicator.backgroundColor, Colors.white);
    });

    testWidgets('triggers onRefresh callback when dragged down', (tester) async {
      int refreshCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CondoPullToRefresh(
              onRefresh: () async {
                refreshCount++;
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 100, child: Text('Content')),
                ],
              ),
            ),
          ),
        ),
      );

      expect(refreshCount, 0);

      // Fling down to trigger refresh
      await tester.fling(find.text('Content'), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(refreshCount, 1);
    });

    testWidgets('guards against concurrent refresh executions', (tester) async {
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
                  SizedBox(height: 100, child: Text('Content')),
                ],
              ),
            ),
          ),
        ),
      );

      final state = tester.state<CondoPullToRefreshState>(find.byType(CondoPullToRefresh));
      final indicatorFinder = find.byType(RefreshIndicator);
      final indicator = tester.widget<RefreshIndicator>(indicatorFinder);

      // Trigger first refresh
      final future1 = indicator.onRefresh();
      expect(state.isRefreshing, isTrue);
      expect(executions, 1);

      // Attempt second concurrent refresh while the first is pending
      final future2 = indicator.onRefresh();
      // Ensure execution count did not increment
      expect(executions, 1);

      // Finish the initial refresh
      completer.complete();
      await future1;
      await future2;
      await tester.pump();

      expect(state.isRefreshing, isFalse);
      expect(executions, 1);
    });

    testWidgets('works on empty state using isEmpty and emptyWidget', (tester) async {
      int refreshCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CondoPullToRefresh(
              onRefresh: () async {
                refreshCount++;
              },
              isEmpty: true,
              emptyWidget: const Text('Nenhum item encontrado'),
              child: ListView(
                children: const [Text('Item')],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Nenhum item encontrado'), findsOneWidget);
      expect(find.text('Item'), findsNothing);

      // Pull down on the empty state text
      await tester.fling(find.text('Nenhum item encontrado'), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(refreshCount, 1);
    });

    testWidgets('works on short lists with 1 item', (tester) async {
      int refreshCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CondoPullToRefresh(
              onRefresh: () async {
                refreshCount++;
              },
              child: ListView(
                physics: CondoPullToRefresh.alwaysScrollablePhysics,
                children: const [
                  ListTile(title: Text('Apenas 1 item curto')),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Apenas 1 item curto'), findsOneWidget);

      await tester.fling(find.text('Apenas 1 item curto'), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(refreshCount, 1);
    });

    testWidgets('CondoPullToRefresh.scrollable wraps non-scrollable widget cleanly', (tester) async {
      int refreshCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CondoPullToRefresh.scrollable(
              onRefresh: () async {
                refreshCount++;
              },
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox),
                  Text('Vazio Total'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Vazio Total'), findsOneWidget);

      await tester.fling(find.text('Vazio Total'), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(refreshCount, 1);
    });
  });
}
