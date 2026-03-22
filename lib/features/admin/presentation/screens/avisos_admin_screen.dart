import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/design_system/design_system.dart';

class AvisosAdminScreen extends StatefulWidget {
  const AvisosAdminScreen({super.key});

  @override
  State<AvisosAdminScreen> createState() => _AvisosAdminScreenState();
}

class _AvisosAdminScreenState extends State<AvisosAdminScreen> {
  final _supabase = Supabase.instance.client;
  final _tituloController = TextEditingController();
  final _corpoController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSending = false;
  bool _loading = true;
  List<Map<String, dynamic>> _avisos = [];

  @override
  void initState() {
    super.initState();
    _loadAvisos();
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _corpoController.dispose();
    super.dispose();
  }

  Future<String?> _getCondoId() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    final profile = await _supabase
        .from('perfil')
        .select('condominio_id')
        .eq('id', user.id)
        .maybeSingle();
    return profile?['condominio_id'] as String?;
  }

  Future<void> _loadAvisos() async {
    try {
      final condoId = await _getCondoId();
      if (condoId == null) return;

      final data = await _supabase
          .from('avisos')
          .select('id, titulo, corpo, created_at')
          .eq('condominio_id', condoId)
          .order('created_at', ascending: false)
          .limit(50);

      if (mounted) {
        setState(() {
          _avisos = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _enviarAviso() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);
    HapticFeedback.mediumImpact();

    try {
      final user = _supabase.auth.currentUser;
      final condoId = await _getCondoId();

      if (condoId == null || user == null) {
        throw Exception('Condomínio não encontrado');
      }

      await _supabase.from('avisos').insert({
        'condominio_id': condoId,
        'autor_id': user.id,
        'titulo': _tituloController.text.trim(),
        'corpo': _corpoController.text.trim(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Aviso enviado com sucesso!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      _tituloController.clear();
      _corpoController.clear();
      _loadAvisos();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erro ao enviar: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _deleteAviso(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir aviso?'),
        content: const Text('Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _supabase.from('avisos').delete().eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ Aviso excluído'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadAvisos();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro ao excluir: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text(
          'Enviar Aviso',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadAvisos,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              // ── Form section ──
              _buildFormSection(),
              const SizedBox(height: 24),

              // ── Existing avisos list ──
              _buildSectionTitle('Avisos enviados'),
              const SizedBox(height: 8),
              if (_loading)
                const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
              else if (_avisos.isEmpty)
                _buildEmptyState()
              else
                ..._avisos.map(_buildAvisoCard),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.campaign_rounded,
                    color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Novo aviso para todos os moradores',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMain,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Título
            TextFormField(
              controller: _tituloController,
              decoration: InputDecoration(
                labelText: 'Título do Aviso',
                hintText: 'Ex: Reunião de condomínio',
                prefixIcon:
                    Icon(Icons.title_rounded, color: AppColors.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Informe o título'
                  : null,
              textInputAction: TextInputAction.next,
              maxLength: 40,
            ),
            const SizedBox(height: 12),

            // Corpo
            TextFormField(
              controller: _corpoController,
              decoration: InputDecoration(
                labelText: 'Mensagem',
                hintText: 'Escreva o conteúdo do aviso...',
                prefixIcon: Icon(Icons.message_outlined,
                    color: AppColors.primary),
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Informe a mensagem'
                  : null,
              maxLines: 5,
              minLines: 3,
              textInputAction: TextInputAction.newline,
            ),
            const SizedBox(height: 20),

            // Botão enviar
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isSending ? null : _enviarAviso,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor:
                      AppColors.primary.withValues(alpha: 0.5),
                ),
                icon: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _isSending ? 'Enviando...' : 'Enviar Aviso',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: const Column(
        children: [
          Icon(Icons.campaign_outlined, size: 48, color: AppColors.disabledIcon),
          SizedBox(height: 12),
          Text(
            'Nenhum aviso enviado ainda',
            style: TextStyle(color: AppColors.textHint, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildAvisoCard(Map<String, dynamic> aviso) {
    final createdAt = DateTime.parse(aviso['created_at']);
    final dateStr =
        '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year} – ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Icon(Icons.campaign_rounded,
            color: AppColors.primary.withValues(alpha: 0.6), size: 28),
        title: Text(
          aviso['titulo'] ?? '',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.textMain,
          ),
        ),
        subtitle: Text(
          dateStr,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded,
              color: Colors.red, size: 20),
          onPressed: () => _deleteAviso(aviso['id']),
        ),
      ),
    );
  }
}
