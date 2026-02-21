import 'package:flutter/material.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/features/portaria/domain/repositories/parcel_repository.dart';
import 'package:condomeet/features/portaria/data/repositories/parcel_repository_impl.dart';

class ParcelHistoryScreen extends StatefulWidget {
  final String? residentId; // Null means Porter view (all history)

  const ParcelHistoryScreen({super.key, this.residentId});

  @override
  State<ParcelHistoryScreen> createState() => _ParcelHistoryScreenState();
}

class _ParcelHistoryScreenState extends State<ParcelHistoryScreen> {
  final ParcelRepository _repository = ParcelRepositoryImpl();
  List<Parcel> _parcels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final result = await _repository.getParcelHistory(residentId: widget.residentId);
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
        title: const Text('Histórico de Encomendas'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _parcels.isEmpty
              ? _buildEmptyState()
              : _buildHistoryList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: AppColors.border),
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

  Widget _buildHistoryList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _parcels.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final parcel = _parcels[index];
        return _buildHistoryCard(parcel);
      },
    );
  }

  Widget _buildHistoryCard(Parcel parcel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
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
                  'Unidade ${parcel.unitNumber} • Bloco ${parcel.block}',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'Entregue em: ${parcel.arrivalTime.day}/${parcel.arrivalTime.month} ${parcel.arrivalTime.hour}:${parcel.arrivalTime.minute.toString().padLeft(2, '0')}',
                      style: AppTypography.bodySmall.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              const Icon(Icons.verified_user_outlined, size: 20, color: Colors.blue),
              const SizedBox(height: 4),
              Text(
                'Auditado',
                style: AppTypography.label.copyWith(fontSize: 8, color: Colors.blue),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
