import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/core/design_system/theme.dart';
import 'package:condomeet/features/security/presentation/widgets/panic_overlay.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_event.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_state.dart';
import 'package:condomeet/features/auth/presentation/screens/pin_setup_screen.dart';
import 'package:condomeet/features/auth/presentation/screens/pin_unlock_screen.dart';
import 'package:condomeet/features/auth/presentation/screens/login_screen.dart';
import 'package:condomeet/features/auth/presentation/screens/self_registration_screen.dart';
import 'package:condomeet/features/auth/presentation/screens/waiting_approval_screen.dart';
import 'package:condomeet/features/auth/presentation/screens/consent_screen.dart';
import 'package:condomeet/features/home/presentation/screens/home_screen.dart';
import 'package:condomeet/core/navigation/app_router.dart';
import 'package:condomeet/core/di/injection_container.dart';
import 'package:condomeet/core/services/powersync_service.dart';
import 'package:condomeet/core/services/security_service.dart';
import 'package:condomeet/core/errors/global_error_handler.dart';
import 'package:condomeet/core/design_system/widgets/condo_error_screen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:condomeet/core/services/notification_service.dart';
import 'package:condomeet/features/parcels/presentation/bloc/parcel_bloc.dart';
import 'package:condomeet/features/access/presentation/bloc/invitation_bloc.dart';
import 'package:condomeet/firebase_options.dart';

import 'package:condomeet/features/security/presentation/bloc/sos_bloc.dart';
import 'package:condomeet/features/security/presentation/bloc/sos_state.dart';
import 'package:condomeet/features/security/presentation/bloc/sos_event.dart';
import 'package:condomeet/features/security/presentation/bloc/occurrence_bloc.dart';
import 'package:condomeet/features/security/presentation/bloc/chat_bloc.dart';

// Community imports
import 'package:condomeet/features/community/presentation/bloc/booking_bloc.dart';
import 'package:condomeet/features/community/presentation/bloc/document_bloc.dart';
import 'package:condomeet/features/admin/presentation/bloc/inventory_bloc.dart';
import 'package:condomeet/features/admin/presentation/bloc/assembly_bloc.dart';
import 'package:condomeet/features/admin/presentation/bloc/structure_bloc.dart';

import 'package:condomeet/core/config/app_config.dart';

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase (Required for Push)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
    // We continue since core app logic doesn't strictly depend on Firebase initialization on desktop/dev
  }

  // Initialize Supabase
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  // Initialize Dependency Injection Container
  await initDependencies();

  // Initialize Notifications (Non-blocking)
  sl<NotificationService>().initialize(); 

  // Initialize Global Error Handler
  GlobalErrorHandler.initialize();
  ErrorWidget.builder = (details) => CondoErrorScreen(details: details);

  // KILLER SCRIPT: Clear PowerSync local queue for user_consents to stop RLS error flood
  /* 
  try {
    final ps = sl<PowerSyncService>();
    // Wait a brief moment for DB to be fully ready
    Future.delayed(const Duration(seconds: 1), () async {
      try {
        await ps.db.execute('DELETE FROM user_consents');
        debugPrint('PowerSync: Emergency cleanup of user_consents completed.');
      } catch (e) {
        debugPrint('PowerSync: Emergency cleanup failed: $e');
      }
    });
  } catch (e) {
    debugPrint('PowerSync: Emergency cleanup injector failed: $e');
  }
  */

  runApp(const CondomeetApp());
}

class CondomeetApp extends StatelessWidget {
  const CondomeetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: sl<PowerSyncService>()),
        RepositoryProvider.value(value: sl<SecurityService>()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(
            value: sl<AuthBloc>()..add(AuthCheckRequested()),
          ),
          BlocProvider(
            create: (context) => ParcelBloc(sl()),
          ),
          BlocProvider(
            create: (context) => sl<InvitationBloc>(),
          ),
          BlocProvider(
            create: (context) => sl<SOSBloc>(),
          ),
          BlocProvider(
            create: (context) => sl<OccurrenceBloc>(),
          ),
          BlocProvider(
            create: (context) => sl<ChatBloc>(),
          ),
          BlocProvider(
            create: (context) => sl<BookingBloc>(),
          ),
          BlocProvider(
            create: (context) => sl<DocumentBloc>(),
          ),
          BlocProvider(
            create: (context) => sl<InventoryBloc>(),
          ),
          BlocProvider(
            create: (context) => sl<AssemblyBloc>(),
          ),
          BlocProvider(
            create: (context) => sl<StructureBloc>(),
          ),
        ],
        child: MaterialApp(
          title: 'Condomeet',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light.copyWith(
            platform: TargetPlatform.iOS,
          ),
          darkTheme: AppTheme.dark.copyWith(
            platform: TargetPlatform.iOS,
          ),
          themeMode: ThemeMode.light,
          scrollBehavior: AppScrollBehavior(),
          routes: AppRouter.getRoutes(sl<AuthBloc>().state),
          home: const AuthRootGate(),
        ),
      ),
    );
  }
}

class AuthRootGate extends StatelessWidget {
  const AuthRootGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (previous, current) => previous.status != current.status || previous.isUnitBlocked != current.isUnitBlocked,
      listener: (context, state) {
        debugPrint('🔄 AuthRootGate: Status = ${state.status} | Profile = ${state.profileStatus}');
      },
      builder: (context, state) {
        switch (state.status) {
          case AuthStatus.authenticated:
            return const HomeScreen();
          case AuthStatus.locked:
            return const PinUnlockScreen();
          case AuthStatus.pendingPinSetup:
            return const PinSetupScreen();
          case AuthStatus.pendingConsent:
            return const ConsentScreen();
          case AuthStatus.needsRegistration:
            return const SelfRegistrationScreen();
          case AuthStatus.pendingApproval:
            return const WaitingApprovalScreen();
          case AuthStatus.rejected:
          case AuthStatus.authenticating:
          case AuthStatus.unauthenticated:
            return const LoginScreen();
          case AuthStatus.otpSent:
            // Obsolete for Schema 2.0 unless we keep phone fallback
            return const LoginScreen();
          case AuthStatus.unknown:
          default:
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
      },
    );
  }
}
