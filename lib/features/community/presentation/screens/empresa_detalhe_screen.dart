import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:condomeet/core/design_system/design_system.dart';

class EmpresaDetalheScreen extends StatelessWidget {
  final Map<String, dynamic> empresa;
  const EmpresaDetalheScreen({super.key, required this.empresa});

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _launchWhatsApp(BuildContext context) {
    final number = (empresa['whatsapp'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
    if (number.isEmpty) return;
    _launch('https://wa.me/55$number?text=Olá, vi seu anúncio no Condomeet!');
  }

  void _launchPhone(BuildContext context) {
    final number = (empresa['celular'] ?? empresa['whatsapp'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
    if (number.isEmpty) return;
    _launch('tel:$number');
  }

  void _launchEmail(BuildContext context) {
    final email = empresa['email'] ?? '';
    if (email.toString().isEmpty) return;
    _launch('mailto:$email');
  }

  Widget _socialButton(String label, String? value, String baseUrl, Color color) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    final handle = value.startsWith('http') ? value : '$baseUrl$value';
    return GestureDetector(
      onTap: () => _launch(handle),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fotos = List<Map<String, dynamic>>.from(empresa['propaganda_fotos'] ?? []);
    fotos.sort((a, b) => (a['ordem'] as int).compareTo(b['ordem'] as int));

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)],
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 40),
                        empresa['logo_url'] != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.network(
                                empresa['logo_url'],
                                width: 100, height: 100, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.business, color: Colors.white, size: 60),
                              ),
                            )
                          : const Icon(Icons.business, color: Colors.white, size: 60),
                        const SizedBox(height: 12),
                        Text(
                          empresa['nome'] ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        if (empresa['especialidade'] != null)
                          Text(empresa['especialidade'], style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Action buttons
                  Row(
                    children: [
                      if ((empresa['whatsapp'] ?? '').isNotEmpty)
                        Expanded(child: _actionButton('WhatsApp', Icons.chat, Colors.green, () => _launchWhatsApp(context))),
                      if ((empresa['celular'] ?? '').isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(child: _actionButton('Ligar', Icons.phone, Colors.blue, () => _launchPhone(context))),
                      ],
                      if ((empresa['email'] ?? '').isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(child: _actionButton('Email', Icons.email, Colors.orange, () => _launchEmail(context))),
                      ],
                      if ((empresa['site'] ?? '').isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(child: _actionButton('Site', Icons.language, AppColors.primary, () => _launch(empresa['site']))),
                      ],
                    ],
                  ),

                  // Info
                  if ((empresa['endereco'] ?? '').isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _infoRow(Icons.location_on, empresa['endereco']),
                  ],
                  if ((empresa['whatsapp'] ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onLongPress: () {
                        Clipboard.setData(ClipboardData(text: empresa['whatsapp']));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('WhatsApp copiado!')),
                        );
                      },
                      child: _infoRow(Icons.phone_android, empresa['whatsapp']),
                    ),
                  ],

                  // Redes sociais
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _socialButton('📷 Instagram', empresa['instagram'], 'https://instagram.com/', Colors.pink),
                      _socialButton('👍 Facebook', empresa['facebook'], 'https://facebook.com/', Colors.blue),
                      _socialButton('▶️ YouTube', empresa['youtube'], 'https://youtube.com/', Colors.red),
                      _socialButton('🎵 TikTok', empresa['tiktok'], 'https://tiktok.com/@', Colors.black),
                      _socialButton('🐦 Twitter/X', empresa['twitter'], 'https://twitter.com/', Colors.blueGrey),
                      _socialButton('💼 LinkedIn', empresa['linkedin'], 'https://linkedin.com/in/', Colors.indigo),
                    ],
                  ),

                  // Fotos do espaço
                  if (fotos.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text('Fotos da empresa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.2,
                      ),
                      itemCount: fotos.length,
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(fotos[i]['foto_url'], fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200)),
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),
                  Center(
                    child: Text('Anúncio no Condomeet',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: Colors.black87))),
      ],
    );
  }
}
