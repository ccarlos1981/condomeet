import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/features/community/domain/models/document.dart';
import 'package:condomeet/features/community/presentation/bloc/document_bloc.dart';
import 'package:condomeet/features/community/presentation/bloc/document_bloc_components.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';

class DocumentCenterScreen extends StatefulWidget {
  const DocumentCenterScreen({super.key});

  @override
  State<DocumentCenterScreen> createState() => _DocumentCenterScreenState();
}

class _DocumentCenterScreenState extends State<DocumentCenterScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState.condominiumId != null) {
      context.read<DocumentBloc>().add(WatchDocumentsRequested(authState.condominiumId!));
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _searchQuery = query.toLowerCase());
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o arquivo.')),
        );
      }
    }
  }

  /// Agrupa documentos filtrados por nome de pasta
  Map<String, List<CondoDocument>> _groupByPasta(List<CondoDocument> docs) {
    final filtered = docs.where((d) {
      final q = _searchQuery;
      if (q.isEmpty) return true;
      return d.titulo.toLowerCase().contains(q) ||
          (d.categoria?.toLowerCase().contains(q) ?? false) ||
          (d.pastaNome?.toLowerCase().contains(q) ?? false);
    }).toList();

    final Map<String, List<CondoDocument>> grupos = {};
    for (final doc in filtered) {
      final pasta = doc.pastaNome ?? 'Sem pasta';
      grupos.putIfAbsent(pasta, () => []).add(doc);
    }
    return grupos;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documentos'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            child: CondoInput(
              label: '',
              hint: 'Buscar documentos...',
              controller: _searchController,
              prefix: const Icon(Icons.search, color: AppColors.textSecondary),
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(
            child: BlocBuilder<DocumentBloc, DocumentState>(
              builder: (context, state) {
                if (state is DocumentLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is DocumentError) {
                  return Center(child: Text(state.message));
                }
                if (state is DocumentLoaded) {
                  final grupos = _groupByPasta(state.documents);
                  if (grupos.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder_open_outlined, size: 56, color: AppColors.textSecondary.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isEmpty
                                ? 'Nenhum documento disponível'
                                : 'Nenhum resultado para "$_searchQuery"',
                            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    children: grupos.entries.map((entry) {
                      return _buildPastaCard(entry.key, entry.value);
                    }).toList(),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPastaCard(String pastaNome, List<CondoDocument> docs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: const Icon(Icons.folder_open_outlined, color: AppColors.primary),
          title: Text(
            pastaNome,
            style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '${docs.length} ${docs.length == 1 ? "documento" : "documentos"}',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          children: docs.map((doc) => _buildDocumentTile(doc)).toList(),
        ),
      ),
    );
  }

  Widget _buildDocumentTile(CondoDocument doc) {
    final ext = doc.extensao;
    final color = _fileColor(ext);
    final icon = _fileIcon(ext);
    final temArquivo = doc.arquivoUrl != null && doc.arquivoUrl!.isNotEmpty;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(doc.titulo, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (doc.categoria != null && doc.categoria!.isNotEmpty)
            Text(doc.categoria!, style: AppTypography.bodySmall.copyWith(color: AppColors.primary)),
          if (doc.dataValidade != null)
            Text(
              'Validade: ${_formatDate(doc.dataValidade!)}',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 10),
            ),
        ],
      ),
      trailing: temArquivo
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility_outlined, size: 20),
                  color: AppColors.textSecondary,
                  tooltip: 'Visualizar',
                  onPressed: () => _openUrl(doc.arquivoUrl!),
                ),
                IconButton(
                  icon: const Icon(Icons.download_outlined, size: 20),
                  color: AppColors.primary,
                  tooltip: 'Baixar',
                  onPressed: () => _openUrl(doc.arquivoUrl!),
                ),
              ],
            )
          : const Icon(Icons.attachment_outlined, color: AppColors.border, size: 20),
    );
  }

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return iso;
    }
  }

  IconData _fileIcon(String ext) {
    if (ext == 'pdf') return Icons.picture_as_pdf_outlined;
    if (ext == 'doc' || ext == 'docx') return Icons.description_outlined;
    if (ext == 'xls' || ext == 'xlsx') return Icons.table_chart_outlined;
    return Icons.insert_drive_file_outlined;
  }

  Color _fileColor(String ext) {
    if (ext == 'pdf') return Colors.red.shade600;
    if (ext == 'doc' || ext == 'docx') return Colors.blue.shade600;
    if (ext == 'xls' || ext == 'xlsx') return Colors.green.shade600;
    return AppColors.primary;
  }
}
