import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import 'package:condomeet/core/design_system/app_colors.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_state.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_event.dart';
import 'package:condomeet/shared/models/condominium.dart';
import 'package:condomeet/shared/repositories/condominium_repository.dart';
import 'package:condomeet/features/parcels/presentation/bloc/parcel_bloc.dart';
import 'package:condomeet/features/parcels/presentation/bloc/parcel_event.dart';
import 'package:condomeet/features/parcels/presentation/bloc/parcel_state.dart';
import 'package:condomeet/features/portaria/domain/entities/parcel.dart';
import 'package:condomeet/features/security/presentation/bloc/sos_bloc.dart';
import 'package:condomeet/features/security/presentation/bloc/sos_event.dart';
import 'package:condomeet/features/auth/presentation/screens/edit_profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
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
  String? _fotoUrl;
  bool _uploadingSelfie = false;

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    _initStream(authState.condominiumId);
    _loadFotoUrl(authState.userId);

    if (authState.userId != null) {
      context.read<ParcelBloc>().add(
        WatchPendingParcelsRequested(authState.userId!),
      );
    }
  }

  Future<void> _loadFotoUrl(String? userId) async {
    if (userId == null) return;
    try {
      final data = await Supabase.instance.client
          .from('perfil')
          .select('foto_url')
          .eq('id', userId)
          .maybeSingle();
      if (mounted && data != null) {
        setState(() => _fotoUrl = data['foto_url'] as String?);
      }
    } catch (_) {}
  }

  Future<void> _captureSelfie() async {
    final authState = context.read<AuthBloc>().state;
    final userId = authState.userId;
    if (userId == null) return;

    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (photo == null || !mounted) return;

    setState(() => _uploadingSelfie = true);
    try {
      final file = File(photo.path);
      final ext = photo.path.split('.').last;
      final path = '$userId/selfie.$ext';

      await Supabase.instance.client.storage
          .from('profile-photos')
          .upload(path, file, fileOptions: const FileOptions(upsert: true));

      final publicUrl = Supabase.instance.client.storage
          .from('profile-photos')
          .getPublicUrl(path);

      // Add cache-buster to force new image
      final urlWithCacheBust = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      await Supabase.instance.client
          .from('perfil')
          .update({'foto_url': publicUrl})
          .eq('id', userId);

      if (mounted) {
        setState(() {
          _fotoUrl = urlWithCacheBust;
          _uploadingSelfie = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📸 Selfie salva com sucesso!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingSelfie = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar selfie: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
                    color: AppColors.textMain,
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
    // Don't show banner if user already has a photo
    if (_fotoUrl != null && _fotoUrl!.isNotEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: _uploadingSelfie ? null : _captureSelfie,
      child: Container(
        width: double.infinity,
        color: const Color(0xFFFFDEDE),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.only(top: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_uploadingSelfie) ...[
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
              const SizedBox(width: 12),
              const Text('Salvando selfie...', style: TextStyle(color: AppColors.textMain, fontSize: 13)),
            ] else ...[
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.camera_alt, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              const Text(
                'Vamos tirar uma Selfie? ',
                style: TextStyle(color: AppColors.textMain, fontSize: 13),
              ),
              const Text(
                'Clique aqui.',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ],
        ),
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
          Image.asset(
            'assets/images/logo.png',
            width: 40,
            height: 40,
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
                  style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
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
              backgroundColor: const Color(0xFFB0BEC5),
              backgroundImage: _fotoUrl != null && _fotoUrl!.isNotEmpty
                  ? NetworkImage(_fotoUrl!)
                  : null,
              child: _fotoUrl == null || _fotoUrl!.isEmpty
                  ? const Icon(Icons.person, color: Colors.white, size: 24)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context, List<FeatureMenuItem> items) {
    // 2 linhas fixas, colunas automáticas, scroll horizontal
    // mainAxisExtent = largura de cada coluna (= tamanho do ícone quadrado)
    // crossAxisExtent = altura de cada linha (ícone + espaço + label)
    const double itemMainAxisExtent = 90.0;  // largura (e altura do ícone, por AspectRatio 1:1)
    const double itemCrossAxisExtent = 115.0; // altura total: 64 ícone + 6 espaço + ~28 label
    const double spacing = 10.0;
    // Altura total = 2 linhas + espaço entre elas + padding vertical
    const double sectionHeight = itemCrossAxisExtent * 2 + spacing + 8;

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          SizedBox(
            height: sectionHeight,
            child: GridView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,          // sempre 2 linhas
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                mainAxisExtent: itemMainAxisExtent,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                return _buildMenuIcon(
                  context,
                  items[index],
                  itemMainAxisExtent,
                );
              },
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
            height: 64,
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
            child: Center(
              child: Icon(iconData, color: AppColors.primary, size: 30),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textMain,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParcelCard() {
    return BlocBuilder<ParcelBloc, ParcelState>(
      builder: (context, state) {
        List<Parcel> pendingParcels = [];
        if (state is ParcelLoaded) {
          final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
          pendingParcels = state.pendingParcels
              .where((p) => p.arrivalTime.isAfter(sevenDaysAgo))
              .toList();
        }
        final pendingCount = pendingParcels.length;
        final firstParcel = pendingParcels.isNotEmpty ? pendingParcels.first : null;

        // Format arrival date
        String arrivalLabel = '';
        if (firstParcel != null) {
          final arrival = firstParcel.arrivalTime;
          final now = DateTime.now();
          final diff = now.difference(arrival).inDays;
          final day = arrival.day.toString().padLeft(2, '0');
          final month = arrival.month.toString().padLeft(2, '0');
          final year = arrival.year;
          final dateStr = '$day/$month/$year';
          if (diff == 0) {
            arrivalLabel = 'Chegou hoje ($dateStr)';
          } else if (diff == 1) {
            arrivalLabel = 'Chegou ontem ($dateStr)';
          } else {
            arrivalLabel = 'Chegou há $diff dias ($dateStr)';
          }
        }

        // Tipo label
        String tipoLabel = '';
        if (firstParcel?.tipo != null) {
          switch (firstParcel!.tipo) {
            case 'caixa':       tipoLabel = 'Caixa'; break;
            case 'envelope':    tipoLabel = 'Envelope'; break;
            case 'pacote':      tipoLabel = 'Pacote'; break;
            case 'notif_judicial': tipoLabel = 'Notificação Judicial'; break;
            default:            tipoLabel = firstParcel.tipo!;
          }
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
                      pendingCount > 0 ? '😯' : '😊',
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pendingCount > 0
                            ? 'Você tem $pendingCount ${pendingCount == 1 ? "encomenda pendente" : "encomendas pendentes"} nos últimos 7 dias'
                            : 'Nenhuma encomenda pendente nos últimos 7 dias :)',
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
                            ? Colors.orange.shade600
                            : AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        pendingCount > 0
                            ? Icons.local_shipping_rounded
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
                                ? 'Encomenda aguardando retirada'
                                : 'Nos últimos 7 Dias',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          if (pendingCount > 0) ...[
                            if (arrivalLabel.isNotEmpty)
                              Text(
                                arrivalLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            Text(
                              [
                                if (tipoLabel.isNotEmpty) tipoLabel,
                                if (pendingCount > 1) '+${pendingCount - 1} mais',
                              ].join(' · ').isNotEmpty
                                ? [
                                    if (tipoLabel.isNotEmpty) tipoLabel,
                                    if (pendingCount > 1) '+${pendingCount - 1} mais',
                                  ].join(' · ')
                                : 'Passe na portaria para retirar.',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const Text(
                              'Passe na portaria para retirar.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ] else
                            const Text(
                              'Avisaremos no seu WhatsApp quando chegar.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
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
                  _drawerItem(Icons.edit_note, 'Editar meu perfil', onTap: () async {
                    Navigator.pop(context); // fecha drawer
                    final userId = authState.userId;
                    final condoId = authState.condominiumId;
                    if (userId == null || condoId == null) return;
                    
                    // Busca dados atuais do perfil
                    try {
                      final perfil = await Supabase.instance.client
                          .from('perfil')
                          .select('nome_completo, whatsapp, tipo_morador, bloco_txt, apto_txt')
                          .eq('id', userId)
                          .single();
                      
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditProfileScreen(
                            userId: userId,
                            condominioId: condoId,
                            currentName: perfil['nome_completo'],
                            currentWhatsapp: perfil['whatsapp'],
                            currentTipoMorador: perfil['tipo_morador'],
                            currentBlocoTxt: perfil['bloco_txt'],
                            currentAptoTxt: perfil['apto_txt'],
                          ),
                        ),
                      );
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro ao carregar perfil: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  }),
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
                    onTap: () {
                      Navigator.pop(context);
                      launchUrl(Uri.parse('https://condomeet.app.br/privacidade'), mode: LaunchMode.externalApplication);
                    },
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
                color: AppColors.textMain,
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
              color: AppColors.textMain,
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
      // Already mapped
      case 'warning':           return Icons.warning_amber_rounded;
      case 'chat':              return Icons.chat_bubble_outline_rounded;
      case 'file_copy':         return Icons.description_outlined;
      case 'calendar_month':    return Icons.calendar_month_outlined;
      case 'inventory_2':       return Icons.inventory_2_outlined;
      case 'qr_code':           return Icons.qr_code_2_rounded;
      case 'check_circle':      return Icons.how_to_reg_outlined;
      case 'history':           return Icons.history_rounded;
      case 'add_box':           return Icons.add_box_outlined;
      case 'local_shipping':    return Icons.local_shipping_outlined;
      case 'how_to_reg':        return Icons.how_to_reg_rounded;
      case 'forum':             return Icons.forum_outlined;
      case 'message':           return Icons.message_outlined;

      // People & access
      case 'person':            return Icons.person_outline_rounded;
      case 'person_add':        return Icons.person_add_outlined;
      case 'person_search':     return Icons.person_search_outlined;
      case 'group':             return Icons.group_outlined;
      case 'groups':            return Icons.groups_outlined;
      case 'manage_accounts':   return Icons.manage_accounts_outlined;
      case 'badge':             return Icons.badge_outlined;
      case 'fingerprint':       return Icons.fingerprint;
      case 'key':               return Icons.key_outlined;

      // Notifications & communication
      case 'notifications':     return Icons.notifications_outlined;
      case 'campaign':          return Icons.campaign_outlined;
      case 'announcement':      return Icons.announcement_outlined;
      case 'email':             return Icons.email_outlined;
      case 'sms':               return Icons.sms_outlined;
      case 'send':              return Icons.send_outlined;
      case 'phone':             return Icons.phone_outlined;

      // Building & condo
      case 'apartment':         return Icons.apartment_outlined;
      case 'domain':            return Icons.domain_outlined;
      case 'business':          return Icons.business_outlined;
      case 'home':              return Icons.home_outlined;
      case 'house':             return Icons.house_outlined;
      case 'meeting_room':      return Icons.meeting_room_outlined;
      case 'door_front':        return Icons.door_front_door_outlined;
      case 'security':          return Icons.security_outlined;
      case 'shield':            return Icons.shield_outlined;

      // Events & schedule
      case 'event':             return Icons.event_outlined;
      case 'event_note':        return Icons.event_note_outlined;
      case 'schedule':          return Icons.schedule_outlined;
      case 'date_range':        return Icons.date_range_outlined;
      case 'how_to_vote':       return Icons.how_to_vote_outlined;
      case 'poll':              return Icons.poll_outlined;
      case 'gavel':             return Icons.gavel_outlined;
      case 'handshake':         return Icons.handshake_outlined;

      // Documents & finance
      case 'article':           return Icons.article_outlined;
      case 'receipt':           return Icons.receipt_outlined;
      case 'receipt_long':      return Icons.receipt_long_outlined;
      case 'attach_money':      return Icons.attach_money;
      case 'paid':              return Icons.paid_outlined;
      case 'request_quote':     return Icons.request_quote_outlined;
      case 'assignment':        return Icons.assignment_outlined;
      case 'description':       return Icons.description_outlined;
      case 'folder':            return Icons.folder_outlined;
      case 'picture_as_pdf':    return Icons.picture_as_pdf_outlined;

      // Tools & settings
      case 'settings':          return Icons.settings_outlined;
      case 'tune':              return Icons.tune;
      case 'build':             return Icons.build_outlined;
      case 'construction':      return Icons.construction_outlined;
      case 'inventory':         return Icons.inventory_outlined;
      case 'warehouse':         return Icons.warehouse_outlined;
      case 'category':          return Icons.category_outlined;

      // Emergency & safety
      case 'emergency':         return Icons.emergency_outlined;
      case 'sos':               return Icons.sos_outlined;
      case 'local_police':      return Icons.local_police_outlined;
      case 'health_and_safety': return Icons.health_and_safety_outlined;

      // Misc
      case 'star':              return Icons.star_outline_rounded;
      case 'favorite':          return Icons.favorite_outline_rounded;
      case 'photo':             return Icons.photo_outlined;
      case 'image':             return Icons.image_outlined;
      case 'map':               return Icons.map_outlined;
      case 'place':             return Icons.place_outlined;
      case 'support':           return Icons.support_outlined;
      case 'help':              return Icons.help_outline_rounded;
      case 'info':              return Icons.info_outline_rounded;
      case 'book':              return Icons.book_outlined;
      case 'newspaper':         return Icons.newspaper_outlined;
      case 'class':             return Icons.class_outlined;

      default:
        return Icons.apps_rounded;
    }
  }
}
