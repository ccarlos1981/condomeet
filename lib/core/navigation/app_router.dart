import 'package:flutter/material.dart';
import 'package:condomeet/core/design_system/widgets/blocked_access_overlay.dart';
import 'package:condomeet/features/auth/presentation/screens/login_screen.dart';
import 'package:condomeet/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:condomeet/features/auth/presentation/screens/consent_screen.dart';
import 'package:condomeet/features/auth/presentation/screens/pin_setup_screen.dart';
import 'package:condomeet/features/auth/presentation/screens/pin_unlock_screen.dart';
import 'package:condomeet/features/auth/presentation/screens/self_registration_screen.dart';
import 'package:condomeet/features/auth/presentation/screens/sindico_registration_screen.dart';
import 'package:condomeet/features/auth/presentation/screens/manager_approval_screen.dart';
import 'package:condomeet/features/auth/presentation/screens/waiting_approval_screen.dart';
import 'package:condomeet/features/portaria/presentation/screens/resident_search_screen.dart';
import 'package:condomeet/features/portaria/presentation/screens/ocr_scanner_screen.dart';
import 'package:condomeet/features/portaria/presentation/screens/parcel_registration_screen.dart';
import 'package:condomeet/features/portaria/presentation/screens/parcel_dashboard_screen.dart';
import 'package:condomeet/features/portaria/presentation/screens/pending_deliveries_screen.dart';
import 'package:condomeet/features/portaria/presentation/screens/parcel_history_screen.dart';
import 'package:condomeet/features/portaria/presentation/screens/visitor_registration_screen.dart';
import 'package:condomeet/features/admin/presentation/screens/enquete_admin_screen.dart';
import 'package:condomeet/features/enquete/presentation/screens/enquete_voting_screen.dart';

import 'package:condomeet/features/access/presentation/screens/visitor_authorization_screen.dart';
import 'package:condomeet/features/access/presentation/screens/portaria_visitor_approval_screen.dart';
import 'package:condomeet/features/access/presentation/screens/portaria_visitor_authorization_form_screen.dart';
import 'package:condomeet/features/community/presentation/screens/documents_screen.dart';
import 'package:condomeet/features/community/presentation/screens/contracts_screen.dart';
import 'package:condomeet/features/community/presentation/screens/admin_documentos_screen.dart';
import 'package:condomeet/features/community/presentation/screens/admin_contratos_screen.dart';
import 'package:condomeet/features/community/presentation/screens/area_picker_screen.dart';
import 'package:condomeet/features/community/presentation/screens/areas_comuns_admin_screen.dart';
import 'package:condomeet/features/community/presentation/screens/admin_horarios_screen.dart';
import 'package:condomeet/features/security/presentation/screens/chat_screen.dart';
import 'package:condomeet/features/security/presentation/screens/occurrence_report_screen.dart';
import 'package:condomeet/features/security/presentation/screens/occurrence_history_screen.dart';
import 'package:condomeet/features/security/presentation/screens/occurrence_admin_screen.dart';
import 'package:condomeet/features/security/presentation/screens/sos_screen.dart';
import 'package:condomeet/features/security/presentation/screens/sos_contatos_screen.dart';
import 'package:condomeet/features/notifications/presentation/screens/avisos_screen.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_state.dart';
import 'package:condomeet/features/dev/presentation/screens/design_system_showcase.dart';
import 'package:condomeet/features/home/presentation/screens/home_screen.dart';
import 'package:condomeet/features/home/presentation/screens/admin_screen.dart';
import 'package:condomeet/features/admin/presentation/screens/inventory_list_screen.dart';
import 'package:condomeet/features/admin/presentation/screens/inventory_detail_screen.dart';
import 'package:condomeet/features/admin/presentation/screens/assembly_list_screen.dart';
import 'package:condomeet/features/admin/presentation/screens/assembly_detail_screen.dart';
import 'package:condomeet/features/admin/presentation/screens/condominium_structure_screen.dart';
import 'package:condomeet/features/admin/presentation/screens/configure_menu_screen.dart';
import 'package:condomeet/features/security/presentation/screens/fale_sindico_screen.dart';
import 'package:condomeet/features/security/presentation/screens/fale_conosco_admin_screen.dart';
import 'package:condomeet/features/auth/presentation/screens/splash_screen.dart';
import 'package:condomeet/features/admin/presentation/screens/universal_push_screen.dart';


