import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/core/design_system/condo_button.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_event.dart';

class WaitingApprovalScreen extends StatelessWidget {
  const WaitingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.access_time_filled_rounded,
                  size: 80,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Solicitação Enviada!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textMain),
              ),
              const SizedBox(height: 16),
              const Text(
                'Seus dados foram enviados para o administrador do condomínio. Você receberá uma notificação assim que seu acesso for liberado.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 48),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.primary),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Dica: O síndico costuma analisar solicitações em horários comerciais.',
                        style: TextStyle(fontSize: 14, color: AppColors.textMain),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              CondoButton(
                label: 'Sair e Voltar ao Início',
                onPressed: () => context.read<AuthBloc>().add(const AuthLogoutRequested()),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
