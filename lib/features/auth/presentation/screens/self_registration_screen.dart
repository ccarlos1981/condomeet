import 'package:flutter/material.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/features/portaria/domain/repositories/resident_repository.dart';
import 'package:condomeet/features/portaria/data/repositories/resident_repository_impl.dart';

class SelfRegistrationScreen extends StatefulWidget {
  const SelfRegistrationScreen({super.key});

  @override
  State<SelfRegistrationScreen> createState() => _SelfRegistrationScreenState();
}

class _SelfRegistrationScreenState extends State<SelfRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _blockController = TextEditingController();
  final _unitController = TextEditingController();
  final ResidentRepository _repository = ResidentRepositoryImpl();
  bool _isLoading = false;

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    final result = await _repository.requestSelfRegistration(
      name: _nameController.text,
      block: _blockController.text,
      unit: _unitController.text,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (result is Success) {
        Navigator.of(context).pushReplacementNamed('/waiting-approval');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao enviar cadastro. Tente novamente.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro de Morador'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bem-vindo ao Condomeet!', style: AppTypography.h1),
              const SizedBox(height: 8),
              Text(
                'Preencha seus dados para solicitar acesso ao seu condomínio.',
                style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              
              // Photo Placeholder (Story 4.3 says photo is recommended)
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.add_a_photo_outlined, size: 40, color: AppColors.primary),
                    ),
                    const SizedBox(height: 8),
                    Text('Adicionar Foto', style: AppTypography.label.copyWith(color: AppColors.primary)),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              CondoInput(
                label: 'Nome Completo',
                hint: 'Como você quer ser chamado',
                controller: _nameController,
                validator: (value) => value == null || value.isEmpty ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: CondoInput(
                      label: 'Bloco / Torre',
                      hint: 'Ex: A',
                      controller: _blockController,
                      validator: (value) => value == null || value.isEmpty ? 'Obrigatório' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CondoInput(
                      label: 'Unidade / Apto',
                      hint: 'Ex: 102',
                      controller: _unitController,
                      keyboardType: TextInputType.number,
                      validator: (value) => value == null || value.isEmpty ? 'Obrigatório' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),
              CondoButton(
                label: 'Solicitar Acesso',
                isLoading: _isLoading,
                onPressed: _handleSubmit,
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Já tenho cadastro? Entrar',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
