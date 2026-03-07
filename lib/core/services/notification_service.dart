abstract class NotificationService {
  /// Initializes the notification service (permissions, token retrieval).
  Future<void> initialize();

  /// Returns the current device's FCM token.
  Future<String?> getToken();

  /// Sets up background and foreground message handlers.
  void setupHandlers();

  /// Disposes of listeners.
  void dispose();
}
