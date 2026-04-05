import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:intl/intl.dart';

class ChatMessage {
  final String id;
  final String userId;
  final String mensagem;
  final String tipo; // 'mensagem', 'sistema'
  final String createdAt;
  final String userName;
  final bool isAdmin;

  const ChatMessage({
    required this.id,
    required this.userId,
    required this.mensagem,
    required this.tipo,
    required this.createdAt,
    required this.userName,
    required this.isAdmin,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    final perfil = map['perfil'] as Map<String, dynamic>?;
    return ChatMessage(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      mensagem: map['mensagem'] ?? '',
      tipo: map['tipo'] ?? 'mensagem',
      createdAt: map['created_at'] ?? '',
      userName: perfil?['nome_completo'] ?? 'Usuário',
      isAdmin: ['Síndico', 'Síndico (a)', 'ADMIN', 'admin'].contains(perfil?['papel_sistema']),
    );
  }
}

class AssembleiaChatWidget extends StatefulWidget {
  final String assembleiaId;
  final String userId;
  final String userName;

  const AssembleiaChatWidget({
    super.key,
    required this.assembleiaId,
    required this.userId,
    required this.userName,
  });

  @override
  State<AssembleiaChatWidget> createState() => _AssembleiaChatWidgetState();
}

class _AssembleiaChatWidgetState extends State<AssembleiaChatWidget> {
  final _supabase = Supabase.instance.client;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _chatBlocked = false;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _setupRealtime();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    if (_channel != null) {
      _supabase.removeChannel(_channel!);
    }
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final data = await _supabase
          .from('assembleia_chat')
          .select('*, perfil:user_id(nome_completo, papel_sistema)')
          .eq('assembleia_id', widget.assembleiaId)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _messages = (data as List).map((e) => ChatMessage.fromMap(e)).toList();
          _loading = false;
          // Check if chat is blocked
          _chatBlocked = _messages.any((m) =>
              m.tipo == 'sistema' &&
              m.mensagem.contains('🔒') &&
              !_messages.any((m2) =>
                  m2.tipo == 'sistema' &&
                  m2.mensagem.contains('🔓') &&
                  m2.createdAt.compareTo(m.createdAt) > 0));
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setupRealtime() {
    _channel = _supabase
        .channel('chat_${widget.assembleiaId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'assembleia_chat',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'assembleia_id',
            value: widget.assembleiaId,
          ),
          callback: (payload) async {
            final newRow = payload.newRecord;
            // Fetch the full record with profile join
            final data = await _supabase
                .from('assembleia_chat')
                .select('*, perfil:user_id(nome_completo, papel_sistema)')
                .eq('id', newRow['id'])
                .maybeSingle();

            if (data != null && mounted) {
              final msg = ChatMessage.fromMap(data);
              setState(() {
                // Avoid duplicates
                if (!_messages.any((m) => m.id == msg.id)) {
                  _messages.add(msg);
                }
                // Check for chat block/unblock
                if (msg.tipo == 'sistema') {
                  if (msg.mensagem.contains('🔒')) _chatBlocked = true;
                  if (msg.mensagem.contains('🔓')) _chatBlocked = false;
                }
              });
              _scrollToBottom();
            }
          },
        )
        .subscribe();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _chatBlocked) return;

    _controller.clear();
    _focusNode.requestFocus();

    await _supabase.from('assembleia_chat').insert({
      'assembleia_id': widget.assembleiaId,
      'user_id': widget.userId,
      'mensagem': text,
      'tipo': 'mensagem',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Messages
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 8),
                          Text(
                            'Ainda sem mensagens',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Seja o primeiro a enviar!',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => _buildMessageBubble(_messages[i]),
                    ),
        ),

        // Chat blocked notice
        if (_chatBlocked)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: Colors.orange.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock, size: 16, color: Colors.orange.shade700),
                const SizedBox(width: 6),
                Text(
                  'Chat bloqueado pelo administrador',
                  style: TextStyle(fontSize: 13, color: Colors.orange.shade700, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

        // Input
        if (!_chatBlocked)
          Container(
            padding: EdgeInsets.fromLTRB(12, 8, 8, MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Enviar mensagem...',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppColors.primary),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isMe = msg.userId == widget.userId;
    final isSystem = msg.tipo == 'sistema';

    if (isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Text(
          msg.mensagem,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.amber.shade800, fontStyle: FontStyle.italic),
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.primary
              : msg.isAdmin
                  ? Colors.amber.shade100
                  : Colors.grey.shade100,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: isMe ? const Radius.circular(14) : const Radius.circular(4),
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(14),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    msg.userName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: msg.isAdmin ? Colors.amber.shade900 : AppColors.primary,
                    ),
                  ),
                  if (msg.isAdmin) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade600,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'ADM',
                        style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            if (!isMe) const SizedBox(height: 3),
            Text(
              msg.mensagem,
              style: TextStyle(
                fontSize: 14,
                color: isMe ? Colors.white : AppColors.textMain,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _formatTime(msg.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: isMe ? Colors.white60 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('HH:mm').format(dt);
    } catch (_) {
      return '';
    }
  }
}
