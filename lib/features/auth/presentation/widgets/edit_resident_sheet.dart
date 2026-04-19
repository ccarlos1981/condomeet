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

  String _tipoMorador = 'Proprietário';
  String _papelSistema = 'Morador';

  bool _isSaving = false;
  bool _isResettingPassword = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.resident.fullName);
    _emailCtrl = TextEditingController(text: widget.resident.email ?? '');
    _phoneCtrl = TextEditingController(text: widget.resident.phoneNumber ?? '');
    _blockCtrl = TextEditingController(text: widget.resident.block ?? '');
    _unitCtrl = TextEditingController(text: widget.resident.unitNumber ?? '');

    _tipoMorador = widget.resident.tipoMorador ?? 'Proprietário';
    _papelSistema = widget.resident.papelSistema ?? 'Morador';
    
    // Ensure fallback if not matching list
    switch (_tipoMorador) {
      case 'Proprietário':
      case 'Inquilino':
      case 'Visitante Frequente':
      case 'Dependente':
        break;
      default:
        _tipoMorador = 'Proprietário';
    }

    switch (_papelSistema) {
      case 'Morador':
      case 'Administrador':
      case 'Porteiro':
      case 'Síndico':
        break;
      default:
        _papelSistema = 'Morador';
    }
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
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O nome é obrigatório.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    
    final repo = sl<ResidentRepository>();
    final result = await repo.updateResidentProfile(
      residentId: widget.resident.id,
      condominiumId: widget.condominiumId,
      fullName: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      block: _blockCtrl.text.trim(),
      unit: _unitCtrl.text.trim(),
      tipoMorador: _tipoMorador,
      papelSistema: _papelSistema,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (result.isSuccess) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Morador atualizado com sucesso!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
        );
        widget.onSaved();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.failureMessage)),
        );
      }
    }
  }

  Future<void> _resetPassword() async {
    setState(() => _isResettingPassword = true);

    final repo = sl<ResidentRepository>();
    final result = await repo.resetPassword(widget.resident.id);

    if (mounted) {
      setState(() => _isResettingPassword = false);
      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Senha redefinida para 123456 com sucesso!', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.failureMessage), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                children: [
                  _input('Nome', _nameCtrl, Icons.person_outline),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _input('Bloco/Torre', _blockCtrl, Icons.business)),
                      const SizedBox(width: 12),
                      Expanded(child: _input('Apto/Casa', _unitCtrl, Icons.door_front_door_outlined)),
                    ],
                  ),
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
                        items: const [
                          DropdownMenuItem(value: 'Proprietário', child: Text('Proprietário')),
                          DropdownMenuItem(value: 'Inquilino', child: Text('Inquilino')),
                          DropdownMenuItem(value: 'Dependente', child: Text('Dependente')),
                          DropdownMenuItem(value: 'Visitante Frequente', child: Text('Visitante Frequente')),
                        ],
                        onChanged: (v) => setState(() => _tipoMorador = v!),
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
                        items: const [
                          DropdownMenuItem(value: 'Morador', child: Text('Morador')),
                          DropdownMenuItem(value: 'Administrador', child: Text('Administrador')),
                          DropdownMenuItem(value: 'Porteiro', child: Text('Porteiro')),
                          DropdownMenuItem(value: 'Síndico', child: Text('Síndico')),
                        ],
                        onChanged: (v) => setState(() => _papelSistema = v!),
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
                style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.bold)
              ),
            ),
          ),
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

  Widget _input(String label, TextEditingController ctrl, IconData icon, {TextInputType keyboard = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.primary)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      ),
    );
  }
}
