import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/shared/utils/structure_labels.dart';

const _visitorTypes = [
  'Uber ou Taxi',
  'Delivery',
  'Farmácia',
  'Diarista',
  'Visitante',
  'Mat. Obra',
  'Serviços',
  'Hóspedes',
  'Outros',
];

class PortariaVisitorAuthorizationFormScreen extends StatefulWidget {
  const PortariaVisitorAuthorizationFormScreen({super.key});

  @override
  State<PortariaVisitorAuthorizationFormScreen> createState() =>
      _PortariaVisitorAuthorizationFormScreenState();
}

class _PortariaVisitorAuthorizationFormScreenState
    extends State<PortariaVisitorAuthorizationFormScreen> {
  // Form state
  String _visitorType = '';
  String _bloco = '';
  String _apto = '';
  String _selectedResidentId = '';
  String _manualResidentName = '';
  String _manualResidentWhatsapp = '';
  DateTime _validityDate = DateTime.now();
  final _guestNameCtrl = TextEditingController();
  final _visitorWhatsappCtrl = TextEditingController();
  final _observacaoCtrl = TextEditingController();

  // UI state
  bool _saving = false;
  String? _error;
  Map<String, dynamic>? _successData; // { code, guestName, visitorType, date }

  // Structural data
  List<String> _allBlocos = [];
  Map<String, List<String>> _aptosMap = {};
  List<Map<String, dynamic>> _unitResidents = [];
  bool _loadingResidents = false;

  // User info
  String _currentUserName = '';

  @override
  void initState() {
    super.initState();
    _loadStructuralData();
    _loadCurrentUserName();
  }

  @override
  void dispose() {
    _guestNameCtrl.dispose();
    _visitorWhatsappCtrl.dispose();
    _observacaoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserName() async {
    final authState = context.read<AuthBloc>().state;
    final userId = authState.userId;
    if (userId == null) return;
    final supabase = Supabase.instance.client;
    final profile = await supabase
        .from('perfil')
        .select('nome_completo')
        .eq('id', userId)
        .maybeSingle();
    if (mounted && profile != null) {
      setState(() => _currentUserName = profile['nome_completo'] as String? ?? '');
    }
  }

  int _numericCompare(String a, String b) {
    final na = int.tryParse(a);
    final nb = int.tryParse(b);
    if (na != null && nb != null) return na.compareTo(nb);
    return a.compareTo(b);
  }

  Future<void> _loadStructuralData() async {
    final condoId = context.read<AuthBloc>().state.condominiumId;
    if (condoId == null) return;
    final supabase = Supabase.instance.client;

    final blocosRes = await supabase
        .from('blocos')
        .select('nome_ou_numero, unidades ( apartamentos ( numero ) )')
        .eq('condominio_id', condoId)
        .order('nome_ou_numero')
        .limit(10000);

    final blocos = <String>{};
    final aptosPerBloco = <String, Set<String>>{};

    for (final blk in blocosRes as List) {
      final blocoName = blk['nome_ou_numero'] as String?;
      if (blocoName == null || blocoName.isEmpty) continue;
      blocos.add(blocoName);
      aptosPerBloco.putIfAbsent(blocoName, () => {});
      final units = blk['unidades'] as List? ?? [];
      for (final u in units) {
        final aptosData = u['apartamentos'];
        if (aptosData is Map) {
          final numero = aptosData['numero'] as String?;
          if (numero != null && numero.isNotEmpty) {
            aptosPerBloco[blocoName]!.add(numero);
          }
        } else if (aptosData is List) {
          for (final a in aptosData) {
            final numero = a['numero'] as String?;
            if (numero != null && numero.isNotEmpty) {
              aptosPerBloco[blocoName]!.add(numero);
            }
          }
        }
      }
    }

    final sortedBlocos = blocos.toList()..sort(_numericCompare);
    final aptosMap = <String, List<String>>{};
    for (final b in sortedBlocos) {
      aptosMap[b] = (aptosPerBloco[b] ?? {}).toList()..sort(_numericCompare);
    }

    if (mounted) setState(() { _allBlocos = sortedBlocos; _aptosMap = aptosMap; });
  }

  Future<void> _loadResidentsForUnit() async {
    if (_bloco.isEmpty || _apto.isEmpty) {
      setState(() => _unitResidents = []);
      return;
    }
    final condoId = context.read<AuthBloc>().state.condominiumId;
    if (condoId == null) return;

    setState(() => _loadingResidents = true);
    try {
      final supabase = Supabase.instance.client;
      final data = await supabase
          .from('perfil')
          .select('id, nome_completo')
          .eq('condominio_id', condoId)
          .eq('bloco_txt', _bloco)
          .eq('apto_txt', _apto)
          .neq('papel_sistema', 'portaria');
      if (mounted) {
        setState(() {
          _unitResidents = List<Map<String, dynamic>>.from(data);
          _loadingResidents = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingResidents = false);
    }
  }

  String _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random();
    return List.generate(3, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  Future<void> _handleSubmit() async {
    // Validation
    if (_visitorType.isEmpty) {
      setState(() => _error = 'Selecione o tipo de visitante.');
      return;
    }
    if (_bloco.isEmpty || _apto.isEmpty) {
      setState(() => _error = 'Selecione o bloco e o apartamento.');
      return;
    }

    setState(() { _error = null; _saving = true; });

    try {
      final supabase = Supabase.instance.client;
      final condoId = context.read<AuthBloc>().state.condominiumId;
      final code = _generateCode();

      String? residentId;
      String? moradorNomeManual;

      if (_unitResidents.isNotEmpty && _selectedResidentId.isNotEmpty && _selectedResidentId != '__none__') {
        residentId = _selectedResidentId;
      } else if (_unitResidents.isEmpty && _manualResidentName.trim().isNotEmpty) {
        moradorNomeManual = _manualResidentName.trim();
      }

      await supabase.from('convites').insert({
        'resident_id': residentId,
        'condominio_id': condoId,
        'guest_name': _guestNameCtrl.text.trim().isEmpty ? null : _guestNameCtrl.text.trim(),
        'visitor_type': _visitorType,
        'validity_date': '${_validityDate.year}-${_validityDate.month.toString().padLeft(2, '0')}-${_validityDate.day.toString().padLeft(2, '0')}',
        'qr_data': code,
        'visitante_compareceu': false,
        'status': 'active',
        'whatsapp': _visitorWhatsappCtrl.text.trim().isEmpty ? null : _visitorWhatsappCtrl.text.trim(),
        'observacao': _observacaoCtrl.text.trim().isEmpty ? null : _observacaoCtrl.text.trim(),
        'criado_por_portaria': true,
        'bloco_destino': _bloco,
        'apto_destino': _apto,
        'morador_nome_manual': moradorNomeManual,
      });

      if (mounted) {
        setState(() {
          _successData = {
            'code': code,
            'guestName': _guestNameCtrl.text.trim().isEmpty ? 'Visitante' : _guestNameCtrl.text.trim(),
            'visitorType': _visitorType,
            'date': '${_validityDate.day.toString().padLeft(2, '0')}/${_validityDate.month.toString().padLeft(2, '0')}/${_validityDate.year}',
          };
          _saving = false;
        });

        // Auto-reset after 4 seconds
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) _resetForm();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao registrar: $e';
          _saving = false;
        });
      }
    }
  }

  void _resetForm() {
    setState(() {
      _visitorType = '';
      _bloco = '';
      _apto = '';
      _selectedResidentId = '';
      _manualResidentName = '';
      _manualResidentWhatsapp = '';
      _validityDate = DateTime.now();
      _guestNameCtrl.clear();
      _visitorWhatsappCtrl.clear();
      _observacaoCtrl.clear();
      _error = null;
      _successData = null;
      _unitResidents = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
        title: const Text('Autorização Visitante', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _successData != null ? _buildSuccess() : _buildForm(),
    );
  }

  // ── SUCCESS VIEW ─────────────────────────────────────────────────
  Widget _buildSuccess() {
    final data = _successData!;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle, color: Colors.green.shade600, size: 36),
            ),
            const SizedBox(height: 16),
            const Text('Autorização Registrada!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('A autorização foi criada com sucesso.', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            const SizedBox(height: 20),

            // QR Code
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: QrImageView(
                    data: data['code'] as String,
                    version: QrVersions.auto,
                    size: 120,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  data['code'] as String,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 6, color: AppColors.primary),
                ),
                const SizedBox(height: 8),
                Text('Tipo: ${data['visitorType']}', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                Text('Visitante: ${data['guestName']}', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                Text('Data: ${data['date']}', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              ]),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _resetForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Nova Autorização', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── FORM VIEW ─────────────────────────────────────────────────────
  Widget _buildForm() {
    final tipoEstrutura = context.read<AuthBloc>().state.tipoEstrutura;
    final availableAptos = _bloco.isNotEmpty && _aptosMap.containsKey(_bloco) ? _aptosMap[_bloco]! : <String>[];
    final hasResidents = _unitResidents.isNotEmpty;

    return SingleChildScrollView(
      child: Column(children: [
        // Header banner
        Container(
          width: double.infinity,
          color: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Text(
            'Solicitação de autorização de entrada — por $_currentUserName',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Tipo de visitante ──────────────────────
            _buildLabel('Tipo de visitante *'),
            _buildDropdown(
              value: _visitorType.isEmpty ? null : _visitorType,
              hint: 'Selecione o tipo de visitante',
              items: _visitorTypes,
              onChanged: (v) => setState(() => _visitorType = v ?? ''),
            ),
            const SizedBox(height: 16),

            // ── Bloco + Apto ──────────────────────────
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _buildLabel('${getBlocoLabel(tipoEstrutura)} *'),
                _buildDropdown(
                  value: _bloco.isEmpty ? null : (_allBlocos.contains(_bloco) ? _bloco : null),
                  hint: getBlocoLabel(tipoEstrutura),
                  items: _allBlocos,
                  onChanged: (v) {
                    setState(() {
                      _bloco = v ?? '';
                      _apto = '';
                      _selectedResidentId = '';
                      _unitResidents = [];
                    });
                  },
                ),
              ])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _buildLabel('${getAptoLabel(tipoEstrutura)} *'),
                _buildDropdown(
                  value: _apto.isEmpty ? null : (availableAptos.contains(_apto) ? _apto : null),
                  hint: getAptoLabel(tipoEstrutura),
                  items: availableAptos,
                  onChanged: (v) {
                    setState(() {
                      _apto = v ?? '';
                      _selectedResidentId = '';
                    });
                    _loadResidentsForUnit();
                  },
                ),
              ])),
            ]),
            const SizedBox(height: 16),

            // ── Quem solicitou ────────────────────────
            if (_bloco.isNotEmpty && _apto.isNotEmpty) ...[
              if (_loadingResidents)
                const Center(child: Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                ))
              else if (hasResidents) ...[
                _buildLabel('Quem solicitou? (Desejável)'),
                _buildDropdown(
                  value: _selectedResidentId.isEmpty ? null : _selectedResidentId,
                  hint: 'Selecione o morador',
                  items: [..._unitResidents.map((r) => r['id'] as String), '__none__'],
                  itemLabels: {
                    for (final r in _unitResidents)
                      r['id'] as String: r['nome_completo'] as String? ?? 'Morador',
                    '__none__': 'Não se identificou',
                  },
                  onChanged: (v) => setState(() => _selectedResidentId = v ?? ''),
                ),
                const SizedBox(height: 16),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: const Row(children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 16),
                    SizedBox(width: 6),
                    Expanded(child: Text('Nenhum morador cadastrado nesta unidade.', style: TextStyle(fontSize: 12, color: Colors.amber))),
                  ]),
                ),
                const SizedBox(height: 12),
                _buildLabel('Nome do morador não cadastrado'),
                _buildTextField(
                  value: _manualResidentName,
                  hint: 'Nome do morador não cadastrado',
                  onChanged: (v) => _manualResidentName = v,
                ),
                const SizedBox(height: 12),
                _buildLabel('WhatsApp do morador'),
                _buildTextField(
                  value: _manualResidentWhatsapp,
                  hint: 'Whatsapp do morador: (62) 9 9999-9999',
                  onChanged: (v) => _manualResidentWhatsapp = v,
                ),
                const SizedBox(height: 16),
              ],
            ],

            // ── Data ──────────────────────────────────
            Center(child: Column(children: [
              _buildLabel('Data'),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _validityDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    builder: (ctx, child) => Theme(
                      data: Theme.of(ctx).copyWith(
                        colorScheme: ColorScheme.light(primary: AppColors.primary),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) setState(() => _validityDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white,
                  ),
                  child: Text(
                    '${_validityDate.day.toString().padLeft(2, '0')}/${_validityDate.month.toString().padLeft(2, '0')}/${_validityDate.year}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ])),
            const SizedBox(height: 16),

            // ── Nome do visitante ─────────────────────
            _buildLabel('Nome do visitante'),
            TextField(
              controller: _guestNameCtrl,
              decoration: _inputDecoration('Nome do visitante'),
            ),
            const SizedBox(height: 16),

            // ── WhatsApp do visitante ──────────────────
            _buildLabel('WhatsApp do visitante'),
            TextField(
              controller: _visitorWhatsappCtrl,
              decoration: _inputDecoration('Whatsapp do visitante: (62) 9 9999-9999'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),

            // ── Observação ────────────────────────────
            _buildLabel('Observação'),
            TextField(
              controller: _observacaoCtrl,
              decoration: _inputDecoration('Colocar observação'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // ── Error ─────────────────────────────────
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(children: [
                  Icon(Icons.error_outline, color: Colors.red.shade600, size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_error!, style: TextStyle(fontSize: 13, color: Colors.red.shade600))),
                ]),
              ),

            // ── Submit button ─────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _handleSubmit,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.how_to_reg, size: 20),
                label: Text(_saving ? 'Registrando...' : 'Registrar visita', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ]),
        ),
      ]),
    );
  }

  // ── HELPERS ─────────────────────────────────────────────────────
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    Map<String, String>? itemLabels,
  }) {
    // Safety: if selected value not in items, reset
    final safeValue = value != null && items.contains(value) ? value : null;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          isExpanded: true,
          isDense: false,
          hint: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(hint, style: TextStyle(fontSize: 13, color: Colors.grey.shade400))),
          items: [
            DropdownMenuItem<String>(value: null, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(hint, style: TextStyle(fontSize: 13, color: Colors.grey.shade400)))),
            ...items.map((item) => DropdownMenuItem<String>(
              value: item,
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(itemLabels?[item] ?? item, style: const TextStyle(fontSize: 13))),
            )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String value,
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      onChanged: onChanged,
      decoration: _inputDecoration(hint),
      controller: TextEditingController(text: value),
    );
  }
}
