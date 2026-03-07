import 'package:flutter/material.dart';
import 'package:condomeet/core/design_system/design_system.dart';

class BlockedAccessOverlay extends StatelessWidget {
  final Widget child;
  final bool isBlocked;

  const BlockedAccessOverlay({
    super.key,
    required this.child,
    required this.isBlocked,
  });

  @override
  Widget build(BuildContext context) {
    if (!isBlocked) return child;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Acesso Restrito'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.block,
                color: Colors.red,
                size: 80,
              ),
              const SizedBox(height: 24),
              Text(
                'Unidade Bloqueada',
                style: AppTypography.h2.copyWith(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'O acesso a esta funcionalidade foi suspenso pela administração do condomínio. Por favor, entre em contato para regularizar sua situação.',
                style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              CondoButton(
                label: 'Voltar ao Início',
                onPressed: () => Navigator.of(context).pushReplacementNamed('/home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
