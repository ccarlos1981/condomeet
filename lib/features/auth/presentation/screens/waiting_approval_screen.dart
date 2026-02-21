import 'package:flutter/material.dart';
import 'package:condomeet/core/design_system/design_system.dart';

class WaitingApprovalScreen extends StatelessWidget {
  const WaitingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Hero(
              tag: 'clock_icon',
              child: Icon(Icons.access_time_filled, size: 100, color: Colors.orange),
            ),
            const SizedBox(height: 32),
            Text(
              'Solicitação Enviada!',
              style: AppTypography.h1,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Seus dados foram enviados para o administrador do condomínio. Você receberá um alerta assim que seu acesso for liberado.',
              style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Dica: Isso costuma levar menos de 24h úteis.',
                      style: AppTypography.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 64),
            CondoButton(
              label: 'Entendi',
              onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false),
            ),
          ],
        ),
      ),
    );
  }
}
