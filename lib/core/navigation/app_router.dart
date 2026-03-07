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
import 'package:condomeet/features/portaria/domain/repositories/resident_repository.dart';
import 'package:condomeet/features/access/presentation/screens/invitation_generator_screen.dart';
import 'package:condomeet/features/access/presentation/screens/guest_checkin_screen.dart';
import 'package:condomeet/features/community/presentation/screens/document_center_screen.dart';
import 'package:condomeet/features/community/presentation/screens/area_picker_screen.dart';
import 'package:condomeet/features/security/presentation/screens/chat_screen.dart';
import 'package:condomeet/features/security/presentation/screens/occurrence_report_screen.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_state.dart';
import 'package:condomeet/features/dev/presentation/screens/design_system_showcase.dart';
import 'package:condomeet/features/home/presentation/screens/home_screen.dart';
import 'package:condomeet/features/home/presentation/screens/admin_screen.dart';
import 'package:condomeet/features/admin/presentation/screens/inventory_list_screen.dart';
import 'package:condomeet/features/admin/presentation/screens/inventory_detail_screen.dart';
import 'package:condomeet/features/admin/presentation/screens/assembly_list_screen.dart';
import 'package:condomeet/features/admin/presentation/screens/assembly_detail_screen.dart';
import 'package:condomeet/features/admin/presentation/screens/condominium_structure_screen.dart';


class AppRouter {
  static Map<String, WidgetBuilder> getRoutes(AuthState state) {
    return {
      '/design-system': (context) => const DesignSystemShowcase(),
      '/login': (context) => const LoginScreen(),
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
        return ParcelDashboardScreen(residentId: state.userId ?? '');
      },
      '/pending-deliveries': (context) => const PendingDeliveriesScreen(),
      '/parcel-history': (context) {
        final residentId = (ModalRoute.of(context)!.settings.arguments as String?) ?? state.userId;
        return ParcelHistoryScreen(residentId: residentId);
      },
      '/invitation-generator': (context) {
        return BlockedAccessOverlay(
          isBlocked: state.isUnitBlocked,
          child: InvitationGeneratorScreen(residentId: state.userId ?? ''),
        );
      },
      '/guest-checkin': (context) => const GuestCheckinScreen(),
      '/self-registration': (context) => const SelfRegistrationScreen(),
      '/sindico-registration': (context) => const SindicoRegistrationScreen(),
      '/waiting-approval': (context) => const WaitingApprovalScreen(),
      '/manager-approval': (context) => const ManagerApprovalScreen(),
      '/report-occurrence': (context) => BlockedAccessOverlay(
            isBlocked: state.isUnitBlocked,
            child: OccurrenceReportScreen(residentId: state.userId ?? ''),
          ),
      '/official-chat': (context) => BlockedAccessOverlay(
            isBlocked: state.isUnitBlocked,
            child: ChatScreen(residentId: state.userId ?? ''),
          ),
      '/area-booking': (context) => BlockedAccessOverlay(
            isBlocked: state.isUnitBlocked,
            child: const AreaPickerScreen(),
          ),
      '/document-center': (context) => BlockedAccessOverlay(
            isBlocked: state.isUnitBlocked,
            child: const DocumentCenterScreen(),
          ),
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
