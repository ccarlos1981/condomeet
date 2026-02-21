import 'dart:io';
import 'package:flutter/material.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/features/portaria/domain/repositories/parcel_repository.dart';
import 'package:condomeet/features/portaria/data/repositories/parcel_repository_impl.dart';

class ParcelDashboardScreen extends StatefulWidget {
  final String residentId;

  const ParcelDashboardScreen({super.key, required this.residentId});

  @override
  State<ParcelDashboardScreen> createState() => _ParcelDashboardScreenState();
}

class _ParcelDashboardScreenState extends State<ParcelDashboardScreen> {
  final ParcelRepository _repository = ParcelRepositoryImpl();
  List<Parcel> _parcels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadParcels();
  }

  Future<void> _loadParcels() async {
    final result = await _repository.getParcelsForResident(widget.residentId);
    if (mounted) {
      setState(() {
        if (result is Success<List<Parcel>>) {
          _parcels = result.data;
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Encomendas'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _parcels.isEmpty
              ? _buildEmptyState()
              : _buildParcelList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: AppColors.border),
          const SizedBox(height: 16),
          Text('Tudo limpo!', style: AppTypography.h2),
          const SizedBox(height: 8),
          Text(
            'Nenhuma encomenda aguardando você.',
            style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildParcelList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _parcels.length,
      itemBuilder: (context, index) {
        final parcel = _parcels[index];
        return _buildParcelCard(parcel);
      },
    );
  }

  Widget _buildParcelCard(Parcel parcel) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (parcel.photoUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.file(
                File(parcel.photoUrl!),
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Encomenda Recebida', style: AppTypography.h3),
                      const SizedBox(height: 4),
                      Text(
                        'Recebida em: ${parcel.arrivalTime.day}/${parcel.arrivalTime.month} às ${parcel.arrivalTime.hour}:${parcel.arrivalTime.minute.toString().padLeft(2, '0')}',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Pendente',
                    style: AppTypography.label.copyWith(color: AppColors.primary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
