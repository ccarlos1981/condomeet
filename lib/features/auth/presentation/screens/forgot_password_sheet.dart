import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

/// Bottom sheet com 2 steps para reset de senha via WhatsApp.
class ForgotPasswordSheet extends StatefulWidget {
  final String? initialEmail;
  const ForgotPasswordSheet({super.key, this.initialEmail});

  static void show(BuildContext context, {String? email}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<AuthBloc>(),
        child: ForgotPasswordSheet(initialEmail: email),
      ),
    );
  }

  @override
  State<ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<ForgotPasswordSheet> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isStep2 = false;
  String? _maskedWhatsapp;
  String? _errorMsg;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null) {
      _emailController.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state.status == AuthStatus.forgotPasswordCodeSent) {
          setState(() {
            _isStep2 = true;
            _isLoading = false;
            _maskedWhatsapp = state.maskedWhatsapp;
            _errorMsg = state.errorMessage;
          });
        } else if (state.status == AuthStatus.authenticated) {
          Navigator.of(context).pop();
        } else if (state.status == AuthStatus.unauthenticated && state.errorMessage != null) {
          setState(() {
            _isLoading = false;
            _errorMsg = state.errorMessage;
          });
        } else if (state.status == AuthStatus.authenticating) {
          setState(() => _isLoading = true);
        }
      },
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top handle
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // Title
              Row(
                children: [
                  if (_isStep2)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => setState(() { _isStep2 = false; _errorMsg = null; }),
                    ),
                  const Icon(Icons.lock_reset, color: AppColors.primary, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    _isStep2 ? 'Verificar Código' : 'Esqueci a Senha',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_errorMsg != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_errorMsg!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                ),
              if (!_isStep2) _buildStep1() else _buildStep2(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Digite seu email cadastrado.\nEnviaremos um código de verificação para o seu WhatsApp.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'Seu email',
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _requestCode,
          icon: _isLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send, size: 18),
          label: Text(_isLoading ? 'Enviando...' : 'Enviar código via WhatsApp'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF25D366), // WhatsApp green
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            children: [
              const TextSpan(text: 'Código enviado para o WhatsApp '),
              TextSpan(
                text: _maskedWhatsapp ?? '***',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain),
              ),
              const TextSpan(text: '.\nDigite o código e a nova senha.'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Code field
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '000000',
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 16),
        // New password
        TextField(
          controller: _newPasswordController,
          keyboardType: TextInputType.number,
          obscureText: _obscureNew,
          decoration: InputDecoration(
            hintText: 'Nova senha (somente números)',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscureNew = !_obscureNew),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 12),
        // Confirm password
        TextField(
          controller: _confirmPasswordController,
          keyboardType: TextInputType.number,
          obscureText: _obscureConfirm,
          decoration: InputDecoration(
            hintText: 'Confirmar nova senha',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _submitReset,
          icon: _isLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_circle_outline, size: 18),
          label: Text(_isLoading ? 'Processando...' : 'Confirmar Nova Senha'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _isLoading ? null : _requestCode,
          child: const Text('Não recebeu? Enviar novamente', style: TextStyle(color: AppColors.textSecondary)),
        ),
      ],
    );
  }

  void _requestCode() {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMsg = 'Digite um email válido');
      return;
    }
    setState(() => _errorMsg = null);
    context.read<AuthBloc>().add(AuthForgotPasswordRequested(email: email));
  }

  void _submitReset() {
    final code = _codeController.text.trim();
    final newPass = _newPasswordController.text.trim();
    final confirmPass = _confirmPasswordController.text.trim();

    if (code.length != 6) {
      setState(() => _errorMsg = 'O código deve ter 6 dígitos.');
      return;
    }
    if (newPass.length < 4) {
      setState(() => _errorMsg = 'A senha deve ter no mínimo 4 dígitos.');
      return;
    }
    if (int.tryParse(newPass) == null) {
      setState(() => _errorMsg = 'A senha deve conter apenas números.');
      return;
    }
    if (newPass != confirmPass) {
      setState(() => _errorMsg = 'As senhas não coincidem.');
      return;
    }
    setState(() => _errorMsg = null);
    context.read<AuthBloc>().add(AuthResetCodeSubmitted(
      email: _emailController.text.trim().toLowerCase(),
      code: code,
      newPassword: newPass,
    ));
  }
}
