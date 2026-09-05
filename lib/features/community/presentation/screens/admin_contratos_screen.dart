import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import '../../domain/models/contract.dart';
import '../widgets/fornecedor_bottom_sheet.dart';

// ─── Model Pasta ─────────────────────────────────────────────────────────────

class _Pasta {
  final String id;
  final String nome;
  _Pasta({required this.id, required this.nome});
  factory _Pasta.fromMap(Map<String, dynamic> m) =>
      _Pasta(id: m['id'] as String, nome: m['nome'] as String? ?? '');
}

// ─── Helpers de Formatação ───────────────────────────────────────────────────

String _formatCurrency(double? val) {
  if (val == null) return 'Não informado';
  final parts = val.toStringAsFixed(2).split('.');
  final integerPart = parts[0].replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]}.',
  );
  return 'R\$ $integerPart,${parts[1]}';
}

String _formatDateBR(DateTime? d) {
  if (d == null) return '—';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ─── Tela Principal de Administração de Contratos ────────────────────────────

class AdminContratosScreen extends StatefulWidget {
  const AdminContratosScreen({super.key});

  @override
  State<AdminContratosScreen> createState() => _AdminContratosScreenState();
}

class _AdminContratosScreenState extends State<AdminContratosScreen> {
  List<_Pasta> _pastas = [];
  List<CondoContract> _contratos = [];
  bool _loading = true;
  String? _condoId;
  String _search = '';
  String _statusFilter = 'TODOS';
  String? _pastaFilter;

  @override
  void initState() {
    super.initState();
    _condoId = context.read<AuthBloc>().state.condominiumId;
    _load();
  }

  Future<void> _load() async {
    if (_condoId == null) return;
    setState(() => _loading = true);
    try {
      final sb = Supabase.instance.client;
      final pastasRes = await sb
          .from('contrato_pastas')
          .select()
          .eq('condominio_id', _condoId!)
          .order('nome');

      final contratosRes = await sb
          .from('contratos')
          .select('*, fornecedores(id, nome, telefone, documento, tipo), contrato_pastas(id, nome)')
          .eq('condominio_id', _condoId!)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _pastas = (pastasRes as List)
              .map((m) => _Pasta.fromMap(m as Map<String, dynamic>))
              .toList();
          _contratos = (contratosRes as List)
              .map((m) => CondoContract.fromMap(m as Map<String, dynamic>))
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── Métricas Executivas ───────────────────────────────────────────────────

  int get _ativosCount => _contratos.where((c) {
        final st = c.statusInfo.type;
        return st == StatusContratoType.permanente ||
            st == StatusContratoType.vigente ||
            st == StatusContratoType.vencendo ||
            st == StatusContratoType.venceHoje;
      }).length;

  int get _vencendoCount => _contratos.where((c) {
        final st = c.statusInfo.type;
        return st == StatusContratoType.vencendo || st == StatusContratoType.venceHoje;
      }).length;

  int get _vencidosCount => _contratos.where((c) {
        return c.statusInfo.type == StatusContratoType.vencido;
      }).length;

  double get _custoMensalAtivo {
    return _contratos.where((c) {
      final st = c.statusInfo.type;
      return st == StatusContratoType.permanente ||
          st == StatusContratoType.vigente ||
          st == StatusContratoType.vencendo ||
          st == StatusContratoType.venceHoje;
    }).fold(0.0, (sum, c) => sum + (c.valorMensal ?? 0.0));
  }

  // ─── Filtragem e Ordenação de Contratos ────────────────────────────────────

  List<CondoContract> get _filteredContratos {
    return _contratos.where((c) {
      final q = _search.trim().toLowerCase();
      final fNome = (c.fornecedorNome ?? '').toLowerCase();
      final matchSearch = q.isEmpty ||
          c.titulo.toLowerCase().contains(q) ||
          fNome.contains(q) ||
          (c.categoria?.toLowerCase().contains(q) ?? false) ||
          (c.pastaNome?.toLowerCase().contains(q) ?? false);

      if (!matchSearch) return false;

      if (_pastaFilter != null && c.pastaId != _pastaFilter) return false;

      final st = c.statusInfo.type;
      if (_statusFilter == 'VIGENTES') {
        return st == StatusContratoType.vigente;
      } else if (_statusFilter == 'VENCENDO') {
        return st == StatusContratoType.vencendo || st == StatusContratoType.venceHoje;
      } else if (_statusFilter == 'VENCIDOS') {
        return st == StatusContratoType.vencido;
      } else if (_statusFilter == 'PERMANENTES') {
        return st == StatusContratoType.permanente;
      }

      return true;
    }).toList()
      ..sort((a, b) {
        const priority = {
          StatusContratoType.vencido: 1,
          StatusContratoType.venceHoje: 2,
          StatusContratoType.vencendo: 3,
          StatusContratoType.vigente: 4,
          StatusContratoType.permanente: 5,
          StatusContratoType.indeterminado: 6,
        };

        final pA = priority[a.statusInfo.type] ?? 99;
        final pB = priority[b.statusInfo.type] ?? 99;
        if (pA != pB) return pA.compareTo(pB);

        final dateA = a.dataValidade ?? DateTime(2099);
        final dateB = b.dataValidade ?? DateTime(2099);
        return dateA.compareTo(dateB);
      });
  }

  // ─── Ações CRUD ────────────────────────────────────────────────────────────

  Future<void> _showContratoForm({CondoContract? contrato}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _ContratoFormScreen(
          condoId: _condoId!,
          pastas: _pastas,
          contrato: contrato,
        ),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _deleteContrato(CondoContract contrato) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Excluir contrato?'),
        content: Text('Deseja realmente remover o contrato "${contrato.titulo}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Supabase.instance.client.from('contratos').delete().eq('id', contrato.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showPastaDialog({_Pasta? pasta}) async {
    final ctrl = TextEditingController(text: pasta?.nome ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(pasta == null ? 'Criar Pasta' : 'Editar Pasta'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nome da pasta'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(pasta == null ? 'Criar' : 'Salvar', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    final sb = Supabase.instance.client;
    if (pasta == null) {
      await sb.from('contrato_pastas').insert({'condominio_id': _condoId, 'nome': result});
    } else {
      await sb.from('contrato_pastas').update({'nome': result}).eq('id', pasta.id);
    }
    _load();
  }

  // ─── Build Principal ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Contratos', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.folder_outlined), onPressed: () => _showPastaDialog(), tooltip: 'Pastas'),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load, tooltip: 'Atualizar'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showContratoForm(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Novo Contrato', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                children: [
                  // ── 1. Cards de Métricas Executivas ──
                  _buildMetricCards(),
                  const SizedBox(height: 16),

                  // ── 2. Busca e Filtros ──
                  _buildSearchAndFilters(),
                  const SizedBox(height: 16),

                  // ── 3. Lista de Contratos ──
                  if (_filteredContratos.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Column(
                          children: [
                            Icon(Icons.description_outlined, size: 56, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            const Text(
                              'Nenhum contrato encontrado',
                              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Cadastre ou ajuste os filtros de busca.',
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._filteredContratos.map((c) => _buildContractCard(c)),
                ],
              ),
            ),
    );
  }

  // ─── Widgets dos Cards Executivos ───

  Widget _buildMetricCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Ativos',
                value: '$_ativosCount',
                icon: Icons.check_circle_outline,
                color: const Color(0xFF059669),
                bgColor: const Color(0xFFECFDF5),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                title: 'Vencendo ≤ 30d',
                value: '$_vencendoCount',
                icon: Icons.access_time_rounded,
                color: const Color(0xFFD97706),
                bgColor: const Color(0xFFFFFBEB),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Vencidos',
                value: '$_vencidosCount',
                icon: Icons.error_outline,
                color: const Color(0xFFDC2626),
                bgColor: const Color(0xFFFEF2F2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                title: 'Custo Mensal Ativo',
                value: _formatCurrency(_custoMensalAtivo),
                icon: Icons.monetization_on_outlined,
                color: const Color(0xFFFC5931),
                bgColor: const Color(0xFFFFF2EE),
                isCurrency: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
    bool isCurrency = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isCurrency ? 13 : 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2937),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Busca e Pílulas de Filtro ───

  Widget _buildSearchAndFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            hintText: 'Buscar por fornecedor, serviço...',
            hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
            prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('TODOS', 'Todos'),
              const SizedBox(width: 6),
              _buildFilterChip('VIGENTES', 'Vigentes'),
              const SizedBox(width: 6),
              _buildFilterChip('VENCENDO', 'Vencendo ≤30d'),
              const SizedBox(width: 6),
              _buildFilterChip('VENCIDOS', 'Vencidos'),
              const SizedBox(width: 6),
              _buildFilterChip('PERMANENTES', 'Permanentes'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _statusFilter == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
      selected: isSelected,
      selectedColor: const Color(0xFF1F2937),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide(color: isSelected ? const Color(0xFF1F2937) : Colors.grey.shade300),
      onSelected: (_) => setState(() => _statusFilter = key),
    );
  }

  // ─── Card Individual do Contrato ───

  Widget _buildContractCard(CondoContract c) {
    final status = c.statusInfo;
    final fornecedorNome = c.nomeFornecedorExibicao;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Linha Superior: Fornecedor e Status Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFFFF2EE),
                  child: Icon(
                    c.fornecedorTipo == 'Pessoa Jurídica' ? Icons.business_rounded : Icons.person_rounded,
                    color: const Color(0xFFFC5931),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fornecedorNome,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111827)),
                      ),
                      if (c.fornecedorTelefone != null || c.fornecedorDoc != null)
                        Text(
                          [
                            if (c.fornecedorTelefone != null) '📞 ${c.fornecedorTelefone}',
                            if (c.fornecedorDoc != null) 'Doc: ${c.fornecedorDoc}',
                          ].join(' • '),
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: status.backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(status.icon, size: 12, color: status.color),
                      const SizedBox(width: 4),
                      Text(
                        status.label,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: status.color),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Serviço / Objeto
            Text(
              c.titulo,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1F2937)),
            ),

            const SizedBox(height: 8),

            // Linha: Valor Mensal e Vigência
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Valor Mensal', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
                    Text(
                      _formatCurrency(c.valorMensal),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Vencimento', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
                    Text(
                      c.semValidade ? 'Permanente' : _formatDateBR(c.dataValidade),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Rodapé: Categoria, Pasta e Botões de Ação
            Row(
              children: [
                if (c.categoria != null)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF2EE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      c.categoria!,
                      style: const TextStyle(fontSize: 10, color: Color(0xFFFC5931), fontWeight: FontWeight.w600),
                    ),
                  ),
                if (c.pastaNome != null)
                  Text(
                    '📁 ${c.pastaNome}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                  onPressed: () => _showContratoForm(contrato: c),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                  onPressed: () => _deleteContrato(c),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Formulário Mobile-First de Inclusão e Edição ───────────────────────────

class _ContratoFormScreen extends StatefulWidget {
  final String condoId;
  final List<_Pasta> pastas;
  final CondoContract? contrato;

  const _ContratoFormScreen({
    required this.condoId,
    required this.pastas,
    this.contrato,
  });

  @override
  State<_ContratoFormScreen> createState() => _ContratoFormScreenState();
}

class _ContratoFormScreenState extends State<_ContratoFormScreen> {
  String? _fornecedorId;
  String? _fornecedorNome;
  late final TextEditingController _servicoCtrl;
  late final TextEditingController _valorMensalCtrl;
  late final TextEditingController _descricaoCtrl;

  DateTime? _dataInicio;
  DateTime? _dataTermino;
  bool _semValidade = false;

  String? _pastaId;
  String? _categoria;
  bool _mostrarMoradores = false;
  bool _lembrar30 = false;
  bool _lembrar60 = false;
  bool _lembrar90 = false;

  PlatformFile? _arquivo;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = widget.contrato;
    _fornecedorId = c?.fornecedorId;
    _fornecedorNome = c?.fornecedorNome;
    _servicoCtrl = TextEditingController(text: c?.titulo ?? '');
    _valorMensalCtrl = TextEditingController(
      text: c?.valorMensal != null ? c!.valorMensal!.toStringAsFixed(2) : '',
    );
    _descricaoCtrl = TextEditingController(text: c?.descricao ?? '');

    _dataInicio = c?.dataExpedicao ?? DateTime.now();
    _dataTermino = c?.dataValidade;
    _semValidade = c?.semValidade ?? false;

    _pastaId = c?.pastaId;
    _categoria = c?.categoria ?? 'Manutenção';
    _mostrarMoradores = c?.mostrarMoradores ?? false;
    _lembrar30 = c?.lembrar30 ?? false;
    _lembrar60 = c?.lembrar60 ?? false;
    _lembrar90 = c?.lembrar90 ?? false;
  }

  @override
  void dispose() {
    _servicoCtrl.dispose();
    _valorMensalCtrl.dispose();
    _descricaoCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectFornecedor() async {
    final res = await FornecedorBottomSheet.show(
      context: context,
      condominioId: widget.condoId,
      selectedFornecedorId: _fornecedorId,
      initialFornecedorNomeAvulso: _fornecedorNome,
    );

    if (res != null) {
      setState(() {
        _fornecedorId = res.fornecedorId;
        _fornecedorNome = res.fornecedorNome;
      });
    }
  }

  Future<void> _pickDate({required bool isInicio}) async {
    final initial = isInicio ? (_dataInicio ?? DateTime.now()) : (_dataTermino ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isInicio) {
          _dataInicio = picked;
        } else {
          _dataTermino = picked;
        }
      });
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _arquivo = result.files.first);
    }
  }

  Future<void> _save() async {
    final servico = _servicoCtrl.text.trim();
    if (servico.isEmpty) {
      setState(() => _error = 'Informe o serviço ou objeto do contrato.');
      return;
    }

    if (!_semValidade && _dataTermino == null && widget.contrato == null) {
      setState(() => _error = 'Informe a data de término ou selecione "Contrato sem validade".');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    double? valorMensal;
    if (_valorMensalCtrl.text.trim().isNotEmpty) {
      valorMensal = double.tryParse(_valorMensalCtrl.text.replaceAll(',', '.'));
      if (valorMensal == null || valorMensal < 0) {
        setState(() {
          _error = 'Informe um valor mensal válido.';
          _saving = false;
        });
        return;
      }
    }

    String? arquivoUrl = widget.contrato?.arquivoUrl;
    String? arquivoNome = widget.contrato?.arquivoNome;

    if (_arquivo != null && _arquivo!.bytes != null) {
      final ext = _arquivo!.extension ?? 'pdf';
      final path = '${widget.condoId}/${DateTime.now().millisecondsSinceEpoch}.$ext';
      try {
        final sb = Supabase.instance.client;
        await sb.storage.from('contratos').uploadBinary(path, _arquivo!.bytes!);
        arquivoUrl = sb.storage.from('contratos').getPublicUrl(path);
        arquivoNome = _arquivo!.name;
      } catch (e) {
        setState(() {
          _error = 'Erro no upload: $e';
          _saving = false;
        });
        return;
      }
    }

    // Regra canônica de precedência
    final fId = _fornecedorId;
    final fNome = fId != null ? null : (_fornecedorNome?.trim().isEmpty == true ? null : _fornecedorNome?.trim());

    final payload = {
      'condominio_id': widget.condoId,
      'fornecedor_id': fId,
      'fornecedor_nome': fNome,
      'titulo': servico,
      'categoria': _categoria,
      'pasta_id': _pastaId,
      'valor_mensal': valorMensal,
      'data_expedicao': _dataInicio != null ? '${_dataInicio!.year}-${_dataInicio!.month.toString().padLeft(2, '0')}-${_dataInicio!.day.toString().padLeft(2, '0')}' : null,
      'data_validade': _semValidade ? null : (_dataTermino != null ? '${_dataTermino!.year}-${_dataTermino!.month.toString().padLeft(2, '0')}-${_dataTermino!.day.toString().padLeft(2, '0')}' : null),
      'sem_validade': _semValidade,
      'lembrar_30': _semValidade ? false : _lembrar30,
      'lembrar_60': _semValidade ? false : _lembrar60,
      'lembrar_90': _semValidade ? false : _lembrar90,
      'arquivo_url': arquivoUrl,
      'arquivo_nome': arquivoNome,
      'mostrar_moradores': _mostrarMoradores,
      'descricao': _descricaoCtrl.text.trim().isEmpty ? null : _descricaoCtrl.text.trim(),
      'tipo': 'obrigatorio',
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      final sb = Supabase.instance.client;
      if (widget.contrato == null) {
        await sb.from('contratos').insert(payload);
      } else {
        await sb.from('contratos').update(payload).eq('id', widget.contrato!.id);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _error = 'Erro ao salvar: $e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.contrato != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(isEdit ? 'Editar Contrato' : 'Novo Contrato', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Fornecedor ──
            const Text('FORNECEDOR / PRESTADOR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 6),
            InkWell(
              onTap: _selectFornecedor,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(14),
                  color: const Color(0xFFF9FAFB),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.handshake_outlined, color: Color(0xFFFC5931), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _fornecedorNome ?? 'Toque para selecionar fornecedor...',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: _fornecedorNome != null ? FontWeight.bold : FontWeight.normal,
                          color: _fornecedorNome != null ? const Color(0xFF111827) : Colors.grey,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // ── 2. Serviço / Objeto ──
            const Text('SERVIÇO / OBJETO DO CONTRATO *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 6),
            TextField(
              controller: _servicoCtrl,
              decoration: InputDecoration(
                hintText: 'Ex: Manutenção Preventiva dos Elevadores',
                hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFFC5931), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // ── 3. Valor Mensal ──
            const Text('VALOR MENSAL RECORRENTE (R\$)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 6),
            TextField(
              controller: _valorMensalCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: 'R\$ ',
                hintText: '0,00',
                hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFFC5931), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // ── 4. Vigência e Validade ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('VIGÊNCIA E PRAZOS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                      Row(
                        children: [
                          Checkbox(
                            value: _semValidade,
                            activeColor: const Color(0xFFFC5931),
                            onChanged: (val) {
                              setState(() {
                                _semValidade = val == true;
                                if (_semValidade) {
                                  _dataTermino = null;
                                  _lembrar30 = false;
                                  _lembrar60 = false;
                                  _lembrar90 = false;
                                }
                              });
                            },
                          ),
                          const Text('Sem validade', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickDate(isInicio: true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Data Início', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                Text(_formatDateBR(_dataInicio), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: _semValidade ? null : () => _pickDate(isInicio: false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: _semValidade ? Colors.grey.shade100 : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Data Término', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                Text(
                                  _semValidade ? 'Permanente' : _formatDateBR(_dataTermino),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: _semValidade ? Colors.grey : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── 5. Arquivo do Contrato ──
            const Text('ARQUIVO DO CONTRATO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 6),
            InkWell(
              onTap: _pickFile,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(14),
                  color: const Color(0xFFF9FAFB),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.attach_file_rounded, color: Color(0xFFFC5931), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _arquivo?.name ?? widget.contrato?.arquivoNome ?? 'Toque para selecionar PDF ou imagem',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _arquivo != null || widget.contrato?.arquivoNome != null ? FontWeight.bold : FontWeight.normal,
                              color: const Color(0xFF1F2937),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Text('PDF, DOC, PNG ou JPG até 10MB', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // ── 6. Opções Adicionais (ExpansionTile) ──
            ExpansionTile(
              title: const Text('Opções Adicionais', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              subtitle: const Text('Pasta, Categoria, Lembretes...', style: TextStyle(fontSize: 11, color: Colors.grey)),
              childrenPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _pastaId,
                  decoration: InputDecoration(
                    labelText: 'Pasta',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Sem pasta')),
                    ...widget.pastas.map((p) => DropdownMenuItem(value: p.id, child: Text(p.nome))),
                  ],
                  onChanged: (v) => setState(() => _pastaId = v),
                ),
                const SizedBox(height: 12),
                if (!_semValidade) ...[
                  const Text('Lembretes de Vencimento', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Lembrar 30 dias antes', style: TextStyle(fontSize: 13)),
                    value: _lembrar30,
                    activeColor: const Color(0xFFFC5931),
                    onChanged: (v) => setState(() => _lembrar30 = v == true),
                  ),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Lembrar 60 dias antes', style: TextStyle(fontSize: 13)),
                    value: _lembrar60,
                    activeColor: const Color(0xFFFC5931),
                    onChanged: (v) => setState(() => _lembrar60 = v == true),
                  ),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Lembrar 90 dias antes', style: TextStyle(fontSize: 13)),
                    value: _lembrar90,
                    activeColor: const Color(0xFFFC5931),
                    onChanged: (v) => setState(() => _lembrar90 = v == true),
                  ),
                ],
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Disponibilizar aos moradores', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Portal da transparência (default desativado)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  value: _mostrarMoradores,
                  activeTrackColor: const Color(0xFFFC5931),
                  onChanged: (v) => setState(() => _mostrarMoradores = v),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descricaoCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Observações / Detalhes de Cláusulas',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                child: Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
              ),
            ],

            const SizedBox(height: 24),

            // ── 7. Botão Salvar ──
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        isEdit ? 'Salvar Alterações' : 'Cadastrar Contrato',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
