import 'dart:ui';
import 'package:condomeet/features/dinglo/revenuecat_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/core/design_system/theme.dart';
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
import 'package:condomeet/features/auth/presentation/screens/splash_screen.dart';
import 'package:condomeet/core/navigation/app_router.dart';
import 'package:condomeet/core/di/injection_container.dart';
import 'package:condomeet/core/services/powersync_service.dart';
import 'package:condomeet/core/services/security_service.dart';
import 'package:condomeet/core/errors/global_error_handler.dart';
import 'package:condomeet/core/services/version_check_service.dart';
import 'package:condomeet/core/design_system/widgets/force_update_screen.dart';
import 'package:condomeet/core/design_system/widgets/condo_error_screen.dart';
import 'dart:async';
import 'package:condomeet/core/services/live_activity_service.dart';
import 'package:condomeet/core/design_system/widgets/connectivity_banner.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:condomeet/core/services/notification_service.dart';
import 'package:condomeet/features/parcels/presentation/bloc/parcel_bloc.dart';
import 'package:condomeet/features/access/presentation/bloc/invitation_bloc.dart';
import 'package:condomeet/features/access/presentation/bloc/invitation_event.dart';
import 'package:condomeet/features/access/presentation/bloc/invitation_state.dart';
import 'package:condomeet/firebase_options.dart';

import 'package:condomeet/features/security/presentation/bloc/sos_bloc.dart';
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

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Travar em modo retrato (vertical) apenas
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
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

  // Initialize RevenueCat (In-App Purchases)
  try {
    await RevenueCatService.initialize();
    RevenueCatService.listenForChanges();
  } catch (e) {
    debugPrint('RevenueCat initialization failed: $e');
  }

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
          navigatorKey: AppRouter.navigatorKey,
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
          builder: (context, child) => ConnectivityBanner(child: child ?? const SizedBox()),
          home: const AuthRootGate(),
        ),
      ),
    );
  }
}

class AuthRootGate extends StatefulWidget {
  const AuthRootGate({super.key});

  @override
  State<AuthRootGate> createState() => _AuthRootGateState();
}

