import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/fornecedor.dart';

class FornecedorSelectionResult {
  final String? fornecedorId;
  final String? fornecedorNome;
  final Fornecedor? fornecedorCompleto;

  const FornecedorSelectionResult({
    this.fornecedorId,
    this.fornecedorNome,
    this.fornecedorCompleto,
  });

  bool get isCadastrado => fornecedorId != null;
  bool get isAvulso => fornecedorId == null && fornecedorNome != null && fornecedorNome!.isNotEmpty;
}

class FornecedorBottomSheet extends StatefulWidget {
  final String condominioId;
  final String? selectedFornecedorId;
  final String? initialFornecedorNomeAvulso;

  const FornecedorBottomSheet({
    super.key,
    required this.condominioId,
    this.selectedFornecedorId,
    this.initialFornecedorNomeAvulso,
  });

  static Future<FornecedorSelectionResult?> show({
    required BuildContext context,
    required String condominioId,
    String? selectedFornecedorId,
    String? initialFornecedorNomeAvulso,
  }) {
    return showModalBottomSheet<FornecedorSelectionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FornecedorBottomSheet(
        condominioId: condominioId,
        selectedFornecedorId: selectedFornecedorId,
        initialFornecedorNomeAvulso: initialFornecedorNomeAvulso,
      ),
    );
  }

  @override
  State<FornecedorBottomSheet> createState() => _FornecedorBottomSheetState();
}

