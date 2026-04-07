import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
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
import 'package:condomeet/features/auth/presentation/screens/minha_unidade_screen.dart';
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
import 'package:condomeet/features/community/presentation/screens/album_fotos_screen.dart';
import 'package:condomeet/features/community/presentation/screens/classificados_screen.dart';
import 'package:condomeet/features/community/presentation/screens/indicacoes_screen.dart';
import 'package:condomeet/features/community/presentation/screens/funcionarios_screen.dart';
import 'package:condomeet/features/community/presentation/screens/area_picker_screen.dart';
import 'package:condomeet/features/community/presentation/screens/portaria_booking_screen.dart';
import 'package:condomeet/features/community/presentation/screens/areas_comuns_admin_screen.dart';
import 'package:condomeet/features/community/presentation/screens/admin_horarios_screen.dart';
import 'package:condomeet/features/community/presentation/screens/manutencoes_screen.dart';
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
import 'package:condomeet/features/assembleia/presentation/screens/assembleia_list_screen.dart';
import 'package:condomeet/features/assembleia/presentation/screens/assembleia_detail_screen.dart';
import 'package:condomeet/features/assembleia/presentation/screens/assembleia_live_screen.dart';
import 'package:condomeet/features/admin/presentation/screens/condominium_structure_screen.dart';
import 'package:condomeet/features/admin/presentation/screens/configure_menu_screen.dart';
import 'package:condomeet/features/security/presentation/screens/fale_sindico_screen.dart';
import 'package:condomeet/features/security/presentation/screens/fale_conosco_admin_screen.dart';
import 'package:condomeet/features/security/presentation/screens/suporte_sistema_screen.dart';
import 'package:condomeet/features/auth/presentation/screens/splash_screen.dart';
import 'package:condomeet/features/admin/presentation/screens/universal_push_screen.dart';
import 'package:condomeet/features/admin/presentation/screens/avisos_admin_screen.dart';
import 'package:condomeet/features/admin/presentation/screens/album_fotos_admin_screen.dart';
import 'package:condomeet/features/portaria/presentation/screens/visita_proprietario_screen.dart';
import 'package:condomeet/features/dinglo/presentation/screens/dinglo_home_screen.dart';
import 'package:condomeet/features/dinglo/presentation/screens/contas_screen.dart';
import 'package:condomeet/features/dinglo/presentation/screens/cadastro_conta_screen.dart';
import 'package:condomeet/features/dinglo/presentation/screens/cartoes_screen.dart';
import 'package:condomeet/features/dinglo/presentation/screens/lancamento_screen.dart';
import 'package:condomeet/features/dinglo/presentation/screens/movimentos_screen.dart';
import 'package:condomeet/features/dinglo/presentation/screens/categorias_screen.dart';
import 'package:condomeet/features/dinglo/presentation/screens/metas_screen.dart';
import 'package:condomeet/features/dinglo/presentation/screens/despesas_fixas_screen.dart';
import 'package:condomeet/features/dinglo/presentation/screens/indicadores_screen.dart';
import 'package:condomeet/features/dinglo/presentation/screens/planos_screen.dart';
import 'package:condomeet/features/dinglo/presentation/screens/meu_bolso_onboarding_screen.dart';
import 'package:condomeet/features/lista_mercado/presentation/screens/lista_mercado_home_screen.dart';
import 'package:condomeet/features/lista_mercado/presentation/screens/lista_edit_screen.dart';
import 'package:condomeet/features/lista_mercado/presentation/screens/lista_compare_screen.dart';
import 'package:condomeet/features/lista_mercado/presentation/screens/reportar_preco_screen.dart';
import 'package:condomeet/features/lista_mercado/presentation/screens/scanner_receipt_screen.dart';
import 'package:condomeet/features/lista_mercado/presentation/screens/gamificacao_screen.dart';
import 'package:condomeet/features/lista_mercado/presentation/screens/alertas_preco_screen.dart';
import 'package:condomeet/features/lista_mercado/presentation/screens/lista_admin_screen.dart';
import 'package:condomeet/features/lista_mercado/presentation/screens/cartao_economia_screen.dart';
import 'package:condomeet/features/lista_mercado/presentation/screens/lista_paywall_screen.dart';
import 'package:condomeet/features/lista_mercado/presentation/screens/lista_onboarding_screen.dart';
import 'package:condomeet/features/lista_mercado/presentation/screens/global_dashboard_screen.dart';
import 'package:condomeet/features/garagem/presentation/screens/garagem_home_screen.dart';
import 'package:condomeet/features/garagem/presentation/screens/garagem_detail_screen.dart';
import 'package:condomeet/features/garagem/presentation/screens/garagem_reservation_screen.dart';
import 'package:condomeet/features/garagem/presentation/screens/garagem_cadastro_screen.dart';
import 'package:condomeet/features/garagem/presentation/screens/garagem_onboarding_screen.dart';
import 'package:condomeet/features/vistoria/presentation/screens/vistoria_home_screen.dart';
import 'package:condomeet/features/vistoria/presentation/screens/vistoria_editor_screen.dart';
import 'package:condomeet/features/vistoria/presentation/screens/vistoria_timeline_screen.dart';
import 'package:condomeet/features/vistoria/presentation/screens/vistoria_onboarding_screen.dart';


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
      '/liberar-visitante-cadastrado': (context) => const VisitorRegistrationScreen(initialTab: 1),
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
      '/minha-unidade': (context) {
        final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
        return MinhaUnidadeScreen(
          userId: args['userId'] as String,
          condominioId: args['condominioId'] as String,
        );
      },
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
      '/reservas-portaria': (context) => const PortariaBookingScreen(),
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
      // Assembleias - Visão do Administrativa
      '/admin-assemblies': (context) => const AssemblyListScreen(),
      // Assembleias — Visão do Morador (novo módulo)
      '/assemblies': (context) => const AssembleiaListScreen(),
      '/assembly-detail': (context) {
        final assemblyId = ModalRoute.of(context)!.settings.arguments as String;
        return AssemblyDetailScreen(assemblyId: assemblyId);
      },
      '/assembleias-morador': (context) => const AssembleiaListScreen(),
      '/assembleia-detalhe-morador': (context) {
        final assembleiaId = ModalRoute.of(context)!.settings.arguments as String;
        return AssembleiaDetalheScreen(assembleiaId: assembleiaId);
      },
      '/assembleia-live': (context) {
        final assembleiaId = ModalRoute.of(context)!.settings.arguments as String;
        return AssembleiaLiveScreen(assembleiaId: assembleiaId);
      },
      '/home': (context) => const HomeScreen(),
      '/admin': (context) => const AdminScreen(),
      '/condo-structure': (context) => const CondominiumStructureScreen(),
      '/portaria-visitor-approval': (context) => const VisitorRegistrationScreen(initialTab: 1),
      '/autorizar-visitante-portaria': (context) => const PortariaVisitorAuthorizationFormScreen(),
      '/configure-menu': (context) => const ConfigureMenuScreen(),
      '/sos': (context) => const SosScreen(),
      '/sos-contatos': (context) => const SosContatosScreen(),
      '/avisos': (context) => const AvisosScreen(),
      '/album-fotos': (context) => const AlbumFotosScreen(),
      '/classificados': (context) => const ClassificadosScreen(),
      '/funcionarios': (context) => const FuncionariosScreen(),
      '/admin-classificados': (context) => const ClassificadosScreen(adminMode: true),
      '/manutencao': (context) => const ManutencoesScreen(),
      '/indicacoes': (context) => const IndicacoesScreen(),
      '/fale-sindico': (context) => BlockedAccessOverlay(
            isBlocked: state.isUnitBlocked,
            child: const FaleSindicoScreen(),
          ),
      '/fale-conosco-admin': (context) => const FaleConoscoAdminScreen(),
      '/suporte-sistema': (context) => const SuporteSistemaScreen(),
      '/admin-avisos': (context) => const AvisosAdminScreen(),
      '/admin-album-fotos': (context) => const AlbumFotosAdminScreen(),
      '/universal-push': (context) => const UniversalPushScreen(),
      '/visita-proprietario': (context) => const VisitaProprietarioScreen(),
      // Dinglo Financial Module
      '/dinglo': (context) => const DingloHomeScreen(),
      '/dinglo/contas': (context) => const ContasScreen(),
      '/dinglo/cadastro-conta': (context) => const CadastroContaScreen(),
      '/dinglo/cartoes': (context) => const CartoesScreen(),
      '/dinglo/lancamento': (context) => const LancamentoScreen(),
      '/dinglo/movimentos': (context) => const MovimentosScreen(),
      '/dinglo/categorias': (context) => const CategoriasScreen(),
      '/dinglo/metas': (context) => const MetasScreen(),
      '/dinglo/despesas-fixas': (context) => const DespesasFixasScreen(),
      '/dinglo/indicadores': (context) => const IndicadoresScreen(),
      '/dinglo/planos': (context) => const PlanosScreen(),
      '/dinglo/onboarding': (context) => const MeuBolsoOnboardingScreen(),
      // Lista Inteligente de Supermercado
      '/lista-mercado': (context) => const ListaMercadoHomeScreen(),
      '/lista-mercado/edit': (context) {
        final listId = ModalRoute.of(context)!.settings.arguments as String;
        return ListaEditScreen(listId: listId);
      },
      '/lista-mercado/compare': (context) {
        final listId = ModalRoute.of(context)!.settings.arguments as String;
        return ListaCompareScreen(listId: listId);
      },
      '/lista-mercado/reportar': (context) => const ReportarPrecoScreen(),
      '/lista-mercado/scanner': (context) => const ScannerReceiptScreen(),
      '/lista-mercado/ranking': (context) => const GamificacaoScreen(),
      '/lista-mercado/alertas': (context) => const AlertasPrecoScreen(),
      '/lista-mercado/admin': (context) => const ListaAdminScreen(),
      '/lista-mercado/cartao': (context) => const CartaoEconomiaScreen(),
      '/lista-mercado/paywall': (context) => const ListaPaywallScreen(),
      '/lista-mercado/onboarding': (context) => const ListaOnboardingScreen(),
      '/lista-mercado/global-dashboard': (context) => const GlobalDashboardScreen(),
      // Garagem (Aluguel de Vaga)
      '/garagem': (context) => const GaragemHomeScreen(),
      '/garagem/onboarding': (context) => const GaragemOnboardingScreen(),
      '/garagem-detalhe': (context) {
        final vagaId = ModalRoute.of(context)!.settings.arguments as String;
        return GaragemDetailScreen(vagaId: vagaId);
      },
      '/garagem-reservar': (context) {
        final vaga = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
        return GaragemReservationScreen(vaga: vaga);
      },
      '/garagem-cadastro': (context) {
        final editId = ModalRoute.of(context)?.settings.arguments as String?;
        return GaragemCadastroScreen(editVagaId: editId);
      },
      // Vistoria Digital
      '/vistorias': (context) => const VistoriaHomeScreen(),
      '/vistoria/onboarding': (context) => const VistoriaOnboardingScreen(),
      '/vistoria-editor': (context) {
        final vistoriaId = ModalRoute.of(context)!.settings.arguments as String;
        return VistoriaEditorScreen(vistoriaId: vistoriaId);
      },
      '/vistoria-timeline': (context) {
        final endereco = ModalRoute.of(context)!.settings.arguments as String;
        return VistoriaTimelineScreen(endereco: endereco);
      },
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
