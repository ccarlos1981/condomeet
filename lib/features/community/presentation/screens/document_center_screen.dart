import 'package:flutter/material.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/features/community/domain/models/document.dart';
import 'package:condomeet/features/community/data/repositories/document_repository_impl.dart';

class DocumentCenterScreen extends StatefulWidget {
  const DocumentCenterScreen({super.key});

  @override
  State<DocumentCenterScreen> createState() => _DocumentCenterScreenState();
}

class _DocumentCenterScreenState extends State<DocumentCenterScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<CondoDocument> _allDocuments = [];
  List<CondoDocument> _filteredDocuments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
    _searchController.addListener(_filterDocuments);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    final result = await documentRepository.getDocuments();
    if (mounted) {
      setState(() {
        if (result is Success<List<CondoDocument>>) {
          _allDocuments = result.data;
          _filteredDocuments = _allDocuments;
        }
        _isLoading = false;
      });
    }
  }

  void _filterDocuments() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredDocuments = _allDocuments.where((doc) {
        return doc.title.toLowerCase().contains(query) ||
               doc.categoryName.toLowerCase().contains(query);
      }).toList();
    });
  }

  void _simulateDownload(CondoDocument doc) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('Abrindo "${doc.title}"...')),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Central de Documentos'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: CondoInput(
              label: '',
              hint: 'Buscar atas, regimentos...',
              controller: _searchController,
              prefix: const Icon(Icons.search, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredDocuments.isEmpty
                    ? const Center(child: Text('Nenhum documento encontrado.'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: _filteredDocuments.length,
                        itemBuilder: (context, index) {
                          return _buildDocumentTile(_filteredDocuments[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentTile(CondoDocument doc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _getFileColor(doc.fileExtension).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getFileIcon(doc.fileExtension),
            color: _getFileColor(doc.fileExtension),
          ),
        ),
        title: Text(doc.title, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(doc.categoryName, style: AppTypography.bodySmall.copyWith(color: AppColors.primary)),
            Text(
              'Publicado em: ${doc.uploadDate.day}/${doc.uploadDate.month}/${doc.uploadDate.year}',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 10),
            ),
          ],
        ),
        trailing: const Icon(Icons.file_download_outlined, color: AppColors.textSecondary),
        onTap: () => _simulateDownload(doc),
      ),
    );
  }

  IconData _getFileIcon(String ext) {
    if (ext == 'pdf') return Icons.picture_as_pdf_outlined;
    if (ext == 'docx' || ext == 'doc') return Icons.description_outlined;
    return Icons.insert_drive_file_outlined;
  }

  Color _getFileColor(String ext) {
    if (ext == 'pdf') return Colors.red;
    if (ext == 'docx' || ext == 'doc') return Colors.blue;
    return AppColors.primary;
  }
}
