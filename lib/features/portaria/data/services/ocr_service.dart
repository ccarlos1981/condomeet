/// Stubbed OCR Service — ML Kit removed to enable arm64 simulator builds.
/// Re-add google_mlkit_text_recognition when ready for production OCR.
class OcrService {
  /// Stub: returns null (no real OCR processing).
  Future<String?> processImage(dynamic image, int rotation) async {
    // TODO: Re-implement with ML Kit when targeting real devices
    return null;
  }

  void dispose() {}
}
