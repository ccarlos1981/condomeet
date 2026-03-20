import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/shared/utils/structure_labels.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'fale_sindico_screen.dart';

class _AdminThread {
  final String id;
  final String tipo;
  final String assunto;
  final String status;
  final DateTime createdAt;
  final DateTime? ultimaMensagemEm;
  final String residentId;
  final String? residentNome;
  final String? residentBloco;
  final String? residentApto;

  _AdminThread({
    required this.id,
    required this.tipo,
    required this.assunto,
    required this.status,
    required this.createdAt,
    this.ultimaMensagemEm,
    required this.residentId,
    this.residentNome,
    this.residentBloco,
    this.residentApto,
  });

  factory _AdminThread.fromMap(Map<String, dynamic> m) {
    final perfil = m['perfil'] as Map<String, dynamic>?;
    return _AdminThread(
      id: m['id'] as String,
      tipo: m['tipo'] as String? ?? 'duvida',
      assunto: m['assunto'] as String? ?? '',
      status: m['status'] as String? ?? 'aberto',
      createdAt: DateTime.parse(m['created_at'] as String),
      ultimaMensagemEm: m['ultima_mensagem_em'] != null
          ? DateTime.parse(m['ultima_mensagem_em'] as String)
          : null,
      residentId: m['resident_id'] as String,
      residentNome: perfil?['nome_completo'] as String?,
      residentBloco: perfil?['bloco_txt'] as String?,
      residentApto: perfil?['apto_txt'] as String?,
    );
  }
}

class _AdminMensagem {
  final String id;
  final String texto;
  final bool isAdmin;
  final DateTime createdAt;

  _AdminMensagem({required this.id, required this.texto, required this.isAdmin, required this.createdAt});

  factory _AdminMensagem.fromMap(Map<String, dynamic> m) => _AdminMensagem(
    id: m['id'] as String,
    texto: m['texto'] as String? ?? '',
    isAdmin: m['is_admin'] as bool? ?? false,
    createdAt: DateTime.parse(m['created_at'] as String),
  );
}

class FaleConoscoAdminScreen extends StatefulWidget {
  const FaleConoscoAdminScreen({super.key});

  @override
  State<FaleConoscoAdminScreen> createState() => _FaleConoscoAdminScreenState();
}

