import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/features/vistoria/vistoria_service.dart';

class VistoriaHomeScreen extends StatefulWidget {
  const VistoriaHomeScreen({super.key});

  @override
  State<VistoriaHomeScreen> createState() => _VistoriaHomeScreenState();
}

class _VistoriaHomeScreenState extends State<VistoriaHomeScreen> {
  final _service = VistoriaService();
  List<Map<String, dynamic>> _vistorias = [];
  List<Map<String, dynamic>> _templates = [];
  bool _loading = true;
  String _statusFilter = '';

  static const _statusLabels = {
    'rascunho':   {'label': 'Rascunho',   'icon': '📝', 'color': Color(0xFF6B7280)},
    'em_andamento': {'label': 'Em andamento', 'icon': '🔄', 'color': Color(0xFF3B82F6)},
    'concluida':  {'label': 'Concluída',  'icon': '✅', 'color': Color(0xFF10B981)},
    'assinada':   {'label': 'Assinada',   'icon': '✍️', 'color': Color(0xFF8B5CF6)},
    'cancelada':  {'label': 'Cancelada',  'icon': '❌', 'color': Color(0xFFEF4444)},
  };

  static const _tiposBem = {
    'apartamento': '🏢 Apartamento',
    'casa': '🏠 Casa',
    'carro': '🚗 Carro',
    'moto': '🏍️ Moto',
    'barco': '🚤 Barco',
    'terreno': '🌍 Terreno',
    'sala_comercial': '🏬 Sala Comercial',
    'outro': '📦 Outro',
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
      final results = await Future.wait([
        _service.listVistorias(condoId),
        _service.listTemplates(),
      ]);
      if (mounted) {
        setState(() {
          _vistorias = results[0];
          _templates = results[1];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_statusFilter.isEmpty) return _vistorias;
    return _vistorias.where((v) => v['status'] == _statusFilter).toList();
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
        title: const Row(
          children: [
            Text('📋', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text(
              'Vistorias',
              style: TextStyle(
                color: AppColors.textMain,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _loadData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Nova Vistoria',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary,
              child: Column(
                children: [
                  // Status filter chips
                  _buildFilterChips(),
                  // Stats summary
                  _buildStats(),
                  // List
                  Expanded(
                    child: _filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.assignment_outlined,
                                    size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text(
                                  'Nenhuma vistoria encontrada',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                            itemCount: _filtered.length,
                            itemBuilder: (context, index) =>
                                _buildVistoriaCard(_filtered[index]),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildChip('Todas', '', _statusFilter.isEmpty),
          ..._statusLabels.entries.map((e) {
            final count = _vistorias.where((v) => v['status'] == e.key).length;
            return _buildChip(
              '${e.value['icon']} ${e.value['label']} ($count)',
              e.key,
              _statusFilter == e.key,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChip(String label, String value, bool selected) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textMain,
          ),
        ),
        selected: selected,
        onSelected: (_) => setState(() => _statusFilter = value),
        selectedColor: AppColors.primary,
        backgroundColor: Colors.white,
        showCheckmark: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }

  Widget _buildStats() {
    final total = _vistorias.length;
    final rascunho = _vistorias.where((v) => v['status'] == 'rascunho').length;
    final andamento = _vistorias.where((v) => v['status'] == 'em_andamento').length;
    final concluida = _vistorias.where((v) => v['status'] == 'concluida' || v['status'] == 'assinada').length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStatItem('Total', total.toString(), AppColors.primary),
          _buildStatDivider(),
          _buildStatItem('Rascunho', rascunho.toString(), const Color(0xFF6B7280)),
          _buildStatDivider(),
          _buildStatItem('Andamento', andamento.toString(), const Color(0xFF3B82F6)),
          _buildStatDivider(),
          _buildStatItem('Concluídas', concluida.toString(), const Color(0xFF10B981)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(width: 1, height: 30, color: Colors.grey.shade200);
  }

  Widget _buildVistoriaCard(Map<String, dynamic> v) {
    final st = _statusLabels[v['status']] ?? _statusLabels['rascunho']!;
    final tipoBem = _tiposBem[v['tipo_bem']] ?? v['tipo_bem'];
    final perfil = v['perfil'] as Map<String, dynamic>?;
    final date = DateTime.tryParse(v['created_at'] ?? '');
    final dateStr = date != null
        ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
        : '';

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/vistoria-editor', arguments: v['id']),
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v['titulo'] ?? 'Sem título',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tipoBem,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (st['color'] as Color).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(st['icon'] as String, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        st['label'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: st['color'] as Color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Address
            if (v['endereco'] != null && (v['endereco'] as String).isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      v['endereco'],
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            // Footer
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '#${v['cod_interno'] ?? ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  dateStr,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                ),
                if (perfil != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    perfil['nome_completo'] ?? '',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                  ),
                ],
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    (v['tipo_vistoria'] as String? ?? 'entrada').toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateDialog() {
    String titulo = '';
    String tipoBem = 'apartamento';
    String tipoVistoria = 'entrada';
    String templateId = '';
    String endereco = '';
    String plano = 'free';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            padding: EdgeInsets.fromLTRB(
              24, 20, 24,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '📋 Nova Vistoria',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Título
                  TextField(
                    onChanged: (v) => titulo = v,
                    decoration: InputDecoration(
                      labelText: 'Título *',
                      hintText: 'Ex: Vistoria Apto 302',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Endereço
                  TextField(
                    onChanged: (v) => endereco = v,
                    decoration: InputDecoration(
                      labelText: 'Endereço',
                      hintText: 'Ex: Rua das Flores, 123 - Apto 302',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tipo de bem
                  DropdownButtonFormField<String>(
                    value: tipoBem,
                    decoration: InputDecoration(
                      labelText: 'Tipo de Bem',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    items: _tiposBem.entries.map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value, style: const TextStyle(fontSize: 14)),
                    )).toList(),
                    onChanged: (v) => setModalState(() => tipoBem = v!),
                  ),
                  const SizedBox(height: 12),

                  // Tipo de vistoria
                  Row(
                    children: [
                      Expanded(
                        child: _radioCard(
                          '📥 Entrada',
                          tipoVistoria == 'entrada',
                          () => setModalState(() => tipoVistoria = 'entrada'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _radioCard(
                          '📤 Saída',
                          tipoVistoria == 'saida',
                          () => setModalState(() => tipoVistoria = 'saida'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Template
                  if (_templates.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      value: templateId.isEmpty ? null : templateId,
                      decoration: InputDecoration(
                        labelText: 'Template (opcional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Sem template (em branco)', style: TextStyle(fontSize: 14)),
                        ),
                        ..._templates.map((t) => DropdownMenuItem(
                          value: t['id'] as String,
                          child: Text(
                            '${t['icone_emoji'] ?? '📋'} ${t['nome']}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        )),
                      ],
                      onChanged: (v) => setModalState(() => templateId = v ?? ''),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Plano
                  Row(
                    children: [
                      Expanded(
                        child: _radioCard(
                          '🆓 Free',
                          plano == 'free',
                          () => setModalState(() => plano = 'free'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _radioCard(
                          '⭐ Plus (R\$50)',
                          plano == 'plus',
                          () => setModalState(() => plano = 'plus'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Create button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: titulo.isEmpty
                          ? null
                          : () async {
                              Navigator.pop(ctx);
                              await _createVistoria(
                                titulo: titulo,
                                tipoBem: tipoBem,
                                tipoVistoria: tipoVistoria,
                                templateId: templateId,
                                endereco: endereco,
                                plano: plano,
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Criar Vistoria',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
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

  Widget _radioCard(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.08) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createVistoria({
    required String titulo,
    required String tipoBem,
    required String tipoVistoria,
    required String templateId,
    required String endereco,
    required String plano,
  }) async {
    final authState = context.read<AuthBloc>().state;
    final condoId = authState.condominiumId;
    if (condoId == null) return;

    try {
      final vistoria = await _service.createVistoria(
        condominioId: condoId,
        titulo: titulo,
        tipoBem: tipoBem,
        tipoVistoria: tipoVistoria,
        templateId: templateId,
        endereco: endereco,
        plano: plano,
      );
      await _loadData();
      if (mounted) {
        Navigator.pushNamed(context, '/vistoria-editor', arguments: vistoria['id']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao criar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
