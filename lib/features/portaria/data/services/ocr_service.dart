import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:camera/camera.dart';

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Processes a camera image and returns extracted unit numbers.
  Future<String?> processImage(CameraImage image, int rotation) async {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final InputImageMetadata metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: _getRotation(rotation),
      format: _getFormat(image.format.raw),
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    final inputImage = InputImage.fromBytes(bytes: bytes, metadata: metadata);
    final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

    return _extractUnitNumber(recognizedText.text);
  }

  InputImageRotation _getRotation(int rawValue) {
    switch (rawValue) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  InputImageFormat _getFormat(dynamic rawValue) {
    return InputImageFormat.nv21; // Default for many Android cameras, adjust if needed
  }

  /// Extracts potential unit numbers from text using regex.
  String? _extractUnitNumber(String text) {
    // Look for patterns like "Apto 101", "Unidade 202", "Sala 303", or just "101"
    // Regex matches common labels followed by numbers, or just 3-4 digit numbers
    final patterns = [
      RegExp(r'(?:apt|apto|unidade|unid|sala|bloco)\s*[:\-\s]*(\d{2,4})', caseSensitive: false),
      RegExp(r'\b(\d{3,4})\b'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(1);
      }
    }

    return null;
  }

  void dispose() {
    _textRecognizer.close();
  }
}
