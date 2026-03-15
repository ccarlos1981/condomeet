import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import '../../domain/models/chat_message.dart';
import 'package:condomeet/features/security/presentation/bloc/chat_bloc.dart';
import 'package:condomeet/features/security/presentation/bloc/chat_event.dart';
import 'package:condomeet/features/security/presentation/bloc/chat_state.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';

class ChatScreen extends StatefulWidget {
  final String residentId;

  const ChatScreen({super.key, required this.residentId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    context.read<ChatBloc>().add(WatchMessagesRequested(widget.residentId));
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    final authState = context.read<AuthBloc>().state;
    if (authState.condominiumId == null || authState.userId == null) return;

    context.read<ChatBloc>().add(
      SendMessageRequested(
        residentId: widget.residentId,
        condominiumId: authState.condominiumId!,
        senderId: authState.userId!,
        senderRole: MessageSenderRole.values.firstWhere(
          (e) => e.name == (authState.role ?? 'resident'),
          orElse: () => MessageSenderRole.resident,
        ),
        text: text,
      ),
    );

    _messageController.clear();
    
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Administração'),
            Text('Suporte Oficial', style: AppTypography.label.copyWith(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocBuilder<ChatBloc, ChatState>(
              builder: (context, state) {
                if (state is ChatLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final messages = state is ChatMessagesLoaded ? state.messages : <ChatMessage>[];
                
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _buildMessageBubble(message);
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

  Widget _buildMessageBubble(ChatMessage message) {
    final isMe = message.isFromResident;
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
          border: isMe ? null : Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.senderName ?? 'Administração',
                  style: AppTypography.label.copyWith(color: AppColors.primary, fontSize: 10),
                ),
              ),
            Text(
              message.text,
              style: AppTypography.bodyMedium.copyWith(
                color: isMe ? Colors.white : AppColors.textMain,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: CondoInput(
                label: '',
                hint: 'Escreva sua mensagem...',
                controller: _messageController,
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send_rounded, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
