import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class SuporteSistemaScreen extends StatefulWidget {
  const SuporteSistemaScreen({super.key});

  @override
  State<SuporteSistemaScreen> createState() => _SuporteSistemaScreenState();
}

class _SuporteSistemaScreenState extends State<SuporteSistemaScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  
  String? _chatId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    final userId = context.read<AuthBloc>().state.userId;
    final condominioId = context.read<AuthBloc>().state.condominiumId;
    if (userId == null) return;

    try {
      // Verifica se já existe um chat para este usuário
      final response = await Supabase.instance.client
          .from('suporte_sistema_chats')
          .select('id')
          .eq('resident_id', userId)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _chatId = response['id'];
          _isLoading = false;
        });
        
        // Zera contagem de nao lidas do usuario
        await Supabase.instance.client
          .from('suporte_sistema_chats')
          .update({'unread_user': 0})
          .eq('id', _chatId!);
          
      } else {
        // Se nao tem, quando enviar a 1a msg a gente interage, 
        // ou cria logo para ficar mais facil
        final newChat = await Supabase.instance.client
            .from('suporte_sistema_chats')
            .insert({
              'resident_id': userId,
              'condominio_id': condominioId,
            })
            .select('id')
            .single();

        setState(() {
          _chatId = newChat['id'];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao inicializar chat: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _chatId == null) return;
    
    final userId = context.read<AuthBloc>().state.userId;
    if (userId == null) return;

    _messageController.clear();

    try {
      await Supabase.instance.client
          .from('suporte_sistema_mensagens')
          .insert({
            'chat_id': _chatId,
            'sender_id': userId,
            'texto': text,
            'is_admin': false,
          });

      // Scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      debugPrint('Erro ao enviar mesagem: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Falha ao enviar mensagem', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Suporte do Sistema'),
            Text('Atendimento Especializado', style: AppTypography.label.copyWith(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textMain),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _chatId == null 
                  ? const Center(child: Text('Não foi possível iniciar o chat.'))
                  : StreamBuilder<List<Map<String, dynamic>>>(
                      stream: Supabase.instance.client
                          .from('suporte_sistema_mensagens')
                          .stream(primaryKey: ['id'])
                          .eq('chat_id', _chatId!)
                          .order('created_at', ascending: true),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        if (snapshot.hasError) {
                          return Center(child: Text('Erro: ${snapshot.error}'));
                        }

                        final messages = snapshot.data ?? [];
                        
                        if (messages.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Text(
                                'Bem-vindo ao Suporte!\n\nEnvie sua dúvida que o time Condomeet irá te responder o mais breve possível.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          );
                        }

                        // Delay to scroll down automatically when messages load
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_scrollController.hasClients) {
                             _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                          }
                        });

                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final msg = messages[index];
                            final isMe = msg['is_admin'] == false;
                            
                            return _buildMessageBubble(
                              text: msg['texto'], 
                              isMe: isMe,
                              createdAt: DateTime.parse(msg['created_at']).toLocal(),
                            );
                          },
                        );
                      },
                  ),
                ),
                _buildInputBar(),
              ],
            ),
    );
  }

  Widget _buildMessageBubble({required String text, required bool isMe, required DateTime createdAt}) {
    final timeStr = DateFormat('HH:mm').format(createdAt);
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: isMe ? null : Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Camelo Pro Suporte',
                  style: AppTypography.label.copyWith(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            Text(
              text,
              style: AppTypography.bodyMedium.copyWith(
                color: isMe ? Colors.white : AppColors.textMain,
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                timeStr,
                style: TextStyle(
                  fontSize: 10,
                  color: isMe ? Colors.white70 : Colors.black54,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 4,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: 'Escreva sua mensagem...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _sendMessage,
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
