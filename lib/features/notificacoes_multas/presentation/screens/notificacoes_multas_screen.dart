import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';


class NotificacoesMultasScreen extends StatefulWidget {
  const NotificacoesMultasScreen({super.key});

  @override
  State<NotificacoesMultasScreen> createState() => _NotificacoesMultasScreenState();
}

class _NotificacoesMultasScreenState extends State<NotificacoesMultasScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _historico = [];
  String? _expandedId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Usuário não autenticado');
      }

      final profileRaw = await _supabase
          .from('perfil')
          .select('condominio_id')
          .eq('id', user.id)
          .maybeSingle();
          
      if (profileRaw == null) {
        throw Exception('Perfil não encontrado');
      }

      final condoId = profileRaw['condominio_id'] as String;

      // Note: RLS automatically handles filtering to only rows that belong to 
      // the units the user is associated with.
      final response = await _supabase
          .from('notificacoes_multas')
          .select('''
            id, tipo, titulo, descricao, anexo_url, lido_em, data_ocorrencia, created_at, status
          ''')
          .eq('condominio_id', condoId)
          .order('created_at', ascending: false);

      setState(() {
        _historico = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDownload(String anexoUrl) async {
    try {
      final response = await _supabase.storage.from('documentos').createSignedUrl(anexoUrl, 60);
      final uri = Uri.parse(response);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Não foi possível abrir o link');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir anexo: $e')),
        );
      }
    }
  }

  Future<void> _toggleExpandAndMarkAsRead(Map<String, dynamic> item) async {
    final id = item['id'];
    
    setState(() {
      if (_expandedId == id) {
        _expandedId = null;
      } else {
        _expandedId = id;
      }
    });

    // Mark as read in DB if it hasn't been read yet
    if (item['lido_em'] == null) {
      try {
        final now = DateTime.now().toIso8601String();
        await _supabase
            .from('notificacoes_multas')
            .update({'lido_em': now, 'lido_por': _supabase.auth.currentUser?.id})
            .eq('id', id);
        
        setState(() {
          final index = _historico.indexWhere((h) => h['id'] == id);
          if (index != -1) {
            _historico[index]['lido_em'] = now;
          }
        });
      } catch (e) {
        print('Erro ao marcar como lido: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Notificações e Multas', style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _historico.isEmpty
              ? _buildEmptyState()
              : _buildList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.notifications_none, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text('Nenhuma notificação ou multa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          SizedBox(height: 8),
          Text('Sua unidade não possui registros.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _historico.length,
      itemBuilder: (context, index) {
        final item = _historico[index];
        final isExpanded = _expandedId == item['id'];
        final isLida = item['lido_em'] != null;
        
        DateTime occDate = DateTime.parse(item['data_ocorrencia'] ?? item['created_at']);
        
        final tipo = item['tipo'] as String? ?? 'NOTIFICACAO';
        final isMulta = tipo == 'MULTA';
        
        final typeColor = isMulta ? Colors.red : Colors.orange;
        final typeBgColor = isMulta ? Colors.red.shade50 : Colors.orange.shade50;
        final typeIcon = isMulta ? Icons.warning_amber_rounded : Icons.notifications;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _toggleExpandAndMarkAsRead(item),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: typeBgColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(typeIcon, color: typeColor, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: typeBgColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: typeColor.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    tipo,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: typeColor,
                                    ),
                                  ),
                                ),
                                if (!isLida) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.blue.shade200),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            color: Colors.blue,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Text(
                                          'Não Lida',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item['titulo'] ?? '',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isLida ? Colors.grey.shade700 : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ocorrência: ${DateFormat('dd MMM yyyy').format(occDate)}',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
                if (isExpanded) ...[
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Detalhes',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            item['descricao']?.isEmpty ?? true 
                                ? 'Nenhuma descrição fornecida.' 
                                : item['descricao'],
                            style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (item['anexo_url'] != null)
                              TextButton.icon(
                                onPressed: () {
                                  _handleDownload(item['anexo_url']);
                                },
                                icon: const Icon(Icons.file_download, size: 18),
                                label: const Text('Baixar Anexo'),
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.blue.shade50,
                                  foregroundColor: Colors.blue.shade700,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              )
                            else
                              const Text('Sem anexos', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                            
                            if (item['lido_em'] != null)
                              Text(
                                'Lido em ${DateFormat('dd/MM HH:mm').format(DateTime.parse(item['lido_em']))}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
