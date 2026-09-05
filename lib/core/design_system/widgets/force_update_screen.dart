import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/core/services/version_check_service.dart';

class ForceUpdateScreen extends StatefulWidget {
  final VersionGateResult gateResult;
  final VoidCallback onRetry;

  const ForceUpdateScreen({
    super.key,
    required this.gateResult,
    required this.onRetry,
  });

  @override
  State<ForceUpdateScreen> createState() => _ForceUpdateScreenState();
}

class _ForceUpdateScreenState extends State<ForceUpdateScreen> {
  bool _isRetrying = false;
  String? _errorMessage;

  Future<void> _openStore() async {
    setState(() => _errorMessage = null);
    try {
      final isAndroid = Platform.isAndroid;
      final nativeUri = isAndroid
          ? Uri.parse('market://details?id=br.com.condod.wwwc')
          : Uri.parse('itms-apps://apps.apple.com/app/id6740927806');

      final webUri = Uri.parse(widget.gateResult.storeUrl.isNotEmpty
          ? widget.gateResult.storeUrl
          : (isAndroid
              ? 'https://play.google.com/store/apps/details?id=br.com.condod.wwwc'
              : 'https://apps.apple.com/app/condomeet/id6740927806'));

      // Tenta abrir primeiro o app da loja nativa
      bool launched = false;
      try {
        if (await canLaunchUrl(nativeUri)) {
          launched = await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {}

      // Fallback para URL HTTP caso a loja nativa não responda
      if (!launched) {
        if (await canLaunchUrl(webUri)) {
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
        } else {
          setState(() {
            _errorMessage = 'Não foi possível abrir a loja automaticamente. Acesse a loja do seu aparelho para atualizar.';
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao redirecionar para a loja: $e';
      });
    }
  }

  void _handleRetry() async {
    setState(() {
      _isRetrying = true;
      _errorMessage = null;
    });
    widget.onRetry();
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() => _isRetrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Impede voltar no Android
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                // Conteúdo Central
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ícone com Destaque
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.system_update_rounded,
                          size: 54,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Título
                    Text(
                      widget.gateResult.title.isNotEmpty
                          ? widget.gateResult.title
                          : 'Atualização Necessária',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Mensagem
                    Text(
                      widget.gateResult.message.isNotEmpty
                          ? widget.gateResult.message
                          : 'Uma nova versão do Condomeet está disponível com melhorias essenciais de segurança e estabilidade. Para continuar utilizando, por favor atualize o aplicativo.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Badge de Versões
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F6F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Versão instalada:',
                                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              ),
                              Text(
                                '${widget.gateResult.installedVersion} (Build ${widget.gateResult.installedBuild})',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.error),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Versão mínima exigida:',
                                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              ),
                              Text(
                                '${widget.gateResult.requiredVersion} (Build ${widget.gateResult.requiredBuild})',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.error, fontSize: 13),
                      ),
                    ],
                  ],
                ),

                // Botões de Ação
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _openStore,
                      icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                      label: const Text(
                        'ATUALIZAR AGORA',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isRetrying ? null : _handleRetry,
                      icon: _isRetrying
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            )
                          : const Icon(Icons.refresh_rounded, size: 20, color: AppColors.textSecondary),
                      label: const Text(
                        'Tentar Novamente',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
