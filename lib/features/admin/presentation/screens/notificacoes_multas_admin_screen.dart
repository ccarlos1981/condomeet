import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class NotificacoesMultasAdminScreen extends StatefulWidget {
  const NotificacoesMultasAdminScreen({super.key});

  @override
  State<NotificacoesMultasAdminScreen> createState() => _NotificacoesMultasAdminScreenState();
}

class _NotificacoesMultasAdminScreenState extends State<NotificacoesMultasAdminScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _historico = [];

  final List<String> _ocorrenciasOpcoes = [
    'Outras infrações da convenção sem multa',
    'Notificação financeira',
    'Outras infrações da convenção com multa',
    'Convivência: infração da convenção sem multa',
    'Convivência: infração da convenção com multa',
    'Obra: infração da convenção sem multa',
    'Obra: infração da convenção com multa',
    'Outros...'
  ];

  @override
  void initState() {
    super.initState();
    _loadHistorico();
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

  Future<void> _loadHistorico() async {
    try {
      final condoId = await _getCondoId();
      if (condoId == null) return;

      final data = await _supabase
          .from('notificacoes_multas')
          .select('''
            id, tipo, titulo, descricao, anexo_url, lido_em, data_ocorrencia, created_at, status,
            unidades ( blocos (nome_ou_numero), apartamentos(numero) )
          ''')
          .eq('condominio_id', condoId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _historico = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      debugPrint('Erro ao carregar historico: $e');
    }
  }

  Future<void> _deleteRegistro(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir registro?'),
        content: const Text('Tem certeza que deseja excluir esta notificação/multa?'),
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
      await _supabase.from('notificacoes_multas').delete().eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ Registro excluído'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadHistorico();
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

  Future<void> _downloadAnexo(String anexoUrl) async {
    try {
      final signedUrl = await _supabase.storage.from('documentos').createSignedUrl(anexoUrl, 60);
      final uri = Uri.parse(signedUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Não foi possível abrir a URL.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro ao abrir anexo: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _abrirFormulario() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _FormularioMultaBottomSheet(
          ocorrenciasOpcoes: _ocorrenciasOpcoes,
          onSuccess: _loadHistorico,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text(
          'Multas e Notificações',
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
          onRefresh: _loadHistorico,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              // Botão para inserir nova multa ou notificação
              InkWell(
                onTap: _abrirFormulario,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFC5931),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Insira multa ou notificação',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              if (_loading)
                const Center(child: CircularProgressIndicator(color: AppColors.primary))
              else if (_historico.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'Nenhum registro encontrado.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ..._historico.map(_buildCardItem),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardItem(Map<String, dynamic> item) {
    final dtStr = item['data_ocorrencia'] as String?;
    String dateFormatted = '-';
    if (dtStr != null) {
      final dt = DateTime.parse(dtStr).toLocal();
      dateFormatted = DateFormat('MMM d, yyyy h:mm a').format(dt);
    }

    final unidades = item['unidades'] as Map<String, dynamic>?;
    final bloco = unidades?['blocos']?['nome_ou_numero'] ?? '';
    final apto = unidades?['apartamentos']?['numero'] ?? '';

    final lido = item['lido_em'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 88.0), // Reserved space for action buttons
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRow('Tipo:', item['tipo'] ?? ''),
                const SizedBox(height: 8),
                _buildRow('Data:', dateFormatted),
                const SizedBox(height: 8),
                _buildRow('Bloco:', bloco),
                const SizedBox(height: 8),
                _buildRow('Unidade:', apto),
                const SizedBox(height: 8),
                _buildRow('Ocorrência:', item['titulo'] ?? ''),
                if (item['descricao'] != null && item['descricao'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildRow('Descrição:', item['descricao']),
                ],
                if (item['anexo_url'] != null) ...[
                  const SizedBox(height: 8),
                  _buildRow('Doc enviado:', 'Documento Anexado'),
                ],
                const SizedBox(height: 12),
                Text(
                  lido ? 'Documento Lido' : 'Documento não Lido',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: lido ? Colors.green.shade600 : Colors.red.shade500,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: Row(
                children: [
                  if (item['anexo_url'] != null)
                    IconButton(
                      icon: const Icon(Icons.file_present_rounded, color: Color(0xFFFC5931), size: 32),
                      onPressed: () => _downloadAnexo(item['anexo_url']),
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 32),
                    onPressed: () => _deleteRegistro(item['id']),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
            ),
          ),
        ),
      ],
    );
  }
}

class _FormularioMultaBottomSheet extends StatefulWidget {
  final List<String> ocorrenciasOpcoes;
  final VoidCallback onSuccess;

  const _FormularioMultaBottomSheet({
    required this.ocorrenciasOpcoes,
    required this.onSuccess,
  });

  @override
  State<_FormularioMultaBottomSheet> createState() => _FormularioMultaBottomSheetState();
}

class _FormularioMultaBottomSheetState extends State<_FormularioMultaBottomSheet> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  bool _isSending = false;
  String _formTipo = 'NOTIFICACAO';
  DateTime? _formData;
  
  List<Map<String, dynamic>> _unidadesDisponiveis = [];
  List<String> _blocosNomes = [];
  List<Map<String, dynamic>> _aptosDisponiveis = [];

  String? _selectedBloco;
  Map<String, dynamic>? _selectedApto; // contem a unidade_id

  String? _formOcorrencia;
  final _descricaoController = TextEditingController();

  File? _file;
  String? _fileName;

  @override
  void initState() {
    super.initState();
    _loadUnidades();
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    super.dispose();
  }

  Future<void> _loadUnidades() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      final profile = await _supabase.from('perfil').select('condominio_id').eq('id', user.id).maybeSingle();
      final condoId = profile?['condominio_id'];
      if (condoId == null) return;

      final data = await _supabase
          .from('unidades')
          .select('id, blocos(nome_ou_numero), apartamentos(numero)')
          .eq('condominio_id', condoId);

      final List<String> blocos = [];
      for (var u in data) {
        final blocoNome = u['blocos']?['nome_ou_numero'];
        if (blocoNome != null && !blocos.contains(blocoNome)) {
          blocos.add(blocoNome);
        }
      }
      blocos.sort();

      setState(() {
        _unidadesDisponiveis = List<Map<String, dynamic>>.from(data);
        _blocosNomes = blocos;
      });
    } catch (e) {
      debugPrint('Erro ao carregar unidades: $e');
    }
  }

  void _onBlocoChanged(String? novoBloco) {
    if (novoBloco == null) return;
    final aptos = _unidadesDisponiveis
        .where((u) => u['blocos']?['nome_ou_numero'] == novoBloco)
        .toList();
    
    // Sort aptos
    aptos.sort((a, b) {
      final numA = a['apartamentos']?['numero'] ?? '';
      final numB = b['apartamentos']?['numero'] ?? '';
      return numA.toString().compareTo(numB.toString());
    });

    setState(() {
      _selectedBloco = novoBloco;
      _selectedApto = null;
      _aptosDisponiveis = aptos;
    });
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _file = File(result.files.single.path!);
          _fileName = result.files.single.name;
        });
      }
    } catch (e) {
      debugPrint('Erro ao selecionar arquivo: $e');
    }
  }

  Future<void> _pickDate() async {
    final initialDate = _formData ?? DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      if (!mounted) return;
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
      );
      if (pickedTime != null) {
        setState(() {
          _formData = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate() || _selectedApto == null || _formData == null || _formOcorrencia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha os campos obrigatórios.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final user = _supabase.auth.currentUser;
      final profile = await _supabase.from('perfil').select('condominio_id').eq('id', user!.id).maybeSingle();
      final condoId = profile?['condominio_id'];

      String? uploadedPath;
      if (_file != null) {
        final ext = _fileName!.split('.').last;
        final name = 'notificacoes/${DateTime.now().millisecondsSinceEpoch}_${user.id.substring(0, 5)}.$ext';
        await _supabase.storage.from('documentos').upload(name, _file!);
        uploadedPath = name;
      }

      await _supabase.from('notificacoes_multas').insert({
        'condominio_id': condoId,
        'unidade_id': _selectedApto!['id'],
        'autor_id': user.id,
        'tipo': _formTipo,
        'titulo': _formOcorrencia,
        'descricao': _descricaoController.text,
        'data_ocorrencia': _formData!.toIso8601String(),
        'anexo_url': uploadedPath,
      });

      if (mounted) {
        Navigator.pop(context); // Fechar bottom sheet
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Salvo com sucesso! O morador será notificado.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro ao enviar: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      // Padding bottom responsivo ao teclado
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Insira a multa ou Infração',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Toggle Tipo
                RadioGroup<String>(
                  groupValue: _formTipo,
                  onChanged: (v) => setState(() => _formTipo = v!),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildRadio('NOTIFICACAO', 'Notificação'),
                      const SizedBox(width: 32),
                      _buildRadio('MULTA', 'Multa'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Data
                _buildFieldRow(
                  label: 'Data:',
                  child: InkWell(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _formData == null ? 'Selecionar' : DateFormat('dd/MM/yyyy HH:mm').format(_formData!),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Bloco
                _buildFieldRow(
                  label: 'Bloco:',
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedBloco,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    ),
                    hint: const Text('Selecione', style: TextStyle(fontSize: 14)),
                    items: _blocosNomes.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                    onChanged: _onBlocoChanged,
                  ),
                ),
                const SizedBox(height: 16),

                // Apto
                _buildFieldRow(
                  label: 'Apto:',
                  child: DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: _selectedApto,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    ),
                    hint: const Text('Selecione', style: TextStyle(fontSize: 14)),
                    items: _aptosDisponiveis.map((a) => DropdownMenuItem(value: a, child: Text(a['apartamentos']['numero'] ?? ''))).toList(),
                    onChanged: _selectedBloco == null ? null : (v) => setState(() => _selectedApto = v),
                    disabledHint: const Text('Selecione', style: TextStyle(fontSize: 14)),
                  ),
                ),
                const SizedBox(height: 16),

                // Documento
                _buildFieldRow(
                  label: 'Documento',
                  child: InkWell(
                    onTap: _pickFile,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _fileName ?? 'Clique para importar o Documento',
                        style: TextStyle(fontSize: 13, color: _fileName != null ? Colors.black87 : Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Ocorrencia
                const Text('Ocorrência:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _formOcorrencia,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  ),
                  hint: const Text('Motivo', style: TextStyle(fontSize: 14)),
                  items: widget.ocorrenciasOpcoes.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) => setState(() => _formOcorrencia = v),
                ),
                const SizedBox(height: 16),

                // Descrição
                const Text('Descrição:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descricaoController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Escreva aqui uma descrição',
                    hintStyle: const TextStyle(fontSize: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  ),
                  validator: (val) => val == null || val.isEmpty ? 'Informe uma descrição' : null,
                ),
                const SizedBox(height: 24),

                // Botões
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSending ? null : _enviar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFC5931),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        child: _isSending
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Enviar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade200,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        child: const Text('Cancelar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldRow({required String label, required Widget child}) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
        ),
        Expanded(child: child),
      ],
    );
  }

  Widget _buildRadio(String value, String label) {
    return InkWell(
      onTap: () => setState(() => _formTipo = value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<String>(
            value: value,
            activeColor: const Color(0xFFFC5931),
          ),
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
        ],
      ),
    );
  }
}
