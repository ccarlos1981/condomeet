import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

class _Pasta {
  final String id;
  final String nome;
  _Pasta({required this.id, required this.nome});
  factory _Pasta.fromMap(Map m) => _Pasta(id: m['id'] as String, nome: m['nome'] as String? ?? '');
}

class _Contrato {
  final String id;
  final String titulo;
  final String? pastaId;
  final String? categoria;
  final String tipo;
  final String? arquivoUrl;
  final String? arquivoNome;
  final String? dataExpedicao;
  final String? dataValidade;
  final bool mostrarMoradores;
  final bool avisarMoradores;
  final bool lembrar30;
  final bool lembrar60;
  final bool lembrar90;

  _Contrato({
    required this.id,
    required this.titulo,
    this.pastaId,
    this.categoria,
    this.tipo = 'obrigatorio',
    this.arquivoUrl,
    this.arquivoNome,
    this.dataExpedicao,
    this.dataValidade,
    this.mostrarMoradores = false,
    this.avisarMoradores = false,
    this.lembrar30 = false,
    this.lembrar60 = false,
    this.lembrar90 = false,
  });

  factory _Contrato.fromMap(Map m) => _Contrato(
        id: m['id'] as String,
        titulo: m['titulo'] as String? ?? '',
        pastaId: m['pasta_id'] as String?,
        categoria: m['categoria'] as String?,
        tipo: m['tipo'] as String? ?? 'obrigatorio',
        arquivoUrl: m['arquivo_url'] as String?,
        arquivoNome: m['arquivo_nome'] as String?,
        dataExpedicao: m['data_expedicao'] as String?,
        dataValidade: m['data_validade'] as String?,
        mostrarMoradores: m['mostrar_moradores'] == true,
        avisarMoradores: m['avisar_moradores'] == true,
        lembrar30: m['lembrar_30'] == true,
        lembrar60: m['lembrar_60'] == true,
        lembrar90: m['lembrar_90'] == true,
      );
}

// ─── Constantes ──────────────────────────────────────────────────────────────

const _tabelaPastas  = 'contrato_pastas';
const _tabelaDocs    = 'contratos';
const _storageBucket = 'contratos';

// ─── Tela principal ──────────────────────────────────────────────────────────

class AdminContratosScreen extends StatefulWidget {
  const AdminContratosScreen({super.key});

  @override
  State<AdminContratosScreen> createState() => _AdminContratosScreenState();
}

