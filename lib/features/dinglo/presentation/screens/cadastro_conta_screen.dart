import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../dinglo_theme.dart';

class CadastroContaScreen extends StatefulWidget {
  const CadastroContaScreen({super.key});
  @override
  State<CadastroContaScreen> createState() => _CadastroContaScreenState();
}

class _CadastroContaScreenState extends State<CadastroContaScreen> {
  final _supabase = Supabase.instance.client;
  int _step = 0;
  String _banco = '';
  String _descricao = '';
  String _tipo = 'corrente';
  double _saldoInicial = 0;
  bool _saving = false;

  final _bancos = [
    'Nubank', 'Itaú', 'Bradesco', 'Banco do Brasil', 'Santander',
    'Caixa', 'Inter', 'C6 Bank', 'PicPay', 'Mercado Pago',
    'PagBank', 'Neon', 'Next', 'Original', 'Sicoob',
    'Sicredi', 'Banrisul', 'Safra', 'BTG', 'Outro',
  ];

  Future<void> _save() async {
    if (_banco.isEmpty) return;
    setState(() => _saving = true);
    try {
      await _supabase.from('dinglo_contas').insert({
        'user_id': _supabase.auth.currentUser!.id,
        'banco': _banco,
        'descricao': _descricao.isEmpty ? _banco : _descricao,
        'tipo': _tipo,
        'saldo_inicial': _saldoInicial,
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DingloTheme.background,
      appBar: AppBar(
        backgroundColor: DingloTheme.primary,
        foregroundColor: Colors.white,
        title: const Text('Nova Conta', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Step indicator
          Container(
            color: DingloTheme.primary,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: List.generate(3, (i) => Expanded(
                child: Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: i <= _step ? Colors.white : Colors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              )),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _buildStep(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0: return _stepBanco();
      case 1: return _stepDescricao();
      case 2: return _stepSaldo();
      default: return const SizedBox.shrink();
    }
  }

  Widget _stepBanco() {
    return Padding(
      key: const ValueKey(0),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Selecione o banco', style: DingloTheme.heading2),
          const SizedBox(height: 6),
          const Text('Escolha seu banco na lista abaixo', style: DingloTheme.body),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _bancos.length,
              itemBuilder: (_, i) {
                final selected = _banco == _bancos[i];
                return GestureDetector(
                  onTap: () {
                    setState(() { _banco = _bancos[i]; _step = 1; });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: selected ? DingloTheme.primary.withValues(alpha: 0.1) : Colors.white,
                      borderRadius: DingloTheme.buttonRadius,
                      border: Border.all(color: selected ? DingloTheme.primary : Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.account_balance_rounded, color: selected ? DingloTheme.primary : DingloTheme.textMuted, size: 20),
                        const SizedBox(width: 12),
                        Text(_bancos[i], style: TextStyle(fontWeight: FontWeight.w600, color: selected ? DingloTheme.primary : DingloTheme.textPrimary)),
                        const Spacer(),
                        if (selected) const Icon(Icons.check_circle, color: DingloTheme.primary, size: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepDescricao() {
    return Padding(
      key: const ValueKey(1),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Descrição da conta', style: DingloTheme.heading2),
          const SizedBox(height: 6),
          const Text('Dê um nome para identificar esta conta', style: DingloTheme.body),
          const SizedBox(height: 20),
          TextField(
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Ex: Conta Principal',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: DingloTheme.inputRadius, borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: DingloTheme.inputRadius, borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(borderRadius: DingloTheme.inputRadius, borderSide: const BorderSide(color: DingloTheme.primary, width: 2)),
            ),
            onChanged: (v) => _descricao = v,
          ),
          const SizedBox(height: 16),
          const Text('Tipo da conta', style: DingloTheme.heading3),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: ['corrente', 'poupanca', 'investimento'].map((t) {
              final selected = _tipo == t;
              final label = t == 'poupanca' ? 'Poupança' : t == 'investimento' ? 'Investimento' : 'Corrente';
              return ChoiceChip(
                label: Text(label),
                selected: selected,
                selectedColor: DingloTheme.primary.withValues(alpha: 0.15),
                labelStyle: TextStyle(color: selected ? DingloTheme.primary : DingloTheme.textSecondary, fontWeight: FontWeight.w600),
                onSelected: (_) => setState(() => _tipo = t),
              );
            }).toList(),
          ),
          const Spacer(),
          Row(
            children: [
              TextButton(
                onPressed: () => setState(() => _step = 0),
                child: const Text('Voltar', style: TextStyle(color: DingloTheme.textSecondary)),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => setState(() => _step = 2),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DingloTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: DingloTheme.buttonRadius),
                ),
                child: const Text('Próximo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepSaldo() {
    final controller = TextEditingController(text: _saldoInicial > 0 ? _saldoInicial.toStringAsFixed(2) : '');
    return Padding(
      key: const ValueKey(2),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Saldo inicial', style: DingloTheme.heading2),
          const SizedBox(height: 6),
          const Text('Quanto tem nesta conta agora?', style: DingloTheme.body),
          const SizedBox(height: 20),
          TextField(
            autofocus: true,
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: DingloTheme.primary),
            decoration: InputDecoration(
              prefixText: 'R\$ ',
              prefixStyle: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: DingloTheme.primary),
              hintText: '0,00',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: DingloTheme.inputRadius, borderSide: BorderSide.none),
            ),
            onChanged: (v) => _saldoInicial = double.tryParse(v.replaceAll(',', '.')) ?? 0,
          ),
          const Spacer(),
          Row(
            children: [
              TextButton(
                onPressed: () => setState(() => _step = 1),
                child: const Text('Voltar', style: TextStyle(color: DingloTheme.textSecondary)),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: DingloTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: DingloTheme.buttonRadius),
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Salvar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
