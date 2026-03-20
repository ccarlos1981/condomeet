import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/core/utils/structure_helper.dart';
import '../../domain/repositories/auth_repository.dart';

class EditProfileScreen extends StatefulWidget {
  final String userId;
  final String condominioId;
  final String? currentName;
  final String? currentWhatsapp;
  final String? currentTipoMorador;
  final String? currentBlocoTxt;
  final String? currentAptoTxt;

  const EditProfileScreen({
    super.key,
    required this.userId,
    required this.condominioId,
    this.currentName,
    this.currentWhatsapp,
    this.currentTipoMorador,
    this.currentBlocoTxt,
    this.currentAptoTxt,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nomeController;
  late TextEditingController _whatsappController;
  String _tipoMorador = 'Proprietário (a)';
  
  // Bloco / Apto
  String? _selectedBlocoId;
  String? _selectedApartamentoId;
  String? _selectedBlocoTxt;
  String? _selectedAptoTxt;
  List<Map<String, dynamic>> _blocosDisponiveis = [];
  List<Map<String, dynamic>> _apartamentosDisponiveis = [];
  
  bool _isLoading = false;
  bool _isSaving = false;
  bool _apartmentChanged = false;
  String _tipoEstrutura = 'predio';

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.currentName ?? '');
    _whatsappController = TextEditingController(text: widget.currentWhatsapp ?? '');
    _tipoMorador = widget.currentTipoMorador ?? 'Proprietário (a)';
    _selectedBlocoTxt = widget.currentBlocoTxt;
    _selectedAptoTxt = widget.currentAptoTxt;
    _loadBlocos();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  Future<void> _loadBlocos() async {
    setState(() => _isLoading = true);
    try {
      final repo = GetIt.instance<AuthRepository>();
      final blocos = await repo.getBlocos(widget.condominioId);
      _blocosDisponiveis = blocos;
      // Pré-selecionar bloco atual
      if (widget.currentBlocoTxt != null) {
        for (var b in blocos) {
          if ((b['nome_ou_numero'] as String).toLowerCase().trim() == widget.currentBlocoTxt!.toLowerCase().trim()) {
            _selectedBlocoId = b['id'];
            break;
          }
        }
        if (_selectedBlocoId != null) {
          await _loadApartamentos(_selectedBlocoId!, preSelectCurrent: true);
        }
      }
    } catch (e) {
      debugPrint('Erro ao buscar blocos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadApartamentos(String blocoId, {bool preSelectCurrent = false}) async {
    try {
      final repo = GetIt.instance<AuthRepository>();
      final aptos = await repo.getApartamentos(widget.condominioId, blocoId);
      setState(() {
        _apartamentosDisponiveis = aptos;
        if (preSelectCurrent && widget.currentAptoTxt != null) {
          for (var a in aptos) {
            if ((a['numero'] as String).toLowerCase().trim() == widget.currentAptoTxt!.toLowerCase().trim()) {
              _selectedApartamentoId = a['id'];
              break;
            }
          }
        }
      });
    } catch (e) {
      debugPrint('Erro ao buscar apartamentos: $e');
    }
  }

  void _checkApartmentChange() {
    String? newBlocoTxt;
    String? newAptoTxt;
    
    if (_selectedBlocoId != null) {
      final bloco = _blocosDisponiveis.firstWhere(
        (b) => b['id'] == _selectedBlocoId,
        orElse: () => {},
      );
      if (bloco.isNotEmpty) newBlocoTxt = bloco['nome_ou_numero'] as String?;
    }
    
    if (_selectedApartamentoId != null) {
      final apto = _apartamentosDisponiveis.firstWhere(
        (a) => a['id'] == _selectedApartamentoId,
        orElse: () => {},
      );
      if (apto.isNotEmpty) newAptoTxt = apto['numero'] as String?;
    }

    _selectedBlocoTxt = newBlocoTxt;
    _selectedAptoTxt = newAptoTxt;

    final bool changed = (newBlocoTxt?.toLowerCase().trim() != widget.currentBlocoTxt?.toLowerCase().trim()) ||
                          (newAptoTxt?.toLowerCase().trim() != widget.currentAptoTxt?.toLowerCase().trim());
    
    setState(() => _apartmentChanged = changed);
  }

  void _showChangePasswordSheet() {
    final newPwdCtrl = TextEditingController();
    final confirmPwdCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        bool saving = false;
        String? errorMsg;
        bool obscureNew = true;
        bool obscureConfirm = true;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Alterar Senha', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Crie uma nova senha numérica.', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: newPwdCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'Nova senha (somente números)',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setSheetState(() => obscureNew = !obscureNew),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmPwdCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirmar nova senha',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setSheetState(() => obscureConfirm = !obscureConfirm),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 12),
                    Text(errorMsg!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: saving
                          ? null
                          : () async {
                              final newPwd = newPwdCtrl.text.trim();
                              final confirmPwd = confirmPwdCtrl.text.trim();
                              if (newPwd.length < 4) {
                                setSheetState(() => errorMsg = 'Mínimo de 4 dígitos');
                                return;
                              }
                              if (newPwd != confirmPwd) {
                                setSheetState(() => errorMsg = 'As senhas não coincidem');
                                return;
                              }
                              setSheetState(() { saving = true; errorMsg = null; });
                              try {
                                await GetIt.instance<AuthRepository>().updatePassword(newPwd);
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Senha alterada com sucesso! ✅'), backgroundColor: Colors.green),
                                  );
                                }
                              } catch (e) {
                                setSheetState(() {
                                  saving = false;
                                  errorMsg = 'Erro ao alterar senha. Tente novamente.';
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Salvar Nova Senha', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _save() async {
    if (_nomeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome é obrigatório'), backgroundColor: AppColors.error),
      );
      return;
    }

    // Se mudou de apto, mostrar confirmação
    if (_apartmentChanged) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 28),
              const SizedBox(width: 8),
              const Text('Atenção!'),
            ],
          ),
          content: const Text(
            'Ao mudar de apartamento, seu acesso será bloqueado até o síndico aprovar novamente.\n\n'
            'Isso é necessário para proteger os dados do novo apartamento.\n\n'
            'Deseja continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Sim, alterar'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    setState(() => _isSaving = true);

    try {
      if (_apartmentChanged && _selectedBlocoTxt != null && _selectedAptoTxt != null) {
        // Mudar de apartamento (RPC)
        final result = await _supabase.rpc('change_apartment', params: {
          'p_user_id': widget.userId,
          'p_new_bloco_txt': _selectedBlocoTxt,
          'p_new_apto_txt': _selectedAptoTxt,
        });

        final success = result['success'] == true;
        if (!success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result['error'] ?? 'Erro ao mudar apartamento'), backgroundColor: AppColors.error),
            );
          }
          setState(() => _isSaving = false);
          return;
        }

        // Também atualiza nome/whatsapp/tipo
        await _supabase.rpc('update_profile', params: {
          'p_user_id': widget.userId,
          'p_nome_completo': _nomeController.text.trim(),
          'p_whatsapp': _whatsappController.text.trim(),
          'p_tipo_morador': _tipoMorador,
        });

        if (mounted) {
          // Morador foi bloqueado — voltar para tela de bloqueio
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Apartamento alterado! Aguarde aprovação do síndico.'),
              backgroundColor: Colors.orange,
            ),
          );
          // Forçar logout e recheck
          await Supabase.instance.client.auth.signOut();
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          }
        }
      } else {
        // Edição simples (sem mudar apto)
        await _supabase.rpc('update_profile', params: {
          'p_user_id': widget.userId,
          'p_nome_completo': _nomeController.text.trim(),
          'p_whatsapp': _whatsappController.text.trim(),
          'p_tipo_morador': _tipoMorador,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Perfil atualizado com sucesso! ✅'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // retorna true para indicar que editou
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Seção: Dados Pessoais
                  const Text('Dados Pessoais', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _nomeController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Nome Completo',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _whatsappController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'WhatsApp',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildSafeSelector(
                    label: 'Tipo de Morador',
                    value: _tipoMorador,
                    icon: Icons.badge_outlined,
                    options: () {
                      final base = [
                        'Proprietário (a)',
                        'Inquilino (a)',
                        'Cônjuge',
                        'Dependente',
                        'Família',
                        'Funcionário (a)',
                        'Terceirizado (a)',
                        'Síndico',
                        'Sub Síndico (a)',
                        'Porteiro (a)',
                        'Zelador (a)',
                      ];
                      if (!base.contains(_tipoMorador)) base.add(_tipoMorador);
                      return base;
                    }(),
                    onChanged: (val) => setState(() => _tipoMorador = val),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Seção: Unidade
                  const Text('Minha Unidade', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'Atualmente: ${StructureHelper.getNivel1Label(_tipoEstrutura)} ${widget.currentBlocoTxt ?? '?'} / ${StructureHelper.getNivel2Label(_tipoEstrutura)} ${widget.currentAptoTxt ?? '?'}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildSafeSelectorMap(
                    label: StructureHelper.getNivel1Label(_tipoEstrutura),
                    value: _selectedBlocoId,
                    icon: Icons.domain_outlined,
                    options: _blocosDisponiveis,
                    idKey: 'id',
                    labelBuilder: (b) => '${StructureHelper.getNivel1Label(_tipoEstrutura)} ${b['nome_ou_numero']}',
                    onChanged: (val) {
                      setState(() {
                        _selectedBlocoId = val;
                        _selectedApartamentoId = null;
                        _apartamentosDisponiveis = [];
                      });
                      if (val != null) {
                        _loadApartamentos(val);
                      }
                      _checkApartmentChange();
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  _buildSafeSelectorMap(
                    label: StructureHelper.getNivel2Label(_tipoEstrutura),
                    value: _selectedApartamentoId,
                    icon: Icons.meeting_room_outlined,
                    options: _apartamentosDisponiveis,
                    idKey: 'id',
                    labelBuilder: (a) => '${StructureHelper.getNivel2Label(_tipoEstrutura)} ${a['numero']}',
                    onChanged: (val) {
                      setState(() => _selectedApartamentoId = val);
                      _checkApartmentChange();
                    },
                  ),
                  
                  // Aviso de bloqueio
                  if (_apartmentChanged) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 24),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Ao mudar de unidade, seu acesso será bloqueado até o síndico aprovar novamente.',
                              style: TextStyle(fontSize: 13, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Seção: Segurança
                  const Text('Segurança', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _showChangePasswordSheet,
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('Alterar Senha', style: TextStyle(fontSize: 15)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  
                  // Botão Salvar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _apartmentChanged ? Colors.orange : AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              _apartmentChanged ? 'Salvar e Solicitar Aprovação' : 'Salvar Alterações',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildSafeSelector({
    required String label,
    required String value,
    required IconData icon,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: options.map((opt) => ListTile(
                      title: Text(opt),
                      trailing: opt == value ? const Icon(Icons.check, color: AppColors.primary) : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        onChanged(opt);
                      },
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(value, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _buildSafeSelectorMap({
    required String label,
    required String? value,
    required IconData icon,
    required List<Map<String, dynamic>> options,
    required String idKey,
    required String Function(Map<String, dynamic>) labelBuilder,
    required ValueChanged<String?> onChanged,
  }) {
    final selectedLabel = value != null
        ? options.where((o) => o[idKey] == value).map(labelBuilder).firstOrNull ?? 'Selecionar...'
        : 'Selecionar...';

    return GestureDetector(
      onTap: options.isEmpty ? null : () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const Divider(height: 1),
                ...options.map((opt) => ListTile(
                  title: Text(labelBuilder(opt)),
                  trailing: opt[idKey] == value ? const Icon(Icons.check, color: AppColors.primary) : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    onChanged(opt[idKey] as String);
                  },
                )),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          selectedLabel,
          style: TextStyle(
            fontSize: 16,
            color: value != null ? Colors.black : Colors.grey.shade500,
          ),
        ),
      ),
    );
  }
}
