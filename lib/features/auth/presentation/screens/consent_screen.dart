import 'package:flutter/material.dart';
import 'package:condomeet/core/design_system/design_system.dart';

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _termsAccepted = false;
  bool _privacyAccepted = false;

  bool get _canProceed => _termsAccepted && _privacyAccepted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Text(
                'Bem-vindo ao Condomeet',
                style: AppTypography.h1,
              ),
              const SizedBox(height: 16),
              Text(
                'Para continuar, precisamos do seu consentimento para processar seus dados de acordo com a LGPD.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildConsentCard(
                        title: 'Termos de Uso',
                        description:
                            'Li e aceito os Termos de Uso do Condomeet.',
                        value: _termsAccepted,
                        onChanged: (value) {
                          setState(() => _termsAccepted = value ?? false);
                        },
                        onViewDocument: () {
                          // TODO: Navigate to Terms of Use document
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildConsentCard(
                        title: 'Política de Privacidade',
                        description:
                            'Li e aceito a Política de Privacidade e o tratamento dos meus dados pessoais.',
                        value: _privacyAccepted,
                        onChanged: (value) {
                          setState(() => _privacyAccepted = value ?? false);
                        },
                        onViewDocument: () {
                          // TODO: Navigate to Privacy Policy document
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              CondoButton(
                label: 'Aceitar e Continuar',
                onPressed: _canProceed ? _handleAccept : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConsentCard({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool?> onChanged,
    required VoidCallback onViewDocument,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.h3,
                ),
              ),
              TextButton(
                onPressed: onViewDocument,
                child: Text(
                  'Ler documento',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: value,
            onChanged: onChanged,
            title: Text(
              description,
              style: AppTypography.bodyMedium,
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  void _handleAccept() {
    // TODO: Save consent to database via BLoC
    // For now, just navigate to main app
    Navigator.of(context).pushReplacementNamed('/home');
  }
}
