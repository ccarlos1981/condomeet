import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/features/garagem/garagem_service.dart';

class GaragemCadastroScreen extends StatefulWidget {
  final String? editVagaId;
  const GaragemCadastroScreen({super.key, this.editVagaId});

  @override
  State<GaragemCadastroScreen> createState() => _GaragemCadastroScreenState();
}

class _GaragemCadastroScreenState extends State<GaragemCadastroScreen> {
  final _service = GaragemService();
  final _numeroController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _precoHoraController = TextEditingController(text: '5');
  final _precoDiaController = TextEditingController(text: '25');
  final _precoMesController = TextEditingController(text: '200');

  String _tipoVaga = 'carro_grande';
  final Map<int, bool> _diasSelecionados = {0: false, 1: true, 2: true, 3: true, 4: true, 5: true, 6: false};
  TimeOfDay _horaInicio = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _horaFim = const TimeOfDay(hour: 18, minute: 0);
  bool _saving = false;
  bool _isEdit = false;

  @override
  void initState() {
    super.initState();
    if (widget.editVagaId != null) {
      _isEdit = true;
      _loadVaga();
    }
  }

  Future<void> _loadVaga() async {
    try {
      final data = await _service.getVagaDetalhe(widget.editVagaId!);
      if (data != null && mounted) {
        setState(() {
          _numeroController.text = data['numero_vaga'] ?? '';
          _descricaoController.text = data['descricao'] ?? '';
          _tipoVaga = data['tipo_vaga'] ?? 'carro_grande';
          _precoHoraController.text = ((data['preco_hora'] ?? 0) as num).toStringAsFixed(0);
          _precoDiaController.text = ((data['preco_dia'] ?? 0) as num).toStringAsFixed(0);
          _precoMesController.text = ((data['preco_mes'] ?? 0) as num).toStringAsFixed(0);

          final avail = data['garage_availability'] as List? ?? [];
          for (final a in avail) {
            final dia = (a as Map)['dia_semana'] as int;
            _diasSelecionados[dia] = true;
          }
          if (avail.isNotEmpty) {
            final first = avail.first as Map;
            final hi = (first['hora_inicio'] as String).split(':');
            final hf = (first['hora_fim'] as String).split(':');
            _horaInicio = TimeOfDay(hour: int.parse(hi[0]), minute: int.parse(hi[1]));
            _horaFim = TimeOfDay(hour: int.parse(hf[0]), minute: int.parse(hf[1]));
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _numeroController.dispose();
    _descricaoController.dispose();
    _precoHoraController.dispose();
    _precoDiaController.dispose();
    _precoMesController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_numeroController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o número da vaga'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _saving = true);
    final condoId = context.read<AuthBloc>().state.condominiumId;
    if (condoId == null) {
      setState(() => _saving = false);
      return;
    }

    try {
      // Build availability list
      final disponibilidade = <Map<String, dynamic>>[];
      _diasSelecionados.forEach((dia, selecionado) {
        if (selecionado) {
          disponibilidade.add({
            'dia_semana': dia,
            'hora_inicio': '${_horaInicio.hour.toString().padLeft(2, '0')}:${_horaInicio.minute.toString().padLeft(2, '0')}',
            'hora_fim': '${_horaFim.hour.toString().padLeft(2, '0')}:${_horaFim.minute.toString().padLeft(2, '0')}',
          });
        }
      });

      if (_isEdit) {
        await _service.updateVaga(widget.editVagaId!, {
          'numero_vaga': _numeroController.text.trim(),
          'tipo_vaga': _tipoVaga,
          'descricao': _descricaoController.text.trim(),
          'preco_hora': double.tryParse(_precoHoraController.text) ?? 0,
          'preco_dia': double.tryParse(_precoDiaController.text) ?? 0,
          'preco_mes': double.tryParse(_precoMesController.text) ?? 0,
        });
        // Update availability
        // TODO: rebuild availability rows on edit
      } else {
        await _service.createVaga(
          condominioId: condoId,
          numeroVaga: _numeroController.text.trim(),
          tipoVaga: _tipoVaga,
          descricao: _descricaoController.text.trim().isEmpty ? null : _descricaoController.text.trim(),
          precoHora: double.tryParse(_precoHoraController.text) ?? 0,
          precoDia: double.tryParse(_precoDiaController.text) ?? 0,
          precoMes: double.tryParse(_precoMesController.text) ?? 0,
          disponibilidade: disponibilidade,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? '✅ Vaga atualizada!' : '✅ Vaga cadastrada com sucesso!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final diasNomes = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(_isEdit ? 'Editar Vaga' : 'Cadastrar Vaga', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Incentivo
            if (!_isEdit)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.green.shade400, Colors.green.shade600]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.monetization_on, color: Colors.white, size: 24),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '💰 Sua vaga pode gerar até R\$ 500/mês!\nCadastre e comece a ganhar enquanto não usa.',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // Número da vaga
            _buildSection(
              'Número da Vaga *',
              TextField(
                controller: _numeroController,
                decoration: InputDecoration(
                  hintText: 'Ex: 21, A-15, B3',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.local_parking),
                ),
              ),
            ),

            // Tipo
            _buildSection(
              'Tipo de Vaga',
              Row(
                children: [
                  _buildTipoChip('carro_grande', 'Carro Grande', Icons.directions_car_filled),
                  const SizedBox(width: 8),
                  _buildTipoChip('carro_pequeno', 'Carro Pequeno', Icons.directions_car),
                  const SizedBox(width: 8),
                  _buildTipoChip('moto', 'Moto', Icons.two_wheeler),
                ],
              ),
            ),

            // Preços
            _buildSection(
              '💰 Preços',
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildPrecoField('Por hora (R\$)', _precoHoraController)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildPrecoField('Por dia (R\$)', _precoDiaController)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildPrecoField('Por mês (R\$)', _precoMesController),
                ],
              ),
            ),

            // Disponibilidade
            _buildSection(
              '🕐 Disponibilidade',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(7, (i) {
                      final selected = _diasSelecionados[i] == true;
                      return GestureDetector(
                        onTap: () => setState(() => _diasSelecionados[i] = !selected),
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: selected ? AppColors.primary : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: selected ? AppColors.primary : Colors.grey.shade300),
                          ),
                          child: Center(
                            child: Text(
                              diasNomes[i],
                              style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: selected ? Colors.white : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTimeButton('Início', _horaInicio, (t) => setState(() => _horaInicio = t)),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('→', style: TextStyle(fontSize: 18)),
                      ),
                      Expanded(
                        child: _buildTimeButton('Fim', _horaFim, (t) => setState(() => _horaFim = t)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Descrição
            _buildSection(
              '📝 Descrição (opcional)',
              TextField(
                controller: _descricaoController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Ex: Vaga coberta, perto do elevador...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Botão salvar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _salvar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 3,
                ),
                child: _saving
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        _isEdit ? 'Salvar Alterações' : 'Cadastrar Vaga',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildTipoChip(String value, String label, IconData icon) {
    final selected = _tipoVaga == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tipoVaga = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.primary : Colors.grey.shade300),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? Colors.white : Colors.grey.shade600, size: 24),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: selected ? Colors.white : Colors.grey.shade700), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrecoField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        prefixText: 'R\$ ',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildTimeButton(String label, TimeOfDay time, Function(TimeOfDay) onChanged) {
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: time);
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.access_time, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
