import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/core/design_system/condo_button.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_event.dart';

class InactiveAccountScreen extends StatelessWidget {
  const InactiveAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            context.read<AuthBloc>().add(const AuthCheckRequested());
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),
                      // Ícone Institucional Neutro
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.home_work_outlined,
                          size: 72,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Título Canônico
                      const Text(
                        'Cadastro inativo',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Mensagem Institucional Canônica
                      const Text(
                        'Seu cadastro não possui um vínculo residencial ativo neste condomínio no momento.\n\nSe você ainda reside aqui ou precisa recuperar seu acesso, entre em contato com a administração do condomínio.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Card Informativo
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: AppColors.primary, size: 22),
                            SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                'A administração do condomínio pode reativar seu vínculo se você for morador.',
                                style: TextStyle(fontSize: 13, color: AppColors.textMain, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 24),

                      // Ação: Verificar Status
                      CondoButton(
                        label: 'Verificar Status',
                        onPressed: () => context.read<AuthBloc>().add(const AuthCheckRequested()),
                      ),
                      const SizedBox(height: 12),

                      // Ação: Logout
                      CondoButton(
                        label: 'Sair e Voltar ao Início',
                        backgroundColor: Colors.transparent,
                        foregroundColor: AppColors.textSecondary,
                        onPressed: () => context.read<AuthBloc>().add(const AuthLogoutRequested()),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
