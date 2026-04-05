import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/features/assembleia/domain/models/pauta_model.dart';

class AssembleiaVotingSheet extends StatefulWidget {
  final PautaModel pauta;
  final String assembleiaId;
  final String userId;
  final Map<String, int>? resultados; // opcao -> count
  final String? myVote;

  const AssembleiaVotingSheet({
    super.key,
    required this.pauta,
    required this.assembleiaId,
    required this.userId,
    this.resultados,
    this.myVote,
  });

  @override
  State<AssembleiaVotingSheet> createState() => _AssembleiaVotingSheetState();
}

class _AssembleiaVotingSheetState extends State<AssembleiaVotingSheet> {
  final _supabase = Supabase.instance.client;
  String? _selected;
  bool _submitting = false;
  bool _voted = false;

  @override
  void initState() {
    super.initState();
    _voted = widget.myVote != null;
    _selected = widget.myVote;
  }

  Future<void> _submitVote() async {
    if (_selected == null || _submitting) return;

    setState(() => _submitting = true);

    try {
      await _supabase.from('assembleia_votos').insert({
        'assembleia_id': widget.assembleiaId,
        'pauta_id': widget.pauta.id,
        'voto': _selected,
        'votante_user_id': widget.userId,
      });

      if (mounted) {
        setState(() {
          _voted = true;
          _submitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Voto registrado com sucesso!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: ${e.toString().contains('duplicate') ? 'Você já votou nesta pauta' : e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultados = widget.resultados ?? {};
    final totalVotos = resultados.values.fold<int>(0, (a, b) => a + b);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${widget.pauta.ordem}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.pauta.titulo,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),

          if (widget.pauta.descricao != null && widget.pauta.descricao!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              widget.pauta.descricao!,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
          ],

          const SizedBox(height: 8),
          Row(
            children: [
              _buildChip(widget.pauta.quorumLabel, Icons.scale),
              const SizedBox(width: 6),
              _buildChip(
                widget.pauta.isAberta ? 'Aberta' : 'Encerrada',
                widget.pauta.isAberta ? Icons.how_to_vote : Icons.lock,
                color: widget.pauta.isAberta ? Colors.green : Colors.red,
              ),
            ],
          ),

          const SizedBox(height: 16),
          Divider(color: Colors.grey.shade200),
          const SizedBox(height: 12),

          // Status banner
          if (_voted) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Seu voto foi registrado',
                      style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Options
          ...widget.pauta.opcoesVoto.map((opcao) {
            final isSelected = _selected == opcao;
            final voteCount = resultados[opcao] ?? 0;
            final pct = totalVotos > 0 ? voteCount / totalVotos : 0.0;
            final showBar = _voted || !widget.pauta.isAberta;

            return GestureDetector(
              onTap: _voted || !widget.pauta.isAberta
                  ? null
                  : () => setState(() => _selected = opcao),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey.shade200,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (!_voted && widget.pauta.isAberta) ...[
                          Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: isSelected ? AppColors.primary : Colors.grey.shade400,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Text(
                            opcao,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: AppColors.textMain,
                            ),
                          ),
                        ),
                        if (showBar)
                          Text(
                            '${(pct * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isSelected ? AppColors.primary : AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                    if (showBar) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: Colors.grey.shade200,
                          color: isSelected ? AppColors.primary : Colors.grey.shade400,
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$voteCount votos',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),

          // Submit button
          if (!_voted && widget.pauta.isAberta) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _selected == null || _submitting ? null : _submitVote,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade200,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Confirmar Voto',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],

          // Pauta not open
          if (!widget.pauta.isAberta && !_voted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    'Votação encerrada para esta pauta',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChip(String text, IconData icon, {Color? color}) {
    final c = color ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
