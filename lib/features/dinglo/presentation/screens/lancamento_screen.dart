import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../dinglo_theme.dart';

class LancamentoScreen extends StatefulWidget {
  const LancamentoScreen({super.key});
  @override
  State<LancamentoScreen> createState() => _LancamentoScreenState();
}

class _LancamentoScreenState extends State<LancamentoScreen> {
  final _supabase = Supabase.instance.client;
  String _tipo = 'despesa';
  final _descricaoCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();
  DateTime _dataLancamento = DateTime.now();
  String? _contaId;
  String? _cartaoId;
  String? _categoriaId;
  int _parcelas = 1;
  bool _saving = false;

  List<Map<String, dynamic>> _contas = [];
  List<Map<String, dynamic>> _cartoes = [];
  List<Map<String, dynamic>> _categorias = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _descricaoCtrl.dispose();
    _valorCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final userId = _supabase.auth.currentUser!.id;
    final results = await Future.wait([
      _supabase.from('dinglo_contas').select().eq('user_id', userId).eq('ativo', true).order('banco'),
      _supabase.from('dinglo_cartoes').select().eq('user_id', userId).eq('ativo', true).order('nome'),
      _supabase.from('dinglo_categorias').select().or('user_id.eq.$userId,is_default.eq.true').order('nome'),
    ]);
    if (mounted) {
      setState(() {
        _contas = List<Map<String, dynamic>>.from(results[0]);
        _cartoes = List<Map<String, dynamic>>.from(results[1]);
        _categorias = List<Map<String, dynamic>>.from(results[2]);
      });
    }
  }

  Future<void> _save() async {
    final valor = double.tryParse(_valorCtrl.text.replaceAll(',', '.'));
    if (valor == null || valor <= 0 || _descricaoCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha descrição e valor'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      final dataStr = _dataLancamento.toIso8601String().split('T')[0];

      if (_parcelas > 1) {
        // Create installments
        final grupoId = DateTime.now().millisecondsSinceEpoch.toString();
        final valorParcela = (valor / _parcelas * 100).round() / 100;
        final inserts = List.generate(_parcelas, (i) => {
          'user_id': userId,
          'tipo': _tipo,
          'descricao': '${_descricaoCtrl.text} (${i + 1}/$_parcelas)',
          'valor': valorParcela,
          'data_lancamento': DateTime(_dataLancamento.year, _dataLancamento.month + i, _dataLancamento.day).toIso8601String().split('T')[0],
          'conta_id': _contaId,
          'cartao_id': _cartaoId,
          'categoria_id': _categoriaId,
          'parcela_atual': i + 1,
          'parcela_total': _parcelas,
          'parcela_grupo_id': grupoId,
          'status': i == 0 ? 'realizado' : 'pendente',
        });
        await _supabase.from('dinglo_lancamentos').insert(inserts);
      } else {
        await _supabase.from('dinglo_lancamentos').insert({
          'user_id': userId,
          'tipo': _tipo,
          'descricao': _descricaoCtrl.text,
          'valor': valor,
          'data_lancamento': dataStr,
          'conta_id': _contaId,
          'cartao_id': _cartaoId,
          'categoria_id': _categoriaId,
          'status': 'realizado',
        });
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataLancamento,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: DingloTheme.primary)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dataLancamento = picked);
  }

  @override
  Widget build(BuildContext context) {
    final filteredCats = _categorias.where((c) => c['tipo'] == _tipo).toList();

    return Scaffold(
      backgroundColor: DingloTheme.background,
      appBar: AppBar(
        backgroundColor: _tipo == 'receita' ? DingloTheme.income : DingloTheme.expense,
        foregroundColor: Colors.white,
        title: Text(_tipo == 'receita' ? 'Nova Receita' : 'Nova Despesa', style: const TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type toggle
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: DingloTheme.buttonRadius,
                boxShadow: DingloTheme.cardShadow,
              ),
              child: Row(
                children: [
                  Expanded(child: _buildTypeBtn('despesa', 'Despesa', Icons.arrow_downward_rounded, DingloTheme.expense)),
                  Expanded(child: _buildTypeBtn('receita', 'Receita', Icons.arrow_upward_rounded, DingloTheme.income)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Value
            const Text('Valor', style: DingloTheme.heading3),
            const SizedBox(height: 8),
            TextField(
              controller: _valorCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                fontSize: 32, fontWeight: FontWeight.w800,
                color: _tipo == 'receita' ? DingloTheme.income : DingloTheme.expense,
              ),
              decoration: InputDecoration(
                prefixText: 'R\$ ',
                prefixStyle: TextStyle(
                  fontSize: 32, fontWeight: FontWeight.w800,
                  color: _tipo == 'receita' ? DingloTheme.income : DingloTheme.expense,
                ),
                hintText: '0,00',
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: DingloTheme.inputRadius, borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            const Text('Descrição', style: DingloTheme.heading3),
            const SizedBox(height: 8),
            TextField(
              controller: _descricaoCtrl,
              decoration: InputDecoration(
                hintText: 'Ex: Almoço no restaurante',
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: DingloTheme.inputRadius, borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),

            // Date
            const Text('Data', style: DingloTheme.heading3),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: DingloTheme.inputRadius,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, color: DingloTheme.primary, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      '${_dataLancamento.day.toString().padLeft(2, '0')}/${_dataLancamento.month.toString().padLeft(2, '0')}/${_dataLancamento.year}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Category
            if (filteredCats.isNotEmpty) ...[
              const Text('Categoria', style: DingloTheme.heading3),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: filteredCats.map((cat) {
                  final selected = _categoriaId == cat['id'];
                  return GestureDetector(
                    onTap: () => setState(() => _categoriaId = cat['id']),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? DingloTheme.parseColor(cat['cor']).withValues(alpha: 0.15) : Colors.white,
                        borderRadius: DingloTheme.chipRadius,
                        border: Border.all(color: selected ? DingloTheme.parseColor(cat['cor']) : Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(DingloTheme.getIcon(cat['icone']), size: 16, color: DingloTheme.parseColor(cat['cor'])),
                          const SizedBox(width: 6),
                          Text(cat['nome'], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? DingloTheme.parseColor(cat['cor']) : DingloTheme.textSecondary)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Account or Card
            if (_contas.isNotEmpty) ...[
              const Text('Conta', style: DingloTheme.heading3),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _contaId,
                hint: const Text('Selecione a conta'),
                decoration: InputDecoration(
                  filled: true, fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: DingloTheme.inputRadius, borderSide: BorderSide.none),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Nenhuma')),
                  ..._contas.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text('${c['banco']} - ${c['descricao'] ?? ''}'))),
                ],
                onChanged: (v) => setState(() { _contaId = v; _cartaoId = null; }),
              ),
              const SizedBox(height: 16),
            ],

            if (_tipo == 'despesa' && _cartoes.isNotEmpty) ...[
              const Text('Cartão de crédito', style: DingloTheme.heading3),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _cartaoId,
                hint: const Text('Selecione o cartão (opcional)'),
                decoration: InputDecoration(
                  filled: true, fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: DingloTheme.inputRadius, borderSide: BorderSide.none),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Nenhum (débito)')),
                  ..._cartoes.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['nome'] ?? ''))),
                ],
                onChanged: (v) => setState(() { _cartaoId = v; if (v != null) _contaId = null; }),
              ),
              const SizedBox(height: 16),
            ],

            // Installments (only for expenses)
            if (_tipo == 'despesa') ...[
              const Text('Parcelas', style: DingloTheme.heading3),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: _parcelas > 1 ? () => setState(() => _parcelas--) : null,
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                    color: DingloTheme.primary,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: DingloTheme.buttonRadius),
                    child: Text('${_parcelas}x', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: DingloTheme.primary)),
                  ),
                  IconButton(
                    onPressed: _parcelas < 48 ? () => setState(() => _parcelas++) : null,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    color: DingloTheme.primary,
                  ),
                  if (_parcelas > 1) ...[
                    const Spacer(),
                    Text(
                      '${_parcelas}x de ${DingloTheme.formatCurrency((double.tryParse(_valorCtrl.text.replaceAll(',', '.')) ?? 0) / _parcelas)}',
                      style: DingloTheme.caption,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
            ],

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _tipo == 'receita' ? DingloTheme.income : DingloTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: DingloTheme.buttonRadius),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Salvar Lançamento', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeBtn(String tipo, String label, IconData icon, Color color) {
    final selected = _tipo == tipo;
    return GestureDetector(
      onTap: () => setState(() => _tipo = tipo),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: DingloTheme.buttonRadius,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? Colors.white : DingloTheme.textMuted, size: 18),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: selected ? Colors.white : DingloTheme.textMuted, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
