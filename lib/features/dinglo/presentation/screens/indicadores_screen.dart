import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../dinglo_theme.dart';
import '../../plano_service.dart';

class IndicadoresScreen extends StatefulWidget {
  const IndicadoresScreen({super.key});
  @override
  State<IndicadoresScreen> createState() => _IndicadoresScreenState();
}

class _IndicadoresScreenState extends State<IndicadoresScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  bool _isPremium = false;
  DateTime _mesSelecionado = DateTime.now();
  double _totalReceitas = 0;
  double _totalDespesas = 0;
  double _receitasMesAnterior = 0;
  double _despesasMesAnterior = 0;
  Map<String, double> _despesasPorCategoria = {};
  Map<String, double> _receitasPorCategoria = {};
  Map<String, String> _categoriaCores = {};
  List<_MesResumo> _historico = [];
  late TabController _tabCtrl;

  static const _meses = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      _isPremium = await PlanoService.isPremium();

      final firstDay = DateTime(_mesSelecionado.year, _mesSelecionado.month, 1).toIso8601String().split('T')[0];
      final lastDay = DateTime(_mesSelecionado.year, _mesSelecionado.month + 1, 0).toIso8601String().split('T')[0];

      // Previous month
      final prevMonth = DateTime(_mesSelecionado.year, _mesSelecionado.month - 1, 1);
      final prevFirst = prevMonth.toIso8601String().split('T')[0];
      final prevLast = DateTime(prevMonth.year, prevMonth.month + 1, 0).toIso8601String().split('T')[0];

      // Current month data
      final data = await _supabase.from('dinglo_lancamentos')
          .select('tipo, valor, dinglo_categorias(nome, cor)')
          .eq('user_id', userId)
          .gte('data_lancamento', firstDay)
          .lte('data_lancamento', lastDay);

      // Previous month data
      final prevData = await _supabase.from('dinglo_lancamentos')
          .select('tipo, valor')
          .eq('user_id', userId)
          .gte('data_lancamento', prevFirst)
          .lte('data_lancamento', prevLast);

      double rec = 0, desp = 0, prevRec = 0, prevDesp = 0;
      Map<String, double> porCatDesp = {};
      Map<String, double> porCatRec = {};
      Map<String, String> catCores = {};

      for (final l in data) {
        final v = (l['valor'] as num?)?.toDouble() ?? 0;
        final catNome = l['dinglo_categorias']?['nome'] ?? 'Outros';
        final catCor = l['dinglo_categorias']?['cor'] ?? '#A9A9A9';
        catCores[catNome] = catCor;
        if (l['tipo'] == 'receita') {
          rec += v;
          porCatRec[catNome] = (porCatRec[catNome] ?? 0) + v;
        } else {
          desp += v;
          porCatDesp[catNome] = (porCatDesp[catNome] ?? 0) + v;
        }
      }

      for (final l in prevData) {
        final v = (l['valor'] as num?)?.toDouble() ?? 0;
        if (l['tipo'] == 'receita') prevRec += v; else prevDesp += v;
      }

      // Last 6 months history
      List<_MesResumo> hist = [];
      for (int i = 5; i >= 0; i--) {
        final m = DateTime(_mesSelecionado.year, _mesSelecionado.month - i, 1);
        final f = m.toIso8601String().split('T')[0];
        final l = DateTime(m.year, m.month + 1, 0).toIso8601String().split('T')[0];
        final hData = await _supabase.from('dinglo_lancamentos')
            .select('tipo, valor').eq('user_id', userId).gte('data_lancamento', f).lte('data_lancamento', l);
        double hRec = 0, hDesp = 0;
        for (final h in hData) {
          final v = (h['valor'] as num?)?.toDouble() ?? 0;
          if (h['tipo'] == 'receita') hRec += v; else hDesp += v;
        }
        hist.add(_MesResumo(_meses[m.month - 1], hRec, hDesp));
      }

      if (mounted) setState(() {
        _totalReceitas = rec;
        _totalDespesas = desp;
        _receitasMesAnterior = prevRec;
        _despesasMesAnterior = prevDesp;
        _despesasPorCategoria = porCatDesp;
        _receitasPorCategoria = porCatRec;
        _categoriaCores = catCores;
        _historico = hist;
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _changeMonth(int delta) {
    setState(() => _mesSelecionado = DateTime(_mesSelecionado.year, _mesSelecionado.month + delta, 1));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final saldo = _totalReceitas - _totalDespesas;

    return Scaffold(
      backgroundColor: DingloTheme.background,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            backgroundColor: DingloTheme.primary,
            foregroundColor: Colors.white,
            pinned: true,
            expandedHeight: 180,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6), Color(0xFF06B6D4)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
                    child: Column(
                      children: [
                        // Month selector
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          GestureDetector(
                            onTap: () => _changeMonth(-1),
                            child: const Icon(Icons.chevron_left_rounded, color: Colors.white70, size: 28),
                          ),
                          const SizedBox(width: 12),
                          Text('${_meses[_mesSelecionado.month - 1]} ${_mesSelecionado.year}',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white)),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => _changeMonth(1),
                            child: const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 28),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        // Summary row
                        Row(children: [
                          _headerStat('Receitas', _totalReceitas, Icons.arrow_upward_rounded),
                          _headerStat('Despesas', _totalDespesas, Icons.arrow_downward_rounded),
                          _headerStat('Saldo', saldo, Icons.account_balance_wallet_rounded),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            title: const Text('Relatórios', style: TextStyle(fontWeight: FontWeight.w700)),
            bottom: TabBar(
              controller: _tabCtrl,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: const [
                Tab(text: 'Resumo'),
                Tab(text: 'Categorias'),
                Tab(text: 'Insights'),
              ],
            ),
          ),
        ],
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: DingloTheme.primary))
            : TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildResumoTab(),
                  _buildCategoriasTab(),
                  _buildInsightsTab(),
                ],
              ),
      ),
    );
  }

  Widget _headerStat(String label, double value, IconData icon) {
    return Expanded(
      child: Column(children: [
        Icon(icon, color: Colors.white60, size: 16),
        const SizedBox(height: 4),
        Text(DingloTheme.formatCurrencyCompact(value),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
      ]),
    );
  }

  // ── Tab 1: Resumo ──────────────────────────────────────────────────

  Widget _buildResumoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Monthly comparison
        _buildMonthComparison(),
        const SizedBox(height: 20),

        // Trend chart
        if (_historico.isNotEmpty) ...[
          const Text('Evolução (6 meses)', style: DingloTheme.heading2),
          const SizedBox(height: 12),
          _buildTrendChart(),
        ],
        const SizedBox(height: 40),
      ]),
    );
  }

  Widget _buildMonthComparison() {
    final despDiff = _despesasMesAnterior > 0
        ? ((_totalDespesas - _despesasMesAnterior) / _despesasMesAnterior * 100)
        : 0.0;
    final recDiff = _receitasMesAnterior > 0
        ? ((_totalReceitas - _receitasMesAnterior) / _receitasMesAnterior * 100)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: DingloTheme.cardRadius, boxShadow: DingloTheme.cardShadow),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.compare_arrows_rounded, color: DingloTheme.primary, size: 20),
          const SizedBox(width: 8),
          const Text('vs mês anterior', style: DingloTheme.heading3),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _compareCard('Receitas', _receitasMesAnterior, _totalReceitas, recDiff, DingloTheme.income)),
          const SizedBox(width: 10),
          Expanded(child: _compareCard('Despesas', _despesasMesAnterior, _totalDespesas, despDiff, DingloTheme.expense)),
        ]),
      ]),
    );
  }

  Widget _compareCard(String label, double prev, double curr, double pct, Color color) {
    final isUp = pct > 0;
    final isExpense = label == 'Despesas';
    // For expenses: up is bad (red), down is good (green)
    // For income: up is good (green), down is bad (red)
    final trendColor = isExpense ? (isUp ? DingloTheme.expense : DingloTheme.income) : (isUp ? DingloTheme.income : DingloTheme.expense);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(DingloTheme.formatCurrencyCompact(curr),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 4),
        if (prev > 0)
          Row(children: [
            Icon(isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: trendColor, size: 14),
            const SizedBox(width: 4),
            Text('${pct.abs().toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: trendColor)),
          ])
        else
          Text('Sem dados anteriores', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
      ]),
    );
  }

  // ── Tab 2: Categorias ─────────────────────────────────────────────

  Widget _buildCategoriasTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Pie chart (visual)
        if (_despesasPorCategoria.isNotEmpty) ...[
          const Text('Despesas por categoria', style: DingloTheme.heading2),
          const SizedBox(height: 16),
          _buildPieChart(),
          const SizedBox(height: 20),
          _buildCategoryBars(),
        ] else ...[
          const SizedBox(height: 60),
          Center(child: Column(children: [
            Icon(Icons.pie_chart_outline_rounded, size: 56, color: DingloTheme.textMuted),
            const SizedBox(height: 12),
            const Text('Nenhuma despesa neste mês', style: DingloTheme.body),
          ])),
        ],

        if (_receitasPorCategoria.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text('Receitas por categoria', style: DingloTheme.heading2),
          const SizedBox(height: 12),
          _buildCategoryList(_receitasPorCategoria, DingloTheme.income),
        ],
        const SizedBox(height: 40),
      ]),
    );
  }

  Widget _buildPieChart() {
    final sorted = _despesasPorCategoria.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = sorted.fold<double>(0, (s, e) => s + e.value);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: DingloTheme.cardRadius, boxShadow: DingloTheme.cardShadow),
      child: Row(children: [
        // Pie
        SizedBox(
          width: 120, height: 120,
          child: CustomPaint(
            painter: _PieChartPainter(
              entries: sorted.map((e) => _PieEntry(e.value / total, DingloTheme.parseColor(_categoriaCores[e.key]))).toList(),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Legend
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: sorted.take(5).map((e) {
            final pct = total > 0 ? (e.value / total * 100) : 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(
                    color: DingloTheme.parseColor(_categoriaCores[e.key]), borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 6),
                Expanded(child: Text(e.key, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                Text('${pct.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: DingloTheme.textMuted)),
              ]),
            );
          }).toList(),
        )),
      ]),
    );
  }

  Widget _buildCategoryBars() {
    final sorted = _despesasPorCategoria.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = sorted.fold<double>(0, (s, e) => s + e.value);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: DingloTheme.cardRadius, boxShadow: DingloTheme.cardShadow),
      child: Column(children: sorted.map((e) {
        final pct = total > 0 ? e.value / total : 0.0;
        final color = DingloTheme.parseColor(_categoriaCores[e.key]);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text(e.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
              Text('${(pct * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: DingloTheme.textSecondary)),
              const SizedBox(width: 8),
              Text(DingloTheme.formatCurrency(e.value), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct, minHeight: 6,
                backgroundColor: color.withValues(alpha: 0.1), color: color,
              ),
            ),
          ]),
        );
      }).toList()),
    );
  }

  Widget _buildCategoryList(Map<String, double> data, Color baseColor) {
    final sorted = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = sorted.fold<double>(0, (s, e) => s + e.value);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: DingloTheme.cardRadius, boxShadow: DingloTheme.cardShadow),
      child: Column(children: sorted.map((e) {
        final pct = total > 0 ? e.value / total : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Expanded(child: Text(e.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
            Text('${(pct * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            const SizedBox(width: 8),
            Text(DingloTheme.formatCurrency(e.value), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: baseColor)),
          ]),
        );
      }).toList()),
    );
  }

  // ── Tab 3: Insights (Premium) ─────────────────────────────────────

  Widget _buildInsightsTab() {
    if (!_isPremium) {
      return _buildPremiumLock();
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ..._generateInsights(),
        const SizedBox(height: 40),
      ]),
    );
  }

  Widget _buildPremiumLock() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: DingloTheme.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              'Insights Inteligentes',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: DingloTheme.textPrimary, letterSpacing: -0.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'Receba análises automáticas dos seus gastos, tendências e dicas personalizadas para economizar.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: DingloTheme.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 8),
            // Preview blurred insights
            ..._generatePreviewInsights(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/dinglo/planos'),
                icon: const Icon(Icons.star_rounded, size: 18),
                label: const Text('Desbloquear com Plus', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DingloTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                  shadowColor: DingloTheme.primary.withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _generatePreviewInsights() {
    return [
      const SizedBox(height: 16),
      _buildBlurredInsight('💡', 'Você gastou mais em...', 'Upgrade para ver'),
      _buildBlurredInsight('📊', 'Sua maior economia foi...', 'Upgrade para ver'),
    ];
  }

  Widget _buildBlurredInsight(String emoji, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade400)),
          Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade300)),
        ])),
        Icon(Icons.lock_rounded, color: Colors.grey.shade300, size: 18),
      ]),
    );
  }

  List<Widget> _generateInsights() {
    final insights = <Widget>[];
    final saldo = _totalReceitas - _totalDespesas;

    // 1. Balance health
    if (saldo >= 0) {
      insights.add(_insightCard(
        '✅', 'Saldo positivo!',
        'Parabéns! Você está gastando menos do que ganha este mês. Saldo: ${DingloTheme.formatCurrency(saldo)}',
        DingloTheme.income,
      ));
    } else {
      insights.add(_insightCard(
        '⚠️', 'Atenção: saldo negativo',
        'Suas despesas superaram suas receitas em ${DingloTheme.formatCurrency(saldo.abs())}. Revise seus gastos!',
        DingloTheme.expense,
      ));
    }

    // 2. Biggest expense category
    if (_despesasPorCategoria.isNotEmpty) {
      final biggest = _despesasPorCategoria.entries.reduce((a, b) => a.value > b.value ? a : b);
      final total = _despesasPorCategoria.values.fold<double>(0, (s, v) => s + v);
      final pct = (biggest.value / total * 100).toStringAsFixed(0);
      insights.add(_insightCard(
        '🏷️', 'Maior gasto: ${biggest.key}',
        'Representa $pct% das suas despesas (${DingloTheme.formatCurrency(biggest.value)}). Considere definir um limite.',
        DingloTheme.primary,
      ));
    }

    // 3. Comparison with previous month
    if (_despesasMesAnterior > 0) {
      final diff = _totalDespesas - _despesasMesAnterior;
      if (diff > 0) {
        final pct = (diff / _despesasMesAnterior * 100).toStringAsFixed(0);
        insights.add(_insightCard(
          '📈', 'Despesas aumentaram $pct%',
          'Você gastou ${DingloTheme.formatCurrency(diff)} a mais que o mês passado. Fique de olho!',
          DingloTheme.warning,
        ));
      } else {
        final pct = (diff.abs() / _despesasMesAnterior * 100).toStringAsFixed(0);
        insights.add(_insightCard(
          '📉', 'Despesas reduziram $pct%',
          'Excelente! Você economizou ${DingloTheme.formatCurrency(diff.abs())} em relação ao mês passado.',
          DingloTheme.income,
        ));
      }
    }

    // 4. Income analysis
    if (_receitasMesAnterior > 0 && _totalReceitas > 0) {
      final diff = _totalReceitas - _receitasMesAnterior;
      if (diff > 0) {
        insights.add(_insightCard(
          '💰', 'Receitas aumentaram!',
          'Suas receitas cresceram ${DingloTheme.formatCurrency(diff)} comparado ao mês anterior.',
          DingloTheme.income,
        ));
      }
    }

    // 5. Savings rate
    if (_totalReceitas > 0) {
      final taxaPoupanca = (((_totalReceitas - _totalDespesas) / _totalReceitas) * 100);
      if (taxaPoupanca > 20) {
        insights.add(_insightCard(
          '🎯', 'Taxa de poupança: ${taxaPoupanca.toStringAsFixed(0)}%',
          'Está acima dos 20% recomendados! Continue assim.',
          DingloTheme.income,
        ));
      } else if (taxaPoupanca > 0) {
        insights.add(_insightCard(
          '💡', 'Taxa de poupança: ${taxaPoupanca.toStringAsFixed(0)}%',
          'O ideal é poupar pelo menos 20% da renda. Tente reduzir despesas não essenciais.',
          DingloTheme.warning,
        ));
      }
    }

    // 6. No data
    if (insights.isEmpty) {
      insights.add(_insightCard(
        '📝', 'Sem dados suficientes',
        'Cadastre mais lançamentos para receber insights personalizados sobre suas finanças.',
        DingloTheme.textMuted,
      ));
    }

    return insights;
  }

  Widget _insightCard(String emoji, String title, String description, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: DingloTheme.cardRadius,
        boxShadow: DingloTheme.cardShadow,
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: DingloTheme.textPrimary)),
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(fontSize: 12, color: DingloTheme.textSecondary, height: 1.4)),
        ])),
      ]),
    );
  }

  // ── Shared: Trend chart ───────────────────────────────────────────

  Widget _buildTrendChart() {
    final maxVal = _historico.fold<double>(0, (m, e) => max(m, max(e.receitas, e.despesas)));
    const chartHeight = 140.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: DingloTheme.cardRadius, boxShadow: DingloTheme.cardShadow),
      child: Column(children: [
        SizedBox(
          height: chartHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _historico.map((m) {
              final recH = maxVal > 0 ? (m.receitas / maxVal * (chartHeight - 30)) : 0.0;
              final despH = maxVal > 0 ? (m.despesas / maxVal * (chartHeight - 30)) : 0.0;
              return Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(width: 10, height: recH, decoration: BoxDecoration(
                        color: DingloTheme.income, borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 2),
                    Container(width: 10, height: despH, decoration: BoxDecoration(
                        color: DingloTheme.expense, borderRadius: BorderRadius.circular(3))),
                  ]),
                  const SizedBox(height: 6),
                  Text(m.mes, style: const TextStyle(fontSize: 10, color: DingloTheme.textMuted)),
                ]),
              ));
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: DingloTheme.income, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 4), const Text('Receitas', style: TextStyle(fontSize: 10, color: DingloTheme.textMuted)),
          const SizedBox(width: 16),
          Container(width: 10, height: 10, decoration: BoxDecoration(color: DingloTheme.expense, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 4), const Text('Despesas', style: TextStyle(fontSize: 10, color: DingloTheme.textMuted)),
        ]),
      ]),
    );
  }
}

// ── Custom Pie Chart Painter ──────────────────────────────────────

class _PieEntry {
  final double fraction;
  final Color color;
  _PieEntry(this.fraction, this.color);
}

class _PieChartPainter extends CustomPainter {
  final List<_PieEntry> entries;
  _PieChartPainter({required this.entries});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    double startAngle = -pi / 2;

    for (final entry in entries) {
      final sweepAngle = 2 * pi * entry.fraction;
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = entry.color;
      canvas.drawArc(rect, startAngle, sweepAngle, true, paint);
      startAngle += sweepAngle;
    }

    // Center hole (donut effect)
    final holePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width * 0.3, holePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _MesResumo {
  final String mes;
  final double receitas;
  final double despesas;
  _MesResumo(this.mes, this.receitas, this.despesas);
}
