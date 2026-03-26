import 'package:flutter/material.dart';
import 'package:condomeet/core/design_system/app_colors.dart';

/// Onboarding carousel that teaches users the Garagem Inteligente flow
class GaragemOnboardingScreen extends StatefulWidget {
  const GaragemOnboardingScreen({super.key});

  @override
  State<GaragemOnboardingScreen> createState() => _GaragemOnboardingScreenState();
}

class _GaragemOnboardingScreenState extends State<GaragemOnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _pages = <_OnboardingPage>[
    _OnboardingPage(
      icon: Icons.add_box_rounded,
      iconBg: Color(0xFF7B2FF7),
      title: 'Cadastre sua Vaga',
      subtitle: 'Informe o número, tipo (carro/moto)\ne o preço por hora, dia ou mês.',
      tip: 'Dica: Defina preços competitivos para atrair vizinhos',
      stepNumber: '1',
    ),
    _OnboardingPage(
      icon: Icons.toggle_on_rounded,
      iconBg: Color(0xFF3B82F6),
      title: 'Publique e Ative',
      subtitle: 'Sua vaga aparecerá na aba "Disponíveis"\npara todos os moradores do condomínio.',
      tip: 'Dica: Desative quando não quiser receber reservas',
      stepNumber: '2',
    ),
    _OnboardingPage(
      icon: Icons.bookmark_added_rounded,
      iconBg: Color(0xFFF59E0B),
      title: 'Receba Reservas',
      subtitle: 'Vizinhos podem reservar sua vaga.\nVocê recebe notificação em tempo real!',
      tip: 'Dica: Confirme rápido para garantir o locatário',
      stepNumber: '3',
    ),
    _OnboardingPage(
      icon: Icons.notifications_active_rounded,
      iconBg: Color(0xFF06B6D4),
      title: 'Notificações Automáticas',
      subtitle: 'Receba via Push e WhatsApp quando\nalguém reservar, cancelar ou confirmar.',
      tip: 'Dica: Mantenha as notificações ativadas',
      stepNumber: '4',
    ),
    _OnboardingPage(
      icon: Icons.emoji_events_rounded,
      iconBg: Color(0xFF10B981),
      title: 'Suba no Ranking',
      subtitle: 'Quanto mais reservas, mais alto\nno ranking do condomínio! 🏆',
      tip: r'Sua vaga pode gerar até R$ 500/mês!',
      stepNumber: '5',
    ),
  ];

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _skip() {
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16, top: 8),
                child: TextButton(
                  onPressed: _skip,
                  child: Text(
                    isLast ? '' : 'Pular',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return _buildPage(page);
                },
              ),
            ),

            // Dot indicators
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (i) {
                  final isActive = i == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFF7B2FF7) : const Color(0xFF7B2FF7).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            // CTA Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B2FF7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    shadowColor: const Color(0xFF7B2FF7).withValues(alpha: 0.4),
                  ),
                  child: Text(
                    isLast ? 'Começar  🚀' : 'Próximo',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ),
            ),

            // Secondary action on last page
            if (isLast)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextButton(
                  onPressed: _skip,
                  child: Text(
                    'Explorar sozinho',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 1),

          // Step badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: page.iconBg.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Passo ${page.stepNumber} de ${_pages.length}',
              style: TextStyle(
                color: page.iconBg,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Big icon with decorative circle
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: page.iconBg.withValues(alpha: 0.12),
                    width: 2,
                  ),
                ),
              ),
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      page.iconBg,
                      page.iconBg.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: page.iconBg.withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(page.icon, color: Colors.white, size: 48),
              ),
            ],
          ),
          const SizedBox(height: 40),

          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppColors.textMain,
              letterSpacing: -0.8,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 14),

          // Subtitle
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // Tip box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: page.iconBg.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: page.iconBg.withValues(alpha: 0.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lightbulb_outline_rounded, color: page.iconBg, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    page.tip,
                    style: TextStyle(
                      color: page.iconBg,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String tip;
  final String stepNumber;

  const _OnboardingPage({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.tip,
    required this.stepNumber,
  });
}
