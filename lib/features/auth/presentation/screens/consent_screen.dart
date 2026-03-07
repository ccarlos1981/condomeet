import 'package:flutter/material.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/core/di/injection_container.dart';
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/features/auth/domain/repositories/consent_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_event.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _termsAccepted = false;
  bool _privacyAccepted = false;
  bool _isLoading = false;

  bool get _canProceed => _termsAccepted && _privacyAccepted && !_isLoading;

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
                          _showDocument(
                            'Termos de Uso',
                            'Estes são os termos de uso do Condomeet. Ao utilizar este aplicativo, você concorda em seguir as regras de convivência do seu condomínio e as normas de segurança estabelecidas.',
                          );
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
                          _showDocument(
                            'Política de Privacidade',
                            'Nós valorizamos sua privacidade. Seus dados (nome, unidade, fotos de encomendas) são processados exclusivamente para fins de gestão condominial e segurança, não sendo compartilhados com terceiros para fins de marketing.',
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              CondoButton(
                label: 'Aceitar e Continuar',
                isLoading: _isLoading,
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

  void _handleAccept() async {
    setState(() => _isLoading = true);

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuário não autenticado.')),
        );
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final repository = sl<ConsentRepository>();
      
      final repTerms = await repository.grantConsent(
        userId: user.id,
        consentType: 'terms_of_service',
      );
      if (repTerms is Failure) throw Exception(repTerms.message);

      final repPrivacy = await repository.grantConsent(
        userId: user.id,
        consentType: 'privacy_policy',
      );
      if (repPrivacy is Failure) throw Exception(repPrivacy.message);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Consentimento registrado com sucesso!'),
          ),
        );
        // Em vez de empurrar para a Home direto, pedimos pro AuthBloc reavaliar o estado.
        // Assim, quem não tem PIN será levado para a tela de PIN, e quem já tem vai pra Home.
        context.read<AuthBloc>().add(AuthCheckRequested());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showDocument(String title, String content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.h2),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Text(
                    content,
                    style: AppTypography.bodyMedium,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              CondoButton(
                label: 'Fechar',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
