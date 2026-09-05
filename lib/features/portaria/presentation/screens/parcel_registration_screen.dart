import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/shared/utils/structure_labels.dart';
import '../../domain/entities/parcel.dart';
import '../../domain/repositories/parcel_repository.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/core/di/injection_container.dart';
import 'package:condomeet/core/utils/error_sanitizer.dart';

const _tipoOptions = [
  {'value': 'caixa', 'label': '📦 Caixa'},
  {'value': 'envelope', 'label': '✉️ Envelope'},
  {'value': 'pacote', 'label': '🛍️ Pacote'},
  {'value': 'notif_judicial', 'label': '⚖️ Notif. Judicial'},
];

class ParcelRegistrationScreen extends StatefulWidget {
  const ParcelRegistrationScreen({super.key});

  @override
  State<ParcelRegistrationScreen> createState() => _ParcelRegistrationScreenState();
}

class _ParcelRegistrationScreenState extends State<ParcelRegistrationScreen> {
  late final ParcelRepository _repo;
  final _supabase = Supabase.instance.client;

  // Block/Apt selection
  List<Map<String, dynamic>> _blocos = [];
  List<Map<String, dynamic>> _aptos = [];
  Map<String, dynamic>? _selectedBloco;
  Map<String, dynamic>? _selectedApto;
  List<Map<String, dynamic>> _residentesUnidade = [];
  bool _loadingBlocos = true;
  bool _loadingAptos = false;

  // AI OCR state
  bool _isAnalyzingPhoto = false;
  String? _aiFeedbackMessage;
  bool _aiFeedbackSuccess = false;
  int _analysisRequestId = 0;

  // Form fields
  String? _selectedTipo;
  final _trackingCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();

  // Photo
  XFile? _photo;
  bool _isUploadingPhoto = false;
  bool _isRegistering = false;

  @override
  void initState() {
    super.initState();
    _repo = sl<ParcelRepository>();
    _loadBlocos();
  }

