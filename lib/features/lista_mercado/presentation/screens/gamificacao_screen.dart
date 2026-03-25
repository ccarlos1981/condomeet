import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:condomeet/features/lista_mercado/lista_mercado_service.dart';

class GamificacaoScreen extends StatefulWidget {
  const GamificacaoScreen({super.key});

  @override
  State<GamificacaoScreen> createState() => _GamificacaoScreenState();
}

class _GamificacaoScreenState extends State<GamificacaoScreen> with SingleTickerProviderStateMixin {
  final _service = ListaMercadoService();
  late TabController _tabController;

  Map<String, dynamic>? _myPoints;
  Map<String, dynamic>? _communityStats;
  List<Map<String, dynamic>> _weeklyBoard = [];
  List<Map<String, dynamic>> _allTimeBoard = [];
  Map<String, String> _userNames = {};
  bool _loading = true;

  String get _myUserId => Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final pts = await _service.getMyPoints();
      final weekly = await _service.getWeeklyLeaderboard();
      final allTime = await _service.getAllTimeLeaderboard();
      final stats = await _service.getCommunityStats();

      // Gather all user IDs for name lookup
      final allIds = <String>{};
      for (final e in weekly) allIds.add(e['user_id'] ?? '');
      for (final e in allTime) allIds.add(e['user_id'] ?? '');
      allIds.remove('');
      final names = await _service.getUserNames(allIds.toList());

