import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/features/community/domain/models/document.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/core/services/powersync_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

class ContractsScreen extends StatefulWidget {
  const ContractsScreen({super.key});

  @override
  State<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends State<ContractsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;
  List<CondoDocument> _contratos = [];
  bool _loading = true;
  String? _error;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    final condoId = context.read<AuthBloc>().state.condominiumId;
    if (condoId == null) {
      setState(() { _loading = false; _error = 'Condomínio não encontrado'; });
      return;
    }

    final db = GetIt.I<PowerSyncService>().db;
    _sub = db.watch(
      '''
      SELECT
        c.id, c.condominio_id, c.titulo, c.pasta_id,
        p.nome AS pasta_nome,
        c.arquivo_url, c.arquivo_nome, c.categoria,
        c.data_validade, c.data_expedicao,
        c.mostrar_moradores, c.descricao
      FROM contratos c
      LEFT JOIN contrato_pastas p ON p.id = c.pasta_id
      WHERE c.condominio_id = ?
        AND c.mostrar_moradores = 1
      ORDER BY p.nome NULLS LAST, c.titulo
      ''',
      parameters: [condoId],
    ).listen(
      (rows) {
        if (mounted) {
          setState(() {
            _contratos = rows.map((r) => CondoDocument.fromMap(r)).toList();
            _loading = false;
            _error = null;
          });
        }
      },
      onError: (e) {
        // Fallback: tabela pode ainda não ter sincronizado
        if (mounted) setState(() { _loading = false; });
      },
    );
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
    _sub?.cancel();
    super.dispose();
  }

  Map<String, List<CondoDocument>> get _grupos {
    final filtered = _contratos.where((d) {
      final q = _searchQuery;
      if (q.isEmpty) return true;
      return d.titulo.toLowerCase().contains(q) ||
          (d.categoria?.toLowerCase().contains(q) ?? false) ||
          (d.pastaNome?.toLowerCase().contains(q) ?? false);
    }).toList();

    final Map<String, List<CondoDocument>> grupos = {};
    for (final c in filtered) {
      final pasta = c.pastaNome ?? 'Sem pasta';
      grupos.putIfAbsent(pasta, () => []).add(c);
    }
    return grupos;
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

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) { return iso; }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contratos'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            child: CondoInput(
              label: '',
              hint: 'Buscar contratos...',
              controller: _searchController,
              prefix: const Icon(Icons.search, color: AppColors.textSecondary),
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));

    final grupos = _grupos;
    if (grupos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open_outlined, size: 56, color: AppColors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isEmpty ? 'Nenhum contrato disponível' : 'Nenhum resultado para "$_searchQuery"',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: grupos.entries.map((entry) {
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
                entry.key,
                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${entry.value.length} ${entry.value.length == 1 ? "contrato" : "contratos"}',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
              children: entry.value.map((doc) {
                final ext = doc.extensao;
                final color = _fileColor(ext);
                final icon = _fileIcon(ext);
                final temArquivo = doc.arquivoUrl != null && doc.arquivoUrl!.isNotEmpty;

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 40, height: 40,
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
                        Text('Validade: ${_formatDate(doc.dataValidade!)}',
                            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 10)),
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
              }).toList(),
            ),
          ),
        );
      }).toList(),
    );
  }
}
