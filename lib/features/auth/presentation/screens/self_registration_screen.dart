import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:get_it/get_it.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/core/utils/structure_helper.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'dart:async';
import '../../domain/repositories/auth_repository.dart';

class SelfRegistrationScreen extends StatefulWidget {
  const SelfRegistrationScreen({super.key});

  @override
  State<SelfRegistrationScreen> createState() => _SelfRegistrationScreenState();
}

class _SelfRegistrationScreenState extends State<SelfRegistrationScreen> {
  int _currentStep = 0;
  
  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _condominioBuscaController = TextEditingController();
  final _nomeController = TextEditingController();
  final _whatsappController = TextEditingController();

  // State Variables
  String? _selectedCondominiumId;
  String? _selectedCondominiumName;
  String _selectedTipoEstrutura = 'predio';
  String _tipoUsuario = 'Proprietário (a)';
  String _perfilUsuario = 'Morador(a)';
  bool _consentimentoWhatsapp = true;
  String? _selectedBlocoId;
  String? _selectedApartamentoId;
  String? _unidadeIdObtida;
  
  List<Map<String, dynamic>> _condominiosEncontrados = [];
  List<Map<String, dynamic>> _blocosDisponiveis = [];
  List<Map<String, dynamic>> _apartamentosDisponiveis = [];

  bool _isSearching = false;
  bool _isCheckingEmail = false;
  String? _emailError;
  Timer? _debounce;

  // Form Keys for Step Validation
  final _formKeyConta = GlobalKey<FormState>();
  final _formKeyDados = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _condominioBuscaController.dispose();
    _nomeController.dispose();
    _whatsappController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchCondominios(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.length < 3) {
        setState(() => _condominiosEncontrados = []);
        return;
      }
      setState(() => _isSearching = true);
      