      if (mounted) {
        setState(() {
          _myPoints = pts;
          _weeklyBoard = weekly;
          _allTimeBoard = allTime;
          _communityStats = stats;
          _userNames = names;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Rank config
  static const _ranks = [
    {'title': 'Iniciante', 'emoji': '🌱', 'min': 0, 'color': 0xFF9E9E9E},
    {'title': 'Colaborador', 'emoji': '⭐', 'min': 50, 'color': 0xFF42A5F5},
    {'title': 'Fiscal de Preço', 'emoji': '🔍', 'min': 200, 'color': 0xFFFFA726},
    {'title': 'Caçador de Oferta', 'emoji': '🎯', 'min': 500, 'color': 0xFFAB47BC},
    {'title': 'Mestre do Preço', 'emoji': '👑', 'min': 1000, 'color': 0xFFFFD700},
  ];

  Map<String, dynamic> _getRankInfo(String? title) {
    return _ranks.firstWhere((r) => r['title'] == title, orElse: () => _ranks.first);
  }

  Map<String, dynamic> _getNextRank(int points) {
    for (final r in _ranks) {
      if ((r['min'] as int) > points) return r;
    }
    return _ranks.last;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Row(
          children: [
            Text('🏆', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text('Ranking', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C853)))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFF00C853),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildMyProfile(),
                  const SizedBox(height: 16),
                  _buildCommunityStats(),
                  const SizedBox(height: 20),
                  _buildLeaderboard(),
                ],
              ),
            ),
    );
  }

  Widget _buildMyProfile() {
    final points = _myPoints?['total_points'] as int? ?? 0;
    final weeklyPts = _myPoints?['weekly_points'] as int? ?? 0;
    final reports = _myPoints?['reports_count'] as int? ?? 0;
    final rankTitle = _myPoints?['rank_title'] as String? ?? 'Iniciante';
    final rank = _getRankInfo(rankTitle);
    final next = _getNextRank(points);
    final nextMin = next['min'] as int;
    final currentMin = rank['min'] as int;
    final progress = nextMin > currentMin ? (points - currentMin) / (nextMin - currentMin) : 1.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(rank['color'] as int).withOpacity(0.15), const Color(0xFF1E1E2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Color(rank['color'] as int).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Rank badge
          Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: Color(rank['color'] as int).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(child: Text(rank['emoji'] as String, style: const TextStyle(fontSize: 32))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rankTitle, style: TextStyle(color: Color(rank['color'] as int), fontWeight: FontWeight.bold, fontSize: 18)),
                    Text('$points pontos totais', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('📊 $weeklyPts', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const Text('esta semana', style: TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress to next rank
          if (rankTitle != 'Mestre do Preço') ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Próximo: ${next['emoji']} ${next['title']}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
                Text('$points / $nextMin pts',
                    style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation(Color(next['color'] as int)),
                minHeight: 8,
              ),
            ),
          ] else
            const Text('🎉 Rank máximo alcançado!', style: TextStyle(color: Color(0xFFFFD700), fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatBadge('📝', '$reports', 'Reportes'),
              _buildStatBadge('⭐', '$points', 'Pontos'),
              _buildStatBadge('📊', '$weeklyPts', 'Semana'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }

  Widget _buildCommunityStats() {
    final totalPrices = _communityStats?['total_prices'] ?? 0;
    final totalContribs = _communityStats?['total_contributors'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildCommunityItem('🏪', '$totalPrices', 'Preços'),
          Container(width: 1, height: 30, color: Colors.white10),
          _buildCommunityItem('👥', '$totalContribs', 'Colaboradores'),
          Container(width: 1, height: 30, color: Colors.white10),
          _buildCommunityItem('📅', '${_weeklyBoard.length}', 'Ativos'),
        ],
      ),
    );
  }

  Widget _buildCommunityItem(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }

  Widget _buildLeaderboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab bar
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF00C853),
            labelColor: const Color(0xFF00C853),
            unselectedLabelColor: Colors.white54,
            indicatorSize: TabBarIndicatorSize.tab,
            onTap: (_) => setState(() {}),
            tabs: const [
              Tab(text: '📅 Semanal'),
              Tab(text: '🏆 Geral'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Board
        ..._buildBoardList(_tabController.index == 0 ? _weeklyBoard : _allTimeBoard, _tabController.index == 0),
      ],
    );
  }

  List<Widget> _buildBoardList(List<Map<String, dynamic>> board, bool isWeekly) {
    if (board.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(30),
          child: const Center(
            child: Text('Nenhum participante ainda.\nSeja o primeiro! 🚀', textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 14)),
          ),
        ),
      ];
    }

    return board.asMap().entries.map((entry) {
      final i = entry.key;
      final user = entry.value;
      final userId = user['user_id'] as String? ?? '';
      final name = _userNames[userId] ?? 'Colaborador';
      final pts = isWeekly ? (user['weekly_points'] as int? ?? 0) : (user['total_points'] as int? ?? 0);
      final rankTitle = user['rank_title'] as String? ?? 'Iniciante';
      final rank = _getRankInfo(rankTitle);
      final isMe = userId == _myUserId;
      final position = i + 1;

      String posEmoji;
      if (position == 1) posEmoji = '🥇';
      else if (position == 2) posEmoji = '🥈';
      else if (position == 3) posEmoji = '🥉';
      else posEmoji = '#$position';

      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF00C853).withOpacity(0.08) : const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isMe ? const Color(0xFF00C853).withOpacity(0.3) : Colors.white10),
        ),
        child: Row(
          children: [
            // Position
            SizedBox(
              width: 36,
              child: Text(posEmoji, style: TextStyle(fontSize: position <= 3 ? 22 : 14, color: Colors.white54), textAlign: TextAlign.center),
            ),
            const SizedBox(width: 10),
            // Rank emoji
            Text(rank['emoji'] as String, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            // Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMe ? '$name (você)' : _anonymizeName(name),
                    style: TextStyle(color: isMe ? const Color(0xFF00C853) : Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Text(rankTitle, style: TextStyle(color: Color(rank['color'] as int).withOpacity(0.7), fontSize: 11)),
                ],
              ),
            ),
            // Points
            Text('$pts pts', style: TextStyle(
              color: isMe ? const Color(0xFF00C853) : Colors.white70,
              fontWeight: FontWeight.bold, fontSize: 15,
            )),
          ],
        ),
      );
    }).toList();
  }

  /// Anonymize name for privacy: "João Silva" → "João S."
  String _anonymizeName(String name) {
    final parts = name.trim().split(' ');
    if (parts.length <= 1) return name;
    return '${parts.first} ${parts.last[0]}.';
  }
}
