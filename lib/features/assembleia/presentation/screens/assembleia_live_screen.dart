import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/features/assembleia/domain/models/assembleia_model.dart';
import 'package:condomeet/features/assembleia/domain/models/pauta_model.dart';
import 'package:condomeet/features/assembleia/presentation/widgets/youtube_player_widget.dart';
import 'package:condomeet/features/assembleia/presentation/widgets/assembleia_chat_widget.dart';
import 'package:condomeet/features/assembleia/presentation/widgets/assembleia_voting_sheet.dart';
import 'package:intl/intl.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:condomeet/core/config/app_config.dart';

class AssembleiaLiveScreen extends StatefulWidget {
  final String assembleiaId;
  const AssembleiaLiveScreen({super.key, required this.assembleiaId});

  @override
  State<AssembleiaLiveScreen> createState() => _AssembleiaLiveScreenState();
}

class _AssembleiaLiveScreenState extends State<AssembleiaLiveScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  AssembleiaModel? _assembleia;
  List<PautaModel> _pautas = [];
  bool _loading = true;
  int _onlineCount = 0;
  Map<String, Map<String, int>> _voteStats = {};
  Map<String, String> _myVotes = {};
  late TabController _tabController;
  RealtimeChannel? _presenceChannel;
  RealtimeChannel? _votesChannel;
  RealtimeChannel? _pautasChannel;

  RtcEngine? _engine;
  bool _agoraInitialized = false;
  int? _remoteUid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    _initAgora();
    // Set landscape-capable for video
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (_presenceChannel != null) _supabase.removeChannel(_presenceChannel!);
    if (_votesChannel != null) _supabase.removeChannel(_votesChannel!);
    if (_pautasChannel != null) _supabase.removeChannel(_pautasChannel!);
    
    if (_engine != null) {
      _engine!.leaveChannel();
      _engine!.release();
    }

    // Lock back to portrait
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Future<void> _initAgora() async {
    await [Permission.microphone, Permission.camera].request();

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(
      const RtcEngineContext(
        appId: AppConfig.agoraAppId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint('Agora local user UID ${connection.localUid} joined');
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint('Agora remote user UID $remoteUid joined');
          if (mounted) {
            setState(() {
              _remoteUid = remoteUid;
            });
          }
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint('Agora remote user UID $remoteUid left channel');
          if (mounted && _remoteUid == remoteUid) {
            setState(() {
              _remoteUid = null;
            });
          }
        },
      ),
    );

    await _engine!.setClientRole(role: ClientRoleType.clientRoleAudience);
    await _engine!.enableVideo();
    await _engine!.joinChannel(
      token: '',
      channelId: widget.assembleiaId,
      uid: 0,
      options: const ChannelMediaOptions(
        autoSubscribeVideo: true,
        autoSubscribeAudio: true,
        clientRoleType: ClientRoleType.clientRoleAudience,
      ),
    );

    if (mounted) {
      setState(() => _agoraInitialized = true);
    }
  }

  Future<void> _loadData() async {
    final userId = context.read<AuthBloc>().state.userId;
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

      // Fetch votes
      final vData = await _supabase
          .from('assembleia_votos')
          .select('pauta_id, voto, votante_user_id')
          .eq('assembleia_id', widget.assembleiaId);

      final voteStats = <String, Map<String, int>>{};
      final myVotes = <String, String>{};
      for (final v in vData) {
        final pId = v['pauta_id'] as String;
        final voto = v['voto'] as String;
        voteStats.putIfAbsent(pId, () => {});
        voteStats[pId]![voto] = (voteStats[pId]![voto] ?? 0) + 1;
        if (v['votante_user_id'] == userId) {
          myVotes[pId] = voto;
        }
      }

      if (mounted) {
        setState(() {
          _assembleia = AssembleiaModel.fromMap(aData);
          _pautas = (pData as List).map((e) => PautaModel.fromMap(e)).toList();
          _voteStats = voteStats;
          _myVotes = myVotes;
          _loading = false;
        });
        _setupPresence();
        _setupVotesRealtime();
        _setupPautasRealtime();
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setupPresence() {
    final userId = context.read<AuthBloc>().state.userId ?? 'anon';
    final userName = context.read<AuthBloc>().state.userName ?? 'Morador';

    _presenceChannel = _supabase
        .channel('presence_${widget.assembleiaId}',
            opts: const RealtimeChannelConfig(self: true))
        .onPresenceSync((payload) {
      if (mounted) {
        final presences = _presenceChannel!.presenceState();
        setState(() => _onlineCount = presences.length);
      }
    }).subscribe((status, [error]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await _presenceChannel!.track({
          'user_id': userId,
          'user_name': userName,
          'online_at': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  void _setupVotesRealtime() {
    final userId = context.read<AuthBloc>().state.userId;
    _votesChannel = _supabase
        .channel('votes_${widget.assembleiaId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'assembleia_votos',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'assembleia_id',
            value: widget.assembleiaId,
          ),
          callback: (payload) {
            final v = payload.newRecord;
            final pId = v['pauta_id'] as String? ?? '';
            final voto = v['voto'] as String? ?? '';
            if (pId.isEmpty || voto.isEmpty) return;

            if (mounted) {
              setState(() {
                _voteStats.putIfAbsent(pId, () => {});
                _voteStats[pId]![voto] = (_voteStats[pId]![voto] ?? 0) + 1;
                if (v['votante_user_id'] == userId) {
                  _myVotes[pId] = voto;
                }
              });
            }
          },
        )
        .subscribe();
  }

  void _setupPautasRealtime() {
    _pautasChannel = _supabase
        .channel('pautas_${widget.assembleiaId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'assembleia_pautas',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'assembleia_id',
            value: widget.assembleiaId,
          ),
          callback: (payload) {
            final updated = payload.newRecord;
            final pautaId = updated['id'] as String? ?? '';
            if (pautaId.isEmpty) return;

            if (mounted) {
              setState(() {
                final idx = _pautas.indexWhere((p) => p.id == pautaId);
                if (idx != -1) {
                  _pautas[idx] = PautaModel.fromMap(updated);
                }
              });
            }
          },
        )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(child: CircularProgressIndicator(color: Colors.red)),
      );
    }

    if (_assembleia == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sessão ao Vivo')),
        body: const Center(child: Text('Assembleia não encontrada')),
      );
    }

    final a = _assembleia!;
    final userId = context.read<AuthBloc>().state.userId ?? '';
    final userName = context.read<AuthBloc>().state.userName ?? 'Morador';
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

    // Landscape → full video
    if (!isPortrait) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            _buildVideoArea(a),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              child: IconButton(
                onPressed: () => SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
                icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            _buildTopBar(a),

            // Video (40% height in portrait)
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.28,
              child: _buildVideoArea(a),
            ),

            // Tabs
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: [
                  const Tab(icon: Icon(Icons.chat, size: 18), text: 'Chat'),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.how_to_vote, size: 18),
                        const SizedBox(width: 4),
                        const Text('Votação'),
                        if (_pautas.any((p) => p.isAberta)) ...[
                          const SizedBox(width: 4),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.info_outline, size: 18),
                        const SizedBox(width: 4),
                        const Text('Info'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Chat
                  AssembleiaChatWidget(
                    assembleiaId: widget.assembleiaId,
                    userId: userId,
                    userName: userName,
                  ),

                  // Votação
                  _buildVotacaoTab(userId),

                  // Info
                  _buildInfoTab(a),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(AssembleiaModel a) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Colors.black87,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.nome,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  a.tipo,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                ),
              ],
            ),
          ),
          // Live badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                const Text('AO VIVO', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Online count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text(
                  '$_onlineCount',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoArea(AssembleiaModel a) {
    if (a.isYoutube && a.youtubeUrl != null && a.youtubeUrl!.isNotEmpty) {
      return YoutubePlayerWidget(youtubeUrl: a.youtubeUrl!);
    }

    if (!_agoraInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.red),
        ),
      );
    }

    if (_remoteUid == null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.videocam_off, size: 48, color: Colors.white24),
              SizedBox(height: 8),
              Text(
                'Aguardando o síndico\niniciar a transmissão...',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine!,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: widget.assembleiaId),
        ),
      ),
    );
  }

  Widget _buildVotacaoTab(String userId) {
    if (_pautas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.how_to_vote_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text(
              'Nenhuma pauta de votação',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pautas.length,
      itemBuilder: (_, i) {
        final p = _pautas[i];
        final myVote = _myVotes[p.id];
        final hasVoted = myVote != null;
        final results = _voteStats[p.id];

        return GestureDetector(
          onTap: p.isVotacao
              ? () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => DraggableScrollableSheet(
                      initialChildSize: 0.65,
                      maxChildSize: 0.9,
                      minChildSize: 0.4,
                      builder: (_, scrollController) => SingleChildScrollView(
                        controller: scrollController,
                        child: AssembleiaVotingSheet(
                          pauta: p,
                          assembleiaId: widget.assembleiaId,
                          userId: userId,
                          resultados: results,
                          myVote: myVote,
                        ),
                      ),
                    ),
                  )
              : null,
          child: Container(
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
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: p.isVotacao
                      ? (p.isAberta ? Colors.green : Colors.grey.shade300)
                      : Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: p.isVotacao
                      ? Icon(
                          hasVoted ? Icons.check : Icons.how_to_vote,
                          color: Colors.white,
                          size: 18,
                        )
                      : Icon(Icons.info_outline, color: Colors.blue.shade600, size: 18),
                ),
              ),
              title: Text(
                p.titulo,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: Row(
                children: [
                  if (p.isVotacao) ...[
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: p.isAberta
                            ? Colors.green.shade50
                            : hasVoted
                                ? Colors.blue.shade50
                                : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        p.isAberta
                            ? (hasVoted ? '✅ Votado' : 'Aberta')
                            : (hasVoted ? '✅ Votado' : 'Fechada'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: p.isAberta ? Colors.green.shade700 : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              trailing: p.isVotacao
                  ? Icon(Icons.chevron_right, color: Colors.grey.shade400)
                  : null,
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoTab(AssembleiaModel a) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Online presence
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                Text(
                  '$_onlineCount participantes online',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Assembly info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Informações', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                _infoRow(Icons.category, 'Tipo', a.tipoLabel),
                _infoRow(Icons.public, 'Modalidade', a.modalidade),
                _infoRow(
                  a.isYoutube ? Icons.play_circle : Icons.sensors,
                  'Transmissão',
                  a.isYoutube ? 'YouTube Live' : 'Agora.io',
                ),
                if (a.dt1aConvocacao != null)
                  _infoRow(Icons.calendar_today, '1ª Convocação', _formatDate(a.dt1aConvocacao!)),
                if (a.localPresencial != null && a.localPresencial!.isNotEmpty)
                  _infoRow(Icons.location_on, 'Local', a.localPresencial!),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Voting summary
          if (_pautas.where((p) => p.isVotacao).isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Resumo Votação', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Text(
                    '${_pautas.where((p) => p.isVotacao).length} pautas no total',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  Text(
                    '${_pautas.where((p) => p.isAberta).length} abertas para votação',
                    style: TextStyle(fontSize: 13, color: Colors.green.shade600),
                  ),
                  Text(
                    '${_myVotes.length} votos registrados por você',
                    style: TextStyle(fontSize: 13, color: AppColors.primary),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }
}
