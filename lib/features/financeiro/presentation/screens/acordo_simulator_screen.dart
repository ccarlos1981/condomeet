import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:intl/intl.dart';

class AcordoSimulatorScreen extends StatefulWidget {
  const AcordoSimulatorScreen({super.key});

  @override
  State<AcordoSimulatorScreen> createState() => _AcordoSimulatorScreenState();
}

class _AcordoSimulatorScreenState extends State<AcordoSimulatorScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _submitting = false;
  List<dynamic> _vencidos = [];
  double _totalAmount = 0.0;
  int _installments = 1;
  String? _generatedAcordoId;
  String? _pixCopiaCola;
  String? _qrCodeUrl;
  bool _paid = false;

  @override
  void initState() {
    super.initState();
    _fetchOverdueFaturamentos();
  }

  Future<void> _fetchOverdueFaturamentos() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final data = await _supabase
          .from('faturamentos')
          .select()
          .eq('status_pagamento', 'vencido');

      double sum = 0.0;
      for (final item in data) {
        sum += (item['valor_total'] as num?)?.toDouble() ?? 0.0;
      }

      setState(() {
        _vencidos = data;
        _totalAmount = sum;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching overdue faturamentos: $e');
      setState(() => _isLoading = false);
    }
  }

  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value);
  }

  Future<void> _signAndGenerateAgreement() async {
    if (_vencidos.isEmpty || _submitting) return;

    setState(() => _submitting = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception("User not authenticated");

      final profileRes = await _supabase
          .from('perfil')
          .select('condominio_id, unidade_id')
          .eq('id', user.id)
          .single();

      final condominioId = profileRes['condominio_id'];
      final targetUnidadeId = profileRes['unidade_id'] ?? _vencidos.first['unidade_id'];

      // 1. Create financeiro_acordos
      final agreementInsert = await _supabase.from('financeiro_acordos').insert({
        'condominio_id': condominioId,
        'unidade_id': targetUnidadeId,
        'perfil_id': user.id,
        'valor_original': _totalAmount,
        'valor_desconto': 0.00,
        'valor_acordo': _totalAmount,
        'parcelas_qtd': _installments,
        'status': 'pendente',
        'termos_texto': 'Acordo Pix Express emitido digitalmente para renegociação de débitos pendentes em conformidade com as regras do condomínio e legislações vigentes.',
        'assinatura_timestamp': DateTime.now().toIso8601String(),
        'assinatura_ip': '127.0.0.1',
        'assinatura_user_agent': 'Condomeet Mobile Client',
      }).select().single();

      final agreementId = agreementInsert['id'];

      // 2. Insert parcelas
      final double valuePerInstallment = _totalAmount / _installments;
      for (int i = 1; i <= _installments; i++) {
        await _supabase.from('financeiro_acordo_parcelas').insert({
          'acordo_id': agreementId,
          'numero_parcela': i,
          'valor': double.parse(valuePerInstallment.toStringAsFixed(2)),
          'data_vencimento': DateTime.now().add(Duration(days: (i - 1) * 30)).toIso8601String().substring(0, 10),
          'status': 'pendente',
          'gateway_invoice_id': 'acordo_${agreementId}_part_$i',
          'gateway_pix_copia_cola': '00020101021226830014br.gov.bcb.pix2561api.asaas.com/v3/pix/qr/pay/acordo_${agreementId}_part_$i',
          'gateway_pix_qr_code': 'https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=acordo_${agreementId}_part_$i',
        });
      }

      // 3. Link original faturamentos
      for (final faturamento in _vencidos) {
        await _supabase.from('financeiro_acordo_faturamentos').insert({
          'acordo_id': agreementId,
          'faturamento_id': faturamento['id'],
        });
      }

      // 4. Invocar Edge Function para gerar Pix real no Asaas
      final response = await _supabase.functions.invoke(
        'finance-generate-agreement-pix',
        body: {'acordo_id': agreementId},
      );

      final data = response.data;
      if (data == null || data['success'] != true) {
        throw Exception(data?['error'] ?? 'Erro desconhecido ao gerar Pix no Asaas');
      }

      setState(() {
        _generatedAcordoId = agreementId;
        _pixCopiaCola = data['gateway_pix_copia_cola'];
        _qrCodeUrl = data['gateway_pix_qr_code'];
        _submitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Acordo assinado e Pix de entrada gerado com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error creating agreement: $e');
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao gerar acordo: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _simulateAsaasPayment() async {
    if (_generatedAcordoId == null || _paid) return;

    setState(() => _submitting = true);

    try {
      // Simulate Asaas gateway callback by updating first installment status to 'pago' directly.
      // This will fire the DB trigger `trg_after_parcela_paga`
      await _supabase
          .from('financeiro_acordo_parcelas')
          .update({'status': 'pago', 'data_pagamento': DateTime.now().toIso8601String()})
          .eq('acordo_id', _generatedAcordoId!)
          .eq('numero_parcela', 1);

      setState(() {
        _paid = true;
        _submitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pagamento confirmado via Asaas webhook simulado!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error simulating payment: $e');
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double valuePerInstallment = _totalAmount / _installments;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Acordo Pix Express', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _generatedAcordoId != null
              ? _buildPaymentDetailsView()
              : _vencidos.isEmpty
                  ? _buildNoDebtsView()
                  : _buildSimulatorView(valuePerInstallment),
    );
  }

  Widget _buildNoDebtsView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade600),
            ),
            const SizedBox(height: 20),
            const Text(
              'Parabéns! Tudo certo.',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Você não possui débitos pendentes elegíveis para acordo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimulatorView(double valuePerInstallment) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Regularização Eleitoral',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'O pagamento da primeira parcela restabelece seu direito de voto nas assembleias em menos de 60s.',
                        style: TextStyle(color: AppColors.primary.withValues(alpha: 0.8), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Resumo de Débitos',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Debts List Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ..._vencidos.map((f) {
                    final date = DateTime.parse(f['data_vencimento']);
                    final formattedDate = DateFormat('dd/MM/yyyy').format(date);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Taxa Condominial ($formattedDate)', style: const TextStyle(fontSize: 14)),
                          Text(_formatCurrency((f['valor_total'] as num).toDouble()), style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Overdue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(
                        _formatCurrency(_totalAmount),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Simular Parcelamento',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Installments slider Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Parcelas: $_installments x', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(
                        _formatCurrency(valuePerInstallment),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: _installments.toDouble(),
                    min: 1,
                    max: 12,
                    divisions: 11,
                    activeColor: AppColors.primary,
                    inactiveColor: Colors.grey.shade200,
                    label: '$_installments x',
                    onChanged: (val) {
                      setState(() {
                        _installments = val.round();
                      });
                    },
                  ),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('1x', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text('12x', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Terms text and sign button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Termos Legais:\nAo assinar este acordo digital, você assume a responsabilidade de pagar todas as parcelas mensais simuladas acima. O atraso de qualquer parcela poderá suspender seus direitos políticos no condomínio.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _submitting ? null : _signAndGenerateAgreement,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _submitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Assinar e Gerar Pix Acordo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetailsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _paid ? Colors.green.shade50 : Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _paid ? Icons.check_circle : Icons.pix,
              size: 48,
              color: _paid ? Colors.green : Colors.blue,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _paid ? 'Acordo Ativo' : 'Pague a 1ª Parcela para Ativar',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _paid
                ? 'Sua unidade foi desbloqueada. Você já pode votar na assembleia!'
                : 'Copie a chave Pix abaixo ou escaneie o QR Code.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),

          if (!_paid) ...[
            // QR Code Placeholder Image
            if (_qrCodeUrl != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Image.network(_qrCodeUrl!, width: 200, height: 200),
              ),
            const SizedBox(height: 24),

            // Pix copy paste field
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pix, color: Colors.blue, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _pixCopiaCola ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      if (_pixCopiaCola != null && _pixCopiaCola!.isNotEmpty) {
                        Clipboard.setData(ClipboardData(text: _pixCopiaCola!));
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Pix Copia e Cola copiado!')),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Simulate payment button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting ? null : _simulateAsaasPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _submitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Simular Pagamento no Asaas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ] else ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Voltar para a Assembleia', style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
