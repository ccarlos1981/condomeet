import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:signature/signature.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/core/di/injection_container.dart';
import 'package:condomeet/shared/utils/structure_labels.dart';
import '../../domain/entities/parcel.dart';
import '../../domain/repositories/parcel_repository.dart';

const _tipoIcons = {
  'caixa': '📦',
  'envelope': '✉️',
  'pacote': '🛍️',
  'notif_judicial': '⚖️',
};

const _tipoLabels = {
  'caixa': 'Caixa',
  'envelope': 'Envelope',
  'pacote': 'Pacote',
  'notif_judicial': 'Notif. Judicial',
};

enum _Filter { todos, aguardando, entregues }

class PendingDeliveriesScreen extends StatefulWidget {
  const PendingDeliveriesScreen({super.key});

  @override
  State<PendingDeliveriesScreen> createState() => _PendingDeliveriesScreenState();
}

class _PendingDeliveriesScreenState extends State<PendingDeliveriesScreen> {
  static const _itemsPerPage = 10;

  _Filter _filter = _Filter.todos;
  String? _filterBloco;
  String? _filterApto;
  int _currentPage = 1;

  List<Parcel> _parcels = []; // current page of results
  int _totalFiltered = 0;
  int _pendingStat = 0;
  int _deliveredStat = 0;
  bool _isLoading = true;
  String? _error;
  String? _fullscreenUrl;
  int _fetchId = 0; // race condition guard

  // Structural data for filter dropdowns
  List<String> _allBlocos = [];
  Map<String, List<String>> _allAptosMap = {};

  @override
  void initState() {
    super.initState();
    _loadStructuralData();
    _fetchParcels();
  }

  /// Loads blocos/aptos from structural tables for filter dropdowns (once)
  Future<void> _loadStructuralData() async {
    final condoId = context.read<AuthBloc>().state.condominiumId;
    if (condoId == null) return;
    final supabase = Supabase.instance.client;

    final blocosRes = await supabase
        .from('blocos')
        .select('nome_ou_numero')
        .eq('condominio_id', condoId)
        .gt('nome_ou_numero', '0');
    final aptosRes = await supabase
        .from('apartamentos')
        .select('numero')
        .eq('condominio_id', condoId)
        .gt('numero', '0');

    // Natural numeric sort
    int numericCompare(String a, String b) {
      final na = int.tryParse(a);
      final nb = int.tryParse(b);
      if (na != null && nb != null) return na.compareTo(nb);
      return a.compareTo(b);
    }

    final blocos = (blocosRes as List)
        .map((b) => b['nome_ou_numero'] as String? ?? '')
        .where((b) => b.isNotEmpty)
        .toSet()
        .toList()
      ..sort(numericCompare);
    final aptos = (aptosRes as List)
        .map((a) => a['numero'] as String? ?? '')
        .where((a) => a.isNotEmpty)
        .toSet()
        .toList()
      ..sort(numericCompare);
    final aptosMap = <String, List<String>>{};
    for (final bloco in blocos) {
      aptosMap[bloco] = aptos;
    }

    if (mounted) setState(() { _allBlocos = blocos; _allAptosMap = aptosMap; });
  }

