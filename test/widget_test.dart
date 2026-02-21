import 'package:flutter_test/flutter_test.dart';
import 'package:condomeet/main.dart';

void main() {
  testWidgets('Design System showcase smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CondomeetApp());

    // Verify that the showcase title is present.
    expect(find.text('Condomeet Design System'), findsOneWidget);
    
    // Verify that atomic components are rendered.
    expect(find.text('Primary Button'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
  });
}
