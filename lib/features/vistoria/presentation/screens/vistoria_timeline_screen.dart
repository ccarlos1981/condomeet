import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/features/vistoria/vistoria_service.dart';
import 'package:condomeet/features/vistoria/presentation/screens/vistoria_comparacao_screen.dart';

class VistoriaTimelineScreen extends StatefulWidget {
  final String endereco;
  const VistoriaTimelineScreen({super.key, required this.endereco});

  @override
  State<VistoriaTimelineScreen> createState() => _VistoriaTimelineScreenState();
}

class _VistoriaTimelineScreenState extends State<VistoriaTimelineScreen> {
  final _service = VistoriaService();
  List<Map<String, dynamic>> _timeline = [];
  bool _loading = true;

  static const _statusColors = {
    'rascunho': Color(0xFF6B7280),
    'em_andamento': Color(0xFF3B82F6),
    'concluida': Color(0xFF10B981),
    'assinada': Color(0xFF8B5CF6),
    'cancelada': Color(0xFFEF4444),
  };

  static const _tipoIcons = {
    'entrada': Icons.login,
    'saida': Icons.logout,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final authState = context.read<AuthBloc>().state;
    final condoId = authState.condominiumId;
    if (condoId == null) return;

    try {
      _timeline = await _service.listTimeline(condoId, widget.endereco);
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textMain),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 Timeline do Imóvel',
              style: TextStyle(
                color: AppColors.textMain,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              widget.endereco,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _timeline.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timeline, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        'Nenhuma vistoria encontrada\npara este endereço',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _timeline.length,
                  itemBuilder: (ctx, idx) => _buildTimelineItem(idx),
                ),
      floatingActionButton: _buildCompareFab(),
    );
  }

  Widget? _buildCompareFab() {
    final entrada = _timeline.where(
        (v) => (v['tipo_vistoria'] as String? ?? '') == 'entrada').toList();
    final saida = _timeline.where(
        (v) => (v['tipo_vistoria'] as String? ?? '') == 'saida').toList();

    // Case 1: Both entrada and saida exist → show compare button
    if (entrada.isNotEmpty && saida.isNotEmpty) {
      return FloatingActionButton.extended(
        backgroundColor: const Color(0xFF8B5CF6),
        icon: const Icon(Icons.compare_arrows, color: Colors.white),
        label: const Text(
          'Comparar Entrada vs Saída',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VistoriaComparacaoScreen(
                entradaId: entrada.first['id'] as String,
                saidaId: saida.first['id'] as String,
              ),
            ),
          );
        },
      );
    }

    // Case 2: Only entrada exists & is concluded → show "Criar Saída"
    if (entrada.isNotEmpty && saida.isEmpty) {
      final entradaStatus = entrada.first['status'] as String? ?? '';
      if (entradaStatus == 'concluida' || entradaStatus == 'assinada') {
        return FloatingActionButton.extended(
          backgroundColor: const Color(0xFFFF6D00),
          icon: const Icon(Icons.exit_to_app, color: Colors.white),
          label: const Text(
            'Realizar Vistoria de Saída',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          onPressed: () => _criarVistoriaSaidaFromTimeline(entrada.first['id'] as String),
        );
      }
    }

    return null;
  }

  Future<void> _criarVistoriaSaidaFromTimeline(String entradaId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.exit_to_app, color: Color(0xFFFF6D00)),
            SizedBox(width: 8),
            Expanded(child: Text('Vistoria de Saída', style: TextStyle(fontSize: 16))),
          ],
        ),
        content: const Text(
          'Será criada uma nova vistoria de SAÍDA com as mesmas seções e itens '
          'da entrada.\n\nVocê poderá re-inspecionar cada item, tirar novas fotos '
          'e registrar o estado atual do imóvel.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF6D00)),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.add_task),
            label: const Text('Criar Saída'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final saida = await VistoriaService().criarVistoriaSaida(entradaId);
      if (!mounted) return;
      Navigator.pop(context); // close loading
      Navigator.pop(context); // go back to list
      Navigator.pushNamed(context, '/vistoria-editor', arguments: saida['id']);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Vistoria de Saída criada! Inspecione cada item.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFFFF6D00),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildTimelineItem(int index) {
    final item = _timeline[index];
    final isFirst = index == 0;
    final isLast = index == _timeline.length - 1;
    final status = item['status'] as String? ?? 'rascunho';
    final tipo = item['tipo_vistoria'] as String? ?? 'entrada';
    final color = _statusColors[status] ?? Colors.grey;
    final date = DateTime.tryParse(item['created_at'] ?? '');
    final dateStr = date != null
        ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
        : '';
    final perfil = item['perfil'] as Map<String, dynamic>?;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line + dot
          SizedBox(
            width: 40,
            child: Column(
              children: [
                if (!isFirst)
                  Container(width: 2, height: 12, color: Colors.grey.shade300),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Icon(
                    _tipoIcons[tipo] ?? Icons.assignment,
                    size: 10,
                    color: Colors.white,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: Colors.grey.shade300),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Card
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(
                context,
                '/vistoria-editor',
                arguments: item['id'],
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: isFirst
                      ? Border.all(color: color.withValues(alpha: 0.3), width: 2)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item['titulo'] ?? 'Sem título',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.textMain,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: tipo == 'saida'
                                ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                                : const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tipo.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: tipo == 'saida'
                                  ? const Color(0xFF8B5CF6)
                                  : const Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Meta row
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 12, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text(
                          dateStr,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '#${item['cod_interno'] ?? ''}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (perfil != null) ...[
                          const Spacer(),
                          Text(
                            perfil['nome_completo'] ?? '',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade400),
                          ),
                        ],
                      ],
                    ),
                    // "Most recent" badge
                    if (isFirst) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '🔴 Mais recente',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
