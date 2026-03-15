import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/core/utils/structure_helper.dart';
import '../../../parcels/presentation/bloc/parcel_bloc.dart';
import '../../../parcels/presentation/bloc/parcel_event.dart';
import '../../../parcels/presentation/bloc/parcel_state.dart';
import '../../../portaria/domain/entities/parcel.dart';

import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';

class ParcelHistoryScreen extends StatefulWidget {
  final String? residentId; // Null means Porter view (all history)

  const ParcelHistoryScreen({super.key, this.residentId});

  @override
  State<ParcelHistoryScreen> createState() => _ParcelHistoryScreenState();
}

class _ParcelHistoryScreenState extends State<ParcelHistoryScreen> {
  @override
  void initState() {
    super.initState();
    final condoId = context.read<AuthBloc>().state.condominiumId;
    if (condoId != null) {
      context.read<ParcelBloc>().add(FetchParcelHistoryRequested(
        residentId: widget.residentId,
        condominiumId: condoId,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Histórico de Encomendas'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: BlocBuilder<ParcelBloc, ParcelState>(
        builder: (context, state) {
          if (state is ParcelLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (state is ParcelError) {
            return Center(child: Text(state.message, style: const TextStyle(color: Colors.red)));
          }

          if (state is ParcelLoaded) {
            final parcels = state.historyParcels;
            if (parcels.isEmpty) {
              return _buildEmptyState();
            }
            return _buildHistoryList(parcels);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history, size: 80, color: AppColors.disabledIcon),
          const SizedBox(height: 16),
          Text('Nenhum registro', style: AppTypography.h2),
          const SizedBox(height: 8),
          Text(
            'Nenhuma encomenda entregue recentemente.',
            style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(List<Parcel> parcels) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: parcels.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final parcel = parcels[index];
        return _buildHistoryCard(parcel);
      },
    );
  }

  Widget _buildHistoryCard(Parcel parcel) {
    final authState = context.read<AuthBloc>().state;
    final unitName = StructureHelper.getFullUnitName(
      authState.tipoEstrutura,
      parcel.block,
      parcel.unitNumber,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Colors.green.withValues(alpha: 0.1),
            child: const Icon(Icons.check, color: Colors.green),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(parcel.residentName, style: AppTypography.h3),
                Text(
                  unitName,
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'Entregue em: ${parcel.deliveryTime?.day}/${parcel.deliveryTime?.month} às ${parcel.deliveryTime?.hour}:${parcel.deliveryTime?.minute.toString().padLeft(2, '0')}',
                      style: AppTypography.bodySmall.copyWith(fontSize: 10, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              const Icon(Icons.verified_user_outlined, size: 20, color: AppColors.primary),
              const SizedBox(height: 4),
              Text(
                'Auditado',
                style: AppTypography.label.copyWith(fontSize: 8, color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

