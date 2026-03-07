import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class SindicoRegistrationScreen extends StatefulWidget {
  const SindicoRegistrationScreen({super.key});

  @override
  State<SindicoRegistrationScreen> createState() => _SindicoRegistrationScreenState();
}

class _SindicoRegistrationScreenState extends State<SindicoRegistrationScreen> {
  int _currentStep = 0;
  
  // Controllers Condominium
  final _condoNomeController = TextEditingController();
  final _condoApelidoController = TextEditingController(); // opcional
  final _condoCNPJController = TextEditingController(); // opcional
  final _condoCepController = TextEditingController();
  final _condoEnderecoController = TextEditingController();
  final _condoNumeroController = TextEditingController();
  final _condoCidadeController = TextEditingController();
  final _condoEstadoController = TextEditingController();

  // Controllers Personal Data
  final _nomeController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _tipoEstrutura = 'predio';

  // Form Keys
  final _formKeyCondo = GlobalKey<FormState>();
  final _formKeyConta = GlobalKey<FormState>();

  @override
  void dispose() {
    _condoNomeController.dispose();
    _condoApelidoController.dispose();
    _condoCNPJController.dispose();
    _condoCepController.dispose();
    _condoEnderecoController.dispose();
    _condoNumeroController.dispose();
    _condoCidadeController.dispose();
    _condoEstadoController.dispose();
    
    _nomeController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submitRegistration() {
    // Map of Condominium Data
    final condoData = {
      'nome': _condoNomeController.text.trim(),
      if (_condoApelidoController.text.trim().isNotEmpty)
        'apelido': _condoApelidoController.text.trim(),
      if (_condoCNPJController.text.trim().isNotEmpty)
        'cnpj': _condoCNPJController.text.trim(),
      'cep': _condoCepController.text.trim(),
      'logradouro': _condoEnderecoController.text.trim(),
      'numero': _condoNumeroController.text.trim(),
      'cidade': _condoCidadeController.text.trim(),
      'estado': _condoEstadoController.text.trim(),
      'tipo_estrutura': _tipoEstrutura,
    };

    context.read<AuthBloc>().add(
      AuthSindicoRegistrationSubmitted(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        condominioData: condoData,
        nomeCompleto: _nomeController.text.trim(),
        whatsapp: _whatsappController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro de Síndico', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state.status == AuthStatus.pendingPinSetup || 
              state.status == AuthStatus.pendingConsent || 
              state.status == AuthStatus.authenticated || 
              state.status == AuthStatus.pendingApproval) {
            // Success! Remove the registration screen from the stack so AuthRootGate takes over.
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          } else if (state.status == AuthStatus.unauthenticated && state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!), backgroundColor: AppColors.error),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state.status == AuthStatus.authenticating;
          
          if (isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          return Stepper(
            currentStep: _currentStep,
            onStepContinue: () {
              if (_currentStep == 0) {
                if (_formKeyCondo.currentState?.validate() ?? false) {
                  setState(() => _currentStep += 1);
                }
              } else if (_currentStep == 1) {
                if (_formKeyConta.currentState?.validate() ?? false) {
                 _submitRegistration();
                }
              }
            },
            onStepCancel: () {
              if (_currentStep > 0) {
                setState(() => _currentStep -= 1);
              } else {
                Navigator.pop(context);
              }
            },
            controlsBuilder: (context, details) {
              final isLastStep = _currentStep == 1;
              return Padding(
                padding: const EdgeInsets.only(top: 24.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: details.onStepContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(isLastStep ? 'Salvar Tudo e Entrar' : 'Avançar'),
                      ),
                    ),
                    if (_currentStep > 0) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: details.onStepCancel,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Voltar'),
                        ),
                      ),
                    ]
                  ],
                ),
              );
            },
            steps: [
              // Passo 1: Dados do Condomínio
              Step(
                title: const Text('Dados do Condomínio'),
                isActive: _currentStep >= 0,
                content: Form(
                  key: _formKeyCondo,
                  child: Column(
                    children: [
                      const Text('Bem-vindo, Síndico! Vamos registrar seu condomínio na plataforma.', style: TextStyle(fontSize: 14)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _tipoEstrutura,
                        decoration: InputDecoration(
                          labelText: 'Tipo de Estrutura *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'predio', child: Text('Prédio (Bloco e Apto)')),
                          DropdownMenuItem(value: 'casa_rua', child: Text('Casa (Rua e Número)')),
                          DropdownMenuItem(value: 'casa_quadra', child: Text('Casa (Quadra e Lote)')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _tipoEstrutura = value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _condoNomeController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Nome Oficial do Condomínio *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _condoCepController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'CEP *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _condoEnderecoController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Endereço (Rua/Avenida) *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _condoNumeroController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Número *',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _condoCidadeController,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                labelText: 'Cidade *',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _condoEstadoController,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 2,
                        decoration: InputDecoration(
                          labelText: 'Estado (Sigla) *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (v) => v!.isEmpty || v.length != 2 ? 'UF Invalido' : null,
                      ),
                    ],
                  ),
                ),
              ),
              
              // Passo 2: Dados do Síndico
              Step(
                title: const Text('Seus Dados de Acesso'),
                isActive: _currentStep >= 1,
                content: Form(
                  key: _formKeyConta,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nomeController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Seu Nome Completo',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _whatsappController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'Seu WhatsApp (Apenas números)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (v) => v!.isEmpty || v.length < 10 ? 'Telefone inválido' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Seu E-mail Administrativo',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (v) => v!.isEmpty || !v.contains('@') ? 'E-mail inválido' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Senha Numérica',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (v) => v!.isEmpty || int.tryParse(v) == null ? 'Apenas números' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPasswordController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Confirme a Senha Numérica',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (v) => v != _passwordController.text ? 'Senhas não conferem' : null,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
