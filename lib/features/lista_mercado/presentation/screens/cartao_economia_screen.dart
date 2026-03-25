import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:condomeet/features/lista_mercado/lista_mercado_service.dart';

/// Phase 7: Viral Sharing — Cartão de Economia
/// Generates a beautiful savings card that users can share.
class CartaoEconomiaScreen extends StatefulWidget {
  const CartaoEconomiaScreen({super.key});

  @override
  State<CartaoEconomiaScreen> createState() => _CartaoEconomiaScreenState();
}

class _CartaoEconomiaScreenState extends State<CartaoEconomiaScreen> {
  final _service = ListaMercadoService();
  final _cardKey = GlobalKey();

  bool _loading = true;
  bool _sharing = false;

  // User data
  String _userName = '';
  String _rankTitle = 'Iniciante';
  int _totalPoints = 0;
  int _reportsCount = 0;
  int _listsCount = 0;
  int _alertsCount = 0;
  double _estimatedSavings = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final points = await _service.getMyPoints();
      final lists = await _service.getMyLists();

      // Get user name
      final userId = _service.currentUserId;
      if (userId != null) {
        final names = await _service.getUserNames([userId]);
        _userName = names[userId] ?? 'Usuário';
      }

      // Estimate savings from price comparisons in user's lists
      double savings = 0;
      for (final list in lists) {
        final items = list['lista_shopping_list_items'] as List? ?? [];
        savings += items.length * 2.50; // Estimated avg savings per item
      }

      // Get alert count
      final alerts = await _service.getMyAlerts();
      final triggeredAlerts = (alerts as List).where((a) => a['status'] == 'triggered').length;
      savings += triggeredAlerts * 5.0; // Extra savings from triggered alerts

      if (mounted) {
        setState(() {
          _totalPoints = points?['total_points'] ?? 0;
          _rankTitle = points?['rank_title'] ?? 'Iniciante';
          _reportsCount = points?['reports_count'] ?? 0;
          _listsCount = lists.length;
          _alertsCount = triggeredAlerts;
          _estimatedSavings = savings;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _shareCard() async {
    setState(() => _sharing = true);
    try {
      // Capture the card as image
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // Save to temp
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/cartao_economia.png');
      await file.writeAsBytes(pngBytes);

      // Share
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '🛒 Já economizei R\$ ${_estimatedSavings.toStringAsFixed(2)} usando a Lista Inteligente do Condomeet! 💰\n\n📊 ${_reportsCount} preços reportados\n🏆 Rank: $_rankTitle\n\nBaixe o app e comece a economizar! 🚀',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao compartilhar: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
    if (mounted) setState(() => _sharing = false);
  }

  String _getRankEmoji() {
    switch (_rankTitle) {
      case 'Mestre do Preço': return '👑';
      case 'Caçador de Oferta': return '🎯';
      case 'Fiscal de Preço': return '🔍';
      case 'Colaborador': return '⭐';
      default: return '🌱';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Row(
          children: [
            Text('📤', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text('Compartilhar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C853)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Preview text
                  const Text('Seu Cartão de Economia 💰',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Mostre quanto você economizou!',
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
                  const SizedBox(height: 20),

                  // ═══════════════════════════════
                  // THE SHAREABLE CARD
                  // ═══════════════════════════════
                  RepaintBoundary(
                    key: _cardKey,
                    child: _buildCard(),
                  ),

                  const SizedBox(height: 24),

                  // Share button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _sharing ? null : _shareCard,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C853),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      child: _sharing
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.share, color: Colors.white),
                                SizedBox(width: 10),
                                Text('Compartilhar no WhatsApp 📲',
                                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Copy text button
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Texto copiado! ✅'), backgroundColor: Color(0xFF00C853)),
                      );
                    },
                    child: const Text('📋 Copiar texto', style: TextStyle(color: Colors.white38)),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: const Color(0xFF00C853).withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              const Text('🛒', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Lista Inteligente', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('Condomeet', style: TextStyle(color: Colors.white38, fontSize: 12, letterSpacing: 1)),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C853).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF00C853).withOpacity(0.4)),
                ),
                child: Text(_getRankEmoji(), style: const TextStyle(fontSize: 20)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Divider
          Container(height: 1, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 20),

          // User name + rank
          Text(_userName.isNotEmpty ? _userName.split(' ').first : 'Você',
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                const Color(0xFF00C853).withOpacity(0.3),
                const Color(0xFF00E676).withOpacity(0.3),
              ]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('${_getRankEmoji()} $_rankTitle',
                style: const TextStyle(color: Color(0xFF00E676), fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 24),

          // Big savings number
          const Text('ECONOMIA ESTIMADA', style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 2)),
          const SizedBox(height: 4),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF00E676), Color(0xFF00C853), Color(0xFF69F0AE)],
            ).createShader(bounds),
            child: Text(
              'R\$ ${_estimatedSavings.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900, height: 1),
            ),
          ),
          const SizedBox(height: 20),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatPill('📊', '$_reportsCount', 'Preços'),
              _buildStatPill('📋', '$_listsCount', 'Listas'),
              _buildStatPill('🔔', '$_alertsCount', 'Alertas'),
              _buildStatPill('⭐', '$_totalPoints', 'Pontos'),
            ],
          ),
          const SizedBox(height: 20),

          // Footer
          Container(height: 1, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Baixe o Condomeet e economize também! ',
                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
              const Text('🚀', style: TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(String emoji, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9)),
        ],
      ),
    );
  }
}
