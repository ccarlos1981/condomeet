import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/core/di/injection_container.dart';

class AvisosScreen extends StatefulWidget {
  const AvisosScreen({super.key});

  @override
  State<AvisosScreen> createState() => _AvisosScreenState();
}

class _AvisosScreenState extends State<AvisosScreen> {
  final _supabase = sl<SupabaseClient>();

  List<_Aviso> _naoLidos = [];
  List<_Aviso> _lidos = [];
  bool _loading = true;
  String? _expandedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // Get user's condo
    final profile = await _supabase
        .from('perfil')
        .select('condominio_id')
        .eq('id', user.id)
        .maybeSingle();

    final condoId = profile?['condominio_id'] as String?;
    if (condoId == null) { setState(() => _loading = false); return; }

    // All avisos for this condo
    final todosRaw = await _supabase
        .from('avisos')
        .select('id, titulo, corpo, created_at')
        .eq('condominio_id', condoId)
        .order('created_at', ascending: false);

    // Which avisos this user has already read
    final lidosRaw = await _supabase
        .from('avisos_lidos')
        .select('aviso_id')
        .eq('user_id', user.id);

    final lidosSet = {for (final r in lidosRaw) r['aviso_id'] as String};

    final todos = (todosRaw as List).map((r) => _Aviso.fromMap(r as Map<String, dynamic>)).toList();

    setState(() {
      _naoLidos = todos.where((a) => !lidosSet.contains(a.id)).toList();
      _lidos = todos.where((a) => lidosSet.contains(a.id)).toList();
      _loading = false;
    });
  }

  Future<void> _markAsRead(_Aviso aviso) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    HapticFeedback.selectionClick();

    try {
      await _supabase.from('avisos_lidos').upsert({
        'aviso_id': aviso.id,
        'user_id': user.id,
      });
    } catch (_) {}

    setState(() {
      _naoLidos.removeWhere((a) => a.id == aviso.id);
      if (!_lidos.any((a) => a.id == aviso.id)) {
        _lidos.insert(0, aviso);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Avisos do Condomínio',
          style: TextStyle(
            color: AppColors.textMain,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 20),
            onPressed: () { setState(() => _loading = true); _load(); },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: (_naoLidos.isEmpty && _lidos.isEmpty)
                  ? _buildEmpty()
                  : _buildList(),
            ),
    );
  }

  Widget _buildEmpty() {
    return ListView(children: [
      const SizedBox(height: 80),
      const Icon(Icons.notifications_none_rounded, size: 56, color: AppColors.disabledIcon),
      const SizedBox(height: 16),
      const Text('Nenhum aviso do condomínio ainda',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textHint, fontSize: 14)),
    ]);
  }

  Widget _buildList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Não lidos ──
        if (_naoLidos.isNotEmpty) ...[
          _buildSectionHeader('Não lidos', _naoLidos.length, isUnread: true),
          const SizedBox(height: 8),
          ..._naoLidos.map((a) => _buildCard(a, unread: true)),
          const SizedBox(height: 20),
        ],
        // ── Lidos ──
        if (_lidos.isNotEmpty) ...[
          _buildSectionHeader('Lidos', null, isUnread: false),
          const SizedBox(height: 8),
          ..._lidos.map((a) => _buildCard(a, unread: false)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String label, int? count, {required bool isUnread}) {
    return Row(
      children: [
        Icon(
          isUnread ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
          size: 16,
          color: isUnread ? AppColors.primary : Colors.grey.shade400,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isUnread ? AppColors.textMain : AppColors.textSecondary,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ],
    );
  }

  Widget _buildCard(_Aviso aviso, {required bool unread}) {
    final isExpanded = _expandedId == aviso.id;
    return GestureDetector(
      onTap: () {
        setState(() => _expandedId = isExpanded ? null : aviso.id);
        if (unread) _markAsRead(aviso);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: unread ? Colors.white : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: unread ? AppColors.border : AppColors.surfaceAlt,
          ),
          boxShadow: unread
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left colour indicator — grows with the content naturally
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
              child: Container(
                width: 4,
                height: isExpanded ? null : 36,
                constraints: const BoxConstraints(minHeight: 36),
                decoration: BoxDecoration(
                  color: unread ? AppColors.primary : Colors.grey.shade300,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(4),
                    bottomRight: Radius.circular(4),
                  ),
                ),
              ),
            ),
            // Card content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            aviso.titulo,
                            style: TextStyle(
                              fontWeight: unread ? FontWeight.bold : FontWeight.w500,
                              fontSize: 14,
                              color: unread ? AppColors.textMain : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Icon(
                          isExpanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 18,
                          color: Colors.grey.shade400,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatDate(aviso.createdAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                    if (isExpanded && aviso.corpo.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      Text(
                        _stripHtml(aviso.corpo),
                        style: TextStyle(
                          fontSize: 13,
                          color: unread ? AppColors.textMain : AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year} – '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  String _stripHtml(String html) {
    final exp = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true);
    return html.replaceAll(exp, '').replaceAll('&nbsp;', ' ').trim();
  }
}

class _Aviso {
  final String id;
  final String titulo;
  final String corpo;
  final DateTime createdAt;

  _Aviso({required this.id, required this.titulo, required this.corpo, required this.createdAt});

  factory _Aviso.fromMap(Map<String, dynamic> m) => _Aviso(
        id: m['id'],
        titulo: m['titulo'] ?? '',
        corpo: m['corpo'] ?? '',
        createdAt: DateTime.parse(m['created_at']),
      );
}
