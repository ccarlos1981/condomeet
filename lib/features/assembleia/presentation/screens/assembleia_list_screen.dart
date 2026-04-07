import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/features/assembleia/domain/models/assembleia_model.dart';

class AssembleiaListScreen extends StatefulWidget {
  const AssembleiaListScreen({super.key});

  @override
  State<AssembleiaListScreen> createState() => _AssembleiaListScreenState();
}

class _AssembleiaListScreenState extends State<AssembleiaListScreen> {
  final _supabase = Supabase.instance.client;
  List<AssembleiaModel> _assembleias = [];
  bool _loading = true;
  String _filtro = 'todas'; // todas, ativas, agendadas, encerradas
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupRealtime();
  }

  @override
  void dispose() {
    if (_channel != null) _supabase.removeChannel(_channel!);
    super.dispose();
  }

  void _setupRealtime() {
    final condoId = context.read<AuthBloc>().state.condominiumId;
    if (condoId == null) return;

    _channel = _supabase
        .channel('assembleias_morador')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'assembleias',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'condominio_id',
            value: condoId,
          ),
          callback: (_) => _loadData(),
        )
        .subscribe();
  }

  Future<void> _loadData() async {
    final condoId = context.read<AuthBloc>().state.condominiumId;
    if (condoId == null) return;

    setState(() => _loading = true);
    try {
      var query = _supabase
          .from('assembleias')
          .select()
          .eq('condominio_id', condoId)
          .neq('status', 'rascunho') // Moradores não veem rascunhos
          .order('created_at', ascending: false);

      final data = await query;
      if (mounted) {
        setState(() {
          _assembleias = (data as List).map((e) => AssembleiaModel.fromMap(e)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<AssembleiaModel> get _filtradas {
    switch (_filtro) {
      case 'ativas':
        return _assembleias.where((a) => a.isLive).toList();
      case 'agendadas':
        return _assembleias.where((a) => a.isScheduled).toList();
      case 'encerradas':
        return _assembleias.where((a) => a.isFinished).toList();
      default:
        return _assembleias;
    }
  }

  @override
  Widget build(BuildContext context) {
    final liveCount = _assembleias.where((a) => a.isLive).length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.groups_outlined, size: 24),
            const SizedBox(width: 8),
            const Text('Assembleias', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            if (liveCount > 0) ...[
              const SizedBox(width: 8),
              _buildLiveBadge(liveCount),
            ],
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.textMain,
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: AppColors.primary,
                    child: _filtradas.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _filtradas.length,
                            itemBuilder: (_, i) => _buildCard(_filtradas[i]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveBadge(int count) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      builder: (_, opacity, child) => Opacity(opacity: opacity, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              '$count AO VIVO',
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'id': 'todas', 'label': 'Todas', 'color': Colors.grey},
      {'id': 'ativas', 'label': '🔴 Ao Vivo', 'color': Colors.red},
      {'id': 'agendadas', 'label': '📅 Agendadas', 'color': Colors.blue},
      {'id': 'encerradas', 'label': '✅ Encerradas', 'color': Colors.green},
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((f) {
            final isActive = _filtro == f['id'];
            final color = f['color'] as MaterialColor;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _filtro = f['id'] as String),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive ? color.shade50 : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive ? color.shade400 : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    f['label'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                      color: isActive ? color.shade700 : Colors.grey.shade500,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        const SizedBox(height: 100),
        Icon(Icons.groups_outlined, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text(
          _filtro == 'todas'
              ? 'Nenhuma assembleia publicada ainda'
              : 'Nenhuma assembleia neste filtro',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildCard(AssembleiaModel a) {
    final isLive = a.isLive;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/assembleia-detalhe-morador', arguments: a.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLive
                ? Colors.red.shade200
                : a.isScheduled
                    ? Colors.blue.shade100
                    : Colors.grey.shade200,
            width: isLive ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isLive
                  ? Colors.red.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isLive
                    ? Colors.red.shade50
                    : a.isScheduled
                        ? Colors.blue.shade50
                        : Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isLive
                          ? Colors.red
                          : a.isScheduled
                              ? Colors.blue
                              : Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isLive
                          ? Icons.videocam
                          : a.isScheduled
                              ? Icons.event
                              : Icons.gavel,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.nome,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          a.tipo,
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Flexible(child: _buildStatusBadge(a)),
                ],
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Dates
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Text(
                            '1ª Conv: ${_formatDate(a.dt1aConvocacao)}',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      if (a.dt2aConvocacao != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today, size: 14, color: Colors.transparent), // for alignment
                            const SizedBox(width: 6),
                            Text(
                              '2ª Conv: ${_formatDate(a.dt2aConvocacao)}',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Modalidade + Transmissão
                  Row(
                    children: [
                      _buildInfoChip(
                        icon: Icons.public,
                        label: a.modalidade == 'online'
                            ? 'Online'
                            : a.modalidade == 'presencial'
                                ? 'Presencial'
                                : 'Híbrida',
                      ),
                      const SizedBox(width: 8),
                      _buildInfoChip(
                        icon: a.isYoutube ? Icons.play_circle : Icons.sensors,
                        label: a.isYoutube ? 'YouTube' : 'Agora.io',
                        color: a.isYoutube ? Colors.red : Colors.blue,
                      ),
                    ],
                  ),
                  // "Participar" button for live
                  if (isLive) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          '/assembleia-live',
                          arguments: a.id,
                        ),
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('Participar Agora'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(AssembleiaModel a) {
    Color bgColor;
    Color textColor;
    String text = a.statusLabel;

    if (a.isLive) {
      bgColor = Colors.red;
      textColor = Colors.white;
    } else if (a.isScheduled) {
      bgColor = Colors.blue.shade100;
      textColor = Colors.blue.shade700;
    } else if (a.isFinished) {
      bgColor = Colors.green.shade100;
      textColor = Colors.green.shade700;
    } else {
      bgColor = Colors.grey.shade100;
      textColor = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (a.isLive)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 4),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
          Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
        ],
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label, Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? Colors.grey).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color ?? Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color ?? Colors.grey.shade600)),
        ],
      ),
    );
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return '—';
    try {
      final dt = DateTime.parse(isoDate);
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      return isoDate;
    }
  }
}
