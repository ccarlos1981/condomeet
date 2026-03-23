import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  static const _superAdminEmails = {
    'ccarlos1981+60@gmail.com',
    'cristiano.santos@gmx.com',
  };

  String? get _currentEmail =>
      Supabase.instance.client.auth.currentUser?.email;

  // Badge counts
  int _pendingEncomendas = 0;
  int _pendingOcorrencias = 0;
  int _pendingCadastros = 0;
  int _pendingReservas = 0;
  int _pendingClassificados = 0;
  int _pendingFaleConosco = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPendingCounts());
  }

  Future<void> _loadPendingCounts() async {
    final condoId = context.read<AuthBloc>().state.condominiumId;
    if (condoId == null) return;

    final supabase = Supabase.instance.client;

    try {
      // Run all queries in parallel
      final results = await Future.wait([
        supabase
            .from('encomendas')
            .select('id')
            .eq('condominio_id', condoId)
            .eq('status', 'pending')
            .count(CountOption.exact),
        supabase
            .from('ocorrencias')
            .select('id')
            .eq('condominio_id', condoId)
            .eq('status', 'pending')
            .count(CountOption.exact),
        supabase
            .from('perfil')
            .select('id')
            .eq('condominio_id', condoId)
            .eq('status_aprovacao', 'pendente')
            .count(CountOption.exact),
        supabase
            .from('reservas')
            .select('id')
            .eq('condominio_id', condoId)
            .eq('status', 'pendente')
            .count(CountOption.exact),
        supabase
            .from('classificados')
            .select('id')
            .eq('condominio_id', condoId)
            .eq('status', 'pendente')
            .count(CountOption.exact),
        supabase
            .from('fale_sindico_threads')
            .select('id')
            .eq('condominio_id', condoId)
            .eq('status', 'aberto')
            .count(CountOption.exact),
      ]);

      if (!mounted) return;
      setState(() {
        _pendingEncomendas = results[0].count;
        _pendingOcorrencias = results[1].count;
        _pendingCadastros = results[2].count;
        _pendingReservas = results[3].count;
        _pendingClassificados = results[4].count;
        _pendingFaleConosco = results[5].count;
      });
    } catch (e) {
      debugPrint('Error loading pending counts: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Área Administrativa',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadPendingCounts,
          child: ListView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            dragStartBehavior: DragStartBehavior.down,
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildSectionTitle('Liberações'),
              _buildAdminItem(
                context: context,
                icon: Icons.local_shipping_outlined,
                label: 'Encomendas do Cond.',
                badgeCount: _pendingEncomendas,
                onTap: () => Navigator.of(context).pushNamed('/pending-deliveries').then((_) => _loadPendingCounts()),
              ),
              _buildAdminItem(
                context: context,
                icon: Icons.book_outlined,
                label: 'Livro de ocorrência',
                badgeCount: _pendingOcorrencias,
                onTap: () => Navigator.of(context).pushNamed('/occurrence-admin').then((_) => _loadPendingCounts()),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Aprovações'),
              _buildAdminItem(
                context: context,
                icon: Icons.person_add_outlined,
                label: 'Aprovar cadastro de Morador',
                badgeCount: _pendingCadastros,
                onTap: () => Navigator.of(context).pushNamed('/manager-approval').then((_) => _loadPendingCounts()),
              ),
              _buildAdminItem(
                context: context,
                icon: Icons.handshake_outlined,
                label: 'Aprovar e consultar reserva de espaço',
                badgeCount: _pendingReservas,
                onTap: () => Navigator.of(context).pushNamed('/area-booking').then((_) => _loadPendingCounts()),
              ),
              _buildAdminItem(
                context: context,
                icon: Icons.newspaper_outlined,
                label: 'Classificados',
                badgeCount: _pendingClassificados,
                onTap: () => Navigator.of(context).pushNamed('/admin-classificados').then((_) => _loadPendingCounts()),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Fale com morador (a)'),
              _buildAdminItem(
                context: context,
                icon: Icons.campaign_outlined,
                label: 'Enviar Aviso',
                onTap: () => Navigator.of(context).pushNamed('/admin-avisos'),
              ),
              _buildAdminItem(
                context: context,
                icon: Icons.phone_callback_outlined,
                label: 'Fale Conosco',
                badgeCount: _pendingFaleConosco,
                onTap: () => Navigator.of(context).pushNamed('/fale-conosco-admin').then((_) => _loadPendingCounts()),
              ),
              _buildAdminItem(
                context: context,
                icon: Icons.description_outlined,
                label: 'Documento',
                onTap: () => Navigator.of(context).pushNamed('/admin-documentos'),
              ),
              _buildAdminItem(
                context: context,
                icon: Icons.assignment_outlined,
                label: 'Contrato',
                onTap: () => Navigator.of(context).pushNamed('/admin-contratos'),
              ),
              _buildAdminItem(
                context: context,
                icon: Icons.how_to_vote_outlined,
                label: 'Assembleias Online',
                onTap: () => Navigator.of(context).pushNamed('/assemblies'),
              ),
              _buildAdminItem(
                context: context,
                icon: Icons.image_outlined,
                label: 'Fotos / evento do cond.',
                onTap: () => Navigator.of(context).pushNamed('/admin-album-fotos'),
              ),
              _buildAdminItem(
                context: context,
                icon: Icons.gavel_outlined,
                label: 'Multas e notificações',
                onTap: () {},
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Parte interna do condomínio'),
              _buildAdminItem(
                context: context,
                icon: Icons.security_outlined,
                label: 'Portaria',
                onTap: () => Navigator.of(context).pushNamed('/resident-search'),
              ),
              _buildAdminItem(
                context: context,
                icon: Icons.inventory_2_outlined,
                label: 'Almoxarifado / Estoque',
                onTap: () => Navigator.of(context).pushNamed('/inventory'),
              ),
              _buildAdminItem(
                context: context,
                icon: Icons.apartment_outlined,
                label: 'Estrutura (Blocos e Unidades)',
                onTap: () => Navigator.of(context).pushNamed('/condo-structure'),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Parametrização'),
              _buildAdminItem(
                context: context,
                icon: Icons.tune,
                label: 'Configurar Menu',
                subtitle: 'Acesso e ordem dos botões por perfil',
                onTap: () => Navigator.of(context).pushNamed('/configure-menu'),
              ),
              if (_superAdminEmails.contains(_currentEmail)) ...[
                const SizedBox(height: 24),
                _buildSectionTitle('Super Admin'),
                _buildAdminItem(
                  context: context,
                  icon: Icons.send_to_mobile_outlined,
                  label: 'Push Notification Universal',
                  subtitle: 'Enviar push para todos os usuários',
                  onTap: () => Navigator.of(context).pushNamed('/universal-push'),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildAdminItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    String? subtitle,
    int? badgeCount,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (badgeCount != null && badgeCount > 0)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(badgeCount.toString(),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              const Icon(
                Icons.keyboard_double_arrow_right,
                color: AppColors.primary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
