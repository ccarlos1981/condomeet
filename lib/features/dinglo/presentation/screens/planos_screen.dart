import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../dinglo_theme.dart';
import '../../plano_service.dart';
import '../../revenuecat_service.dart';

class PlanosScreen extends StatefulWidget {
  const PlanosScreen({super.key});
  @override
  State<PlanosScreen> createState() => _PlanosScreenState();
}

class _PlanosScreenState extends State<PlanosScreen> {
  final _supabase = Supabase.instance.client;
  String _planoAtual = 'basico';
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final data = await _supabase.from('dinglo_plano_usuario')
          .select('plano').eq('user_id', _supabase.auth.currentUser!.id).maybeSingle();
      if (mounted) setState(() { _planoAtual = data?['plano'] ?? 'basico'; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _selecionarPlano(String plano) async {
    if (plano == _planoAtual) return;

    if (plano != 'basico') {
      if (kIsWeb) {
        _showWebMessage();
        return;
      }

      // Fetch RevenueCat packages and trigger purchase
      setState(() => _loading = true);
      try {
        final packages = await RevenueCatService.getPackages();
        if (!mounted) return;
        setState(() => _loading = false);

        if (packages.isEmpty) {
          _showNoPurchaseAvailable();
          return;
        }

        // Find the right package based on plan
        Package? targetPackage;
        if (plano == 'plus') {
          targetPackage = packages.firstWhere(
            (p) => p.packageType == PackageType.monthly,
            orElse: () => packages.first,
          );
        } else if (plano == 'plus_anual') {
          targetPackage = packages.firstWhere(
            (p) => p.packageType == PackageType.annual,
            orElse: () => packages.first,
          );
        }

        if (targetPackage != null) {
          final success = await RevenueCatService.purchasePackage(targetPackage);
          if (success && mounted) {
            _load();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🎉 Plano ativado com sucesso!'),
                backgroundColor: DingloTheme.income,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Compra cancelada ou erro. Tente novamente.'),
              backgroundColor: DingloTheme.expense,
            ),
          );
        }
      }
      return;
    }

    await _supabase.from('dinglo_plano_usuario')
        .update({'plano': plano}).eq('user_id', _supabase.auth.currentUser!.id);
    PlanoService.clearCache();
    _load();
  }

  void _showCupomDialog() {
    final cupomCtrl = TextEditingController();
    bool loading = false;
    String? errorMsg;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setBS) {
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF8B5CF6)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.confirmation_number_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 16),
              const Text('Resgatar Cupom', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: DingloTheme.textPrimary)),
              const SizedBox(height: 6),
              const Text('Digite o código promocional para\ndesbloquear recursos premium', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: DingloTheme.textSecondary, height: 1.4)),
              const SizedBox(height: 20),
              TextField(
                controller: cupomCtrl,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 3),
                decoration: InputDecoration(
                  hintText: 'EX: PROMO2026',
                  hintStyle: TextStyle(color: Colors.grey.shade300, letterSpacing: 2, fontWeight: FontWeight.w500),
                  filled: true,
                  fillColor: DingloTheme.surfaceVariant,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: DingloTheme.primary, width: 2),
                  ),
                  errorText: errorMsg,
                  prefixIcon: const Icon(Icons.vpn_key_rounded, color: DingloTheme.primary),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading ? null : () async {
                    final code = cupomCtrl.text.trim();
                    if (code.isEmpty) {
                      setBS(() => errorMsg = 'Digite um código');
                      return;
                    }
                    setBS(() { loading = true; errorMsg = null; });
                    try {
                      final result = await _supabase.rpc('dinglo_resgatar_cupom', params: {'p_codigo': code});
                      if (result['success'] == true) {
                        PlanoService.clearCache();
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          _load();
                          _showSuccessDialog(result['plano'] ?? 'plus', result['duracao_dias']);
                        }
                      } else {
                        setBS(() { loading = false; errorMsg = result['error'] ?? 'Erro ao resgatar'; });
                      }
                    } catch (e) {
                      setBS(() { loading = false; errorMsg = 'Erro de conexão. Tente novamente.'; });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DingloTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 4,
                    shadowColor: DingloTheme.primary.withValues(alpha: 0.4),
                  ),
                  child: loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Resgatar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  void _showSuccessDialog(String plano, dynamic duracaoDias) {
    final nomeMap = {'plus': 'Plus', 'plus_anual': 'Plus+'};
    final nomePlano = nomeMap[plano] ?? plano;
    final duracao = duracaoDias != null ? '$duracaoDias dias' : 'ilimitado';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: DingloTheme.income.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: DingloTheme.income, size: 40),
            ),
            const SizedBox(height: 16),
            const Text('Cupom Resgatado! 🎉', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(
              'Seu plano foi atualizado para $nomePlano.\nDuração: $duracao',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: DingloTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DingloTheme.income,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Aproveitar!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWebMessage() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Assinatura via App'),
      content: const Text('As assinaturas são processadas pela App Store / Google Play.\n\nAbra o Condomeet no seu celular para assinar.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Entendi', style: TextStyle(color: DingloTheme.primary, fontWeight: FontWeight.w700)),
        ),
      ],
    ));
  }

  void _showNoPurchaseAvailable() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Planos indisponíveis'),
      content: const Text('Os planos de assinatura ainda não estão configurados na loja.\n\nTente novamente mais tarde.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK', style: TextStyle(color: DingloTheme.primary, fontWeight: FontWeight.w700)),
        ),
      ],
    ));
  }

  Future<void> _restorePurchases() async {
    if (kIsWeb) return;
    setState(() => _loading = true);
    try {
      final restored = await RevenueCatService.restorePurchases();
      if (mounted) {
        _load();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(restored ? '✅ Assinatura restaurada!' : 'Nenhuma assinatura encontrada.'),
          backgroundColor: restored ? DingloTheme.income : DingloTheme.textMuted,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Erro ao restaurar. Tente novamente.'),
          backgroundColor: DingloTheme.expense,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DingloTheme.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: DingloTheme.primary))
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6), Color(0xFF06B6D4)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(28),
                        bottomRight: Radius.circular(28),
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Column(
                        children: [
                          // Back button
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                          const Icon(Icons.compass_calibration_rounded, color: Colors.white, size: 40),
                          const SizedBox(height: 10),
                          const Text(
                            'Uma bússola financeira\nem suas mãos',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.2),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Não fique mais perdido com suas contas',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Plans
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(child: _buildPlanCard(
                          nome: 'Básico',
                          preco: 'Grátis',
                          periodo: '',
                          planoId: 'basico',
                          features: ['Até 2 contas', '1 cartão', 'Categorias padrão', 'Lançamentos ilimitados'],
                          gradient: const LinearGradient(
                            colors: [Color(0xFF374151), Color(0xFF1F2937)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: _buildPlanCard(
                          nome: 'Plus',
                          preco: 'R\$ 15',
                          periodo: '/mês',
                          planoId: 'plus',
                          features: ['Relatórios avançados', 'Tags customizáveis', 'Anexar comprovante', 'Tudo do Básico'],
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                          popular: true,
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: _buildPlanCard(
                          nome: 'Plus +',
                          preco: 'R\$ 120',
                          periodo: '/ano',
                          planoId: 'plus_anual',
                          features: ['Tudo do Plus', 'Economia de 33%', 'Prioridade suporte', '12 meses'],
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Compare section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: DingloTheme.cardRadius,
                        boxShadow: DingloTheme.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Compare os planos', style: DingloTheme.heading3),
                          const SizedBox(height: 12),
                          _buildCompareRow('Contas bancárias', '2', '∞', '∞'),
                          _buildCompareRow('Cartões de crédito', '1', '∞', '∞'),
                          _buildCompareRow('Lançamentos', '✅', '✅', '✅'),
                          _buildCompareRow('Categorias', 'Padrão', 'Custom', 'Custom'),
                          _buildCompareRow('Metas', '❌', '✅', '✅'),
                          _buildCompareRow('Desp. fixas', '❌', '✅', '✅'),
                          _buildCompareRow('Relatórios avançados', '❌', '✅', '✅'),
                          _buildCompareRow('Tags', '❌', '✅', '✅'),
                          _buildCompareRow('Comprovantes', '❌', '✅', '✅'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Coupon button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _showCupomDialog,
                        icon: const Icon(Icons.confirmation_number_rounded, size: 18),
                        label: const Text('Tenho um cupom', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF7C3AED),
                          side: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                  if (!kIsWeb) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton.icon(
                        onPressed: _restorePurchases,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Restaurar compras',
                            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                        style: TextButton.styleFrom(foregroundColor: DingloTheme.textMuted),
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildPlanCard({
    required String nome,
    required String preco,
    required String periodo,
    required String planoId,
    required List<String> features,
    required LinearGradient gradient,
    bool popular = false,
  }) {
    final isAtual = _planoAtual == planoId;

    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: gradient.colors.first.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
        border: isAtual ? Border.all(color: Colors.white, width: 2) : null,
      ),
      child: Column(
        children: [
          if (popular) Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            child: const Text('⭐ Popular', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.black)),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(nome, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 6),
                Text(preco, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                if (periodo.isNotEmpty) Text(periodo, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10)),
                const SizedBox(height: 10),
                ...features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(children: [
                    Icon(Icons.check_rounded, color: Colors.white.withValues(alpha: 0.8), size: 12),
                    const SizedBox(width: 4),
                    Flexible(child: Text(f, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 9))),
                  ]),
                )),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isAtual ? null : () => _selecionarPlano(planoId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAtual ? Colors.white.withValues(alpha: 0.3) : Colors.white,
                      foregroundColor: isAtual ? Colors.white : gradient.colors.first,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: Text(
                      isAtual ? 'Atual' : 'Selecionar',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompareRow(String feature, String basico, String plus, String plusAnual) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
      child: Row(children: [
        Expanded(flex: 3, child: Text(feature, style: const TextStyle(fontSize: 11, color: DingloTheme.textSecondary))),
        Expanded(child: Text(basico, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
        Expanded(child: Text(plus, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
        Expanded(child: Text(plusAnual, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
      ]),
    );
  }
}
