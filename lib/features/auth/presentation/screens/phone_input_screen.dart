import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_event.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_state.dart';

class PhoneInputScreen extends StatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _handleSendCode() {
    final phone = _phoneController.text.trim();
    
    if (phone.isEmpty) {
      _showError('Por favor, insira seu número de WhatsApp');
      return;
    }

    context.read<AuthBloc>().add(AuthPhoneSubmitted(phone));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state.status == AuthStatus.otpSent) {
          Navigator.of(context).pushNamed(
            '/otp-verification',
            arguments: state.phoneNumber,
          );
        } else if (state.errorMessage != null) {
          _showError(state.errorMessage!);
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final isLoading = state.status == AuthStatus.authenticating;
          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 48),
                    GestureDetector(
                      onLongPress: () {
                        context.read<AuthBloc>().add(AuthDevBypassRequested());
                      },
                      child: Text(
                        'Bem-vindo ao\nCondomeet',
                        style: AppTypography.h1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Entre com seu número de WhatsApp para receber o código de acesso.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 48),
                    CondoInput(
                      label: 'Número do WhatsApp',
                      hint: '11999999999',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      prefix: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '+55',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    CondoButton(
                      label: isLoading ? 'Enviando...' : 'Enviar Código',
                      isLoading: isLoading,
                      onPressed: isLoading ? null : _handleSendCode,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
