import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/core/errors/result.dart';

void main() {
  group('Design System Components', () {
    testWidgets('CondoButton renders and responds to tap', (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CondoButton(
            label: 'Test Button',
            onPressed: () => tapped = true,
          ),
        ),
      ));

      expect(find.text('Test Button'), findsOneWidget);
      await tester.tap(find.byType(ElevatedButton));
      expect(tapped, isTrue);
    });

    testWidgets('CondoButton shows loading indicator when isLoading is true', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: CondoButton(
            label: 'Loading',
            isLoading: true,
          ),
        ),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading'), findsNothing);
    });

    testWidgets('CondoInput shows label and hint', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: CondoInput(
            label: 'User Label',
            hint: 'User Hint',
          ),
        ),
      ));

      expect(find.text('User Label'), findsOneWidget);
      expect(find.text('User Hint'), findsOneWidget);
    });

    test('Result fold handles Success and Failure correctly', () {
      const success = Success<String>('Data');
      final successValue = success.fold((f) => 'Error', (s) => s);
      expect(successValue, 'Data');

      const failure = Failure<String>('Error Message');
      final failureValue = failure.fold((f) => f.message, (s) => 'Success');
      expect(failureValue, 'Error Message');
    });
  });
}
