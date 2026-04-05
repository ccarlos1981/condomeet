import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/features/assembleia/presentation/screens/document_viewer_screen.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/features/assembleia/domain/models/assembleia_model.dart';
import 'package:condomeet/features/assembleia/domain/models/pauta_model.dart';

class AssembleiaDetalheScreen extends StatefulWidget {
  final String assembleiaId;
  const AssembleiaDetalheScreen({super.key, required this.assembleiaId});

  @override
  State<AssembleiaDetalheScreen> createState() => _AssembleiaDetalheScreenState();
}

class _AssembleiaDetalheScreenState extends State<AssembleiaDetalheScreen> {
  final _supabase = Supabase.instance.client;
  AssembleiaModel? _assembleia;
  List<PautaModel> _pautas = [];
  bool _loading = true;
  bool _submittingVote = false;
  Map<String, Map<String, int>> _resultados = {}; // pauta_id -> {opcao: count}
  Map<String, String> _meusVotos = {}; // pauta_id -> voto string do morador
  Map<String, dynamic> _selectedOptions = {}; // pauta_id -> seleções temporárias
  String? _myUnitId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // Fetch assembly
      final aData = await _supabase
          .from('assembleias')
          .select()
          .eq('id', widget.assembleiaId)
          .single();

      // Fetch pautas
      final pData = await _supabase
          .from('assembleia_pautas')
          .select()
          .eq('assembleia_id', widget.assembleiaId)
          .order('ordem', ascending: true);

      final resultados = <String, Map<String, int>>{};
      
      try {
        // Fetch vote results (if encerrada) 
        // THIS WILL ONLY LOAD THE USER'S OWN VOTES DUE TO RLS (if resident)
        // Admin gets all votes.
        final vData = await _supabase
            .from('assembleia_votos')
            .select('pauta_id, voto')
            .eq('assembleia_id', widget.assembleiaId);

        for (final v in vData) {
          final pId = v['pauta_id'] as String;
          final votoStr = v['voto'] as String;
          resultados.putIfAbsent(pId, () => {});
          
          if (votoStr.startsWith('[')) {
            final stripped = votoStr.replaceAll(RegExp(r'[\[\]"]'), '');
            final opts = stripped.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
            for (final opt in opts) {
              resultados[pId]![opt] = (resultados[pId]![opt] ?? 0) + 1;
            }
          } else {
             resultados[pId]![votoStr] = (resultados[pId]![votoStr] ?? 0) + 1;
          }
        }
      } catch (_) {}

      final userId = _supabase.auth.currentUser?.id;
      final meusVotos = <String, String>{};
      String? unitId;
      
