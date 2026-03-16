import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import '../../domain/repositories/auth_repository.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'password_setup_sheet.dart';
import 'waiting_approval_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitLogin() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
        AuthLoginSubmitted(
          email: _emailController.text.trim().toLowerCase(),
          password: _passwordController.text.trim(),
        ),
      );
    }
  }

  void _navigateToRegistration() {
    Navigator.pushNamed(context, '/self-registration');
  }

  void _showForgotPasswordDialog() {
    final emailCtrl = TextEditingController(text: _emailController.text.trim());
    showDialog(
      context: context,
      builder: (ctx) {
        bool sending = false;
        String? msg;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Esqueci a senha'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Digite seu email e enviaremos um link para redefinir sua senha.'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'Seu email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  if (msg != null) ...[
                    const SizedBox(height: 12),
                    Text(msg!, style: TextStyle(color: msg!.startsWith('✅') ? Colors.green : AppColors.error, fontSize: 13)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Fechar'),
                ),
                ElevatedButton(
                  onPressed: sending
                      ? null
                      : () async {
                          final email = emailCtrl.text.trim().toLowerCase();
                          if (email.isEmpty || !email.contains('@')) {
                            setDialogState(() => msg = 'Digite um email válido');
                            return;
                          }
                          setDialogState(() { sending = true; msg = null; });
                          try {
                            await GetIt.instance<AuthRepository>().resetPasswordForEmail(email);
                            setDialogState(() {
                              sending = false;
                              msg = '✅ Email enviado! Verifique sua caixa de entrada.';
                            });
                          } catch (e) {
                            setDialogState(() {
                              sending = false;
                              msg = 'Erro ao enviar. Verifique o email.';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: sending
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Enviar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state.status == AuthStatus.needsPasswordSetup && state.phoneNumber != null) {
            PasswordSetupSheet.show(context, state.phoneNumber!);
          } else if (state.status == AuthStatus.unauthenticated && state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!), backgroundColor: AppColors.error),
            );
          } else if (state.status == AuthStatus.needsRegistration) {
             ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Usuário não encontrado. Crie seu cadastro.'), backgroundColor: AppColors.error),
            );
          } else if (state.status == AuthStatus.pendingApproval) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const WaitingApprovalScreen()),
              (route) => false,
            );
          }
        },
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 48),
                  // Logo Placeholder (Usually an image here)
                  Center(
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 90,
                      height: 90,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Condomeet',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const Text(
                    'seu Condomínio Digital',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // Botão de Cadastro Novo
                  ElevatedButton(
                    onPressed: _navigateToRegistration,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Ainda não tem cadastro? Clique aqui!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 32),
                  
                  const Text(
                    'Já é cadastrado?\nDigite E-mail e Senha',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Formulário de Login
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'Digite seu email',
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty || !value.contains('@')) {
                              return 'Digite um e-mail válido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          keyboardType: TextInputType.number, // SOMENTE NÚMEROS
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly, // REGRA: Apenas digitos numéricos
                          ],
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: 'Senha (somente números)',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Digite sua senha';
                            }
                            if (int.tryParse(value) == null) {
                              return 'A senha deve conter apenas números';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: _rememberMe,
                                  onChanged: (val) => setState(() => _rememberMe = val ?? true),
                                  activeColor: AppColors.primary,
                                ),
                                const Text('Lembrar Senha'),
                              ],
                            ),
                            TextButton(
                              onPressed: _showForgotPasswordDialog,
                              child: const Text(
                                'Esqueci a senha',
                                style: TextStyle(
                                  color: AppColors.textMain,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        BlocBuilder<AuthBloc, AuthState>(
                          builder: (context, state) {
                            final isLoading = state.status == AuthStatus.authenticating;
                            return SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: isLoading ? null : _submitLogin,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(color: AppColors.primary, width: 2),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: isLoading
                                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Text('Acessar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/sindico-registration');
                    },
                    child: const Text(
                      'Sou Síndico e quero registrar meu condomínio',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        decoration: TextDecoration.underline,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'Todos os direitos reservados à @2SCapital @2026\nPolítica de Privacidade',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
