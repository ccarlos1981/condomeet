import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'fale_sindico_chat_screen.dart';

class FaleSindicoThread {
  final String id;
  final String tipo;
  final String assunto;
  final String status;
  final DateTime createdAt;
  final DateTime? ultimaMensagemEm;

  FaleSindicoThread({
    required this.id,
    required this.tipo,
    required this.assunto,
    required this.status,
    required this.createdAt,
    this.ultimaMensagemEm,
  });

  factory FaleSindicoThread.fromMap(Map<String, dynamic> m) {
    return FaleSindicoThread(
      id: m['id'] as String,
      tipo: m['tipo'] as String? ?? 'duvida',
      assunto: m['assunto'] as String? ?? '',
      status: m['status'] as String? ?? 'aberto',
      createdAt: DateTime.parse(m['created_at'] as String),
      ultimaMensagemEm: m['ultima_mensagem_em'] != null
          ? DateTime.parse(m['ultima_mensagem_em'] as String)
          : null,
    );
  }
}

const tipoEmoji = {
  'reclamacao': '⚠️',
  'elogio': '👏',
  'pendencia': '📋',
  'sugestao': '💡',
  'duvida': '❓',
};

const tipoLabel = {
  'reclamacao': 'Reclamação',
  'elogio': 'Elogio',
  'pendencia': 'Pendência',
  'sugestao': 'Sugestão',
  'duvida': 'Dúvida',
};

class FaleSindicoScreen extends StatefulWidget {
  const FaleSindicoScreen({super.key});

  @override
  State<FaleSindicoScreen> createState() => _FaleSindicoScreenState();
}

class _FaleSindicoScreenState extends State<FaleSindicoScreen> {
  List<FaleSindicoThread> _threads = [];
  bool _loading = true;
  String? _error;

  // Modal de novo assunto
  String _novoTipo = 'duvida';
  final _assuntoCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final authState = context.read<AuthBloc>().state;
    final userId = authState.userId;
    if (userId == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final res = await Supabase.instance.client
          .from('fale_sindico_threads')
          .select()
          .eq('resident_id', userId)
          .order('ultima_mensagem_em', ascending: false, nullsFirst: false);
      setState(() {
        _threads = (res as List).map((r) => FaleSindicoThread.fromMap(r as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _criarThread() async {
    if (_assuntoCtrl.text.trim().isEmpty || _msgCtrl.text.trim().isEmpty) return;
    final authState = context.read<AuthBloc>().state;
    final userId = authState.userId;
    final condoId = authState.condominiumId;
    if (userId == null || condoId == null) return;

    setState(() => _saving = true);
    try {
      final threadRes = await Supabase.instance.client
          .from('fale_sindico_threads')
          .insert({
            'condominio_id': condoId,
            'resident_id': userId,
            'tipo': _novoTipo,
            'assunto': _assuntoCtrl.text.trim(),
            'status': 'aberto',
          })
          .select()
          .single();

      await Supabase.instance.client
          .from('fale_sindico_mensagens')
          .insert({
            'thread_id': threadRes['id'],
            'sender_id': userId,
            'is_admin': false,
            'texto': _msgCtrl.text.trim(),
          });

      // Update ultima_mensagem_em
      await Supabase.instance.client
          .from('fale_sindico_threads')
          .update({'ultima_mensagem_em': DateTime.now().toIso8601String()})
          .eq('id', threadRes['id'] as String);

      if (mounted) {
        Navigator.of(context).pop();
        _assuntoCtrl.clear();
        _msgCtrl.clear();
        _novoTipo = 'duvida';
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  void _showNovoAssunto() {
    _assuntoCtrl.clear();
    _msgCtrl.clear();
    _novoTipo = 'duvida';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Novo Assunto',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Tipo
              const Text('Tipo', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: tipoLabel.entries.map((e) {
                  final sel = _novoTipo == e.key;
                  return GestureDetector(
                    onTap: () => setModal(() => _novoTipo = e.key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primary : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? AppColors.primary : Colors.grey.shade300),
                      ),
                      child: Text(
                        '${tipoEmoji[e.key]} ${e.value}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Assunto
              const Text('Assunto', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _assuntoCtrl,
                decoration: InputDecoration(
                  hintText: 'Ex: Barulho no corredor',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              // Mensagem
              const Text('Mensagem', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _msgCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Descreva seu assunto...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : () async {
                    await _criarThread();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Enviar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Fale com a administração.',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(child: Text('Erro: $_error', style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _load,
                  child: Column(
                    children: [
                      // Botão Novo Assunto
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _showNovoAssunto,
                            icon: const Icon(Icons.add, color: AppColors.primary),
                            label: const Text('Novo assunto',
                                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      // Lista
                      Expanded(
                        child: _threads.isEmpty
                            ? _buildEmpty()
                            : ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: _threads.length,
                                itemBuilder: (_, i) => _ThreadCard(
                                  thread: _threads[i],
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => FaleSindicoChatScreen(thread: _threads[i]),
                                      ),
                                    );
                                    _load();
                                  },
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('Nenhuma conversa', style: TextStyle(fontSize: 16, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Clique em "Novo assunto" para iniciar', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        ],
      ),
    );
  }
}

class _ThreadCard extends StatelessWidget {
  final FaleSindicoThread thread;
  final VoidCallback onTap;

  const _ThreadCard({required this.thread, required this.onTap});

  Color get _statusColor {
    switch (thread.status) {
      case 'respondido': return Colors.green;
      case 'fechado': return Colors.grey;
      default: return AppColors.primary;
    }
  }

  String get _statusLabel {
    switch (thread.status) {
      case 'respondido': return 'Lido...';
      case 'fechado': return 'Fechado';
      default: return 'Aguardando';
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = thread.ultimaMensagemEm ?? thread.createdAt;
    final dateStr = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} ${date.hour < 12 ? 'am' : 'pm'}';

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
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Text(
          tipoEmoji[thread.tipo] ?? '📋',
          style: const TextStyle(fontSize: 24),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assunto: ${thread.assunto}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(color: _statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(_statusLabel, style: TextStyle(fontSize: 12, color: _statusColor, fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Criado no dia: $dateStr',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Container(
            width: 36, height: 36,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            child: const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
          ),
          onPressed: onTap,
        ),
        onTap: onTap,
      ),
    );
  }
}
