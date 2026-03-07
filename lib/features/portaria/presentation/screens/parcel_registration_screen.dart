import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/core/errors/result.dart';
import '../../domain/entities/parcel.dart';
import '../../domain/repositories/resident_repository.dart';
import '../../domain/repositories/parcel_repository.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/core/services/messaging_service.dart';
import 'package:condomeet/core/di/injection_container.dart';
import 'package:condomeet/core/utils/structure_helper.dart';
import 'package:condomeet/core/utils/error_sanitizer.dart';

class ParcelRegistrationScreen extends StatefulWidget {
  final Resident resident;

  const ParcelRegistrationScreen({super.key, required this.resident});

  @override
  State<ParcelRegistrationScreen> createState() => _ParcelRegistrationScreenState();
}

class _ParcelRegistrationScreenState extends State<ParcelRegistrationScreen> {
  late final ParcelRepository _repository;
  final MessagingService _messagingService = WhatsAppMessagingServiceMock();
  dynamic _capturedPhoto;
  bool _isRegistering = false;

  @override
  void initState() {
    super.initState();
    _repository = sl<ParcelRepository>();
  }

  void _takePhoto() async {
    // For simulator testing, we'll use a dummy photo path if the user taps the capture area
    setState(() {
      _capturedPhoto = File('/tmp/dummy_parcel.jpg'); // Dummy path for logic verification
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Foto simulada capturada para teste.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleRegister() async {
    setState(() => _isRegistering = true);
    
    // Haptic feedback (AC4)
    HapticFeedback.mediumImpact();

    final authState = context.read<AuthBloc>().state;

    final parcel = Parcel(
      id: const Uuid().v4(),
      residentId: widget.resident.id,
      residentName: widget.resident.fullName,
      unitNumber: widget.resident.unitNumber ?? 'N/A',
      block: widget.resident.block ?? 'N/A',
      arrivalTime: DateTime.now(),
      status: 'pending',
      photoUrl: _capturedPhoto?.path,
      condominiumId: authState.condominiumId,
    );

    final result = await _repository.registerParcel(parcel);

    if (mounted) {
      if (result is Success) {
        // Trigger WhatsApp Alert (Story 2.4)
        // Note: For now, we don't block the UI on the alert delivery
        _messagingService.sendParcelAlert(
          residentName: widget.resident.fullName,
          residentPhone: widget.resident.phoneNumber ?? 'Unknown',
          unitNumber: widget.resident.unitNumber ?? 'N/A',
        );
        
        _showSuccessAnimation();
      } else {
        final errorMessage = ErrorSanitizer.sanitize((result as Failure).message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: AppColors.error),
        );
        setState(() => _isRegistering = false);
      }
    }
  }

  void _showSuccessAnimation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SuccessDialog(),
    ).then((_) {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.settings.name == '/home' || route.isFirst);
      }
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Encomenda'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildResidentCard(),
              const SizedBox(height: 32),
              Text('Capturar Foto (Opcional)', style: AppTypography.label),
              const SizedBox(height: 12),
              _buildPhotoCapture(),
              const Spacer(),
              if (_isRegistering)
                const Center(child: CircularProgressIndicator(color: AppColors.primary))
              else
                CondoButton(
                  label: 'Registrar Encomenda',
                  onPressed: _handleRegister,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResidentCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              widget.resident.fullName[0].toUpperCase(),
              style: AppTypography.h2.copyWith(color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.resident.fullName, style: AppTypography.h2),
                const SizedBox(height: 4),
                Text(
                  StructureHelper.getFullUnitName(context.read<AuthBloc>().state.tipoEstrutura, widget.resident.block ?? '?', widget.resident.unitNumber ?? '?'),
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCapture() {
    return GestureDetector(
      onTap: _takePhoto,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, style: BorderStyle.solid),
        ),
        child: _capturedPhoto == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.camera_alt_outlined, size: 48, color: AppColors.border),
                  const SizedBox(height: 8),
                  Text('Tocar para capturar', style: TextStyle(color: AppColors.textSecondary)),
                ],
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(File(_capturedPhoto!.path), fit: BoxFit.cover),
              ),
      ),
    );
  }
}

class SuccessDialog extends StatelessWidget {
  const SuccessDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 80),
            const SizedBox(height: 24),
            Text('Sucesso!', style: AppTypography.h1),
            const SizedBox(height: 8),
            Text('Encomenda registrada.', style: AppTypography.bodyLarge),
          ],
        ),
      ),
    );
  }
}