      try {
        final repository = GetIt.instance<AuthRepository>();
        final response = await repository.searchCondominios(query);
            
        setState(() {
          _condominiosEncontrados = response;
          _isSearching = false;
        });
      } catch (e) {
        setState(() => _isSearching = false);
      }
    });
  }

  Future<void> _fetchBlocos() async {
    if (_selectedCondominiumId == null) return;
    try {
      final repository = GetIt.instance<AuthRepository>();
      final response = await repository.getBlocos(_selectedCondominiumId!);
          
      setState(() {
        _blocosDisponiveis = response;
        _selectedBlocoId = null;
        _selectedApartamentoId = null;
        _apartamentosDisponiveis = [];
      });
      print('📦 Blocos encontrados (Online): ${_blocosDisponiveis.length}');
    } catch (e) {
      print('Erro ao buscar blocos: $e');
    }
  }

  Future<void> _fetchApartamentos(String blocoId) async {
    if (_selectedCondominiumId == null) return;
    try {
      final repository = GetIt.instance<AuthRepository>();
      final response = await repository.getApartamentos(_selectedCondominiumId!, blocoId);
      
      setState(() {
        _apartamentosDisponiveis = response;
        _selectedApartamentoId = null;
      });
      print('📦 Aptos encontrados (Online) para bloco $blocoId: ${_apartamentosDisponiveis.length}');
    } catch (e) {
      print('Erro ao buscar aptos: $e');
    }
  }

  Future<void> _getUnidadeExata() async {
    if (_selectedCondominiumId == null || _selectedBlocoId == null || _selectedApartamentoId == null) return;
    try {
      final repository = GetIt.instance<AuthRepository>();
      final response = await repository.getUnidade(
        _selectedCondominiumId!, 
        _selectedBlocoId!, 
        _selectedApartamentoId!,
      );
          
      if (response != null) {
        _unidadeIdObtida = response['id'] as String;
      }
    } catch (e) {
      print('Erro ao buscar unidade: $e');
    }
  }

  void _submitRegistration() async {
    await _getUnidadeExata();
    
    if (_unidadeIdObtida == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta unidade ainda não está disponível no servidor. Tente novamente em alguns segundos.'), backgroundColor: AppColors.error),
      );
      return;
    }

    // Resolve text values for bloco and apto
    final blocoData = _blocosDisponiveis.firstWhere((b) => b['id'] == _selectedBlocoId, orElse: () => {});
    final aptoData = _apartamentosDisponiveis.firstWhere((a) => a['id'] == _selectedApartamentoId, orElse: () => {});

    context.read<AuthBloc>().add(
      AuthResidentRegistrationSubmitted(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        condominioId: _selectedCondominiumId!,
        unidadeId: _unidadeIdObtida!,
        nomeCompleto: _nomeController.text.trim(),
        whatsapp: _whatsappController.text.trim(),
        tipoMorador: _tipoUsuario,
        papelSistema: _perfilUsuario,
        consentimentoWhatsapp: _consentimentoWhatsapp,
        blocoTxt: blocoData['nome_ou_numero'] as String?,
        aptoTxt: aptoData['numero'] as String?,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro de Morador', style: TextStyle(color: Colors.white)),
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
          }
          if (state.status == AuthStatus.unauthenticated && state.errorMessage != null) {
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
            onStepContinue: () async {
              if (_currentStep == 0) {
                if (_selectedCondominiumId != null) {
                  setState(() => _currentStep += 1);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Selecione seu condomínio primeiro')),
                  );
                }
              } else if (_currentStep == 1) {
                // Valida apenas o e-mail primeiro para dar feedback imediato
                if (_emailController.text.isEmpty || !_emailController.text.contains('@')) {
                  _formKeyConta.currentState?.validate(); // Força exibição de "E-mail inválido"
                  return;
                }

                setState(() { _isCheckingEmail = true; _emailError = null; });
                try {
                  final isAvailable = await GetIt.instance<AuthRepository>().isEmailAvailable(
                    _emailController.text.trim(),
                  );
                  
                  if (!isAvailable) {
                    setState(() {
                      _emailError = 'Este e-mail já existe em nosso banco de dados. Tente fazer login.';
                      _isCheckingEmail = false;
                    });
                  } else {
                    // E-mail está livre, agora valida o resto do formulário (senhas)
                    if (_formKeyConta.currentState?.validate() ?? false) {
                      setState(() {
                        _isCheckingEmail = false;
                        _currentStep += 1;
                      });
                    } else {
                      setState(() => _isCheckingEmail = false);
                    }
                  }
                } catch (e) {
                  setState(() {
                    _emailError = 'Erro na validação: $e';
                    _isCheckingEmail = false;
                  });
                }
              }
 else if (_currentStep == 2) {
                 if (_formKeyDados.currentState?.validate() ?? false) {
                  setState(() => _currentStep += 1);
                }
              } else if (_currentStep == 3) {
                 if (_selectedBlocoId != null && _selectedApartamentoId != null) {
                   _submitRegistration();
                 } else {
                   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Selecione Bloco e Apartamento')),
                  );
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
              final isLastStep = _currentStep == 3;
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
                        child: Text(isLastStep ? 'Finalizar Cadastro' : 'Avançar'),
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
              // Passo 1: Busca do Condomínio
              Step(
                title: const Text('Condomínio'),
                isActive: _currentStep >= 0,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Qual é o seu condomínio?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    if (_selectedCondominiumName != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(_selectedCondominiumName!, style: const TextStyle(fontWeight: FontWeight.bold))),
                            IconButton(
                              icon: const Icon(Icons.close, color: AppColors.error),
                              onPressed: () {
                                setState(() {
                                  _selectedCondominiumId = null;
                                  _selectedCondominiumName = null;
                                  _condominioBuscaController.clear();
                                });
                              },
                            )
                          ],
                        ),
                      )
                    ] else ...[
                      TextField(
                        controller: _condominioBuscaController,
                        decoration: InputDecoration(
                          hintText: 'Digite o nome do condomínio',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _isSearching ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          ) : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: _onSearchCondominios,
                      ),
                      const SizedBox(height: 16),
                      if (_condominiosEncontrados.isNotEmpty)
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _condominiosEncontrados.length,
                          itemBuilder: (context, index) {
                            final condo = _condominiosEncontrados[index];
                            return ListTile(
                              leading: const Icon(Icons.apartment, color: AppColors.primary),
                              title: Text(condo['nome']),
                              subtitle: Text('${condo['cidade']} - ${condo['estado']}'),
                              onTap: () {
                                setState(() {
                                  _selectedCondominiumId = condo['id'];
                                  _selectedCondominiumName = condo['nome'];
                                  _selectedTipoEstrutura = condo['tipo_estrutura'] ?? 'predio';
                                });
                                _fetchBlocos();
                              },
                            );
                          },
                        ),
                    ]
                  ],
                ),
              ),
              
              // Passo 2: Dados de Login (E-mail e Senha)
              Step(
                title: const Text('Conta'),
                isActive: _currentStep >= 1,
                content: Form(
                  key: _formKeyConta,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Seu melhor e-mail',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (v) => v!.isEmpty || !v.contains('@') ? 'E-mail inválido' : null,
                        onChanged: (_) => setState(() => _emailError = null),
                      ),
                      if (_emailError != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_emailError!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_isCheckingEmail) ...[
                        const SizedBox(height: 12),
                        const Center(child: CircularProgressIndicator()),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Senha Numérica',
                          helperText: 'Apenas números (usado para FaceID depois)',
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

              // Passo 3: Dados Pessoais
              Step(
                title: const Text('Dados'),
                isActive: _currentStep >= 2,
                content: Form(
                  key: _formKeyDados,
                  child: Column(
                    children: [
                       TextFormField(
                        controller: _nomeController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Nome Completo',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (v) => v!.isEmpty ? 'Nome é obrigatório' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _whatsappController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'WhatsApp (Ex: 11999999999)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (v) => v!.isEmpty || v.length < 10 ? 'Telefone inválido' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _tipoUsuario,
                        decoration: InputDecoration(
                          labelText: 'Tipo de Usuário',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: [
                          'Proprietário (a)',
                          'Inquilino (a)',
                          'Cônjuge',
                          'Dependente',
                          'Família',
                          'Funcionário (a)',
                          'Terceirizado (a)',
                        ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (val) => setState(() => _tipoUsuario = val!),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _perfilUsuario,
                        decoration: InputDecoration(
                          labelText: 'Perfil de Usuário',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: [
                          'Morador(a)',
                          'Proprietário não morador',
                          'Locatário (a)',
                          'Locador',
                          'Funcionário (a)',
                          'Porteiro (a)',
                          'Zelador (a)',
                          'Síndico (a)',
                          'Sub Síndico (a)',
                          'Afiliado (a)',
                          'Terceirizado (a)',
                          'Financeiro',
                          'Serviços',
                        ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (val) => setState(() => _perfilUsuario = val!),
                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        title: const Text('Aceito receber notificações importantes pelo WhatsApp'),
                        value: _consentimentoWhatsapp,
                        onChanged: (val) => setState(() => _consentimentoWhatsapp = val ?? true),
                        activeColor: AppColors.primary,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),

              // Passo 4: Unidade Física
              Step(
                title: const Text('Unidade'),
                isActive: _currentStep >= 3,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Selecione onde você mora:', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedBlocoId,
                      decoration: InputDecoration(
                        labelText: 'Qual seu(sua) ${StructureHelper.getNivel1Label(_selectedTipoEstrutura)}?',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: _blocosDisponiveis.map((b) => DropdownMenuItem<String>(value: b['id'], child: Text('${StructureHelper.getNivel1Label(_selectedTipoEstrutura)} ${b['nome_ou_numero']}'))).toList(),
                      onChanged: (val) {
                        setState(() => _selectedBlocoId = val);
                        if (val != null) _fetchApartamentos(val);
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedApartamentoId,
                      decoration: InputDecoration(
                        labelText: 'Qual seu(sua) ${StructureHelper.getNivel2Label(_selectedTipoEstrutura)}?',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: _apartamentosDisponiveis.map((a) => DropdownMenuItem<String>(value: a['id'], child: Text('${StructureHelper.getNivel2Label(_selectedTipoEstrutura)} ${a['numero']}'))).toList(),
                      onChanged: (val) => setState(() => _selectedApartamentoId = val),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Ao clicar em finalizar, seu cadastro será enviado para aprovação do Síndico ou Administradora responsável pelo condomínio.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      textAlign: TextAlign.center,
                    )
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
