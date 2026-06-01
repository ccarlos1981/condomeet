import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GaragemCheckoutScreen extends StatefulWidget {
  final Map<String, dynamic> reserva;
  const GaragemCheckoutScreen({super.key, required this.reserva});

  @override
  State<GaragemCheckoutScreen> createState() => _GaragemCheckoutScreenState();
}

class _GaragemCheckoutScreenState extends State<GaragemCheckoutScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  String? _qrCodeBase64;
  String? _copyPaste;
  String? _error;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _generatePix();
    _listenPaymentStatus();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  void _listenPaymentStatus() {
    _channel = _supabase
        .channel('public:garage_reservations:id=eq.${widget.reserva['id']}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'garage_reservations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.reserva['id'],
          ),
          callback: (payload) {
            final newStatus = payload.newRecord['payment_status'];
            if (newStatus == 'pago' || newStatus == 'repassado') {
              if (mounted) {
                _showSuccessAndPop();
              }
            }
          },
        )
        .subscribe();
  }

  void _showSuccessAndPop() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Pagamento confirmado! Sua reserva está garantida.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 4),
      ),
    );
    Navigator.of(context).pop(true);
  }

  Future<void> _generatePix() async {
    try {
      final res = await _supabase.functions.invoke('garage-checkout', body: {
        'reservation_id': widget.reserva['id'],
      });

      final data = res.data;
      if (data['error'] != null) {
        throw data['error'];
      }

      if (mounted) {
        setState(() {
          _qrCodeBase64 = data['qrCode'];
          _copyPaste = data['copyPaste'];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Pagamento da Reserva'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Center(
        child: _loading
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Gerando código PIX...'),
                ],
              )
            : _error != null
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 64),
                        const SizedBox(height: 16),
                        Text('Erro ao gerar pagamento:', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _loading = true;
                              _error = null;
                            });
                            _generatePix();
                          },
                          child: const Text('Tentar novamente'),
                        )
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'Pague via PIX para confirmar',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sua reserva só será confirmada após o pagamento.',
                          style: TextStyle(color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        if (_qrCodeBase64 != null)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
                              ],
                            ),
                            child: Image.memory(
                              base64Decode(_qrCodeBase64!),
                              width: 200,
                              height: 200,
                            ),
                          ),
                        const SizedBox(height: 32),
                        const Text('Ou copie o código PIX abaixo:', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _copyPaste ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontFamily: 'monospace'),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, color: AppColors.primary),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: _copyPaste ?? ''));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Código copiado!')),
                                  );
                                },
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        const CircularProgressIndicator(strokeWidth: 2),
                        const SizedBox(height: 16),
                        const Text('Aguardando confirmação do banco...', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
      ),
    );
  }
}
