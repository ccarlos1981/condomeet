import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../dinglo_theme.dart';

class DingloWelcomeDialog extends StatelessWidget {
  const DingloWelcomeDialog({super.key});

  /// Shows the welcome dialog only on first access
  static Future<void> showIfFirstTime(BuildContext context) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Check if user already has a plan record (meaning they've seen the welcome)
    final existing = await supabase.from('dinglo_plano_usuario')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) return; // Already onboarded

    // Create free plan record (marks as onboarded)
    await supabase.from('dinglo_plano_usuario').insert({
      'user_id': userId,
      'plano': 'basico',
      'ativo': true,
    });

    // Show the welcome dialog
    if (context.mounted) {
      showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, __, ___) => const DingloWelcomeDialog(),
        transitionBuilder: (_, anim, __, child) {
          return ScaleTransition(
            scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
            child: child,
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: DingloTheme.primary.withValues(alpha: 0.3),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top gradient section with illustration
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6), Color(0xFF06B6D4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Rocket icon (inspired by the Dinglo branding)
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                        ),
                        child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 36),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '💰 Meu Bolso',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Uma bússola financeira\nem suas mãos',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),

                // Content section
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    children: [
                      const Text(
                        'Organize suas finanças\nde uma vez por todas!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: DingloTheme.textPrimary,
                          height: 1.3,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Features list
                      _buildFeatureRow(Icons.swap_horiz_rounded, 'Movimentação',
                          'Controle despesas e ganhos', const Color(0xFF3B82F6)),
                      _buildFeatureRow(Icons.account_balance_wallet_rounded, 'Orçamento',
                          'Defina quanto pode gastar', const Color(0xFF10B981)),
                      _buildFeatureRow(Icons.notifications_active_rounded, 'Alertas',
                          'Lembre de contas que não pode atrasar', const Color(0xFFF59E0B)),
                      _buildFeatureRow(Icons.bar_chart_rounded, 'Relatórios',
                          'Resumo simples e eficiente', const Color(0xFF8B5CF6)),

                      const SizedBox(height: 20),

                      // Free plan badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: DingloTheme.income.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: DingloTheme.income.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded, color: DingloTheme.income, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'Plano Free ativado!',
                              style: TextStyle(
                                color: DingloTheme.income,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Quer mais? Conheça os planos Plus',
                        style: TextStyle(
                          fontSize: 11,
                          color: DingloTheme.textMuted,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // CTA Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/dinglo/onboarding');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: DingloTheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 4,
                            shadowColor: DingloTheme.primary.withValues(alpha: 0.4),
                          ),
                          child: const Text(
                            'Começar Agora  🚀',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildFeatureRow(IconData icon, String title, String subtitle, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: DingloTheme.textPrimary)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: DingloTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
