import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/features/community/domain/models/common_area.dart';
import 'package:condomeet/features/community/presentation/bloc/booking_bloc.dart';
import 'package:condomeet/features/community/presentation/bloc/booking_bloc_components.dart';
import 'package:condomeet/features/community/presentation/screens/area_availability_screen.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';

class AreaPickerScreen extends StatefulWidget {
  const AreaPickerScreen({super.key});

  @override
  State<AreaPickerScreen> createState() => _AreaPickerScreenState();
}

class _AreaPickerScreenState extends State<AreaPickerScreen> {
  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState.condominiumId != null) {
      context.read<BookingBloc>().add(WatchCommonAreasRequested(authState.condominiumId!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservar Espaço'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: BlocBuilder<BookingBloc, BookingState>(
        builder: (context, state) {
          if (state is BookingLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is BookingError) {
            return Center(child: Text(state.message));
          }

          if (state is BookingAreasLoaded) {
            if (state.areas.isEmpty) {
              return const Center(child: Text('Nenhum espaço disponível.'));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: state.areas.length,
              itemBuilder: (context, index) {
                return _buildAreaCard(context, state.areas[index]);
              },
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildAreaCard(BuildContext context, CommonArea area) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => AreaAvailabilityScreen(area: area)),
        ),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(_getIcon(area.iconPath), color: AppColors.primary, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(area.name, style: AppTypography.h3),
                    const SizedBox(height: 4),
                    Text(
                      'Capacidade: ${area.capacity} pessoas',
                      style: AppTypography.label.copyWith(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      area.description,
                      style: AppTypography.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIcon(String iconKey) {
    switch (iconKey) {
      case 'grill':
        return Icons.outdoor_grill;
      case 'party_room':
        return Icons.celebration;
      case 'sports':
        return Icons.sports_basketball;
      default:
        return Icons.location_on;
    }
  }
}