class _AdminContratosScreenState extends State<AdminContratosScreen> {
  List<_Pasta> _pastas = [];
  List<_Contrato> _contratos = [];
  bool _loading = true;
  String? _expandedPastaId;
  String? _condoId;

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
      final pastasRes = await sb.from(_tabelaPastas).select().eq('condominio_id', _condoId!).order('nome');
      final contratosRes = await sb.from(_tabelaDocs).select().eq('condominio_id', _condoId!).order('titulo');
      if (mounted) {
        setState(() {
          _pastas   = (pastasRes   as List).map((m) => _Pasta.fromMap(m as Map)).toList();
          _contratos = (contratosRes as List).map((m) => _Contrato.fromMap(m as Map)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_Contrato> _contratosNaPasta(String pastaId) =>
      _contratos.where((c) => c.pastaId == pastaId).toList();

  // ─── Pasta CRUD ────────────────────────────────────────────────────────────

  Future<void> _showPastaDialog({_Pasta? pasta}) async {
    final ctrl = TextEditingController(text: pasta?.nome ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(pasta == null ? 'Criar pasta' : 'Editar pasta'),
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
      await sb.from(_tabelaPastas).insert({'condominio_id': _condoId, 'nome': result});
    } else {
      await sb.from(_tabelaPastas).update({'nome': result}).eq('id', pasta.id);
    }
    _load();
  }

  Future<void> _deletePasta(_Pasta pasta) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remover pasta?'),
        content: const Text('Os contratos dentro serão desvinculados da pasta.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await Supabase.instance.client.from(_tabelaPastas).delete().eq('id', pasta.id);
    _load();
  }

  // ─── Contrato CRUD ─────────────────────────────────────────────────────────

  Future<void> _showContratoForm({_Contrato? contrato}) async {
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

  Future<void> _deleteContrato(_Contrato contrato) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remover contrato?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await Supabase.instance.client.from(_tabelaDocs).delete().eq('id', contrato.id);
    _load();
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contratos'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      _ActionBtn(
                        icon: Icons.note_add_outlined,
                        label: 'Inserir contrato',
                        onTap: () => _showContratoForm(),
                      ),
                      const SizedBox(width: 12),
                      _ActionBtn(
                        icon: Icons.create_new_folder_outlined,
                        label: 'Criar pasta',
                        onTap: () => _showPastaDialog(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_pastas.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Column(
                          children: [
                            Icon(Icons.folder_open, size: 56, color: Colors.grey.shade300),
                            const SizedBox(height: 8),
                            const Text('Nenhuma pasta criada', style: TextStyle(color: Colors.grey)),
                            const Text('Crie uma pasta para organizar os contratos',
                                style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _pastas.map((pasta) {
                        final expanded = _expandedPastaId == pasta.id;
                        final contratos = _contratosNaPasta(pasta.id);
                        return SizedBox(
                          width: expanded
                              ? double.infinity
                              : (MediaQuery.of(context).size.width - 44) / 2,
                          child: _buildPastaCard(pasta, contratos, expanded),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildPastaCard(_Pasta pasta, List<_Contrato> contratos, bool expanded) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            pasta.nome,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
              letterSpacing: 0.3,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
          ),
          child: Column(
            children: [
              InkWell(
                onTap: () => setState(() => _expandedPastaId = expanded ? null : pasta.id),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.folder_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${contratos.length}',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                color: Colors.grey.shade500)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () => _showPastaDialog(pasta: pasta),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () => _deletePasta(pasta),
                      ),
                      Icon(expanded ? Icons.expand_less : Icons.expand_more,
                          size: 18, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              if (expanded) ...[
                const Divider(height: 1),
                if (contratos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nenhum contrato nesta pasta',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  )
                else
                  ...contratos.map((c) => _buildContratoTile(c)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContratoTile(_Contrato c) {
    return ListTile(
      dense: true,
      leading: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.description_outlined, size: 16, color: AppColors.primary),
      ),
      title: Text(c.titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: c.categoria != null
          ? Text(c.categoria!, style: const TextStyle(fontSize: 11)) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 16),
            onPressed: () => _showContratoForm(contrato: c),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
            onPressed: () => _deleteContrato(c),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

// ─── Botão de ação ────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: AppColors.primary),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Categorias padrão ───────────────────────────────────────────────────────

const _defaultCategorias = [
  'Obrigatório',
  'Manutenção',
  'Prestador',
  'Seguro',
  'Outros',
];

// ─── Formulário ──────────────────────────────────────────────────────────────

class _ContratoFormScreen extends StatefulWidget {
  final String condoId;
  final List<_Pasta> pastas;
  final _Contrato? contrato;
  const _ContratoFormScreen({required this.condoId, required this.pastas, this.contrato});

  @override
  State<_ContratoFormScreen> createState() => _ContratoFormScreenState();
}

class _ContratoFormScreenState extends State<_ContratoFormScreen> {
  late final TextEditingController _tituloCtrl;
  String _tipo = 'obrigatorio';
  String? _pastaId;
  String? _categoria;
  List<String> _categorias = [];
  DateTime? _dataEmissao;
  DateTime? _dataValidade;
  bool _mostrarMoradores = false;
  bool _avisarMoradores = false;
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
    _tituloCtrl       = TextEditingController(text: c?.titulo ?? '');
    _tipo             = c?.tipo ?? 'obrigatorio';
    _pastaId          = c?.pastaId;
    _categoria        = c?.categoria;
    _dataEmissao      = _tryParseDate(c?.dataExpedicao) ?? DateTime.now();
    _dataValidade     = _tryParseDate(c?.dataValidade);
    _mostrarMoradores = c?.mostrarMoradores ?? false;
    _avisarMoradores  = c?.avisarMoradores  ?? false;
    _lembrar30 = c?.lembrar30 ?? false;
    _lembrar60 = c?.lembrar60 ?? false;
    _lembrar90 = c?.lembrar90 ?? false;
    _loadCategorias();
  }

  DateTime? _tryParseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  String _formatDateBR(DateTime? d) {
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _pickDate({required bool isEmissao}) async {
    final initial = isEmissao ? (_dataEmissao ?? DateTime.now()) : (_dataValidade ?? DateTime.now());
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
        if (isEmissao) {
          _dataEmissao = picked;
        } else {
          _dataValidade = picked;
        }
      });
    }
  }

  Future<void> _loadCategorias() async {
    try {
      final sb = Supabase.instance.client;
      final res = await sb
          .from('documentos_categorias')
          .select('nome')
          .eq('condominio_id', widget.condoId);
      final custom = (res as List).map((r) => r['nome'] as String).toList();
      final all = <String>{..._defaultCategorias, ...custom};
      if (mounted) {
        setState(() => _categorias = all.toList()..sort());
      }
    } catch (_) {
      setState(() => _categorias = List.from(_defaultCategorias));
    }
  }

  Future<void> _addCategoria() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nova Categoria'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nome da nova categoria'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Adicionar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    // Persist to database
    try {
      final sb = Supabase.instance.client;
      await sb.from('documentos_categorias').upsert(
        {'condominio_id': widget.condoId, 'nome': result},
        onConflict: 'condominio_id,nome',
      );
    } catch (_) {}
    setState(() {
      if (!_categorias.contains(result)) {
        _categorias.add(result);
        _categorias.sort();
      }
      _categoria = result;
    });
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'png', 'jpg'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _arquivo = result.files.first);
    }
  }

  Future<void> _save() async {
    if (_tituloCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Informe o título do contrato.');
      return;
    }
    setState(() { _saving = true; _error = null; });

    String? arquivoUrl  = widget.contrato?.arquivoUrl;
    String? arquivoNome = widget.contrato?.arquivoNome;

    if (_arquivo != null && _arquivo!.bytes != null) {
      final ext  = _arquivo!.extension ?? 'pdf';
      final path = '${widget.condoId}/${DateTime.now().millisecondsSinceEpoch}.$ext';
      try {
        final sb = Supabase.instance.client;
        await sb.storage.from(_storageBucket).uploadBinary(path, _arquivo!.bytes!);
        arquivoUrl  = sb.storage.from(_storageBucket).getPublicUrl(path);
        arquivoNome = _arquivo!.name;
      } catch (e) {
        setState(() { _error = 'Erro no upload: $e'; _saving = false; });
        return;
      }
    }

    final payload = {
      'condominio_id':    widget.condoId,
      'pasta_id':         _pastaId,
      'titulo':           _tituloCtrl.text.trim(),
      'categoria':        _categoria,
      'tipo':             _tipo,
      'data_expedicao':   _dataEmissao != null ? '${_dataEmissao!.year}-${_dataEmissao!.month.toString().padLeft(2, '0')}-${_dataEmissao!.day.toString().padLeft(2, '0')}' : null,
      'data_validade':    _dataValidade != null ? '${_dataValidade!.year}-${_dataValidade!.month.toString().padLeft(2, '0')}-${_dataValidade!.day.toString().padLeft(2, '0')}' : null,
      'arquivo_url':      arquivoUrl,
      'arquivo_nome':     arquivoNome,
      'mostrar_moradores': _mostrarMoradores,
      'avisar_moradores':  _avisarMoradores,
      'lembrar_30': _lembrar30,
      'lembrar_60': _lembrar60,
      'lembrar_90': _lembrar90,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      final sb = Supabase.instance.client;
      if (widget.contrato == null) {
        await sb.from(_tabelaDocs).insert(payload);
      } else {
        await sb.from(_tabelaDocs).update(payload).eq('id', widget.contrato!.id);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() { _error = 'Erro ao salvar: $e'; _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.contrato != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Editar Contrato' : 'Novo Contrato'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Tipo de Contrato ──
            const Text('Tipo de Contrato', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            _buildTipoRadios(),
            const SizedBox(height: 20),

            _field('Título *', _tituloCtrl, hint: 'Ex: Contrato de Manutenção'),
            const SizedBox(height: 16),

            // ── Categoria dropdown + botão "+" ──
            const Text('Categoria', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _categoria,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    hint: const Text('Selecione'),
                    items: _categorias.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => _categoria = v),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add, color: AppColors.primary),
                    onPressed: _addCategoria,
                    tooltip: 'Adicionar categoria',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Text('Pasta', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _pastaId,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              hint: const Text('Selecionar pasta'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Sem pasta')),
                ...widget.pastas.map((p) => DropdownMenuItem(value: p.id, child: Text(p.nome))),
              ],
              onChanged: (v) => setState(() => _pastaId = v),
            ),
            const SizedBox(height: 16),

            // ── Datas com calendário ──
            Row(
              children: [
                Expanded(child: _datePickerField('Data Emissão', _dataEmissao, isEmissao: true)),
                const SizedBox(width: 12),
                Expanded(child: _datePickerField('Data Validade', _dataValidade, isEmissao: false)),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Arquivo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            InkWell(
              onTap: _pickFile,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade50,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.attach_file, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _arquivo?.name ?? widget.contrato?.arquivoNome ?? 'Clique para selecionar arquivo',
                        style: TextStyle(
                          fontSize: 13,
                          color: _arquivo != null || widget.contrato?.arquivoNome != null
                              ? Colors.black87 : Colors.grey,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _switch('Mostrar para moradores?', _mostrarMoradores, (v) => setState(() => _mostrarMoradores = v)),
            _switch('Avisar todos os moradores (push)?', _avisarMoradores, (v) => setState(() => _avisarMoradores = v)),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('Lembretes de vencimento', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            _switch('Lembrar 30 dias antes', _lembrar30, (v) => setState(() => _lembrar30 = v)),
            _switch('Lembrar 60 dias antes', _lembrar60, (v) => setState(() => _lembrar60 = v)),
            _switch('Lembrar 90 dias antes', _lembrar90, (v) => setState(() => _lembrar90 = v)),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(isEdit ? 'Salvar' : 'Inserir Contrato',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipoRadios() {
    return RadioGroup<String>(
      groupValue: _tipo,
      onChanged: (v) { if (v != null) setState(() => _tipo = v); },
      child: Row(
        children: [
          _radioOption('obrigatorio', 'Obrigatórios'),
          const SizedBox(width: 12),
          _radioOption('manutencao', 'Manutenção'),
          const SizedBox(width: 12),
          _radioOption('outros', 'Outros...'),
        ],
      ),
    );
  }

  Widget _radioOption(String value, String label) {
    return GestureDetector(
      onTap: () => setState(() => _tipo = value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<String>(
            value: value,
            activeColor: AppColors.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _datePickerField(String label, DateTime? date, {required bool isEmissao}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _pickDate(isEmissao: isEmissao),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    date != null ? _formatDateBR(date) : 'DD/MM/AAAA',
                    style: TextStyle(
                      fontSize: 14,
                      color: date != null ? Colors.black87 : Colors.grey,
                    ),
                  ),
                ),
                Icon(Icons.calendar_today, size: 18, color: Colors.grey.shade500),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _field(String label, TextEditingController ctrl, {String? hint, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _switch(String label, bool value, ValueChanged<bool> onChange) {
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 13)),
      value: value,
      activeThumbColor: AppColors.primary,
      onChanged: onChange,
    );
  }
}