      if (userId != null) {
        try {
          // Obter unidade do morador
          final perfil = await _supabase
              .from('perfil')
              .select('unidade_id')
              .eq('id', userId)
              .maybeSingle();
          unitId = perfil?['unidade_id'] as String?;

          // Obter votos que este morador já fez
          final mvData = await _supabase
              .from('assembleia_votos')
              .select('pauta_id, voto')
              .eq('assembleia_id', widget.assembleiaId)
              .eq('votante_user_id', userId);
              
          for (final mv in mvData) {
             meusVotos[mv['pauta_id'] as String] = mv['voto'] as String;
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _assembleia = AssembleiaModel.fromMap(aData);
          _pautas = (pData as List).map((e) => PautaModel.fromMap(e)).toList();
          _resultados = resultados;
          _meusVotos = meusVotos;
          _myUnitId = unitId;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching assembleia detalhe: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: (_loading || _assembleia == null)
          ? AppBar(
              backgroundColor: AppColors.surface,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _assembleia == null
              ? const Center(child: Text('Assembleia não encontrada'))
              : CustomScrollView(
                  slivers: [
                    _buildSliverAppBar(),
                    SliverToBoxAdapter(child: _buildBody()),
                  ],
                ),
      bottomNavigationBar: _assembleia?.isLive == true ? _buildLiveFooter() : null,
    );
  }

  Widget _buildSliverAppBar() {
    final a = _assembleia!;
    Color headerColor;
    IconData headerIcon;

    if (a.isLive) {
      headerColor = Colors.red;
      headerIcon = Icons.videocam;
    } else if (a.isScheduled) {
      headerColor = Colors.blue;
      headerIcon = Icons.event;
    } else {
      headerColor = Colors.teal;
      headerIcon = Icons.gavel;
    }

    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: headerColor,
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          a.nome,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [headerColor, headerColor.withValues(alpha: 0.7)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -30,
                bottom: -20,
                child: Icon(headerIcon, size: 160, color: Colors.white.withValues(alpha: 0.1)),
              ),
              Positioned(
                left: 20,
                bottom: 60,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        a.tipo,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        a.statusLabel,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final a = _assembleia!;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info Cards
          _buildInfoSection(a),
          const SizedBox(height: 20),

          // Edital
          if (a.editalUrl != null && a.editalUrl!.isNotEmpty) ...[
            _buildDocumentCard(
              icon: Icons.description,
              title: 'Edital da Assembleia',
              subtitle: 'Toque para visualizar',
              color: Colors.orange,
              onTap: () => _openUrl(a.editalUrl!, 'Edital da Assembleia'),
            ),
            const SizedBox(height: 16),
          ],

          // ATA
          if (a.ataUrl != null && a.ataUrl!.isNotEmpty) ...[
            _buildDocumentCard(
              icon: Icons.article,
              title: 'ATA da Assembleia',
              subtitle: 'Documento oficial gerado',
              color: Colors.green,
              onTap: () => _openUrl(a.ataUrl!, 'ATA da Assembleia'),
            ),
            const SizedBox(height: 16),
          ],

          // Gravação
          if (a.gravacaoUrl != null && a.gravacaoUrl!.isNotEmpty) ...[
            _buildDocumentCard(
              icon: Icons.play_circle_fill,
              title: 'Gravação da Sessão',
              subtitle: 'Assista a gravação completa',
              color: Colors.purple,
              onTap: () => _openUrl(a.gravacaoUrl!, 'Gravação da Sessão'),
            ),
            const SizedBox(height: 16),
          ],

          // Pautas
          const Text(
            'Pautas',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 12),
          if (_pautas.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'Nenhuma pauta cadastrada',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ..._pautas.map((p) => _buildPautaCard(p)),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildInfoSection(AssembleiaModel a) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.category_outlined, 'Tipo', a.tipoLabel),
          _buildDivider(),
          _buildInfoRow(Icons.public, 'Modalidade', a.modalidade == 'online' ? 'Online' : a.modalidade == 'presencial' ? 'Presencial' : 'Híbrida'),
          _buildDivider(),
          _buildInfoRow(
            a.isYoutube ? Icons.play_circle : Icons.sensors,
            'Transmissão',
            a.isYoutube ? 'YouTube Live' : 'Agora.io',
          ),
          if (a.dt1aConvocacao != null) ...[
            _buildDivider(),
            _buildInfoRow(Icons.calendar_today, '1ª Convocação', _formatDateTime(a.dt1aConvocacao)),
          ],
          if (a.dt2aConvocacao != null) ...[
            _buildDivider(),
            _buildInfoRow(Icons.calendar_month, '2ª Convocação', _formatDateTime(a.dt2aConvocacao)),
          ],
          if (a.localPresencial != null && a.localPresencial!.isNotEmpty) ...[
            _buildDivider(),
            _buildInfoRow(Icons.location_on_outlined, 'Local', a.localPresencial!),
          ],
          if (a.dtInicioVotacao != null) ...[
            _buildDivider(),
            _buildInfoRow(Icons.how_to_vote, 'Votação', '${_formatDateTime(a.dtInicioVotacao)} até ${_formatDateTime(a.dtFimVotacao)}'),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, color: Colors.grey.shade100);
  }

  Widget _buildDocumentCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildPautaCard(PautaModel p) {

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: p.isAberta
              ? Colors.green.shade200
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: p.isAberta ? Colors.green.shade50 : Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${p.ordem}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    p.titulo,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                // Tipo badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: p.isVotacao
                        ? Colors.amber.shade100
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        p.isVotacao ? Icons.how_to_vote : Icons.info_outline,
                        size: 12,
                        color: p.isVotacao ? Colors.amber.shade800 : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        p.isVotacao ? 'Votação' : 'Info',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: p.isVotacao ? Colors.amber.shade800 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (p.descricao != null && p.descricao!.isNotEmpty) ...[
                  Text(
                    p.descricao!,
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                ],
                if (p.isVotacao) ...[
                  Row(
                    children: [
                      _buildPautaChip('Quórum: ${p.quorumLabel}'),
                      const SizedBox(width: 6),
                      _buildPautaChip(p.modoResposta == 'unica' ? 'Voto único' : 'Múltipla escolha'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildVotingArea(p),
                  if (_assembleia!.isFinished || p.resultadoVisivel) ...[
                    const SizedBox(height: 16),
                    _buildVoteResults(p),
                  ]
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPautaChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
      ),
    );
  }

  Widget _buildLiveFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: () => Navigator.pushNamed(
            context,
            '/assembleia-live',
            arguments: widget.assembleiaId,
          ),
          icon: const Icon(Icons.play_arrow, size: 22),
          label: const Text('Participar da Sessão ao Vivo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }

  String _formatDateTime(String? isoDate) {
    if (isoDate == null) return '—';
    try {
      final dt = DateTime.parse(isoDate);
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return isoDate;
    }
  }

  Future<void> _openUrl(String url, String title) async {
    String finalUrl = url.trim();

    // Se for um caminho do bucket do Supabase (ex: assembleias/condo_id/...)
    if (finalUrl.startsWith('assembleias/')) {
      try {
        // Tenta gerar um link assinado (para buckets privados)
        finalUrl = await Supabase.instance.client.storage
            .from('assembleia-recordings')
            .createSignedUrl(finalUrl, 60 * 60); // 1 hora de validade
      } catch (e) {
        // Se falhar o signed url, tenta gerar a URL pública
        finalUrl = Supabase.instance.client.storage
            .from('assembleia-recordings')
            .getPublicUrl(finalUrl);
      }
    } else if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
      finalUrl = 'https://$finalUrl';
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DocumentViewerScreen(
            url: finalUrl,
            title: title,
          ),
        ),
      );
    }
  }

  Widget _buildVotingArea(PautaModel p) {
    if (_assembleia?.isFinished == true) {
      return const SizedBox.shrink(); // Hide voting area if assembly is complete
    }
    
    if (_meusVotos.containsKey(p.id)) {
       final strVoto = _meusVotos[p.id]!.replaceAll(RegExp(r'[\[\]"]'), '').replaceAll(',', ', ');
       return Container(
         width: double.infinity,
         padding: const EdgeInsets.all(12),
         decoration: BoxDecoration(
           color: Colors.green.shade50,
           borderRadius: BorderRadius.circular(8),
           border: Border.all(color: Colors.green.shade200),
         ),
         child: Row(
           children: [
             Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
             const SizedBox(width: 8),
             Expanded(
               child: Text('Você votou: $strVoto', style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 13)),
             ),
           ],
         ),
       );
    }
    
    if (!_assembleia!.isLive) {
      return Container(
         padding: const EdgeInsets.all(12),
         decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
         child: const Text('A votação ainda não foi aberta.', style: TextStyle(fontSize: 13, color: Colors.grey)),
      );
    }

    final opcoes = p.opcoesVoto;
    if (opcoes.isEmpty) return const SizedBox.shrink();

    final isMultipla = p.modoResposta == 'multipla';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         const Text('Seu Voto:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
         const SizedBox(height: 8),
         ...opcoes.map((opt) {
           if (isMultipla) {
             final List<String> currentSelections = _selectedOptions[p.id] as List<String>? ?? <String>[];
             final isSelected = currentSelections.contains(opt);
             return CheckboxListTile(
               title: Text(opt, style: const TextStyle(fontSize: 13)),
               value: isSelected,
               dense: true,
               controlAffinity: ListTileControlAffinity.leading,
               contentPadding: EdgeInsets.zero,
               activeColor: AppColors.primary,
               onChanged: _submittingVote ? null : (checked) {
                 setState(() {
                   final list = List<String>.from(currentSelections);
                   if (checked == true) {
                     list.add(opt);
                   } else {
                     list.remove(opt);
                   }
                   _selectedOptions[p.id] = list;
                 });
               },
             );
           } else {
             final selectedOpt = _selectedOptions[p.id] as String?;
             return RadioListTile<String>(
               title: Text(opt, style: const TextStyle(fontSize: 13)),
               value: opt,
               groupValue: selectedOpt,
               dense: true,
               contentPadding: EdgeInsets.zero,
               activeColor: AppColors.primary,
               onChanged: _submittingVote ? null : (val) {
                 setState(() => _selectedOptions[p.id] = val);
               },
             );
           }
         }),
         const SizedBox(height: 12),
         SizedBox(
           width: double.infinity,
           child: ElevatedButton(
             onPressed: _submittingVote ? null : () => _submitVote(p),
             style: ElevatedButton.styleFrom(
               backgroundColor: AppColors.primary,
               padding: const EdgeInsets.symmetric(vertical: 12),
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
             ), 
             child: _submittingVote 
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('CONFIRMAR VOTO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
           ),
         ),
      ],
    );
  }

  Future<void> _submitVote(PautaModel p) async {
     if (_myUnitId == null) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Sua unidade não pôde ser identificada para votar.'))
       );
       return;
     }

     final isMultipla = p.modoResposta == 'multipla';
     dynamic selected = _selectedOptions[p.id];

     if (selected == null || (isMultipla && (selected as List).isEmpty) || (!isMultipla && selected.toString().isEmpty)) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Selecione pelo menos uma opção antes de votar.'))
       );
       return;
     }

