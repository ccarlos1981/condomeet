import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/core/utils/structure_helper.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import '../../../parcels/presentation/bloc/parcel_bloc.dart';
import '../../../parcels/presentation/bloc/parcel_event.dart';
import '../../../parcels/presentation/bloc/parcel_state.dart';
import '../../../portaria/domain/entities/parcel.dart';

class ParcelDashboardScreen extends StatefulWidget {
  final String residentId;

  const ParcelDashboardScreen({super.key, required this.residentId});

  @override
  State<ParcelDashboardScreen> createState() => _ParcelDashboardScreenState();
}

class _ParcelDashboardScreenState extends State<ParcelDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Start watching pending parcels
    context.read<ParcelBloc>().add(WatchPendingParcelsRequested(widget.residentId));
    
    // Fetch history
    final condoId = context.read<AuthBloc>().state.condominiumId;
    if (condoId != null) {
      context.read<ParcelBloc>().add(FetchParcelHistoryRequested(
        residentId: widget.residentId,
        condominiumId: condoId,
      ));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Minhas Encomendas'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'Pendentes'),
            Tab(text: 'Histórico'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildPendingTab() {
    return BlocBuilder<ParcelBloc, ParcelState>(
      builder: (context, state) {
        if (state is ParcelLoading) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        if (state is ParcelError) {
          return Center(child: Text(state.message, style: const TextStyle(color: Colors.red)));
        }

        if (state is ParcelLoaded) {
          final parcels = state.pendingParcels;
          if (parcels.isEmpty) {
            return _buildEmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Tudo limpo!',
              message: 'Nenhuma encomenda aguardando você.',
            );
          }
          return _buildParcelList(parcels, isPending: true);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildHistoryTab() {
    return BlocBuilder<ParcelBloc, ParcelState>(
      builder: (context, state) {
        if (state is ParcelLoading) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        if (state is ParcelLoaded) {
          final parcels = state.historyParcels;
          if (parcels.isEmpty) {
            return _buildEmptyState(
              icon: Icons.history,
              title: 'Histórico vazio',
              message: 'Suas encomendas entregues aparecerão aqui.',
            );
          }
          return _buildParcelList(parcels, isPending: false);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: const Color(0xFFCED4DA)),
            const SizedBox(height: 24),
            Text(title, style: AppTypography.h2),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParcelList(List<Parcel> parcels, {required bool isPending}) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: parcels.length,
      itemBuilder: (context, index) {
        final parcel = parcels[index];
        return _buildParcelCard(parcel, isPending);
      },
    );
  }

  Widget _buildParcelCard(Parcel parcel, bool isPending) {
    final authState = context.read<AuthBloc>().state;
    final unitName = StructureHelper.getFullUnitName(
      authState.tipoEstrutura,
      parcel.block,
      parcel.unitNumber,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (parcel.photoUrl != null)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: _buildImage(parcel.photoUrl!),
                ),
                if (!isPending)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Entregue',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isPending ? 'Encomenda Pendente' : 'Encomenda Entregue',
                      style: AppTypography.h3.copyWith(
                        color: isPending ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                    if (isPending)
                       const Icon(Icons.notifications_active, color: AppColors.primary, size: 20),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.home_outlined, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      unitName,
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Recebida: ${parcel.arrivalTime.day}/${parcel.arrivalTime.month} às ${parcel.arrivalTime.hour}:${parcel.arrivalTime.minute.toString().padLeft(2, '0')}',
                        style: AppTypography.bodySmall,
                      ),
                    ),
                  ],
                ),
                if (!isPending && parcel.deliveryTime != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Retirada: ${parcel.deliveryTime!.day}/${parcel.deliveryTime!.month} às ${parcel.deliveryTime!.hour}:${parcel.deliveryTime!.minute.toString().padLeft(2, '0')}',
                          style: AppTypography.bodySmall.copyWith(color: Colors.green, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String url) {
    if (url.startsWith('http')) {
      return Image.network(
        url,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    } else {
      final file = File(url);
      if (file.existsSync()) {
        return Image.file(
          file,
          height: 180,
          width: double.infinity,
          fit: BoxFit.cover,
        );
      }
      return _buildPlaceholder();
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 180,
      width: double.infinity,
      color: Colors.grey.shade100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2, color: Colors.grey.shade400, size: 48),
          const SizedBox(height: 8),
          Text(
            'Imagem não disponível',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

