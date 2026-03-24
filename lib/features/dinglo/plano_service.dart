import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dinglo_theme.dart';

/// Service to check plan limits and show upgrade prompts
class PlanoService {
  static final _supabase = Supabase.instance.client;

  /// Cached plan slug for the current session
  static String? _cachedPlano;

  /// Get the current user's plan slug
  static Future<String> getPlanoAtual() async {
    if (_cachedPlano != null) return _cachedPlano!;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 'basico';

    final data = await _supabase.from('dinglo_plano_usuario')
        .select('plano')
        .eq('user_id', userId)
        .maybeSingle();

    _cachedPlano = data?['plano'] ?? 'basico';
    return _cachedPlano!;
  }

  /// Clear cache (call when plan changes)
  static void clearCache() => _cachedPlano = null;

  /// True if user has Plus or Plus+
  static Future<bool> isPremium() async {
    final plano = await getPlanoAtual();
    return plano == 'plus' || plano == 'plus_anual';
  }

  // ── Limits for Básico plan ─────────────────────────────────────────

  static const int maxContasBasico = 2;
  static const int maxCartoesBasico = 1;

  /// Check if user can add more accounts
  static Future<bool> canAddConta() async {
    if (await isPremium()) return true;
    final userId = _supabase.auth.currentUser!.id;
    final count = await _supabase.from('dinglo_contas')
        .select('id')
        .eq('user_id', userId);
    return (count as List).length < maxContasBasico;
  }

  /// Check if user can add more cards
  static Future<bool> canAddCartao() async {
    if (await isPremium()) return true;
    final userId = _supabase.auth.currentUser!.id;
    final count = await _supabase.from('dinglo_cartoes')
        .select('id')
        .eq('user_id', userId);
    return (count as List).length < maxCartoesBasico;
  }

  /// Shows the upgrade dialog with animation
  static void showUpgradeDialog(BuildContext context, {
    required String recurso,
    required String limite,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'upgrade',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => _UpgradeDialog(recurso: recurso, limite: limite),
      transitionBuilder: (_, anim, __, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
    );
  }
}

class _UpgradeDialog extends StatelessWidget {
  final String recurso;
  final String limite;

  const _UpgradeDialog({required this.recurso, required this.limite});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: DingloTheme.primary.withValues(alpha: 0.25),
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
                // Header gradient
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6), Color(0xFF06B6D4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                        ),
                        child: const Icon(Icons.lock_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Limite atingido',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Plano Básico: $limite',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // Body
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    children: [
                      Text(
                        'Faça upgrade para o Plus e tenha $recurso ilimitados!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: DingloTheme.textPrimary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Benefits
                      _buildBenefit(Icons.all_inclusive_rounded, 'Contas e cartões ilimitados'),
                      _buildBenefit(Icons.bar_chart_rounded, 'Relatórios avançados'),
                      _buildBenefit(Icons.attach_file_rounded, 'Anexar comprovantes'),
                      _buildBenefit(Icons.sell_rounded, 'Tags personalizadas'),

                      const SizedBox(height: 20),

                      // Price badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: DingloTheme.income.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: DingloTheme.income.withValues(alpha: 0.3)),
                        ),
                        child: const Text(
                          'A partir de R\$ 14,90/mês',
                          style: TextStyle(
                            color: DingloTheme.income,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // CTA
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/dinglo/planos');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: DingloTheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 4,
                            shadowColor: DingloTheme.primary.withValues(alpha: 0.4),
                          ),
                          child: const Text(
                            'Conhecer Planos  ⭐',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Agora não',
                          style: TextStyle(
                            color: DingloTheme.textMuted,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
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

  static Widget _buildBenefit(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: DingloTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: DingloTheme.primary, size: 16),
          ),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(fontSize: 13, color: DingloTheme.textSecondary)),
        ],
      ),
    );
  }
}
