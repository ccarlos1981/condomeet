import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';

// ─── Model simples ───────────────────────────────────────────────────────────

class _Pasta {
  final String id;
  final String nome;
  _Pasta({required this.id, required this.nome});
  factory _Pasta.fromMap(Map m) => _Pasta(id: m['id'] as String, nome: m['nome'] as String? ?? '');
}

class _Doc {
  final String id;
  final String titulo;
  final String? pastaId;
  final String? categoria;
  final String? arquivoUrl;
  final String? arquivoNome;
  final String? dataValidade;
  final bool mostrarMoradores;
  final bool avisarMoradores;

  _Doc({
    required this.id,
    required this.titulo,
    this.pastaId,
    this.categoria,
    this.arquivoUrl,
    this.arquivoNome,
    this.dataValidade,
    this.mostrarMoradores = false,
    this.avisarMoradores = false,
  });

  factory _Doc.fromMap(Map m) => _Doc(
        id: m['id'] as String,
        titulo: m['titulo'] as String? ?? '',
        pastaId: m['pasta_id'] as String?,
        categoria: m['categoria'] as String?,
        arquivoUrl: m['arquivo_url'] as String?,
        arquivoNome: m['arquivo_nome'] as String?,
        dataValidade: m['data_validade'] as String?,
        mostrarMoradores: m['mostrar_moradores'] == true,
        avisarMoradores: m['avisar_moradores'] == true,
      );
}

// ─── Constantes ──────────────────────────────────────────────────────────────

const _tabelaPastas = 'doc_pastas';
const _tabelaDocs   = 'documentos';
const _storageBucket = 'documentos';

// ─── Tela principal ──────────────────────────────────────────────────────────

class AdminDocumentosScreen extends StatefulWidget {
  const AdminDocumentosScreen({super.key});

  @override
  State<AdminDocumentosScreen> createState() => _AdminDocumentosScreenState();
}

