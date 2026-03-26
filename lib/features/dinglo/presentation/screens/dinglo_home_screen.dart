import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../dinglo/dinglo_theme.dart';
import '../widgets/dinglo_welcome_dialog.dart';

class DingloHomeScreen extends StatefulWidget {
  const DingloHomeScreen({super.key});

  @override
  State<DingloHomeScreen> createState() => _DingloHomeScreenState();
}

class _DingloHomeScreenState extends State<DingloHomeScreen> {
  final _supabase = Supabase.instance.client;
  int _currentTab = 0;
  bool _loading = true;
  bool _showBalance = true;

  double _saldoTotal = 0;
  double _receitasMes = 0;
  double _despesasMes = 0;
  int _contasCount = 0;
  int _cartoesCount = 0;
  List<Map<String, dynamic>> _recentTransactions = [];
  bool _showGuide = true;
  static const _guidePrefKey = 'dinglo_guide_dismissed';

  @override
  void initState() {
    super.initState();
    _loadDashboardData().then((_) {
      if (mounted) DingloWelcomeDialog.showIfFirstTime(context);
    });
    _loadGuideState();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _loading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      final now = DateTime.now();
      final firstDay = DateTime(now.year, now.month, 1).toIso8601String().split('T')[0];
      final lastDay = DateTime(now.year, now.month + 1, 0).toIso8601String().split('T')[0];

      // Parallel fetches
      final results = await Future.wait([
        _supabase.from('dinglo_contas').select('saldo_inicial').eq('user_id', userId).eq('ativo', true),
        _supabase.from('dinglo_lancamentos').select('tipo, valor, status')
            .eq('user_id', userId)
            .gte('data_lancamento', firstDay)
            .lte('data_lancamento', lastDay),
        _supabase.from('dinglo_contas').select('id').eq('user_id', userId).eq('ativo', true),
        _supabase.from('dinglo_cartoes').select('id').eq('user_id', userId).eq('ativo', true),
        _supabase.from('dinglo_lancamentos').select('*, dinglo_categorias(nome, icone, cor)')
            .eq('user_id', userId)
            .order('data_lancamento', ascending: false)
            .limit(5),
      ]);

      final contas = results[0] as List;
      final lancamentos = results[1] as List;
      final contasList = results[2] as List;
      final cartoesList = results[3] as List;
      final recent = results[4] as List;

      double saldo = 0;
      for (final c in contas) {
        saldo += (c['saldo_inicial'] as num?)?.toDouble() ?? 0;
      }

      double receitas = 0, despesas = 0;
      for (final l in lancamentos) {
        final valor = (l['valor'] as num?)?.toDouble() ?? 0;
        if (l['tipo'] == 'receita') {
          receitas += valor;
        } else {
          despesas += valor;
        }
      }

      // Adjust saldo with realized transactions
      for (final l in lancamentos) {
        final valor = (l['valor'] as num?)?.toDouble() ?? 0;
        if (l['status'] == 'realizado') {
          if (l['tipo'] == 'receita') {
            saldo += valor;
          } else {
            saldo -= valor;
          }
        }
      }

      if (mounted) {
        setState(() {
          _saldoTotal = saldo;
          _receitasMes = receitas;
          _despesasMes = despesas;
          _contasCount = contasList.length;
          _cartoesCount = cartoesList.length;
          _recentTransactions = List<Map<String, dynamic>>.from(recent);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        primaryColor: DingloTheme.primary,
        scaffoldBackgroundColor: DingloTheme.background,
        fontFamily: 'Inter',
      ),
      child: Scaffold(
        backgroundColor: DingloTheme.background,
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: DingloTheme.primary))
            : _buildBody(),
        bottomNavigationBar: _buildBottomNav(),
        floatingActionButton: _currentTab == 0
            ? FloatingActionButton(
                onPressed: () => Navigator.pushNamed(context, '/dinglo/lancamento').then((_) => _loadDashboardData()),
                backgroundColor: DingloTheme.primary,
                elevation: 6,
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
              )
            : null,
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentTab) {
      case 0: return _buildDashboard();
      case 1: return _buildMovimentos();
      case 2: return _buildPainel();
      default: return _buildDashboard();
    }
  }

