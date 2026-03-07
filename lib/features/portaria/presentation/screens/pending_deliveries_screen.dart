import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import '../../../parcels/presentation/bloc/parcel_bloc.dart';
import '../../../parcels/presentation/bloc/parcel_event.dart';
import '../../../parcels/presentation/bloc/parcel_state.dart';
import 'package:condomeet/features/portaria/domain/entities/parcel.dart';
import 'package:condomeet/core/utils/structure_helper.dart';
import '../widgets/pickup_verification_dialog.dart';

import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_state.dart';

class PendingDeliveriesScreen extends StatefulWidget {
  const PendingDeliveriesScreen({super.key});

  @override
  State<PendingDeliveriesScreen> createState() => _PendingDeliveriesScreenState();
}

class _PendingDeliveriesScreenState extends State<PendingDeliveriesScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final condoId = context.read<AuthBloc>().state.condominiumId;
    if (condoId != null) {
      context.read<ParcelBloc>().add(WatchAllPendingParcelsRequested(condoId));
    }
  }

  void _handleConfirmDelivery(Parcel parcel) async {
    showDialog(
      context: context,
      builder: (context) => PickupVerificationDialog(
        residentName: parcel.residentName,
        onVerified: (method, data) {
          Navigator.of(context).pop(); 
          _finalizeDelivery(parcel, method, data);
        },
      ),
    );
  }

  void _finalizeDelivery(Parcel parcel, VerificationMethod method, String? data) {
    HapticFeedback.mediumImpact();
    context.read<ParcelBloc>().add(MarkParcelAsDeliveredRequested(parcel.id, pickupProofUrl: data));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Entrega confirmada via ${method == VerificationMethod.pin ? 'PIN' : 'Foto'}!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Entregas Pendentes'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: CondoInput(
              label: '',
              hint: 'Filtrar por nome ou unidade...',
              prefix: const Icon(Icons.search, color: AppColors.textSecondary),
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          Expanded(
            child: BlocBuilder<ParcelBloc, ParcelState>(
              builder: (context, state) {
                if (state is ParcelLoading) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }

                if (state is ParcelError) {
                  return Center(child: Text(state.message, style: const TextStyle(color: Colors.red)));
                }

                if (state is ParcelLoaded) {
                  final filteredParcels = state.pendingParcels.where((p) {
                    return p.residentName.toLowerCase().contains(_searchQuery) ||
                           p.unitNumber.contains(_searchQuery);
                  }).toList();

                  if (filteredParcels.isEmpty) {
                    return _buildEmptyState();
                  }
                  return _buildDeliveriesList(filteredParcels);
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.15),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, size: 80, color: Color(0xFFB0BEC5)),
              const SizedBox(height: 16),
              Text('Nenhuma pendência', style: AppTypography.h2),
              const SizedBox(height: 8),
              Text(
                'Todas as encomendas foram entregues.',
                style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveriesList(List<Parcel> parcels) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: parcels.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final parcel = parcels[index];
        return _buildDeliveryTile(parcel);
      },
    );
  }

  Widget _buildDeliveryTile(Parcel parcel) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFEEEEEE),
            child: Icon(Icons.inventory_2, color: Color(0xFF757575)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(parcel.residentName, style: AppTypography.h3),
                Text(
                  StructureHelper.getFullUnitName(context.read<AuthBloc>().state.tipoEstrutura, parcel.block ?? '?', parcel.unitNumber ?? '?'),
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          CondoButton(
            label: 'Entregar',
            onPressed: () => _handleConfirmDelivery(parcel),
            isFullWidth: false,
          ),
        ],
      ),
    );
  }
}
