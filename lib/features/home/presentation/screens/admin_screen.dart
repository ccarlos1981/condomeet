import 'package:flutter/material.dart';
import 'package:condomeet/core/design_system/design_system.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
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
        child: ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildSectionTitle('Liberações'),
            _buildAdminItem(
              context: context,
              icon: Icons.inventory_2_outlined,
              label: 'Encomendas',
              onTap: () => Navigator.of(context).pushNamed('/parcel-history'),
            ),
            _buildAdminItem(
              context: context,
              icon: Icons.book_outlined,
              label: 'Livro de ocorrência',
              onTap: () {},
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Aprovações'),
            _buildAdminItem(
              context: context,
              icon: Icons.person_add_outlined,
              label: 'Aprovar cadastro de Morador',
              onTap: () => Navigator.of(context).pushNamed('/manager-approval'),
            ),
            _buildAdminItem(
              context: context,
              icon: Icons.handshake_outlined,
              label: 'Aprovar e consultar reserva de espaço',
              onTap: () => Navigator.of(context).pushNamed('/area-booking'),
            ),
            _buildAdminItem(
              context: context,
              icon: Icons.newspaper_outlined,
              label: 'Classificados',
              badgeCount: 0,
              onTap: () {},
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Fale com morador (a)'),
            _buildAdminItem(
              context: context,
              icon: Icons.phone_outlined,
              label: 'Enviar Aviso',
              onTap: () {},
            ),
            _buildAdminItem(
              context: context,
              icon: Icons.phone_callback_outlined,
              label: 'Fale Conosco',
              onTap: () {},
            ),
            _buildAdminItem(
              context: context,
              icon: Icons.description_outlined,
              label: 'Documento',
              onTap: () => Navigator.of(context).pushNamed('/document-center'),
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
              onTap: () {},
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
            const SizedBox(height: 40),
          ],
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
          color: Color(0xFF666666),
        ),
      ),
    );
  }

  Widget _buildAdminItem({
    required BuildContext context,
    required IconData icon,
    required String label,
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
              if (badgeCount != null)
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
