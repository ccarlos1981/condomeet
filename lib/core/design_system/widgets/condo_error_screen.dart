import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:condomeet/core/design_system/design_system.dart';

class CondoErrorScreen extends StatelessWidget {
  final FlutterErrorDetails? details;
  final VoidCallback? onRetry;

  const CondoErrorScreen({
    super.key,
    this.details,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: AppColors.background,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: 80,
                ),
                const SizedBox(height: 24),
                Text(
                  'Ops! Algo deu errado',
                  style: AppTypography.h2.copyWith(color: AppColors.textMain),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Ocorreu um erro inesperado. Nossa equipe técnica já foi notificada para resolver isso o mais rápido possível.',
                  style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                if (onRetry != null)
                  CondoButton(
                    label: 'Tentar Novamente',
                    onPressed: onRetry,
                  ),

                if (kDebugMode && details != null) ...[
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    'Detalhamento do Erro (Apenas visível em modo Debug):',
                    style: AppTypography.label.copyWith(color: AppColors.error),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          details?.exceptionAsString() ?? 'Erro desconhecido',
                          style: const TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 12,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
