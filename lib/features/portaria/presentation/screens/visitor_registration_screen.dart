import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/shared/utils/structure_labels.dart';

const _tipoVisitanteOptions = [
  {'value': 'Uber ou Taxi', 'label': '🚗 Uber ou Taxi'},
  {'value': 'Delivery', 'label': '📦 Delivery'},
  {'value': 'Farmácia', 'label': '💊 Farmácia'},
  {'value': 'Diarista', 'label': '🧹 Diarista'},
  {'value': 'Visitante', 'label': '🧑 Visitante'},
  {'value': 'Mat. Obra', 'label': '🧱 Mat. Obra'},
  {'value': 'Serviços', 'label': '🔧 Serviços'},
  {'value': 'Hóspedes', 'label': '🏨 Hóspedes'},
  {'value': 'Outros', 'label': '📋 Outros'},
];

class VisitorRegistrationScreen extends StatefulWidget {
  const VisitorRegistrationScreen({super.key});

  @override
  State<VisitorRegistrationScreen> createState() =>
      _VisitorRegistrationScreenState();
}

class _VisitorRegistrationScreenState extends State<VisitorRegistrationScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late final TabController _tabController;

  // ── Block / Apt ──────────────────────────────────────────────
  List<Map<String, dynamic>> _blocos = [];
  List<Map<String, dynamic>> _aptos = [];
  Map<String, dynamic>? _selectedBloco;
  Map<String, dynamic>? _selectedApto;
  bool _loadingBlocos = true;
  bool _loadingAptos = false;

  // ── Form fields ──────────────────────────────────────────────
  final _cpfCtrl = TextEditingController();
  final _nomeCtrl = TextEditingController();
  final _wpCtrl = TextEditingController();
  final _empresaCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  String? _selectedTipo;

  // ── Photo ────────────────────────────────────────────────────
  XFile? _photo;
  bool _isUploadingPhoto = false;
  bool _isRegistering = false;

  // ── CPF search ───────────────────────────────────────────────
  Timer? _searchTimer;
  List<Map<String, dynamic>> _cpfSuggestions = [];
  bool _showSuggestions = false;
  Map<String, dynamic>? _lastVisit; // returning visitor data
  String? _existingPhotoUrl; // photo URL from last visit

  // ── Liberar tab (visitor history) ────────────────────────
  List<Map<String, dynamic>> _visitantes = [];
  bool _loadingVisitantes = true;
  int _visitanteLimit = 10;
  String _liberarFilter = 'pendente'; // 'pendente', 'todos', 'liberado'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBlocos();
    _loadVisitantes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cpfCtrl.dispose();
    _nomeCtrl.dispose();
    _wpCtrl.dispose();
    _empresaCtrl.dispose();
    _obsCtrl.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  // ── Load visitor history ─────────────────────────────────
  Future<void> _loadVisitantes() async {
    final condoId = context.read<AuthBloc>().state.condominiumId;
    if (condoId == null) return;
    try {
      final data = await _supabase
          .from('visitante_registros')
          .select('*')
          .eq('condominio_id', condoId)
          .order('entrada_at', ascending: false)
          .limit(_visitanteLimit);
      if (mounted) {
        setState(() {
          _visitantes = List<Map<String, dynamic>>.from(data);
          _loadingVisitantes = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingVisitantes = false);
    }
  }

  // ── Handle exit release ──────────────────────────────────
  Future<void> _handleRegistrarSaida(String id) async {
    try {
      await _supabase
          .from('visitante_registros')
          .update({'saida_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id);
      // Optimistic update
      setState(() {
        final idx = _visitantes.indexWhere((v) => v['id'] == id);
        if (idx >= 0) {
          _visitantes[idx] = {
            ..._visitantes[idx],
            'saida_at': DateTime.now().toIso8601String(),
          };
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Saída registrada com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao registrar saída: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ── Load blocos ──────────────────────────────────────────────
  Future<void> _loadBlocos() async {
    final condoId = context.read<AuthBloc>().state.condominiumId;
    if (condoId == null) return;
    try {
      final data = await _supabase
          .from('blocos')
          .select('id, nome_ou_numero')
          .eq('condominio_id', condoId)
          .neq('nome_ou_numero', '0')
          .order('nome_ou_numero');
      setState(() {
        _blocos = List<Map<String, dynamic>>.from(data);
        _loadingBlocos = false;
      });
    } catch (_) {
      setState(() => _loadingBlocos = false);
    }
  }

  Future<void> _onBlocoSelected(Map<String, dynamic>? bloco) async {
    setState(() {
      _selectedBloco = bloco;
      _selectedApto = null;
      _aptos = [];
      _loadingAptos = bloco != null;
    });
    if (bloco == null) return;

    final condoId = context.read<AuthBloc>().state.condominiumId ?? '';
    try {
      final data = await _supabase
          .from('unidades')
          .select('apartamento_id, apartamentos(numero)')
          .eq('condominio_id', condoId)
          .eq('bloco_id', bloco['id'])
          .order('apartamentos(numero)');

      final aptos = data.map<Map<String, dynamic>>((e) {
        final apto = e['apartamentos'];
        return {
          'id': e['apartamento_id'],
          'numero': apto is Map
              ? apto['numero']
              : (apto is List && apto.isNotEmpty ? apto[0]['numero'] : '?'),
        };
      }).where((e) => e['numero'] != '0').toList();

      setState(() {
        _aptos = aptos;
        _loadingAptos = false;
      });
    } catch (_) {
      setState(() => _loadingAptos = false);
    }
  }

  // ── CPF/RG search with debounce ──────────────────────────────
  void _onCpfChanged(String value) {
    final cleaned = value.replaceAll(RegExp(r'\D'), '');
    _searchTimer?.cancel();

    if (cleaned.length >= 3) {
      _searchTimer = Timer(const Duration(milliseconds: 400), () async {
        final condoId = context.read<AuthBloc>().state.condominiumId;
        if (condoId == null) return;
        try {
          final data = await _supabase
              .from('visitante_registros')
              .select('*')
              .eq('condominio_id', condoId)
              .ilike('cpf_rg', '$cleaned%')
              .order('entrada_at', ascending: false)
              .limit(5);

          // Deduplicate by cpf_rg (keep most recent)
          final seen = <String>{};
          final unique = (data as List).where((v) {
            final cpf = v['cpf_rg'] as String?;
            if (cpf == null || seen.contains(cpf)) return false;
            seen.add(cpf);
            return true;
          }).toList();

          if (mounted) {
            setState(() {
              _cpfSuggestions =
                  unique.map((e) => Map<String, dynamic>.from(e)).toList();
              _showSuggestions = unique.isNotEmpty;
            });
          }
        } catch (_) {}
      });
    } else {
      setState(() {
        _cpfSuggestions = [];
        _showSuggestions = false;
      });
      // Clear auto-filled fields
      if (_lastVisit != null) {
        _clearForm();
      }
    }
  }

  void _selectSuggestion(Map<String, dynamic> v) {
    _cpfCtrl.text = v['cpf_rg'] ?? '';
    _nomeCtrl.text = (v['nome'] ?? '').toString().trim();
    _wpCtrl.text = v['whatsapp'] ?? '';
    _selectedTipo = v['tipo_visitante'];
    _empresaCtrl.text = v['empresa'] ?? '';

    // Try to match bloco
    final blocoTxt = (v['bloco'] ?? '').toString().trim();
    final matchedBloco = _blocos.cast<Map<String, dynamic>?>().firstWhere(
        (b) => b!['nome_ou_numero'].toString() == blocoTxt,
        orElse: () => null);
    if (matchedBloco != null) {
      _onBlocoSelected(matchedBloco).then((_) {
        // Try to match apto after loading
        final aptoTxt = (v['apto'] ?? '').toString().trim();
        final matchedApto = _aptos.cast<Map<String, dynamic>?>().firstWhere(
            (a) => a!['numero'].toString() == aptoTxt,
            orElse: () => null);
        if (matchedApto != null && mounted) {
          setState(() => _selectedApto = matchedApto);
        }
      });
    }

    setState(() {
      _lastVisit = v;
      _existingPhotoUrl = v['foto_url'] as String?;
      _photo = null; // don't use a file, use URL
      _showSuggestions = false;
    });
  }

  void _clearForm() {
    _nomeCtrl.clear();
    _wpCtrl.clear();
    _empresaCtrl.clear();
    _obsCtrl.clear();
    setState(() {
      _selectedTipo = null;
      _selectedBloco = null;
      _selectedApto = null;
      _aptos = [];
      _photo = null;
      _lastVisit = null;
      _existingPhotoUrl = null;
    });
  }

  // ── Photo capture ────────────────────────────────────────────
  Future<void> _takePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primaryLight,
                child: Icon(Icons.camera_alt_outlined, color: AppColors.primary),
              ),
              title: const Text('Tirar foto com a câmera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primaryLight,
                child: Icon(Icons.photo_library_outlined,
                    color: AppColors.primary),
              ),
              title: const Text('Escolher da galeria'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    try {
      final photo = await picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );
      if (photo != null && mounted) {
        setState(() {
          _photo = photo;
          _existingPhotoUrl = null; // new photo overrides existing
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(source == ImageSource.camera
                ? 'Câmera não disponível. Use a galeria.'
                : 'Não foi possível acessar a galeria.'),
          ),
        );
      }
    }
  }

  Future<String?> _uploadPhoto(XFile photo) async {
    setState(() => _isUploadingPhoto = true);
    try {
      final condoId = context.read<AuthBloc>().state.condominiumId ?? '';
      final ext = photo.path.split('.').last;
      final fileName = '$condoId/${const Uuid().v4()}.$ext';
      final bytes = await photo.readAsBytes();
      await _supabase.storage.from('visitor-photos').uploadBinary(fileName,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'));
      return _supabase.storage.from('visitor-photos').getPublicUrl(fileName);
    } catch (e) {
      return null;
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  // ── Can submit? ──────────────────────────────────────────────
  bool get _canRegister =>
      _nomeCtrl.text.trim().isNotEmpty && _selectedTipo != null;

  // ── Handle registration ──────────────────────────────────────
  Future<void> _handleRegister() async {
    if (!_canRegister) return;
    setState(() => _isRegistering = true);
    HapticFeedback.mediumImpact();

    final authState = context.read<AuthBloc>().state;
    final condoId = authState.condominiumId ?? '';

    String? photoUrl;

    // Upload new photo if taken
    if (_photo != null) {
      photoUrl = await _uploadPhoto(_photo!);
    } else if (_existingPhotoUrl != null) {
      // Reuse returning visitor's photo
      photoUrl = _existingPhotoUrl;
    }

    // Determine bloco/apto text
    final blocoTxt = _selectedBloco?['nome_ou_numero']?.toString() ?? '';
    final aptoTxt = _selectedApto?['numero']?.toString() ?? '';

    try {
      await _supabase.from('visitante_registros').insert({
        'condominio_id': condoId,
        'nome': _nomeCtrl.text.trim(),
        'cpf_rg': _cpfCtrl.text.trim().isEmpty ? null : _cpfCtrl.text.trim(),
        'whatsapp': _wpCtrl.text.trim().isEmpty ? null : _wpCtrl.text.trim(),
        'tipo_visitante': _selectedTipo,
        'empresa':
            _empresaCtrl.text.trim().isEmpty ? null : _empresaCtrl.text.trim(),
        'bloco': blocoTxt.isEmpty ? null : blocoTxt,
        'apto': aptoTxt.isEmpty ? null : aptoTxt,
        'observacao':
            _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
        'foto_url': photoUrl,
        'registrado_por': authState.userId,
      });

      if (mounted) _showSuccess();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao registrar: $e'),
              backgroundColor: AppColors.error),
        );
        setState(() => _isRegistering = false);
      }
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _SuccessDialog(),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pop(); // dismiss dialog
        _clearForm();
        _cpfCtrl.clear();
        setState(() => _isRegistering = false);
        _loadVisitantes(); // refresh Liberar tab
      }
    });
  }

  // ════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final pendentes = _visitantes.where((v) => v['saida_at'] == null).length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Autorizar Visitante'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          tabs: [
            const Tab(icon: Icon(Icons.person_add_outlined), text: 'Registrar'),
            Tab(
              icon: Badge(
                isLabelVisible: pendentes > 0,
                label: Text('$pendentes', style: const TextStyle(fontSize: 10)),
                child: const Icon(Icons.exit_to_app_outlined),
              ),
              text: 'Liberar',
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            // ═══ TAB 1: Registration form ═══
            _buildRegistrationTab(),
            // ═══ TAB 2: Visitor history / release ═══
            _buildLiberarTab(),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 1 — Registration Form
  // ════════════════════════════════════════════════════════════
  Widget _buildRegistrationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── CPF/RG search ──────────────────────────────
          _buildCpfSearch(),
          const SizedBox(height: 20),

          // ── Returning visitor card ─────────────────────
          if (_lastVisit != null) ...[
            _buildReturningVisitorCard(),
            const SizedBox(height: 20),
          ],

          // ── Name ──────────────────────────────────────
          _buildTextField(
            controller: _nomeCtrl,
            label: 'Nome do Visitante',
            hint: 'Ex: João da Silva',
            icon: Icons.person_outline,
            required: true,
          ),
          const SizedBox(height: 16),

          // ── WhatsApp ──────────────────────────────────
          _buildTextField(
            controller: _wpCtrl,
            label: 'WhatsApp',
            hint: '(00) 00000-0000',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 20),

          // ── Tipo visitante ─────────────────────────────
          _buildTipoSelector(),
          const SizedBox(height: 16),

          // ── Empresa ───────────────────────────────────
          _buildTextField(
            controller: _empresaCtrl,
            label: 'Empresa',
            hint: 'Ex: Net, Eletricista...',
            icon: Icons.business_outlined,
          ),
          const SizedBox(height: 20),

          // ── Bloco / Apto ──────────────────────────────
          Row(children: [
            Expanded(child: _buildBlocoDropdown()),
            const SizedBox(width: 12),
            Expanded(child: _buildAptoDropdown()),
          ]),
          const SizedBox(height: 20),

          // ── Photo (only for new visitors) ──────────────
          if (_lastVisit == null) ...[
            _buildPhotoCapture(),
            const SizedBox(height: 20),
          ],

          // ── Observação ─────────────────────────────────
          _buildTextField(
            controller: _obsCtrl,
            label: 'Observação',
            hint: 'Ex: Mudança, manutenção...',
            icon: Icons.notes_outlined,
            maxLines: 3,
          ),
          const SizedBox(height: 28),

          // ── Submit ─────────────────────────────────────
          (_isRegistering || _isUploadingPhoto)
              ? Column(children: [
                  const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary)),
                  const SizedBox(height: 8),
                  Text(
                      _isUploadingPhoto
                          ? 'Enviando foto...'
                          : 'Registrando...',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary)),
                ])
              : CondoButton(
                  label: 'Registrar Entrada',
                  onPressed: _canRegister ? _handleRegister : null,
                ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 2 — Liberar (Visitor History)
  // ════════════════════════════════════════════════════════════
  Widget _buildLiberarTab() {
    if (_loadingVisitantes) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_visitantes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('Nenhum visitante registrado',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
          ],
        ),
      );
    }

    // Apply filter
    final filtered = _liberarFilter == 'todos'
        ? _visitantes
        : _liberarFilter == 'pendente'
            ? _visitantes.where((v) => v['saida_at'] == null).toList()
            : _visitantes.where((v) => v['saida_at'] != null).toList();

    final hasMore = _visitantes.length >= _visitanteLimit;

    return Column(
      children: [
        // Filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: [
              const Text('Status: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(width: 4),
              _buildLiberarChip('Pendentes', 'pendente', Colors.orange),
              const SizedBox(width: 6),
              _buildLiberarChip('Todos', 'todos', Colors.grey),
              const SizedBox(width: 6),
              _buildLiberarChip('Liberados', 'liberado', Colors.green),
            ],
          ),
        ),

        // List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text('Nenhum visitante ${_liberarFilter == 'pendente' ? 'pendente' : 'liberado'}',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length + (hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= filtered.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: TextButton.icon(
                onPressed: () {
                  setState(() => _visitanteLimit += 10);
                  _loadVisitantes();
                },
                icon: const Icon(Icons.expand_more),
                label: const Text('Carregar mais'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ),
          );
        }

        final v = _visitantes[index];
        final nome = v['nome'] ?? '';
        final bloco = v['bloco'] ?? '';
        final apto = v['apto'] ?? '';
        final rawFotoUrl = v['foto_url'] as String?;
        final fotoUrl = (rawFotoUrl != null && rawFotoUrl.startsWith('http')) ? rawFotoUrl : null;
        final entradaAt = v['entrada_at'] as String?;
        final saidaAt = v['saida_at'] as String?;
        final hasSaida = saidaAt != null;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasSaida ? Colors.green.shade100 : Colors.orange.shade100,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Photo
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
                  child: fotoUrl == null
                      ? Icon(Icons.person, color: Colors.grey.shade400)
                      : null,
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nome,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      if (bloco.isNotEmpty || apto.isNotEmpty)
                        Text('${getBlocoLabel(context.read<AuthBloc>().state.tipoEstrutura)} $bloco / ${getAptoLabel(context.read<AuthBloc>().state.tipoEstrutura)} $apto',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600)),
                      if (entradaAt != null)
                        Text('Entrada: ${_formatDate(entradaAt)}',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500)),
                      if (hasSaida)
                        Text('Saída: ${_formatDate(saidaAt)}',
                            style: TextStyle(
                                fontSize: 11, color: Colors.green.shade600)),
                    ],
                  ),
                ),
                // Action
                if (!hasSaida)
                  ElevatedButton(
                    onPressed: () => _handleRegistrarSaida(v['id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade500,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    child: const Text('Registrar\nSaída',
                        textAlign: TextAlign.center),
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('✅ Saiu',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700)),
                  ),
              ],
            ),
          ),
        );
      },
    ),
        ),
      ],
    );
  }

  Widget _buildLiberarChip(String label, String value, Color color) {
    final isActive = _liberarFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _liberarFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isActive ? color : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  // ── CPF/RG search widget ─────────────────────────────────────
  Widget _buildCpfSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CPF / RG', style: AppTypography.label),
        const SizedBox(height: 8),
        TextFormField(
          controller: _cpfCtrl,
          keyboardType: TextInputType.number,
          onChanged: _onCpfChanged,
          decoration: InputDecoration(
            hintText: 'Digite CPF ou RG para buscar...',
            prefixIcon: const Icon(Icons.search, color: AppColors.primary),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
        // Suggestion list
        if (_showSuggestions && _cpfSuggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _cpfSuggestions.map((v) {
                final nome = v['nome'] ?? '';
                final cpf = v['cpf_rg'] ?? '';
                final fotoUrl = v['foto_url'] as String?;
                return ListTile(
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primaryLight,
                    backgroundImage:
                        fotoUrl != null ? NetworkImage(fotoUrl) : null,
                    child: fotoUrl == null
                        ? const Icon(Icons.person, color: AppColors.primary)
                        : null,
                  ),
                  title: Text(nome,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('CPF/RG: $cpf',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  onTap: () => _selectSuggestion(v),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  // ── Returning visitor card ───────────────────────────────────
  Widget _buildReturningVisitorCard() {
    final nome = _lastVisit!['nome'] ?? '';
    final entrada = _lastVisit!['entrada_at'] ?? '';
    final fotoUrl = _existingPhotoUrl ?? _lastVisit!['foto_url'] as String?;
    final hasNewPhoto = _photo != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Visitante Retornando',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Large photo
          if (hasNewPhoto)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(_photo!.path),
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
              ),
            )
          else if (fotoUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                fotoUrl,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 200,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image,
                      size: 48, color: Colors.grey),
                ),
              ),
            )
          else
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person, size: 48, color: Colors.grey),
            ),

          const SizedBox(height: 12),
          Text(nome,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          if (entrada.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Última visita: ${_formatDate(entrada)}',
                style:
                    TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _takePhoto,
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: Text(hasNewPhoto ? 'Trocar foto' : 'Capturar outra foto',
                      style: const TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              if (hasNewPhoto) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _photo = null;
                      _existingPhotoUrl = _lastVisit?['foto_url'] as String?;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
                  ),
                  child: const Text('Manter original',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── Photo capture (new visitors) ─────────────────────────────
  Widget _buildPhotoCapture() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Foto do Visitante', style: AppTypography.label),
        const SizedBox(height: 4),
        Text('Opcional — recomendado para identificação',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _takePhoto,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _photo != null ? AppColors.primary : AppColors.border,
                width: _photo != null ? 2 : 1,
              ),
            ),
            child: _photo == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        Icon(Icons.camera_alt_outlined,
                            size: 44, color: AppColors.border),
                        const SizedBox(height: 8),
                        Text('Tocar para tirar foto',
                            style:
                                TextStyle(color: AppColors.textSecondary)),
                      ])
                : Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(File(_photo!.path),
                          width: double.infinity,
                          height: 160,
                          fit: BoxFit.cover),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.refresh,
                                  color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text('Trocar',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 12)),
                            ]),
                      ),
                    ),
                  ]),
          ),
        ),
      ],
    );
  }

  // ── Tipo visitante selector ──────────────────────────────────
  Widget _buildTipoSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('Tipo de Visitante', style: AppTypography.label),
          const Text(' *',
              style:
                  TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _tipoVisitanteOptions.map((opt) {
            final selected = _selectedTipo == opt['value'];
            return GestureDetector(
              onTap: () => setState(() => _selectedTipo = opt['value']),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.border,
                    width: selected ? 2 : 1,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                              color:
                                  AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2))
                        ]
                      : [],
                ),
                child: Text(
                  opt['label']!,
                  style: AppTypography.bodyMedium.copyWith(
                    color: selected
                        ? Colors.white
                        : AppColors.textSecondary,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Bloco dropdown ───────────────────────────────────────────
  Widget _buildBlocoDropdown() {
    final tipo = context.read<AuthBloc>().state.tipoEstrutura;
    final label = getBlocoLabel(tipo);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.label),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: _loadingBlocos
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary)))
              : DropdownButtonHideUnderline(
                  child: DropdownButton<Map<String, dynamic>>(
                    value: _selectedBloco,
                    isExpanded: true,
                    hint: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(label)),
                    items: _blocos
                        .map((b) => DropdownMenuItem(
                              value: b,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text('$label ${b['nome_ou_numero']}'),
                              ),
                            ))
                        .toList(),
                    onChanged: _onBlocoSelected,
                  ),
                ),
        ),
      ],
    );
  }

  // ── Apto dropdown ────────────────────────────────────────────
  Widget _buildAptoDropdown() {
    final tipo = context.read<AuthBloc>().state.tipoEstrutura;
    final label = getAptoLabel(tipo);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.label),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: _loadingAptos
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary)))
              : DropdownButtonHideUnderline(
                  child: DropdownButton<Map<String, dynamic>>(
                    value: _selectedApto,
                    isExpanded: true,
                    hint: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(label)),
                    items: _aptos
                        .map((a) => DropdownMenuItem(
                              value: a,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text('$label ${a['numero']}'),
                              ),
                            ))
                        .toList(),
                    onChanged: _selectedBloco == null
                        ? null
                        : (val) => setState(() => _selectedApto = val),
                  ),
                ),
        ),
      ],
    );
  }

  // ── Text field builder ───────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(required ? label : '$label (opcional)',
              style: AppTypography.label),
          if (required)
            const Text(' *',
                style: TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          onChanged: (_) => setState(() {}), // refresh _canRegister
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon:
                Icon(icon, color: AppColors.textSecondary, size: 20),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 2)),
          ),
        ),
      ],
    );
  }

  // ── Date formatting helper ───────────────────────────────────
  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// Success Dialog
// ═══════════════════════════════════════════════════════════════

class _SuccessDialog extends StatelessWidget {
  const _SuccessDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
                color: Colors.green.shade50, shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded,
                color: Colors.green, size: 56),
          ),
          const SizedBox(height: 20),
          Text('Entrada Registrada!', style: AppTypography.h1),
          const SizedBox(height: 8),
          Text('Visitante registrado com sucesso.',
              style: AppTypography.bodyLarge, textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
