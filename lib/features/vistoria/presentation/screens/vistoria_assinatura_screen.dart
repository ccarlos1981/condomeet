import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:signature/signature.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/features/vistoria/vistoria_service.dart';

class VistoriaAssinaturaScreen extends StatefulWidget {
  final String vistoriaId;
  final Map<String, dynamic> vistoria;
  const VistoriaAssinaturaScreen({
    super.key,
    required this.vistoriaId,
    required this.vistoria,
  });

  @override
  State<VistoriaAssinaturaScreen> createState() =>
      _VistoriaAssinaturaScreenState();
}

class _VistoriaAssinaturaScreenState extends State<VistoriaAssinaturaScreen> {
  final _service = VistoriaService();
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _assinaturas = [];
  bool _loading = true;

  static const _papeis = [
    {'value': 'proprietario', 'label': 'Proprietário', 'icon': Icons.home_rounded, 'color': Color(0xFF3B82F6)},
    {'value': 'inquilino', 'label': 'Inquilino', 'icon': Icons.person_rounded, 'color': Color(0xFF10B981)},
    {'value': 'vistoriador', 'label': 'Vistoriador', 'icon': Icons.assignment_ind_rounded, 'color': Color(0xFFF59E0B)},
    {'value': 'testemunha', 'label': 'Testemunha', 'icon': Icons.visibility_rounded, 'color': Color(0xFF8B5CF6)},
  ];

  @override
  void initState() {
    super.initState();
    _loadAssinaturas();
  }

