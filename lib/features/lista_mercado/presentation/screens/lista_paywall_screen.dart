import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../lista_mercado/lista_subscription_service.dart';

/// Paywall screen for Lista Inteligente — shown when trial expires.
/// Light/white theme for elderly accessibility.
class ListaPaywallScreen extends StatefulWidget {
  const ListaPaywallScreen({super.key});

  @override
  State<ListaPaywallScreen> createState() => _ListaPaywallScreenState();
}

class _ListaPaywallScreenState extends State<ListaPaywallScreen> {
  bool _loading = false;
  List<Package> _packages = [];

  static const _green = Color(0xFF2E7D32);
  static const _greenLight = Color(0xFF4CAF50);

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _loadPackages();
  }

  Future<void> _loadPackages() async {
    final packages = await ListaSubscriptionService.getListaPackages();
    if (mounted) setState(() => _packages = packages);
  }

  Future<void> _handlePurchase(Package package) async {
    setState(() => _loading = true);
    try {
      final success = await ListaSubscriptionService.purchasePackage(package);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Assinatura ativada! Aproveite a Lista Inteligente Premium!'),
            backgroundColor: _green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (_) {
      // User cancelled or error
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _handleRestore() async {
    setState(() => _loading = true);
    try {
      final restored = await ListaSubscriptionService.restorePurchases();
      if (mounted) {
        if (restored) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Assinatura restaurada!'), backgroundColor: _green),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('Nenhuma assinatura encontrada.'), backgroundColor: Colors.grey.shade600),
          );
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _showCouponDialog() {
    final controller = TextEditingController();
    bool loading = false;
    String? errorMsg;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
                  gradient: const LinearGradient(colors: [_green, _greenLight]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.confirmation_number_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 16),
              Text('Resgatar Cupom', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.grey.shade900)),
              const SizedBox(height: 6),
              Text(
                'Digite o código promocional para\ndesbloquear recursos premium',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 3, color: Colors.grey.shade900),
                decoration: InputDecoration(
                  hintText: 'EX: LISTA2026',
                  hintStyle: TextStyle(color: Colors.grey.shade300, letterSpacing: 2, fontWeight: FontWeight.w500),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _green, width: 2),
                  ),
                  errorText: errorMsg,
                  prefixIcon: const Icon(Icons.vpn_key_rounded, color: _green),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          final code = controller.text.trim();
                          if (code.isEmpty) {
                            setBS(() => errorMsg = 'Digite um código');
                            return;
                          }
                          setBS(() {
                            loading = true;
                            errorMsg = null;
                          });
                          try {
                            final result = await ListaSubscriptionService.redeemCoupon(code);
                            if (result['success'] == true) {
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) {
                                _showSuccessDialog(result['message'] ?? 'Cupom aplicado!');
                              }
                            } else {
                              setBS(() {
                                loading = false;
                                errorMsg = result['error'] ?? 'Erro ao resgatar';
                              });
                            }
                          } catch (e) {
                            setBS(() {
                              loading = false;
                              errorMsg = 'Erro de conexão. Tente novamente.';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 4,
                    shadowColor: _green.withValues(alpha: 0.4),
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

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: _green, size: 40),
            ),
            const SizedBox(height: 16),
            Text('Cupom Resgatado! 🎉', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.grey.shade900)),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, true); // Return to previous screen with refresh
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF4CAF50)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
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
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                    const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 40),
                    const SizedBox(height: 10),
                    const Text(
                      'Lista Inteligente\nPremium',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, height: 1.2),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Compare preços, crie alertas e economize\ncom supermercados da sua região',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Trial expired notice ──────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer_off_rounded, color: Colors.orange.shade700, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Período gratuito encerrado',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.orange.shade900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Assine para continuar usando todas as funcionalidades.',
                            style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Plans ───────────────────────────────────────
            if (_packages.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    ..._packages.map((pkg) {
                      final isMonthly = pkg.packageType == PackageType.monthly;
                      return Expanded(
                        child: _buildPlanCard(
                          title: isMonthly ? 'Mensal' : 'Anual',
                          price: pkg.storeProduct.priceString,
                          period: isMonthly ? '/mês' : '/ano',
                          savings: isMonthly ? null : 'Economia de 33%',
                          popular: !isMonthly,
                          onTap: _loading ? null : () => _handlePurchase(pkg),
                        ),
                      );
                    }),
                  ].expand((w) => [w, const SizedBox(width: 12)]).toList()
                    ..removeLast(),
                ),
              ),
            ] else ...[
              // Fallback when packages aren't loaded
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildPlanCard(
                        title: 'Mensal',
                        price: 'R\$ 9,90',
                        period: '/mês',
                        popular: false,
                        onTap: kIsWeb ? _showWebMessage : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildPlanCard(
                        title: 'Anual',
                        price: 'R\$ 79,90',
                        period: '/ano',
                        savings: 'Economia de 33%',
                        popular: true,
                        onTap: kIsWeb ? _showWebMessage : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // ── Free vs Premium comparison ──────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Compare os planos', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.grey.shade900)),
                    const SizedBox(height: 12),
                    _buildCompareRow('Listas de compras', '1', 'Ilimitadas', true),
                    _buildCompareRow('Itens por lista', '15', 'Ilimitados', true),
                    _buildCompareRow('Buscar produtos', '✅', '✅', false),
                    _buildCompareRow('Marcar comprado', '✅', '✅', false),
                    _buildCompareRow('Estimativa de preço', '❌', '✅', true),
                    _buildCompareRow('Comparar preços', '❌', '✅', true),
                    _buildCompareRow('Alertas de preço', '❌', '✅', true),
                    _buildCompareRow('Scanner de cupom', '❌', '✅', true),
                    _buildCompareRow('Reportar preço', '❌', '✅', true),
                    _buildCompareRow('Cartão economia', '❌', '✅', true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Coupon button ─────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showCouponDialog,
                  icon: const Icon(Icons.confirmation_number_rounded, size: 18),
                  label: const Text('Tenho um cupom', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _green,
                    side: const BorderSide(color: _green, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),

            // ── Restore purchases ──────────────────────────
            if (!kIsWeb) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  onPressed: _loading ? null : _handleRestore,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Restaurar compras', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey.shade500),
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
    required String title,
    required String price,
    required String period,
    String? savings,
    bool popular = false,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: popular
            ? const LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)])
            : const LinearGradient(colors: [Color(0xFF37474F), Color(0xFF455A64)]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: (popular ? _green : Colors.grey).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          if (popular)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: const BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
              ),
              child: const Text('⭐ Melhor valor', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black)),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 8),
                Text(price, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24)),
                Text(period, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                if (savings != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(savings, style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: popular ? _green : Colors.grey.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: _loading
                        ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: popular ? _green : Colors.grey))
                        : const Text('Assinar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompareRow(String feature, String free, String premium, bool highlight) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(feature, style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: highlight ? FontWeight.w600 : FontWeight.w400)),
          ),
          Expanded(child: Text(free, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey.shade500))),
          Expanded(
            child: Text(
              premium,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: highlight ? _green : Colors.grey.shade700, fontWeight: highlight ? FontWeight.w700 : FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  void _showWebMessage() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Assinatura via App', style: TextStyle(color: Colors.grey.shade900)),
        content: Text(
          'As assinaturas são processadas pela App Store / Google Play.\n\nAbra o Condomeet no seu celular para assinar.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendi', style: TextStyle(color: _green, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
