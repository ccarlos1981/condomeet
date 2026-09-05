import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:condomeet/core/services/version_check_service.dart';
import 'package:condomeet/core/design_system/widgets/force_update_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ForceUpdateScreen renders correctly with version badges and buttons', (tester) async {
    bool retryCalled = false;

    const gateResult = VersionGateResult(
      status: VersionGateStatus.updateRequired,
      installedBuild: 101,
      installedVersion: '3.9.1',
      requiredBuild: 102,
      requiredVersion: '3.9.3',
      storeUrl: 'https://play.google.com/store/apps/details?id=br.com.condod.wwwc',
      title: 'Atualização Necessária',
      message: 'Por favor atualize seu app.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ForceUpdateScreen(
          gateResult: gateResult,
          onRetry: () {
            retryCalled = true;
          },
        ),
      ),
    );

    expect(find.text('Atualização Necessária'), findsOneWidget);
    expect(find.text('Por favor atualize seu app.'), findsOneWidget);
    expect(find.text('3.9.1 (Build 101)'), findsOneWidget);
    expect(find.text('3.9.3 (Build 102)'), findsOneWidget);
    expect(find.text('ATUALIZAR AGORA'), findsOneWidget);
    expect(find.text('Tentar Novamente'), findsOneWidget);

    // Test retry button
    await tester.tap(find.text('Tentar Novamente'));
    await tester.pumpAndSettle();
    expect(retryCalled, isTrue);
  });
}
