import 'package:flutter/material.dart';
import 'package:condomeet/core/design_system/design_system.dart';

/// Stubbed OCR Scanner Screen — Camera/ML Kit removed to enable arm64 simulator builds.
/// Re-add camera and google_mlkit_text_recognition when ready for production OCR.
class OcrScannerScreen extends StatelessWidget {
  const OcrScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 80),
                const SizedBox(height: 24),
                Text(
                  'Scanner OCR',
                  style: AppTypography.h2.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  'O scanner de câmera estará disponível em breve.\nPor enquanto, digite o número da unidade manualmente.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 32),
                CondoButton(
                  label: 'Voltar',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
