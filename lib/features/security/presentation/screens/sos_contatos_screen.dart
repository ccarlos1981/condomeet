import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/core/di/injection_container.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/features/security/domain/repositories/sos_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SosContatosScreen extends StatefulWidget {
  const SosContatosScreen({super.key});

  @override
  State<SosContatosScreen> createState() => _SosContatosScreenState();
}

class _SosContatosScreenState extends State<SosContatosScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contato1NomeCtrl = TextEditingController();
  final _contato1WaCtrl = TextEditingController();
  final _contato2NomeCtrl = TextEditingController();
  final _contato2WaCtrl = TextEditingController();
  bool _aceite = false;
  bool _loading = false;
  bool _saving = false;
  String? _existingId;

  late final SOSRepository _repo;
  late final String _userId;

  @override
  void initState() {
    super.initState();
    _repo = sl<SOSRepository>();
    final authState = context.read<AuthBloc>().state;
    _userId = authState.userId ?? '';
    _loadContatos();
  }

  @override
  void dispose() {
    _contato1NomeCtrl.dispose();
    _contato1WaCtrl.dispose();
    _contato2NomeCtrl.dispose();
    _contato2WaCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadContatos() async {
    if (_userId.isEmpty) return;
    setState(() => _loading = true);
    final contatos = await _repo.getSosContatos(_userId);
    if (mounted && contatos != null) {
      setState(() {
        _existingId = contatos.id;
        _contato1NomeCtrl.text = contatos.contato1Nome ?? '';
        _contato1WaCtrl.text = contatos.contato1Whatsapp ?? '';
        _contato2NomeCtrl.text = contatos.contato2Nome ?? '';
        _contato2WaCtrl.text = contatos.contato2Whatsapp ?? '';
        _aceite = contatos.aceiteResponsabilidade;
      });
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_aceite) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você precisa aceitar a responsabilidade pelos dados informados.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    final contatos = SosContatos(
      id: _existingId,
      userId: _userId,
      contato1Nome: _contato1NomeCtrl.text.trim().isEmpty ? null : _contato1NomeCtrl.text.trim(),
      contato1Whatsapp: _contato1WaCtrl.text.trim().isEmpty ? null : _contato1WaCtrl.text.trim(),
      contato2Nome: _contato2NomeCtrl.text.trim().isEmpty ? null : _contato2NomeCtrl.text.trim(),
      contato2Whatsapp: _contato2WaCtrl.text.trim().isEmpty ? null : _contato2WaCtrl.text.trim(),
      aceiteResponsabilidade: _aceite,
    );

    final result = await _repo.saveSosContatos(userId: _userId, contatos: contatos);
    if (!mounted) return;

    setState(() => _saving = false);
    result.fold(
      (err) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: ${err.message}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      ),
      (_) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Contatos SOS salvos com sucesso!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Informações de contato - SOS',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: Colors.red.shade600, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Esses contatos receberão uma mensagem de WhatsApp caso você acione o SOS.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade700,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Contato 1
                    _buildSectionHeader('Contato de confiança 1'),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _contato1NomeCtrl,
                      label: 'Nome do contato 1',
                      icon: Icons.person_outline_rounded,
                      hint: 'Ex: Maria Silva',
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _contato1WaCtrl,
                      label: 'Nº do WhatsApp',
                      icon: Icons.phone_outlined,
                      hint: '(61) 9 9999-9999',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 24),

                    // Contato 2
                    _buildSectionHeader('Contato de confiança 2'),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _contato2NomeCtrl,
                      label: 'Nome do contato 2',
                      icon: Icons.person_outline_rounded,
                      hint: 'Ex: João Souza',
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _contato2WaCtrl,
                      label: 'Nº do WhatsApp',
                      icon: Icons.phone_outlined,
                      hint: '(61) 9 9999-9999',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 24),

                    // Aceite
                    GestureDetector(
                      onTap: () => setState(() => _aceite = !_aceite),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _aceite,
                            onChanged: (v) => setState(() => _aceite = v ?? false),
                            activeColor: AppColors.primary,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          const SizedBox(width: 4),
                          const Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(top: 11),
                              child: Text(
                                'Me responsabilizo pelos dados inseridos como contatos.',
                                style: TextStyle(fontSize: 13, color: Color(0xFF444444)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Buttons
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          elevation: 0,
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Salvar contatos',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade400),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                        ),
                        child: Text(
                          'Voltar',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Color(0xFF333333),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
