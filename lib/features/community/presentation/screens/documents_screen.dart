import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class _Document {
  final String id;
  final String titulo;
  final String? categoria;
  final String? arquivoUrl;
  final String? arquivoNome;
  final String? dataValidade;
  final DateTime? createdAt;

  const _Document({
    required this.id,
    required this.titulo,
    this.categoria,
    this.arquivoUrl,
    this.arquivoNome,
    this.dataValidade,
    this.createdAt,
  });

  factory _Document.fromMap(Map<String, dynamic> m) => _Document(
        id: m['id'] as String,
        titulo: m['titulo'] as String? ?? '',
        categoria: m['categoria'] as String?,
        arquivoUrl: m['arquivo_url'] as String?,
        arquivoNome: m['arquivo_nome'] as String?,
        dataValidade: m['data_validade'] as String?,
        createdAt: m['created_at'] != null
            ? DateTime.tryParse(m['created_at'] as String)
            : null,
      );

  bool get isExpired {
    if (dataValidade == null) return false;
    final expiry = DateTime.tryParse(dataValidade!);
    if (expiry == null) return false;
    return expiry.isBefore(DateTime.now());
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<_Document> _allDocs = [];
  bool _loading = true;
  String _search = '';
  String? _selectedCategory;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final condoId = context.read<AuthBloc>().state.condominiumId;
    if (condoId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final res = await Supabase.instance.client
          .from('documentos')
          .select('id, titulo, categoria, arquivo_url, arquivo_nome, data_validade, created_at')
          .eq('condominio_id', condoId)
          .eq('mostrar_moradores', true)
          .order('titulo');
      if (mounted) {
        setState(() {
          _allDocs = (res as List).map((m) => _Document.fromMap(Map<String, dynamic>.from(m))).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> get _categories {
    final cats = _allDocs.map((d) => d.categoria).whereType<String>().toSet().toList()..sort();
    return cats;
  }

  List<_Document> get _filtered {
    final q = _search.toLowerCase();
    return _allDocs.where((d) {
      final matchesSearch = q.isEmpty ||
          d.titulo.toLowerCase().contains(q) ||
          (d.categoria?.toLowerCase().contains(q) ?? false);
      final matchesCat =
          _selectedCategory == null || d.categoria == _selectedCategory;
      return matchesSearch && matchesCat;
    }).toList();
  }

  Future<void> _openDocument(_Document doc) async {
    if (doc.arquivoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Arquivo não disponível.')),
      );
      return;
    }
    final uri = Uri.tryParse(doc.arquivoUrl!);
    if (uri == null) return;
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o arquivo.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao abrir o arquivo.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Documentos',
          style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _load,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          if (_categories.isNotEmpty) _buildCategoryChips(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _search = v),
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Buscar por título ou categoria...',
          hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
          prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
          suffixIcon: _search.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16, color: Colors.grey),
                  onPressed: () => setState(() {
                    _searchCtrl.clear();
                    _search = '';
                  }),
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.primary),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _categoryChip('Todos', null),
            ..._categories.map((cat) => _categoryChip(cat, cat)),
          ],
        ),
      ),
    );
  }

  Widget _categoryChip(String label, String? value) {
    final selected = _selectedCategory == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 12, color: selected ? Colors.white : Colors.black87)),
        selected: selected,
        selectedColor: AppColors.primary,
        backgroundColor: Colors.grey.shade100,
        side: BorderSide(color: selected ? AppColors.primary : Colors.grey.shade300),
        onSelected: (_) => setState(() => _selectedCategory = value),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final docs = _filtered;
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              _allDocs.isEmpty
                  ? 'Nenhum documento disponível'
                  : 'Nenhum documento encontrado',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
            if (_allDocs.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Os documentos publicados pelo síndico\naparecerão aqui.',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: docs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _buildDocTile(docs[i]),
      ),
    );
  }

  Widget _buildDocTile(_Document doc) {
    final ext = _extension(doc.arquivoNome ?? doc.arquivoUrl ?? '');
    final icon = _iconForExt(ext);
    final color = _colorForExt(ext);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: doc.arquivoUrl != null ? () => _openDocument(doc) : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              // File type icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.titulo,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (doc.categoria != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              doc.categoria!,
                              style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w500),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (doc.isExpired)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'EXPIRADO',
                              style: TextStyle(fontSize: 10, color: Colors.red.shade700, fontWeight: FontWeight.bold),
                            ),
                          )
                        else if (doc.dataValidade != null)
                          Text(
                            'Válido até ${_formatDate(doc.dataValidade!)}',
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Open icon
              if (doc.arquivoUrl != null)
                Icon(Icons.open_in_new, size: 18, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  String _extension(String filename) {
    final parts = filename.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  IconData _iconForExt(String ext) {
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'doc':
      case 'docx':
        return Icons.description_outlined;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_outlined;
      case 'png':
      case 'jpg':
      case 'jpeg':
        return Icons.image_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  Color _colorForExt(String ext) {
    switch (ext) {
      case 'pdf':
        return Colors.red.shade600;
      case 'doc':
      case 'docx':
        return Colors.blue.shade600;
      case 'xls':
      case 'xlsx':
        return Colors.green.shade600;
      case 'png':
      case 'jpg':
      case 'jpeg':
        return Colors.purple.shade400;
      default:
        return AppColors.primary;
    }
  }

  String _formatDate(String dateStr) {
    final d = DateTime.tryParse(dateStr);
    if (d == null) return dateStr;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
