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
    _OnboardingPage(
      icon: Icons.shopping_cart_rounded,
      title: 'Lista Inteligente',
      subtitle: 'Compare preços e economize!',
      desc: 'Crie sua lista de compras e descubra qual mercado tem o melhor preço na sua região.',
      color: Color(0xFF00C853),
    ),
    _OnboardingPage(
      icon: Icons.bar_chart_rounded,
      title: 'Compare Preços',
      subtitle: 'Veja onde comprar mais barato',
      desc: 'O app compara os preços da sua lista em todos os mercados cadastrados e mostra onde você economiza mais.',
      color: Color(0xFF1976D2),
    ),
    _OnboardingPage(
      icon: Icons.edit_note_rounded,
      title: 'Reporte Preços',
      subtitle: 'Ganhe pontos ajudando!',
      desc: 'Reporte preços que você vê no mercado e ganhe pontos. Suba no ranking e se torne um Mestre do Preço!',
      color: Color(0xFFF57C00),
    ),
    _OnboardingPage(
      icon: Icons.camera_alt_rounded,
      title: 'Escaneie o Cupom',
      subtitle: 'Importação automática',
      desc: 'Tire foto do seu cupom fiscal e os preços são importados automaticamente. Rápido e fácil!',
      color: Color(0xFF7B1FA2),
    ),
    _OnboardingPage(
      icon: Icons.notifications_active_rounded,
      title: 'Alertas de Preço',
      subtitle: 'Seja notificado!',
      desc: 'Defina um preço alvo e receba notificação quando o produto atingir seu valor. Nunca perca uma oferta!',
      color: Color(0xFFE53935),
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_page];
    
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 480),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          children: [
            // ── Page content ──
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
                      // Icon container
                      Container(
                        width: 88, height: 88,
                        decoration: BoxDecoration(
                          color: p.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Center(
                          child: Icon(p.icon, size: 44, color: p.color),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Title
                      Text(
                        p.title,
                        style: TextStyle(
                          color: Colors.grey.shade900,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Subtitle
                      Text(
                        p.subtitle,
                        style: TextStyle(
                          color: p.color,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Description
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          p.desc,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // ── Dots indicator ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: i == _page ? 28 : 10,
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: i == _page ? page.color : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(5),
                ),
              )),
            ),
            const SizedBox(height: 20),

            // ── Buttons ──
            Row(
              children: [
                if (_page > 0)
                  TextButton(
                    onPressed: () => _controller.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: Text(
                      '← Voltar',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                const Spacer(),
                _page < _pages.length - 1
                    ? ElevatedButton(
                        onPressed: () => _controller.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: page.color,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          elevation: 2,
                        ),
                        child: const Text('Próximo →', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      )
                    : ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C853),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                          elevation: 2,
                        ),
                        child: const Text('Começar!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String subtitle;
  final String desc;
  final Color color;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.desc,
    required this.color,
  });
}
