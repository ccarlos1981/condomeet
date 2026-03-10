import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_state.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_event.dart';
import 'package:condomeet/shared/models/condominium.dart';
import 'package:condomeet/shared/repositories/condominium_repository.dart';
import 'package:condomeet/features/parcels/presentation/bloc/parcel_bloc.dart';
import 'package:condomeet/features/parcels/presentation/bloc/parcel_event.dart';
import 'package:condomeet/features/parcels/presentation/bloc/parcel_state.dart';
import 'package:condomeet/features/security/presentation/bloc/sos_bloc.dart';
import 'package:condomeet/features/security/presentation/bloc/sos_event.dart';
import 'package:condomeet/main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Stream<Condominium?>? _condominiumStream;
  String? _currentCondoId;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    _initStream(authState.condominiumId);

    // Trigger parcel matching if we have a user
    if (authState.userId != null) {
      context.read<ParcelBloc>().add(
        WatchPendingParcelsRequested(authState.userId!),
      );
    }
  }

  void _initStream(String? condoId) {
    if (condoId == null) {
      _condominiumStream = null;
    } else if (_currentCondoId != condoId) {
      _currentCondoId = condoId;
      _condominiumStream = GetIt.I<CondominiumRepository>()
          .watchCondominiumById(condoId);
    }
  }

  // ── SOS dialog — shown directly when SOS tab is tapped ────────────────
  void _showSosDialog(BuildContext context) {
    HapticFeedback.heavyImpact();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.red.shade100, width: 2),
                  ),
                  child: Icon(Icons.emergency_share_rounded,
                      color: Colors.red.shade600, size: 36),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Tem certeza que\nprecisa de ajuda?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Avisaremos ao Síndico(a) e Subsíndico(a)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          _triggerSOS(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text(
                          'QUERO AJUDA',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey.shade400),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'NÃO QUERO',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _triggerSOS(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final condoId = authState.condominiumId;
    final userId = authState.userId;

    if (condoId == null || userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Erro: não foi possível identificar o condomínio.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.heavyImpact();
    context.read<SOSBloc>().add(
      TriggerSOSRequested(
        residentId: userId,
        condominiumId: condoId,
        latitude: 0.0,
        longitude: 0.0,
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🚨 Alerta SOS enviado! Aguarde o retorno do síndico.'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AuthBloc, AuthState>(
          listenWhen: (prev, curr) =>
              prev.condominiumId != curr.condominiumId ||
              prev.userId != curr.userId,
          listener: (context, state) {
            setState(() => _initStream(state.condominiumId));
            if (state.userId != null) {
              context.read<ParcelBloc>().add(
                WatchPendingParcelsRequested(state.userId!),
              );
            }
          },
        ),
      ],
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: const Color(0xFFF5F5F5),
            endDrawer: _buildDrawer(context, authState),
            body: SafeArea(
              child: StreamBuilder<Condominium?>(
                stream: _condominiumStream,
                builder: (context, snapshot) {
                  final condominium =
                      snapshot.data ??
                      Condominium(
                        id: authState.condominiumId ?? 'default',
                        name: 'Condomeet',
                        slug: 'default',
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      );
                  final menuItems = condominium.getMenuForRole(
                    authState.role ?? 'resident',
                  );


                  return Column(
                    children: [
                      _buildHeader(authState),
                      Expanded(
                        child: SingleChildScrollView(
                          dragStartBehavior: DragStartBehavior.down,
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            children: [
                              _buildSelfieBanner(),
                              if (menuItems.isNotEmpty)
                                _buildMenuSection(context, menuItems),
                              _buildParcelCard(),
                              _buildPartnersSection(),
                              _buildFeaturedSection(),
                              const SizedBox(
                                height: 80,
                              ), // Space for bottom nav
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            bottomNavigationBar: _buildBottomNav(context, authState),
          );
        },
      ),
    );
  }

  Widget _buildSelfieBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFDEDE),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Vamos tirar uma Selfie? ',
            style: TextStyle(color: Color(0xFF333333), fontSize: 13),
          ),
          const Text(
            'Clique aqui.',
            style: TextStyle(
              color: Color(0xFF333333),
              fontSize: 13,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AuthState authState) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Logo
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.apartment_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONDOMEET',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'seu condomínio digital',
                  style: TextStyle(fontSize: 10, color: Color(0xFF666666)),
                ),
              ],
            ),
          ),
          // Notification bell
          Stack(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: AppColors.primary,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {},
              ),
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Profile
          GestureDetector(
            onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFB0BEC5), // Light grey
              child: const Icon(Icons.person, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context, List<FeatureMenuItem> items) {
    final displayItems = items.length > 8 ? items.sublist(0, 8) : items;
    // Special logic for the indicator in screenshot: if more than 8, or just show it

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Menu completo',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.normal,
              color: Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              const cols = 4;
              const spacing = 8.0;
              final totalSpacing = spacing * (cols - 1);
              final itemWidth = (constraints.maxWidth - totalSpacing) / cols;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: 20,
                  childAspectRatio: 0.7,
                ),
                itemCount: displayItems.length,
                itemBuilder: (context, index) {
                  return _buildMenuIcon(
                    context,
                    displayItems[index],
                    itemWidth,
                  );
                },
              );
            },
          ),
          const SizedBox(height: 16),
          const Center(
            child: Icon(
              Icons.keyboard_double_arrow_down,
              color: AppColors.primary,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuIcon(
    BuildContext context,
    FeatureMenuItem item,
    double availWidth,
  ) {
    final iconData = _getIconData(item.icon);
    return InkWell(
      onTap: () {
        if (item.route.isNotEmpty) {
          Navigator.of(context).pushNamed(item.route);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
            ),
            child: AspectRatio(
              aspectRatio: 1.0,
              child: Center(
                child: Icon(iconData, color: AppColors.primary, size: 36),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF666666),
              height: 1.2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParcelCard() {
    return BlocBuilder<ParcelBloc, ParcelState>(
      builder: (context, state) {
        int pendingCount = 0;
        if (state is ParcelLoaded) {
          pendingCount = state.pendingParcels.length;
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Text(
                      pendingCount > 0 ? '📦' : '😊',
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pendingCount > 0
                            ? 'Você tem $pendingCount ${pendingCount == 1 ? "encomenda pendente" : "encomendas pendentes"}'
                            : 'Você não tem encomenda pendente :)',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (pendingCount > 0)
                      TextButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/parcel-dashboard'),
                        child: const Text(
                          'Ver tudo',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: pendingCount > 0
                            ? Colors.green
                            : AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        pendingCount > 0
                            ? Icons.local_shipping
                            : Icons.inventory_2,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pendingCount > 0
                                ? 'Encomenda pronta para retirada'
                                : 'Nos últimos 7 Dias',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            pendingCount > 0
                                ? 'Passe na portaria para retirar.'
                                : 'Nenhuma foi registrada nos últimos dias.\nAvisaremos no seu WhatsApp quando chegar.',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF666666),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDrawer(BuildContext context, AuthState authState) {
    final bool isAdmin =
        authState.role == 'admin' ||
        authState.role == 'syndic' ||
        authState.role == 'Síndico';

    return Drawer(
      backgroundColor: AppColors.primary,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authState.userName ?? 'Usuário',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (authState.unitId != null &&
                            authState.unitId!.isNotEmpty &&
                            authState.unitId != '0 / 0' &&
                            !authState.unitId!.contains(' 0,') &&
                            !authState.unitId!.endsWith(' 0'))
                          Text(
                            'Unid. ${authState.unitId}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          )
                        else
                          Text(
                            isAdmin ? 'Administrador' : 'Morador',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isAdmin)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'ADMIN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(color: Colors.white, height: 1),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _drawerItem(Icons.edit_note, 'Editar meu perfil'),
                  _drawerItem(Icons.home_outlined, 'Minha unidade'),
                  _drawerItem(
                    Icons.emergency_outlined,
                    'SOS - Cadastrar celulares SOS',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/sos-contatos');
                    },
                  ),
                  _drawerItem(Icons.chat_outlined, 'Outras notificações...'),
                  _drawerItem(Icons.cancel_outlined, 'Inativar conta'),
                  _drawerItem(Icons.help_outline, 'Suporte WhatsApp'),
                  _drawerItem(
                    Icons.privacy_tip_outlined,
                    'Política de privacidade',
                  ),
                  _drawerItem(
                    Icons.chevron_left,
                    'Sair',
                    onTap: () {
                      context.read<AuthBloc>().add(AuthLogoutRequested());
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const AuthRootGate(),
                        ),
                        (route) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
            if (isAdmin)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/admin');
                  },
                  icon: const Icon(
                    Icons.admin_panel_settings_outlined,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Página do Administrador',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    minimumSize: const Size(double.infinity, 50),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.white, size: 20),
      title: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      onTap: onTap ?? () {},
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildPartnersSection() {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Empresas parceiras',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildPartnerItem(
                  const Color(0xFF003D4C),
                  Icons.attach_money_rounded,
                ),
                _buildPartnerItem(AppColors.primary, Icons.stars_rounded),
                _buildPartnerItem(AppColors.primary, Icons.stars_rounded),
                _buildPartnerItem(AppColors.primary, Icons.stars_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerItem(Color color, IconData icon) {
    return Container(
      width: 70,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 30),
            const Text(
              'sua marca aqui',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedSection() {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Em destaque',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFeaturedCard(
                  'Indicação Síndico',
                  'Indicações de serviços feitas pelos Síndicos.',
                  Colors.orange.shade800,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFeaturedCard(
                  'Classificados',
                  'Itens à venda no condomínio.',
                  Colors.red.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedCard(String title, String subtitle, Color color) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white, fontSize: 10),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context, AuthState authState) {
    final tabs = [
      {'icon': Icons.home_outlined, 'label': 'início'},
      {'icon': Icons.emergency_share_outlined, 'label': 'SOS'},
      {'icon': Icons.campaign_outlined, 'label': 'Notificação'},
      {'icon': Icons.person_outline_rounded, 'label': 'Perfil'},
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF616161), // Grey bottom nav as in screenshot
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: List.generate(tabs.length, (index) {
            final isSelected = _selectedTab == index;
            final item = tabs[index];
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  if (index == 1) {
                    // SOS tab — mostrar dialog diretamente
                    _showSosDialog(context);
                  } else if (index == 2) {
                    // Notificação tab — avisos do condomínio
                    Navigator.of(context).pushNamed('/avisos');
                  } else if (index == 3) {
                    _scaffoldKey.currentState?.openEndDrawer();
                  } else {
                    setState(() => _selectedTab = index);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item['icon'] as IconData,
                        // SOS tab (index 1) is always red; others use selected state
                        color: index == 1
                            ? Colors.red
                            : (isSelected ? Colors.red : Colors.white),
                        size: 24,
                      ),
                      Text(
                        item['label'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          color: index == 1
                              ? Colors.red
                              : (isSelected ? Colors.red : Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'chat':
        return Icons.chat_bubble_outline_rounded;
      case 'file_copy':
        return Icons.description_outlined;
      case 'calendar_month':
        return Icons.calendar_month_outlined;
      case 'inventory_2':
        return Icons.inventory_2_outlined;
      case 'qr_code':
        return Icons.qr_code_2_rounded;
      case 'check_circle':
        return Icons.how_to_reg_outlined;
      case 'history':
        return Icons.history_rounded;
      case 'add_box':
        return Icons.add_box_outlined;
      case 'local_shipping':
        return Icons.local_shipping_outlined;
      case 'how_to_reg':
        return Icons.how_to_reg_rounded;
      case 'forum':
        return Icons.forum_outlined;
      case 'message':
        return Icons.message_outlined;
      default:
        return Icons.widgets_outlined;
    }
  }
}
