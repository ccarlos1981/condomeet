import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/core/di/injection_container.dart';

const _meses = ['Janeiro','Fevereiro','Março','Abril','Maio','Junho',
  'Julho','Agosto','Setembro','Outubro','Novembro','Dezembro'];
const _diasSemana = ['Dom','Seg','Ter','Qua','Qui','Sex','Sáb'];
// Supabase uses 'Sab' (no accent)
const _diasSemanaDb = ['Dom','Seg','Ter','Qua','Qui','Sex','Sab'];

class BookingFormScreen extends StatefulWidget {
  final Map<String, dynamic> area;
  const BookingFormScreen({super.key, required this.area});

  @override
  State<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends State<BookingFormScreen> {
  final _supabase = sl<SupabaseClient>();

  // calendar state
  late int _viewYear;
  late int _viewMonth;
  String? _selectedDate;

  // slots
  List<Map<String, dynamic>> _slots = [];
  bool _loadingSlots = false;
  String? _selectedSlotId;

  // form
  late TextEditingController _nomeCtrl;
  bool _ciente = false;
  bool _saving = false;
  String? _error;

  // already booked dates (for this area)
  Set<String> _bookedDates = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _viewYear = now.year;
    _viewMonth = now.month;
    _nomeCtrl = TextEditingController(text: widget.area['tipo_agenda'] ?? '');
    _loadBookedDates();
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBookedDates() async {
    try {
      final areaId = widget.area['id'] as String;
      final firstOfMonth = '$_viewYear-${_viewMonth.toString().padLeft(2,'0')}-01';
      final lastDay = DateTime(_viewYear, _viewMonth + 1, 0).day;
      final lastOfMonth = '$_viewYear-${_viewMonth.toString().padLeft(2,'0')}-$lastDay';

      final data = await _supabase
          .from('reservas')
          .select('data_reserva')
          .eq('area_id', areaId)
          .inFilter('status', ['pendente','aprovado'])
          .gte('data_reserva', firstOfMonth)
          .lte('data_reserva', lastOfMonth);

      final typ = widget.area['tipo_reserva'] as String? ?? 'por_dia';
      if (typ == 'por_dia') {
        final newBooked = {for (final r in (data as List)) r['data_reserva'] as String};
        debugPrint('[BookingForm] areaId=$areaId datas=$newBooked');
        setState(() {
          _bookedDates = newBooked;
          if (_selectedDate != null && _bookedDates.contains(_selectedDate)) {
            _selectedDate = null;
            _selectedSlotId = null;
            _error = 'Esta data já está reservada. Escolha outra.';
          }
        });
      }
    } catch (e) {
      debugPrint('[BookingForm] Erro ao carregar datas: $e');
    }
  }

  void _prevMonth() {
    setState(() {
      if (_viewMonth == 1) { _viewYear--; _viewMonth = 12; }
      else _viewMonth--;
    });
    _selectedDate = null;
    _loadBookedDates();
  }

  void _nextMonth() {
    setState(() {
      if (_viewMonth == 12) { _viewYear++; _viewMonth = 1; }
      else _viewMonth++;
    });
    _selectedDate = null;
    _loadBookedDates();
  }

  Future<void> _onDateTap(String iso) async {
    setState(() { _selectedDate = iso; _selectedSlotId = null; _slots = []; });
    HapticFeedback.selectionClick();

    final tipo = widget.area['tipo_reserva'] as String? ?? 'por_dia';
    if (tipo == 'por_hora') {
      setState(() => _loadingSlots = true);
      final date = DateTime.parse(iso + ' 12:00:00');
      final diaSemana = _diasSemanaDb[date.weekday % 7];

      final areaId = widget.area['id'] as String;
      final horarios = await _supabase
          .from('areas_comuns_horarios')
          .select('id, hora_inicio, duracao_minutos')
          .eq('area_id', areaId)
          .eq('dia_semana', diaSemana)
          .eq('ativo', true)
          .order('hora_inicio');

      final reservados = await _supabase
          .from('reservas')
          .select('horario_id')
          .eq('area_id', areaId)
          .eq('data_reserva', iso)
          .inFilter('status', ['pendente','aprovado']);

      final ocupados = {for (final r in (reservados as List)) r['horario_id'] as String?};

      setState(() {
        _slots = (horarios as List).map<Map<String,dynamic>>((h) => {
          ...h as Map<String, dynamic>,
          'disponivel': !ocupados.contains(h['id']),
        }).toList();
        _loadingSlots = false;
      });
    }
  }

  Future<void> _agendar() async {
    if (_selectedDate == null) { setState(() => _error = 'Selecione uma data'); return; }
    if (_bookedDates.contains(_selectedDate)) { setState(() => _error = 'Esta data já está reservada'); return; }
    final tipo = widget.area['tipo_reserva'] as String? ?? 'por_dia';
    if (tipo == 'por_hora' && _selectedSlotId == null) {
      setState(() => _error = 'Selecione um horário'); return;
    }
    if (!_ciente) { setState(() => _error = 'Confirme que está ciente do regimento'); return; }

    setState(() { _saving = true; _error = null; });
    HapticFeedback.lightImpact();

    try {
      final user = _supabase.auth.currentUser!;
      final profile = await _supabase
          .from('perfil').select('condominio_id').eq('id', user.id).maybeSingle();
      final condoId = profile?['condominio_id'] as String?;
      if (condoId == null) throw Exception('Perfil não encontrado');

      final aprovAuto = widget.area['aprovacao_automatica'] == true;

      await _supabase.from('reservas').insert({
        'area_id': widget.area['id'],
        'horario_id': _selectedSlotId,
        'user_id': user.id,
        'condominio_id': condoId,
        'data_reserva': _selectedDate,
        'nome_evento': _nomeCtrl.text.trim().isEmpty ? widget.area['tipo_agenda'] : _nomeCtrl.text.trim(),
        'status': aprovAuto ? 'aprovado' : 'pendente',
      });

      if (mounted) {
        Navigator.of(context).pop(true); // signal success
      }
    } catch (e) {
      setState(() { _error = 'Erro ao reservar: $e'; _saving = false; });
    }
  }

  String _fmtHora(String h) => h.length >= 5 ? h.substring(0, 5) : h;

  @override
  Widget build(BuildContext context) {
    final tipo = widget.area['tipo_agenda'] as String? ?? '—';
    final tipoReserva = widget.area['tipo_reserva'] as String? ?? 'por_dia';

    final today = DateTime.now();
    final todayIso = '${today.year}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}';
    final firstDay = DateTime(_viewYear, _viewMonth, 1);
    final lastDay = DateTime(_viewYear, _viewMonth + 1, 0).day;
    final startDow = firstDay.weekday % 7; // 0=Sun

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(tipo,
          style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _agendar,
            child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
              : const Text('Agendar', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Calendar header
            Row(children: [
              GestureDetector(
                onTap: () { final now = DateTime.now(); setState(() { _viewYear = now.year; _viewMonth = now.month; }); _loadBookedDates(); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                  child: const Text('Hoje', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              const Spacer(),
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: _prevMonth, padding: EdgeInsets.zero),
              Text('${_meses[_viewMonth-1]} de $_viewYear',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: _nextMonth, padding: EdgeInsets.zero),
            ]),

            const SizedBox(height: 8),

            // Day headers
            Row(children: _diasSemana.map((d) =>
              Expanded(child: Center(child: Text(d, style: const TextStyle(fontSize: 10, color: Color(0xFF999999), fontWeight: FontWeight.w600))))
            ).toList()),

            const SizedBox(height: 4),

            // Calendar grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1.1),
              itemCount: startDow + lastDay,
              itemBuilder: (_, i) {
                if (i < startDow) return const SizedBox();
                final day = i - startDow + 1;
                final iso = '$_viewYear-${_viewMonth.toString().padLeft(2,'0')}-${day.toString().padLeft(2,'0')}';
                final isPast = iso.compareTo(todayIso) < 0;
                final isBooked = _bookedDates.contains(iso);
                final isSel = iso == _selectedDate;
                final isToday = iso == todayIso;

                Color bg = Colors.transparent;
                Color textColor = const Color(0xFF333333);
                if (isPast) { textColor = const Color(0xFFCCCCCC); }
                else if (isBooked) { bg = AppColors.primary.withValues(alpha: 0.15); textColor = AppColors.primary; }
                else if (isSel) { bg = const Color(0xFF222222); textColor = Colors.white; }
                else if (isToday) { bg = AppColors.primary.withValues(alpha: 0.1); textColor = AppColors.primary; }

                return GestureDetector(
                  onTap: () { if (!isPast && !isBooked) _onDateTap(iso); },
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
                    child: Center(child: Text('$day',
                      style: TextStyle(fontSize: 12, fontWeight: isSel || isToday ? FontWeight.bold : FontWeight.normal, color: textColor))),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // Time slots (por_hora only)
            if (tipoReserva == 'por_hora' && _selectedDate != null) ...[
              Text('Escolha aqui seu horário',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              if (_loadingSlots) const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
              else if (_slots.isEmpty) Text('Nenhum horário disponível para este dia.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400))
              else Wrap(
                spacing: 8, runSpacing: 8,
                children: _slots.map((h) {
                  final hora = _fmtHora(h['hora_inicio'] as String);
                  final disponivel = h['disponivel'] == true;
                  final isSel = _selectedSlotId == h['id'];
                  return GestureDetector(
                    onTap: disponivel ? () { HapticFeedback.selectionClick(); setState(() => _selectedSlotId = h['id'] as String?); } : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: !disponivel ? Colors.grey.shade100
                          : isSel ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(hora,
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: !disponivel ? Colors.grey.shade400
                            : isSel ? Colors.white
                            : AppColors.primary,
                          decoration: disponivel ? null : TextDecoration.lineThrough,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],

            // Nome do evento
            Text('Dê um nome para o seu evento',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            TextField(
              controller: _nomeCtrl,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: widget.area['tipo_agenda'] ?? '',
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primary)),
              ),
            ),

            const SizedBox(height: 16),

            // Regimento checkbox
            GestureDetector(
              onTap: () { HapticFeedback.selectionClick(); setState(() => _ciente = !_ciente); },
              child: Row(children: [
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: _ciente ? AppColors.primary : Colors.white,
                    border: Border.all(color: _ciente ? AppColors.primary : const Color(0xFFCCCCCC), width: 2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: _ciente ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
                ),
                const SizedBox(width: 10),
                const Expanded(child: Text('Ciente do Regimento do condomínio',
                  style: TextStyle(fontSize: 13, color: Color(0xFF555555)))),
              ]),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: Builder(builder: (_) {
                final dateBooked = _selectedDate != null && _bookedDates.contains(_selectedDate);
                final canBook = !_saving && _selectedDate != null && !dateBooked;
                final label = _saving ? 'Agendando...'
                  : _selectedDate == null ? 'Selecione uma data'
                  : dateBooked ? 'Data já reservada'
                  : 'Agendar';
                return ElevatedButton(
                  onPressed: canBook ? _agendar : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canBook ? AppColors.primary : Colors.grey.shade300,
                    foregroundColor: canBook ? Colors.white : Colors.grey.shade500,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade500,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
