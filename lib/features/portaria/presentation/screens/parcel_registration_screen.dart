import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/core/errors/result.dart';
import 'package:condomeet/features/portaria/domain/repositories/resident_repository.dart';
import 'package:condomeet/features/portaria/domain/repositories/parcel_repository.dart';
import 'package:condomeet/features/portaria/data/repositories/parcel_repository_impl.dart';
import 'package:condomeet/core/services/messaging_service.dart';

class ParcelRegistrationScreen extends StatefulWidget {
  final Resident resident;

  const ParcelRegistrationScreen({super.key, required this.resident});

  @override
  State<ParcelRegistrationScreen> createState() => _ParcelRegistrationScreenState();
}

class _ParcelRegistrationScreenState extends State<ParcelRegistrationScreen> {
  final ParcelRepository _repository = ParcelRepositoryImpl();
  final MessagingService _messagingService = WhatsAppMessagingServiceMock();
  XFile? _capturedPhoto;
  bool _isRegistering = false;

  void _takePhoto() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    // Simplified camera taking logic for MVP/Prototype
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Câmera disparada (Simulado)')),
    );
    
    // For now, we simulate a photo captured (if we were on mobile/real device)
    // setState(() => _capturedPhoto = ...);
  }

  void _handleRegister() async {
    setState(() => _isRegistering = true);
    
    // Haptic feedback (AC4)
    HapticFeedback.mediumImpact();

    final parcel = Parcel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      residentId: widget.resident.id,
      residentName: widget.resident.fullName,
      unitNumber: widget.resident.unitNumber ?? 'N/A',
      block: widget.resident.block ?? 'N/A',
      arrivalTime: DateTime.now(),
      photoUrl: _capturedPhoto?.path,
    );

    final result = await _repository.registerParcel(parcel);

    if (mounted) {
      if (result is Success) {
        // Trigger WhatsApp Alert (Story 2.4)
        // Note: For now, we don't block the UI on the alert delivery
        _messagingService.sendParcelAlert(
          residentName: widget.resident.fullName,
          residentPhone: '5511988887777', // Mock phone
          unitNumber: widget.resident.unitNumber ?? 'N/A',
        );
        
        _showSuccessAnimation();
      } else {
        final errorMessage = (result as Failure).message;
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
                  'Bloco ${widget.resident.block} • Unidade ${widget.resident.unitNumber}',
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
