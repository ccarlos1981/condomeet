import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/features/security/presentation/bloc/sos_bloc.dart';
import 'package:condomeet/features/security/presentation/bloc/sos_state.dart';
import 'package:condomeet/features/security/presentation/bloc/sos_event.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';

class PanicOverlay extends StatelessWidget {
  const PanicOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SOSBloc, SOSState>(
      builder: (context, state) {
        final activeState = state is SOSActive ? state : null;
        final isActive = activeState != null && activeState.alerts.isNotEmpty;
        final alert = isActive ? activeState.alerts.first : null;

        if (!isActive || alert == null) {
          return const SizedBox.shrink();
        }

        return Material(
                  color: Colors.black54,
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.all(32),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.5),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 80),
                          const SizedBox(height: 16),
                          Text(
                            'PÂNICO! SOS ATIVADO',
                            style: AppTypography.h1.copyWith(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          _buildAlertInfo('Morador', alert.residentName),
                          _buildAlertInfo('Unidade', alert.unit ?? 'Não informado'),
                          _buildAlertInfo('Local', '${alert.latitude}, ${alert.longitude}'),
                          const SizedBox(height: 32),
                          CondoButton(
                            label: 'RECONHECER ACIONAMENTO',
                            onPressed: () {
                              final authState = context.read<AuthBloc>().state;
                              if (authState.userId != null) {
                                context.read<SOSBloc>().add(AcknowledgeSOSRequested(
                                  alertId: alert.id,
                                  porterId: authState.userId!,
                                ));
                              }
                            },
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.red,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
      },
    );
  }

  Widget _buildAlertInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
