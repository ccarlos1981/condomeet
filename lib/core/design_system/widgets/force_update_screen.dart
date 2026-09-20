import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/core/services/version_check_service.dart';

class ForceUpdateScreen extends StatelessWidget {
  final VersionGateResult gateResult;
  final VoidCallback? onRetry;

  const ForceUpdateScreen({
    super.key,
    required this.gateResult,
    this.onRetry,
  });

  Future<void> _openStore() async {
    final rawUrl = gateResult.storeUrl.trim();
    if (rawUrl.isEmpty) {
      debugPrint('⚠️ [ForceUpdate] Nenhuma URL de loja configurada na política remota.');
      return;
    }

    try {
      final uri = Uri.parse(rawUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('⚠️ [ForceUpdate] Erro ao abrir URL da loja ($rawUrl): $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Bloqueia botão voltar do Android e gestos de retorno
      child: Scaffold(
        backgroundColor: Colors.black54, // Bloqueio total da tela com backdrop escuro
        body: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28.0),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ícone de Destaque
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.system_update_rounded,
                      size: 34,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Texto Obrigatório do Popup
                const Text(
                  'Você precisa atualizar o aplicativo para continuar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMain,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),

                // Somente o botão "Atualizar"
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _openStore,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Atualizar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
