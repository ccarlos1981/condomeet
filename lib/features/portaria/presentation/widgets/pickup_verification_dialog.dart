import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:condomeet/core/di/injection_container.dart';
import 'package:condomeet/core/services/security_service.dart';
import 'package:condomeet/core/design_system/design_system.dart';

enum VerificationMethod { pin, photo }

class PickupVerificationDialog extends StatefulWidget {
  final String residentName;
  final Function(VerificationMethod method, String? data) onVerified;

  const PickupVerificationDialog({
    super.key,
    required this.residentName,
    required this.onVerified,
  });

  @override
  State<PickupVerificationDialog> createState() => _PickupVerificationDialogState();
}

class _PickupVerificationDialogState extends State<PickupVerificationDialog> {
  String _pin = '';
  bool _isPinMode = true;

  bool _isError = false;

  void _handleKeyPress(String value) {
    if (_pin.length < 6) {
      setState(() {
        _pin += value;
        _isError = false;
      });
      HapticFeedback.lightImpact();
      
      if (_pin.length == 6) {
        _verifyPin();
      }
    }
  }

  Future<void> _verifyPin() async {
    final security = sl<SecurityService>();
    final isValid = await security.verifyPin(_pin);
    
    if (isValid) {
      widget.onVerified(VerificationMethod.pin, _pin);
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _pin = '';
        _isError = true;
      });
    }
  }

  void _handleBackspace() {
    if (_pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Comprovar Retirada', style: AppTypography.h2),
            const SizedBox(height: 8),
            Text(
              'Confirmando entrega para ${widget.residentName}',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildModeTab(
                    label: 'PIN',
                    icon: Icons.grid_3x3,
                    isActive: _isPinMode,
                    onTap: () => setState(() => _isPinMode = true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildModeTab(
                    label: 'Foto',
                    icon: Icons.camera_alt_outlined,
                    isActive: !_isPinMode,
                    onTap: () => setState(() => _isPinMode = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            if (_isPinMode) _buildPinPad() else _buildPhotoSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTab({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? AppColors.primary : AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isActive ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.label.copyWith(
                color: isActive ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinPad() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (index) {
            final hasValue = index < _pin.length;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isError 
                  ? Colors.redAccent 
                  : (hasValue ? AppColors.primary : AppColors.border),
              ),
            );
          }),
        ),
        const SizedBox(height: 32),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
          ),
          itemCount: 12,
          itemBuilder: (context, index) {
            if (index == 9) return const SizedBox.shrink();
            if (index == 10) return _buildKey('0');
            if (index == 11) {
              return IconButton(
                onPressed: _handleBackspace,
                icon: const Icon(Icons.backspace_outlined, color: AppColors.textSecondary),
              );
            }
            return _buildKey('${index + 1}');
          },
        ),
      ],
    );
  }

  Widget _buildKey(String value) {
    return InkWell(
      onTap: () => _handleKeyPress(value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(value, style: AppTypography.h2),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      children: [
        Container(
          height: 160,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, style: BorderStyle.solid),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_outline, size: 48, color: AppColors.border),
              const SizedBox(height: 8),
              Text('Capturar foto do recebedor', style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        CondoButton(
          label: 'Capturar e Confirmar',
          onPressed: () {
            // Simulated photo capture and confirmation
            widget.onVerified(VerificationMethod.photo, 'fake_photo_path');
          },
        ),
      ],
    );
  }
}