  /// Server-side fetch: queries Supabase with current filters + pagination
  Future<void> _fetchParcels() async {
    final condoId = context.read<AuthBloc>().state.condominiumId;
    if (condoId == null) return;

    final fetchId = ++_fetchId;
    setState(() { _isLoading = true; _error = null; });

    try {
      final supabase = Supabase.instance.client;
      final rangeFrom = (_currentPage - 1) * _itemsPerPage;
      final rangeTo = rangeFrom + _itemsPerPage - 1;

      // ── Build filter base ─────────────────────────────────────────────
      // Apply all .eq() filters BEFORE .order() since order() returns
      // PostgrestTransformBuilder which doesn't expose filter methods.

      var dataFilter = supabase
          .from('encomendas')
          .select('''
            id, resident_id, condominio_id, status, arrival_time, delivery_time,
            photo_url, pickup_proof_url, tipo, tracking_code, observacao,
            registered_by, picked_up_by_id, picked_up_by_name, bloco, apto, created_at,
            perfil!encomendas_resident_id_fkey(nome_completo, apto_txt, bloco_txt)
          ''')
          .eq('condominio_id', condoId);

      var countFilter = supabase.from('encomendas').select('id').eq('condominio_id', condoId);
      var pendingFilter = supabase.from('encomendas').select('id').eq('condominio_id', condoId).eq('status', 'pending');
      var deliveredFilter = supabase.from('encomendas').select('id').eq('condominio_id', condoId).eq('status', 'delivered');

      // Apply status filter to data + count queries
      if (_filter == _Filter.aguardando) {
        dataFilter = dataFilter.eq('status', 'pending');
        countFilter = countFilter.eq('status', 'pending');
      } else if (_filter == _Filter.entregues) {
        dataFilter = dataFilter.eq('status', 'delivered');
        countFilter = countFilter.eq('status', 'delivered');
      }

      // Apply bloco/apto to all queries
      if (_filterBloco != null) {
        dataFilter = dataFilter.eq('bloco', _filterBloco!);
        countFilter = countFilter.eq('bloco', _filterBloco!);
        pendingFilter = pendingFilter.eq('bloco', _filterBloco!);
        deliveredFilter = deliveredFilter.eq('bloco', _filterBloco!);
      }
      if (_filterApto != null) {
        dataFilter = dataFilter.eq('apto', _filterApto!);
        countFilter = countFilter.eq('apto', _filterApto!);
        pendingFilter = pendingFilter.eq('apto', _filterApto!);
        deliveredFilter = deliveredFilter.eq('apto', _filterApto!);
      }

      // Execute queries separately (different return types: List vs int)
      final dataFuture = dataFilter.order('created_at', ascending: false).range(rangeFrom, rangeTo);
      final countFuture = countFilter.count(CountOption.exact);
      final pendingFuture = pendingFilter.count(CountOption.exact);
      final deliveredFuture = deliveredFilter.count(CountOption.exact);

      // Await all
      final dataRows = await dataFuture;
      final countResult = await countFuture;
      final pendingResult = await pendingFuture;
      final deliveredResult = await deliveredFuture;

      final totalCount = countResult.count;
      final pendingCount = pendingResult.count;
      final deliveredCount = deliveredResult.count;

      // Race condition guard
      if (fetchId != _fetchId) return;

      final parcels = (dataRows as List).map<Parcel>((row) {
        final raw = row['perfil'];
        final perfil = (raw is Map) ? raw as Map<String, dynamic> : null;

        final bloco = (row['bloco'] as String?)?.isNotEmpty == true
            ? row['bloco'] as String
            : (perfil?['bloco_txt'] as String?) ?? '?';
        final apto = (row['apto'] as String?)?.isNotEmpty == true
            ? row['apto'] as String
            : (perfil?['apto_txt'] as String?) ?? '?';

        return Parcel(
          id: row['id'] as String? ?? '',
          residentId: row['resident_id'] as String?,
          residentName: (perfil?['nome_completo'] as String?) ?? 'Sem morador',
          unitNumber: apto,
          block: bloco,
          arrivalTime: row['arrival_time'] != null
              ? DateTime.tryParse(row['arrival_time'] as String) ?? DateTime.now()
              : DateTime.now(),
          deliveryTime: row['delivery_time'] != null
              ? DateTime.tryParse(row['delivery_time'] as String)
              : null,
          photoUrl: row['photo_url'] as String?,
          pickupProofUrl: row['pickup_proof_url'] as String?,
          status: row['status'] as String? ?? 'pending',
          condominiumId: row['condominio_id'] as String?,
          tipo: row['tipo'] as String?,
          trackingCode: row['tracking_code'] as String?,
          observacao: row['observacao'] as String?,
          registeredBy: row['registered_by'] as String?,
          pickedUpById: row['picked_up_by_id'] as String?,
          pickedUpByName: row['picked_up_by_name'] as String?,
        );
      }).toList();

      if (fetchId != _fetchId) return;

      if (mounted) {
        setState(() {
          _parcels = parcels;
          _totalFiltered = totalCount;
          _pendingStat = pendingCount;
          _deliveredStat = deliveredCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (fetchId == _fetchId && mounted) {
        setState(() { _error = 'Erro ao carregar: $e'; _isLoading = false; });
      }
    }
  }

  void _onFilterChanged({_Filter? filter, String? bloco, String? apto, bool resetApto = false}) {
    setState(() {
      if (filter != null) _filter = filter;
      if (bloco != null || resetApto) _filterBloco = bloco;
      if (apto != null || resetApto) _filterApto = resetApto ? null : apto;
      _currentPage = 1;
    });
    _fetchParcels();
  }

  int get _totalPages => (_totalFiltered / _itemsPerPage).ceil().clamp(1, 9999);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Encomendas do Condomínio'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pushNamed('/parcel-registration').then((_) => _fetchParcels()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nova', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchParcels,
          ),
        ],
      ),
      body: Stack(
        children: [
          _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _buildBody(),
          if (_fullscreenUrl != null) _buildFullscreen(),
        ],
      ),
    );
  }

  Widget _buildFullscreen() {
    return GestureDetector(
      onTap: () => setState(() => _fullscreenUrl = null),
      child: Container(
        color: Colors.black.withValues(alpha: 0.92),
        child: Stack(children: [
          Center(
            child: InteractiveViewer(
              child: Image.network(
                _fullscreenUrl!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white, size: 64),
              ),
            ),
          ),
          Positioned(
            top: 48, right: 20,
            child: GestureDetector(
              onTap: () => setState(() => _fullscreenUrl = null),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 24),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildBody() {
    final total = _pendingStat + _deliveredStat;

    return Column(children: [
      // ── Stats row
      _buildStats(total, _pendingStat, _deliveredStat),

      // ── Filter chips + dropdowns
      _buildFilters(),

      // ── Count label
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(children: [
          _isLoading
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.textSecondary))
              : Icon(Icons.sync, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text('$_totalFiltered encomenda${_totalFiltered != 1 ? 's' : ''}',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ]),
      ),

      // ── List
      Expanded(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _parcels.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _parcels.length,
                    itemBuilder: (_, i) => _buildCard(_parcels[i]),
                  ),
      ),

      // ── Pagination controls
      if (_totalPages > 1)
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
              onPressed: _currentPage > 1 ? () { setState(() => _currentPage--); _fetchParcels(); } : null,
              icon: const Icon(Icons.chevron_left),
              color: AppColors.primary,
            ),
            Text(
              'Página $_currentPage de $_totalPages',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
            IconButton(
              onPressed: _currentPage < _totalPages ? () { setState(() => _currentPage++); _fetchParcels(); } : null,
              icon: const Icon(Icons.chevron_right),
              color: AppColors.primary,
            ),
          ]),
        ),
    ]);
  }

  Widget _buildStats(int total, int pending, int delivered) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        _statBox('Total', total.toString(), AppColors.primary),
        _divider(),
        _statBox('Aguardando', pending.toString(), Colors.orange),
        _divider(),
        _statBox('Entregues', delivered.toString(), Colors.green),
      ]),
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Expanded(
      child: Column(children: [
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }

  Widget _divider() => Container(height: 36, width: 1, color: AppColors.border);

  Widget _buildFilters() {
    final aptos = _filterBloco != null && _allAptosMap.containsKey(_filterBloco)
        ? _allAptosMap[_filterBloco]!
        : <String>[];

    // Safety: if selected value is not in items, pass null to avoid assertion error
    final safeBloco = (_filterBloco != null && _allBlocos.contains(_filterBloco)) ? _filterBloco : null;
    final safeApto = (_filterApto != null && aptos.contains(_filterApto)) ? _filterApto : null;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(children: [
        // Status filter chips
        Row(children: [
          _filterChip('Todos', _Filter.todos),
          const SizedBox(width: 8),
          _filterChip('Aguardando', _Filter.aguardando),
          const SizedBox(width: 8),
          _filterChip('Entregues', _Filter.entregues),
        ]),
        const SizedBox(height: 10),
        // Bloco + Apto dropdowns
        Row(children: [
          Expanded(child: _buildDropdown(
            value: safeBloco,
            hint: getBlocoLabel(context.read<AuthBloc>().state.tipoEstrutura),
            items: _allBlocos,
            onChanged: (v) => _onFilterChanged(bloco: v, resetApto: true),
          )),
          const SizedBox(width: 10),
          Expanded(child: _buildDropdown(
            value: safeApto,
            hint: getAptoLabel(context.read<AuthBloc>().state.tipoEstrutura),
            items: aptos,
            onChanged: (v) => _onFilterChanged(apto: v),
          )),
        ]),
      ]),
    );
  }

  Widget _filterChip(String label, _Filter value) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => _onFilterChanged(filter: value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(label, style: TextStyle(
          color: selected ? Colors.white : AppColors.textSecondary,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        )),
      ),
    );
  }

  Widget _buildDropdown({required String? value, required String hint, required List<String> items, required ValueChanged<String?> onChanged}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          hint: Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(hint, style: const TextStyle(fontSize: 13))),
          items: [
            DropdownMenuItem(value: null, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('Todos $hint', style: const TextStyle(fontSize: 13)))),
            ...items.map((b) => DropdownMenuItem(value: b, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(b, style: const TextStyle(fontSize: 13))))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildCard(Parcel parcel) {
    final isPending = parcel.status == 'pending';
    final tipoIcon = _tipoIcons[parcel.tipo] ?? '📦';
    final tipoLabel = _tipoLabels[parcel.tipo] ?? parcel.tipo ?? 'Encomenda';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPending ? AppColors.success.withValues(alpha: 0.08) : AppColors.info.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header row
          Row(children: [
            Text('${parcel.block} / ${getAptoLabel(context.read<AuthBloc>().state.tipoEstrutura)} ${parcel.unitNumber}',
                style: AppTypography.h3.copyWith(fontSize: 15)),
            const Spacer(),
            // Tipo badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$tipoIcon $tipoLabel',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.warning)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(parcel.residentName, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),

          const Divider(height: 16),

          // Details row
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Chegada', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                Text(_fmt(parcel.arrivalTime), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                if (parcel.trackingCode != null) ...[
                  const SizedBox(height: 6),
                  Text('Rastreio', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  Text(parcel.trackingCode!, style: const TextStyle(fontSize: 13)),
                ],
                if (parcel.observacao != null) ...[
                  const SizedBox(height: 6),
                  Text('Observação', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  Text(parcel.observacao!, style: const TextStyle(fontSize: 13)),
                ],
                const SizedBox(height: 8),
                // Status line
                if (!isPending && parcel.deliveryTime != null)
                  Row(children: [
                    const Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
                    const SizedBox(width: 4),
                    Text('Retirado ${_fmt(parcel.deliveryTime!)}',
                        style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600)),
                  ]),
                if (isPending) ...[
                  // Dar Baixa button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showDarBaixaModal(parcel),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Dar Baixa', style: TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ]),
            ),

            // Photos column (parcel + signature)
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (parcel.photoUrl != null)
                _tappableThumb(parcel.photoUrl!, label: 'Foto'),
              if (parcel.pickupProofUrl != null) ...[
                const SizedBox(height: 6),
                _tappableThumb(parcel.pickupProofUrl!, label: 'Assinatura', isSignature: true),
              ],
            ]),
          ]),
        ]),
      ),
    );
  }

  Widget _tappableThumb(String url, {required String label, bool isSignature = false}) {
    return GestureDetector(
      onTap: url.startsWith('http') ? () => setState(() => _fullscreenUrl = url) : null,
      child: Column(children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSignature ? AppColors.primary.withValues(alpha: 0.4) : Colors.grey.shade200,
              width: isSignature ? 1.5 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: _buildThumb(url, size: 56),
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 9, color: AppColors.textSecondary)),
      ]),
    );
  }

  Widget _buildThumb(String url, {double size = 56}) {
    if (url.startsWith('http')) {
      return Image.network(url, width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _photoIcon(size));
    }
    final f = File(url);
    if (f.existsSync()) return Image.file(f, width: size, height: size, fit: BoxFit.cover);
    return _photoIcon(size);
  }

  Widget _photoIcon([double size = 56]) => Container(
      width: size, height: size, color: AppColors.surfaceAlt,
      child: const Icon(Icons.inventory_2, color: AppColors.disabledIcon, size: 24));

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.disabledIcon),
        const SizedBox(height: 16),
        Text('Nenhuma encomenda', style: AppTypography.h2),
        const SizedBox(height: 8),
        Text('Nenhum resultado para os filtros aplicados.',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center),
      ]),
    );
  }

  String _fmt(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}, ${local.hour}:${local.minute.toString().padLeft(2, '0')}';
  }

  void _showDarBaixaModal(Parcel parcel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DarBaixaSheet(
        parcel: parcel,
        onConfirmed: _fetchParcels,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Dar Baixa Bottom Sheet (reused from parcel_dashboard)
// ─────────────────────────────────────────────

class _DarBaixaSheet extends StatefulWidget {
  final Parcel parcel;
  final VoidCallback onConfirmed;
  const _DarBaixaSheet({required this.parcel, required this.onConfirmed});

  @override
  State<_DarBaixaSheet> createState() => _DarBaixaSheetState();
}

class _DarBaixaSheetState extends State<_DarBaixaSheet> {
  List<Map<String, dynamic>> _residents = [];
  String? _selectedResidentId;
  String? _selectedResidentName;
  bool _isThirdParty = false;
  final _thirdPartyCtrl = TextEditingController();
  bool _isLoading = true;
  bool _isConfirming = false;

  // Signature
  late final SignatureController _sigCtrl;
  bool _hasSigned = false;

  @override
  void initState() {
    super.initState();
    _sigCtrl = SignatureController(
      penStrokeWidth: 2.5,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    _sigCtrl.addListener(() {
      if (_sigCtrl.isNotEmpty && !_hasSigned) setState(() => _hasSigned = true);
    });
    _loadResidents();
  }

  @override
  void dispose() {
    _sigCtrl.dispose();
    _thirdPartyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadResidents() async {
    try {
      final data = await Supabase.instance.client
          .from('perfil')
          .select('id, nome_completo')
          .eq('bloco_txt', widget.parcel.block)
          .eq('apto_txt', widget.parcel.unitNumber)
          .neq('papel_sistema', 'portaria');
      setState(() {
        _residents = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // Recipient selection is optional — condominium decides if it's required.
  // The confirm button is always enabled; empty recipient is stored as null.
  bool get _canConfirm => true;

  /// Uploads the signature PNG to Supabase Storage and returns its public URL.
  Future<String?> _uploadSignature() async {
    if (_sigCtrl.isEmpty) return null;
    try {
      final bytes = await _sigCtrl.toPngBytes();
      if (bytes == null) return null;
      final supabase = Supabase.instance.client;
      final path = 'signatures/${widget.parcel.id}_sig.png';
      await supabase.storage.from('parcel-photos').uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(contentType: 'image/png', upsert: true),
      );
      return supabase.storage.from('parcel-photos').getPublicUrl(path);
    } catch (e) {
      debugPrint('⚠️ Signature upload failed: $e');
      return null;
    }
  }

  Future<void> _confirm() async {
    if (!_canConfirm) return;
    setState(() => _isConfirming = true);
    HapticFeedback.mediumImpact();

    // Upload signature (optional — failure is non-blocking)
    final signatureUrl = await _uploadSignature();

    final repo = sl<ParcelRepository>();
    final result = await repo.markAsDelivered(
      widget.parcel.id,
      pickupProofUrl: signatureUrl,
      pickedUpById: _isThirdParty ? null : _selectedResidentId,
      pickedUpByName: _isThirdParty ? _thirdPartyCtrl.text.trim() : _selectedResidentName,
    );

    if (mounted) {
      if (result is Success) {
        Navigator.of(context).pop();
        widget.onConfirmed();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(signatureUrl != null
              ? '✅ Baixa confirmada com assinatura!'
              : '✅ Baixa confirmada!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      } else {
        setState(() => _isConfirming = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text((result as Failure).message),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Row(children: [
            const Icon(Icons.check_circle_outline, color: AppColors.primary),
            const SizedBox(width: 10),
            Text('Dar Baixa na Encomenda', style: AppTypography.h2),
          ]),
          const SizedBox(height: 4),
          Text('${widget.parcel.block} / ${getAptoLabel(context.read<AuthBloc>().state.tipoEstrutura)} ${widget.parcel.unitNumber}',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
          const Divider(height: 28),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: AppColors.primary))
          else ...[
            Text('Entregue a:', style: AppTypography.label),
            const SizedBox(height: 10),
            if (_residents.isNotEmpty)
              Container(
                decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedResidentId,
                    isExpanded: true,
                    hint: const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Selecionar morador...')),
                    items: _residents.map((r) => DropdownMenuItem<String>(
                      value: r['id'] as String,
                      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(r['nome_completo'] as String? ?? 'Morador')),
                    )).toList(),
                    onChanged: _isThirdParty ? null : (v) {
                      setState(() {
                        _selectedResidentId = v;
                        _selectedResidentName = _residents.firstWhere((r) => r['id'] == v)['nome_completo'] as String?;
                      });
                    },
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(children: [
              Checkbox(value: _isThirdParty, onChanged: (v) => setState(() { _isThirdParty = v ?? false; if (_isThirdParty) _selectedResidentId = null; }), activeColor: AppColors.primary),
              const SizedBox(width: 4),
              const Text('Terceiro(a)'),
            ]),
            if (_isThirdParty) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _thirdPartyCtrl,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Nome de quem está retirando',
                  prefixIcon: const Icon(Icons.person_outline, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primary, width: 2)),
                ),
              ),
            ],

            // ── SIGNATURE SECTION ──────────────────────────────────────────
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.draw_outlined, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('Assinatura do recebedor', style: AppTypography.label),
                  const SizedBox(width: 6),
                  Text('(opcional)', style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  )),
                ]),
                if (_hasSigned)
                  TextButton.icon(
                    onPressed: () {
                      _sigCtrl.clear();
                      setState(() => _hasSigned = false);
                    },
                    icon: const Icon(Icons.clear, size: 14),
                    label: const Text('Limpar', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: _hasSigned ? Colors.white : AppColors.surface,
                border: Border.all(
                  color: _hasSigned ? AppColors.primary : Colors.grey.shade300,
                  width: _hasSigned ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Stack(children: [
                  Signature(
                    controller: _sigCtrl,
                    backgroundColor: Colors.transparent,
                    width: double.infinity,
                    height: 160,
                  ),
                  if (!_hasSigned)
                    Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.gesture, color: Colors.grey.shade400, size: 32),
                        const SizedBox(height: 8),
                        Text('Assine aqui', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                      ]),
                    ),
                ]),
              ),
            ),

            // ── CONFIRM BUTTON ─────────────────────────────────────────────
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canConfirm && !_isConfirming ? _confirm : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isConfirming
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Confirmar Retirada', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