class AppRouter {
  static Map<String, WidgetBuilder> getRoutes(AuthState state) {
    return {
      '/design-system': (context) => const DesignSystemShowcase(),
      '/splash': (context) => const SplashScreen(),
      '/login': (context) => const LoginScreen(),
      '/otp-verification': (context) => OtpVerificationScreen(
            phoneNumber: ModalRoute.of(context)!.settings.arguments as String,
          ),
      '/consent': (context) => const ConsentScreen(),
      '/pin-setup': (context) => const PinSetupScreen(),
      '/pin-unlock': (context) => const PinUnlockScreen(),
      '/resident-search': (context) => const ResidentSearchScreen(),
      '/ocr-scanner': (context) => const OcrScannerScreen(),
      '/parcel-registration': (context) => const ParcelRegistrationScreen(),
      '/parcel-dashboard': (context) {
        return ParcelDashboardScreen(residentId: state.userId ?? '');
      },
      '/pending-deliveries': (context) => const PendingDeliveriesScreen(),
      '/visitor-registration': (context) => const VisitorRegistrationScreen(),
      '/registrar-visitante': (context) => const VisitorRegistrationScreen(), // alias for stale DB configs
      '/enquete-admin': (context) => const EnqueteAdminScreen(),
      '/enquetes': (context) => const EnqueteVotingScreen(),
      '/parcel-history': (context) {
        final residentId = (ModalRoute.of(context)!.settings.arguments as String?) ?? state.userId;
        return ParcelHistoryScreen(residentId: residentId);
      },
      '/invitation-generator': (context) {
        return BlockedAccessOverlay(
          isBlocked: state.isUnitBlocked,
          child: const VisitorAuthorizationScreen(),
        );
      },
      '/guest-checkin': (context) => const PortariaVisitorApprovalScreen(),
      '/self-registration': (context) => const SelfRegistrationScreen(),
      '/sindico-registration': (context) => const SindicoRegistrationScreen(),
      '/waiting-approval': (context) => const WaitingApprovalScreen(),
      '/manager-approval': (context) => const ManagerApprovalScreen(),
      '/report-occurrence': (context) => BlockedAccessOverlay(
            isBlocked: state.isUnitBlocked,
            child: OccurrenceHistoryScreen(residentId: state.userId ?? ''),
          ),
      '/new-occurrence': (context) => BlockedAccessOverlay(
            isBlocked: state.isUnitBlocked,
            child: OccurrenceReportScreen(residentId: state.userId ?? ''),
          ),
      '/occurrence-admin': (context) => const OccurrenceAdminScreen(),
      '/official-chat': (context) => BlockedAccessOverlay(
            isBlocked: state.isUnitBlocked,
            child: ChatScreen(residentId: state.userId ?? ''),
          ),
      '/admin-areas-comuns': (context) => const AreasComunsAdminScreen(),
      '/admin-horarios': (context) {
        final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
        return AdminHorariosScreen(
          areaId: args['areaId'] as String,
          tipoAgenda: args['tipo'] as String? ?? '',
        );
      },
      '/area-booking': (context) => BlockedAccessOverlay(
            isBlocked: state.isUnitBlocked,
            child: const AreaPickerScreen(),
          ),
      '/document-center': (context) => BlockedAccessOverlay(
            isBlocked: state.isUnitBlocked,
            child: const DocumentsScreen(),
          ),
      '/documentos': (context) => BlockedAccessOverlay(
            isBlocked: state.isUnitBlocked,
            child: const DocumentsScreen(),
          ),
      '/contratos': (context) => BlockedAccessOverlay(
            isBlocked: state.isUnitBlocked,
            child: const ContractsScreen(),
          ),
      '/admin-documentos': (context) => const AdminDocumentosScreen(),
      '/admin-contratos': (context) => const AdminContratosScreen(),
      '/inventory': (context) => const InventoryListScreen(),
      '/inventory-detail': (context) {
        final itemId = ModalRoute.of(context)!.settings.arguments as String;
        return InventoryDetailScreen(itemId: itemId);
      },
      '/assemblies': (context) => const AssemblyListScreen(),
      '/assembly-detail': (context) {
        final assemblyId = ModalRoute.of(context)!.settings.arguments as String;
        return AssemblyDetailScreen(assemblyId: assemblyId);
      },
      '/home': (context) => const HomeScreen(),
      '/admin': (context) => const AdminScreen(),
      '/condo-structure': (context) => const CondominiumStructureScreen(),
      '/portaria-visitor-approval': (context) => const PortariaVisitorAuthorizationFormScreen(),
      '/configure-menu': (context) => const ConfigureMenuScreen(),
      '/sos': (context) => const SosScreen(),
      '/sos-contatos': (context) => const SosContatosScreen(),
      '/avisos': (context) => const AvisosScreen(),
      '/fale-sindico': (context) => BlockedAccessOverlay(
            isBlocked: state.isUnitBlocked,
            child: const FaleSindicoScreen(),
          ),
      '/fale-conosco-admin': (context) => const FaleConoscoAdminScreen(),
      '/universal-push': (context) => const UniversalPushScreen(),
    };
  }

  static String getInitialRoute(AuthState state) {
    switch (state.status) {
      case AuthStatus.authenticated:
        return '/home';
      case AuthStatus.pendingPinSetup:
        return '/pin-setup';
      case AuthStatus.pendingConsent:
        return '/consent';
      case AuthStatus.needsRegistration:
        return '/self-registration';
      case AuthStatus.pendingApproval:
        return '/waiting-approval';
      case AuthStatus.rejected:
      case AuthStatus.unauthenticated:
        return '/login';
      case AuthStatus.authenticating:
      case AuthStatus.otpSent:
        return '/otp-verification'; // Will be removed later
      case AuthStatus.unknown:
      default:
        return '/login'; 
    }
  }
}
