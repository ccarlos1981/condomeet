import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/features/garagem/garagem_service.dart';
import 'package:condomeet/features/garagem/presentation/widgets/garagem_onboarding_popup.dart';

class GaragemHomeScreen extends StatefulWidget {
  const GaragemHomeScreen({super.key});

  @override
  State<GaragemHomeScreen> createState() => _GaragemHomeScreenState();
}

class _GaragemHomeScreenState extends State<GaragemHomeScreen>
    with SingleTickerProviderStateMixin {
  final _service = GaragemService();
  late TabController _tabController;

  List<Map<String, dynamic>> _vagas = [];
  List<Map<String, dynamic>> _minhasVagas = [];
  List<Map<String, dynamic>> _minhasReservas = [];
  List<Map<String, dynamic>> _ranking = [];
  Map<String, dynamic>? _trial;
  bool _loading = true;
  String? _condoId;
  bool _showGuide = true;
  static const _guidePrefKey = 'garagem_guide_dismissed';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    final authState = context.read<AuthBloc>().state;
    _condoId = authState.condominiumId;
    _loadData();
    _loadGuideState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GaragemOnboardingPopup.showIfNeeded(context);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_condoId == null) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _service.listVagas(_condoId!),
        _service.listMinhasVagas(),
        _service.listMinhasReservas(),
        _service.getRanking(_condoId!),
        _service.checkTrial(_condoId!),
      ]);
      if (mounted) {
        setState(() {
          _vagas = results[0] as List<Map<String, dynamic>>;
          _minhasVagas = results[1] as List<Map<String, dynamic>>;
          _minhasReservas = results[2] as List<Map<String, dynamic>>;
          _ranking = results[3] as List<Map<String, dynamic>>;
          _trial = results[4] as Map<String, dynamic>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('🅿️ Garagem', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline_rounded, color: Colors.grey.shade500),
            tooltip: 'Como funciona?',
            onPressed: () {
              GaragemOnboardingPopup.showAlways(context);
              _showGuideAgain();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Disponíveis'),
            Tab(text: 'Minhas Vagas'),
            Tab(text: 'Reservas'),
            Tab(text: 'Ranking'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_showGuide) _buildStepGuide(),
                if (_trial != null) _buildTrialBanner(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildVagasDisponiveis(),
                      _buildMinhasVagas(),
                      _buildMinhasReservas(),
                      _buildRanking(),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/garagem-cadastro').then((_) => _loadData()),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Cadastrar Vaga', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ── Trial Banner ──
  Widget _buildTrialBanner() {
    final daysLeft = _trial?['days_left'] ?? 0;
    final isActive = _trial?['is_active'] == true;

    if (!isActive) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        color: Colors.red.shade50,
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Período gratuito encerrado. Entre em contato para ativar o módulo.',
                style: TextStyle(color: Colors.red.shade800, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.green.shade400, Colors.green.shade600]),
      ),
      child: Row(
        children: [
          const Icon(Icons.celebration, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '🎉 60 dias grátis! Faltam $daysLeft dias.',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 1: Vagas Disponíveis ──
  Widget _buildVagasDisponiveis() {
    if (_vagas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_parking, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Nenhuma vaga disponível', style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Seja o primeiro a cadastrar!', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _vagas.length,
        itemBuilder: (context, index) => _buildVagaCard(_vagas[index]),
      ),
    );
  }

  Widget _buildVagaCard(Map<String, dynamic> vaga) {
    final perfil = vaga['perfil'] as Map<String, dynamic>?;
    final tipo = vaga['tipo_vaga'] as String? ?? 'carro_grande';
    final tipoIcon = tipo == 'moto' ? Icons.two_wheeler
        : tipo == 'carro_pequeno' ? Icons.directions_car
        : Icons.directions_car_filled;
    final tipoLabel = tipo == 'moto' ? 'Moto'
        : tipo == 'carro_pequeno' ? 'Carro Pequeno'
        : 'Carro Grande';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.pushNamed(context, '/garagem-detalhe', arguments: vaga['id']).then((_) => _loadData()),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Ícone tipo da vaga
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(tipoIcon, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vaga ${vaga['numero_vaga']}',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$tipoLabel · ${perfil?['nome_completo'] ?? 'Morador'}',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    if (vaga['descricao'] != null && (vaga['descricao'] as String).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          vaga['descricao'],
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              // Preço
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if ((vaga['preco_hora'] ?? 0) > 0)
                    Text(
                      'R\$ ${(vaga['preco_hora'] as num).toStringAsFixed(0)}/h',
                      style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  if ((vaga['preco_dia'] ?? 0) > 0)
                    Text(
                      'R\$ ${(vaga['preco_dia'] as num).toStringAsFixed(0)}/dia',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  if ((vaga['preco_mes'] ?? 0) > 0)
                    Text(
                      'R\$ ${(vaga['preco_mes'] as num).toStringAsFixed(0)}/mês',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tab 2: Minhas Vagas ──
  Widget _buildMinhasVagas() {
    if (_minhasVagas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.garage, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Você ainda não cadastrou vagas', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text('💰 Sua vaga pode gerar até R\$ 500/mês!', style: TextStyle(fontSize: 14, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _minhasVagas.length,
        itemBuilder: (context, index) {
          final v = _minhasVagas[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            child: ListTile(
              contentPadding: const EdgeInsets.all(14),
              leading: CircleAvatar(
                backgroundColor: v['ativo'] == true ? Colors.green.shade100 : Colors.grey.shade200,
                child: Icon(
                  Icons.local_parking,
                  color: v['ativo'] == true ? Colors.green.shade700 : Colors.grey,
                ),
              ),
              title: Text('Vaga ${v['numero_vaga']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                v['ativo'] == true ? 'Ativa' : 'Desativada',
                style: TextStyle(color: v['ativo'] == true ? Colors.green : Colors.grey),
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (action) async {
                  if (action == 'toggle') {
                    await _service.toggleVaga(v['id'], !(v['ativo'] == true));
                    _loadData();
                  } else if (action == 'edit') {
                    Navigator.pushNamed(context, '/garagem-cadastro', arguments: v['id']).then((_) => _loadData());
                  } else if (action == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Excluir vaga?'),
                        content: const Text('Essa ação não pode ser desfeita.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await _service.deleteVaga(v['id']);
                      _loadData();
                    }
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(v['ativo'] == true ? 'Desativar' : 'Ativar'),
                  ),
                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                  const PopupMenuItem(value: 'delete', child: Text('Excluir', style: TextStyle(color: Colors.red))),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Tab 3: Minhas Reservas ──
  Widget _buildMinhasReservas() {
    if (_minhasReservas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Nenhuma reserva', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _minhasReservas.length,
        itemBuilder: (context, index) {
          final r = _minhasReservas[index];
          final status = r['status'] as String? ?? 'pendente';
          final statusColor = status == 'confirmado' ? Colors.green
              : status == 'pendente' ? Colors.orange
              : status == 'finalizado' ? Colors.blue
              : Colors.red;
          final statusLabel = status == 'confirmado' ? '✅ Confirmada'
              : status == 'pendente' ? '⏳ Pendente'
              : status == 'finalizado' ? '✔️ Finalizada'
              : status == 'cancelado' ? '❌ Cancelada'
              : '⚠️ Problema';

          final inicio = DateTime.tryParse(r['inicio'] ?? '');
          final fim = DateTime.tryParse(r['fim'] ?? '');
          final garage = r['garages'] as Map<String, dynamic>?;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Vaga ${garage?['numero_vaga'] ?? ''}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(statusLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (inicio != null && fim != null)
                    Text(
                      '${_formatDate(inicio)} → ${_formatDate(fim)}',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  if (r['placa'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('🚗 ${r['placa']} · ${r['modelo'] ?? ''} · ${r['cor'] ?? ''}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    ),
                  if ((r['valor_total'] ?? 0) > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'R\$ ${(r['valor_total'] as num).toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                      ),
                    ),
                  if (status == 'pendente' || status == 'confirmado')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () async {
                              await _service.cancelarReserva(r['id'], _condoId!);
                              _loadData();
                            },
                            icon: const Icon(Icons.cancel_outlined, size: 18),
                            label: const Text('Cancelar'),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                          ),
                          if (status == 'confirmado')
                            TextButton.icon(
                              onPressed: () async {
                                await _service.reportarProblema(r['id']);
                                _loadData();
                              },
                              icon: const Icon(Icons.report_problem_outlined, size: 18),
                              label: const Text('Problema'),
                              style: TextButton.styleFrom(foregroundColor: Colors.orange),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Tab 4: Ranking ──
  Widget _buildRanking() {
    if (_ranking.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events, size: 80, color: Colors.amber.shade200),
            const SizedBox(height: 16),
            Text('Nenhum ranking ainda', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text('Cadastre sua vaga e comece a ganhar!', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _ranking.length,
      itemBuilder: (context, index) {
        final r = _ranking[index];
        final medal = index == 0 ? '🥇' : index == 1 ? '🥈' : index == 2 ? '🥉' : '${index + 1}º';

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: index < 3 ? 3 : 1,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Text(medal, style: const TextStyle(fontSize: 28)),
            title: Text(
              r['nome'] ?? 'Morador',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            subtitle: Text('Vaga ${r['vaga']} · ${r['reservas']} reservas'),
            trailing: Text(
              'R\$ ${(r['total'] as double).toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
      _GuideStep('Cadastre sua vaga', Icons.add_box_rounded, 'Informe número, tipo e preço', _minhasVagas.isNotEmpty),
      _GuideStep('Publique e ative', Icons.check_circle_outline, 'Deixe visível para vizinhos', _minhasVagas.any((v) => v['ativo'] == true)),
      _GuideStep('Receba reservas', Icons.bookmark_added, 'Aceite e lucre!', _minhasReservas.isNotEmpty),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF7B2FF7).withValues(alpha: 0.06), const Color(0xFF9B5FFF).withValues(alpha: 0.1)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7B2FF7).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.route_rounded, color: const Color(0xFF7B2FF7), size: 18),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Como começar',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF4A148C)),
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
            return _buildStepItem(step, i + 1, isLast);
          }),
        ],
      ),
    );
  }

  Widget _buildStepItem(_GuideStep step, int number, bool isLast) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checkbox circle
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
                      '$number',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade500),
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: step.done ? Colors.grey.shade500 : Colors.grey.shade900,
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
  }
}

class _GuideStep {
  final String title;
  final IconData icon;
  final String subtitle;
  final bool done;
  const _GuideStep(this.title, this.icon, this.subtitle, this.done);
}
