import 'package:flutter/material.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/features/security/presentation/widgets/sos_button.dart';
import 'package:condomeet/features/security/presentation/widgets/broadcast_card.dart';
import 'package:condomeet/features/security/domain/models/broadcast.dart';

class DesignSystemShowcase extends StatelessWidget {
  const DesignSystemShowcase({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Condomeet Design System'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Navegação de Teste', style: AppTypography.h2),
            const SizedBox(height: 16),
            CondoButton(
                label: 'Fluxo de Login (Phone -> OTP -> PIN)',
                onPressed: () => Navigator.of(context).pushNamed('/login-phone')),
            const SizedBox(height: 8),
            CondoButton(
                label: 'Tela de Desbloqueio (PIN)',
                onPressed: () => Navigator.of(context).pushNamed('/pin-unlock')),
            const SizedBox(height: 8),
            CondoButton(
                label: 'Busca de Moradores (Portaria)',
                onPressed: () => Navigator.of(context).pushNamed('/resident-search')),
            const SizedBox(height: 8),
            CondoButton(
                label: 'Dashboard de Encomendas (Morador)',
                onPressed: () => Navigator.of(context).pushNamed('/parcel-dashboard')),
            const SizedBox(height: 8),
            CondoButton(
                label: 'Entregas Pendentes (Portaria)',
                onPressed: () => Navigator.of(context).pushNamed('/pending-deliveries')),
            const SizedBox(height: 8),
            CondoButton(
                label: 'Histórico de Entregas (Admin)',
                onPressed: () => Navigator.of(context).pushNamed('/parcel-history')),
            const SizedBox(height: 8),
            CondoButton(
                label: 'Gerador de Convites (Morador)',
                onPressed: () => Navigator.of(context).pushNamed('/invitation-generator')),
            const SizedBox(height: 8),
            CondoButton(
                label: 'Terminal de Visitantes (Portaria)',
                onPressed: () => Navigator.of(context).pushNamed('/guest-checkin')),
            const SizedBox(height: 8),
            CondoButton(
                label: 'Auto-Cadastro (Morador)',
                onPressed: () => Navigator.of(context).pushNamed('/self-registration')),
            const SizedBox(height: 8),
            CondoButton(
                label: 'Aprovações (Gestor/Admin)',
                onPressed: () => Navigator.of(context).pushNamed('/manager-approval')),
            const SizedBox(height: 32),
            Text('Segurança', style: AppTypography.h2),
            const SizedBox(height: 16),
            const SOSButton(residentId: null),
            const SizedBox(height: 32),
            Text('Comunicados Oficiais', style: AppTypography.h2),
            const SizedBox(height: 16),
            BroadcastCard(
              broadcast: Broadcast(
                id: '1',
                title: 'Aviso Importante',
                content: 'Comunicado de teste com prioridade normal.',
                timestamp: DateTime.now(),
                priority: BroadcastPriority.normal,
              ),
            ),
            BroadcastCard(
              broadcast: Broadcast(
                id: '2',
                title: 'Alerta Crítico',
                content: 'Comunicado urgente que exige atenção imediata de todos os moradores.',
                timestamp: DateTime.now(),
                priority: BroadcastPriority.critical,
              ),
            ),
            const SizedBox(height: 16),
            CondoButton(
              label: 'Relatar Ocorrência (Morador)',
              onPressed: () => Navigator.of(context).pushNamed('/report-occurrence'),
            ),
            const SizedBox(height: 12),
            CondoButton(
              label: 'Chat Oficial (Morador)',
              onPressed: () => Navigator.of(context).pushNamed('/official-chat'),
            ),
            const SizedBox(height: 32),
            Text('Vida em Comum', style: AppTypography.h2),
            const SizedBox(height: 16),
            CondoButton(
              label: 'Reservar Espaço (Morador)',
              onPressed: () => Navigator.of(context).pushNamed('/area-booking'),
            ),
            const SizedBox(height: 12),
            CondoButton(
              label: 'Central de Documentos (Morador)',
              onPressed: () => Navigator.of(context).pushNamed('/document-center'),
            ),
            const SizedBox(height: 32),
            Text('Typography', style: AppTypography.h2),
            const SizedBox(height: 16),
            Text('Heading 1 (Outfit)', style: AppTypography.h1),
            Text('Heading 2 (Outfit)', style: AppTypography.h2),
            Text('Body Large (Inter)', style: AppTypography.bodyLarge),
            
            const SizedBox(height: 32),
            Text('Buttons', style: AppTypography.h2),
            const SizedBox(height: 16),
            CondoButton(
              label: 'Primary Button',
              onPressed: () {},
            ),
            const SizedBox(height: 12),
            CondoButton(
              label: 'Loading Button',
              isLoading: true,
              onPressed: () {},
            ),
            
            const SizedBox(height: 32),
            Text('Inputs', style: AppTypography.h2),
            const SizedBox(height: 16),
            const CondoInput(
              label: 'Email Address',
              hint: 'Enter your email',
              prefix: Icon(Icons.email_outlined),
            ),
            const SizedBox(height: 16),
            const CondoInput(
              label: 'Password',
              hint: 'Enter your password',
              isPassword: true,
              prefix: Icon(Icons.lock_outline),
            ),
          ],
        ),
      ),
    );
  }
}
