import 'package:flutter/material.dart';
import 'core/design_system/design_system.dart';
import 'features/auth/presentation/screens/consent_screen.dart';
import 'features/auth/presentation/screens/phone_input_screen.dart';
import 'features/auth/presentation/screens/otp_verification_screen.dart';
import 'features/auth/presentation/screens/pin_setup_screen.dart';
import 'features/auth/presentation/screens/pin_unlock_screen.dart';
import 'features/portaria/presentation/screens/resident_search_screen.dart';
import 'features/portaria/presentation/screens/ocr_scanner_screen.dart';
import 'features/portaria/presentation/screens/parcel_registration_screen.dart';
import 'features/portaria/presentation/screens/parcel_dashboard_screen.dart';
import 'features/portaria/presentation/screens/pending_deliveries_screen.dart';
import 'features/portaria/presentation/screens/parcel_history_screen.dart';
import 'features/access/presentation/screens/invitation_generator_screen.dart';
import 'features/access/presentation/screens/guest_checkin_screen.dart';
import 'features/auth/presentation/screens/self_registration_screen.dart';
import 'features/auth/presentation/screens/waiting_approval_screen.dart';
import 'features/auth/presentation/screens/manager_approval_screen.dart';
import 'features/security/presentation/widgets/sos_button.dart';
import 'features/security/presentation/widgets/panic_overlay.dart';
import 'features/security/presentation/widgets/broadcast_card.dart';
import 'features/security/presentation/screens/occurrence_report_screen.dart';
import 'features/security/presentation/screens/chat_screen.dart';
import 'features/community/presentation/screens/area_picker_screen.dart';
import 'features/community/presentation/screens/document_center_screen.dart';
import 'package:condomeet/features/security/domain/models/broadcast.dart';
import 'package:condomeet/features/portaria/domain/repositories/resident_repository.dart';

void main() {
  runApp(const CondomeetApp());
}

class CondomeetApp extends StatelessWidget {
  const CondomeetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Condomeet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      initialRoute: '/design-system',
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            const PanicOverlay(),
          ],
        );
      },
      routes: {
        '/design-system': (context) => const DesignSystemShowcase(),
        '/login-phone': (context) => const PhoneInputScreen(),
        '/otp-verification': (context) => OtpVerificationScreen(
              phoneNumber: ModalRoute.of(context)!.settings.arguments as String,
            ),
        '/consent': (context) => const ConsentScreen(),
        '/pin-setup': (context) => const PinSetupScreen(),
        '/pin-unlock': (context) => const PinUnlockScreen(),
        '/resident-search': (context) => const ResidentSearchScreen(),
        '/ocr-scanner': (context) => const OcrScannerScreen(),
        '/parcel-registration': (context) {
          final resident = ModalRoute.of(context)!.settings.arguments as Resident;
          return ParcelRegistrationScreen(resident: resident);
        },
        '/parcel-dashboard': (context) {
          // In a real app, the residentId would come from the auth state
          // For testing/prototyping, we use a fixed ID
          return const ParcelDashboardScreen(residentId: 'res123');
        },
        '/pending-deliveries': (context) => const PendingDeliveriesScreen(),
        '/parcel-history': (context) {
          final residentId = ModalRoute.of(context)!.settings.arguments as String?;
          return ParcelHistoryScreen(residentId: residentId);
        },
        '/invitation-generator': (context) {
          // Fixed ID for prototyping
          return const InvitationGeneratorScreen(residentId: 'res123');
        },
        '/guest-checkin': (context) => const GuestCheckinScreen(),
        '/self-registration': (context) => const SelfRegistrationScreen(),
        '/waiting-approval': (context) => const WaitingApprovalScreen(),
        '/manager-approval': (context) => const ManagerApprovalScreen(),
        '/report-occurrence': (context) => const OccurrenceReportScreen(residentId: 'res123'),
        '/official-chat': (context) => const ChatScreen(residentId: 'res123'),
        '/area-booking': (context) => const AreaPickerScreen(),
        '/document-center': (context) => const DocumentCenterScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Condomeet Home'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Você está logado!'),
            const SizedBox(height: 24),
            CondoButton(
              label: 'Minhas Encomendas (Morador)',
              onPressed: () => Navigator.of(context).pushNamed('/parcel-dashboard'),
            ),
            const SizedBox(height: 12),
            CondoButton(
              label: 'Gerar Convite Digital (Morador)',
              onPressed: () => Navigator.of(context).pushNamed('/invitation-generator'),
            ),
            const SizedBox(height: 12),
            CondoButton(
              label: 'Ver Meu Histórico (Morador)',
              onPressed: () => Navigator.of(context).pushNamed('/parcel-history', arguments: 'res123'),
            ),
            const SizedBox(height: 12),
            CondoButton(
              label: 'Entregas Pendentes (Portaria)',
              onPressed: () => Navigator.of(context).pushNamed('/pending-deliveries'),
            ),
            const SizedBox(height: 12),
            CondoButton(
              label: 'Terminal de Visitantes (Portaria)',
              onPressed: () => Navigator.of(context).pushNamed('/guest-checkin'),
            ),
            const SizedBox(height: 12),
            CondoButton(
              label: 'Auto-Cadastro (Novo Morador)',
              onPressed: () => Navigator.of(context).pushNamed('/self-registration'),
            ),
            const SizedBox(height: 12),
            CondoButton(
              label: 'Ir para Login (Teste)',
              onPressed: () => Navigator.of(context).pushNamed('/login-phone'),
            ),
          ],
        ),
      ),
    );
  }
}

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
            const SOSButton(residentId: 'res123'),
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
