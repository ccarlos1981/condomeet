import 'package:flutter/material.dart';
import 'package:condomeet/core/design_system/design_system.dart';

class PhoneInputScreen extends StatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              Text(
                'Bem-vindo ao\nCondomeet',
                style: AppTypography.h1,
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
                hint: '(11) 99999-9999',
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
                label: _isLoading ? 'Enviando...' : 'Enviar Código',
                isLoading: _isLoading,
                onPressed: _handleSendCode,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSendCode() async {
    final phone = _phoneController.text.trim();
    
    if (phone.isEmpty) {
      _showError('Por favor, insira seu número de WhatsApp');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // TODO: Integrate with Supabase Auth
      // await supabase.auth.signInWithOtp(phone: '+55$phone');
      
      // For now, simulate API call
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        Navigator.of(context).pushNamed(
          '/otp-verification',
          arguments: phone,
        );
      }
    } catch (e) {
      _showError('Erro ao enviar código. Tente novamente.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }
}
