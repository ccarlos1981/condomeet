import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:condomeet/core/services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:condomeet/core/services/security_service.dart';
import 'package:condomeet/core/utils/structure_helper.dart';
import 'package:condomeet/core/errors/result.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/consent_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  final SecurityService _securityService;
  final ConsentRepository _consentRepository;

  AuthBloc({
    required AuthRepository authRepository,
    required SecurityService securityService,
    required ConsentRepository consentRepository,
  })  : _authRepository = authRepository,
        _securityService = securityService,
        _consentRepository = consentRepository,
        super(const AuthState.unknown()) {
    // Usamos o transformador concurrent() para que eventos como AuthCheckRequested (com retries)
    // não bloqueiem a fila de outros eventos, como o AuthLoginSubmitted.
    on<AuthCheckRequested>(_onAuthCheckRequested, transformer: droppable());
    on<AuthLoginSubmitted>(_onAuthLoginSubmitted, transformer: droppable());
    on<AuthResidentRegistrationSubmitted>(_onAuthResidentRegistrationSubmitted, transformer: concurrent());
    on<AuthSindicoRegistrationSubmitted>(_onAuthSindicoRegistrationSubmitted, transformer: concurrent());
    on<AuthPinSetupCompleted>(_onAuthPinSetupCompleted, transformer: concurrent());
    on<AuthLogoutRequested>(_onAuthLogoutRequested, transformer: concurrent());
    on<AuthPinUnlocked>(_onAuthPinUnlocked, transformer: concurrent());
    on<AuthPasswordSetupSubmitted>(_onAuthPasswordSetupSubmitted, transformer: droppable());
    on<AuthDevBypassRequested>(_onAuthDevBypassRequested, transformer: droppable());
  }

  bool _isSessionUnlocked = false;

  Future<void> _onAuthCheckRequested(AuthCheckRequested event, Emitter<AuthState> emit) async {
    var session = _authRepository.currentSession;
    if (session == null) {
      print('🔐 AuthCheckRequested: No session found. Checking saved credentials...');
      // Try auto-login with saved credentials
      final creds = await _securityService.getCredentials();
      if (creds != null) {
        try {
          print('🔑 Auto-login attempt with saved credentials for ${creds['email']}');
          await _authRepository.signInWithEmail(creds['email']!, creds['password']!);
          session = _authRepository.currentSession;
          print('✅ Auto-login successful');
        } catch (e) {
          print('❌ Auto-login failed: $e — clearing saved credentials');
          await _securityService.clearCredentials();
          emit(const AuthState.unauthenticated());
          return;
        }
      }
      if (session == null) {
        emit(const AuthState.unauthenticated());
        return;
      }
    }

    try {
      print('🔐 AuthCheckRequested: Fetching profile for ${session.user.id}...');
      // Retry logic for profile fetching (handles backend transaction delays during registration)
      Map<String, dynamic>? profile;
      for (var i = 0; i < 3; i++) {
        profile = await _authRepository.fetchProfile(session.user.id);
        if (profile != null) break;
        print('⏳ Profile not found yet, retrying in 1s... (${i + 1}/3)');
        await Future.delayed(const Duration(seconds: 1));
      }
      
      if (profile == null) {
        print('❌ Profile NOT FOUND after retries.');
        // No profile found after retries — send to login with explicit error message to break the silent freeze
        emit(const AuthState.unauthenticated(error: 'As informações do seu perfil não foram encontradas após o registro. Contate o suporte.'));
        return;
      }

      print('✅ Profile found: ${profile['nome_completo']} | Status: ${profile['status_aprovacao']}');

      final String profileStatus = profile['status_aprovacao'] as String? ?? 'pendente';
      final String userId = session.user.id;
      final String? userName = profile['nome_completo'];
      final String? condominiumId = profile['condominio_id'];
      final String? role = profile['papel_sistema'];
      
      if (profileStatus == 'pendente' || profileStatus == 'bloqueado') {
        emit(AuthState.pendingApproval(
          userId: userId,
          userName: userName,
          condominiumId: condominiumId,
          role: role,
        ));
        return;
      }

      if (profileStatus == 'rejeitado') {
        emit(AuthState(
          status: AuthStatus.rejected,
          userId: userId,
          profileStatus: 'rejeitado',
        ));
        return;
      }

      // Update FCM token on app start for active users
      _syncFcmToken(session.user.id);
      
      // 1. Consent Check (Story 1.3)
      final consentResult = await _consentRepository.hasConsent(
        userId: session.user.id,
        consentType: 'terms_of_service',
      );
      
      final hasConsent = consentResult is Success<bool> && consentResult.data;
      if (!hasConsent) {
        emit(AuthState.pendingConsent(
          userId: userId,
          userName: userName,
        ));
        return;
      }

      // 2. PIN Check
      final hasPin = await _securityService.getPin() != null;
      
      // Check if there are linked units and if they're blocked
      bool isBlocked = false;
      String? unitDisplay;
      
      try {
        if (profile['unidade_perfil'] != null && (profile['unidade_perfil'] as List).isNotEmpty) {
             final firstLink = (profile['unidade_perfil'] as List).first;
             final units = firstLink['unidades'];
             if (units != null) {
               isBlocked = units['bloqueada'] == true;
               // Map safely to avoid null reference exceptions
               final bloco = (units['blocos'] as Map?)?['nome_ou_numero'] ?? '0';
               final apto = (units['apartamentos'] as Map?)?['numero'] ?? '0';
               final String? tipoEstruturaLocal = (profile['condominios'] as Map<String, dynamic>?)?['tipo_estrutura'] as String? ?? 'predio';
               // Bloco 0 / Apto 0 é a unidade placeholder do Síndico — não exibir
               if (bloco == '0' && apto == '0') {
                 unitDisplay = null;
               } else {
                 unitDisplay = StructureHelper.getFullUnitName(tipoEstruturaLocal, bloco, apto);
               }
             }
        }
      } catch (e) {
        print('Erro ao carregar dados da unidade no AuthBloc: $e');
        unitDisplay = '? / ?';
      }

      final String? tipoEstrutura = (profile['condominios'] as Map<String, dynamic>?)?['tipo_estrutura'] as String? ?? 'predio';

      if (!hasPin) {
        emit(AuthState.pendingPinSetup(
          userId: userId,
          userName: userName,
          condominiumId: condominiumId,
          role: role,
        ));
      } else if (!_isSessionUnlocked) {
        // Enforce PIN Unlock on app start if PIN is set
        emit(AuthState(
          status: AuthStatus.locked,
          userId: session.user.id,
          condominiumId: profile['condominio_id'],
          userName: profile['nome_completo'],
          role: profile['papel_sistema'],
          tipoEstrutura: tipoEstrutura,
          unitId: unitDisplay,
          isUnitBlocked: isBlocked,
          profileStatus: profileStatus,
        ));
      } else {
        emit(AuthState.authenticated(
          userId: session.user.id,
          condominiumId: profile['condominio_id'],
          role: profile['papel_sistema'],
          userName: profile['nome_completo'],
          tipoEstrutura: tipoEstrutura,
          unitId: unitDisplay,
          isUnitBlocked: isBlocked,
          profileStatus: profileStatus,
        ));
      }
    } catch (e) {
      if (e is PostgrestException && e.code == 'PGRST116') {
        // Not found
        emit(const AuthState.needsRegistration());
      } else {
        emit(AuthState.unauthenticated(error: 'Erro ao buscar perfil: ${e.toString()}'));
      }
    }
  }

  Future<void> _onAuthLoginSubmitted(AuthLoginSubmitted event, Emitter<AuthState> emit) async {
    print('🔑 Manual Login submitted for ${event.email}');
    emit(state.copyWith(status: AuthStatus.authenticating));
    try {
      await _authRepository.signInWithEmail(event.email, event.password);
      print('✅ signInWithEmail successful');
      // Save credentials if rememberMe is checked
      if (event.rememberMe) {
        await _securityService.saveCredentials(event.email, event.password);
        print('💾 Credentials saved for auto-login');
      } else {
        await _securityService.clearCredentials();
        print('🗑️ Credentials cleared (rememberMe unchecked)');
      }
      final session = _authRepository.currentSession;
      if (session != null) {
        print('👤 Session found for user ${session.user.id}. Fetching profile...');
        final profile = await _authRepository.fetchProfile(session.user.id);
        
        if (profile == null) {
          print('⚠️ Profile not found in Supabase for user ${session.user.id}');
          emit(const AuthState.needsRegistration());
          return;
        }
        print('✅ Profile fetched: ${profile['nome_completo']}');

        final String profileStatus = profile['status_aprovacao'] as String? ?? 'pendente';
        final String userId = session.user.id;
        final String? userName = profile['nome_completo'];
        final String? condominiumId = profile['condominio_id'];
        final String? role = profile['papel_sistema'];
        
        if (profileStatus == 'pendente' || profileStatus == 'bloqueado') {
          print('🚫 Login bloqueado: $profileStatus → emitindo pendingApproval');
          emit(AuthState.pendingApproval(
            userId: userId,
            userName: userName,
            condominiumId: condominiumId,
            role: role,
          ));
          return;
        }

        if (profileStatus == 'rejeitado') {
          emit(AuthState(
            status: AuthStatus.rejected,
            userId: userId,
            profileStatus: 'rejeitado',
          ));
          return;
        }

        // Check if there are linked units and if they're blocked
        bool isBlocked = false;
        String? unitDisplay;
        
        try {
          if (profile['unidade_perfil'] != null && (profile['unidade_perfil'] as List).isNotEmpty) {
               final firstLink = (profile['unidade_perfil'] as List).first;
               final units = firstLink['unidades'];
               if (units != null) {
                 isBlocked = units['bloqueada'] == true;
                 
                 // Map safely handling potential List-type responses from old-style Supabase queries
                 final blocoData = units['blocos'];
                 final aptoData = units['apartamentos'];
                 
                 final bloco = (blocoData is List && blocoData.isNotEmpty) 
                     ? blocoData[0]['nome_ou_numero'] 
                     : (blocoData is Map ? blocoData['nome_ou_numero'] : '0');
                     
                 final apto = (aptoData is List && aptoData.isNotEmpty) 
                     ? aptoData[0]['numero'] 
                     : (aptoData is Map ? aptoData['numero'] : '0');
                     
                 final String? tipoEstruturaLocal = (profile['condominios'] as Map<String, dynamic>?)?['tipo_estrutura'] as String? ?? 'predio';
                 // Bloco 0 / Apto 0 é a unidade placeholder do Síndico — não exibir
                 if (bloco == '0' && apto == '0') {
                   unitDisplay = null;
                 } else {
                   unitDisplay = StructureHelper.getFullUnitName(tipoEstruturaLocal, bloco, apto);
                 }
               }
          }
        } catch (e) {
          print('Erro ao carregar dados da unidade no Login (AuthBloc): $e');
          unitDisplay = '? / ?';
        }

        final String? tipoEstrutura = (profile['condominios'] as Map<String, dynamic>?)?['tipo_estrutura'] as String? ?? 'predio';

        // 1. Consent Check (LGPD)
        final consentResult = await _consentRepository.hasConsent(
          userId: userId,
          consentType: 'terms_of_service',
        );
        
        final hasConsent = consentResult is Success<bool> && consentResult.data;
        if (!hasConsent) {
          print('⚖️ Consent required for user $userId');
          emit(AuthState.pendingConsent(
            userId: userId,
            userName: userName,
          ));
          return;
        }

        // 2. PIN Check
        final hasPin = await _securityService.getPin() != null;
        print('🔐 User has PIN: $hasPin');

        _syncFcmToken(session.user.id);

        if (!hasPin) {
          emit(AuthState.pendingPinSetup(
            userId: userId,
            userName: userName,
            condominiumId: condominiumId,
            role: role,
          ));
        } else {
          // If already has PIN, go to home (manual login assumes user knows their own device)
          // Or go to Locked if we want to be super secure.
          _isSessionUnlocked = true; // Mark as unlocked since they just put in their full credentials
          emit(AuthState.authenticated(
            userId: userId,
            userName: userName,
            role: role,
            condominiumId: condominiumId,
            tipoEstrutura: tipoEstrutura,
            unitId: unitDisplay,
            isUnitBlocked: isBlocked,
            profileStatus: profileStatus,
          ));
        }
      }
    } catch (e) {
      print('❌ Manual Login ERROR: ${e.toString()}');
      final errorMsg = e.toString();
      if (errorMsg.contains('email_not_confirmed') || errorMsg.contains('Email not confirmed')) {
        emit(const AuthState.unauthenticated(error: 'Seu e-mail ainda não foi confirmado. Verifique sua caixa de entrada.'));
      } else if (errorMsg.contains('Invalid login credentials') || errorMsg.contains('invalid_credentials')) {
        // Verifica se é morador migrado que precisa configurar senha
        try {
          final needsSetup = await Supabase.instance.client
              .rpc('check_needs_password_setup', params: {'user_email': event.email});
          if (needsSetup == true) {
            print('🔑 Email ${event.email} precisa configurar senha');
            emit(AuthState.needsPasswordSetup(email: event.email));
            return;
          }
        } catch (_) {}
        emit(const AuthState.unauthenticated(error: 'E-mail ou senha incorretos.'));
      } else {
        emit(AuthState.unauthenticated(error: 'Erro ao entrar: $errorMsg'));
      }
    }
  }

  Future<void> _onAuthPasswordSetupSubmitted(AuthPasswordSetupSubmitted event, Emitter<AuthState> emit) async {
    print('🔑 Configurando senha para ${event.email}');
    emit(state.copyWith(status: AuthStatus.authenticating));
    try {
      await Supabase.instance.client.rpc(
        'setup_user_password',
        params: {'user_email': event.email, 'new_password': event.newPassword},
      );
      // Login automático com a nova senha
      await _authRepository.signInWithEmail(event.email, event.newPassword);
      add(const AuthCheckRequested());
    } catch (e) {
      print('❌ Erro ao configurar senha: $e');
      emit(AuthState.unauthenticated(error: 'Erro ao definir senha. Tente novamente.'));
    }
  }

  Future<void> _onAuthResidentRegistrationSubmitted(AuthResidentRegistrationSubmitted event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.authenticating));
    try {
      // 1. Create Auth User
      final newUserId = await _authRepository.signUpWithEmail(event.email, event.password);
      
      // 2. Register profile in the database
      await _authRepository.registerResident(
        userId: newUserId,
        email: event.email,
        condominioId: event.condominioId,
        unidadeId: event.unidadeId,
        nomeCompleto: event.nomeCompleto,
        whatsapp: event.whatsapp,
        tipoMorador: event.tipoMorador,
        papelSistema: event.papelSistema,
        consentimentoWhatsapp: event.consentimentoWhatsapp,
        blocoTxt: event.blocoTxt,
        aptoTxt: event.aptoTxt,
      );
      
      // 3. Force Login to hydrate the Supabase Client session before checking auth state
      await _authRepository.signInWithEmail(event.email, event.password);
      
      print('🚀 Resident registered! Waiting 1s before AuthCheck...');
      await Future.delayed(const Duration(seconds: 1));
      
      // Let AuthCheckRequested pull from the newly inserted database row to ensure proper structure.
      add(AuthCheckRequested());
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('already registered') || 
          errorMsg.contains('already exists') || 
          errorMsg.contains('duplicate key')) {
        emit(const AuthState.unauthenticated(error: 'Este e-mail já existe em nosso banco de dados. Tente fazer login.'));
      } else {
        emit(AuthState.unauthenticated(error: 'Houve um problema ao criar seu cadastro: ${e.toString()}'));
      }
    }
  }

  Future<void> _onAuthSindicoRegistrationSubmitted(AuthSindicoRegistrationSubmitted event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.authenticating));
    try {
      // 1. Create Auth User
      final newUserId = await _authRepository.signUpWithEmail(event.email, event.password);
      
      // 2. Register Sindico and Condominium
      await _authRepository.registerSindico(
        userId: newUserId,
        email: event.email,
        condominioData: event.condominioData,
        nomeCompleto: event.nomeCompleto,
        whatsapp: event.whatsapp,
      );
      
      // 3. Force Login to hydrate the Supabase Client session before checking auth state
      await _authRepository.signInWithEmail(event.email, event.password);
      
      print('🚀 Resident registered! Waiting 1s before AuthCheck...');
      await Future.delayed(const Duration(seconds: 1));
      
      // Let AuthCheckRequested pull from the newly inserted database row to ensure proper structure.
      add(AuthCheckRequested());
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('already registered') || 
          errorMsg.contains('already exists') || 
          errorMsg.contains('duplicate key')) {
        emit(const AuthState.unauthenticated(error: 'Este e-mail já existe em nosso banco de dados. Tente fazer login.'));
      } else {
        emit(AuthState.unauthenticated(error: 'Erro no cadastro: $errorMsg'));
      }
    }
  }
  // Remove _fetchProfile

  Future<void> _onAuthPinSetupCompleted(AuthPinSetupCompleted event, Emitter<AuthState> emit) async {
    try {
      await _securityService.savePin(event.pin);
      _isSessionUnlocked = true;
      emit(state.copyWith(status: AuthStatus.authenticated, isUnlocked: true));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Erro ao salvar PIN'));
    }
  }

  void _onAuthPinUnlocked(AuthPinUnlocked event, Emitter<AuthState> emit) {
    _isSessionUnlocked = true;
    emit(state.copyWith(status: AuthStatus.authenticated, isUnlocked: true));
  }

  Future<void> _onAuthLogoutRequested(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    await _securityService.clearCredentials();
    await _authRepository.signOut();
    emit(const AuthState.unauthenticated());
  }

  /// Dev-only: bypasses OTP by logging in with a test account.
  /// Guarded by kDebugMode — no-op in release builds.
  Future<void> _onAuthDevBypassRequested(AuthDevBypassRequested event, Emitter<AuthState> emit) async {
    const isDebug = bool.fromEnvironment('dart.vm.product') == false;
    if (!isDebug) return;

    print('🛠️ DEV BYPASS: Attempting login with test account...');
    emit(state.copyWith(status: AuthStatus.authenticating));

    try {
      // Try to sign in with the test account
      add(const AuthLoginSubmitted(
        email: 'dev@condomeet.app',
        password: 'dev123456',
      ));
    } catch (e) {
      print('❌ DEV BYPASS failed: $e');
      emit(state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Dev bypass failed: $e',
      ));
    }
  }


  Future<void> _syncFcmToken(String userId) async {
    try {
      final notificationService = GetIt.instance<NotificationService>();
      final token = await notificationService.getToken();
      if (token != null) {
        await _authRepository.updateFcmToken(userId, token);
        print('✅ FCM Token synced for user $userId');
      }
    } catch (e) {
      print('❌ Failed to sync FCM token: $e');
    }
  }
}
