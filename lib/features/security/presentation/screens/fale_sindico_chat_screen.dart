import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'fale_sindico_screen.dart';

class FaleSindicoMensagem {
  final String id;
  final String texto;
  final bool isAdmin;
  final DateTime createdAt;
  final String? senderNome;

  FaleSindicoMensagem({
    required this.id,
    required this.texto,
    required this.isAdmin,
    required this.createdAt,
    this.senderNome,
  });

  factory FaleSindicoMensagem.fromMap(Map<String, dynamic> m) {
    return FaleSindicoMensagem(
      id: m['id'] as String,
      texto: m['texto'] as String? ?? '',
      isAdmin: m['is_admin'] as bool? ?? false,
      createdAt: DateTime.parse(m['created_at'] as String),
      senderNome: m['perfil'] != null ? (m['perfil'] as Map)['nome_completo'] as String? : null,
    );
  }
}

class FaleSindicoChatScreen extends StatefulWidget {
  final FaleSindicoThread thread;

  const FaleSindicoChatScreen({super.key, required this.thread});

  @override
  State<FaleSindicoChatScreen> createState() => _FaleSindicoChatScreenState();
}

class _FaleSindicoChatScreenState extends State<FaleSindicoChatScreen> {
  List<FaleSindicoMensagem> _mensagens = [];
  bool _loading = true;
  bool _sending = false;
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client
          .from('fale_sindico_mensagens')
          .select('*, perfil:sender_id(nome_completo)')
          .eq('thread_id', widget.thread.id)
          .order('created_at', ascending: true);

      setState(() {
        _mensagens = (res as List)
            .map((m) => FaleSindicoMensagem.fromMap(m as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _loading = false);
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

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    final authState = context.read<AuthBloc>().state;
    final userId = authState.userId;
    if (userId == null) return;

    setState(() => _sending = true);
    _ctrl.clear();
    try {
      await Supabase.instance.client.from('fale_sindico_mensagens').insert({
        'thread_id': widget.thread.id,
        'sender_id': userId,
        'is_admin': false,
        'texto': text,
      });
      await Supabase.instance.client.from('fale_sindico_threads').update({
        'ultima_mensagem_em': DateTime.now().toIso8601String(),
        'status': 'aberto',
      }).eq('id', widget.thread.id);
      await _load();
    } catch (_) {}
    if (mounted) setState(() => _sending = false);
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    final d = '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
    return '$d, $h:$m ${local.hour < 12 ? 'am' : 'pm'}';
  }

  @override
  Widget build(BuildContext context) {
    final emoji = _tipoEmoji[widget.thread.tipo] ?? '📋';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$emoji ${widget.thread.assunto}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              _tipoLabel[widget.thread.tipo] ?? '',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _mensagens.isEmpty
                    ? const Center(child: Text('Nenhuma mensagem ainda.'))
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        itemCount: _mensagens.length,
                        itemBuilder: (_, i) => _Bubble(
                          msg: _mensagens[i],
                          timeStr: _formatTime(_mensagens[i].createdAt),
                        ),
                      ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildInput() {
    final isClosed = widget.thread.status == 'fechado';
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        left: 12, right: 8, top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              enabled: !isClosed,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: isClosed ? 'Conversa encerrada' : 'Digite sua mensagem aqui...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
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
            onTap: _send,
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: isClosed ? Colors.grey.shade300 : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: isClosed ? Colors.grey : Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final FaleSindicoMensagem msg;
  final String timeStr;

  const _Bubble({required this.msg, required this.timeStr});

  @override
  Widget build(BuildContext context) {
    final isMe = !msg.isAdmin;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: isMe ? Colors.green.shade300 : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: isMe ? null : Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.isAdmin && msg.senderNome != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  msg.senderNome!,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
            Text(msg.texto, style: const TextStyle(fontSize: 13, color: Colors.black87)),
            const SizedBox(height: 4),
            Text(timeStr, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}
