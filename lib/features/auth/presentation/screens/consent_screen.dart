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

class _ConsentScreenState extends State<ConsentScreen>
    with TickerProviderStateMixin {
  bool _termsAccepted = false;
  bool _privacyAccepted = false;
  bool _isLoading = false;

  late final AnimationController _shieldController;
  late final AnimationController _shakeController;
  late final Animation<double> _shieldAnimation;
  late final Animation<double> _shakeAnimation;

  bool get _canProceed => _termsAccepted && _privacyAccepted && !_isLoading;

  @override
  void initState() {
    super.initState();
    _shieldController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _shieldAnimation = Tween<double>(begin: 0.0, end: 12.0).animate(
      CurvedAnimation(parent: _shieldController, curve: Curves.easeInOut),
    );

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _shieldController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _triggerShake() {
    _shakeController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withOpacity(0.05),
              AppColors.background,
              AppColors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const SizedBox(height: 24),

                // Shield icon with floating animation
                AnimatedBuilder(
                  animation: _shieldAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, -_shieldAnimation.value),
                      child: child,
                    );
                  },
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withOpacity(0.7),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  'Proteção dos seus Dados',
                  style: AppTypography.h1.copyWith(
                    fontSize: 22,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Para sua segurança, precisamos do seu consentimento\npara processar seus dados conforme a LGPD.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),

                // Warning banner
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFFD666),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFF856404),
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'A aceitação é obrigatória para uso do aplicativo.',
                          style: AppTypography.bodySmall.copyWith(
                            color: const Color(0xFF856404),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Consent cards
                Expanded(
                  child: AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      final shakeOffset =
                          _shakeAnimation.value * 8 * (1 - _shakeAnimation.value);
                      return Transform.translate(
                        offset: Offset(
                          shakeOffset *
                              ((_shakeAnimation.value * 10).toInt().isEven
                                  ? 1
                                  : -1),
                          0,
                        ),
                        child: child,
                      );
                    },
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildConsentCard(
                            icon: Icons.description_outlined,
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
                                _termsOfUseText,
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildConsentCard(
                            icon: Icons.privacy_tip_outlined,
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
                                _privacyPolicyText,
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),

                // Accept button
                Padding(
                  padding: const EdgeInsets.only(bottom: 24, top: 8),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleButtonPress,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _canProceed
                                ? AppColors.primary
                                : Colors.grey.shade300,
                            foregroundColor:
                                _canProceed ? Colors.white : Colors.grey.shade500,
                            elevation: _canProceed ? 4 : 0,
                            shadowColor: _canProceed
                                ? AppColors.primary.withOpacity(0.4)
                                : Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _canProceed
                                          ? Icons.check_circle_outline
                                          : Icons.lock_outline,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Aceitar e Continuar',
                                      style: AppTypography.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: _canProceed
                                            ? Colors.white
                                            : Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Condomeet v1.0 • Todos os direitos reservados',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary.withOpacity(0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConsentCard({
    required IconData icon,
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool?> onChanged,
    required VoidCallback onViewDocument,
  }) {
    final isAccepted = value;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isAccepted
            ? const Color(0xFFF0FFF4)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAccepted
              ? const Color(0xFF38A169)
              : AppColors.border,
          width: isAccepted ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isAccepted
                ? const Color(0xFF38A169).withOpacity(0.1)
                : Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isAccepted
                      ? const Color(0xFF38A169).withOpacity(0.1)
                      : AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isAccepted ? Icons.check_circle : icon,
                  color: isAccepted
                      ? const Color(0xFF38A169)
                      : AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.h3.copyWith(
                    fontSize: 16,
                    color: isAccepted
                        ? const Color(0xFF276749)
                        : AppColors.textMain,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onViewDocument,
                icon: Icon(
                  Icons.open_in_new_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
                label: Text(
                  'Ler',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => onChanged(!value),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isAccepted
                        ? const Color(0xFF38A169)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isAccepted
                          ? const Color(0xFF38A169)
                          : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                  child: isAccepted
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    description,
                    style: AppTypography.bodyMedium.copyWith(
                      color: isAccepted
                          ? const Color(0xFF276749)
                          : AppColors.textSecondary,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleButtonPress() {
    if (!_canProceed) {
      _triggerShake();
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Você precisa aceitar ambos os termos para continuar utilizando o app.',
                  style: AppTypography.bodySmall.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFE53E3E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }
    _handleAccept();
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
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Consentimento registrado com sucesso!',
                  style: AppTypography.bodySmall.copyWith(color: Colors.white),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF38A169),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      title.contains('Privacidade')
                          ? Icons.privacy_tip_outlined
                          : Icons.description_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(title, style: AppTypography.h2),
                ],
              ),
            ),
            const Divider(height: 32),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Text(
                  content,
                  style: AppTypography.bodyMedium.copyWith(
                    height: 1.6,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: CondoButton(
                  label: 'Entendi',
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── LGPD Texts ─────────────────────────────────────────────

  static const String _termsOfUseText = '''
TERMOS DE USO — CONDOMEET

Última atualização: Março de 2026

1. ACEITAÇÃO DOS TERMOS
Ao utilizar o aplicativo Condomeet ("App"), você concorda integralmente com estes Termos de Uso. Caso não concorde, não utilize o App.

2. DESCRIÇÃO DO SERVIÇO
O Condomeet é uma plataforma digital de gestão condominial que oferece funcionalidades como:
• Comunicação entre moradores e administração
• Gestão de visitantes e controle de acesso
• Reserva de áreas comuns
• Acompanhamento de encomendas
• Registro e acompanhamento de ocorrências
• Comunicações oficiais e avisos
• Enquetes e votações condominiais

3. CADASTRO E CONTA
3.1. Para utilizar o App, é necessário realizar um cadastro vinculado ao seu condomínio.
3.2. Você é responsável por manter a confidencialidade de sua senha e PIN de acesso.
3.3. Suas credenciais são pessoais e intransferíveis.
3.4. O acesso ao App está condicionado à aprovação do síndico ou administrador do seu condomínio.

4. RESPONSABILIDADES DO USUÁRIO
4.1. Fornecer informações verdadeiras e mantê-las atualizadas.
4.2. Utilizar o App de forma ética e em conformidade com as leis aplicáveis.
4.3. Não utilizar o App para fins ilícitos, difamatórios ou que violem direitos de terceiros.
4.4. Respeitar as regras de convivência do seu condomínio.

5. PROPRIEDADE INTELECTUAL
Todo o conteúdo do App (design, código, marcas, logotipos) é de propriedade da 2SCapital e protegido pela legislação de propriedade intelectual.

6. LIMITAÇÃO DE RESPONSABILIDADE
6.1. O Condomeet não se responsabiliza por decisões tomadas com base nas informações do App.
6.2. Não garantimos disponibilidade ininterrupta do serviço.
6.3. A responsabilidade pela veracidade das informações inseridas é do usuário e do condomínio.

7. MODIFICAÇÕES
Reservamo-nos o direito de modificar estes Termos a qualquer momento, notificando os usuários através do próprio App.

8. CONTATO
Em caso de dúvidas sobre estes termos, entre em contato pelo e-mail: contato@condomeet.app.br
''';

  static const String _privacyPolicyText = '''
POLÍTICA DE PRIVACIDADE — CONDOMEET

Última atualização: Março de 2026

Em conformidade com a Lei Geral de Proteção de Dados Pessoais (LGPD — Lei nº 13.709/2018), informamos como tratamos seus dados pessoais.

1. DADOS COLETADOS
Coletamos os seguintes dados pessoais:
• Nome completo
• E-mail
• Número de WhatsApp
• Unidade/apartamento e bloco
• Foto de perfil (opcional)
• Tipo de morador (proprietário, inquilino, etc.)

Dados gerados pelo uso:
• Registros de visitantes autorizados
• Histórico de encomendas recebidas
• Reservas de áreas comuns
• Ocorrências registradas
• Mensagens enviadas pelo App

2. FINALIDADE DO TRATAMENTO
Seus dados são processados exclusivamente para:
• Gestão e administração condominial
• Controle de acesso e segurança
• Comunicação entre moradores e administração
• Entrega de encomendas e correspondências
• Reserva de espaços comuns
• Registro de ocorrências e demandas

3. BASE LEGAL
O tratamento é realizado com base no:
• Consentimento do titular (Art. 7º, I, LGPD)
• Execução de contrato (Art. 7º, V, LGPD)
• Legítimo interesse do controlador (Art. 7º, IX, LGPD)

4. COMPARTILHAMENTO
Seus dados NÃO são compartilhados com terceiros para fins de marketing ou publicidade. O compartilhamento ocorre apenas:
• Com o síndico e administração do seu condomínio
• Com prestadores de serviço essenciais (portaria, segurança)
• Por determinação legal ou judicial

5. RETENÇÃO DE DADOS
• Seus dados são mantidos enquanto você for morador ativo no condomínio.
• Após desvinculação, os dados são mantidos por 6 meses para fins de auditoria e segurança, sendo anonimizados ou excluídos após esse período.

6. SEUS DIREITOS (Art. 18, LGPD)
Você tem direito a:
• Confirmar a existência do tratamento
• Acessar seus dados
• Corrigir dados incompletos ou desatualizados
• Solicitar a anonimização ou exclusão
• Revogar o consentimento a qualquer momento
• Obter informações sobre o compartilhamento

7. SEGURANÇA
Adotamos medidas técnicas e administrativas para proteger seus dados:
• Criptografia em trânsito (HTTPS/TLS)
• Autenticação segura com PIN
• Controle de acesso baseado em perfil (RLS)
• Armazenamento em servidores seguros

8. NOTIFICAÇÕES
Com seu consentimento, poderemos enviar notificações via:
• Push notifications (celular)
• WhatsApp (avisos, encomendas, visitantes)
Você pode gerenciar suas preferências de notificação a qualquer momento nas configurações do App.

9. ENCARREGADO DE DADOS (DPO)
Para exercer seus direitos ou esclarecer dúvidas sobre o tratamento de dados:
E-mail: privacidade@condomeet.app.br

10. ALTERAÇÕES
Esta Política poderá ser atualizada periodicamente. Notificaremos você sobre alterações significativas através do App.
''';
}
