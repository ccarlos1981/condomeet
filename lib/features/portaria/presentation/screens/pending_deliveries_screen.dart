import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/features/portaria/domain/repositories/parcel_repository.dart';
import 'package:condomeet/features/portaria/data/repositories/parcel_repository_impl.dart';
import 'package:condomeet/features/portaria/presentation/widgets/pickup_verification_dialog.dart';

class PendingDeliveriesScreen extends StatefulWidget {
  const PendingDeliveriesScreen({super.key});

  @override
  State<PendingDeliveriesScreen> createState() => _PendingDeliveriesScreenState();
}

class _PendingDeliveriesScreenState extends State<PendingDeliveriesScreen> {
  final ParcelRepository _repository = ParcelRepositoryImpl();
  List<Parcel> _parcels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingParcels();
  }

  Future<void> _loadPendingParcels() async {
    setState(() => _isLoading = true);
    final result = await _repository.getAllPendingParcels();
    if (mounted) {
      setState(() {
        if (result is Success<List<Parcel>>) {
          _parcels = result.data;
        }
        _isLoading = false;
      });
    }
  }

  void _handleConfirmDelivery(Parcel parcel) async {
    showDialog(
      context: context,
      builder: (context) => PickupVerificationDialog(
        residentName: parcel.residentName,
        onVerified: (method, data) async {
          Navigator.of(context).pop(); // Close dialog
          _finalizeDelivery(parcel, method, data);
        },
      ),
    );
  }

  void _finalizeDelivery(Parcel parcel, VerificationMethod method, String? data) async {
    // Haptic feedback
    HapticFeedback.mediumImpact();

    final result = await _repository.markAsDelivered(parcel.id);
    
    if (mounted) {
      if (result is Success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Entrega confirmada via ${method == VerificationMethod.pin ? 'PIN' : 'Foto'}!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadPendingParcels(); // Refresh list
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entregas Pendentes'),
        backgroundColor: Colors.transparent,
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
              onChanged: (value) {
                // TODO: Implement local filtering logic
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _parcels.isEmpty
                    ? _buildEmptyState()
                    : _buildDeliveriesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 80, color: AppColors.border),
          const SizedBox(height: 16),
          Text('Nenhuma pendência', style: AppTypography.h2),
          const SizedBox(height: 8),
          Text(
            'Todas as encomendas foram entregues.',
            style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveriesList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _parcels.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final parcel = _parcels[index];
        return _buildDeliveryTile(parcel);
      },
    );
  }

  Widget _buildDeliveryTile(Parcel parcel) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.surface,
            child: const Icon(Icons.inventory_2, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(parcel.residentName, style: AppTypography.h3),
                Text(
                  'Bloco ${parcel.block} • Unidade ${parcel.unitNumber}',
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
