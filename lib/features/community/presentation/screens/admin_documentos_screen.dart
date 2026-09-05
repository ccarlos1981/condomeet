import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/features/community/domain/models/document_constants.dart';
import 'package:condomeet/shared/utils/role_helper.dart';

// ─── Models Locais ───────────────────────────────────────────────────────────

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
  final String? tipoId; // Preservado caso já exista
  final String tipo; // obrigatorio, manutencao, outros
  final bool semValidade;
  final String? categoria; // Motivo do documento
  final String? arquivoUrl;
  final String? arquivoNome;
  final String? dataExpedicao;
  final String? dataValidade;
  final bool mostrarMoradores;
  final bool avisarMoradores;
  final bool lembrar30;
  final bool lembrar60;
  final bool lembrar90;

  _Doc({
    required this.id,
    required this.titulo,
    this.pastaId,
    this.tipoId,
    this.tipo = 'obrigatorio',
    this.semValidade = false,
    this.categoria,
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

  factory _Doc.fromMap(Map m) => _Doc(
        id: m['id'] as String,
        titulo: m['titulo'] as String? ?? '',
        pastaId: m['pasta_id'] as String?,
        tipoId: m['tipo_id'] as String?,
        tipo: m['tipo'] as String? ?? 'obrigatorio',
        semValidade: m['sem_validade'] == true || m['sem_validade'] == 1,
        categoria: m['categoria'] as String?,
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

const _tabelaPastas = 'doc_pastas';
const _tabelaDocs = 'documentos';
const _storageBucket = 'documentos';

// ─── Tela Principal ──────────────────────────────────────────────────────────

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
  String _search = '';
  String? _selectedTipoFilter; // 'obrigatorio', 'manutencao', 'outros' ou null

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
      final results = await Future.wait([
        sb.from(_tabelaPastas).select().eq('condominio_id', _condoId!).order('nome'),
        sb.from(_tabelaDocs).select().eq('condominio_id', _condoId!).order('created_at', ascending: false),
      ]);

      if (mounted) {
        setState(() {
          _pastas = (results[0] as List).map((m) => _Pasta.fromMap(m as Map)).toList();
          _docs = (results[1] as List).map((m) => _Doc.fromMap(m as Map)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_Doc> _docsNaPasta(String pastaId) {
    return _docs.where((d) => d.pastaId == pastaId).where((d) {
      final matchSearch = _search.isEmpty ||
          d.titulo.toLowerCase().contains(_search.toLowerCase()) ||
          (d.categoria?.toLowerCase().contains(_search.toLowerCase()) ?? false);

      final docTipoNorm = normalizeTipoDocumento(d.tipo);
      final matchTipo = _selectedTipoFilter == null || docTipoNorm == _selectedTipoFilter;

      return matchSearch && matchTipo;
    }).toList();
  }

  // ─── Pasta CRUD ────────────────────────────────────────────────────────────

  Future<void> _showPastaDialog({_Pasta? pasta}) async {
    if (!context.read<AuthBloc>().state.isAdministrativeUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Apenas administradores e síndicos podem gerenciar pastas.')),
      );
      return;
    }
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
    if (!context.read<AuthBloc>().state.isAdministrativeUser) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remover pasta?'),
        content: const Text('Os documentos dentro serão desvinculados da pasta.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
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
    if (!context.read<AuthBloc>().state.isAdministrativeUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Apenas administradores e síndicos podem cadastrar documentos.')),
      );
      return;
    }
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
    if (!context.read<AuthBloc>().state.isAdministrativeUser) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remover documento?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
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

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    if (!authState.isAdministrativeUser) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Documentos'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 72, color: AppColors.textSecondary),
                const SizedBox(height: 16),
                Text(
                  'Acesso Restrito',
                  style: AppTypography.h2.copyWith(color: AppColors.textMain),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Esta área de gerenciamento de documentos e pastas é exclusiva para administradores e síndicos do condomínio.',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  label: const Text('Voltar', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
    }
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
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.note_add_outlined,
                          label: 'Inserir documento',
                          onTap: () => _showDocForm(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.create_new_folder_outlined,
                          label: 'Criar pasta',
                          onTap: () => _showPastaDialog(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Filtros e Busca ─────────────────────────────────────
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar por título ou motivo...',
                      prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    onChanged: (v) => setState(() => _search = v.trim()),
                  ),
                  const SizedBox(height: 10),

                  // ── Chips de Filtro por Categoria ──
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'Todas',
                          isSelected: _selectedTipoFilter == null,
                          onTap: () => setState(() => _selectedTipoFilter = null),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Obrigatórios',
                          isSelected: _selectedTipoFilter == 'obrigatorio',
                          onTap: () => setState(() => _selectedTipoFilter = 'obrigatorio'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Manutenções',
                          isSelected: _selectedTipoFilter == 'manutencao',
                          onTap: () => setState(() => _selectedTipoFilter = 'manutencao'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Outros',
                          isSelected: _selectedTipoFilter == 'outros',
                          onTap: () => setState(() => _selectedTipoFilter = 'outros'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Pastas ───────────────────────────────────────────────
                  if (_pastas.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(Icons.folder_open, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            const Text('Nenhuma pasta criada ainda.', style: TextStyle(color: Colors.grey, fontSize: 14)),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._pastas.map((pasta) {
                      final docsDaPasta = _docsNaPasta(pasta.id);
                      final isExpanded = _expandedPastaId == pasta.id;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                        color: Colors.white,
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.folder, color: AppColors.primary, size: 28),
                              title: Text(pasta.nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              subtitle: Text('${docsDaPasta.length} documento(s)', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                                    onPressed: () => _showPastaDialog(pasta: pasta),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                    onPressed: () => _deletePasta(pasta),
                                  ),
                                  IconButton(
                                    icon: Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.grey),
                                    onPressed: () => setState(() => _expandedPastaId = isExpanded ? null : pasta.id),
                                  ),
                                ],
                              ),
                            ),
                            if (isExpanded) ...[
                              const Divider(height: 1),
                              if (docsDaPasta.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text('Nenhum documento nesta pasta.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                )
                              else
                                ...docsDaPasta.map((doc) {
                                  final badgeStyle = getCategoriaBadgeStyle(doc.tipo);
                                  final catLabel = getCategoriaLabel(doc.tipo);

                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    leading: Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.description_outlined,
                                        color: AppColors.primary,
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(doc.titulo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: badgeStyle.backgroundColor,
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: badgeStyle.borderColor),
                                              ),
                                              child: Text(
                                                catLabel,
                                                style: TextStyle(fontSize: 10, color: badgeStyle.textColor, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            if (doc.categoria != null && doc.categoria!.isNotEmpty) ...[
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  doc.categoria!,
                                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        if (doc.semValidade)
                                          const Text('Vigência: Permanente (sem validade)', style: TextStyle(fontSize: 11, color: Colors.grey))
                                        else if (doc.dataValidade != null)
                                          Text('Validade: ${doc.dataValidade}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                                          onPressed: () => _showDocForm(doc: doc),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                          onPressed: () => _deleteDoc(doc),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                            ],
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.grey.shade800,
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Formulário de Inclusão / Edição de Documento ─────────────────────────────

class _DocFormScreen extends StatefulWidget {
  final String condoId;
  final List<_Pasta> pastas;
  final _Doc? doc;

  const _DocFormScreen({
    required this.condoId,
    required this.pastas,
    this.doc,
  });

  @override
  State<_DocFormScreen> createState() => _DocFormScreenState();
}

class _DocFormScreenState extends State<_DocFormScreen> {
  late final TextEditingController _tituloCtrl;
  late final TextEditingController _customMotivoCtrl;

  String _tipo = 'obrigatorio'; // 'obrigatorio', 'manutencao', 'outros'
  String? _motivo;
  String? _pastaId;
  DateTime? _dataEmissao;
  DateTime? _dataValidade;
  bool _semValidade = false;
  bool _mostrarMoradores = false;
  bool _avisarMoradores = false;
  bool _lembrar30 = false;
  bool _lembrar60 = false;
  bool _lembrar90 = false;
  Uint8List? _arquivoBytes;
  String? _arquivoNome;
  String? _arquivoExt;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final doc = widget.doc;
    _tituloCtrl = TextEditingController(text: doc?.titulo ?? '');

    _tipo = normalizeTipoDocumento(doc?.tipo);
    _motivo = doc?.categoria;
    _customMotivoCtrl = TextEditingController(
      text: _tipo == 'outros' ? (doc?.categoria ?? '') : '',
    );

    _pastaId = doc?.pastaId;
    _semValidade = doc?.semValidade ?? false;
    _dataEmissao = _tryParseDate(doc?.dataExpedicao) ?? DateTime.now();
    _dataValidade = _semValidade ? null : _tryParseDate(doc?.dataValidade);
    _mostrarMoradores = doc?.mostrarMoradores ?? false;
    _avisarMoradores = doc?.avisarMoradores ?? false;
    _lembrar30 = _semValidade ? false : (doc?.lembrar30 ?? false);
    _lembrar60 = _semValidade ? false : (doc?.lembrar60 ?? false);
    _lembrar90 = _semValidade ? false : (doc?.lembrar90 ?? false);
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _customMotivoCtrl.dispose();
    super.dispose();
  }

  DateTime? _tryParseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  String _formatDateBR(DateTime? d) {
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  void _onTipoChanged(String newTipo) {
    if (newTipo == _tipo) return;
    setState(() {
      _tipo = newTipo;

      // Regra canônica: "Ao alterar a Categoria durante a edição, limpar o Motivo anterior caso ele não pertença à nova categoria."
      if (newTipo == 'obrigatorio') {
        if (!kMotivosObrigatorios.contains(_motivo)) {
          _motivo = null;
        }
      } else if (newTipo == 'manutencao') {
        if (!kMotivosManutencao.contains(_motivo)) {
          _motivo = null;
        }
      } else if (newTipo == 'outros') {
        _motivo = _customMotivoCtrl.text.trim();
      }
    });
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

  void _showAttachmentPickerModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('Anexar Arquivo ou Foto', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                title: const Text('Tirar foto com a câmera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                title: const Text('Escolher da galeria de fotos'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file_outlined, color: AppColors.primary),
                title: const Text('Selecionar documento (PDF, DOC, XLS...)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromFile();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFromCamera() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final name = picked.name.isNotEmpty ? picked.name : 'foto_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ext = name.contains('.') ? name.split('.').last : 'jpg';
        setState(() {
          _arquivoBytes = bytes;
          _arquivoNome = name;
          _arquivoExt = ext;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Erro ao capturar foto: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final name = picked.name.isNotEmpty ? picked.name : 'imagem_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ext = name.contains('.') ? name.split('.').last : 'jpg';
        setState(() {
          _arquivoBytes = bytes;
          _arquivoNome = name;
          _arquivoExt = ext;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Erro ao selecionar imagem: $e');
    }
  }

  Future<void> _pickFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'png', 'jpg'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          setState(() {
            _arquivoBytes = file.bytes;
            _arquivoNome = file.name;
            _arquivoExt = file.extension ?? 'pdf';
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Erro ao selecionar arquivo: $e');
    }
  }

  Future<void> _save() async {
    if (!context.read<AuthBloc>().state.isAdministrativeUser) {
      setState(() => _error = 'Apenas administradores e síndicos têm permissão para salvar documentos.');
      return;
    }

    if (_tituloCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Informe o título do documento.');
      return;
    }

    final finalMotivo = _tipo == 'outros' ? _customMotivoCtrl.text.trim() : (_motivo ?? '').trim();
    if (finalMotivo.isEmpty) {
      setState(() => _error = 'Informe o motivo do documento.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final sb = Supabase.instance.client;
    String? arquivoUrl = widget.doc?.arquivoUrl;
    String? arquivoNome = widget.doc?.arquivoNome;

    if (_arquivoBytes != null) {
      final ext = _arquivoExt ?? 'pdf';
      final path = '${widget.condoId}/${DateTime.now().millisecondsSinceEpoch}.$ext';
      try {
        await sb.storage.from(_storageBucket).uploadBinary(path, _arquivoBytes!).timeout(const Duration(seconds: 30));
        arquivoUrl = sb.storage.from(_storageBucket).getPublicUrl(path);
        arquivoNome = _arquivoNome;
      } catch (e) {
        if (mounted) setState(() { _error = 'Erro no upload: $e'; _saving = false; });
        return;
      }
    }

    final payload = {
      'condominio_id': widget.condoId,
      'pasta_id': _pastaId,
      // Para novos documentos: tipo_id permanece null. Para documentos existentes: preserva o existente.
      'tipo_id': widget.doc?.tipoId,
      'tipo': _tipo,
      'titulo': _tituloCtrl.text.trim(),
      'categoria': finalMotivo,
      'sem_validade': _semValidade,
      'data_expedicao': _dataEmissao != null ? '${_dataEmissao!.year}-${_dataEmissao!.month.toString().padLeft(2, '0')}-${_dataEmissao!.day.toString().padLeft(2, '0')}' : null,
      'data_validade': _semValidade
          ? null
          : (_dataValidade != null ? '${_dataValidade!.year}-${_dataValidade!.month.toString().padLeft(2, '0')}-${_dataValidade!.day.toString().padLeft(2, '0')}' : null),
      'arquivo_url': arquivoUrl,
      'arquivo_nome': arquivoNome,
      'mostrar_moradores': _mostrarMoradores,
      'avisar_moradores': _avisarMoradores,
      'lembrar_30': _semValidade ? false : _lembrar30,
      'lembrar_60': _semValidade ? false : _lembrar60,
      'lembrar_90': _semValidade ? false : _lembrar90,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      if (widget.doc == null) {
        await sb.from(_tabelaDocs).insert(payload).timeout(const Duration(seconds: 30));
      } else {
        await sb.from(_tabelaDocs).update(payload).eq('id', widget.doc!.id).timeout(const Duration(seconds: 30));
      }
      if (mounted) Navigator.pop(context, true);
    } on TimeoutException {
      if (mounted) setState(() { _error = 'Tempo limite excedido. Tente novamente.'; _saving = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Erro ao salvar: $e'; _saving = false; });
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
            // ── 1. Categoria (Radio Button) ──
            const Text('Categoria *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _CategoryRadioCard(
                    title: 'Obrigatório',
                    isSelected: _tipo == 'obrigatorio',
                    onTap: () => _onTipoChanged('obrigatorio'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CategoryRadioCard(
                    title: 'Manutenção',
                    isSelected: _tipo == 'manutencao',
                    onTap: () => _onTipoChanged('manutencao'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CategoryRadioCard(
                    title: 'Outros',
                    isSelected: _tipo == 'outros',
                    onTap: () => _onTipoChanged('outros'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── 2. Motivo do Documento (Dinâmico) ──
            const Text('Motivo do Documento *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),

            if (_tipo == 'obrigatorio')
              DropdownButtonFormField<String>(
                key: ValueKey('obrigatorio-$_motivo'),
                initialValue: kMotivosObrigatorios.contains(_motivo) ? _motivo : null,
                isExpanded: true,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  hintText: 'Selecione o motivo obrigatório',
                ),
                items: kMotivosObrigatorios.map((m) => DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) => setState(() => _motivo = v),
              ),

            if (_tipo == 'manutencao')
              DropdownButtonFormField<String>(
                key: ValueKey('manutencao-$_motivo'),
                initialValue: kMotivosManutencao.contains(_motivo) ? _motivo : null,
                isExpanded: true,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  hintText: 'Selecione o motivo de manutenção',
                ),
                items: kMotivosManutencao.map((m) => DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) => setState(() => _motivo = v),
              ),

            if (_tipo == 'outros')
              TextField(
                controller: _customMotivoCtrl,
                decoration: InputDecoration(
                  hintText: 'Informe o motivo (ex: Seguro da academia, Comunicado piscina...)',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (v) => _motivo = v.trim(),
              ),

            const SizedBox(height: 20),

            // ── 3. Título ──
            const Text('Título do Documento *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: _tituloCtrl,
              decoration: InputDecoration(
                hintText: 'Ex: Balancete de Março, AVCB 2026, Laudo Bombeiros...',
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),

            // ── 4. Pasta de Armazenamento ──
            const Text('Pasta de Armazenamento', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey('pasta-$_pastaId'),
              initialValue: widget.pastas.any((p) => p.id == _pastaId) ? _pastaId : null,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: 'Selecione a pasta (opcional)',
              ),
              items: widget.pastas.map((p) => DropdownMenuItem(value: p.id, child: Text(p.nome))).toList(),
              onChanged: (v) => setState(() => _pastaId = v),
            ),
            const SizedBox(height: 20),

            // ── 5. Datas e Sem Validade ──
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Data de Emissão', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _pickDate(isEmissao: true),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(_formatDateBR(_dataEmissao)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Data de Validade', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _semValidade ? null : () => _pickDate(isEmissao: false),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: _semValidade ? Colors.grey.shade100 : Colors.white,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, size: 16, color: _semValidade ? Colors.grey.shade400 : Colors.grey),
                              const SizedBox(width: 8),
                              Text(
                                _semValidade ? 'Sem validade' : (_dataValidade != null ? _formatDateBR(_dataValidade) : 'Definir data'),
                                style: TextStyle(color: _semValidade ? Colors.grey.shade500 : Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Toggle Sem Validade ──
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _semValidade,
              activeColor: AppColors.primary,
              title: const Text('Documento sem validade (permanente / indeterminado)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (v) {
                setState(() {
                  _semValidade = v ?? false;
                  if (_semValidade) {
                    _dataValidade = null;
                    _lembrar30 = false;
                    _lembrar60 = false;
                    _lembrar90 = false;
                  }
                });
              },
            ),
            const SizedBox(height: 16),

            // ── Lembretes de Vencimento ──
            if (!_semValidade) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Lembretes de Vencimento', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: _lembrar30,
                      activeColor: AppColors.primary,
                      title: const Text('Lembrar com 30 dias de antecedência', style: TextStyle(fontSize: 13)),
                      onChanged: (v) => setState(() => _lembrar30 = v ?? false),
                    ),
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: _lembrar60,
                      activeColor: AppColors.primary,
                      title: const Text('Lembrar com 60 dias de antecedência', style: TextStyle(fontSize: 13)),
                      onChanged: (v) => setState(() => _lembrar60 = v ?? false),
                    ),
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: _lembrar90,
                      activeColor: AppColors.primary,
                      title: const Text('Lembrar com 90 dias de antecedência', style: TextStyle(fontSize: 13)),
                      onChanged: (v) => setState(() => _lembrar90 = v ?? false),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Anexo de Arquivo ──
            const Text('Arquivo do Documento', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            InkWell(
              onTap: _showAttachmentPickerModal,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_upload_outlined, color: AppColors.primary, size: 24),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        _arquivoNome ?? (widget.doc?.arquivoNome ?? 'Anexar PDF, DOC, XLS ou Foto'),
                        style: TextStyle(
                          fontSize: 13,
                          color: _arquivoNome != null || widget.doc?.arquivoNome != null ? Colors.black87 : Colors.grey,
                          fontWeight: _arquivoNome != null ? FontWeight.bold : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Visibilidade e Notificação ──
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _mostrarMoradores,
              activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
              activeThumbColor: AppColors.primary,
              title: const Text('Mostrar aos moradores no app', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              onChanged: (v) => setState(() => _mostrarMoradores = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _avisarMoradores,
              activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
              activeThumbColor: AppColors.primary,
              title: const Text('Avisar moradores (Push na publicação)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              onChanged: (v) => setState(() => _avisarMoradores = v),
            ),
            const SizedBox(height: 24),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                child: Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
              ),
              const SizedBox(height: 16),
            ],

            // ── Salvar ──
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : Text(isEdit ? 'Salvar Alterações' : 'Inserir Documento', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRadioCard extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryRadioCard({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey.shade400,
                  width: 2,
                ),
                color: isSelected ? AppColors.primary : Colors.transparent,
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(Icons.circle, size: 8, color: Colors.white),
                    )
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primary : Colors.grey.shade800,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