class _FaleConoscoAdminScreenState extends State<FaleConoscoAdminScreen> {
  List<_AdminThread> _threads = [];
  bool _loading = true;
  _AdminThread? _selected;
  List<_AdminMensagem> _mensagens = [];
  bool _loadingChat = false;
  bool _sending = false;
  final _replyCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  // Pagination
  int _page = 1;
  final int _perPage = 10;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final authState = context.read<AuthBloc>().state;
    final condoId = authState.condominiumId;
    if (condoId == null) return;
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client
          .from('fale_sindico_threads')
          .select('*, perfil:resident_id(nome_completo, bloco_txt, apto_txt)')
          .eq('condominio_id', condoId)
          .order('ultima_mensagem_em', ascending: false, nullsFirst: false);
      final list = (res as List).map((m) => _AdminThread.fromMap(m as Map<String, dynamic>)).toList();
      setState(() {
        _threads = list;
        _totalPages = (list.length / _perPage).ceil().clamp(1, 9999);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadChat(_AdminThread thread) async {
    setState(() { _selected = thread; _loadingChat = true; });
    try {
      final res = await Supabase.instance.client
          .from('fale_sindico_mensagens')
          .select()
          .eq('thread_id', thread.id)
          .order('created_at', ascending: true);
      if (mounted) {
        setState(() {
          _mensagens = (res as List).map((m) => _AdminMensagem.fromMap(m as Map<String, dynamic>)).toList();
          _loadingChat = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _loadingChat = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _reply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty || _sending || _selected == null) return;
    final authState = context.read<AuthBloc>().state;
    final userId = authState.userId;
    if (userId == null) return;

    setState(() => _sending = true);
    _replyCtrl.clear();
    try {
      await Supabase.instance.client.from('fale_sindico_mensagens').insert({
        'thread_id': _selected!.id,
        'sender_id': userId,
        'is_admin': true,
        'texto': text,
      });
      await Supabase.instance.client.from('fale_sindico_threads').update({
        'ultima_mensagem_em': DateTime.now().toIso8601String(),
        'status': 'respondido',
      }).eq('id', _selected!.id);
      await _loadChat(_selected!);
    } catch (_) {}
    if (mounted) setState(() => _sending = false);
  }

  String _fmtDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}, ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')} ${local.hour < 12 ? 'am' : 'pm'}';
  }

  List<_AdminThread> get _paginated {
    final start = (_page - 1) * _perPage;
    final end = (start + _perPage).clamp(0, _threads.length);
    return _threads.sublist(start, end);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Fale conosco',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _selected == null
              ? _buildList()
              : _buildChat(),
    );
  }

  Widget _buildList() {
    if (_threads.isEmpty) {
      return const Center(child: Text('Nenhuma mensagem dos moradores.'));
    }
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _loadAll,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _paginated.length,
              itemBuilder: (_, i) {
                final t = _paginated[i];
                return _AdminThreadCard(
                  thread: t,
                  onTap: () => _loadChat(t),
                );
              },
            ),
          ),
        ),
        // Paginação
        if (_totalPages > 1)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _page > 1 ? () => setState(() => _page--) : null,
                  color: AppColors.primary,
                ),
                Text('$_page de $_totalPages',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _page < _totalPages ? () => setState(() => _page++) : null,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildChat() {
    final t = _selected!;
    final isClosed = t.status == 'fechado';
    final emoji = tipoEmoji[t.tipo] ?? '📋';

    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          color: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _selected = null),
                child: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Conversando com ${t.residentNome ?? 'Morador'} / ${getBlocoLabel(context.read<AuthBloc>().state.tipoEstrutura)}: ${t.residentBloco ?? '-'} / ${getAptoLabel(context.read<AuthBloc>().state.tipoEstrutura)}: ${t.residentApto ?? '-'}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        // Assunto info
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Text('$emoji ', style: const TextStyle(fontSize: 16)),
              Expanded(
                child: Text(
                  t.assunto,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              _StatusBadge(status: t.status),
            ],
          ),
        ),

        // Mensagens
        Expanded(
          child: _loadingChat
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  itemCount: _mensagens.length,
                  itemBuilder: (_, i) => _AdminBubble(
                    msg: _mensagens[i],
                    timeStr: _fmtDate(_mensagens[i].createdAt),
                  ),
                ),
        ),

        // Input admin
        Container(
          color: Colors.white,
          padding: EdgeInsets.only(
            left: 12, right: 8, top: 8,
            bottom: MediaQuery.of(context).padding.bottom + 8,
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _selected = null),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_rounded, size: 18, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _replyCtrl,
                  enabled: !isClosed,
                  onSubmitted: (_) => _reply(),
                  decoration: InputDecoration(
                    hintText: isClosed ? 'Conversa encerrada' : 'Digite aqui sua pergunta ou resposta',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _reply,
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: isClosed ? Colors.grey.shade300 : AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminThreadCard extends StatelessWidget {
  final _AdminThread thread;
  final VoidCallback onTap;

  const _AdminThreadCard({required this.thread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final date = thread.ultimaMensagemEm ?? thread.createdAt;
    final dateStr = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} ${date.hour < 12 ? 'am' : 'pm'}';
    final tipoLabelText = tipoLabel[thread.tipo] ?? 'Assunto';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        leading: const CircleAvatar(
          backgroundColor: Colors.white,
          child: Icon(Icons.person, color: Colors.grey),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (thread.residentNome != null)
              Text('Nome: ${thread.residentNome}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            Text('${getBlocoLabel(context.read<AuthBloc>().state.tipoEstrutura)}: ${thread.residentBloco ?? '-'} ${getAptoLabel(context.read<AuthBloc>().state.tipoEstrutura)}: ${thread.residentApto ?? '-'}',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(tipoLabelText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ],
        ),
        trailing: Container(
          width: 36, height: 36,
          decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
          child: const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _AdminBubble extends StatelessWidget {
  final _AdminMensagem msg;
  final String timeStr;

  const _AdminBubble({required this.msg, required this.timeStr});

  @override
  Widget build(BuildContext context) {
    final isAdmin = msg.isAdmin;

    return Align(
      alignment: isAdmin ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: isAdmin ? Colors.white : Colors.green.shade200,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isAdmin ? 4 : 16),
            bottomRight: Radius.circular(isAdmin ? 16 : 4),
          ),
          border: isAdmin ? Border.all(color: Colors.grey.shade200) : null,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msg.texto, style: const TextStyle(fontSize: 13, color: Colors.black87)),
            const SizedBox(height: 4),
            Text(timeStr, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'respondido':
        color = Colors.green;
        label = 'Respondido';
        break;
      case 'fechado':
        color = Colors.grey;
        label = 'Fechado';
        break;
      default:
        color = AppColors.primary;
        label = 'Aberto';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
