import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class BoletosListScreen extends StatefulWidget {
  const BoletosListScreen({super.key});

  @override
  State<BoletosListScreen> createState() => _BoletosListScreenState();
}

class _BoletosListScreenState extends State<BoletosListScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _boletos = [];

  @override
  void initState() {
    super.initState();
    _fetchBoletos();
  }

  Future<void> _fetchBoletos() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // A política RLS "Residents can view own faturamentos" cuida de filtrar os boletos
      // apenas para a unidade do morador logado.
      final data = await _supabase
          .from('faturamentos')
          .select()
          .order('data_vencimento', ascending: false);

      setState(() {
        _boletos = data;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erro ao buscar boletos: $e');
      setState(() => _isLoading = false);
    }
  }

  String _formatCurrency(num value) {
    return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value);
  }

  String _formatDate(String dateStr) {
    final date = DateTime.parse(dateStr);
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Future<void> _abrirBoletoPDF(String boletoUrl) async {
    if (boletoUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Boleto PDF ainda não foi gerado pelo sistema.')),
      );
      return;
    }
    
    final uri = Uri.parse(boletoUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o Boleto.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Meus Boletos', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _boletos.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhum boleto encontrado.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _boletos.length,
                  itemBuilder: (context, index) {
                    final boleto = _boletos[index];
                    final isPago = boleto['status_pagamento'] == 'pago';
                    final valor = boleto['valor_total'] ?? 0;
                    final dataVencimento = boleto['data_vencimento'] ?? '';
                    
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey[200]!),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatCurrency(valor),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isPago ? Colors.green[50] : Colors.orange[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isPago ? 'PAGO PIX' : 'PENDENTE',
                                    style: TextStyle(
                                      color: isPago ? Colors.green[700] : Colors.orange[800],
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text(
                                  'Vencimento: ${_formatDate(dataVencimento)}',
                                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                if (!isPago) ...[
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Código PIX copiado!')),
                                        );
                                      },
                                      icon: const Icon(Icons.pix, size: 18),
                                      label: const Text('COPIAR PIX'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _abrirBoletoPDF(boleto['pdf_url'] ?? ''),
                                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                                    label: const Text('VER BOLETO'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.black87,
                                      side: BorderSide(color: Colors.grey[300]!),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