class _AdminDocumentosScreenState extends State<AdminDocumentosScreen> {
  List<_Pasta> _pastas = [];
  List<_Doc> _docs = [];
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
      final docsRes   = await sb.from(_tabelaDocs).select().eq('condominio_id', _condoId!).order('titulo');
      if (mounted) {
        setState(() {
          _pastas = (pastasRes as List).map((m) => _Pasta.fromMap(m as Map)).toList();
          _docs   = (docsRes   as List).map((m) => _Doc.fromMap(m as Map)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_Doc> _docsNaPasta(String pastaId) => _docs.where((d) => d.pastaId == pastaId).toList();

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
        content: const Text('Os documentos dentro serão desvinculados da pasta.'),
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

  // ─── Documento CRUD ────────────────────────────────────────────────────────

  Future<void> _showDocForm({_Doc? doc}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _DocFormScreen(
          condoId: _condoId!,
          pastas: _pastas,
          doc: doc,
        ),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _deleteDoc(_Doc doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remover documento?'),
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
    await Supabase.instance.client.from(_tabelaDocs).delete().eq('id', doc.id);
    _load();
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documentos'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Botões de ação ──────────────────────────────────────
                  Row(
                    children: [
                      _ActionButton(
                        icon: Icons.note_add_outlined,
                        label: 'Inserir documento',
                        onTap: () => _showDocForm(),
                      ),
                      const SizedBox(width: 12),
                      _ActionButton(
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
                            const Text('Crie uma pasta para organizar os documentos',
                                style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                    )
                  else
                    // Grid 2 colunas (pasta expandida ocupa 2)
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _pastas.map((pasta) {
                        final expanded = _expandedPastaId == pasta.id;
                        final docs = _docsNaPasta(pasta.id);
                        return SizedBox(
                          width: expanded
                              ? double.infinity
                              : (MediaQuery.of(context).size.width - 44) / 2,
                          child: _buildPastaCard(pasta, docs, expanded),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildPastaCard(_Pasta pasta, List<_Doc> docs, bool expanded) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Nome da pasta acima do card
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header da pasta
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
                        child: Text(
                          '${docs.length}',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
                        ),
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
              // Conteúdo expandido
              if (expanded) ...[
                const Divider(height: 1),
                if (docs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nenhum documento nesta pasta',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  )
                else
                  ...docs.map((doc) => _buildDocTile(doc)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocTile(_Doc doc) {
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
      title: Text(doc.titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: doc.categoria != null ? Text(doc.categoria!, style: const TextStyle(fontSize: 11)) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 16),
            onPressed: () => _showDocForm(doc: doc),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
            onPressed: () => _deleteDoc(doc),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

// ─── Botão de ação ────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.onTap});

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
  'Regulamento',
  'Ata',
  'Contrato',
  'Outros',
];

// ─── Tela de formulário do documento ─────────────────────────────────────────

class _DocFormScreen extends StatefulWidget {
  final String condoId;
  final List<_Pasta> pastas;
  final _Doc? doc;

  const _DocFormScreen({required this.condoId, required this.pastas, this.doc});

  @override
  State<_DocFormScreen> createState() => _DocFormScreenState();
}

class _DocFormScreenState extends State<_DocFormScreen> {
  late final TextEditingController _tituloCtrl;
  late final TextEditingController _dataValCtrl;
  String? _pastaId;
  String? _categoria;
  List<String> _categorias = [];
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
    final doc = widget.doc;
    _tituloCtrl    = TextEditingController(text: doc?.titulo ?? '');
    _dataValCtrl   = TextEditingController(text: doc?.dataValidade ?? '');
    _pastaId       = doc?.pastaId;
    _categoria     = doc?.categoria;
    _mostrarMoradores = doc?.mostrarMoradores ?? false;
    _avisarMoradores  = doc?.avisarMoradores  ?? false;
    _loadCategorias();
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
    _dataValCtrl.dispose();
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
      setState(() => _error = 'Informe o título do documento.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    final sb = Supabase.instance.client;

    String? arquivoUrl = widget.doc?.arquivoUrl;
    String? arquivoNome = widget.doc?.arquivoNome;

    if (_arquivo != null && _arquivo!.bytes != null) {
      final ext = _arquivo!.extension ?? 'pdf';
      final path = '${widget.condoId}/${DateTime.now().millisecondsSinceEpoch}.$ext';
      try {
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
      'data_validade':    _dataValCtrl.text.trim().isEmpty ? null : _dataValCtrl.text.trim(),
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
      if (widget.doc == null) {
        await sb.from(_tabelaDocs).insert(payload);
      } else {
        await sb.from(_tabelaDocs).update(payload).eq('id', widget.doc!.id);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() { _error = 'Erro ao salvar: $e'; _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.doc != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Editar Documento' : 'Novo Documento'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field('Título *', _tituloCtrl, hint: 'Ex: Regulamento Interno'),
            const SizedBox(height: 16),

            // ── Categoria dropdown + botão "+" ──
            const Text('Categoria', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _categoria,
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

            // Pasta
            const Text('Pasta', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _pastaId,
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

            _field('Data de validade', _dataValCtrl, hint: 'YYYY-MM-DD', keyboardType: TextInputType.datetime),
            const SizedBox(height: 16),

            // Arquivo
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
                        _arquivo?.name ?? widget.doc?.arquivoNome ?? 'Clique para selecionar arquivo',
                        style: TextStyle(
                          fontSize: 13,
                          color: _arquivo != null || widget.doc?.arquivoNome != null
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

            // Switches
            _switchTile('Mostrar para moradores?', _mostrarMoradores, (v) => setState(() => _mostrarMoradores = v)),
            _switchTile('Avisar todos os moradores (push)?', _avisarMoradores, (v) => setState(() => _avisarMoradores = v)),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('Lembretes de vencimento', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            _switchTile('Lembrar 30 dias antes', _lembrar30, (v) => setState(() => _lembrar30 = v)),
            _switchTile('Lembrar 60 dias antes', _lembrar60, (v) => setState(() => _lembrar60 = v)),
            _switchTile('Lembrar 90 dias antes', _lembrar90, (v) => setState(() => _lembrar90 = v)),

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
                    : Text(isEdit ? 'Salvar' : 'Inserir Documento',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {String? hint, TextInputType? keyboardType}) {
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

  Widget _switchTile(String label, bool value, ValueChanged<bool> onChange) {
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
