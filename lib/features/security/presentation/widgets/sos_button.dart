import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:condomeet/core/design_system/design_system.dart';
import 'package:condomeet/features/security/data/repositories/sos_repository_impl.dart';

class SOSButton extends StatefulWidget {
  final String residentId;

  const SOSButton({super.key, required this.residentId});

  @override
  State<SOSButton> createState() => _SOSButtonState();
}

class _SOSButtonState extends State<SOSButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _triggerSOS();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _triggerSOS() async {
    HapticFeedback.heavyImpact();
    setState(() => _isSuccess = true);
    
    await sosRepository.triggerSOS(
      residentId: widget.residentId,
      latitude: -23.5505, // Simulated
      longitude: -46.6333,
    );

    if (mounted) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isSuccess = false;
            _controller.reset();
          });
        }
      });
    }
  }

  void _onTapDown(TapDownDetails details) {
    if (_isSuccess) return;
    _controller.forward();
    HapticFeedback.lightImpact();
  }

  void _onTapUp(TapUpDetails details) {
    if (_controller.status != AnimationStatus.completed) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: () => _controller.reverse(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Circular shadow for depth
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (_isSuccess ? Colors.green : Colors.red).withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),
          
          // Progress Ring
          SizedBox(
            width: 90,
            height: 90,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CircularProgressIndicator(
                  value: _controller.value,
                  strokeWidth: 8,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _isSuccess ? Colors.green : Colors.red,
                  ),
                );
              },
            ),
          ),
          
          // Button Core
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: _isSuccess ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                _isSuccess ? Icons.check : Icons.emergency,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          
          if (!_isSuccess)
            Positioned(
              bottom: -20,
              child: Text(
                'Segure 3s',
                style: AppTypography.label.copyWith(color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}
