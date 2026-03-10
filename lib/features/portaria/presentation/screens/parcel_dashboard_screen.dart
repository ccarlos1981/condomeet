import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:signature/signature.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/core/utils/structure_helper.dart';
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/core/di/injection_container.dart';
import '../../../parcels/presentation/bloc/parcel_bloc.dart';
import '../../../parcels/presentation/bloc/parcel_event.dart';
import '../../../parcels/presentation/bloc/parcel_state.dart';
import '../../../portaria/domain/entities/parcel.dart';
import '../../../portaria/domain/repositories/parcel_repository.dart';

const _tipoIcons = {
  'caixa': '📦',
  'envelope': '✉️',
  'pacote': '🛍️',
  'notif_judicial': '⚖️',
};

class ParcelDashboardScreen extends StatefulWidget {
  final String residentId;

  const ParcelDashboardScreen({super.key, required this.residentId});

  @override
  State<ParcelDashboardScreen> createState() => _ParcelDashboardScreenState();
}

class _ParcelDashboardScreenState extends State<ParcelDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _fullscreenPhotoUrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    context.read<ParcelBloc>().add(WatchPendingParcelsRequested(widget.residentId));
    final condoId = context.read<AuthBloc>().state.condominiumId;
    if (condoId != null) {
      context.read<ParcelBloc>().add(FetchParcelHistoryRequested(
        residentId: widget.residentId,
        condominiumId: condoId,
      ));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showDarBaixaModal(Parcel parcel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DarBaixaSheet(
        parcel: parcel,
        onConfirmed: () {
          // Refresh list
          context.read<ParcelBloc>().add(WatchPendingParcelsRequested(widget.residentId));
          final condoId = context.read<AuthBloc>().state.condominiumId;
          if (condoId != null) {
            context.read<ParcelBloc>().add(FetchParcelHistoryRequested(
              residentId: widget.residentId,
              condominiumId: condoId,
            ));
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Minhas Encomendas'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [Tab(text: 'Pendentes'), Tab(text: 'Histórico')],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [_buildPendingTab(), _buildHistoryTab()],
          ),
          if (_fullscreenPhotoUrl != null) _buildFullscreenPhoto(),
        ],
      ),
    );
  }

  Widget _buildPendingTab() {
    return BlocBuilder<ParcelBloc, ParcelState>(
      builder: (context, state) {
        if (state is ParcelLoading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        if (state is ParcelError) return Center(child: Text(state.message, style: const TextStyle(color: Colors.red)));
        if (state is ParcelLoaded) {
          final parcels = state.pendingParcels;
          if (parcels.isEmpty) return _buildEmptyState(icon: Icons.inventory_2_outlined, title: 'Tudo limpo!', message: 'Nenhuma encomenda aguardando você.');
          return _buildParcelList(parcels, isPending: true);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildHistoryTab() {
    return BlocBuilder<ParcelBloc, ParcelState>(
      builder: (context, state) {
        if (state is ParcelLoading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        if (state is ParcelLoaded) {
          final parcels = state.historyParcels;
          if (parcels.isEmpty) return _buildEmptyState(icon: Icons.history, title: 'Histórico vazio', message: 'Suas encomendas entregues aparecerão aqui.');
          return _buildParcelList(parcels, isPending: false);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 80, color: const Color(0xFFCED4DA)),
          const SizedBox(height: 24),
          Text(title, style: AppTypography.h2),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary)),
        ]),
      ),
    );
  }

  Widget _buildParcelList(List<Parcel> parcels, {required bool isPending}) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: parcels.length,
      itemBuilder: (context, index) => _buildParcelCard(parcels[index], isPending),
    );
  }

  Widget _buildParcelCard(Parcel parcel, bool isPending) {
    final authState = context.read<AuthBloc>().state;
    final unitName = StructureHelper.getFullUnitName(authState.tipoEstrutura, parcel.block, parcel.unitNumber);
    final tipoIcon = _tipoIcons[parcel.tipo] ?? '📦';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('$tipoIcon ${parcel.tipo != null ? _tipoLabelShort(parcel.tipo!) : "Encomenda"}',
                      style: AppTypography.h3.copyWith(color: isPending ? AppColors.primary : AppColors.textSecondary)),
                  if (isPending) const Icon(Icons.notifications_active, color: AppColors.primary, size: 20),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.home_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(unitName, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
                ]),
                if (parcel.trackingCode != null) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.pin_outlined, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(parcel.trackingCode!, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
                  ]),
                ],
              ]),
            ),

            // Photos column (package + signature)
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (parcel.photoUrl != null)
                _tappableThumb(parcel.photoUrl!, label: 'Foto'),
              if (parcel.pickupProofUrl != null) ...[
                const SizedBox(height: 6),
                _tappableThumb(parcel.pickupProofUrl!, label: 'Assinatura', isSignature: true),
              ],
            ]),
          ]),

          const Divider(height: 20),
          Row(children: [
            const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              'Chegada: ${_fmt(parcel.arrivalTime)}',
              style: AppTypography.bodySmall,
            ),
          ]),
          if (!isPending && parcel.deliveryTime != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
              const SizedBox(width: 6),
              Text('Retirada: ${_fmt(parcel.deliveryTime!)}',
                  style: AppTypography.bodySmall.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
            ]),
          ],
          // Pickup name badge
          if (!isPending && (parcel.pickedUpByName != null || parcel.pickedUpById != null)) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.person_outline, size: 14, color: Colors.green.shade700),
                const SizedBox(width: 4),
                Text(parcel.pickedUpByName ?? 'Morador', style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
          // Dar Baixa button
          if (isPending) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showDarBaixaModal(parcel),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Dar Baixa'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _tappableThumb(String url, {required String label, bool isSignature = false}) {
    return GestureDetector(
      onTap: url.startsWith('http') ? () => setState(() => _fullscreenPhotoUrl = url) : null,
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
            child: _buildImage(url, height: 56, width: 56),
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 9, color: AppColors.textSecondary)),
      ]),
    );
  }

  String _tipoLabelShort(String tipo) {
    const labels = {
      'caixa': 'Caixa',
      'envelope': 'Envelope',
      'pacote': 'Pacote',
      'notif_judicial': 'Notif. Judicial',
    };
    return labels[tipo] ?? tipo;
  }

  String _fmt(DateTime dt) => '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} às ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';

  Widget _buildImage(String url, {double height = 180, double? width}) {
    if (url.startsWith('http')) {
      return Image.network(url, height: height, width: width ?? double.infinity, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(height));
    }
    final file = File(url);
    if (file.existsSync()) {
      return Image.file(file, height: height, width: width ?? double.infinity, fit: BoxFit.cover);
    }
    return _buildPlaceholder(height);
  }

  Widget _buildPlaceholder(double height) {
    return Container(height: height, width: double.infinity, color: Colors.grey.shade100,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.inventory_2, color: Colors.grey.shade400, size: 40),
          const SizedBox(height: 8),
          Text('Imagem não disponível', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        ]));
  }

  Widget _buildFullscreenPhoto() {
    return GestureDetector(
      onTap: () => setState(() => _fullscreenPhotoUrl = null),
      child: Container(
        color: Colors.black.withOpacity(0.9),
        child: Stack(children: [
          Center(
            child: InteractiveViewer(
              child: Image.network(_fullscreenPhotoUrl!, fit: BoxFit.contain),
            ),
          ),
          const Positioned(top: 40, right: 16,
            child: Icon(Icons.close, color: Colors.white, size: 32)),
        ]),
      ),
    );
  }
}

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
      final supabase = Supabase.instance.client;
      final residents = await supabase
          .from('perfil')
          .select('id, nome_completo')
          .eq('bloco_txt', widget.parcel.block)
          .eq('apto_txt', widget.parcel.unitNumber)
          .neq('papel_sistema', 'portaria');
      setState(() {
        _residents = List<Map<String, dynamic>>.from(residents);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // Recipient selection is optional — condominium decides if it's required.
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
      // Signature upload failed — don't block the overall confirm
      debugPrint('⚠️ Signature upload failed: $e');
      return null;
    }
  }

  Future<void> _confirm() async {
    if (!_canConfirm) return;
    setState(() => _isConfirming = true);

    // Upload signature (optional — failure is non-blocking)
    final signatureUrl = await _uploadSignature();

    final repo = sl<ParcelRepository>();
    final result = await repo.markAsDelivered(
      widget.parcel.id,
      pickupProofUrl: signatureUrl,
      pickedUpById: _isThirdParty ? null : _selectedResidentId,
      pickedUpByName: _isThirdParty
          ? _thirdPartyCtrl.text.trim()
          : _selectedResidentName,
    );

    if (mounted) {
      if (result is Success) {
        Navigator.of(context).pop();
        widget.onConfirmed();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(signatureUrl != null
                ? '✅ Baixa confirmada com assinatura!'
                : '✅ Baixa confirmada!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() => _isConfirming = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text((result as Failure).message),
            backgroundColor: AppColors.error,
          ),
        );
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Row(children: [
              const Icon(Icons.check_circle_outline, color: AppColors.primary),
              const SizedBox(width: 10),
              Text('Dar Baixa na Encomenda', style: AppTypography.h2),
            ]),
            const SizedBox(height: 6),
            Text('${widget.parcel.block} / Apto ${widget.parcel.unitNumber}',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
            const Divider(height: 28),

            // ── RECIPIENT SECTION ──────────────────────────────────────────
            if (_isLoading)
              const Center(child: CircularProgressIndicator(color: AppColors.primary))
            else ...[
              Text('Entregue á:', style: AppTypography.label),
              const SizedBox(height: 10),
              if (_residents.isEmpty)
                Text('Nenhum morador encontrado para este apto.',
                    style: TextStyle(color: AppColors.textSecondary))
              else
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedResidentId,
                      isExpanded: true,
                      hint: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('Selecionar morador...'),
                      ),
                      items: _residents.map((r) => DropdownMenuItem<String>(
                        value: r['id'] as String,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(r['nome_completo'] as String? ?? 'Morador'),
                        ),
                      )).toList(),
                      onChanged: _isThirdParty ? null : (val) {
                        setState(() {
                          _selectedResidentId = val;
                          _selectedResidentName = _residents
                              .firstWhere((r) => r['id'] == val)['nome_completo'] as String?;
                        });
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Third party toggle
              Row(children: [
                Checkbox(
                  value: _isThirdParty,
                  onChanged: (v) => setState(() {
                    _isThirdParty = v ?? false;
                    if (_isThirdParty) _selectedResidentId = null;
                  }),
                  activeColor: AppColors.primary,
                ),
                const SizedBox(width: 4),
                Text('Entregar a terceiro(a):', style: AppTypography.label),
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
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
              ],
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
                color: _hasSigned ? Colors.white : const Color(0xFFF8F9FA),
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
                        Text(
                          'Assine aqui',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        ),
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
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text(
                        'Confirmar Retirada',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
