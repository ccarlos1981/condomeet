import 'package:condomeet/core/errors/result.dart';

abstract class ConsentRepository {
  /// Records a user's consent for a specific document.
  Future<Result<void>> grantConsent({
    required String userId,
    required String consentType,
  });

  /// Checks if a user has granted consent for a specific document type and version.
  Future<Result<bool>> hasConsent({
    required String userId,
    required String consentType,
  });
}
