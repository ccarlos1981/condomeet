import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/features/security/domain/models/occurrence.dart';
import 'package:condomeet/features/security/presentation/bloc/occurrence_bloc.dart';
import 'package:condomeet/features/security/presentation/bloc/occurrence_event.dart';
import 'package:condomeet/features/security/presentation/bloc/occurrence_state.dart';

class OccurrenceHistoryScreen extends StatefulWidget {
  final String residentId;

  const OccurrenceHistoryScreen({super.key, required this.residentId});

  @override
  State<OccurrenceHistoryScreen> createState() => _OccurrenceHistoryScreenState();
}

class _OccurrenceHistoryScreenState extends State<OccurrenceHistoryScreen> {
  List<Occurrence> _cachedOccurrences = [];
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    // widget.residentId may be empty string when the router hasn't resolved userId yet.
    // Fall back to the AuthBloc's userId directly.
    final authState = context.read<AuthBloc>().state;
    final userId = widget.residentId.isNotEmpty
        ? widget.residentId
        : (authState.userId ?? '');
    context.read<OccurrenceBloc>().add(
      WatchResidentOccurrencesRequested(userId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Ocorrências'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: BlocConsumer<OccurrenceBloc, OccurrenceState>(
        listener: (context, state) {
          if (state is OccurrenceLoaded) {
            setState(() {
              _cachedOccurrences = state.occurrences;
              _hasLoaded = true;
            });
          }
          // NOTE: Do NOT re-subscribe on OccurrenceSuccess.
          // Supabase .stream() is realtime and fires automatically when new data is inserted.
          // Re-subscribing causes "Bad state: Stream has already been listened to".
        },
        builder: (context, state) {
          // Only show spinner on very first load, before any data has arrived
          if (!_hasLoaded && state is! OccurrenceError) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is OccurrenceError && !_hasLoaded) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(state.message, textAlign: TextAlign.center),
                ],
              ),
            );
          }

          final occurrences = _cachedOccurrences;

          return Column(
            children: [
              // Botão Nova Ocorrência
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text(
                      'Nova Ocorrência',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    onPressed: () => Navigator.of(context)
                        .pushNamed('/new-occurrence')
                        .then((_) => _subscribe()),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Lista
              Expanded(
                child: occurrences.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: () async => _subscribe(),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: occurrences.length,
                          itemBuilder: (context, index) {
                            return _OccurrenceCard(
                              occurrence: occurrences[index],
                              number: occurrences.length - index,
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'Nenhuma ocorrência registrada',
            style: AppTypography.h2.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Use o botão acima para registrar\numa nova ocorrência.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _OccurrenceCard extends StatelessWidget {
  final Occurrence occurrence;
  final int number;

  const _OccurrenceCard({required this.occurrence, required this.number});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yy – HH:mm');
    final hasResponse = occurrence.hasAdminResponse;

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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ocorrência Nº $number',
                        style: AppTypography.label.copyWith(color: AppColors.textSecondary),
                      ),
                      if (occurrence.assunto.isNotEmpty)
                        Text(
                          occurrence.assunto,
                          style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(status: occurrence.status),
              ],
            ),
          ),

          const Divider(height: 1),

          // Conteúdo da ocorrência
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ocorrência:',
                  style: AppTypography.label.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(occurrence.description, style: AppTypography.bodyMedium),

                // Foto
                if (occurrence.photoUrl != null && occurrence.photoUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      occurrence.photoUrl!,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 140,
                          color: AppColors.surface,
                          child: const Center(child: CircularProgressIndicator()),
                        );
                      },
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ],

                const SizedBox(height: 8),
                Text(
                  'Ocorrência criada em: ${dateFmt.format(occurrence.timestamp.toLocal())}',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),

          // Resposta do Admin
          if (hasResponse) ...[
            const Divider(height: 1),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, size: 16, color: Colors.green),
                      const SizedBox(width: 6),
                      Text(
                        'Resposta do Adm/Síndico:',
                        style: AppTypography.label.copyWith(color: Colors.green.shade700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(occurrence.adminResponse!, style: AppTypography.bodyMedium),
                  if (occurrence.adminResponseAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Respondido em: ${dateFmt.format(occurrence.adminResponseAt!.toLocal())}',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Text(
                'Aguardando resposta da administração...',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final OccurrenceStatus status;

  const _StatusBadge({required this.status});

  Color get _color {
    switch (status) {
      case OccurrenceStatus.resolved:
      case OccurrenceStatus.closed:
        return Colors.green;
      case OccurrenceStatus.inProgress:
        return Colors.orange;
      case OccurrenceStatus.open:
      case OccurrenceStatus.pending:
        return AppColors.primary;
    }
  }

  String get _label {
    switch (status) {
      case OccurrenceStatus.open:
        return 'Aberto';
      case OccurrenceStatus.pending:
        return 'Pendente';
      case OccurrenceStatus.inProgress:
        return 'Em Andamento';
      case OccurrenceStatus.resolved:
        return 'Resolvido';
      case OccurrenceStatus.closed:
        return 'Fechado';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: _color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
