import 'package:flutter/material.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/features/garagem/garagem_service.dart';

class GaragemReservationScreen extends StatefulWidget {
  final Map<String, dynamic> vaga;
  const GaragemReservationScreen({super.key, required this.vaga});

  @override
  State<GaragemReservationScreen> createState() => _GaragemReservationScreenState();
}

class _GaragemReservationScreenState extends State<GaragemReservationScreen> {
  final _service = GaragemService();
  final _placaController = TextEditingController();
  final _modeloController = TextEditingController();
  final _corController = TextEditingController();
  final _obsController = TextEditingController();

  String _tipoPeriodo = 'hora';
  DateTime _inicio = DateTime.now().add(const Duration(hours: 1));
  DateTime _fim = DateTime.now().add(const Duration(hours: 3));
  double _valorEstimado = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _calcularPreco();
  }

  @override
  void dispose() {
    _placaController.dispose();
    _modeloController.dispose();
    _corController.dispose();
    _obsController.dispose();
    super.dispose();
  }

  Future<void> _calcularPreco() async {
    try {
      final valor = await _service.calculatePrice(
        widget.vaga['id'], _tipoPeriodo, _inicio, _fim,
      );
      if (mounted) setState(() => _valorEstimado = valor);
    } catch (_) {}
  }

  Future<void> _pickDateTime(bool isInicio) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isInicio ? _inicio : _fim,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(isInicio ? _inicio : _fim),
    );
    if (time == null || !mounted) return;

    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isInicio) {
        _inicio = dt;
        if (_fim.isBefore(_inicio.add(const Duration(hours: 1)))) {
          _fim = _inicio.add(const Duration(hours: 2));
        }
      } else {
        _fim = dt;
      }
    });
    _calcularPreco();
  }

  Future<void> _reservar() async {
    if (_placaController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe a placa do veículo'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final result = await _service.createReserva(
        garageId: widget.vaga['id'],
        condominioId: widget.vaga['condominio_id'] ?? '',
        placa: _placaController.text.trim().toUpperCase(),
        modelo: _modeloController.text.trim(),
        cor: _corController.text.trim(),
        inicio: _inicio,
        fim: _fim,
        tipoPeriodo: _tipoPeriodo,
        observacao: _obsController.text.trim().isEmpty ? null : _obsController.text.trim(),
      );

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Reserva criada! Valor: R\$ ${(result['valor'] as num).toStringAsFixed(2)}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${result['error']}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
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
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Reservar Vaga ${widget.vaga['numero_vaga']}', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tipo de período
            const Text('Tipo de aluguel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildPeriodoChip('hora', 'Por hora'),
                const SizedBox(width: 8),
                _buildPeriodoChip('dia', 'Por dia'),
                const SizedBox(width: 8),
                _buildPeriodoChip('mes', 'Por mês'),
              ],
            ),

            const SizedBox(height: 20),

            // Data/hora início
            const Text('Início', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _buildDateButton(_inicio, true),

            const SizedBox(height: 16),

            // Data/hora fim
            const Text('Fim', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _buildDateButton(_fim, false),

            const SizedBox(height: 20),

            // Dados do veículo
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🚗 Dados do veículo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _placaController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Placa *',
                      hintText: 'ABC-1234',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.badge),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _modeloController,
                          decoration: InputDecoration(
                            labelText: 'Modelo',
                            hintText: 'Corolla',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _corController,
                          decoration: InputDecoration(
                            labelText: 'Cor',
                            hintText: 'Branco',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _obsController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Observação (opcional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Valor estimado
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                children: [
                  Text('Valor estimado', style: TextStyle(fontSize: 14, color: Colors.green.shade700)),
                  const SizedBox(height: 6),
                  Text(
                    'R\$ ${_valorEstimado.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pagamento combinado entre moradores',
                    style: TextStyle(fontSize: 12, color: Colors.green.shade600),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Botão reservar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _reservar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 3,
                ),
                child: _saving
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text(
                        'Confirmar Reserva',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodoChip(String value, String label) {
    final selected = _tipoPeriodo == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _tipoPeriodo = value);
          _calcularPreco();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.primary : Colors.grey.shade300),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateButton(DateTime dt, bool isInicio) {
    return GestureDetector(
      onTap: () => _pickDateTime(isInicio),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 20, color: Colors.grey.shade600),
            const SizedBox(width: 10),
            Text(
              '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} às ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
