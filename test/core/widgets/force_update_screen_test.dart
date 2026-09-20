import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:condomeet/core/services/version_check_service.dart';
import 'package:condomeet/core/design_system/widgets/force_update_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ForceUpdateScreen renders unclosable popup with exact text and only Atualizar button', (tester) async {
    const gateResult = VersionGateResult(
      status: VersionGateStatus.updateRequired,
      installedBuild: 101,
      installedVersion: '3.9.1',
      requiredBuild: 105,
      requiredVersion: '3.9.5',
      storeUrl: 'https://play.google.com/store/apps/details?id=br.com.condod.wwwc',
      title: 'Atualização Obrigatória',
      message: 'Você precisa atualizar o aplicativo para continuar.',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: ForceUpdateScreen(
          gateResult: gateResult,
        ),
      ),
    );

    // 1. Verifica presença do texto mandatório do popup
    expect(
      find.text('Você precisa atualizar o aplicativo para continuar.'),
      findsOneWidget,
    );

    // 2. Verifica presença de SOMENTE o botão "Atualizar"
    expect(find.widgetWithText(ElevatedButton, 'Atualizar'), findsOneWidget);

    // 3. Garante que NÃO existem botões extras (como 'Tentar Novamente', 'Fechar', 'Cancelar')
    expect(find.text('Tentar Novamente'), findsNothing);
    expect(find.text('Fechar'), findsNothing);
    expect(find.text('Cancelar'), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);

    // 4. Garante que o PopScope bloqueia o retorno (canPop = false)
    final popScopeFinder = find.byType(PopScope);
    expect(popScopeFinder, findsOneWidget);
    final popScope = tester.widget<PopScope>(popScopeFinder);
    expect(popScope.canPop, isFalse);
  });
}