  Widget _buildDashboard() {
    return RefreshIndicator(
      color: DingloTheme.primary,
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 16),
            if (_showGuide) _buildStepGuide(),
            _buildQuickActions(),
            const SizedBox(height: 16),
            _buildSummaryCards(),
            const SizedBox(height: 16),
            _buildRecentTransactions(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: DingloTheme.headerGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '💰 Meu Bolso',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/dinglo/onboarding'),
                    child: const Icon(
                      Icons.route_rounded,
                      color: Colors.white70,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => const DingloWelcomeDialog(),
                      );
                      _showGuideAgain();
                    },
                    child: const Icon(
                      Icons.help_outline_rounded,
                      color: Colors.white70,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => setState(() => _showBalance = !_showBalance),
                    child: Icon(
                      _showBalance ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      color: Colors.white70,
                      size: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Balance
              const Text(
                'Saldo total',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 4),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _showBalance ? DingloTheme.formatCurrency(_saldoTotal) : 'R\$ ••••••',
                  key: ValueKey(_showBalance),
                  style: DingloTheme.money,
                ),
              ),
              const SizedBox(height: 20),
              // Income / Expense row
              Row(
                children: [
                  Expanded(child: _buildMiniStat(Icons.arrow_upward_rounded, 'Receitas', _receitasMes, DingloTheme.income)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildMiniStat(Icons.arrow_downward_rounded, 'Despesas', _despesasMes, DingloTheme.expense)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
                Text(
                  _showBalance ? DingloTheme.formatCurrency(value) : '••••',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      _QuickAction('Contas', Icons.account_balance_rounded, '/dinglo/contas'),
      _QuickAction('Cartões', Icons.credit_card_rounded, '/dinglo/cartoes'),
      _QuickAction('Categorias', Icons.category_rounded, '/dinglo/categorias'),
      _QuickAction('Metas', Icons.flag_rounded, '/dinglo/metas'),
      _QuickAction('Despesas\nFixas', Icons.repeat_rounded, '/dinglo/despesas-fixas'),
      _QuickAction('Relatórios', Icons.bar_chart_rounded, '/dinglo/indicadores'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.1,
        ),
        itemCount: actions.length,
        itemBuilder: (_, i) => _buildQuickActionCard(actions[i]),
      ),
    );
  }

  Widget _buildQuickActionCard(_QuickAction action) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, action.route).then((_) => _loadDashboardData()),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: DingloTheme.cardRadius,
          boxShadow: DingloTheme.cardShadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: DingloTheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(action.icon, color: DingloTheme.primary, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              action.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: DingloTheme.textPrimary,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildInfoCard(
              Icons.account_balance_rounded,
              '$_contasCount',
              'Contas\nativas',
              DingloTheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildInfoCard(
              Icons.credit_card_rounded,
              '$_cartoesCount',
              'Cartões\nativos',
              DingloTheme.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildInfoCard(
              Icons.compare_arrows_rounded,
              '${_recentTransactions.length}',
              'Últimos\nlançam.',
              DingloTheme.warning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: DingloTheme.cardRadius,
        boxShadow: DingloTheme.cardShadow,
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: DingloTheme.caption),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Últimas movimentações', style: DingloTheme.heading3),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _currentTab = 1),
                child: const Text('Ver tudo',
                    style: TextStyle(color: DingloTheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_recentTransactions.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: DingloTheme.cardRadius,
                boxShadow: DingloTheme.cardShadow,
              ),
              child: Column(
                children: [
                  Icon(Icons.receipt_long_rounded, color: DingloTheme.textMuted, size: 40),
                  const SizedBox(height: 10),
                  const Text('Nenhum lançamento ainda', style: DingloTheme.body),
                  const SizedBox(height: 4),
                  const Text('Toque no + para adicionar', style: DingloTheme.caption),
                ],
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: DingloTheme.cardRadius,
                boxShadow: DingloTheme.cardShadow,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recentTransactions.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                itemBuilder: (_, i) {
                  final tx = _recentTransactions[i];
                  final isReceita = tx['tipo'] == 'receita';
                  final valor = (tx['valor'] as num?)?.toDouble() ?? 0;
                  final categoria = tx['dinglo_categorias'];
                  final catNome = categoria?['nome'] ?? 'Sem categoria';
                  final catIcone = categoria?['icone'];
                  final catCor = categoria?['cor'];

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: DingloTheme.parseColor(catCor).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(DingloTheme.getIcon(catIcone), color: DingloTheme.parseColor(catCor), size: 20),
                    ),
                    title: Text(tx['descricao'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(catNome, style: DingloTheme.caption),
                    trailing: Text(
                      '${isReceita ? '+' : '-'} ${DingloTheme.formatCurrency(valor)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isReceita ? DingloTheme.income : DingloTheme.expense,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // ── Movimentos tab (placeholder → real screen) ──
  Widget _buildMovimentos() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long_rounded, size: 48, color: DingloTheme.textMuted),
          const SizedBox(height: 12),
          const Text('Movimentações', style: DingloTheme.heading2),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/dinglo/movimentos'),
            style: ElevatedButton.styleFrom(backgroundColor: DingloTheme.primary),
            child: const Text('Abrir Movimentações', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Painel tab ──
  Widget _buildPainel() {
    final items = [
      _PainelItem('Contas', Icons.account_balance_rounded, '/dinglo/contas'),
      _PainelItem('Cartões', Icons.credit_card_rounded, '/dinglo/cartoes'),
      _PainelItem('Categorias', Icons.category_rounded, '/dinglo/categorias'),
      _PainelItem('Metas', Icons.flag_rounded, '/dinglo/metas'),
      _PainelItem('Desp. Fixas', Icons.repeat_rounded, '/dinglo/despesas-fixas'),
      _PainelItem('Relatórios', Icons.bar_chart_rounded, '/dinglo/indicadores'),
      _PainelItem('Lançar', Icons.add_circle_outline_rounded, '/dinglo/lancamento'),
      _PainelItem('Movimentos', Icons.swap_horiz_rounded, '/dinglo/movimentos'),
      _PainelItem('Planos', Icons.workspace_premium_rounded, '/dinglo/planos'),
    ];

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: DingloTheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                const Text('Painel', style: DingloTheme.heading1),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.3,
                ),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  return GestureDetector(
                    onTap: () => Navigator.pushNamed(context, item.route).then((_) => _loadDashboardData()),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: i == 0 ? DingloTheme.cardGradient : null,
                        color: i != 0 ? Colors.white : null,
                        borderRadius: DingloTheme.cardRadius,
                        boxShadow: DingloTheme.cardShadow,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(item.icon, color: i == 0 ? Colors.white : DingloTheme.primary, size: 30),
                          const SizedBox(height: 8),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: i == 0 ? Colors.white : DingloTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, 'Início'),
              _buildNavItem(1, Icons.swap_horiz_rounded, 'Movimentos'),
              _buildNavItem(2, Icons.grid_view_rounded, 'Painel'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final selected = _currentTab == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _currentTab = index);
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: selected ? DingloTheme.primary : DingloTheme.textMuted, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? DingloTheme.primary : DingloTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Guide State ──
  Future<void> _loadGuideState() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _showGuide = !(prefs.getBool(_guidePrefKey) ?? false));
    }
  }

  Future<void> _dismissGuide() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guidePrefKey, true);
    if (mounted) setState(() => _showGuide = false);
  }

  void _showGuideAgain() {
    setState(() => _showGuide = true);
  }

  // ── Step-by-Step Checklist Guide ──
  Widget _buildStepGuide() {
    final steps = [
      _DingloGuideStep('Cadastre suas contas', 'Banco, carteira, poupança...', _contasCount > 0),
      _DingloGuideStep('Organize categorias', 'Alimentação, transporte, lazer...', true), // Always has defaults
      _DingloGuideStep('Registre seus gastos', 'Acompanhe para onde vai seu dinheiro', _recentTransactions.isNotEmpty),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [DingloTheme.primary.withValues(alpha: 0.06), DingloTheme.primary.withValues(alpha: 0.12)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DingloTheme.primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.route_rounded, color: DingloTheme.primary, size: 18),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Como começar',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: DingloTheme.textPrimary),
                  ),
                ),
                GestureDetector(
                  onTap: _dismissGuide,
                  child: Icon(Icons.close_rounded, color: Colors.grey.shade400, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...steps.asMap().entries.map((entry) {
              final i = entry.key;
              final step = entry.value;
              final isLast = i == steps.length - 1;
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(
                        color: step.done ? const Color(0xFF00C853) : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: step.done ? const Color(0xFF00C853) : Colors.grey.shade400,
                          width: 2,
                        ),
                      ),
                      child: step.done
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                          : Center(
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade500),
                              ),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: step.done ? Colors.grey.shade500 : DingloTheme.textPrimary,
                              decoration: step.done ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          Text(
                            step.subtitle,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _QuickAction {
  final String label;
  final IconData icon;
  final String route;
  _QuickAction(this.label, this.icon, this.route);
}

class _PainelItem {
  final String label;
  final IconData icon;
  final String route;
  _PainelItem(this.label, this.icon, this.route);
}

class _DingloGuideStep {
  final String title;
  final String subtitle;
  final bool done;
  const _DingloGuideStep(this.title, this.subtitle, this.done);
}
