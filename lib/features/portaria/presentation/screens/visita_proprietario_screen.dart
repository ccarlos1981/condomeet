import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';

class VisitaProprietarioScreen extends StatefulWidget {
  const VisitaProprietarioScreen({super.key});

  @override
  State<VisitaProprietarioScreen> createState() => _VisitaProprietarioScreenState();
}

class _VisitaProprietarioScreenState extends State<VisitaProprietarioScreen> {
  final _supabase = Supabase.instance.client;

  // Data
  List<Map<String, dynamic>> _visitas = [];
  bool _loading = true;
  int _totalCount = 0;
  int _page = 0;
  static const _pageSize = 15;

  // Filters
  String _filterTipo = 'todos'; // todos | entrada | saida
  String _filterBloco = '';
  String _filterApto = '';
  String _filterNome = '';
  late String _filterData;
  bool _showFilters = false;

  // BlocoApto data
  List<String> _blocos = [];
  Map<String, List<String>> _aptosMap = {};
  Map<String, List<Map<String, String>>> _moradoresMap = {};

  // Stats
  int _countEntrada = 0;
  int _countSaida = 0;

  String? _condoId;
  String? _userId;
  String? _tipoEstrutura;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _filterData = DateFormat('yyyy-MM-dd').format(now);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthBloc>().state;
      _condoId = authState.condominiumId;
      _userId = authState.userId;
      _loadStructureData();
      _fetchVisitas();
    });
  }

  Future<void> _loadStructureData() async {
    if (_condoId == null) return;

    // Get tipo_estrutura
    final condo = await _supabase
        .from('condominios')
        .select('tipo_estrutura')
        .eq('id', _condoId!)
        .maybeSingle();
    _tipoEstrutura = condo?['tipo_estrutura'];

    // Natural numeric sort
    int numericCompare(String a, String b) {
      final na = int.tryParse(a);
      final nb = int.tryParse(b);
      if (na != null && nb != null) return na.compareTo(nb);
      return a.compareTo(b);
    }

    // Get blocos from 'blocos' table (nome_ou_numero column)
    final blocosRes = await _supabase
        .from('blocos')
        .select('nome_ou_numero')
        .eq('condominio_id', _condoId!)
        .gt('nome_ou_numero', '0');

    final blocos = (blocosRes as List)
        .map((b) => b['nome_ou_numero'] as String? ?? '')
        .where((b) => b.isNotEmpty)
        .toSet()
        .toList()
      ..sort(numericCompare);

    // Get aptos from 'apartamentos' table (numero column)
    final aptosRes = await _supabase
        .from('apartamentos')
        .select('numero')
        .eq('condominio_id', _condoId!)
        .gt('numero', '0');

    final aptos = (aptosRes as List)
        .map((a) => a['numero'] as String? ?? '')
        .where((a) => a.isNotEmpty)
        .toSet()
        .toList()
      ..sort(numericCompare);

    final aptosMap = <String, List<String>>{};
    for (final bloco in blocos) {
      aptosMap[bloco] = aptos; // all aptos available for all blocos
    }

    // Get moradores per unit
    final moradoresMap = <String, List<Map<String, String>>>{};
    final moradores = await _supabase
        .from('perfil')
        .select('id, nome_completo, bloco_txt, apto_txt')
        .eq('condominio_id', _condoId!)
        .eq('status_aprovacao', 'aprovado');
    
    for (final m in moradores) {
      final key = '${m['bloco_txt']}|${m['apto_txt']}';
      moradoresMap.putIfAbsent(key, () => []);
      moradoresMap[key]!.add({
        'id': m['id'] as String,
        'nome': m['nome_completo'] as String? ?? 'Sem nome',
      });
    }

    if (mounted) {
      setState(() {
        _blocos = blocos;
        _aptosMap = aptosMap;
        _moradoresMap = moradoresMap;
      });
    }
  }

  Future<void> _fetchVisitas() async {
    if (_condoId == null) return;
    setState(() => _loading = true);

    final from = _page * _pageSize;
    final to = from + _pageSize - 1;

    // Build filter for data query
    var dataQuery = _supabase
        .from('visita_proprietario')
        .select('*')
        .eq('condominio_id', _condoId!);

    // Build separate count query
    var countQuery = _supabase
        .from('visita_proprietario')
        .select('id')
        .eq('condominio_id', _condoId!);

    if (_filterTipo != 'todos') {
      dataQuery = dataQuery.eq('tipo', _filterTipo);
      countQuery = countQuery.eq('tipo', _filterTipo);
    }
    if (_filterBloco.isNotEmpty) {
      dataQuery = dataQuery.eq('bloco', _filterBloco);
      countQuery = countQuery.eq('bloco', _filterBloco);
    }
    if (_filterApto.isNotEmpty) {
      dataQuery = dataQuery.eq('apto', _filterApto);
      countQuery = countQuery.eq('apto', _filterApto);
    }
    if (_filterNome.isNotEmpty) {
      dataQuery = dataQuery.ilike('nome_morador', '%$_filterNome%');
      countQuery = countQuery.ilike('nome_morador', '%$_filterNome%');
    }
    if (_filterData.isNotEmpty) {
      dataQuery = dataQuery
          .gte('created_at', '${_filterData}T00:00:00')
          .lte('created_at', '${_filterData}T23:59:59');
      countQuery = countQuery
          .gte('created_at', '${_filterData}T00:00:00')
          .lte('created_at', '${_filterData}T23:59:59');
    }

    // Apply order + range after filters
    final data = await dataQuery
        .order('created_at', ascending: false)
        .range(from, to);
    final countData = await countQuery;
    final count = (countData as List).length;

    // Calculate entry/exit counts from fetched data
    int entrada = 0;
    int saida = 0;
    for (final v in data) {
      if (v['tipo'] == 'entrada') entrada++;
      if (v['tipo'] == 'saida') saida++;
    }

    if (mounted) {
      setState(() {
        _visitas = List<Map<String, dynamic>>.from(data);
        _totalCount = count;
        _countEntrada = entrada;
        _countSaida = saida;
        _loading = false;
      });
    }
  }

  String get _blocoLabel {
    if (_tipoEstrutura == 'horizontal') return 'Rua';
    if (_tipoEstrutura == 'comercial') return 'Sala';
    return 'Bloco';
  }

  String get _aptoLabel {
    if (_tipoEstrutura == 'horizontal') return 'Casa';
    if (_tipoEstrutura == 'comercial') return 'Sala';
    return 'Apto';
  }

  void _showRegistrationModal() {
    String modalTipo = 'entrada';
    String modalBloco = '';
    String modalApto = '';
    String? modalMoradorId;
    String modalNome = '';
    String modalCracha = '';
    String? error;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          final availableAptos = modalBloco.isNotEmpty ? (_aptosMap[modalBloco] ?? []) : <String>[];
          final unitKey = '$modalBloco|$modalApto';
          final unitMoradores = _moradoresMap[unitKey] ?? [];

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Row(
                      children: [
                        const Text('Registrar Visita',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: const Icon(Icons.close, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tipo: Entrada / Saída
                        const Text('Tipo de Registro', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setModalState(() => modalTipo = 'entrada'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    color: modalTipo == 'entrada' ? Colors.green.shade50 : Colors.grey.shade50,
                                    border: Border.all(
                                      color: modalTipo == 'entrada' ? Colors.green : Colors.grey.shade300,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.login, color: modalTipo == 'entrada' ? Colors.green.shade700 : Colors.grey, size: 20),
                                      const SizedBox(width: 8),
                                      Text('Entrada',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: modalTipo == 'entrada' ? Colors.green.shade700 : Colors.grey,
                                          )),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setModalState(() => modalTipo = 'saida'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    color: modalTipo == 'saida' ? Colors.orange.shade50 : Colors.grey.shade50,
                                    border: Border.all(
                                      color: modalTipo == 'saida' ? Colors.orange : Colors.grey.shade300,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.logout, color: modalTipo == 'saida' ? Colors.orange.shade700 : Colors.grey, size: 20),
                                      const SizedBox(width: 8),
                                      Text('Saída',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: modalTipo == 'saida' ? Colors.orange.shade700 : Colors.grey,
                                          )),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Bloco / Apto
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('$_blocoLabel *', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  const SizedBox(height: 4),
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: modalBloco.isEmpty ? null : modalBloco,
                                        hint: const Text('Selecione', style: TextStyle(fontSize: 14)),
                                        isExpanded: true,
                                        items: _blocos.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                                        onChanged: (v) {
                                          setModalState(() {
                                            modalBloco = v ?? '';
                                            modalApto = '';
                                            modalMoradorId = null;
                                            modalNome = '';
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('$_aptoLabel *', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  const SizedBox(height: 4),
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: modalApto.isEmpty ? null : modalApto,
                                        hint: const Text('Selecione', style: TextStyle(fontSize: 14)),
                                        isExpanded: true,
                                        items: availableAptos.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                                        onChanged: modalBloco.isEmpty
                                            ? null
                                            : (v) {
                                                setModalState(() {
                                                  modalApto = v ?? '';
                                                  modalMoradorId = null;
                                                  modalNome = '';
                                                });
                                              },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Moradores da unidade
                        if (modalBloco.isNotEmpty && modalApto.isNotEmpty && unitMoradores.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text('Moradores desta unidade', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: unitMoradores.map((m) {
                              final isSelected = modalMoradorId == m['id'];
                              return GestureDetector(
                                onTap: () {
                                  setModalState(() {
                                    modalMoradorId = m['id'];
                                    modalNome = m['nome'] ?? '';
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.grey.shade50,
                                    border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(isSelected ? '✅ ' : '👤 ', style: const TextStyle(fontSize: 14)),
                                      Flexible(
                                        child: Text(
                                          m['nome'] ?? '',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                            color: isSelected ? AppColors.primary : Colors.grey.shade700,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Nome manual
                        Text(
                          'Nome do morador *${unitMoradores.isNotEmpty ? " (ou digite manualmente)" : ""}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        TextFormField(
                          initialValue: modalNome,
                          onChanged: (v) {
                            modalNome = v;
                            modalMoradorId = null;
                          },
                          decoration: InputDecoration(
                            hintText: 'Nome do morador',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Crachá
                        const Text('Crachá / Referência (opcional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 4),
                        TextFormField(
                          initialValue: modalCracha,
                          onChanged: (v) => modalCracha = v,
                          decoration: InputDecoration(
                            hintText: 'Nº do crachá ou referência',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),

                        // Error
                        if (error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
                                const SizedBox(width: 8),
                                Expanded(child: Text(error!, style: TextStyle(color: Colors.red.shade700, fontSize: 13))),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Submit
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: saving
                                ? null
                                : () async {
                                    if (modalNome.trim().isEmpty) {
                                      setModalState(() => error = 'Informe o nome do morador.');
                                      return;
                                    }
                                    if (modalBloco.isEmpty || modalApto.isEmpty) {
                                      setModalState(() => error = 'Selecione o $_blocoLabel e o $_aptoLabel.');
                                      return;
                                    }
                                    setModalState(() {
                                      error = null;
                                      saving = true;
                                    });

                                    await _supabase.from('visita_proprietario').insert({
                                      'condominio_id': _condoId,
                                      'tipo': modalTipo,
                                      'morador_id': modalMoradorId,
                                      'nome_morador': modalNome.trim(),
                                      'bloco': modalBloco,
                                      'apto': modalApto,
                                      'cracha_referencia': modalCracha.trim().isEmpty ? null : modalCracha.trim(),
                                      'registrado_por': _userId,
                                    });

                                    // Fire-and-forget push notification
                                    try {
                                      await _supabase.functions.invoke('visita-proprietario-push-notify', body: {
                                        'condominio_id': _condoId,
                                        'bloco': modalBloco,
                                        'apto': modalApto,
                                        'tipo': modalTipo,
                                        'nome_morador': modalNome.trim(),
                                      });
                                    } catch (_) {}

                                    if (mounted) {
                                      Navigator.pop(ctx);
                                      _fetchVisitas();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('${modalTipo == 'entrada' ? 'Entrada' : 'Saída'} registrada com sucesso!'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: modalTipo == 'entrada' ? Colors.green.shade600 : Colors.orange.shade600,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: saving
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(modalTipo == 'entrada' ? Icons.login : Icons.logout, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Registrar ${modalTipo == 'entrada' ? 'Entrada' : 'Saída'}',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (_totalCount / _pageSize).ceil().clamp(1, 9999);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('🚪 Visita Proprietário', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showRegistrationModal,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Registrar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchVisitas,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            // ── Stats Cards ──
            Row(
              children: [
                _statCard('Total', _totalCount.toString(), Colors.grey.shade700, Colors.grey.shade100),
                const SizedBox(width: 8),
                _statCard('Entradas', _countEntrada.toString(), Colors.green.shade700, Colors.green.shade50, Icons.login),
                const SizedBox(width: 8),
                _statCard('Saídas', _countSaida.toString(), Colors.orange.shade700, Colors.orange.shade50, Icons.logout),
              ],
            ),

            const SizedBox(height: 16),

            // ── Tipo Filter Tabs ──
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  _filterTab('Todos', 'todos', Icons.people),
                  _filterTab('Entrada', 'entrada', Icons.login),
                  _filterTab('Saída', 'saida', Icons.logout),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Expandable Filters ──
            GestureDetector(
              onTap: () => setState(() => _showFilters = !_showFilters),
              child: Row(
                children: [
                  Icon(Icons.filter_list, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text('Filtros', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey.shade600)),
                  Icon(_showFilters ? Icons.expand_less : Icons.expand_more, size: 18, color: Colors.grey.shade600),
                ],
              ),
            ),

            if (_showFilters) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _dropdownFilter(_blocoLabel, _filterBloco, _blocos, (v) {
                            setState(() {
                              _filterBloco = v ?? '';
                              _filterApto = '';
                              _page = 0;
                            });
                            _fetchVisitas();
                          }),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _dropdownFilter(
                            _aptoLabel,
                            _filterApto,
                            _filterBloco.isNotEmpty ? (_aptosMap[_filterBloco] ?? []) : [],
                            (v) {
                              setState(() {
                                _filterApto = v ?? '';
                                _page = 0;
                              });
                              _fetchVisitas();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            onChanged: (v) {
                              _filterNome = v;
                              _page = 0;
                              _fetchVisitas();
                            },
                            decoration: InputDecoration(
                              hintText: 'Buscar nome...',
                              prefixIcon: const Icon(Icons.search, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.tryParse(_filterData) ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 1)),
                              );
                              if (picked != null) {
                                setState(() {
                                  _filterData = DateFormat('yyyy-MM-dd').format(picked);
                                  _page = 0;
                                });
                                _fetchVisitas();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _filterData.isNotEmpty
                                          ? DateFormat('dd/MM/yyyy').format(DateTime.parse(_filterData))
                                          : 'Data',
                                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // ── Visitas List ──
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            else if (_visitas.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    Text('🚪', style: TextStyle(fontSize: 40)),
                    SizedBox(height: 8),
                    Text('Nenhum registro encontrado', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                    SizedBox(height: 4),
                    Text('Registre a primeira entrada ou saída', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              )
            else
              ..._visitas.map((v) => _visitaCard(v)),

            // ── Pagination ──
            if (_totalCount > _pageSize) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_page * _pageSize + 1}–${((_page + 1) * _pageSize).clamp(0, _totalCount)} de $_totalCount',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _page > 0
                            ? () {
                                setState(() => _page--);
                                _fetchVisitas();
                              }
                            : null,
                        child: const Text('← Anterior'),
                      ),
                      Text('${_page + 1} / $totalPages', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                      TextButton(
                        onPressed: _page < totalPages - 1
                            ? () {
                                setState(() => _page++);
                                _fetchVisitas();
                              }
                            : null,
                        child: const Text('Próximo →'),
                      ),
                    ],
                  ),
                ],
              ),
            ],

            const SizedBox(height: 80), // space for FAB
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, Color textColor, Color bgColor, [IconData? icon]) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: textColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 12, color: textColor),
                  const SizedBox(width: 4),
                ],
                Text(label, style: TextStyle(fontSize: 11, color: textColor, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterTab(String label, String tipo, IconData icon) {
    final isActive = _filterTipo == tipo;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _filterTipo = tipo;
            _page = 0;
          });
          _fetchVisitas();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isActive ? AppColors.primary : Colors.grey),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isActive ? AppColors.primary : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dropdownFilter(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value.isEmpty ? null : value,
              hint: const Text('Todos', style: TextStyle(fontSize: 13)),
              isExpanded: true,
              isDense: true,
              items: [
                const DropdownMenuItem(value: '', child: Text('Todos', style: TextStyle(fontSize: 13))),
                ...items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 13)))),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _visitaCard(Map<String, dynamic> v) {
    final isEntrada = v['tipo'] == 'entrada';
    final dt = DateTime.tryParse(v['created_at'] ?? '');
    final timeStr = dt != null ? DateFormat('HH:mm').format(dt.toLocal()) + 'h' : '';
    final dateStr = dt != null ? DateFormat('dd/MM/yyyy').format(dt.toLocal()) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          // Type badge
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isEntrada ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isEntrada ? Icons.login : Icons.logout,
              color: isEntrada ? Colors.green.shade600 : Colors.orange.shade600,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        v['nome_morador'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isEntrada ? Colors.green.shade100 : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isEntrada ? 'ENTRADA' : 'SAÍDA',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isEntrada ? Colors.green.shade700 : Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$_blocoLabel ${v['bloco'] ?? '–'} / $_aptoLabel ${v['apto'] ?? '–'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),

          // Crachá
          if (v['cracha_referencia'] != null && (v['cracha_referencia'] as String).isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                border: Border.all(color: Colors.amber.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text('🪪', style: const TextStyle(fontSize: 14)),
                  Text(
                    v['cracha_referencia'],
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.amber.shade800),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(width: 8),

          // Time
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(timeStr, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
              Text(dateStr, style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
            ],
          ),
        ],
      ),
    );
  }
}
