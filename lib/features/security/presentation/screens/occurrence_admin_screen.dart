import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/features/security/domain/models/occurrence.dart';
import 'package:condomeet/features/security/presentation/bloc/occurrence_bloc.dart';
import 'package:condomeet/features/security/presentation/bloc/occurrence_event.dart';
import 'package:condomeet/features/security/presentation/bloc/occurrence_state.dart';

class OccurrenceAdminScreen extends StatefulWidget {
  const OccurrenceAdminScreen({super.key});

  @override
  State<OccurrenceAdminScreen> createState() => _OccurrenceAdminScreenState();
}

class _OccurrenceAdminScreenState extends State<OccurrenceAdminScreen> {
  List<Occurrence> _occurrences = [];
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    final authState = context.read<AuthBloc>().state;
    final condoId = authState.condominiumId ?? '';
    context.read<OccurrenceBloc>().add(
      WatchAllOccurrencesRequested(condoId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text(
          'Livro de Ocorrências',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocConsumer<OccurrenceBloc, OccurrenceState>(
        listener: (context, state) {
          if (state is OccurrenceLoaded) {
            setState(() {
              _occurrences = state.occurrences;
              _hasLoaded = true;
            });
          }
        },
        builder: (context, state) {
          if (!_hasLoaded && state is! OccurrenceError) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_occurrences.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.book_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text('Nenhuma ocorrência registrada',
                      style: AppTypography.h2.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _occurrences.length,
            itemBuilder: (context, index) {
              final occ = _occurrences[index];
              final number = _occurrences.length - index;
              return _OccurrenceAdminCard(
                occurrence: occ,
                number: number,
                onResponseSaved: (response) async {
                  context.read<OccurrenceBloc>().add(
                    RespondOccurrenceRequested(
                      occurrenceId: occ.id,
                      response: response,
                    ),
                  );
                  // Wait briefly then refresh list
                  await Future.delayed(const Duration(milliseconds: 600));
                  if (mounted) _subscribe();
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _OccurrenceAdminCard extends StatefulWidget {
  final Occurrence occurrence;
  final int number;
  final Future<void> Function(String response) onResponseSaved;

  const _OccurrenceAdminCard({
    required this.occurrence,
    required this.number,
    required this.onResponseSaved,
  });

  @override
  State<_OccurrenceAdminCard> createState() => _OccurrenceAdminCardState();
}

class _OccurrenceAdminCardState extends State<_OccurrenceAdminCard> {
  late TextEditingController _controller;
  bool _isEditing = false;
  bool _saving = false;
  bool _savedFeedback = false;

  final DateFormat _dateFmt = DateFormat('dd/MM/yy – HH:mm');

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.occurrence.adminResponse ?? '');
    // Start in editing mode if no response yet
    _isEditing = !widget.occurrence.hasAdminResponse;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveResponse() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _saving = true);
    await widget.onResponseSaved(_controller.text.trim());
    if (mounted) {
      setState(() {
        _saving = false;
        _isEditing = false;
        _savedFeedback = true;
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _savedFeedback = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final occ = widget.occurrence;
    final hasResponse = occ.hasAdminResponse;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
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
          // Header
          Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ocorrência Nº ${widget.number}',
                  style: AppTypography.label.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                _StatusBadge(status: occ.status),
              ],
            ),
          ),

          // Detalhes
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (occ.assunto.isNotEmpty) ...[
                  _row('Assunto:', occ.assunto, bold: true),
                  const SizedBox(height: 6),
                ],
                _row('Ocorrência:', occ.description),
                const SizedBox(height: 6),
                _row('Data:', _dateFmt.format(occ.timestamp.toLocal())),

                // Foto
                if (occ.photoUrl != null && occ.photoUrl!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      occ.photoUrl!,
                      height: 130,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const Divider(height: 24, indent: 16, endIndent: 16),

          // Seção de resposta
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      hasResponse && !_isEditing
                          ? 'Resposta do Síndico:'
                          : 'Responder Ocorrência Nº ${widget.number}',
                      style: AppTypography.label.copyWith(
                        color: hasResponse && !_isEditing ? Colors.green.shade700 : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // Edit button (only shown when there's a response and not editing)
                    if (hasResponse && !_isEditing)
                      IconButton(
                        icon: Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                        tooltip: 'Editar resposta',
                        onPressed: () => setState(() => _isEditing = true),
                      ),
                  ],
                ),

                if (hasResponse && !_isEditing) ...[
                  // Read-only response view
                  if (occ.adminResponseAt != null)
                    Text(
                      'Respondido em: ${_dateFmt.format(occ.adminResponseAt!.toLocal())}',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade100),
                    ),
                    child: Text(occ.adminResponse!, style: AppTypography.bodyMedium),
                  ),
                ] else ...[
                  // Input field
                  const SizedBox(height: 8),
                  TextField(
                    controller: _controller,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Digite aqui a resposta para o Morador',
                      hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.6), fontSize: 14),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (_savedFeedback) ...[
                        const Icon(Icons.check_circle, color: Colors.green, size: 16),
                        const SizedBox(width: 4),
                        Text('Resposta enviada!', style: TextStyle(color: Colors.green.shade700, fontSize: 13)),
                      ],
                      const Spacer(),
                      if (_isEditing && hasResponse)
                        TextButton(
                          onPressed: () => setState(() {
                            _controller.text = occ.adminResponse ?? '';
                            _isEditing = false;
                          }),
                          child: const Text('Cancelar'),
                        ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: _saving
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send, size: 16),
                        label: Text(_saving ? 'Enviando...' : 'Enviar resposta'),
                        onPressed: _saving ? null : _saveResponse,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 14, color: AppColors.textMain),
        children: [
          TextSpan(text: '$label ', style: const TextStyle(fontWeight: FontWeight.w600)),
          TextSpan(
            text: value,
            style: TextStyle(fontWeight: bold ? FontWeight.w600 : FontWeight.normal),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final OccurrenceStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      OccurrenceStatus.resolved => ('Resolvido', Colors.green),
      OccurrenceStatus.closed => ('Fechado', Colors.grey),
      OccurrenceStatus.inProgress => ('Em Andamento', Colors.orange),
      OccurrenceStatus.open => ('Aberto', AppColors.primary),
      OccurrenceStatus.pending => ('Pendente', AppColors.primary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
