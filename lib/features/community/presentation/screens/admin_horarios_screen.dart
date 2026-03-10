import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/core/di/injection_container.dart';

const _dias = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sab', 'Dom'];

class AdminHorariosScreen extends StatefulWidget {
  final String areaId;
  final String tipoAgenda;

  const AdminHorariosScreen({
    super.key,
    required this.areaId,
    required this.tipoAgenda,
  });

  @override
  State<AdminHorariosScreen> createState() => _AdminHorariosScreenState();
}

class _AdminHorariosScreenState extends State<AdminHorariosScreen> {
  final _supabase = sl<SupabaseClient>();
  List<Map<String, dynamic>> _horarios = [];
  bool _loading = true;
  String _selectedDay = 'Seg';

  // Form fields
  String _diaSemana = 'Seg';
  TimeOfDay? _horaInicio;
  int _duracao = 60;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _supabase
        .from('areas_comuns_horarios')
        .select('*')
        .eq('area_id', widget.areaId)
        .order('dia_semana')
        .order('hora_inicio');

    setState(() {
      _horarios = List<Map<String, dynamic>>.from(data as List);
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _slotsForDay =>
      _horarios.where((h) => h['dia_semana'] == _selectedDay).toList()
        ..sort((a, b) => (a['hora_inicio'] as String).compareTo(b['hora_inicio'] as String));

  int _countForDay(String day) => _horarios.where((h) => h['dia_semana'] == day).length;

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _horaInicio ?? TimeOfDay.now(),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _horaInicio = picked);
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _fmtHora(String t) => t.length >= 5 ? t.substring(0, 5) : t;

  Future<void> _create() async {
    if (_horaInicio == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a hora inicial')),
      );
      return;
    }
    HapticFeedback.lightImpact();
    await _supabase.from('areas_comuns_horarios').insert({
      'area_id': widget.areaId,
      'dia_semana': _diaSemana,
      'hora_inicio': '${_formatTime(_horaInicio!)}:00',
      'duracao_minutos': _duracao,
      'ativo': true,
    });
    setState(() { _horaInicio = null; _duracao = 60; });
    await _load();
    setState(() => _selectedDay = _diaSemana);
  }

  Future<void> _toggleAtivo(Map<String, dynamic> h) async {
    HapticFeedback.selectionClick();
    final cur = h['ativo'] == true || h['ativo'] == 1;
    await _supabase
        .from('areas_comuns_horarios')
        .update({'ativo': !cur})
        .eq('id', h['id'] as String);
    _load();
  }

  Future<void> _delete(String id) async {
    await _supabase.from('areas_comuns_horarios').delete().eq('id', id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Horários — ${widget.tipoAgenda}',
              style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const Text('Slots disponíveis para agendamento',
              style: TextStyle(color: Color(0xFF999999), fontSize: 11, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 20),
            onPressed: () { setState(() => _loading = true); _load(); },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildCreateForm(),
                  const SizedBox(height: 16),
                  _buildDayTabs(),
                  const SizedBox(height: 12),
                  ..._buildSlotCards(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildCreateForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Novo horário',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
          const SizedBox(height: 12),
          Row(children: [
            // Dia da semana
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Dia', style: TextStyle(fontSize: 11, color: Color(0xFF999999))),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFDDDDDD)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _diaSemana,
                        isDense: true,
                        items: _dias.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (v) => setState(() => _diaSemana = v!),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Hora inicial
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hora Inicial', style: TextStyle(fontSize: 11, color: Color(0xFF999999))),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: _pickTime,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFDDDDDD)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        const Icon(Icons.access_time, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          _horaInicio != null ? _formatTime(_horaInicio!) : '--:--',
                          style: TextStyle(
                            fontSize: 13,
                            color: _horaInicio != null ? const Color(0xFF333333) : const Color(0xFF999999),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Duração
            SizedBox(
              width: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Min', style: TextStyle(fontSize: 11, color: Color(0xFF999999))),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFDDDDDD)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _duracao,
                        isDense: true,
                        items: [30, 45, 60, 90, 120, 180].map((m) =>
                          DropdownMenuItem(value: m, child: Text('$m', style: const TextStyle(fontSize: 13)))
                        ).toList(),
                        onChanged: (v) => setState(() => _duracao = v!),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _create,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('CRIAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _dias.map((d) {
          final count = _countForDay(d);
          final selected = d == _selectedDay;
          return GestureDetector(
            onTap: () => setState(() => _selectedDay = d),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selected ? AppColors.primary : const Color(0xFFDDDDDD)),
              ),
              child: Row(children: [
                Text(d, style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : const Color(0xFF666666),
                )),
                if (count > 0) ...[
                  const SizedBox(width: 5),
                  Container(
                    width: 16, height: 16,
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: Text('$count', style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.bold,
                      color: selected ? AppColors.primary : Colors.white,
                    ))),
                  ),
                ],
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<Widget> _buildSlotCards() {
    final slots = _slotsForDay;
    if (slots.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 32),
          alignment: Alignment.center,
          child: Column(children: [
            const Icon(Icons.schedule, size: 36, color: Color(0xFFCCCCCC)),
            const SizedBox(height: 8),
            Text('Nenhum horário para $_selectedDay',
              style: const TextStyle(fontSize: 13, color: Color(0xFFAAAAAA))),
          ]),
        ),
      ];
    }
    return slots.map((h) {
      final isAtivo = h['ativo'] == true || h['ativo'] == 1;
      final hora = _fmtHora(h['hora_inicio'] as String? ?? '');
      final dur = h['duracao_minutos']?.toString() ?? '?';
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isAtivo ? Colors.white : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.access_time, size: 18, color: Colors.blue.shade600),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$_selectedDay — $hora',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
              Text('Duração: $dur min',
                style: const TextStyle(fontSize: 11, color: Color(0xFF999999))),
            ],
          )),
          GestureDetector(
            onTap: () => _toggleAtivo(h),
            child: Icon(
              isAtivo ? Icons.toggle_on : Icons.toggle_off,
              color: isAtivo ? Colors.green : Colors.grey.shade400,
              size: 28,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _delete(h['id'] as String),
            child: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade400),
          ),
        ]),
      );
    }).toList();
  }
}
