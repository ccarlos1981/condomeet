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
    {'title': 'Iniciante', 'icon': Icons.spa, 'min': 0, 'color': 0xFF9E9E9E},
    {'title': 'Colaborador', 'icon': Icons.star, 'min': 50, 'color': 0xFF42A5F5},
    {'title': 'Fiscal de Preço', 'icon': Icons.search, 'min': 200, 'color': 0xFFFFA726},
    {'title': 'Caçador de Oferta', 'icon': Icons.gps_fixed, 'min': 500, 'color': 0xFFAB47BC},
    {'title': 'Mestre do Preço', 'icon': Icons.workspace_premium, 'min': 1000, 'color': 0xFFFFD700},
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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: IconThemeData(color: Colors.grey.shade800),
        title: Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber.shade700, size: 22),
            const SizedBox(width: 8),
            Text('Ranking', style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFF2E7D32),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Color(rank['color'] as int).withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // Rank badge
          Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: Color(rank['color'] as int).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(child: Icon(rank['icon'] as IconData, color: Color(rank['color'] as int), size: 30)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rankTitle, style: TextStyle(color: Color(rank['color'] as int), fontWeight: FontWeight.bold, fontSize: 18)),
                    Text('$points pontos totais', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Icon(Icons.trending_up, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text('$weeklyPts', style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  Text('esta semana', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
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
                Row(
                  children: [
                    Text('Próximo: ', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    Icon(next['icon'] as IconData, size: 14, color: Color(next['color'] as int)),
                    Text(' ${next['title']}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ],
                ),
                Text('$points / $nextMin pts',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(Color(next['color'] as int)),
                minHeight: 8,
              ),
            ),
          ] else
            Text('Rank máximo alcançado!', style: TextStyle(color: Colors.amber.shade700, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatBadge(Icons.edit_note, '$reports', 'Reportes'),
              _buildStatBadge(Icons.star, '$points', 'Pontos'),
              _buildStatBadge(Icons.trending_up, '$weeklyPts', 'Semana'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 22),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
      ],
    );
  }

  Widget _buildCommunityStats() {
    final totalPrices = _communityStats?['total_prices'] ?? 0;
    final totalContribs = _communityStats?['total_contributors'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildCommunityItem(Icons.store, '$totalPrices', 'Preços'),
          Container(width: 1, height: 30, color: Colors.grey.shade200),
          _buildCommunityItem(Icons.group, '$totalContribs', 'Colaboradores'),
          Container(width: 1, height: 30, color: Colors.grey.shade200),
          _buildCommunityItem(Icons.calendar_month, '${_weeklyBoard.length}', 'Ativos'),
        ],
      ),
    );
  }

  Widget _buildCommunityItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 20),
        Text(value, style: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
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
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF2E7D32),
            labelColor: const Color(0xFF2E7D32),
            unselectedLabelColor: Colors.grey.shade600,
            indicatorSize: TabBarIndicatorSize.tab,
            onTap: (_) => setState(() {}),
            tabs: const [
              Tab(text: 'Semanal'),
              Tab(text: 'Geral'),
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
          child: Center(
            child: Text('Nenhum participante ainda.\nSeja o primeiro!', textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
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

      IconData posIcon;
      Color posColor;
      if (position == 1) { posIcon = Icons.emoji_events; posColor = Colors.amber; }
      else if (position == 2) { posIcon = Icons.emoji_events; posColor = Colors.grey.shade400; }
      else if (position == 3) { posIcon = Icons.emoji_events; posColor = Colors.brown.shade300; }
      else { posIcon = Icons.tag; posColor = Colors.grey.shade400; }

      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF2E7D32).withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isMe ? const Color(0xFF2E7D32).withOpacity(0.3) : Colors.grey.shade200),
        ),
        child: Row(
          children: [
            // Position
            SizedBox(
              width: 36,
              child: position <= 3
                ? Icon(posIcon, color: posColor, size: 22)
                : Text('#$position', style: TextStyle(fontSize: 14, color: Colors.grey.shade500), textAlign: TextAlign.center),
            ),
            const SizedBox(width: 10),
            // Rank icon
            Icon(rank['icon'] as IconData, color: Color(rank['color'] as int), size: 20),
            const SizedBox(width: 10),
            // Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMe ? '$name (você)' : _anonymizeName(name),
                    style: TextStyle(color: isMe ? const Color(0xFF2E7D32) : Colors.grey.shade900, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Text(rankTitle, style: TextStyle(color: Color(rank['color'] as int).withOpacity(0.8), fontSize: 11)),
                ],
              ),
            ),
            // Points
            Text('$pts pts', style: TextStyle(
              color: isMe ? const Color(0xFF2E7D32) : Colors.grey.shade700,
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
