import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shows the onboarding popup on first access to Garagem.
class GaragemOnboardingPopup {
  static const _prefKey = 'garagem_onboarding_seen';

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

  static const _accent = Color(0xFF7B2FF7);

  static const _pages = [
    _OnboardingPage(
      icon: Icons.local_parking_rounded,
      title: 'Garagem Inteligente',
      subtitle: 'Sua vaga pode gerar renda!',
      desc: 'Alugue sua vaga de garagem para vizinhos e ganhe dinheiro. '
          'Reserve vagas disponíveis quando precisar.',
      color: Color(0xFF7B2FF7),
    ),
    _OnboardingPage(
      icon: Icons.add_box_rounded,
      title: 'Cadastre sua Vaga',
      subtitle: 'Simples e rápido',
      desc: 'Informe o número da vaga, tipo (carro/moto), '
          'preço e disponibilidade. Sua vaga fica visível para todos.',
      color: Color(0xFF2196F3),
    ),
    _OnboardingPage(
      icon: Icons.bookmark_add_rounded,
      title: 'Reserve uma Vaga',
      subtitle: 'Encontre e reserve',
      desc: 'Navegue pelas vagas disponíveis no seu condomínio, '
          'escolha a melhor opção e reserve direto pelo app.',
      color: Color(0xFF00C853),
    ),
    _OnboardingPage(
      icon: Icons.emoji_events_rounded,
      title: 'Ranking e Lucros',
      subtitle: 'Acompanhe seus ganhos',
      desc: 'Veja quanto você está faturando e compare no ranking '
          'do condomínio. Sua vaga pode render até R\$ 500/mês!',
      color: Color(0xFFF9A825),
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

            // Dots indicator
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

            // Buttons
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
                          backgroundColor: _accent,
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