  Future<void> _loadAssinaturas() async {
    setState(() => _loading = true);
    try {
      _assinaturas = await _service.listAssinaturas(widget.vistoriaId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _shareLinkAssinatura() async {
    try {
      String? token = widget.vistoria['link_publico_token'] as String?;
      if (token == null || token.isEmpty) {
        token = await _service.gerarLinkPublico(widget.vistoriaId);
      }

      // TODO: Replace with production URL when deploying
      const String baseUrl = 'https://web-app-mu-rouge.vercel.app';
      final url = '$baseUrl/vistoria/$token';
      final titulo = widget.vistoria['titulo'] ?? 'Vistoria';
      final tipo = widget.vistoria['tipo_vistoria'] == 'saida' ? 'Saída' : 'Entrada';

      final message = '📋 *Vistoria de $tipo - $titulo*\n\n'
          'Você foi convidado(a) a revisar e assinar esta vistoria digital.\n\n'
          '👉 Acesse o link abaixo para visualizar todos os detalhes e assinar:\n'
          '$url\n\n'
          '_Enviado via Condomeet Check_';

      await SharePlus.instance.share(ShareParams(text: message));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao compartilhar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textMain),
          onPressed: () => Navigator.pop(context, _assinaturas),
        ),
        title: Row(
          children: [
            const Text('✍️', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              widget.vistoria['tipo_vistoria'] == 'saida' 
                  ? 'Assinaturas de Saída' 
                  : 'Assinaturas de Entrada',
              style: const TextStyle(
                color: AppColors.textMain,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                // Info header
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade50, Colors.purple.shade50],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Adicione as partes envolvidas e colete as assinaturas digitais.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Share link button
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _shareLinkAssinatura,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [const Color(0xFF8B5CF6).withValues(alpha: 0.08), const Color(0xFF6366F1).withValues(alpha: 0.08)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.share_rounded, color: Color(0xFF8B5CF6), size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Enviar Link de Assinatura',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Color(0xFF6D28D9),
                                    ),
                                  ),
                                  Text(
                                    'Via WhatsApp, e-mail ou SMS — sem instalar o app',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.open_in_new_rounded, color: Color(0xFF8B5CF6), size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Signatures list
                Expanded(
                  child: _assinaturas.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.draw_rounded, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text(
                                'Nenhuma assinatura ainda',
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Toque no "+" para adicionar',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _assinaturas.length,
                          itemBuilder: (context, index) =>
                              _buildAssinaturaCard(_assinaturas[index]),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAssinaturaDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text(
          'Adicionar Parte',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildAssinaturaCard(Map<String, dynamic> a) {
    final papel = _papeis.firstWhere(
      (p) => p['value'] == a['papel'],
      orElse: () => _papeis.first,
    );
    final assinado = a['assinatura_url'] != null &&
        (a['assinatura_url'] as String).isNotEmpty;
    final assinadoEm = a['assinado_em'] != null
        ? DateTime.tryParse(a['assinado_em'] as String)
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (papel['color'] as Color).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    papel['icon'] as IconData,
                    color: papel['color'] as Color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a['nome'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.textMain,
                        ),
                      ),
                      Text(
                        papel['label'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          color: papel['color'] as Color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: assinado
                        ? const Color(0xFFD1FAE5)
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        assinado ? Icons.check_circle : Icons.pending,
                        size: 14,
                        color: assinado
                            ? const Color(0xFF059669)
                            : const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        assinado ? 'Assinado' : 'Pendente',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: assinado
                              ? const Color(0xFF059669)
                              : const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Signature area
          if (assinado) ...[
            const Divider(height: 1),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      a['assinatura_url'] as String,
                      height: 80,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  if (assinadoEm != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Assinado em ${assinadoEm.day.toString().padLeft(2, '0')}/${assinadoEm.month.toString().padLeft(2, '0')}/${assinadoEm.year} às ${assinadoEm.hour.toString().padLeft(2, '0')}:${assinadoEm.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            const Divider(height: 1),
            InkWell(
              onTap: () => _showSignaturePad(a),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Icon(Icons.draw_rounded, size: 32, color: Colors.grey.shade400),
                    const SizedBox(height: 6),
                    Text(
                      'Toque para assinar',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAddAssinaturaDialog() {
    String nome = '';
    String papel = 'proprietario';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(
            24, 20, 24,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '👤 Adicionar Parte',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (v) => nome = v,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Nome completo *',
                  hintText: 'Ex: João da Silva',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Papel',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _papeis.map((p) {
                  final selected = papel == p['value'];
                  return GestureDetector(
                    onTap: () => setModalState(() => papel = p['value'] as String),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? (p['color'] as Color).withValues(alpha: 0.1)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? p['color'] as Color : Colors.grey.shade300,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(p['icon'] as IconData, size: 16, color: p['color'] as Color),
                          const SizedBox(width: 6),
                          Text(
                            p['label'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: selected ? p['color'] as Color : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: nome.isEmpty
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          await _addAssinatura(nome, papel);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Adicionar',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addAssinatura(String nome, String papel) async {
    try {
      await _service.addAssinatura(
        vistoriaId: widget.vistoriaId,
        nome: nome,
        papel: papel,
      );
      await _loadAssinaturas();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showSignaturePad(Map<String, dynamic> assinatura) {
    final controller = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
      exportPenColor: Colors.black,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    '✍️ Assine abaixo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => controller.clear(),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Limpar'),
                    style: TextButton.styleFrom(foregroundColor: Colors.grey),
                  ),
                ],
              ),
            ),
            // Name/Role
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '${assinatura['nome']}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      assinatura['papel'] ?? '',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Signature pad
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Signature(
                    controller: controller,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
            ),
            // Hint
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Use o dedo para assinar',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              ),
            ),
            // Confirm button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (controller.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Desenhe sua assinatura primeiro'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    await _uploadSignature(assinatura, controller);
                  },
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: const Text(
                    'Confirmar Assinatura',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).then((_) => controller.dispose());
  }

  Future<void> _uploadSignature(
    Map<String, dynamic> assinatura,
    SignatureController controller,
  ) async {
    try {
      final authState = context.read<AuthBloc>().state;
      final condoId = authState.condominiumId;
      if (condoId == null) return;

      // Export signature as PNG bytes
      final data = await controller.toPngBytes();
      if (data == null) return;

      final assinaturaId = assinatura['id'] as String;
      final path = '$condoId/${widget.vistoriaId}/$assinaturaId.png';

      // Upload to Supabase Storage
      await _supabase.storage.from('vistoria-assinaturas').uploadBinary(
        path,
        data,
        fileOptions: const FileOptions(upsert: true, contentType: 'image/png'),
      );

      final url = _supabase.storage
          .from('vistoria-assinaturas')
          .getPublicUrl(path);

      // Update record
      await _supabase.from('vistoria_assinaturas').update({
        'assinatura_url': url,
        'assinado_em': DateTime.now().toIso8601String(),
      }).eq('id', assinaturaId);

      await _loadAssinaturas();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Assinatura registrada!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
