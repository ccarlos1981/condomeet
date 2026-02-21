import 'package:flutter/material.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/core/services/security_service.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isConfirmation = false;
  String _firstPin = '';

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              Text(
                _isConfirmation ? 'Confirme seu PIN' : 'Crie seu PIN',
                style: AppTypography.h1,
              ),
              const SizedBox(height: 16),
              Text(
                _isConfirmation
                    ? 'Digite novamente o PIN de 6 dígitos'
                    : 'Crie um PIN de 6 dígitos para acesso rápido',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  6,
                  (index) => _buildPinField(index),
                ),
              ),
              const Spacer(),
              if (!_isConfirmation)
                TextButton(
                  onPressed: () {
                    // TODO: Navigate to biometric setup
                    Navigator.of(context).pushReplacementNamed('/home');
                  },
                  child: Center(
                    child: Text(
                      'Pular e usar biometria',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinField(int index) {
    return SizedBox(
      width: 50,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        obscureText: true,
        maxLength: 1,
        style: AppTypography.h2,
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
          
          // Auto-submit when all fields are filled
          if (index == 5 && value.isNotEmpty) {
            _handlePinComplete();
          }
        },
      ),
    );
  }

  void _handlePinComplete() async {
    final pin = _controllers.map((c) => c.text).join();
    
    if (pin.length != 6) {
      return;
    }

    if (!_isConfirmation) {
      // First PIN entry
      setState(() {
        _firstPin = pin;
        _isConfirmation = true;
      });
      
      // Clear fields for confirmation
      for (var controller in _controllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
    } else {
      // Confirmation
      if (pin != _firstPin) {
        _showError('Os PINs não coincidem. Tente novamente.');
        setState(() {
          _isConfirmation = false;
          _firstPin = '';
        });
        for (var controller in _controllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();
        return;
      }

      try {
        final securityService = SecurityService();
        await securityService.savePin(pin);
        
        // Check for biometrics
        final canUseBiometrics = await securityService.isBiometricsAvailable();
        
        if (!mounted) return;
        
        if (canUseBiometrics) {
          _showBiometricsDialog(securityService);
        } else {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } catch (e) {
        _showError('Erro ao salvar PIN. Tente novamente.');
      }
    }
  }

  void _showBiometricsDialog(SecurityService service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usar Biometria?'),
        content: const Text(
          'Deseja usar FaceID/Digital para entrar mais rápido no Condomeet?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pushReplacementNamed('/home'),
            child: const Text('Não'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              await service.setBiometricsEnabled(true);
              navigator.pushReplacementNamed('/home');
            },
            child: const Text('Sim'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }
}
