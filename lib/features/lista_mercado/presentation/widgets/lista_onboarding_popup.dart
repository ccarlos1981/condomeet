import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shows the "Como funciona" onboarding popup on first access.
/// Uses SharedPreferences to track if user has seen it.
class ListaOnboardingPopup {
  static const _prefKey = 'lista_mercado_onboarding_seen';

  static Future<void> showIfNeeded(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefKey) == true) return;

    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _OnboardingDialog(),
    );

    await prefs.setBool(_prefKey, true);
  }

  /// Force-show the onboarding (for help button)
  static Future<void> showAlways(BuildContext context) async {
    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const _OnboardingDialog(),
    );
  }
}

class _OnboardingDialog extends StatefulWidget {
  const _OnboardingDialog();

  @override
  State<_OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends State<_OnboardingDialog> {
  int _page = 0;
  final _controller = PageController();

  static const _pages = [
    {
      'emoji': '🛒',
      'title': 'Lista Inteligente',
      'subtitle': 'Compare preços e economize!',
      'desc': 'Crie sua lista de compras e descubra qual mercado tem o melhor preço na sua região.',
      'color': 0xFF00C853,
    },
    {
      'emoji': '📊',
      'title': 'Compare Preços',
      'subtitle': 'Veja onde comprar mais barato',
      'desc': 'O app compara os preços da sua lista em todos os mercados cadastrados e mostra onde você economiza mais.',
      'color': 0xFF42A5F5,
    },
    {
      'emoji': '📝',
      'title': 'Reporte Preços',
      'subtitle': 'Ganhe pontos ajudando!',
      'desc': 'Reporte preços que você vê no mercado e ganhe pontos. Suba no ranking e se torne um Mestre do Preço! 👑',
      'color': 0xFFFFA726,
    },
    {
      'emoji': '📷',
      'title': 'Escaneie o Cupom',
      'subtitle': 'OCR automático',
      'desc': 'Tire foto do seu cupom fiscal e os preços são importados automaticamente. Rápido e fácil!',
      'color': 0xFFAB47BC,
    },
    {
      'emoji': '🔔',
      'title': 'Alertas de Preço',
      'subtitle': 'Seja notificado!',
      'desc': 'Defina um preço alvo e receba notificação quando o produto atingir seu valor. Nunca perca uma oferta!',
      'color': 0xFFEF5350,
    },
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 420),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Page content
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _pages.length,
                itemBuilder: (ctx, i) {
                  final p = _pages[i];
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Emoji
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          color: Color(p['color'] as int).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(child: Text(p['emoji'] as String, style: const TextStyle(fontSize: 44))),
                      ),
                      const SizedBox(height: 16),
                      Text(p['title'] as String, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(p['subtitle'] as String, style: TextStyle(color: Color(p['color'] as int), fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(p['desc'] as String, textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white54, fontSize: 14, height: 1.4)),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Dots indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) => Container(
                width: i == _page ? 24 : 8, height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: i == _page ? Color(_pages[_page]['color'] as int) : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
            ),
            const SizedBox(height: 16),

            // Buttons
            Row(
              children: [
                if (_page > 0)
                  TextButton(
                    onPressed: () => _controller.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                    child: const Text('Voltar', style: TextStyle(color: Colors.white38)),
                  ),
                const Spacer(),
                _page < _pages.length - 1
                    ? ElevatedButton(
                        onPressed: () => _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(_pages[_page]['color'] as int),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: const Text('Próximo →', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      )
                    : ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C853),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: const Text('Começar! 🚀', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
