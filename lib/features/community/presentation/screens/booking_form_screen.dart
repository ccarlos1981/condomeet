import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/core/di/injection_container.dart';
import 'package:condomeet/core/utils/structure_helper.dart';

const _meses = ['Janeiro','Fevereiro','Março','Abril','Maio','Junho',
  'Julho','Agosto','Setembro','Outubro','Novembro','Dezembro'];
const _diasSemana = ['Dom','Seg','Ter','Qua','Qui','Sex','Sáb'];
// Supabase uses 'Sab' (no accent)
const _diasSemanaDb = ['Dom','Seg','Ter','Qua','Qui','Sex','Sab'];

class BookingFormScreen extends StatefulWidget {
  final Map<String, dynamic> area;
  final bool portariaMode;

  const BookingFormScreen({
    super.key,
    required this.area,
    this.portariaMode = false,
  });

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

  // ─── Portaria mode state ───
  String? _tipoEstrutura;
  List<String> _blocos = [];
  Map<String, List<String>> _aptosMap = {};
  Map<String, List<Map<String, String>>> _residentsPerUnit = {};
  String? _selectedBloco;
  String? _selectedApto;
  String? _selectedResidentId;
  bool _loadingPortaria = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _viewYear = now.year;
    _viewMonth = now.month;
    _nomeCtrl = TextEditingController(text: widget.area['tipo_agenda'] ?? '');
    _loadBookedDates();
    if (widget.portariaMode) _loadPortariaData();
  }

  Future<void> _loadPortariaData() async {
    setState(() => _loadingPortaria = true);
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final profile = await _supabase
        .from('perfil').select('condominio_id').eq('id', user.id).maybeSingle();
    final condoId = profile?['condominio_id'] as String?;
    if (condoId == null) return;

    final condo = await _supabase
        .from('condominios').select('tipo_estrutura').eq('id', condoId).maybeSingle();
    _tipoEstrutura = condo?['tipo_estrutura'] as String? ?? 'predio';

    final structData = await _supabase
        .from('blocos')
        .select('nome_ou_numero, unidades ( apartamentos ( numero ) )')
        .eq('condominio_id', condoId)
        .order('nome_ou_numero');

    final blocosSet = <String>{};
    final aptosPerBloco = <String, Set<String>>{};
    for (final blk in (structData as List)) {
      final blocoName = blk['nome_ou_numero'] as String?;
      if (blocoName == null) continue;
      blocosSet.add(blocoName);
      aptosPerBloco[blocoName] ??= {};
      final units = blk['unidades'] as List? ?? [];
      for (final u in units) {
        final apto = (u['apartamentos'] as Map?)?['numero'] as String?;
        if (apto != null) aptosPerBloco[blocoName]!.add(apto);
      }
    }

    final moradores = await _supabase
        .from('perfil')
        .select('id, nome_completo, bloco_txt, apto_txt')
        .eq('condominio_id', condoId)
        .not('bloco_txt', 'is', null)
        .or('status_aprovacao.is.null,status_aprovacao.eq.aprovado');

    final resPerUnit = <String, List<Map<String, String>>>{};
    for (final m in (moradores as List)) {
      final b = m['bloco_txt'] as String?;
      final a = m['apto_txt'] as String?;
      if (b != null && a != null) {
        final key = '${b}__$a';
        resPerUnit[key] ??= [];
        resPerUnit[key]!.add({'id': m['id'] as String, 'nome': m['nome_completo'] as String? ?? 'Morador'});
      }
    }

    if (mounted) {
      setState(() {
        _blocos = blocosSet.toList()..sort();
        _aptosMap = { for (final b in _blocos) b: (aptosPerBloco[b] ?? {}).toList()..sort() };
        _residentsPerUnit = resPerUnit;
        _loadingPortaria = false;
      });
    }
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
    if (widget.portariaMode && (_selectedBloco == null || _selectedApto == null)) {
      setState(() => _error = 'Selecione Bloco e Apto'); return;
    }
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

      // Server-side validation: check if date is already booked (pendente or aprovado)
      final areaId = widget.area['id'] as String;
      if (tipo == 'por_dia') {
        final existing = await _supabase
            .from('reservas')
            .select('id')
            .eq('area_id', areaId)
            .eq('data_reserva', _selectedDate!)
            .inFilter('status', ['pendente', 'aprovado'])
            .maybeSingle();

        if (existing != null) {
          if (mounted) {
            setState(() {
              _error = 'Esta data já foi reservada por outro morador.';
              _saving = false;
              _bookedDates.add(_selectedDate!);
            });
          }
          return;
        }
      } else if (tipo == 'por_hora' && _selectedSlotId != null) {
        final existing = await _supabase
            .from('reservas')
            .select('id')
            .eq('area_id', areaId)
            .eq('data_reserva', _selectedDate!)
            .eq('horario_id', _selectedSlotId!)
            .inFilter('status', ['pendente', 'aprovado'])
            .maybeSingle();

        if (existing != null) {
          if (mounted) {
            setState(() {
              _error = 'Este horário já foi reservado por outro morador.';
              _saving = false;
            });
          }
          return;
        }
      }

      final insertData = <String, dynamic>{
        'area_id': areaId,
        'horario_id': _selectedSlotId,
        'condominio_id': condoId,
        'data_reserva': _selectedDate,
        'nome_evento': _nomeCtrl.text.trim().isEmpty ? widget.area['tipo_agenda'] : _nomeCtrl.text.trim(),
        'status': aprovAuto ? 'aprovado' : 'pendente',
      };

      if (widget.portariaMode) {
        insertData['user_id'] = _selectedResidentId;
        insertData['criado_por_portaria'] = true;
        insertData['bloco_destino'] = _selectedBloco;
        insertData['apto_destino'] = _selectedApto;
        insertData['criado_por'] = user.id;
      } else {
        insertData['user_id'] = user.id;
      }

      await _supabase.from('reservas').insert(insertData);

      if (mounted) {
        Navigator.of(context).pop(true); // signal success
      }
    } catch (e) {
      setState(() { _error = 'Erro ao reservar: $e'; _saving = false; });
    }
  }

  String _fmtHora(String h) => h.length >= 5 ? h.substring(0, 5) : h;

  // ─── Portaria unit selector widget ───
  Widget _buildPortariaUnitSelector() {
    final blocoLabel = _tipoEstrutura != null ? StructureHelper.getNivel1Label(_tipoEstrutura) : 'Bloco';
    final aptoLabel = _tipoEstrutura != null ? StructureHelper.getNivel2Label(_tipoEstrutura) : 'Apto';
    final availAptos = _selectedBloco != null ? (_aptosMap[_selectedBloco] ?? <String>[]) : <String>[];
    final unitKey = '${_selectedBloco ?? ''}__${_selectedApto ?? ''}';
    final unitResidents = _residentsPerUnit[unitKey] ?? [];

    if (_loadingPortaria) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: const Center(child: SizedBox(width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.apartment_rounded, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text('Reserva em nome do morador',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _buildPortariaDropdown(
              label: blocoLabel,
              value: _selectedBloco,
              items: _blocos,
              onChanged: (v) => setState(() {
                _selectedBloco = v;
                _selectedApto = null;
                _selectedResidentId = null;
              }),
            )),
            const SizedBox(width: 10),
            Expanded(child: _buildPortariaDropdown(
              label: aptoLabel,
              value: _selectedApto,
              items: availAptos,
              enabled: _selectedBloco != null,
              onChanged: (v) => setState(() {
                _selectedApto = v;
                _selectedResidentId = null;
              }),
            )),
          ]),
          if (_selectedBloco != null && _selectedApto != null && unitResidents.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildPortariaDropdown(
              label: 'Morador (opcional)',
              value: _selectedResidentId,
              items: unitResidents.map((r) => r['id']!).toList(),
              displayItems: unitResidents.map((r) => r['nome']!).toList(),
              onChanged: (v) => setState(() => _selectedResidentId = v),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPortariaDropdown({
    required String label,
    required String? value,
    required List<String> items,
    List<String>? displayItems,
    bool enabled = true,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: enabled ? AppColors.border : Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
          icon: Icon(Icons.keyboard_arrow_down, size: 18,
            color: enabled ? AppColors.primary : Colors.grey.shade300),
          style: const TextStyle(fontSize: 12, color: AppColors.textMain),
          items: items.asMap().entries.map((e) {
            final display = displayItems != null ? displayItems[e.key] : e.value;
            return DropdownMenuItem(value: e.value, child: Text(display));
          }).toList(),
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }

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
          style: const TextStyle(color: AppColors.textMain, fontSize: 16, fontWeight: FontWeight.bold)),
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
            // ─── Portaria: bloco/apto selector ───
            if (widget.portariaMode) ...[
              _buildPortariaUnitSelector(),
              const SizedBox(height: 16),
            ],
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
              Expanded(child: Center(child: Text(d, style: const TextStyle(fontSize: 10, color: AppColors.textHint, fontWeight: FontWeight.w600))))
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
                Color textColor = AppColors.textMain;
                if (isPast) { textColor = AppColors.disabledIcon; }
                else if (isBooked) { bg = AppColors.primary.withValues(alpha: 0.15); textColor = AppColors.primary; }
                else if (isSel) { bg = AppColors.textMain; textColor = Colors.white; }
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
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
                    border: Border.all(color: _ciente ? AppColors.primary : AppColors.disabledIcon, width: 2),
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
                final canBook = !_saving && _selectedDate != null && !dateBooked && _ciente;
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
