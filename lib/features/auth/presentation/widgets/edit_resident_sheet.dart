import 'package:flutter/material.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/core/di/injection_container.dart';
import 'package:condomeet/features/portaria/domain/repositories/resident_repository.dart';

class EditResidentSheet extends StatefulWidget {
  final Resident resident;
  final String condominiumId;
  final VoidCallback onSaved;

  const EditResidentSheet({
    super.key,
    required this.resident,
    required this.condominiumId,
    required this.onSaved,
  });

  static Future<void> show(BuildContext context, Resident resident, String condominiumId, VoidCallback onSaved) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditResidentSheet(
        resident: resident,
        condominiumId: condominiumId,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<EditResidentSheet> createState() => _EditResidentSheetState();
}

class _EditResidentSheetState extends State<EditResidentSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _blockCtrl;
  late TextEditingController _unitCtrl;

  late String _tipoMorador;
  late String _papelSistema;

  bool _isSaving = false;
  bool _isResettingPassword = false;
  String? _errorMessage;

  static const List<String> _baseTipoMoradorOptions = [
    'Proprietário',
    'Proprietário não morador',
    'Inquilino',
    'Cônjuge',
    'Dependente',
    'Família',
    'Funcionário',
    'Visitante Frequente',
  ];

  static const Map<String, String> _papelSistemaLabels = {
    'Morador': 'Morador',
    'Síndico': 'Síndico',
    'Subsíndico': 'Subsíndico',
    'Porteiro': 'Porteiro',
    'Zelador': 'Zelador',
    'Admin': 'Administrador',
  };

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.resident.fullName);
    _emailCtrl = TextEditingController(text: widget.resident.email ?? '');
    _phoneCtrl = TextEditingController(text: widget.resident.phoneNumber ?? '');

    _tipoMorador = _normalizeTipoMorador(widget.resident.tipoMorador);
    _papelSistema = _normalizePapelSistema(widget.resident.papelSistema);

    final isAdmin = _papelSistema == 'Admin';
    _blockCtrl = TextEditingController(text: isAdmin ? 'Admin' : (widget.resident.block ?? ''));
    _unitCtrl = TextEditingController(text: isAdmin ? 'Admin' : (widget.resident.unitNumber ?? ''));
  }

  String _normalizeTipoMorador(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Proprietário';
    final trimmed = raw.trim();
    final lower = trimmed.toLowerCase();

    if (lower.startsWith('propriet') && lower.contains('nao')) {
      return 'Proprietário não morador';
    }
    if (lower.startsWith('propriet')) return 'Proprietário';
    if (lower.startsWith('inquilino') || lower.startsWith('locat') || lower.startsWith('locador')) {
      return 'Inquilino';
    }
    if (lower.startsWith('conju')) return 'Cônjuge';
    if (lower.startsWith('depend')) return 'Dependente';
    if (lower.startsWith('famil')) return 'Família';
    if (lower.startsWith('funcionar')) return 'Funcionário';
    if (lower.startsWith('visit')) return 'Visitante Frequente';

    return trimmed;
  }

  String _normalizePapelSistema(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Morador';
    final trimmed = raw.trim();
    final lower = trimmed.toLowerCase();

    if (lower == 'admin' || lower == 'administrador' || lower == 'administradora') {
      return 'Admin';
    }
    if (lower.contains('subsindico') || (lower.contains('sub') && lower.contains('sindico'))) {
      return 'Subsíndico';
    }
    if (lower.contains('sindico')) {
      return 'Síndico';
    }
    if (lower.startsWith('porteir') || lower.startsWith('portaria')) {
      return 'Porteiro';
    }
    if (lower.startsWith('zelador')) {
      return 'Zelador';
    }
    if (lower.startsWith('morador')) {
      return 'Morador';
    }

    return trimmed;
  }

  void _onRoleChanged(String newRole) {
    setState(() {
      final wasAdmin = _papelSistema == 'Admin';
      _papelSistema = newRole;

      if (newRole == 'Admin') {
        _blockCtrl.text = 'Admin';
        _unitCtrl.text = 'Admin';
      } else if (wasAdmin) {
        _blockCtrl.text = '';
        _unitCtrl.text = '';
      }
    });
  }

  String _sanitizeErrorMessage(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('postgrest') ||
        lower.contains('pgrst') ||
        lower.contains('schema cache') ||
        lower.contains('postgresql') ||
        lower.contains('syntax error') ||
        lower.contains('exception') ||
        lower.contains('unidades') ||
        lower.contains('perfil') ||
        lower.contains('socketexception') ||
        lower.contains('bad request')) {
      return 'Não foi possível salvar as alterações. Verifique os dados e tente novamente.';
    }
    return raw;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _blockCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'O nome é obrigatório.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O nome é obrigatório.')),
      );
      return;
    }

    final isAdmin = _papelSistema == 'Admin';
    final block = isAdmin ? 'Admin' : _blockCtrl.text.trim();
    final unit = isAdmin ? 'Admin' : _unitCtrl.text.trim();

    if (!isAdmin && (block.toLowerCase() == 'admin' || unit.toLowerCase() == 'admin')) {
      const msg = 'Moradores e síndicos devem possuir unidade residencial válida, não podendo utilizar a identificação técnica Admin.';
      setState(() => _errorMessage = msg);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _errorMessage = null;
      _isSaving = true;
    });

    final repo = sl<ResidentRepository>();
    final result = await repo.updateResidentProfile(
      residentId: widget.resident.id,
      condominiumId: widget.condominiumId,
      fullName: name,
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      block: block,
      unit: unit,
      tipoMorador: _tipoMorador,
      papelSistema: _papelSistema,
    );

    if (mounted) {
      if (result.isSuccess) {
        setState(() {
          _isSaving = false;
          _errorMessage = null;
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Morador atualizado com sucesso!', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.green,
          ),
        );
        widget.onSaved();
      } else {
        final rawMsg = result.failureMessage;
        debugPrint('⚠️ [EditResidentSheet] Erro ao salvar morador: $rawMsg');
        final friendlyMsg = _sanitizeErrorMessage(rawMsg);
        setState(() {
          _isSaving = false;
          _errorMessage = friendlyMsg;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyMsg),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _resetPassword() async {
    setState(() {
      _errorMessage = null;
      _isResettingPassword = true;
    });

    final repo = sl<ResidentRepository>();
    final result = await repo.resetPassword(widget.resident.id);

    if (mounted) {
      if (result.isSuccess) {
        setState(() {
          _isResettingPassword = false;
          _errorMessage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Senha redefinida para 123456 com sucesso!', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        final rawMsg = result.failureMessage;
        debugPrint('⚠️ [EditResidentSheet] Erro ao resetar senha: $rawMsg');
        final friendlyMsg = _sanitizeErrorMessage(rawMsg);
        setState(() {
          _isResettingPassword = false;
          _errorMessage = friendlyMsg;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyMsg), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _papelSistema == 'Admin';

    // Build dynamic items for tipo_morador ensuring current value is always present
    final List<String> tipoOptions = List.from(_baseTipoMoradorOptions);
    if (!tipoOptions.contains(_tipoMorador)) {
      tipoOptions.add(_tipoMorador);
    }

    // Build dynamic items for papel_sistema ensuring current value is always present
    final List<String> papelKeys = _papelSistemaLabels.keys.toList();
    if (!papelKeys.contains(_papelSistema)) {
      papelKeys.add(_papelSistema);
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Editar Morador', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 16),

          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _input('Nome', _nameCtrl, Icons.person_outline),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _input(
                          'Bloco/Torre',
                          _blockCtrl,
                          Icons.business,
                          enabled: !isAdmin,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _input(
                          'Apto/Casa',
                          _unitCtrl,
                          Icons.door_front_door_outlined,
                          enabled: !isAdmin,
                        ),
                      ),
                    ],
                  ),
                  if (isAdmin) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Text(
                        '🔐 Identidade Administrativa: Perfis de Administrador possuem identificação técnica Admin/Admin e não ocupam unidade residencial.',
                        style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _input('Telefone / WhatsApp', _phoneCtrl, Icons.phone_outlined, keyboard: TextInputType.phone),
                  const SizedBox(height: 12),
                  _input('Email', _emailCtrl, Icons.email_outlined, keyboard: TextInputType.emailAddress),
                  const SizedBox(height: 12),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Tipo de Conexão', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _tipoMorador,
                        items: tipoOptions.map((opt) {
                          return DropdownMenuItem<String>(value: opt, child: Text(opt));
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _tipoMorador = v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Nível de Acesso', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _papelSistema,
                        items: papelKeys.map((key) {
                          final label = _papelSistemaLabels[key] ?? key;
                          return DropdownMenuItem<String>(value: key, child: Text(label));
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) _onRoleChanged(v);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.orange.shade700),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isResettingPassword ? null : _resetPassword,
              icon: _isResettingPassword
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange))
                  : Icon(Icons.lock_reset, color: Colors.orange.shade700),
              label: Text(
                'RESETAR SENHA (123456)',
                style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              key: const Key('edit_resident_error_banner'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Não foi possível salvar',
                          style: TextStyle(
                            color: Colors.red.shade900,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('SALVAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _input(String label, TextEditingController ctrl, IconData icon, {TextInputType keyboard = TextInputType.text, bool enabled = true}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey, size: 20),
        filled: !enabled,
        fillColor: enabled ? Colors.white : Colors.grey.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.primary)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      ),
    );
  }
}

