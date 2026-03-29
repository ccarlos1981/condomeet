import 'package:flutter/material.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/features/garagem/garagem_service.dart';

class GaragemDetailScreen extends StatefulWidget {
  final String vagaId;
  const GaragemDetailScreen({super.key, required this.vagaId});

  @override
  State<GaragemDetailScreen> createState() => _GaragemDetailScreenState();
}

class _GaragemDetailScreenState extends State<GaragemDetailScreen> {
  final _service = GaragemService();
  Map<String, dynamic>? _vaga;
  bool _loading = true;
  double _rating = 0;

  @override
  void initState() {
    super.initState();
    _loadVaga();
  }

  Future<void> _loadVaga() async {
    setState(() => _loading = true);
    try {
      final data = await _service.getVagaDetalhe(widget.vagaId);
      double rating = 0;
      if (data != null) {
        final reviews = data['garage_reviews'] as List? ?? [];
        if (reviews.isNotEmpty) {
          final sum = reviews.fold(0, (s, r) => s + ((r as Map)['rating'] as int));
          rating = sum / reviews.length;
        }
      }
      if (mounted) setState(() { _vaga = data; _rating = rating; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_vaga == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vaga')),
        body: const Center(child: Text('Vaga não encontrada')),
      );
    }

    final tipo = _vaga!['tipo_vaga'] as String? ?? 'carro_grande';
    final tipoLabel = tipo == 'moto' ? 'Moto' : tipo == 'carro_pequeno' ? 'Carro Pequeno' : 'Carro Grande';
    final tipoIcon = tipo == 'moto' ? Icons.two_wheeler : tipo == 'carro_pequeno' ? Icons.directions_car : Icons.directions_car_filled;
    final perfil = _vaga!['perfil'] as Map<String, dynamic>?;
    final availability = (_vaga!['garage_availability'] as List?) ?? [];
    final diasSemana = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Vaga ${_vaga!['numero_vaga']}', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(tipoIcon, color: AppColors.primary, size: 36),
                  ),
                  const SizedBox(height: 12),
                  Text('Vaga ${_vaga!['numero_vaga']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(tipoLabel, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                  if (_rating > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ...List.generate(5, (i) => Icon(
                          i < _rating.round() ? Icons.star : Icons.star_border,
                          color: Colors.amber, size: 20,
                        )),
                        const SizedBox(width: 6),
                        Text(_rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                  if (perfil != null) ...[
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: perfil['foto_url'] != null ? NetworkImage(perfil['foto_url']) : null,
                          child: perfil['foto_url'] == null ? const Icon(Icons.person, size: 18) : null,
                        ),
                        const SizedBox(width: 8),
                        Text(perfil['nome_completo'] ?? 'Morador', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    if (perfil['bloco_txt'] != null || perfil['apto_txt'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${perfil['bloco_txt'] ?? ''} ${perfil['apto_txt'] ?? ''}'.trim(),
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Preços
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💰 Preços', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if ((_vaga!['preco_hora'] ?? 0) > 0)
                    _buildPriceRow('Por hora', _vaga!['preco_hora']),
                  if ((_vaga!['preco_dia'] ?? 0) > 0)
                    _buildPriceRow('Por dia', _vaga!['preco_dia']),
                  if ((_vaga!['preco_mes'] ?? 0) > 0)
                    _buildPriceRow('Por mês', _vaga!['preco_mes']),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Disponibilidade
            if (availability.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🕐 Disponibilidade', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ...availability.map((a) {
                      final dia = (a as Map)['dia_semana'] as int;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 40,
                              child: Text(
                                diasSemana[dia],
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${a['hora_inicio']} - ${a['hora_fim']}',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

            if (_vaga!['descricao'] != null && (_vaga!['descricao'] as String).isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📝 Descrição', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_vaga!['descricao'], style: TextStyle(color: Colors.grey.shade700)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/garagem-reservar', arguments: _vaga).then((_) => _loadVaga());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 3,
            ),
            child: const Text(
              'Reservar Vaga',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 15, color: Colors.grey.shade700)),
          Text(
            'R\$ ${(value as num).toStringAsFixed(2)}',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.green.shade700),
          ),
        ],
      ),
    );
  }
}