     setState(() => _submittingVote = true);
     try {
        final userId = _supabase.auth.currentUser!.id;
        final votoJsonStr = isMultipla ? '[${(selected as List).map((e) => '"$e"').join(",")}]' : selected.toString();

        await _supabase.from('assembleia_votos').insert({
           'assembleia_id': widget.assembleiaId,
           'pauta_id': p.id,
           'unit_id': _myUnitId,
           'voto': votoJsonStr,
           'votante_user_id': userId,
        });

        // re-load to reflect vote + results
        await _loadData();
     } catch (e) {
        if (mounted) {
           setState(() => _submittingVote = false);
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Erro ao registrar voto! Tente novamente.'))
           );
        }
     }
  }

  Widget _buildVoteResults(PautaModel p) {
    var votosList = _resultados[p.id] ?? {};
    if (votosList.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text('Nenhum voto computado.', style: TextStyle(color: Colors.grey, fontSize: 13)),
        ),
      );
    }

    int totalVotos = votosList.values.fold(0, (a, b) => a + b);
    final sorted = votosList.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Resultados Parciais/Finais:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textMain)),
        const SizedBox(height: 12),
        ...sorted.map((e) {
          final percentage = totalVotos > 0 ? e.value / totalVotos : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        e.key,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMain),
                        maxLines: 1, 
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${(percentage * 100).toStringAsFixed(1)}% (${e.value} votos)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: percentage,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