  @override
  void dispose() {
    _trackingCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBlocos() async {
    final authState = context.read<AuthBloc>().state;
    final condoId = authState.condominiumId;
    if (condoId == null) return;
    try {
      final data = await _supabase
          .from('blocos')
          .select('id, nome_ou_numero')
          .eq('condominio_id', condoId)
          .neq('nome_ou_numero', '0')
          .order('nome_ou_numero');
      final list = List<Map<String, dynamic>>.from(data);
      list.sort((a, b) {
        final na = int.tryParse(a['nome_ou_numero'].toString()) ?? 0;
        final nb = int.tryParse(b['nome_ou_numero'].toString()) ?? 0;
        return na != 0 && nb != 0 ? na.compareTo(nb) : a['nome_ou_numero'].toString().compareTo(b['nome_ou_numero'].toString());
      });
      setState(() {
        _blocos = list;
        _loadingBlocos = false;
      });
    } catch (e) {
      setState(() => _loadingBlocos = false);
    }
  }

  Future<void> _onBlocoSelected(Map<String, dynamic>? bloco, {Map<String, dynamic>? preserveApto}) async {
    setState(() {
      _selectedBloco = bloco;
      _selectedApto = preserveApto;
      _aptos = [];
      if (preserveApto == null) {
        _residentesUnidade = [];
      }
      _loadingAptos = bloco != null;
    });
    if (bloco == null) return;

    final authState = context.read<AuthBloc>().state;
    try {
      final data = await _supabase
          .from('unidades')
          .select('apartamento_id, apartamentos(numero)')
          .eq('condominio_id', authState.condominiumId ?? '')
          .eq('bloco_id', bloco['id'])
          .order('apartamentos(numero)');

      final aptos = data.map<Map<String, dynamic>>((e) {
        final apto = e['apartamentos'];
        return {
          'id': e['apartamento_id'],
          'numero': apto is Map ? apto['numero'] : (apto is List && apto.isNotEmpty ? apto[0]['numero'] : '?'),
        };
      }).where((e) => e['numero'] != '0').toList();
      aptos.sort((a, b) {
        final na = int.tryParse(a['numero'].toString()) ?? 0;
        final nb = int.tryParse(b['numero'].toString()) ?? 0;
        return na != 0 && nb != 0 ? na.compareTo(nb) : a['numero'].toString().compareTo(b['numero'].toString());
      });

      setState(() {
        _aptos = aptos;
        _loadingAptos = false;
      });
    } catch (e) {
      setState(() => _loadingAptos = false);
    }
  }

  Future<void> _onAptoSelected(Map<String, dynamic>? apto) async {
    setState(() {
      _selectedApto = apto;
      _residentesUnidade = [];
    });
    if (apto == null || _selectedBloco == null) return;

    // Load residents for this unit (for resident_id on parcel)
    final blocoNome = _selectedBloco!['nome_ou_numero'] as String;
    final aptoNum = apto['numero'].toString();
    try {
      final data = await _supabase
          .from('perfil')
          .select('id, nome_completo')
          .eq('bloco_txt', blocoNome)
          .eq('apto_txt', aptoNum)
          .neq('papel_sistema', 'portaria')
          .neq('papel_sistema', 'Admin');
      setState(() {
        _residentesUnidade = List<Map<String, dynamic>>.from(data);
      });
    } catch (_) {}
  }

  Future<void> _analyzePhotoWithAi(XFile photo) async {
    final hasBloco = _selectedBloco != null;
    final hasApto = _selectedApto != null;

    // CENÁRIO 1: Ambos já preenchidos manualmente -> NÃO chamar Edge Function / IA. Custo ZERO.
    if (hasBloco && hasApto) {
      return;
    }

    final currentReqId = ++_analysisRequestId;
    setState(() {
      _isAnalyzingPhoto = true;
      _aiFeedbackMessage = 'Analisando a foto...';
      _aiFeedbackSuccess = false;
    });

    try {
      final bytes = await photo.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Call Edge Function parcel-ai-extract
      final response = await _supabase.functions.invoke(
        'parcel-ai-extract',
        body: {'image_base64': base64Image},
      );

      // Check race condition & mounted
      if (!mounted || currentReqId != _analysisRequestId) return;

      if (response.status != 200) {
        setState(() {
          _isAnalyzingPhoto = false;
          _aiFeedbackMessage = '⚠️ Não foi possível identificar a unidade pela foto. Preencha Bloco e Apartamento manualmente.';
          _aiFeedbackSuccess = false;
        });
        return;
      }

      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : jsonDecode(response.data.toString()) as Map<String, dynamic>;

      final leituraOk = data['leitura_ok'] == true;
      final rawBloco = data['bloco']?.toString().trim();
      final rawApto = data['apartamento']?.toString().trim();

      if (!leituraOk || (rawBloco == null && rawApto == null)) {
        setState(() {
          _isAnalyzingPhoto = false;
          _aiFeedbackMessage = '⚠️ Não foi possível identificar a unidade pela foto. Preencha manualmente.';
          _aiFeedbackSuccess = false;
        });
        return;
      }

      // CENÁRIO 2: Bloco preenchido manualmente, Apto vazio
      if (hasBloco && !hasApto) {
        if (rawApto != null) {
          final matchingApto = _aptos.firstWhere(
            (a) => a['numero'].toString().trim().toLowerCase() == rawApto.toLowerCase(),
            orElse: () => {},
          );

          if (matchingApto.isNotEmpty) {
            await _onAptoSelected(matchingApto);
            if (!mounted || currentReqId != _analysisRequestId) return;

            setState(() {
              _isAnalyzingPhoto = false;
              _aiFeedbackMessage = '✓ Apartamento identificado automaticamente pela foto';
              _aiFeedbackSuccess = true;
            });
          } else {
            setState(() {
              _isAnalyzingPhoto = false;
              _aiFeedbackMessage = '⚠️ O apartamento identificado na foto não foi encontrado para o bloco selecionado. Confira os dados manualmente.';
              _aiFeedbackSuccess = false;
            });
          }
        } else {
          setState(() {
            _isAnalyzingPhoto = false;
            _aiFeedbackMessage = '⚠️ Não foi possível identificar o apartamento pela foto. Selecione manualmente.';
            _aiFeedbackSuccess = false;
          });
        }
        return;
      }

      // CENÁRIO 3: Bloco vazio, Apartamento preenchido manualmente
      if (!hasBloco && hasApto) {
        final manualApto = _selectedApto!;
        final manualAptoNum = manualApto['numero'].toString().trim().toLowerCase();

        if (rawBloco != null) {
          final matchingBloco = _blocos.firstWhere(
            (b) => b['nome_ou_numero'].toString().trim().toLowerCase() == rawBloco.toLowerCase(),
            orElse: () => {},
          );

          if (matchingBloco.isNotEmpty) {
            await _onBlocoSelected(matchingBloco, preserveApto: manualApto);
            if (!mounted || currentReqId != _analysisRequestId) return;

            final matchingAptoInBloco = _aptos.firstWhere(
              (a) => a['numero'].toString().trim().toLowerCase() == manualAptoNum,
              orElse: () => {},
            );

            if (matchingAptoInBloco.isNotEmpty) {
              await _onAptoSelected(matchingAptoInBloco);
              if (!mounted || currentReqId != _analysisRequestId) return;

              setState(() {
                _isAnalyzingPhoto = false;
                _aiFeedbackMessage = '✓ Bloco identificado automaticamente pela foto';
                _aiFeedbackSuccess = true;
              });
            } else {
              setState(() {
                _selectedBloco = null;
                _aptos = [];
                _isAnalyzingPhoto = false;
                _aiFeedbackMessage = '⚠️ O bloco identificado na foto não foi encontrado para o apartamento selecionado. Confira os dados manualmente.';
                _aiFeedbackSuccess = false;
              });
            }
          } else {
            setState(() {
              _isAnalyzingPhoto = false;
              _aiFeedbackMessage = '⚠️ O bloco identificado na foto não foi encontrado neste condomínio. Confira os dados manualmente.';
              _aiFeedbackSuccess = false;
            });
          }
        } else {
          setState(() {
            _isAnalyzingPhoto = false;
            _aiFeedbackMessage = '⚠️ Não foi possível identificar o bloco pela foto. Selecione manualmente.';
            _aiFeedbackSuccess = false;
          });
        }
        return;
      }

      // CENÁRIO 4: Ambos vazios (!hasBloco && !hasApto)
      if (rawBloco == null && rawApto != null) {
        setState(() {
          _isAnalyzingPhoto = false;
          _aiFeedbackMessage = '⚠️ Apartamento $rawApto identificado, mas o bloco não está visível na foto. Selecione o bloco manualmente.';
          _aiFeedbackSuccess = false;
        });
        return;
      }

      final matchingBloco = _blocos.firstWhere(
        (b) => b['nome_ou_numero'].toString().trim().toLowerCase() == rawBloco!.toLowerCase(),
        orElse: () => {},
      );

      if (matchingBloco.isEmpty) {
        setState(() {
          _isAnalyzingPhoto = false;
          _aiFeedbackMessage = '⚠️ A unidade identificada na foto não foi encontrada neste condomínio. Confira os dados manualmente.';
          _aiFeedbackSuccess = false;
        });
        return;
      }

      // Block exists in condominium! Load aptos for this block
      await _onBlocoSelected(matchingBloco);
      if (!mounted || currentReqId != _analysisRequestId) return;

      // If apartment was also extracted, look for it in _aptos
      if (rawApto != null) {
        final matchingApto = _aptos.firstWhere(
          (a) => a['numero'].toString().trim().toLowerCase() == rawApto.toLowerCase(),
          orElse: () => {},
        );

        if (matchingApto.isNotEmpty) {
          await _onAptoSelected(matchingApto);
          if (!mounted || currentReqId != _analysisRequestId) return;

          setState(() {
            _isAnalyzingPhoto = false;
            _aiFeedbackMessage = '✓ Unidade identificada automaticamente pela foto';
            _aiFeedbackSuccess = true;
          });
          return;
        } else {
          setState(() {
            _isAnalyzingPhoto = false;
            _aiFeedbackMessage = '⚠️ A unidade identificada na foto não foi encontrada neste condomínio. Confira os dados manualmente.';
            _aiFeedbackSuccess = false;
          });
          return;
        }
      } else {
        // Only block found
        setState(() {
          _isAnalyzingPhoto = false;
          _aiFeedbackMessage = '✓ Bloco identificado. Selecione o apartamento manualmente.';
          _aiFeedbackSuccess = false;
        });
      }
    } catch (e) {
      if (!mounted || currentReqId != _analysisRequestId) return;
      setState(() {
        _isAnalyzingPhoto = false;
        _aiFeedbackMessage = '⚠️ Não foi possível identificar a unidade pela foto. Preencha Bloco e Apartamento manualmente.';
        _aiFeedbackSuccess = false;
      });
    }
  }

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
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
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
                child: Icon(Icons.photo_library_outlined, color: AppColors.primary),
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
        setState(() => _photo = photo);
        _analyzePhotoWithAi(photo);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(source == ImageSource.camera
                ? 'Câmera não disponível no simulador. Use a galeria.'
                : 'Não foi possível acessar a galeria.'),
          ),
        );
      }
    }
  }

  Future<String?> _uploadPhoto(XFile photo) async {
    setState(() => _isUploadingPhoto = true);
    try {
      final ext = photo.path.split('.').last;
      final fileName = 'parcel_${const Uuid().v4()}.$ext';
      final bytes = await photo.readAsBytes();
      await _supabase.storage.from('parcel-photos').uploadBinary(
          fileName, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg'));
      return _supabase.storage.from('parcel-photos').getPublicUrl(fileName);
    } catch (e) {
      return null;
    } finally {
      setState(() => _isUploadingPhoto = false);
    }
  }

  bool get _canRegister =>
      _selectedBloco != null &&
      _selectedApto != null &&
      _selectedTipo != null;

  Future<void> _handleRegister() async {
    if (!_canRegister) return;
    setState(() => _isRegistering = true);
    HapticFeedback.mediumImpact();

    final authState = context.read<AuthBloc>().state;
    final blocoNome = _selectedBloco!['nome_ou_numero'] as String;
    final aptoNum = _selectedApto!['numero'].toString();

    // Use first resident of the unit, or null if no resident is registered
    final residentId = _residentesUnidade.isNotEmpty
        ? _residentesUnidade[0]['id'] as String?
        : null;

    String? photoUrl;
    if (_photo != null) photoUrl = await _uploadPhoto(_photo!);

    final parcel = Parcel(
      id: const Uuid().v4(),
      residentId: residentId,
      residentName: _residentesUnidade.isNotEmpty
          ? (_residentesUnidade[0]['nome_completo'] as String? ?? 'Morador')
          : 'Sem morador cadastrado',
      unitNumber: aptoNum,
      block: blocoNome,
      arrivalTime: DateTime.now(),
      status: 'pending',
      photoUrl: photoUrl,
      condominiumId: authState.condominiumId,
      tipo: _selectedTipo,
      trackingCode: _trackingCtrl.text.trim().isEmpty ? null : _trackingCtrl.text.trim(),
      observacao: _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
      registeredBy: authState.userId,
    );

    final result = await _repo.registerParcel(parcel);

    if (mounted) {
      if (result is Success) {
        _showSuccess();
      } else {
        final msg = ErrorSanitizer.sanitize((result as Failure).message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.error),
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
        Navigator.of(context).pop(); // go back to previous screen
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Registrar Encomenda'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── AI Extraction Feedback Banner
              if (_isAnalyzingPhoto)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Analisando a foto...',
                          style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ]),
                  ),
                )
              else if (_aiFeedbackMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: _aiFeedbackSuccess ? Colors.green.shade50 : Colors.amber.shade50,
                      border: Border.all(
                        color: _aiFeedbackSuccess ? Colors.green.shade200 : Colors.amber.shade300,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      Icon(
                        _aiFeedbackSuccess ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                        color: _aiFeedbackSuccess ? Colors.green.shade700 : Colors.amber.shade800,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _aiFeedbackMessage!,
                          style: TextStyle(
                            color: _aiFeedbackSuccess ? Colors.green.shade800 : Colors.amber.shade900,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),

              // ── Bloco / Apto
              Row(children: [
                Expanded(child: _buildBlocoDropdown()),
                const SizedBox(width: 12),
                Expanded(child: _buildAptoDropdown()),
              ]),
              // ── Resident warning
              if (_selectedBloco != null && _selectedApto != null && _residentesUnidade.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Não existe morador cadastrado na unidade',
                          style: TextStyle(color: Colors.orange.shade800, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ]),
                  ),
                ),
              const SizedBox(height: 20),

              // ── Tipo (obrigatório)
              _buildTipoSelector(),
              const SizedBox(height: 20),

              // ── Foto
              _buildPhotoCapture(),
              const SizedBox(height: 20),

              // ── Rastreio
              _buildTextField(
                controller: _trackingCtrl,
                label: 'Código de Rastreio',
                hint: 'Ex: BR123456789',
                icon: Icons.pin_outlined,
              ),
              const SizedBox(height: 16),

              // ── Observação
              _buildTextField(
                controller: _obsCtrl,
                label: 'Observação',
                hint: 'Ex: Embalagem aberta, volumoso...',
                icon: Icons.notes_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: 28),

              (_isRegistering || _isUploadingPhoto)
                  ? Column(children: [
                      const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                      const SizedBox(height: 8),
                      Text(_isUploadingPhoto ? 'Enviando foto...' : 'Registrando...',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary)),
                    ])
                  : CondoButton(
                      label: 'Registrar Encomenda',
                      onPressed: _canRegister ? _handleRegister : null,
                    ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlocoDropdown() {
    final tipo = context.read<AuthBloc>().state.tipoEstrutura;
    final label = getBlocoLabel(tipo);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: AppTypography.label),
        const Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      ]),
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
                child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)))
            : DropdownButtonHideUnderline(
                child: DropdownButton<Map<String, dynamic>>(
                  value: _selectedBloco,
                  isExpanded: true,
                  hint: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(label)),
                  items: _blocos.map((b) => DropdownMenuItem(
                    value: b,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                       child: Text('${b['nome_ou_numero']}'),
                    ),
                  )).toList(),
                  onChanged: _onBlocoSelected,
                ),
              ),
      ),
    ]);
  }

  Widget _buildAptoDropdown() {
    final tipo = context.read<AuthBloc>().state.tipoEstrutura;
    final label = getAptoLabel(tipo);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: AppTypography.label),
        const Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      ]),
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
                child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)))
            : DropdownButtonHideUnderline(
                child: DropdownButton<Map<String, dynamic>>(
                  value: _selectedApto,
                  isExpanded: true,
                  hint: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(label)),
                  items: _aptos.map((a) => DropdownMenuItem(
                    value: a,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                       child: Text('${a['numero']}'),
                    ),
                  )).toList(),
                  onChanged: _selectedBloco == null ? null : _onAptoSelected,
                ),
              ),
      ),
    ]);
  }

  Widget _buildTipoSelector() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Tipo de Encomenda', style: AppTypography.label),
        const Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 10),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _tipoOptions.map((opt) {
          final selected = _selectedTipo == opt['value'];
          return GestureDetector(
            onTap: () => setState(() => _selectedTipo = opt['value']),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                  width: selected ? 2 : 1,
                ),
                boxShadow: selected
                    ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2))]
                    : [],
              ),
              child: Text(
                opt['label']!,
                style: AppTypography.bodyMedium.copyWith(
                  color: selected ? Colors.white : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ]);
  }

  Widget _buildPhotoCapture() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Foto da Encomenda', style: AppTypography.label),
      const SizedBox(height: 4),
      Text('Opcional — recomendado para notif. judicial',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      const SizedBox(height: 10),
      GestureDetector(
        onTap: _takePhoto,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 100,
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
              ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.camera_alt_outlined, size: 28, color: AppColors.border),
                  const SizedBox(width: 10),
                  Text('Tocar para tirar foto', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ])
              : Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(File(_photo!.path), width: double.infinity, height: 100, fit: BoxFit.cover),
                  ),
                  Positioned(
                    bottom: 6, right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.refresh, color: Colors.white, size: 13),
                        SizedBox(width: 4),
                        Text('Trocar', style: TextStyle(color: Colors.white, fontSize: 11)),
                      ]),
                    ),
                  ),
                ]),
        ),
      ),
    ]);
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$label (opcional)', style: AppTypography.label),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primary, width: 2)),
        ),
      ),
    ]);
  }
}

class _SuccessDialog extends StatelessWidget {
  const _SuccessDialog();
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 56),
          ),
          const SizedBox(height: 20),
          Text('Registrada!', style: AppTypography.h1),
          const SizedBox(height: 8),
          Text('Encomenda salva com sucesso.', style: AppTypography.bodyLarge, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('Os moradores serão notificados.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
