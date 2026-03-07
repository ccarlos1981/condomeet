import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/core/services/security_service.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_event.dart';
import 'package:condomeet/features/auth/presentation/bloc/auth_state.dart';

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

  void _handlePinComplete() {
    final pin = _controllers.map((c) => c.text).join();
    
    if (pin.length != 6) {
      return;
    }

    if (!_isConfirmation) {
      setState(() {
        _firstPin = pin;
        _isConfirmation = true;
      });
      
      for (var controller in _controllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
    } else {
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

      context.read<AuthBloc>().add(AuthPinSetupCompleted(pin));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _showBiometricsDialog(SecurityService service) {
    showDialog(
      context: context,
      barrierDismissible: false,
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

  Widget _buildPinField(int index) {
    return SizedBox(
      width: 45,
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
          
          if (index == 5 && value.isNotEmpty) {
            _handlePinComplete();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) async {
        if (state.status == AuthStatus.authenticated) {
          final securityService = SecurityService();
          final available = await securityService.isBiometricsAvailable();
          
          if (mounted && available) {
            _showBiometricsDialog(securityService);
          }
        } else if (state.errorMessage != null) {
          _showError(state.errorMessage!);
        }
      },
      child: Scaffold(
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
      ),
    );
  }
}