class _FornecedorBottomSheetState extends State<FornecedorBottomSheet> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  final _avulsoController = TextEditingController();

  List<Fornecedor> _fornecedores = [];
  bool _isLoading = true;
  String? _error;
  bool _isAvulsoMode = false;

  @override
  void initState() {
    super.initState();
    if (widget.selectedFornecedorId == null &&
        widget.initialFornecedorNomeAvulso != null &&
        widget.initialFornecedorNomeAvulso!.isNotEmpty) {
      _isAvulsoMode = true;
      _avulsoController.text = widget.initialFornecedorNomeAvulso!;
    }
    _loadFornecedores();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _avulsoController.dispose();
    super.dispose();
  }

  Future<void> _loadFornecedores() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await _supabase
          .from('fornecedores')
          .select('*')
          .eq('condominio_id', widget.condominioId)
          .eq('ativo', true)
          .order('nome');

      final list = (res as List)
          .map((m) => Fornecedor.fromMap(m as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _fornecedores = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao carregar fornecedores: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<Fornecedor> get _filteredFornecedores {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _fornecedores;
    return _fornecedores.where((f) {
      return f.nome.toLowerCase().contains(q) ||
          (f.documento?.toLowerCase().contains(q) ?? false) ||
          (f.telefone?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Future<void> _showQuickCreateDialog() async {
    final nomeCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    final docCtrl = TextEditingController();
    String tipo = 'Pessoa Jurídica';
    bool saving = false;
    String? dialogError;

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.business_rounded, color: Color(0xFFFC5931)),
              SizedBox(width: 8),
              Text(
                'Novo Fornecedor',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (dialogError != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      dialogError!,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                    ),
                  ),
                const Text(
                  'Nome / Razão Social *',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: nomeCtrl,
                  decoration: InputDecoration(
                    hintText: 'Ex: Atlas Schindler Elevadores',
                    hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tipo',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: tipo,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Pessoa Jurídica', child: Text('Pessoa Jurídica')),
                    DropdownMenuItem(value: 'Pessoa Física', child: Text('Pessoa Física')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => tipo = val);
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'Telefone',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: telCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: '(11) 98888-7777',
                    hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'CNPJ / CPF',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: docCtrl,
                  decoration: InputDecoration(
                    hintText: '00.000.000/0001-00',
                    hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final nome = nomeCtrl.text.trim();
                      if (nome.isEmpty) {
                        setDialogState(() => dialogError = 'Informe o nome do fornecedor.');
                        return;
                      }

                      setDialogState(() {
                        saving = true;
                        dialogError = null;
                      });

                      try {
                        final insertRes = await _supabase
                            .from('fornecedores')
                            .insert({
                              'condominio_id': widget.condominioId,
                              'nome': nome,
                              'tipo': tipo,
                              'telefone': telCtrl.text.trim().isEmpty ? null : telCtrl.text.trim(),
                              'documento': docCtrl.text.trim().isEmpty ? null : docCtrl.text.trim(),
                              'ativo': true,
                            })
                            .select()
                            .single();

                        final novo = Fornecedor.fromMap(insertRes);

                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        if (mounted) {
                          Navigator.pop(
                            context,
                            FornecedorSelectionResult(
                              fornecedorId: novo.id,
                              fornecedorNome: novo.nome,
                              fornecedorCompleto: novo,
                            ),
                          );
                        }
                      } catch (err) {
                        setDialogState(() {
                          saving = false;
                          dialogError = 'Erro: $err';
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFC5931),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Cadastrar e Selecionar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.handshake_outlined, color: Color(0xFFFC5931), size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Selecionar Fornecedor',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isAvulsoMode = !_isAvulsoMode;
                      });
                    },
                    child: Text(
                      _isAvulsoMode ? 'Ver Lista' : 'Fornecedor Avulso',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFC5931),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Modo Avulso
            if (_isAvulsoMode)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nome do Fornecedor / Prestador Avulso',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _avulsoController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Ex: João Eletricista, BioPrag, etc.',
                        hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFFC5931), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          final text = _avulsoController.text.trim();
                          if (text.isEmpty) return;
                          Navigator.pop(
                            context,
                            FornecedorSelectionResult(
                              fornecedorId: null,
                              fornecedorNome: text,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFC5931),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Confirmar Fornecedor Avulso', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              // Barra de Busca
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nome, documento...',
                    hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                ),
              ),

              // Lista de Fornecedores
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFFC5931)))
                    : _error != null
                        ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)))
                        : _filteredFornecedores.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.business_outlined, size: 40, color: Colors.grey.shade300),
                                    const SizedBox(height: 8),
                                    const Text('Nenhum fornecedor encontrado', style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: _filteredFornecedores.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (ctx, idx) {
                                  final f = _filteredFornecedores[idx];
                                  final isSelected = f.id == widget.selectedFornecedorId;

                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    leading: CircleAvatar(
                                      backgroundColor: isSelected ? const Color(0xFFFC5931) : const Color(0xFFFFF2EE),
                                      child: Icon(
                                        f.tipo == 'Pessoa Jurídica' ? Icons.business_rounded : Icons.person_rounded,
                                        color: isSelected ? Colors.white : const Color(0xFFFC5931),
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(
                                      f.nome,
                                      style: TextStyle(
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        color: isSelected ? const Color(0xFFFC5931) : const Color(0xFF1F2937),
                                        fontSize: 14,
                                      ),
                                    ),
                                    subtitle: Text(
                                      [
                                        if (f.telefone != null) '📞 ${f.telefone}',
                                        if (f.documento != null) 'Doc: ${f.documento}',
                                      ].join(' • '),
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                    trailing: isSelected
                                        ? const Icon(Icons.check_circle_rounded, color: Color(0xFFFC5931), size: 22)
                                        : null,
                                    onTap: () {
                                      Navigator.pop(
                                        context,
                                        FornecedorSelectionResult(
                                          fornecedorId: f.id,
                                          fornecedorNome: f.nome,
                                          fornecedorCompleto: f,
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
              ),

              // Rodapé: Botão de Novo Fornecedor
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: OutlinedButton.icon(
                    onPressed: _showQuickCreateDialog,
                    icon: const Icon(Icons.add_business_rounded, size: 18),
                    label: const Text('+ Cadastrar Novo Fornecedor', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFC5931),
                      side: const BorderSide(color: Color(0xFFFC5931)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