class _AuthRootGateState extends State<AuthRootGate> with WidgetsBindingObserver {
  VersionGateResult? _gateResult;
  StreamSubscription<String>? _deepLinkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LiveActivityService.initializeDeepLinking();
    _deepLinkSubscription = LiveActivityService.deepLinkStream.listen(_handleDeepLinkNavigation);
    _checkVersion();
  }

  @override
  void dispose() {
    _deepLinkSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _handleDeepLinkNavigation(String target) async {
    if (!mounted) return;
    final authState = context.read<AuthBloc>().state;
    if (authState.status == AuthStatus.authenticated && _gateResult != null && !_gateResult!.isBlocked) {
      LiveActivityService.clearPendingInvitationId();

      // Deep link agregado: navega diretamente para a lista de autorizações do morador
      if (target == 'list' || target == '__list__' || target.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          AppRouter.navigatorKey.currentState?.pushNamed('/invitation-generator');
        });
        return;
      }

      // Deep link individual: Guardrail de ownership pré-navegação
      // Deep Link -> autenticação -> validação do invitationId -> resident_id = usuário autenticado -> condomínio do usuário -> consulta protegida por RLS -> somente depois navegação/renderização
      final userId = authState.userId;
      final condoId = authState.condominiumId;
      if (userId == null) {
        debugPrint('⚠️ [AuthRootGate] Deep link retido: usuário não identificado.');
        return;
      }

      bool isValidOwner = false;

      // 1. Checar coleção em memória no BLoC (já autenticado e filtrado)
      try {
        final bloc = context.read<InvitationBloc>();
        final found = bloc.cachedResidentInvitations.any((inv) => inv.id == target && inv.residentId == userId);
        if (found) {
          isValidOwner = true;
        } else if (bloc.state is InvitationLoaded) {
          final foundInState = (bloc.state as InvitationLoaded).invitations.any((inv) => inv.id == target && inv.residentId == userId);
          if (foundInState) isValidOwner = true;
        }
      } catch (e) {
        debugPrint('⚠️ [AuthRootGate] Erro ao checar BLoC para ownership do deep link: $e');
      }

      // 2. Se não estiver em memória, consulta no Supabase protegida por RLS
      if (!isValidOwner) {
        try {
          final response = await Supabase.instance.client
              .from('convites')
              .select('id')
              .eq('id', target)
              .eq('resident_id', userId)
              .eq('condominio_id', condoId ?? '')
              .maybeSingle();

          if (response != null && response['id'] == target) {
            isValidOwner = true;
          }
        } catch (e) {
          debugPrint('⚠️ [AuthRootGate] Erro na consulta RLS de ownership do deep link: $e');
        }
      }

      // Se a autorização não pertencer ao usuário:
      // - não exibir dados;
      // - não exibir código;
      // - não abrir credencial;
      // - informar "Autorização não encontrada ou indisponível".
      if (!isValidOwner) {
        debugPrint('⛔ [AuthRootGate] Deep link bloqueado por ownership/RLS: $target');
        final scaffoldContext = AppRouter.navigatorKey.currentContext;
        if (scaffoldContext != null && scaffoldContext.mounted) {
          ScaffoldMessenger.of(scaffoldContext).showSnackBar(
            const SnackBar(
              content: Text('Autorização não encontrada ou indisponível.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      // Validação de ownership concluída com sucesso: somente agora navega e renderiza
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppRouter.navigatorKey.currentState?.pushNamed(
          '/invitation-generator',
          arguments: {'highlightInvitationId': target},
        );
      });
    } else {
      debugPrint('⏳ [AuthRootGate] Deep link retido aguardando autenticação completa: $target');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Ao voltar da loja para o app, reavalia a versão instalada.
    // Só desbloqueia se a nova versão efetivamente atender à política.
    if (state == AppLifecycleState.resumed) {
      if (_gateResult?.isBlocked == true) {
        debugPrint('🔄 [AuthRootGate] App retornou ao primeiro plano com bloqueio ativo: reavaliando versão instalada...');
        _checkVersion();
      }
      _reconcileLiveActivityOnForeground();
    }
  }

  void _reconcileLiveActivityOnForeground() {
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState.status == AuthStatus.authenticated && authState.userId != null) {
        if (authState.userName != null) {
          LiveActivityService.cacheNames(moradorNome: authState.userName);
        }
        final bloc = context.read<InvitationBloc>();
        final cached = bloc.cachedResidentInvitations;
        if (cached.isNotEmpty) {
          final openList = cached.where(LiveActivityService.isInvitationOpen).toList();
          LiveActivityService.syncActiveInvitationsState(
            openInvitations: openList,
            moradorNome: authState.userName ?? (LiveActivityService.cachedMoradorNome ?? 'Morador'),
            condominioNome: LiveActivityService.cachedCondominioNome ?? 'Condomínio',
          );
        } else {
          bloc.add(LoadResidentInvitationsPaginated(residentId: authState.userId!, isRefresh: true));
        }
      }
    } catch (e) {
      debugPrint('⚠️ [AuthRootGate] Falha ao reconciliar Live Activity no foreground: $e');
    }
  }

  Future<void> _checkVersion() async {
    try {
      final result = await sl<VersionCheckService>().checkVersionGate();
      if (mounted) {
        setState(() {
          _gateResult = result;
        });
        final pending = LiveActivityService.pendingInvitationId;
        if (pending != null && pending.isNotEmpty) {
          _handleDeepLinkNavigation(pending);
        }
      }
    } catch (e) {
      debugPrint('⚠️ [AuthRootGate] Erro inesperado ao checar versão (Fail-Open): $e');
      if (mounted) {
        setState(() {
          _gateResult = const VersionGateResult(
            status: VersionGateStatus.allow,
            installedBuild: VersionCheckService.defaultBuildNumber,
            installedVersion: VersionCheckService.defaultAppVersion,
            requiredBuild: VersionCheckService.defaultBuildNumber,
            requiredVersion: VersionCheckService.defaultAppVersion,
            storeUrl: '',
            title: '',
            message: '',
          );
        });
        final pending = LiveActivityService.pendingInvitationId;
        if (pending != null && pending.isNotEmpty) {
          _handleDeepLinkNavigation(pending);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Enquanto a checagem inicial de versão estiver em andamento, exibe SplashScreen
    if (_gateResult == null) {
      return const SplashScreen();
    }

    // 2. Se a versão instalada for menor que a versão mínima, intercepta e bloqueia com popup
    if (_gateResult!.isBlocked) {
      return ForceUpdateScreen(
        gateResult: _gateResult!,
        onRetry: _checkVersion,
      );
    }

    // 3. Versão permitida (ou offline/bypass): prossegue para o fluxo de autenticação normal
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          previous.status != current.status || previous.isUnitBlocked != current.isUnitBlocked,
      listener: (context, state) {
        debugPrint('🔄 AuthRootGate: Status = ${state.status} | Profile = ${state.profileStatus}');
        if (state.status == AuthStatus.authenticated) {
          final pending = LiveActivityService.pendingInvitationId;
          if (pending != null && pending.isNotEmpty) {
            _handleDeepLinkNavigation(pending);
          }
        }
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
          case AuthStatus.needsPasswordSetup:
          case AuthStatus.forgotPasswordCodeSent:
            return const LoginScreen();
          case AuthStatus.otpSent:
            // Obsolete for Schema 2.0 unless we keep phone fallback
            return const LoginScreen();
          case AuthStatus.unknown:
            return const SplashScreen();
        }
      },
    );
  }
}
