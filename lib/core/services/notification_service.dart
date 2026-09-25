abstract class NotificationService {
  /// Initializes the notification service (permissions, token retrieval).
  Future<void> initialize();

  /// Returns the current device's FCM token.
  Future<String?> getToken();

  /// Emits new FCM tokens when refreshed/rotated by Firebase.
  Stream<String> get onTokenRefresh;

  /// Deletes the FCM token from the device and invalidates it on Firebase servers.
  Future<void> deleteToken();

  /// Sets up background and foreground message handlers.
  void setupHandlers();

  /// Disposes of listeners.
  void dispose();
}
